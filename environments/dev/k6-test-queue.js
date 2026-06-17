import http from 'k6/http';
import { check, sleep } from 'k6';
import crypto from 'k6/crypto';
import { Trend } from 'k6/metrics';
//  [PostgreSQL 플러그인] DB에 직접 질의하기 위한 내장 모듈
import sql from 'k6/x/sql';
import driver from 'k6/x/sql/driver/postgres'; // postgres 드라이버로 변경 완료

// [실질 지표 정의] PostgreSQL 통계 엔진이 직접 반환한 '진짜' 트래픽 수치
const rdsRealWriteTPS = new Trend('rds_actual_engine_write_tps');

const CONFIG = {
    AWS_ACCESS_KEY_ID: __ENV.AWS_ACCESS_KEY_ID || '', 
    AWS_SECRET_ACCESS_KEY: __ENV.AWS_SECRET_ACCESS_KEY || '', 
    AWS_REGION: __ENV.AWS_REGION || '',
    AWS_ACCOUNT_ID: __ENV.AWS_ACCOUNT_ID || '',
    QUEUE_NAME: __ENV.QUEUE_NAME || '',
    DATABASE_NAME: __ENV.DATABASE_NAME || '', // 타겟 DB 이름 분리
    //  PostgreSQL 전용 DSN 포맷 (postgres://유저:비밀번호@엔드포인트:5432/디비명?sslmode=disable)
    RDS_DSN: __ENV.RDS_DSN || ''
};

CONFIG.SQS_ENDPOINT = `https://sqs.${CONFIG.AWS_REGION}.amazonaws.com/`;
CONFIG.SQS_QUEUE_URL = `https://sqs.${CONFIG.AWS_REGION}.amazonaws.com/${CONFIG.AWS_ACCOUNT_ID}/${CONFIG.QUEUE_NAME}`;

export const options = {
    scenarios: {
        sqs_fifo_fixed_tps: {
            executor: 'constant-arrival-rate',
            rate: 200,             // 초당 200번 배치 (초당 2,000개 예약 타격)
            timeUnit: '1s',        
            duration: '3m',        // 총 3분 (180초)
            preAllocatedVUs: 10,   
            maxVUs: 50,            
        },
    },
};

// --- [AWS SigV4 서명 함수] ---
function awsAws4Encode(str){return encodeURIComponent(str).replace(/[!'()*]/g,function(c){return'%'+c.charCodeAt(0).toString(16).toUpperCase();});}
function signSqsFormRequest(p,r,a,s){const amzDate=new Date().toISOString().replace(/[:\-]|\.\d{3}/g,'');const datestamp=amzDate.substring(0,8);const host=`sqs.${r}.amazonaws.com`;const canonicalHeaders='content-type:application/x-www-form-urlencoded; charset=utf-8\nhost:'+host+'\nx-amz-date:'+amzDate+'\n';const signedHeaders='content-type;host;x-amz-date';const payloadHash=crypto.sha256(p,'hex');const canonicalRequest='POST\n/\n\n'+canonicalHeaders+'\n'+signedHeaders+'\n'+payloadHash;const algorithm='AWS4-HMAC-SHA256';const credentialScope=`${datestamp}/${r}/sqs/aws4_request`;const stringToSign=algorithm+'\n'+amzDate+'\n'+credentialScope+'\n'+crypto.sha256(canonicalRequest,'hex');const kDate=crypto.hmac('sha256','AWS4'+s,datestamp,'binary');const kRegion=crypto.hmac('sha256',kDate,r,'binary');const kService=crypto.hmac('sha256',kRegion,'sqs','binary');const kSigning=crypto.hmac('sha256',kService,'aws4_request','binary');const signature=crypto.hmac('sha256',kSigning,stringToSign,'hex');const authorizationHeader=algorithm+' Credential='+a+'/'+credentialScope+', SignedHeaders='+signedHeaders+', Signature='+signature;return{'Content-Type':'application/x-www-form-urlencoded; charset=utf-8','X-Amz-Date':amzDate,'Authorization':authorizationHeader,'Host':host};}

// 1. [시작 단계] 부하 전 PostgreSQL 내부의 누적 INSERT 카운트 스냅샷 확보
export function setup() {
    const db = sql.open(driver, CONFIG.RDS_DSN);
    
    // AWS 공식 PostgreSQL 명세: 해당 디비의 실질적인 누적 INSERT 행 수 추출
    const query = `SELECT tup_inserted FROM pg_stat_database WHERE datname = '${CONFIG.DATABASE_NAME}';`;
    const rows = db.query(query);
    
    let initialWriteCount = 0;
    for (const row of rows) {
        initialWriteCount = parseInt(row.tup_inserted, 10);
    }
    db.close();

    return { 
        startCount: initialWriteCount,
        startTime: Date.now()
    };
}

// 2. [부하 단계] SQS 입구 타격 
export default function () {
    let formData = `Action=SendMessageBatch&QueueUrl=${awsAws4Encode(CONFIG.SQS_QUEUE_URL)}&Version=2012-11-05`;
    for (let i = 0; i < 10; i++) {
        const uniqueId = `resv_${__VU}_${__ITER}_${i}_${Date.now()}`;
        const index = i + 1;
        const messageBody = JSON.stringify({ reservation_id: `REV-${Date.now()}-${__VU}`, user_id: `user_${__VU}` });
        formData += `&SendMessageBatchRequestEntry.${index}.Id=${uniqueId}&SendMessageBatchRequestEntry.${index}.MessageBody=${awsAws4Encode(messageBody)}&SendMessageBatchRequestEntry.${index}.MessageGroupId=group_vu_${__VU}&SendMessageBatchRequestEntry.${index}.MessageDeduplicationId=${uniqueId}`;
    }

    const headers = signSqsFormRequest(formData, CONFIG.AWS_REGION, CONFIG.AWS_ACCESS_KEY_ID, CONFIG.AWS_SECRET_ACCESS_KEY);
    let res = http.post(CONFIG.SQS_ENDPOINT, formData, { headers: headers });

    check(res, { 'SQS HTTP 200 OK': (r) => r.status === 200 });
    sleep(0.05); 
}

// 3. [종료 단계] 부하 종료 직후 다시 카운트를 비교하여 "순수 실질 트래픽(Real TPS)" 역산
export function teardown(setupData) {
    const testDurationSeconds = (Date.now() - setupData.startTime) / 1000;
    
    const db = sql.open(driver, CONFIG.RDS_DSN);
    const query = `SELECT tup_inserted FROM pg_stat_database WHERE datname = '${CONFIG.DATABASE_NAME}';`;
    const rows = db.query(query);
    
    let finalWriteCount = 0;
    for (const row of rows) {
        finalWriteCount = parseInt(row.tup_inserted, 10);
    }
    db.close();

    // 수학적 검증 레이어: (최종 누적수 - 최초 누적수) / 실제 테스트 시간
    const totalActualInserts = finalWriteCount - setupData.startCount;
    const realRdsTPS = totalActualInserts / testDurationSeconds;

    // k6 최종 리포트에 주입
    rdsRealWriteTPS.add(realRdsTPS);
}
import http from 'k6/http';
import { check, sleep } from 'k6';
import crypto from 'k6/crypto';
import { Trend } from 'k6/metrics';
//  [PostgreSQL 플러그인] DB 시스템 뷰 직접 질의를 위한 내장 모듈
import sql from 'k6/x/sql';
import driver from 'k6/x/sql/driver/postgres'; 

//  [5초 주기 지표] PostgreSQL 엔진이 실제로 5초 동안 처리한 '진짜 실질 초당 트래픽(Real TPS)'
const rdsIntervalRealTPS = new Trend('rds_actual_interval_tps');

// [환경설정] 모든 인프라 및 자격 증명 정보를 환경변수(__ENV)로 안전하게 주입받음
const CONFIG = {
    AWS_ACCESS_KEY_ID: __ENV.AWS_ACCESS_KEY_ID || '', 
    AWS_SECRET_ACCESS_KEY: __ENV.AWS_SECRET_ACCESS_KEY || '', 
    AWS_REGION: __ENV.AWS_REGION || '',
    AWS_ACCOUNT_ID: __ENV.AWS_ACCOUNT_ID || '',
    QUEUE_NAME: __ENV.QUEUE_NAME || '',
    DATABASE_NAME: __ENV.DATABASE_NAME || 'concert_db', 
    RDS_DSN: __ENV.RDS_DSN || 'postgres://postgres:password@your-rds-endpoint.amazonaws.com:5432/concert_db?sslmode=disable'
};

// AWS Query API 사양 정렬
CONFIG.SQS_ENDPOINT = `https://sqs.${CONFIG.AWS_REGION}.amazonaws.com/`;
CONFIG.SQS_QUEUE_URL = `https://sqs.${CONFIG.AWS_REGION}.amazonaws.com/${CONFIG.CONFIG.AWS_ACCOUNT_ID}/${CONFIG.QUEUE_NAME}`;

export const options = {
    scenarios: {
        sqs_fifo_fixed_tps: {
            executor: 'constant-arrival-rate',
            rate: 200,             // 초당 200번 배치 요청 타겟 (초당 2,000개 예약 타격)
            timeUnit: '1s',        // 기준 시간은 1초
            duration: '3m',        // 총 부하 테스트 시간 3분
            preAllocatedVUs: 10,   // 초기 기본 VU 수
            maxVUs: 50,            // 목표 TPS를 채우기 위해 최대 50 VU까지 k6가 자동 증설
        },
    },
    thresholds: {
        http_req_failed: ['rate<0.02'], // SQS 인입 실패율 2% 미만 조건
    },
};

// AWS Signature V4 사양에 부합하는 RFC 3986 인코딩 헬퍼
function awsAws4Encode(str) {
    return encodeURIComponent(str).replace(/[!'()*]/g, function(c) {
        return '%' + c.charCodeAt(0).toString(16).toUpperCase();
    });
}

// AWS 표준 Signature V4 서명 생성기 
function signSqsFormRequest(payload, region, accessKey, secretKey) {
    const amzDate = new Date().toISOString().replace(/[:\-]|\.\d{3}/g, '');
    const datestamp = amzDate.substring(0, 8);
    const host = `sqs.${region}.amazonaws.com`;
    const canonicalUri = '/'; 
    const canonicalQueryString = '';
    
    const canonicalHeaders = 
        'content-type:application/x-www-form-urlencoded; charset=utf-8\n' + 
        'host:' + host + '\n' + 
        'x-amz-date:' + amzDate + '\n';
        
    const signedHeaders = 'content-type;host;x-amz-date';
    const payloadHash = crypto.sha256(payload, 'hex');
    
    const canonicalRequest = 'POST\n' + canonicalUri + '\n' + canonicalQueryString + '\n' + canonicalHeaders + '\n' + signedHeaders + '\n' + payloadHash;
    const algorithm = 'AWS4-HMAC-SHA256';
    const credentialScope = `${datestamp}/${region}/sqs/aws4_request`;
    const stringToSign = algorithm + '\n' + amzDate + '\n' + credentialScope + '\n' + crypto.sha256(canonicalRequest, 'hex');
        
    const kDate = crypto.hmac('sha256', 'AWS4' + secretKey, datestamp, 'binary');
    const kRegion = crypto.hmac('sha256', kDate, region, 'binary');
    const kService = crypto.hmac('sha256', kRegion, 'sqs', 'binary');
    const kSigning = crypto.hmac('sha256', kService, 'aws4_request', 'binary');
    
    const signature = crypto.hmac('sha256', kSigning, stringToSign, 'hex');
    const authorizationHeader = algorithm + ' Credential=' + accessKey + '/' + credentialScope + ', SignedHeaders=' + signedHeaders + ', Signature=' + signature;
        
    return {
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'X-Amz-Date': amzDate,
        'Authorization': authorizationHeader,
        'Host': host
    };
}

// 5초 주기 실시간 중계 연산을 위한 공유 상태 변수 초기화
let lastCheckedTime = Date.now();
let lastCheckedCount = 0;

// 1. [시작 단계] 부하가 걸리기 직전, 현재 PostgreSQL 내부의 누적 INSERT 카운트 백업
export function setup() {
    const missingVars = [];
    if (!CONFIG.AWS_ACCESS_KEY_ID) missingVars.push('AWS_ACCESS_KEY_ID');
    if (!CONFIG.AWS_SECRET_ACCESS_KEY) missingVars.push('AWS_SECRET_ACCESS_KEY');
    if (!CONFIG.AWS_ACCOUNT_ID) missingVars.push('AWS_ACCOUNT_ID');
    if (!CONFIG.QUEUE_NAME) missingVars.push('QUEUE_NAME');
    if (!CONFIG.AWS_REGION) missingVars.push('AWS_REGION');

    if (missingVars.length > 0) {
        throw new Error(`[환경변수 오류] 부하 테스트를 실행할 수 없습니다: ${missingVars.join(', ')}`);
    }

    const db = sql.open(driver, CONFIG.RDS_DSN);
    const query = `SELECT tup_inserted FROM pg_stat_database WHERE datname = '${CONFIG.DATABASE_NAME}';`;
    const rows = db.query(query);
    let initialWriteCount = 0;
    for (const row of rows) { initialWriteCount = parseInt(row.tup_inserted, 10); }
    db.close();

    return { startCount: initialWriteCount, startTime: Date.now() };
}

// 2. [부하 단계] SQS 타격 진행 및 1번 유저 격리 기반 5초 주기 DB 통계 수집
export default function () {
    let formData = `Action=SendMessageBatch&QueueUrl=${awsAws4Encode(CONFIG.SQS_QUEUE_URL)}&Version=2012-11-05`;
    
    for (let i = 0; i < 10; i++) {
        const uniqueId = `resv_${__VU}_${__ITER}_${i}_${Date.now()}`;
        const index = i + 1;
        const messageBody = JSON.stringify({ 
            reservation_id: `REV-${Date.now()}-${__VU}-${__ITER}-${i}`, 
            user_id: `user_${__VU}_${i}`,
            concert_id: 'concert-2026',
            timestamp: Date.now()
        });
        formData += `&SendMessageBatchRequestEntry.${index}.Id=${uniqueId}&SendMessageBatchRequestEntry.${index}.MessageBody=${awsAws4Encode(messageBody)}&SendMessageBatchRequestEntry.${index}.MessageGroupId=group_vu_${__VU}_${i}&SendMessageBatchRequestEntry.${index}.MessageDeduplicationId=${uniqueId}`;
    }

    const headers = signSqsFormRequest(formData, CONFIG.AWS_REGION, CONFIG.AWS_ACCESS_KEY_ID, CONFIG.AWS_SECRET_ACCESS_KEY);
    
    // 실제 SQS POST 전송 
    let res = http.post(CONFIG.SQS_ENDPOINT, formData, { headers: headers });

    // -------------------------------------------------------------------------
    // [격리 제어] 5초에 한 번만 실행되는 백그라운드 RDS 실측 트래픽 연산 레이어
    // -------------------------------------------------------------------------
    // 수많은 가상 유저들 중 딱 1번 유저(__VU === 1)만 5초 주기를 계산하여 가볍게 전담 조회
    if (__VU === 1 && Date.now() - lastCheckedTime >= 5000) {
        const currentTime = Date.now();
        const durationSeconds = (currentTime - lastCheckedTime) / 1000;

        try {
            const db = sql.open(driver, CONFIG.RDS_DSN);
            const query = `SELECT tup_inserted FROM pg_stat_database WHERE datname = '${CONFIG.DATABASE_NAME}';`;
            const rows = db.query(query);
            
            let currentWriteCount = 0;
            for (const row of rows) { currentWriteCount = parseInt(row.tup_inserted, 10); }
            db.close();

            if (lastCheckedCount === 0) {
                lastCheckedCount = currentWriteCount; 
            } else {
                const intervalInserts = currentWriteCount - lastCheckedCount;
                const intervalTPS = intervalInserts / durationSeconds;

                // 5초 주기 실측 TPS 데이터를 k6 시계열 스트림에 주입
                rdsIntervalRealTPS.add(intervalTPS);
                lastCheckedCount = currentWriteCount;
            }
        } catch (err) {
            // DB 네트워크 지연 등 돌발 변수 시 테스트가 멈추지 않도록 예외 차단 안전장치
        }
        lastCheckedTime = currentTime;
    }

    check(res, { 'SQS HTTP 200 OK': (r) => r.status === 200 });
    sleep(0.05); 
}

// 3. [종료 단계] 부하 종료 직후 전체 평균 "순수 실질 트래픽(Real TPS)" 최종 검증 리포트 병합
export function teardown(setupData) {
    const testDurationSeconds = (Date.now() - setupData.startTime) / 1000;
    
    const db = sql.open(driver, CONFIG.RDS_DSN);
    const query = `SELECT tup_inserted FROM pg_stat_database WHERE datname = '${CONFIG.DATABASE_NAME}';`;
    const rows = db.query(query);
    let finalWriteCount = 0;
    for (const row of rows) { finalWriteCount = parseInt(row.tup_inserted, 10); }
    db.close();

    const totalActualInserts = finalWriteCount - setupData.startCount;
    const realRdsTPS = totalActualInserts / testDurationSeconds;
    
    // 최종 평균 실측 리포트값 기록
    rdsIntervalRealTPS.add(realRdsTPS);
}
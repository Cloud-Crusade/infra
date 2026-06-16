import http from 'k6/http';
import { check, sleep } from 'k6';
import crypto from 'k6/crypto';

// [환경설정] 모든 인프라 및 자격 증명 정보를 환경변수(__ENV)로 안전하게 주입받음
const CONFIG = {
    AWS_ACCESS_KEY_ID: __ENV.AWS_ACCESS_KEY_ID || '', 
    AWS_SECRET_ACCESS_KEY: __ENV.AWS_SECRET_ACCESS_KEY || '', 
    AWS_REGION: __ENV.AWS_REGION || '',
    AWS_ACCOUNT_ID: __ENV.AWS_ACCOUNT_ID || '',
    QUEUE_NAME: __ENV.QUEUE_NAME || ''
};

// AWS Query API 명세에 따라 호스트 루트 정렬 및 가상 큐 URL 분리
CONFIG.SQS_ENDPOINT = `https://sqs.${CONFIG.AWS_REGION}.amazonaws.com/`;
CONFIG.SQS_QUEUE_URL = `https://sqs.${CONFIG.AWS_REGION}.amazonaws.com/${CONFIG.AWS_ACCOUNT_ID}/${CONFIG.QUEUE_NAME}`;

export const options = {
    scenarios: {
        sqs_fifo_direct_stable_load: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '30s', target: 20 }, // 30초 동안 20 VU까지 점진적 상승
                { duration: '3m', target: 50 },  // 3분 동안 50 VU 유지 (안정성 검증 핵심 구간)
                { duration: '30s', target: 0 },  // 30초 동안 자원 회수 및 점진적 종료
            ],
            gracefulStop: '30s',
        },
    },
    thresholds: {
        http_req_failed: ['rate<0.02'], // 전체 에러율 2% 미만 유지 조건 (임계치 실패 시 테스트 실패 처리)
    },
};

// AWS Signature V4 사양에 부합하는 RFC 3986 인코딩 헬퍼
function awsAws4Encode(str) {
    return encodeURIComponent(str).replace(/[!'()*]/g, function(c) {
        return '%' + c.charCodeAt(0).toString(16).toUpperCase();
    });
}

// AWS 표준 Signature V4 서명 생성기 (Form URL-Encoded 프로토콜 완전 정렬)
function signSqsFormRequest(payload, region, accessKey, secretKey) {
    const amzDate = new Date().toISOString().replace(/[:\-]|\.\d{3}/g, '');
    const datestamp = amzDate.substring(0, 8);
    
    const host = `sqs.${region}.amazonaws.com`;
    const canonicalUri = '/'; // AWS Query API 표준에 따라 POST 요청은 루트(/) 경로 기준 서명 생성
    const canonicalQueryString = '';
    
    // JSON 기반의 X-Amz-Target 헤더는 완벽히 제거하고 Form 규격 헤더들로만 표준 가공
    const canonicalHeaders = 
        'content-type:application/x-www-form-urlencoded; charset=utf-8\n' + 
        'host:' + host + '\n' + 
        'x-amz-date:' + amzDate + '\n';
        
    const signedHeaders = 'content-type;host;x-amz-date';
    const payloadHash = crypto.sha256(payload, 'hex');
    
    const canonicalRequest = 
        'POST\n' + 
        canonicalUri + '\n' + 
        canonicalQueryString + '\n' + 
        canonicalHeaders + '\n' + 
        signedHeaders + '\n' + 
        payloadHash;
        
    const algorithm = 'AWS4-HMAC-SHA256';
    const credentialScope = `${datestamp}/${region}/sqs/aws4_request`;
    const stringToSign = 
        algorithm + '\n' + 
        amzDate + '\n' + 
        credentialScope + '\n' + 
        crypto.sha256(canonicalRequest, 'hex');
        
    const kDate = crypto.hmac('sha256', 'AWS4' + secretKey, datestamp, 'binary');
    const kRegion = crypto.hmac('sha256', kDate, region, 'binary');
    const kService = crypto.hmac('sha256', kRegion, 'sqs', 'binary');
    const kSigning = crypto.hmac('sha256', kService, 'aws4_request', 'binary');
    
    const signature = crypto.hmac('sha256', kSigning, stringToSign, 'hex');
    const authorizationHeader = 
        algorithm + ' ' + 
        'Credential=' + accessKey + '/' + credentialScope + ', ' + 
        'SignedHeaders=' + signedHeaders + ', ' + 
        'Signature=' + signature;
        
    return {
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'X-Amz-Date': amzDate,
        'Authorization': authorizationHeader,
        'Host': host
    };
}

// 런타임 진입 전 환경변수 유실 유무를 1차 차단하는 방어 레이어
export function setup() {
    const missingVars = [];
    if (!CONFIG.AWS_ACCESS_KEY_ID) missingVars.push('AWS_ACCESS_KEY_ID');
    if (!CONFIG.AWS_SECRET_ACCESS_KEY) missingVars.push('AWS_SECRET_ACCESS_KEY');
    if (!CONFIG.AWS_ACCOUNT_ID) missingVars.push('AWS_ACCOUNT_ID');
    if (!CONFIG.QUEUE_NAME) missingVars.push('QUEUE_NAME');
    if (!CONFIG.AWS_REGION) missingVars.push('AWS_REGION');

    if (missingVars.length > 0) {
        throw new Error(`[환경변수 유실 오류] 부하 테스트를 실행할 수 없습니다: ${missingVars.join(', ')}`);
    }
    return {};
}

export default function () {
    // 가상 호스트 엔드포인트로 쏘기 위해 큐 URL 주소를 바디 파라미터(QueueUrl)에 명시
    let formData = `Action=SendMessageBatch&QueueUrl=${awsAws4Encode(CONFIG.SQS_QUEUE_URL)}&Version=2012-11-05`;

    for (let i = 0; i < 10; i++) {
        const uniqueId = `resv_${__VU}_${__ITER}_${i}_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
        const index = i + 1;

        const messageBody = JSON.stringify({
            reservation_id: `REV-${Date.now()}-${__VU}-${__ITER}-${i}`,
            user_id: `user_${__VU}_${i}`,
            concert_id: 'concert-2026',
            timestamp: Date.now()
        });

        formData += `&SendMessageBatchRequestEntry.${index}.Id=${uniqueId}`;
        formData += `&SendMessageBatchRequestEntry.${index}.MessageBody=${awsAws4Encode(messageBody)}`;
        
        // [중요] 대규모 인프라 부하 시 특정 파티션 락 및 순서 병목 현상을 방지하기 위해 GroupId 분산 설계 적용
        formData += `&SendMessageBatchRequestEntry.${index}.MessageGroupId=group_vu_${__VU}_${i}`;
        formData += `&SendMessageBatchRequestEntry.${index}.MessageDeduplicationId=${uniqueId}`;
    }

    // 전송 전용 서명 헤더셋 빌드
    const headers = signSqsFormRequest(
        formData, 
        CONFIG.AWS_REGION, 
        CONFIG.AWS_ACCESS_KEY_ID, 
        CONFIG.AWS_SECRET_ACCESS_KEY
    );

    // 실제 POST 전송 (엔드포인트 최적화 완료)
    let res = http.post(CONFIG.SQS_ENDPOINT, formData, { headers: headers });

    let isAllSuccess = false;
    let failReason = '';

    // SQS 특유의 HTTP 200 내 파셜 에러(일부 성공, 일부 실패) 현상 완벽 파싱 레이어
    if (res.status === 200) {
        if (res.body && res.body.includes('<BatchResultErrorEntry>')) {
            isAllSuccess = false;
            failReason = 'BatchPartialFailure_In_XML';
        } else {
            isAllSuccess = true;
        }
    } else {
        isAllSuccess = false;
        failReason = `HTTP_STATUS_${res.status}`;
    }

    // k6 대시보드 실시간 지표 검증 바인딩
    check(res, {
        'SQS HTTP 200 OK': (r) => r.status === 200,
        'FIFO Batch All Delivered': () => isAllSuccess,
    });

    // 에러 발생 시 신속한 원인 분석을 위한 로깅 스니펫 제공
    if (!isAllSuccess) {
        console.warn(`[SQS FAIL] VU: ${__VU} | Reason: ${failReason} | Response Snippet: ${res.body ? res.body.substring(0, 150) : 'No Body'}`);
    }

    sleep(0.05); // 과도한 로컬 자원 점유 방지용 인터벌 미세 조정
}
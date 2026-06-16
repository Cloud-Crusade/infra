import http from 'k6/http';
import { check } from 'k6';
import crypto from 'k6/crypto';

// [환경설정] 모든 인프라 및 자격 증명 정보를 환경변수(__ENV)로 안전하게 주입받음
const CONFIG = {
    AWS_ACCESS_KEY_ID: __ENV.AWS_ACCESS_KEY_ID || '', 
    AWS_SECRET_ACCESS_KEY: __ENV.AWS_SECRET_ACCESS_KEY || '', 
    AWS_REGION: __ENV.AWS_REGION || '',
    AWS_ACCOUNT_ID: __ENV.AWS_ACCOUNT_ID || '',
    QUEUE_NAME: __ENV.QUEUE_NAME || '' // 아키텍처 상의 '예약/결제 확정 SQS'
};

// AWS Query API 명세 표준화 정렬
CONFIG.SQS_ENDPOINT = `https://sqs.${CONFIG.AWS_REGION}.amazonaws.com/`;
CONFIG.SQS_QUEUE_URL = `https://sqs.${CONFIG.AWS_REGION}.amazonaws.com/${CONFIG.AWS_ACCOUNT_ID}/${CONFIG.QUEUE_NAME}`;

export const options = {
    scenarios: {
        leaky_bucket_integrated_test: {
            executor: 'constant-arrival-rate',
            rate: 10,              // 초당 정확히 10회 실행 호출 보장
            timeUnit: '1s',
            duration: '5m',        // 다이어그램의 '초당 50~100 TPS' 지속성을 검증하기 위한 5분 가동
            preAllocatedVUs: 15,   // 안정적인 부하 유지를 위한 가상 유저 선할당
            maxVUs: 50,            // 인프라 지연 발생 시 확장 한계선
        },
    },
    thresholds: {
        http_req_failed: ['rate<0.01'], // SQS 전송 자체 실패율 1% 미만 조건
    },
};

// AWS 사양 표준 URL 인코딩 헬퍼
function awsAws4Encode(str) {
    return encodeURIComponent(str).replace(/[!'()*]/g, function(c) {
        return '%' + c.charCodeAt(0).toString(16).toUpperCase();
    });
}

// AWS 표준 Signature V4 서명 생성기 (Form 프로토콜 완벽 대응)
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
    
    return {
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'X-Amz-Date': amzDate,
        'Authorization': `${algorithm} Credential=${accessKey}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`,
        'Host': host
    };
}

export function setup() {
    const missingVars = [];
    if (!CONFIG.AWS_ACCESS_KEY_ID) missingVars.push('AWS_ACCESS_KEY_ID');
    if (!CONFIG.AWS_SECRET_ACCESS_KEY) missingVars.push('AWS_SECRET_ACCESS_KEY');
    if (!CONFIG.AWS_ACCOUNT_ID) missingVars.push('AWS_ACCOUNT_ID');
    if (!CONFIG.QUEUE_NAME) missingVars.push('QUEUE_NAME');
    if (!CONFIG.AWS_REGION) missingVars.push('AWS_REGION');

    if (missingVars.length > 0) {
        throw new Error(`[환경변수 오류] 필수 변수 누락: ${missingVars.join(', ')}`);
    }
    return {};
}

export default function () {
    // 크리티컬 패치: 파라미터 알파벳 순서 정렬 원칙 준수 (Action -> QueueUrl)
    let formData = `Action=SendMessageBatch&QueueUrl=${awsAws4Encode(CONFIG.SQS_QUEUE_URL)}`;

    // consumer.py 내부 분기 처리를 정밀 타격하기 위한 액션 명세
    const actions = ['reservation.create', 'reservation.cancel', 'payment.create'];

    // 1회 호출당 10개 메시지 묶음 전송 (rate 10 * 배치 10 = 전체 100 TPS 트래픽 형성)
    for (let i = 0; i < 10; i++) {
        const index = i + 1;
        const timestamp = Date.now();
        const randId = Math.floor(Math.random() * 100000);
        
        const resvId = `REV-${timestamp}-${__VU}-${__ITER}-${i}-${randId}`;
        const payId = `PAY-${timestamp}-${__VU}-${__ITER}-${i}-${randId}`;
        const uniqueMessageId = `msg_${timestamp}_${__VU}_${__ITER}_${i}_${randId}`;

        // 루프 순서에 따라 3가지 이벤트를 골고루 교차 배정
        const selectedAction = actions[(i + __ITER) % actions.length];
        
        // 무결성 패치: repository.py의 각 SQL 적재 필드 명세와 100% 매칭된 body 구성
        let bodyPayload = {
            action: selectedAction,
            reservation_id: resvId,
            user_id: `USER-${__VU}-${randId}`
        };

        if (selectedAction === 'reservation.create') {
            bodyPayload.event_id = 'CONCERT-2026-GRAND';
            bodyPayload.reserved_num = Math.floor(Math.random() * 4) + 1; // %s 파라미터 매핑용
        } else if (selectedAction === 'payment.create') {
            bodyPayload.payment_history_id = payId;
            bodyPayload.payment_method = 'CREDIT_CARD';
        }

        formData += `&SendMessageBatchRequestEntry.${index}.Id=${uniqueMessageId}`;
        formData += `&SendMessageBatchRequestEntry.${index}.MessageBody=${awsAws4Encode(JSON.stringify(bodyPayload))}`;
        
        // consumer.py 가 messageGroupId 단위로 묶어 정렬하므로, 부하 분산을 조율하기 위한 그룹 식별자 고유화
        formData += `&SendMessageBatchRequestEntry.${index}.MessageGroupId=group_persistence_${__VU}_${i}`;
        formData += `&SendMessageBatchRequestEntry.${index}.MessageDeduplicationId=${uniqueMessageId}`;
    }

    // Version 속성을 알파벳 순서상 가장 뒤에 결합
    formData += `&Version=2012-11-05`;

    // 서명 생성 후 SQS 엔드포인트로 전송
    const headers = signSqsFormRequest(formData, CONFIG.AWS_REGION, CONFIG.AWS_ACCESS_KEY_ID, CONFIG.AWS_SECRET_ACCESS_KEY);
    let res = http.post(CONFIG.SQS_ENDPOINT, formData, { headers: headers });

    let isAllSuccess = res.status === 200 && (!res.body || !res.body.includes('<BatchResultErrorEntry>'));

    check(res, {
        'SQS Inbound HTTP 200': (r) => r.status === 200,
        'Batch Inqueue Perfect': () => isAllSuccess,
    });

    if (!isAllSuccess) {
        console.warn(`[SQS 인큐 실패] 상태: ${res.status} | 스니펫: ${res.body ? res.body.substring(0, 120) : 'No Body'}`);
    }
}
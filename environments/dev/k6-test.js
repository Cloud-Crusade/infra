import http from 'k6/http';
import { check, sleep } from 'k6';
import crypto from 'k6/crypto';
import encoding from 'k6/encoding';

export const options = {
    scenarios: {
        safe_lambda_queue_test: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '30s', target: 20 }, // 30초 동안 VU 20명까지 안정적으로 증가
                { duration: '2m', target: 40 },  // 최대 40명 유지 (AWS Secrets Manager 제한을 피하기 위한 안전 수치)
                { duration: '30s', target: 0 },  // 30초 동안 서서히 감소 후 종료
            ],
            gracefulStop: '30s',
        },
    },
    thresholds: {
        http_req_failed: ['rate<0.01'],   // 안전 테스트이므로 에러율 1% 미만 조건 타이트하게 설정
        http_req_duration: ['p(95)<1500'], // 95%의 요청이 1.5초 이내에 완료될 것
    },
};

// ==========================================
//  [설정 사항] 환경 변수(Environment Variable) 적용
// ==========================================
const CONFIG = {
    // Git에 공유되어도 안전한 엔드포인트 정보
    BASE_URL: 'https://yeuc9w7wyj.execute-api.ap-northeast-2.amazonaws.com/dev',
    EVENT_ID: 'concert-2026',

    // 🔥 보안 위협이 되는 실제 대칭키는 환경 변수에서 동적으로 읽어옵니다.
    JWT_SECRET_KEY: __ENV.JWT_SECRET_KEY
};

/**
 * 람다 규격에 맞는 가짜 로그인 세션 토큰 실시간 생성 함수
 */
function generateTestToken(userId, secret) {
    const header = { alg: 'HS256', typ: 'JWT' };
    const payload = {
        type: 'access',
        sub: userId,
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 3600
    };

    const base64UrlEncode = (obj) => {
        let str = JSON.stringify(obj);
        return encoding.b64encode(str, 'rawurl');
    };

    const encodedHeader = base64UrlEncode(header);
    const encodedPayload = base64UrlEncode(payload);
    const signatureInput = `${encodedHeader}.${encodedPayload}`;

    const signature = crypto.hmac('sha256', secret, signatureInput, 'base64url');
    return `${signatureInput}.${signature}`;
}

export function setup() {
    // 시크릿 키 누락 시 테스트가 실행되지 않도록 강제 종료 처리
    if (!CONFIG.JWT_SECRET_KEY) {
        throw new Error('[실행 차단] JWT_SECRET_KEY 환경 변수가 설정되지 않았습니다. 테스트를 시작할 수 없습니다.');
    }
    return {};
}

export default function (data) {
    // Redis의 중복 인플레이션을 방지하기 위한 가상 유저별 고유 ID 매핑
    const uniqueUserId = `user_${__VU}_${__ITER}`;
    const token = generateTestToken(uniqueUserId, CONFIG.JWT_SECRET_KEY);

    // 엔드포인트 주소 규칙 매핑: /dev/queue/{event_id}
    const TARGET_URL = `${CONFIG.BASE_URL}/queue/${CONFIG.EVENT_ID}`;

    const params = {
        headers: {
            'Content-Type': 'application/json',
            'X-Dummy-Ping': 'true',
            'Authorization': `Bearer ${token}`
        },
        timeout: '10s'
    };

    // 대기열 API 호출 
    let res = http.get(TARGET_URL, params);

    let isCompleted = false;
    let isWaiting = false;

    if (res.status === 200) {
        const jsonBody = res.json();
        isCompleted = jsonBody.code === 'COMPLETED';
        isWaiting = jsonBody.code === 'WAITING';
    }

    // 최종 검증 지표 세팅
    check(res, {
        'HTTP Status 200 OK': (r) => r.status === 200,
        'Auth Passed (Not 401)': (r) => r.status !== 401,
        'Path Valid (Not 400/404)': (r) => r.status !== 400 && r.status !== 404,
        'Queue Logic Standard Output': (r) => isCompleted || isWaiting,
    });

    // 상세 에러 핸들링 모니터링 로그
    if (res.status === 401) {
        console.error(`[인증 오류] JWT_SECRET_KEY가 AWS 비밀키와 일치하지 않습니다.`);
    } else if (res.status === 400 || res.status === 404) {
        console.error(`[경로 오류] 주소가 유효하지 않거나 파라미터가 유실되었습니다. (요청 주소: ${TARGET_URL})`);
    } else if (res.status === 500) {
        console.warn(`[백엔드 오버로드] AWS Secrets Manager 호출 제한(Rate Limit)을 초과 중입니다.`);
    }

    // 안전 제어: 요청 간격을 5.0초로 두어 AWS 시크릿 호출을 분산시킵니다.
    sleep(5.0);
}
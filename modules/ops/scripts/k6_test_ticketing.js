import http from 'k6/http';
import { check, sleep } from 'k6';
import crypto from 'k6/crypto';
import encoding from 'k6/encoding';
import { Counter, Rate } from 'k6/metrics';

// 각 VU = 한 유저. 같은 유저가 /queue 를 폴링하며 순번 배정·진행이 올바른지 검증한다.
//  - queue_number 는 폴링 내내 고정(유저별 캐시)
//  - remaining 은 단조 감소(입장 커서 current 는 전진만)
//  - 최종적으로 COMPLETED + 입장 토큰(data.token) 수신
export const options = {
    scenarios: {
        queue_progression: {
            executor: 'per-vu-iterations',
            vus: 20,
            iterations: 60,      // 유저당 최대 60회 폴링
            maxDuration: '3m',
            gracefulStop: '10s',
        },
    },
    thresholds: {
        http_req_failed: ['rate<0.01'],
        http_req_duration: ['p(95)<1500'],
        queue_number_stable: ['rate>0.99'],   // 순번이 폴링 중 바뀌지 않음
        remaining_monotonic: ['rate>0.99'],   // remaining 이 증가하지 않음
        checks: ['rate>0.99'],
    },
};

const CONFIG = {
    BASE_URL: __ENV.BASE_URL,
    EVENT_ID: __ENV.EVENT_ID,
    JWT_SECRET_KEY: __ENV.JWT_SECRET_KEY,
};
const POLL_INTERVAL_SECONDS = 2.0;

const queueNumberStable = new Rate('queue_number_stable');
const remainingMonotonic = new Rate('remaining_monotonic');
const completedUsers = new Counter('completed_users');

// 람다 규격(HS256 access)에 맞는 세션 토큰 생성. sub(user_id)가 같으면 동일 순번을 받는다.
function generateTestToken(userId, secret) {
    const header = { alg: 'HS256', typ: 'JWT' };
    const now = Math.floor(Date.now() / 1000);
    const payload = { type: 'access', sub: userId, iat: now, exp: now + 3600 };
    const b64 = (obj) => encoding.b64encode(JSON.stringify(obj), 'rawurl');
    const signingInput = `${b64(header)}.${b64(payload)}`;
    const signature = crypto.hmac('sha256', secret, signingInput, 'base64url');
    return `${signingInput}.${signature}`;
}

export function setup() {
    const missing = ['BASE_URL', 'EVENT_ID', 'JWT_SECRET_KEY'].filter((k) => !CONFIG[k]);
    if (missing.length > 0) {
        throw new Error(`[실행 실패] 필수 환경 변수 누락: ${missing.join(', ')}`);
    }
    return {};
}

// VU 단위 상태 — k6 는 VU 마다 모듈 인스턴스를 분리하므로 반복(iteration) 간 유지된다.
let userId = null;
let myQueueNumber = null;
let lastRemaining = Infinity;
let done = false;

export default function () {
    if (userId === null) userId = `user_${__VU}`;
    if (done) { sleep(POLL_INTERVAL_SECONDS); return; } // 이미 입장한 유저는 폴링 종료

    const token = generateTestToken(userId, CONFIG.JWT_SECRET_KEY);
    const res = http.get(`${CONFIG.BASE_URL}/queue/${CONFIG.EVENT_ID}`, {
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        timeout: '10s',
    });

    if (res.status !== 200) {
        check(res, { 'HTTP 200': (r) => r.status === 200 });
        if (res.status === 401) console.error('[인증 오류] JWT_SECRET_KEY 불일치');
        else if (res.status === 400 || res.status === 404) console.error(`[경로 오류] ${CONFIG.EVENT_ID}`);
        else if (res.status >= 500) console.warn('[백엔드 오류] 5xx');
        sleep(POLL_INTERVAL_SECONDS);
        return;
    }

    const body = res.json();
    if (body.code === 'WAITING') {
        const qn = body.data && body.data.queue_number;
        const remaining = body.data && body.data.remaining;
        if (myQueueNumber === null) myQueueNumber = qn;

        const stable = qn === myQueueNumber;          // 순번 고정
        const monotonic = remaining <= lastRemaining; // remaining 비증가
        queueNumberStable.add(stable);
        remainingMonotonic.add(monotonic);
        lastRemaining = remaining;

        check(body, {
            'WAITING: queue_number 존재': () => typeof qn === 'number' && qn > 0,
            'WAITING: remaining 존재': () => typeof remaining === 'number' && remaining >= 0,
            'WAITING: 순번 고정': () => stable,
            'WAITING: remaining 단조 감소': () => monotonic,
        });
    } else if (body.code === 'COMPLETED') {
        const hasToken = !!(body.data && body.data.token);
        check(body, { 'COMPLETED: 입장 토큰 존재': () => hasToken });
        if (hasToken) completedUsers.add(1);
        done = true;
        return;
    } else {
        check(body, { '알 수 없는 code': () => false });
        console.error(`[응답 오류] 예상치 못한 code: ${body.code}`);
    }

    sleep(POLL_INTERVAL_SECONDS);
}

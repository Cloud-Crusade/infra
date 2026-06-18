import { check, sleep } from 'k6';
import { Trend, Gauge } from 'k6/metrics';
// [PostgreSQL 플러그인] DB 시스템 뷰 직접 질의를 위한 내장 모듈
import sql from 'k6/x/sql';
import driver from 'k6/x/sql/driver/postgres';
// [공식 AWS 라이브러리] SQS 클라이언트 — SigV4 서명·SQS JSON 프로토콜을 내부에서 처리
import { AWSConfig, SQSClient } from 'https://jslib.k6.io/aws/0.14.0/sqs.js';

// [5초 주기 지표] PostgreSQL 엔진이 실제로 처리한 '실질 초당 트래픽(Real TPS)' 분포
const rdsIntervalRealTPS = new Trend('rds_actual_interval_tps');
// [전체 평균] interval 분포와 섞이지 않도록 별도 Gauge 로 분리(분포 왜곡 방지)
const rdsOverallAvgTPS = new Gauge('rds_overall_avg_tps');

// [환경설정] 모든 인프라 및 자격 증명 정보를 환경변수(__ENV)로 안전하게 주입받음
const CONFIG = {
    AWS_ACCESS_KEY_ID: __ENV.AWS_ACCESS_KEY_ID || '',
    AWS_SECRET_ACCESS_KEY: __ENV.AWS_SECRET_ACCESS_KEY || '',
    AWS_REGION: __ENV.AWS_REGION || '',
    AWS_ACCOUNT_ID: __ENV.AWS_ACCOUNT_ID || '',
    QUEUE_NAME: __ENV.QUEUE_NAME || '',
    DATABASE_NAME: __ENV.DATABASE_NAME || '',
    RDS_DSN: __ENV.RDS_DSN || ''
};

// AWS 표준 큐 URL (sendMessageBatch 의 QueueUrl)
CONFIG.SQS_QUEUE_URL = `https://sqs.${CONFIG.AWS_REGION}.amazonaws.com/${CONFIG.AWS_ACCOUNT_ID}/${CONFIG.QUEUE_NAME}`;

// [환경변수 검증] 클라이언트 생성 전 init 단계에서 누락 즉시 차단
const REQUIRED_VARS = ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_REGION', 'AWS_ACCOUNT_ID', 'QUEUE_NAME', 'DATABASE_NAME', 'RDS_DSN'];
const missingVars = REQUIRED_VARS.filter((k) => !CONFIG[k]);
if (missingVars.length > 0) {
    throw new Error(`[환경변수 오류] 부하 테스트를 실행할 수 없습니다: ${missingVars.join(', ')}`);
}

// [Init Context] DB 커넥션 풀과 SQS 클라이언트는 여기서 단 한 번만 생성한다.
// xk6-sql 의 sql.open() 은 커넥션 풀을 만들므로 setup/default/teardown(특히 반복 루프) 안에서
// 호출하면 풀이 무한 증식해 커넥션 고갈·메모리 누수가 발생한다. 전 함수가 이 핸들을 공유한다.
const db = sql.open(driver, CONFIG.RDS_DSN);

// 자격증명·리전만 주입하면 SigV4 서명은 라이브러리가 처리(수동 서명 코드 제거)
const sqs = new SQSClient(new AWSConfig({
    region: CONFIG.AWS_REGION,
    accessKeyId: CONFIG.AWS_ACCESS_KEY_ID,
    secretAccessKey: CONFIG.AWS_SECRET_ACCESS_KEY,
}));

const WRITE_COUNT_QUERY = `SELECT tup_inserted FROM pg_stat_database WHERE datname = '${CONFIG.DATABASE_NAME}';`;

function readWriteCount() {
    let count = 0;
    for (const row of db.query(WRITE_COUNT_QUERY)) { count = parseInt(row.tup_inserted, 10); }
    return count;
}

// [Mock 데이터 사양] 식별이 용이하도록 TEST- 접두사 일괄 적용
const MOCK_DATA = {
    CONCERT_ID: 'TEST-CONCERT-2026',
    USER_PREFIX: 'TEST-USER',
    RESERVATION_PREFIX: 'TEST-REV',
    GROUP_PREFIX: 'TEST-GROUP'
};

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

// VU별 격리 환경 타이머 변수 초기화
let lastCheckedTime = Date.now();
let lastCheckedCount = 0;

// 1. [시작 단계] 부하 직전 PostgreSQL 누적 INSERT 카운트 백업 (Init 의 공유 db 핸들 사용)
export function setup() {
    return { startCount: readWriteCount(), startTime: Date.now() };
}

// 2. [부하 단계] SQS 타격 진행 및 VU 1번 격리 기반 5초 주기 DB 통계 수집
export default async function (setupData) {
    const entries = [];

    for (let i = 0; i < 10; i++) {
        const timestamp = Date.now();
        const uniqueId = `resv_${__VU}_${__ITER}_${i}_${timestamp}`;

        // 요구사항 반영: 식별하기 편하도록 TEST- 접두사를 명시한 구조로 바디 조립
        const messageBody = JSON.stringify({
            reservation_id: `${MOCK_DATA.RESERVATION_PREFIX}-${timestamp}-${__VU}-${__ITER}-${i}`,
            user_id: `${MOCK_DATA.USER_PREFIX}-${__VU}-${i}`,
            concert_id: MOCK_DATA.CONCERT_ID,
            timestamp: timestamp
        });

        // FIFO 큐 옵션(MessageGroupId/MessageDeduplicationId)은 entry 의 messageOptions 로 전달
        entries.push({
            messageId: uniqueId,
            messageBody: messageBody,
            messageOptions: {
                messageGroupId: `${MOCK_DATA.GROUP_PREFIX}-VU-${__VU}-${i}`,
                messageDeduplicationId: uniqueId,
            },
        });
    }

    // 실제 SQS 배치 전송 — 라이브러리가 SigV4 서명·JSON 프로토콜 처리
    let batchOk = false;
    try {
        const result = await sqs.sendMessageBatch(CONFIG.SQS_QUEUE_URL, entries);
        batchOk = result.failed.length === 0;
    } catch (err) {
        // 테스트는 중단하지 않되 원인 파악을 위해 에러는 로깅 (CWE-391: 에러 은닉 방지)
        console.error('[SQS 전송 에러]', err.message);
    }

    // -------------------------------------------------------------------------
    // [격리 제어] VU 1번이 5초 주기로만 RDS 실측 트래픽 산정 (공유 db 핸들 재사용)
    // TPS 는 실제 경과시간(durationSeconds)으로 나누므로, 폴링 간격이 약간 흔들려도 값은 정확하다.
    // -------------------------------------------------------------------------
    if (__VU === 1 && Date.now() - lastCheckedTime >= 5000) {
        const currentTime = Date.now();
        const durationSeconds = (currentTime - lastCheckedTime) / 1000;

        try {
            const currentWriteCount = readWriteCount();

            // VU 1번 최초 기동 시엔 직전 카운트가 없으므로 기준값만 백업 (오차 방지)
            if (lastCheckedCount === 0) {
                lastCheckedCount = currentWriteCount;
            } else if (durationSeconds > 0) {
                rdsIntervalRealTPS.add((currentWriteCount - lastCheckedCount) / durationSeconds);
                lastCheckedCount = currentWriteCount;
            }
        } catch (err) {
            // 테스트는 중단하지 않되 원인 파악을 위해 에러는 로깅 (CWE-391: 에러 은닉 방지)
            console.error('[DB 조회 에러]', err.message);
        }
        lastCheckedTime = currentTime;
    }

    check(batchOk, { 'SQS 배치 전송 성공': (ok) => ok === true });
    sleep(0.05);
}

// 3. [종료 단계] 전체 평균 실질 TPS 산정 — interval Trend 와 분리(Gauge + 콘솔)
export function teardown(setupData) {
    const testDurationSeconds = (Date.now() - setupData.startTime) / 1000;
    const totalActualInserts = readWriteCount() - setupData.startCount;
    const realRdsTPS = testDurationSeconds > 0 ? totalActualInserts / testDurationSeconds : 0;

    rdsOverallAvgTPS.add(realRdsTPS);
    console.log(`[최종] 누적 INSERT=${totalActualInserts}, 평균 실측 TPS=${realRdsTPS.toFixed(2)}`);

    // 모든 부하 종료 후 공유 커넥션 풀을 최종적으로 한 번만 닫는다.
    db.close();
}

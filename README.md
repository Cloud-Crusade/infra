# Infra (Terraform)

## 목차

- [Overview](#overview)
- [Architecture](#architecture)
- [모듈 구성 (Modules)](#모듈-구성-modules)
- [Directory Structure](#directory-structure)
- [Getting Started](#getting-started)
- [Convention](#convention)

## Overview

티켓팅 서비스 **C.C (Cloud Crusade)** 의 AWS 인프라를 Terraform으로 정의한 저장소입니다.

이 서비스의 목표는 **"티켓 오픈 순간 몰리는 폭발적인 트래픽(스파이크)을 인프라가 안정적으로 흡수"** 하는 것입니다. 인프라는 이를 위해 다음을 핵심으로 설계되었으며, 각 책임은 아래 **모듈 단위**로 분리되어 있습니다.

- **대기열(Queue)** — 한꺼번에 몰린 요청을 줄 세워 DB로 천천히 흘려보냄
- **자동 확장(Auto Scaling)** — 트래픽이 늘면 EKS 노드/파드가 스스로 증가
- **비동기 쓰기(Async Write)** — 예매·결제를 SQS 큐 → Lambda로 분리해 DB 과부하 방지
- **고가용성(HA)** — 멀티 AZ + ARC(Application Recovery Controller) Zonal Autoshift로 AZ 장애 시에도 서비스 유지
- **모니터링** — Prometheus / Grafana / CloudWatch로 상태를 실시간 관찰

> 모든 리소스는 코드(Terraform)로 관리하며, 콘솔에서 수동 생성하지 않습니다. 상태(state)는 S3 백엔드로 원격 관리합니다.

## Architecture

요청은 다음 흐름으로 처리됩니다. (괄호는 담당 모듈)

1. **정적 웹 진입** — 사용자 → CloudFront → S3 정적 호스팅의 React SPA `(frontend)`
2. **API 진입** — SPA → Route53 → API Gateway / NLB → EKS 백엔드(WAS) `(api · cluster)`
3. **대기열 발급** — 백엔드 → ElastiCache(Redis) 대기열, `ticketing` Lambda가 순번 발급 후 입장 토큰(JWT) 발급 `(data · async)`
4. **입장 검증** — API Gateway가 `authorizer` Lambda로 예약 토큰(S3 공개키 RS256) + 인증 토큰(Secrets Manager 대칭키 HS256)을 함께 검증 `(api · async · data)`
5. **예매·결제 적재** — 백엔드 → SQS FIFO → `persistence` Lambda가 leaky bucket으로 소비 → RDS Proxy 경유 → RDS 적재 `(async · data)`
6. **모니터링·운영** — metrics-server/Prometheus, CloudWatch Container Insights·알람, bastion의 Grafana, test_ec2의 k6 부하 테스트 `(cluster · shared · ops)`
7. **고가용성** — 멀티 AZ + ARC Zonal Autoshift로 AZ 장애 시 트래픽 자동 이동 `(arc)`

---

## 모듈 구성 (Modules)

모듈은 `modules/` 아래에 **도메인/역할별 레이어**로 분리되어 있습니다. 각 레이어는 자체 `main.tf · variables.tf · outputs.tf`를 가지며, 필요한 하위 모듈을 조합합니다.

### `network` — 네트워크 기반

| 항목 | 내용 |
| --- | --- |
| 역할 | 전체 인프라가 올라갈 VPC 네트워크 토대 제공 |
| 하위 모듈 | `vpc/` |
| 주요 리소스 | VPC, public/private 서브넷, IGW(Internet Gateway), NAT Gateway, 라우팅 테이블 |
| 가용성 설계 | 서브넷을 Multi-AZ로 분산 배치해 EKS 노드·RDS 이중화의 토대 제공 |
| 보안 설계 | public/private 서브넷 분리, 외부 통신은 NAT 경유만 허용해 내부 리소스 노출 최소화 |
| 비고 | 서브넷·VPC ID를 출력해 cluster·data·api 등 다른 레이어가 참조 |

### `cluster` — 쿠버네티스(EKS) 클러스터·애드온

| 항목 | 내용 |
| --- | --- |
| 역할 | 백엔드(WAS) 워크로드가 동작하는 EKS(Elastic Kubernetes Service) 클러스터와 운영 애드온 구성 |
| 하위 모듈 | `eks/`, `aws_lb_controller/`, `cluster_autoscaler/`, `metrics_server/`, `prometheus/`, `workloads/` |
| 주요 리소스 | EKS 클러스터·노드그룹, IRSA(IAM Roles for Service Accounts) 역할, AWS LB Controller, Cluster Autoscaler, metrics-server(HPA용), Prometheus |
| 확장 전략 | Cloud Bursting — 평시 Scale-In으로 최소 노드만 유지(비용 절감), 예매 오픈 시 Auto Scaling으로 즉시 확장(버스트 대응). 비용과 가용성의 절충 |
| 특이사항 | 노드를 Multi-AZ로 분산해 한 AZ 장애에도 클러스터 유지. 모니터링은 비용 고정형 Prometheus 주력(`ops`·`shared` 참고) |

### `data` — 데이터 저장·캐시·비밀 (AZ 페일오버 · 데이터 계층 포함)

| 항목 | 내용 |
| --- | --- |
| 역할 | 영속 데이터·대기열 캐시·민감 정보 관리 + AZ 장애 시 DB 자동 승격 |
| 하위 모듈 | `rds/`, `rds_proxy/`, `elasticache/`, `secrets_manager/` (+ `db_roles.tf`) |
| 주요 리소스 | RDS Multi-AZ(스탠바이 복제본 + 자동 장애조치), RDS Proxy, ElastiCache Redis(대기열), Secrets Manager(JWT 키·DB 자격증명·writer 엔드포인트) |
| 캐시 선택 | 대기열을 SQS(약 226ms) 대신 Redis(9.66ms)로 채택 — 속도·실시간 순번·Atomic 중복 발급 방지 우위 (SQS의 무유실 장점보다 폭증 흡수·속도·순서를 우선) |
| DB 구성 | Reader/Writer 엔드포인트 분리로 읽기 부하 분산 + RDS Multi-AZ로 Primary 장애 시 다른 AZ 자동 승격(Failover) |
| RDS Proxy | 커넥션 풀링으로 DB 부하 분산, 장애 시 연결 유지로 재연결 약 1초, 앱은 Proxy 경유만 허용(접속 일원화·보안), 배포 단계 on/off 플래그로 비용 제어 |
| 흐름 | App → RDS Proxy → DB (Multi-AZ) |
| 특이사항 | 과접속 IP 블랙리스트를 ElastiCache로 관리(봇 차단), Lambda/WAS가 Secrets Manager에서 키·자격증명 주입 |

### `async` — 비동기 처리 파이프라인

| 항목 | 내용 |
| --- | --- |
| 역할 | 예매·결제 쓰기를 큐로 분리해 DB 유입 속도 제어 |
| 하위 모듈 | `sqs/`, `lambda/`, `eventbridge/` |
| 주요 리소스 | SQS(Simple Queue Service) FIFO 큐, Lambda 함수·레이어·이벤트 소스 매핑, EventBridge 트리거 |
| 트래픽 제어 | Leaky Bucket — WAS 확장에 비례해 DB 트래픽이 폭증·다운되는 문제를, 쓰기를 비동기 처리하고 약 100~200 TPS로 평탄화해 방지 |
| 특이사항 | `persistence` Lambda를 leaky bucket(batchSize/reserved concurrency)으로 운영, ElastiCache 캐싱으로 정합성·DB 가용성 확보 |

### `api` — 외부 API 진입점

| 항목 | 내용 |
| --- | --- |
| 역할 | 외부 요청을 받아 인증·라우팅 후 백엔드로 전달 |
| 하위 모듈 | `apigateway/`, `nlb/`, `route53/` |
| 주요 리소스 | API Gateway(REQUEST authorizer Lambda 연동), NLB(Network Load Balancer), Route53 DNS 레코드 |
| 진입점 선택 | ALB Ingress(Lambda 불가)·API Gateway+ALB(비용·L7 지연) → **API Gateway + NLB(L4)** L4 빠른 라우팅·연산 최소화·고가용성, gRPC는 DNS Resolver로 해결 |
| 특이사항 | WAF 규칙으로 봇·매크로 트래픽을 진입 단계에서 1차 필터링 |

### `frontend` — 정적 웹 배포·CDN

| 항목 | 내용 |
| --- | --- |
| 역할 | React SPA를 전 세계에 빠르게 배포 |
| 하위 모듈 | `cloudfront/`, `acm/` |
| 주요 리소스 | CloudFront 배포(OAC, Origin Access Control), ACM(AWS Certificate Manager) 인증서(HTTPS) |
| 보안 설계 | OAC로 S3 직접 접근 차단(CloudFront 경유만 허용), HTTPS 강제 리다이렉트, JWT 검증용 Public Key는 별도 퍼블릭 버킷으로 분리 |
| 특이사항 | 정적 자산을 CDN 캐싱해 응답 속도 향상 |

### `shared` — 공통 리소스

| 항목 | 내용 |
| --- | --- |
| 역할 | 여러 레이어가 공통으로 쓰는 모니터링·보안 리소스 |
| 하위 모듈 | `cloudwatch/`, `security_group/` |
| 주요 리소스 | CloudWatch 로그그룹·알람·대시보드·Container Insights, 공통 Security Group |
| 모니터링 역할 분담 | 주 모니터링은 Prometheus+Grafana(`ops` 참고)지만, EKS 노드·컨테이너 알람과 ARC 판단용 알람은 CloudWatch(Container Insights)로 병행 |
| 특이사항 | 보안 그룹을 공통 모듈로 묶어 레이어 간 접근 규칙을 일관 관리 |

### `ops` — 운영·테스트 인프라

| 항목 | 내용 |
| --- | --- |
| 역할 | 운영 도구와 부하 테스트 환경 제공 |
| 구성 | `bastion.tf`, `test_ec2.tf`, `compose/`, `scripts/`, `templates/` |
| 주요 리소스 | Bastion(Grafana docker compose 호스팅), test EC2(k6 부하 테스트), cAdvisor 컨테이너 메트릭 |
| 모니터링 선택 | CloudWatch는 수집 주기 단축·커스텀 지표·트래픽 급증 시 메트릭당 과금으로 비용 증가 → **Prometheus+Grafana** 인프라 고정비만 발생해 지표를 늘려도 추가 과금 없이 비용 예측 가능 |
| 특이사항 | bastion에서 Grafana 호스팅, k6(test EC2)로 SQS-Lambda-RDS 처리량 실측 검증 |

### `arc` — 가용성·장애 대응 (AZ 페일오버 · 트래픽 계층)

| 항목 | 내용 |
| --- | --- |
| 역할 | AZ 한 곳이 통째로 멈춰도 서비스 유지 — AZ 장애 시 트래픽을 자동으로 정상 AZ로 이동 |
| 구성 | NLB + ARC(Application Recovery Controller) Zonal Autoshift |
| 주요 리소스 | `aws_arczonalshift_zonal_autoshift_configuration` (대상: NLB ARN) |
| 감지 | NLB 비정상 호스트 합산 CloudWatch 알람 (`outcome_alarms`) |
| 안전 장치 | 오작동 시 정상 AZ까지 막을 위험이 있어 기본값 `DISABLED` → Practice Run(연습 실행) 검증 후 `ENABLED` (`zonal_autoshift_status`, `blocked_windows`/`blocked_dates`로 연습 시점 제어) |
| 흐름 | NLB → 장애 AZ 제외 → 정상 AZ |
| 비고 | AZ 페일오버의 데이터 계층은 `data` 모듈(RDS Multi-AZ + RDS Proxy)이 담당 |

---

## Directory Structure

```
infra/
├── modules/                  # 재사용 모듈 (도메인/역할별 레이어)
│   ├── network/   └─ vpc/
│   ├── cluster/   └─ eks/ · aws_lb_controller/ · cluster_autoscaler/ · metrics_server/ · prometheus/ · workloads/
│   ├── data/      └─ rds/ · rds_proxy/ · elasticache/ · secrets_manager/ · db_roles.tf
│   ├── async/     └─ sqs/ · lambda/ · eventbridge/
│   ├── api/       └─ apigateway/ · nlb/ · route53/
│   ├── frontend/  └─ cloudfront/ · acm/
│   ├── shared/    └─ cloudwatch/ · security_group/
│   ├── ops/       └─ bastion.tf · test_ec2.tf · compose/ · scripts/ · templates/
│   └── arc/          (ARC Zonal Autoshift)
│
└── environments/             # 환경별 실행 진입점
    ├── dev/                  # 개발 환경
    │   ├── backend.tf        # S3 원격 state 백엔드
    │   ├── main.tf           # 모듈 호출 진입점
    │   ├── variables.tf · outputs.tf
    │   ├── terraform.tfvars  # 환경별 변수 값 주입
    │   ├── data.tf · jwt_key.tf · cadvisor-setup.yaml
    │   └── compose/
    └── prod/                 # 운영 환경
```

각 환경(`dev`, `prod`)은 **독립적인 `main.tf` 진입점**을 가지며, 모듈은 직접 참조 대신 **`terraform.tfvars`로 값을 주입**합니다.

## Getting Started

### 사전 요구

- Terraform, AWS 자격 증명(`aws configure`)
- 코드 포맷팅: `terraform fmt`

### 실행 (dev 기준)

```bash
cd environments/dev

terraform init       # 백엔드(S3) 초기화 + 모듈/프로바이더 다운로드
terraform plan       # 변경 사항 미리보기
terraform apply      # 실제 적용
```

> 운영 환경은 `cd environments/prod`에서 동일하게 실행합니다.

### State 관리 (S3 백엔드)

원격 state는 S3 백엔드로 관리하며, dev/prod가 같은 버킷·락 테이블을 공유하고 `key` 경로로만 환경을 구분합니다.

| 항목 | dev | prod |
| --- | --- | --- |
| S3 버킷 | `tfstate-bucket-d8f5bb8d` | `tfstate-bucket-d8f5bb8d` |
| state 키 | `dev/terraform.tfstate` | `prod/terraform.tfstate` |
| 리전 | `ap-northeast-2` | `ap-northeast-2` |
| 잠금 테이블(DynamoDB) | `terraform-lock` | `terraform-lock` |
| 암호화 | `encrypt = true` | `encrypt = true` |

### 민감 파일 관리 (.gitignore)

아래 항목들은 로컬에만 두고 커밋하지 않습니다. (`.gitignore` 실제 내용 기준)

```gitignore
# Terraform 로컬 디렉토리·캐시
**/.terraform/*
.terraform/

# 상태 파일 (원격 backend 사용으로 로컬 보관 불필요)
*.tfstate
*.tfstate.*
*.tfstate.backup

# Plan 파일
*.tfplan
*.tfplan.json

# 민감 정보가 포함될 수 있는 파일
.terraform.lock.hcl
*.auto.tfvars
secrets.tfvars
*.pem
*.key

# 로컬 오버라이드 파일
override.tf
override.tf.json
*_override.tf
*_override.tf.json
```

> `terraform.tfvars`는 현재 ignore 대상이 아니므로, 민감 값을 직접 넣지 않도록 주의합니다. 민감 값은 `secrets.tfvars` 또는 `*.auto.tfvars`로 분리하세요.

## Convention

> 팀 내 협업의 효율 및 생산성을 위한 규약

### Github 컨벤션

**Issue**
- 형식: `[카테고리]: 이슈 제목`
- 카테고리: `FEATURE` / `REFACTOR` / `BUG` / `CHORE`

**Branch**
- 형식: `카테고리/#이슈번호/브랜치명`
- 카테고리: `feature` / `refactor` / `fix` / `chore`

**Commit**
- 형식: `[카테고리]: 커밋 내용`
- 카테고리: `FEAT` / `REFAC` / `FIX` / `CHORE`

**Pull Request**
- 형식: `[카테고리#이슈번호] PR 제목`
- 카테고리는 커밋과 동일

### Code 컨벤션

- 변수는 `snake_case`로 작성, 의미 없는 변수명(`data1` 등) 금지
- `terraform fmt`로 포맷팅

```hcl
resource "local_file" "ssh_key" {
  filename        = "${path.module}/lecture-key.pem"
  content         = tls_private_key.pk.private_key_pem
  file_permission = "0600"
}
```

### Architecture 원칙

- DDD(Domain-Driven Design, 도메인 주도 설계) 기반 모듈형 설계: `modules/`(공통 모듈, 레이어화) + `environments/`(dev·prod 실행 모듈)
- **단순함 우선** — 값이 없는 경우를 `for_each` 등 복잡한 조건으로 처리하지 않고 단순하게 작성
- **미연결 모듈 참조** — 빈 문자열(`""`) placeholder + 실제 참조는 주석으로 표기
- **민감 변수** — `sensitive = true` + `default = ""`로 CI plan 호환성 유지
- **모듈 연동** — 직접 참조 대신 `terraform.tfvars`로 값 주입
# Convention
팀 내 협업의 효율 및 생산성을 위한 규약

## Github 컨벤션

### Issue
**템플릿을 준수**
이슈 타이틀 형태: `[카테고리]: 이슈 제목`

카테고리
- Feature: 기능 추가, 기능 변경
- Refactor: 리팩토링, 구조 변경
- Bug: 발생한 버그 목록
- Chore: 의존성, 문서 작업 등 코드 외 작업 (별도의 의존성 작업만 추가할 경우)

EX
`[Feature] OAuth 2.0 추가`
`[Refactor] Ansible 모듈 리팩토링`

### Branch
브랜치 이름 형태: `카테고리/#이슈번호/브랜치명`

카테고리
- feature: 기능 추가, 기능 변경
- refactor: 리팩토링, 구조 변경
- fix: 버그 수정
- chore: 의존성, 문서 작업 등 코드 외 작업 (별도의 의존성 작업만 추가할 경우)

### Commit
커밋 메시지 형태: `[카테고리]: 커밋 내용`

카테고리
- FEAT: 기능 추가, 기능 변경
- REFAC: 리팩토링, 구조 변경
- FIX: 버그 수정, 오류 수정
- CHORE: 의존성 추가, 코드 외 작업

EX
`[FEAT]: OAuth2.0 추가 - Google, Naver Authentication`
`[CHORE]: pytest 의존성 추가`

### Pull Request
**템플릿을 준수**

제목 형태: `[카테고리#이슈번호] PR 제목`

카테고리
- FEAT: 기능 추가, 기능 변경
- REFAC: 리팩토링, 구조 변경
- FIX: 버그 수정, 오류 수정
- CHORE: 의존성 추가, 코드 외 작업
**카테고리는 커밋과 동일**

EX
`[FEAT#18] Google, Naver OAuth 2.0 추가`

## Code 컨벤션

### Naming

**Variable**
변수는 snake_case로 작성

기본 작성 규칙
- 각 변수는 사용처, 알고리즘, 아키텍처에 맞는 명칭 사용
- 의미 없는 변수 (ex: data1, document 등) 사용 금지
- terraform fmt를 사용하여 포맷팅

EX
```terraform

resource "local_file" "ssh_key" {
  filename        = "${path.module}/lecture-key.pem"
  content         = tls_private_key.pk.private_key_pem
  file_permission = "0600" 
}

```

### Architecture
기본은 DDD 아키텍처에 기반한 설계
모듈형으로 설계

아키텍처 일반화
- modules/ : 공통 모듈 (ex: alb/, eks/, rds/ 등)
- exec/ : 실행 모듈

EX
```
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   └── variables.tf
│   └── eks/
│       ├── main.tf
│       └── variables.tf
│
└── environments/
    ├── dev/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── terraform.tfvars
    │
    └── prod/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── terraform.tfvars
```

> 각 환경(`dev`, `prod`)은 독립적인 `main.tf` 진입점을 가지며, 환경별로 분리되어 실행된다.


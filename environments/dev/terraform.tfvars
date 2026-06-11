aws_region   = "ap-northeast-2"
environment  = "dev"
project_name = "cc"

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
availability_zones   = ["ap-northeast-2a", "ap-northeast-2c"]

bastion_instance_type = "t3.micro"
bastion_key_name      = "bastion-key"

allowed_ssh_cidrs = ["0.0.0.0/0"]

oidc_provider_arn = ""
oidc_provider_url = ""

db_username = "ccadmin"
# db_password 는 민감값 → tfvars 평문 금지.
# CI: GitHub Secret 이름을 DB_PASSWORD 로 (컨버터가 TF_VAR_ 접두사 + 소문자화 → TF_VAR_db_password)
# 로컬: export TF_VAR_db_password=...

public_bucket             = "einsof-service-625368338405-ap-northeast-2-an"
public_bucket_domain_name = "einsof-service-625368338405-ap-northeast-2-an.s3.ap-northeast-2.amazonaws.com"

# ===== Route53 / 도메인 =====
# domain_name·route53_zone_id 는 tfvars 에 적지 않는다 — tfvars 값이 TF_VAR_ 환경변수보다
# 우선해 덮어쓰기 때문(빈 문자열도 우선). 환경별 값이므로 TF_VAR_ 로만 주입한다.
# CI: GitHub Secret/Variable 이름을 DOMAIN_NAME / ROUTE53_ZONE_ID 로
#     (컨버터가 TF_VAR_ 접두사 + 소문자화 → TF_VAR_domain_name / TF_VAR_route53_zone_id)
# 로컬: export TF_VAR_domain_name=... TF_VAR_route53_zone_id=...
# api 레코드는 API Gateway 커스텀 도메인(apigateway 모듈, REGIONAL)에 자동 연결 — 별도 대상 입력 불필요
# cloudfront_zone_id 는 기본값(전역 CloudFront) 사용
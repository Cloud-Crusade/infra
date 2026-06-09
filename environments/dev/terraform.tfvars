aws_region   = "ap-northeast-2"
environment  = "dev"
project_name = "cc"

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
availability_zones   = ["ap-northeast-2a", "ap-northeast-2c"]

bastion_ami           = "ami-0a10b2721688ce9d2" # KT Cloud AMI ID
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
# 실제 도메인과 기존 hosted zone ID 로 교체하세요.
domain_name     = "einsof.app"
route53_zone_id = "" # TODO: 기존 호스팅 영역 ID (예: Z0123456789ABCDEFGHIJ)
# api 레코드가 가리킬 트래픽 라우팅 대상(서버) DNS. EKS ingress 로 생성된 ALB DNS 등으로 교체.
api_target_dns_name = "" # TODO: 예) k8s-...elb.ap-northeast-2.amazonaws.com
# api_target_zone_id / cloudfront_zone_id 는 기본값(서울 ALB / 전역 CloudFront) 사용
AWS_REGION   = "ap-northeast-2"
ENVIRONMENT  = "dev"
PROJECT_NAME = "cc"

VPC_CIDR             = "10.0.0.0/16"
PUBLIC_SUBNET_CIDRS  = ["10.0.1.0/24", "10.0.2.0/24"]
PRIVATE_SUBNET_CIDRS = ["10.0.11.0/24", "10.0.12.0/24"]
AVAILABILITY_ZONES   = ["ap-northeast-2a", "ap-northeast-2c"]

BASTION_AMI           = "ami-0a10b2721688ce9d2" # KT Cloud AMI ID
BASTION_INSTANCE_TYPE = "t3.micro"
BASTION_KEY_NAME      = "bastion-key"

ALLOWED_SSH_CIDRS = ["0.0.0.0/0"]

OIDC_PROVIDER_ARN = ""
OIDC_PROVIDER_URL = ""

DB_USERNAME = "ccadmin"
# DB_PASSWORD 는 민감값 → tfvars 평문 금지. TF_VAR_DB_PASSWORD 로 주입
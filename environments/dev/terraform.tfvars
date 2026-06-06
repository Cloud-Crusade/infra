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
# db_password 는 민감값 → tfvars 평문 금지. TF_VAR_db_password 로 주입
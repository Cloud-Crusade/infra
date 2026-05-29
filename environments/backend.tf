terraform {
  backend "s3" {
    bucket         = "ktcloud-cc-infra-terraform-state"
    key            = "terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "ktcloud-cc-infra-terraform-lock"
  }
}

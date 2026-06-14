
terraform {
  backend "s3" {
    bucket         = "tfstate-bucket-d8f5bb8d"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}

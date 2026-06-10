# 호출 측에서 provider 를 명시 주입(providers = { aws = aws.us_east_1 })하므로
# 자식 모듈에서 provider 출처를 선언해야 한다.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

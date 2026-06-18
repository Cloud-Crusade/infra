terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      # acm_www(CloudFront 인증서)는 us-east-1 전용 → env 에서 aliased provider 주입
      configuration_aliases = [aws.us_east_1]
    }
  }
}

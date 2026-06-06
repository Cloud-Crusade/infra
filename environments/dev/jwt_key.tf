# JWT RS256 키 페어 (terraform 생성) — authorization / reservation 각각
# - 개인키: secrets_manager 모듈 입력으로 전달 → Secrets Manager 저장
# - 공개키: S3(terraform backend 와 동일 버킷 재사용)에 저장 → 검증 측이 가져감
locals {
  public_key_bucket = "tfstate-bucket-d8f5bb8d" # backend.tf 의 state 버킷 재사용
}

resource "tls_private_key" "authorization" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_private_key" "reservation" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_s3_object" "authorization_public_key" {
  bucket       = local.public_key_bucket
  key          = "jwt/${var.environment}/authorization/public_key.pem"
  content      = tls_private_key.authorization.public_key_pem
  content_type = "application/x-pem-file"
}

resource "aws_s3_object" "reservation_public_key" {
  bucket       = local.public_key_bucket
  key          = "jwt/${var.environment}/reservation/public_key.pem"
  content      = tls_private_key.reservation.public_key_pem
  content_type = "application/x-pem-file"
}

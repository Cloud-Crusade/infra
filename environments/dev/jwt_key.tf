# JWT RS256 키 페어 (terraform 생성) — authorization / reservation 각각
# - 개인키: secrets_manager 모듈 입력으로 전달 → Secrets Manager 저장
# - 공개키: public S3 버킷(정적 호스팅·공개 리소스 공유용, state 버킷과 분리)에 저장 → 검증 측이 가져감. 버킷명은 변수 주입
resource "tls_private_key" "authorization" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_private_key" "reservation" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_s3_object" "authorization_public_key" {
  bucket       = var.public_bucket
  key          = "jwt/${var.environment}/authorization/public_key.pem"
  content      = tls_private_key.authorization.public_key_pem
  content_type = "application/x-pem-file"
}

resource "aws_s3_object" "reservation_public_key" {
  bucket       = var.public_bucket
  key          = "jwt/${var.environment}/reservation/public_key.pem"
  content      = tls_private_key.reservation.public_key_pem
  content_type = "application/x-pem-file"
}

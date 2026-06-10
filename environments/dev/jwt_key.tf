# JWT 서명키 (terraform 생성)
# - authorization: HS256 대칭 시크릿 (공개키 없음, app/검증측이 동일 시크릿 공유)
# - reservation:   RS256 키페어 (공개키는 public S3 버킷 → 검증측이 가져감)
resource "random_password" "authorization" {
  length  = 64
  special = false
}

resource "tls_private_key" "reservation" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_s3_object" "reservation_public_key" {
  bucket       = var.public_bucket
  key          = "jwt/${var.environment}/reservation/public_key.pem"
  content      = tls_private_key.reservation.public_key_pem
  content_type = "application/x-pem-file"
}

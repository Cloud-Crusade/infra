# ==============================
# Origin Access Control 정의
# ==============================

# S3 버킷 접근을 위한 Origin Access Control
# CloudFront만 S3에 접근할 수 있도록 제한
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.environment}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ==============================
# CloudFront 배포 정의
# ==============================

# CloudFront 배포
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  comment             = "${var.environment} CloudFront distribution"
  default_root_object = "index.html"

  # S3 오리진 설정
  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_id                = "S3-${var.s3_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  # 기본 캐시 동작 설정
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.s3_bucket_name}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # 접근 제한 없음 (전체 공개)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # 커스텀 도메인 별칭 (acm_certificate_arn 과 함께 사용)
  aliases = var.aliases

  # SSL 인증서 — acm_certificate_arn 제공 시 커스텀 도메인(ACM, sni-only), 아니면 CloudFront 기본 인증서
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == "" ? true : null
    acm_certificate_arn            = var.acm_certificate_arn == "" ? null : var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn == "" ? null : "sni-only"
    minimum_protocol_version       = var.acm_certificate_arn == "" ? "TLSv1" : "TLSv1.2_2021"
  }

  tags = {
    Name = "${var.environment}-cloudfront"
  }
}

# ==============================
# S3 버킷 정책 (OAC 접근 허용)
# ==============================

# CloudFront(OAC) 가 퍼블릭 버킷 객체(예: 공개키)를 읽을 수 있도록 허용.
# 이 정책이 없으면 OAC 가 있어도 S3 가 AccessDenied 를 반환한다.
resource "aws_s3_bucket_policy" "cloudfront_oac" {
  bucket = var.s3_bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontOACReadOnly"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::${var.s3_bucket_name}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}

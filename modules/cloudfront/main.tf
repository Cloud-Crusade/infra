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

  # SSL 인증서 설정 (CloudFront 기본 인증서 사용)
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.environment}-cloudfront"
  }
}

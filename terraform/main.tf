data "aws_caller_identity" "current" {}

data "aws_route53_zone" "registered" {
  name = "chasedickinson.com."
}

data "aws_iam_policy_document" "cloudfront_access" {
  statement {
    sid = "CloudFrontOriginAccess"

    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.web_origin.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.this.iam_arn]
    }
  }
}

locals {
  primary_origin = "primary-origin"
  web_domain     = substr(data.aws_route53_zone.registered.name, 0, length(data.aws_route53_zone.registered.name) - 1)
}

resource "aws_s3_bucket" "web_origin" {
  bucket = "${data.aws_caller_identity.current.account_id}-web-origin"
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.web_origin.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = aws_s3_bucket.web_origin.id
  policy = data.aws_iam_policy_document.cloudfront_access.json
}

resource "aws_acm_certificate" "this" {
  domain_name       = local.web_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  name    = aws_acm_certificate.this.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.this.domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.registered.id
  records = [aws_acm_certificate.this.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}

resource "aws_cloudfront_origin_access_identity" "this" {
  comment = "Identity utilized by CloudFront to retrieve objects from S3 bucket."
}

resource "aws_cloudfront_distribution" "this" {
  origin {
    domain_name = aws_s3_bucket.web_origin.bucket_regional_domain_name
    origin_id   = local.primary_origin

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN used to distribute website."
  default_root_object = "index.html"

  aliases = [local.web_domain]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.primary_origin

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 60 * 60 * 1
    max_ttl                = 60 * 60 * 24 * 1
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.this.arn
    minimum_protocol_version = "TLSv1.2_2018"
    ssl_support_method       = "sni-only"
  }
}

resource "aws_route53_record" "website" {
  zone_id = data.aws_route53_zone.registered.zone_id
  name    = local.web_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

//TODO
//  - Web content
//  - GitHub Actions

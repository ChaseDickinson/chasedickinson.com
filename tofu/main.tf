data "aws_caller_identity" "current" {}

data "aws_route53_zone" "registered" {
  name = "chasedickinson.com."
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
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

  # Added before the distribution switches to origin access control, so the policy already
  # allows the new path when the switch happens. The identity statement above goes in a later PR.
  statement {
    sid = "CloudFrontServiceOriginAccess"

    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.web_origin.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

locals {
  web_origin_bucket = "${data.aws_caller_identity.current.account_id}-web-origin"
  primary_origin    = "primary-origin"
  web_domain        = "chasedickinson.com"

  cert_validation_options = {
    for option in aws_acm_certificate.this.domain_validation_options : option.domain_name => option
  }
}

resource "aws_s3_bucket" "web_origin" {
  bucket = local.web_origin_bucket
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
  # Keyed by the domain, which is known up front, so the import block can target it.
  for_each = toset([local.web_domain])

  name    = local.cert_validation_options[each.key].resource_record_name
  type    = local.cert_validation_options[each.key].resource_record_type
  zone_id = data.aws_route53_zone.registered.id
  records = [local.cert_validation_options[each.key].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_cloudfront_origin_access_identity" "this" {
  comment = "Identity utilized by CloudFront to retrieve objects from S3 bucket."
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "web-origin"
  description                       = "Signs CloudFront's requests to the origin bucket."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# The site loads no scripts, so the policy allows none. Styles are inline, and the favicon is a
# data: URI. HSTS has no includeSubDomains or preload, so it can't affect other names.
resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "website-security-headers"
  comment = "Security headers for the site."

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 60 * 60 * 24 * 365
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    content_security_policy {
      content_security_policy = "default-src 'none'; img-src 'self' data:; style-src 'unsafe-inline'; font-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
      override                = true
    }
  }

  custom_headers_config {
    items {
      header   = "Cross-Origin-Opener-Policy"
      value    = "same-origin"
      override = true
    }

    items {
      header   = "Permissions-Policy"
      value    = "camera=(), microphone=(), geolocation=()"
      override = true
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  origin {
    domain_name              = aws_s3_bucket.web_origin.bucket_regional_domain_name
    origin_id                = local.primary_origin
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
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

    # Caches by the origin's Cache-Control header, between 1 second and 1 year: the page and
    # fonts send 60 seconds, and hashed images send a year. Query strings and cookies are not
    # part of the key. Compression is on.
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                   = true

    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.this.arn
    minimum_protocol_version = "TLSv1.2_2021"
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
//  - Second region
//  - Site logging
//  - Blog
//  - GitHub Actions

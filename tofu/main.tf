data "aws_caller_identity" "current" {}

data "aws_route53_zone" "registered" {
  name = "chasedickinson.com."
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_iam_policy_document" "cloudfront_access" {
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
  www_domain        = "www.chasedickinson.com"

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

# Adding a name replaces the certificate. The new one is created first, and the distribution
# only switches to it through the validation resource below, once DNS validation finishes.
resource "aws_acm_certificate" "this" {
  domain_name               = local.web_domain
  subject_alternative_names = [local.www_domain]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  # Keyed by the domain, which is known up front.
  for_each = toset([local.web_domain, local.www_domain])

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

# Sends www to the apex and keeps the path and query. It runs on every request, since a
# distribution can't attach a function to one host, and it passes apex requests through.
resource "aws_cloudfront_function" "redirect_www" {
  name    = "redirect-www-to-apex"
  runtime = "cloudfront-js-2.0"
  comment = "Redirects ${local.www_domain} to ${local.web_domain}."
  publish = true

  code = <<-EOT
    function handler(event) {
      var request = event.request;
      var host = request.headers.host ? request.headers.host.value : "";

      if (host !== "${local.www_domain}") {
        return request;
      }

      var params = [];
      var query = request.querystring;
      for (var name in query) {
        if (query[name].multiValue) {
          query[name].multiValue.forEach(function (item) {
            params.push(name + "=" + item.value);
          });
        } else {
          params.push(name + "=" + query[name].value);
        }
      }

      var location = "https://${local.web_domain}" + request.uri;
      if (params.length > 0) {
        location += "?" + params.join("&");
      }

      return {
        statusCode: 301,
        statusDescription: "Moved Permanently",
        headers: { location: { value: location } }
      };
    }
  EOT
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

  aliases = [local.web_domain, local.www_domain]

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

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect_www.arn
    }
  }

  # The bucket has no ListBucket grant for CloudFront, so S3 answers a missing key with 403.
  # Both codes show the 404 page. The short TTL keeps a page added later from staying "missing".
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 10
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # The validated certificate, so the distribution never switches to one DNS hasn't confirmed.
    acm_certificate_arn      = aws_acm_certificate_validation.this.certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}

# Every name gets an A and an AAAA record, since the distribution has IPv6 on.
resource "aws_route53_record" "alias" {
  for_each = {
    for pair in setproduct([local.web_domain, local.www_domain], ["A", "AAAA"]) :
    "${pair[0]} ${pair[1]}" => { name = pair[0], type = pair[1] }
  }

  zone_id = data.aws_route53_zone.registered.zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

moved {
  from = aws_route53_record.website
  to   = aws_route53_record.alias["chasedickinson.com A"]
}

moved {
  from = aws_route53_record.website_ipv6
  to   = aws_route53_record.alias["chasedickinson.com AAAA"]
}

moved {
  from = aws_route53_record.www["A"]
  to   = aws_route53_record.alias["www.chasedickinson.com A"]
}

moved {
  from = aws_route53_record.www["AAAA"]
  to   = aws_route53_record.alias["www.chasedickinson.com AAAA"]
}

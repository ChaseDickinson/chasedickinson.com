data "aws_caller_identity" "current" {}

data "aws_route53_zone" "registered" {
  name = "chasedickinson.com."
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

resource "aws_acm_certificate" "this" {
  domain_name       = substr(data.aws_route53_zone.registered.name, 0, length(data.aws_route53_zone.registered.name)-1)
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

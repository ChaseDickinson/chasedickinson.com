# Adopts the resources that were created before this config ran under OpenTofu.
# Once a merge has applied them, this file can be deleted.

data "aws_acm_certificate" "existing" {
  domain      = local.web_domain
  statuses    = ["ISSUED"]
  most_recent = true
}

import {
  to = aws_s3_bucket.web_origin
  id = local.web_origin_bucket
}

import {
  to = aws_s3_bucket_public_access_block.this
  id = local.web_origin_bucket
}

import {
  to = aws_s3_bucket_policy.cloudfront_access
  id = local.web_origin_bucket
}

import {
  to = aws_acm_certificate.this
  id = data.aws_acm_certificate.existing.arn
}

import {
  to = aws_route53_record.cert_validation["chasedickinson.com"]
  id = "${data.aws_route53_zone.registered.zone_id}__224cad3889341ebcb12fa72af56b2773.chasedickinson.com_CNAME"
}

import {
  to = aws_cloudfront_origin_access_identity.this
  id = "E1CVPRJ2G19X9P"
}

import {
  to = aws_cloudfront_distribution.this
  id = "E106P28OEOHY1M"
}

import {
  to = aws_route53_record.website
  id = "${data.aws_route53_zone.registered.zone_id}_${local.web_domain}_A"
}

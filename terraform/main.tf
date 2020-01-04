locals {
  org_name       = var.org_name
  workspace_name = var.workspace_name
}

data "aws_caller_identity" "current" {}

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

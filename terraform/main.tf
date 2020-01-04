locals {
  org_name       = var.org_name
  workspace_name = var.workspace_name
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "web_origin" {
  bucket = "${data.aws_caller_identity.current.account_id}-web-origin"
  acl    = "private"
}

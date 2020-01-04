data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "web_origin" {
  bucket = "${data.aws_caller_identity.current}-web-origin"
  acl    = "private"
}

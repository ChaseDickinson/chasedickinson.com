terraform {
  required_version = "= 0.12.18"

  backend "remote" {
    hostname     = "app.terraform.io"
  }
}

provider "aws" {
  version = "=2.43"
  region = "us-east-1"
}
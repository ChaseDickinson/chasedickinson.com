terraform {
  required_version = "= 0.12.18"
  required_providers {
    aws = "=2.43"
  }

  backend "remote" {
    hostname = "app.terraform.io"
  }
}

provider "aws" {
  region = "us-east-1"
}

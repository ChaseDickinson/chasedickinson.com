terraform {
  required_version = "= 0.12.18"

  backend "remote" {
    hostname = "app.terraform.io"
    workspaces {
      prefix = "website-"
    }
  }
}

provider "aws" {
  version = "=2.43"
  region  = "us-east-1"
}
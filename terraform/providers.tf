terraform {
  required_version = "= 0.12.18"

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = local.org_name

    workspaces {
      name = local.workspace_name
    }
  }
}

provider "aws" {
  version = "=2.43"

  region = "us-east-1"
}
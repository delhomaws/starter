terraform {
  backend "s3" {
    key = "toolchain"
  }

  required_version = ">= 1.0.0"
  required_providers {
    aws = ">= 3.60.0"
  }

}

provider "aws" {}

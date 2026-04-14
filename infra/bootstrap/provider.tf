terraform {
  required_version = ">= 1.6.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.26.0"
    }
  }

  # Local backend — bootstrap must run before the S3 bucket exists.
  # State for this root is stored locally and should be committed or
  # kept safe. Do NOT switch to S3 backend here.
  backend "local" {}
}

provider "aws" {
  region = "eu-west-2"
}

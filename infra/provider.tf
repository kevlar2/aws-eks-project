terraform {
  required_version = ">= 1.6.5"


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.26.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }




  backend "s3" {
    bucket       = "2048-eks-project-dev-ko-tf-state"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true #important for state locking to prevent corruption of state file
    # key is passed at init time via -backend-config="key=<env>/terraform.tfstate"
  }
}


provider "aws" {
  region = var.aws_region

}
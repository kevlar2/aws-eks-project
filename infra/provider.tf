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
    key          = "2048/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true #important for state locking to prevent corruption of state file

  }
}


provider "aws" {
  region = "eu-west-2"

}
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "s3_backend" {
  source          = "../modules/s3-backend"
  bucket_name     = var.state_bucket_name
  lock_table_name = var.lock_table_name
  tags            = var.tags
}
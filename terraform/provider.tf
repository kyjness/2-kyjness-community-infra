terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 기본 리전 (서울)
provider "aws" {
  region = var.region
}

# CloudFront 인증서용 리전 (미국 버지니아)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    docker = {
      source = "kreuzwerker/docker"
      version = "3.6.2"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Project = "gcp-wif-for-aws-ecs-tasks"
    }
  }
  region = var.aws_region
}
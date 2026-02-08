terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"   # latest stable 2.x series
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

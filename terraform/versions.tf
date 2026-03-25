terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend is configured via -backend-config flag per environment.
  # See terraform/environments/dev/backend.hcl for dev values.
  backend "s3" {}
}

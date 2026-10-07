terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }

  # Remote state in an S3 bucket on the local emulator. Connection details are in
  # backend.local.hcl (terraform init -backend-config=backend.local.hcl).
  backend "s3" {}
}

provider "aws" {
  region     = "us-east-1"
  access_key = "test" # the emulator accepts anything; there is no AWS account behind this
  secret_key = "test"

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  endpoints {
    s3 = var.s3_endpoint
  }
}

module "logs" {
  source = "../modules/s3-bucket"

  name                = "demo-app-logs"
  environment         = "dev"
  owner               = "platform"
  expiration_days     = var.expiration_days
  block_public_access = var.block_public_access
  tags                = var.extra_tags
}

output "logs_bucket" {
  value = module.logs.bucket_id
}

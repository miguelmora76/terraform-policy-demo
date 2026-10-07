# Remote state on the local S3 emulator (moto). Fake credentials; no AWS account involved.
bucket                      = "tf-state"
key                         = "terraform-policy-demo/live.tfstate"
region                      = "us-east-1"
endpoints                   = { s3 = "http://127.0.0.1:5100" }
access_key                  = "test"
secret_key                  = "test"
use_path_style              = true
use_lockfile                = true # native S3 locking (no DynamoDB)
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_requesting_account_id  = true
skip_region_validation      = true

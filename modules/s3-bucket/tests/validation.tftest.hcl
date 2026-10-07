mock_provider "aws" {}

variables {
  name        = "demo-logs"
  environment = "dev"
  owner       = "platform"
}

run "rejects_uppercase_bucket_name" {
  command = plan
  variables { name = "Demo_Logs" }
  expect_failures = [var.name]
}

run "rejects_unknown_environment" {
  command = plan
  variables { environment = "production" }
  expect_failures = [var.environment]
}

run "rejects_blank_owner" {
  command = plan
  variables { owner = "  " }
  expect_failures = [var.owner]
}

run "rejects_zero_expiration" {
  command = plan
  variables { expiration_days = 0 }
  expect_failures = [var.expiration_days]
}

# Plan-only tests against a mocked AWS provider: no emulator and no credentials needed.
mock_provider "aws" {}

variables {
  name        = "demo-logs"
  environment = "dev"
  owner       = "platform"
}

run "secure_by_default" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "versioning should be on by default"
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.this.block_public_acls,
      aws_s3_bucket_public_access_block.this.block_public_policy,
      aws_s3_bucket_public_access_block.this.ignore_public_acls,
      aws_s3_bucket_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "all public access must be blocked by default"
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    error_message = "objects must be encrypted at rest"
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this) == 0
    error_message = "no lifecycle rule unless expiration_days is set"
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == false
    error_message = "force_destroy must be off by default"
  }
}

run "required_tags_win_over_caller_tags" {
  command = plan

  variables {
    tags = { Owner = "someone-else", CostCenter = "1234" }
  }

  assert {
    condition     = aws_s3_bucket.this.tags["Owner"] == "platform" && aws_s3_bucket.this.tags["Environment"] == "dev"
    error_message = "module-set tags must override caller tags"
  }

  assert {
    condition     = aws_s3_bucket.this.tags["CostCenter"] == "1234" && aws_s3_bucket.this.tags["ManagedBy"] == "terraform"
    error_message = "extra tags are kept and ManagedBy is set"
  }
}

run "expiration_adds_a_lifecycle_rule" {
  command = plan

  variables {
    expiration_days = 30
  }

  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.this[0].rule).expiration[0].days == 30
    error_message = "expiration_days should set the rule's days"
  }
}

run "module_version_is_semver_and_tagged" {
  command = plan

  assert {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", output.module_version))
    error_message = "module_version must be semver"
  }

  assert {
    condition     = aws_s3_bucket.this.tags["ModuleVersion"] == output.module_version
    error_message = "buckets must be tagged with the module version"
  }
}

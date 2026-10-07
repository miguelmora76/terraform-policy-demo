# Changelog

Semantic versioning. The version lives in `main.tf` (`local.module_version`), is written to each bucket's
`ModuleVersion` tag, and is released as a git tag `s3-bucket/vX.Y.Z`. Consumers pin it:

```hcl
source = "git::https://github.com/miguelmora76/terraform-policy-demo.git//modules/s3-bucket?ref=s3-bucket/v1.0.0"
```

- **Major**: a change that forces replacement of buckets or removes/renames an input or output.
- **Minor**: a new optional input or output, or a new default-off feature.
- **Patch**: fixes and docs that don't change the plan.

## 1.0.0

- Private, versioned, AES256-encrypted bucket with required `Environment` and `Owner` tags.
- Optional object expiration (`expiration_days`).
- Input validation for `name`, `environment`, `owner` and `expiration_days`.

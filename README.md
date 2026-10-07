# terraform-policy-demo

A sample **versioned Terraform module** (a secure S3 bucket), **OPA policies that run against the plan in CI**
(one change that passes, one that is blocked), **`terraform test`** for the module, and **remote state in an
S3 bucket on a local emulator**, so no cloud account is needed.

> **Honest scope:** this is a learning and portfolio project. There is **no real AWS account**: every "bucket"
> lives in a local S3 emulator ([moto](https://github.com/getmoto/moto)) that keeps its data in memory and
> forgets it on restart. It has no real users and makes no production claims. The emulator is not AWS, so
> behavior that depends on real IAM, KMS, replication or eventual consistency is not exercised.

## Contents

- [What it does](#what-it-does)
- [How it works](#how-it-works)
- [What this project demonstrates](#what-this-project-demonstrates)
- [Quick start](#quick-start)
- [The policies](#the-policies)
- [Module versioning](#module-versioning)
- [Project layout](#project-layout)
- [Known limits](#known-limits)

## What it does

`modules/s3-bucket` creates a private, versioned, encrypted bucket with required `Owner` and `Environment` tags.
`live/` uses it and stores its state remotely. CI then proposes two changes to that live configuration and runs
the policies on each plan:

| Change | What it does | Plan | Policy |
|---|---|---|---|
| **allowed** | adds a 30-day object expiry and a `CostCenter` tag | update bucket, create lifecycle rule | passes |
| **blocked** | sets `block_public_access = false` | update public access block | rejected by `S3-001` |

The module deliberately lets a caller turn the public access block off: a validation rule can't know the
organization's policy. The OPA check is the second layer that stops it before it is applied.

## How it works

```mermaid
flowchart LR
    pr[change to live/] --> plan[terraform plan]
    state[(remote state<br/>S3 emulator)] <--> plan
    plan --> json[terraform show -json]
    json --> opa{conftest + OPA policies}
    opa -->|allowed| ok[plan may be applied]
    opa -->|S3-001..005| no[blocked in CI]
```

The plan runs against a real baseline: CI first applies the baseline to the emulator (state written to
`s3://tf-state/...`), so the two plans show genuine in-place updates, not just creates.

## What this project demonstrates

- **A versioned module** with typed, validated inputs, secure defaults, outputs, a changelog and semver rules.
- **Policy-as-code on the plan**, not the source: OPA/Rego rules read `terraform show -json`, so they judge what
  Terraform is actually about to do, including changes made through a module.
- **Allowed and blocked paths both tested.** The CI script fails if the blocked change is *not* blocked, or is
  blocked by the wrong rule. The policies also have their own unit tests (`conftest verify`).
- **`terraform test`** for the module: secure defaults, tag precedence, optional lifecycle rule, input
  validation (`expect_failures`), run against a mocked provider so it needs no emulator.
- **Remote state with native S3 locking** (`use_lockfile`, no DynamoDB) against a local S3 emulator. A planted
  lock file made `terraform plan` fail with `PreconditionFailed`, so the emulator enforces the lock.

## Quick start

Needs [Terraform](https://developer.hashicorp.com/terraform) 1.10+ (tested on 1.16.4),
[conftest](https://www.conftest.dev) and [uv](https://docs.astral.sh/uv/).

```bash
uv sync
make ci              # fmt, validate, terraform test, OPA tests, version check, then the policy demo
```

Or one piece at a time:

```bash
make test-module     # terraform test (mocked provider)
make test-policy     # conftest verify: unit tests for the Rego rules
make policy-demo     # starts the emulator, applies the baseline, plans both changes, runs the policies
make clean           # stop the emulator, remove plan files
```

## The policies

`policy/s3.rego`, evaluated by `conftest test` against the plan JSON. Rules only judge resources the plan
changes; an untouched legacy bucket is not this change's problem.

| Rule | Denies |
|---|---|
| `S3-001` | any public access setting that is not `true` |
| `S3-002` | a changed bucket with no server-side encryption configured alongside it |
| `S3-003` | a changed bucket missing a non-blank `Owner` or `Environment` tag |
| `S3-004` | `force_destroy = true` on a bucket tagged `prod` |
| `S3-005` | destroying a bucket |

## Module versioning

`modules/s3-bucket` follows semver, documented in its [`CHANGELOG.md`](modules/s3-bucket/CHANGELOG.md). The
version is set once in `main.tf`, written to every bucket's `ModuleVersion` tag, and released as the git tag
`s3-bucket/vX.Y.Z`. CI fails if `main.tf` and the changelog disagree. Consumers pin a tag:

```hcl
source = "git::https://github.com/miguelmora76/terraform-policy-demo.git//modules/s3-bucket?ref=s3-bucket/v1.0.0"
```

`live/` uses a relative path so the demo changes and the module move together.

## Project layout

```
modules/s3-bucket/   main/variables/outputs/versions.tf, CHANGELOG.md, tests/*.tftest.hcl
live/                root config using the module; backend.local.hcl; changes/allowed.tfvars, blocked.tfvars
policy/              s3.rego and s3_test.rego
scripts/             emulator.sh, check_policy.sh, check_changelog.sh
.github/workflows/   ci.yml
```

## Known limits

- No real AWS account; a local emulator stands in, and the "remote" state is on localhost, in memory.
- The emulator doesn't evaluate IAM or KMS, and the module uses AES256 only (no customer-managed keys).
- Five small rules for one resource family. A real guardrail set would be broader and would load organization
  data (exemptions, allowed regions) instead of hard-coding.
- The S3-002 check matches an encryption resource to a bucket by module address, not by resource reference.
  It catches a bucket created with no encryption alongside it, not a mismatched pairing within one module.
- The blocked change is a plan only, never applied. There is no apply-on-merge pipeline, and no
  Terratest-style (Go) integration test; `terraform test` covers the module.
- Fake credentials (`test`/`test`) are committed on purpose; they only work against the emulator.

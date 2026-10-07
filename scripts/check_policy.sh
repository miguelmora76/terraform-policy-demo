#!/usr/bin/env bash
# 1. Apply the baseline to the emulator (state goes to the remote S3 backend).
# 2. Plan the ALLOWED change and the BLOCKED change against that state, convert each plan to JSON,
#    and run the OPA policies on it with conftest.
# Succeeds only if the allowed plan passes AND the blocked plan is rejected by the expected rule.
set -euo pipefail
cd "$(dirname "$0")/../live"
export AWS_EC2_METADATA_DISABLED=true

terraform init -input=false -reconfigure -backend-config=backend.local.hcl >/dev/null
terraform apply -input=false -auto-approve >/dev/null
echo "baseline applied (remote state: s3://tf-state/terraform-policy-demo/live.tfstate on the emulator)"

plan_json() { # $1 = name, $2 = tfvars
  terraform plan -input=false -var-file="$2" -out="$1.tfplan" >/dev/null
  terraform show -json "$1.tfplan" >"$1.plan.json"
}

echo; echo "== ALLOWED change (changes/allowed.tfvars)"
plan_json allowed changes/allowed.tfvars
conftest test allowed.plan.json -p ../policy --all-namespaces

echo; echo "== BLOCKED change (changes/blocked.tfvars)"
plan_json blocked changes/blocked.tfvars
set +e
out="$(conftest test blocked.plan.json -p ../policy --all-namespaces 2>&1)"
status=$?
set -e
echo "$out"
if [ "$status" -eq 0 ]; then echo "FAIL: the blocked change was not blocked" >&2; exit 1; fi
if ! grep -q "S3-001" <<<"$out"; then echo "FAIL: blocked, but not by the expected rule S3-001" >&2; exit 1; fi
echo; echo "OK: allowed change passed, blocked change was rejected by S3-001"

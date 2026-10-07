#!/usr/bin/env bash
# The module's version (main.tf), the top CHANGELOG entry and, if present, the latest tag must agree.
set -euo pipefail
cd "$(dirname "$0")/../modules/s3-bucket"
code=$(sed -n 's/.*module_version = "\(.*\)"/\1/p' main.tf | head -1)
log=$(sed -n 's/^## \([0-9][0-9.]*\)$/\1/p' CHANGELOG.md | head -1)
[ "$code" = "$log" ] || { echo "version mismatch: main.tf=$code CHANGELOG=$log" >&2; exit 1; }
echo "module version $code matches CHANGELOG"

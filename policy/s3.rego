# Guardrails for S3 changes, evaluated by conftest against `terraform show -json <plan>`.
# Rules only look at resources the plan changes (create/update/delete); untouched resources are ignored.
package main

import rego.v1

bucket_type := "aws_s3_bucket"

changing(rc) if {
	some action in rc.change.actions
	action in {"create", "update", "delete"}
}

changing_buckets contains rc if {
	some rc in input.resource_changes
	rc.type == bucket_type
	changing(rc)
}

# S3-001: public access must stay fully blocked.
deny contains msg if {
	some rc in input.resource_changes
	rc.type == "aws_s3_bucket_public_access_block"
	changing(rc)
	not "delete" in rc.change.actions
	some setting in ["block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"]
	rc.change.after[setting] != true
	msg := sprintf("S3-001: %s sets %s to %v; public access must stay fully blocked", [rc.address, setting, rc.change.after[setting]])
}

# S3-002: every bucket the plan changes must have server-side encryption configured alongside it.
deny contains msg if {
	some rc in changing_buckets
	not "delete" in rc.change.actions
	not encrypted_alongside(rc)
	msg := sprintf("S3-002: %s has no server-side encryption configuration", [rc.address])
}

encrypted_alongside(bucket) if {
	some rc in input.resource_changes
	rc.type == "aws_s3_bucket_server_side_encryption_configuration"
	object.get(rc, "module_address", "") == object.get(bucket, "module_address", "")
	not "delete" in rc.change.actions
	some rule in rc.change.after.rule
	some applied in rule.apply_server_side_encryption_by_default
	applied.sse_algorithm in {"AES256", "aws:kms"}
}

# S3-003: buckets need Owner and Environment tags.
deny contains msg if {
	some rc in changing_buckets
	not "delete" in rc.change.actions
	some tag in ["Owner", "Environment"]
	not nonblank(object.get(rc.change.after, "tags", {}), tag)
	msg := sprintf("S3-003: %s is missing the required tag %s", [rc.address, tag])
}

nonblank(tags, key) if {
	tags[key] != ""
}

# S3-004: a prod bucket must not allow force_destroy.
deny contains msg if {
	some rc in changing_buckets
	not "delete" in rc.change.actions
	object.get(rc.change.after, "tags", {}).Environment == "prod"
	rc.change.after.force_destroy == true
	msg := sprintf("S3-004: %s is tagged prod and sets force_destroy = true", [rc.address])
}

# S3-005: destroying a bucket needs a human decision, so it is never silent.
deny contains msg if {
	some rc in changing_buckets
	"delete" in rc.change.actions
	msg := sprintf("S3-005: %s would be destroyed; remove it from state or get an exemption instead", [rc.address])
}

package main

import rego.v1

bucket(after, actions) := {
	"address": "module.logs.aws_s3_bucket.this",
	"module_address": "module.logs",
	"type": "aws_s3_bucket",
	"change": {"actions": actions, "after": after},
}

good_after := {"tags": {"Owner": "platform", "Environment": "dev"}, "force_destroy": false}

sse := {
	"address": "module.logs.aws_s3_bucket_server_side_encryption_configuration.this",
	"module_address": "module.logs",
	"type": "aws_s3_bucket_server_side_encryption_configuration",
	"change": {"actions": ["no-op"], "after": {"rule": [{"apply_server_side_encryption_by_default": [{"sse_algorithm": "AES256"}]}]}},
}

pab(v) := {
	"address": "module.logs.aws_s3_bucket_public_access_block.this",
	"module_address": "module.logs",
	"type": "aws_s3_bucket_public_access_block",
	"change": {"actions": ["update"], "after": {
		"block_public_acls": v, "block_public_policy": v,
		"ignore_public_acls": v, "restrict_public_buckets": v,
	}},
}

compliant := [bucket(good_after, ["no-op"]), sse, pab(true)]

test_compliant_plan_is_allowed if {
	count(deny) == 0 with input as {"resource_changes": compliant}
}

test_public_access_block_off_is_denied if {
	msgs := deny with input as {"resource_changes": [bucket(good_after, ["no-op"]), sse, pab(false)]}
	some m in msgs
	startswith(m, "S3-001")
}

test_missing_encryption_is_denied if {
	msgs := deny with input as {"resource_changes": [bucket(good_after, ["create"]), pab(true)]}
	some m in msgs
	startswith(m, "S3-002")
}

test_encryption_in_another_module_does_not_count if {
	other := object.union(sse, {"module_address": "module.other"})
	msgs := deny with input as {"resource_changes": [bucket(good_after, ["create"]), other, pab(true)]}
	some m in msgs
	startswith(m, "S3-002")
}

test_missing_tag_is_denied if {
	after := {"tags": {"Environment": "dev"}, "force_destroy": false}
	msgs := deny with input as {"resource_changes": [bucket(after, ["create"]), sse, pab(true)]}
	some m in msgs
	startswith(m, "S3-003")
}

test_blank_tag_is_denied if {
	after := {"tags": {"Owner": "", "Environment": "dev"}, "force_destroy": false}
	msgs := deny with input as {"resource_changes": [bucket(after, ["create"]), sse, pab(true)]}
	some m in msgs
	startswith(m, "S3-003")
}

test_prod_force_destroy_is_denied if {
	after := {"tags": {"Owner": "platform", "Environment": "prod"}, "force_destroy": true}
	msgs := deny with input as {"resource_changes": [bucket(after, ["create"]), sse, pab(true)]}
	some m in msgs
	startswith(m, "S3-004")
}

test_dev_force_destroy_is_allowed if {
	after := {"tags": {"Owner": "platform", "Environment": "dev"}, "force_destroy": true}
	count(deny) == 0 with input as {"resource_changes": [bucket(after, ["create"]), sse, pab(true)]}
}

test_bucket_destroy_is_denied if {
	msgs := deny with input as {"resource_changes": [bucket(null, ["delete"]), sse, pab(true)]}
	some m in msgs
	startswith(m, "S3-005")
}

test_unchanged_noncompliant_bucket_is_ignored if {
	# Rules only judge what the plan changes; an untouched legacy bucket is not this PR's problem.
	legacy := bucket({"tags": {}, "force_destroy": true}, ["no-op"])
	count(deny) == 0 with input as {"resource_changes": [legacy]}
}

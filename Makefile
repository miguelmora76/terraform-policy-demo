.PHONY: emulator-up emulator-down fmt validate test-module test-policy check-version policy-demo ci clean
emulator-up:     ## local S3 emulator + remote-state bucket
	./scripts/emulator.sh start
emulator-down:
	./scripts/emulator.sh stop
fmt:             ## terraform fmt must be clean
	terraform fmt -check -recursive
validate:
	cd modules/s3-bucket && terraform init -backend=false -input=false >/dev/null && terraform validate
test-module:     ## terraform test (mocked provider; no emulator needed)
	cd modules/s3-bucket && terraform init -backend=false -input=false >/dev/null && terraform test
test-policy:     ## OPA unit tests for the policies
	conftest verify -p policy
check-version:
	./scripts/check_changelog.sh
policy-demo: emulator-up   ## baseline + allowed plan (passes) + blocked plan (rejected)
	./scripts/check_policy.sh
ci: fmt validate test-module test-policy check-version policy-demo
clean: emulator-down
	rm -rf live/.terraform live/*.tfplan live/*.plan.json

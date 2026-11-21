source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
f=tests/report.tftest.hcl
no_mocks
run_tests "$f"
run_has "$f" defaults 'command\s*=\s*plan' "must be plan only."
run_has "$f" defaults 'assert\s*\{' "needs an assert block."
run_has "$f" invalid_environment 'expect_failures\s*=\s*\[\s*var\.environment' "must expect the failure of var.environment."
run_has "$f" invalid_environment 'command\s*=\s*plan' "must be plan only."
run_has "$f" disallowed_instance_type 'expect_failures\s*=\s*\[\s*aws_instance\.report' "must expect the failure of aws_instance.report."
run_has "$f" disallowed_instance_type 'm5\.large' "must set instance_type = \"m5.large\"."
grep -qF '"vt-orders-config-test"' "$f" || fail "run \"apply_config\" must set bucket_name = \"vt-orders-config-test\"."
run_has "$f" apply_config 'orders_app' "must assert the username orders_app."
run_body "$f" apply_config | grep -qE 'command\s*=\s*plan' && fail "run \"apply_config\" must apply."
for r in defaults invalid_environment disallowed_instance_type apply_config; do run_passed "$r"; done
clean_test_bucket
pass "terraform test passes all four runs and cleans up."

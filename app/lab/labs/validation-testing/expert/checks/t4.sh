source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
f=tests/report.tftest.hcl
no_mocks
run_tests "$f"
run_has "$f" defaults 'command\s*=\s*plan' "must be plan only."
run_has "$f" open_cidr 'expect_failures\s*=\s*\[\s*var\.trusted_cidrs' "must expect the failure of var.trusted_cidrs."
run_has "$f" open_cidr '0\.0\.0\.0/0' "must set trusted_cidrs = [\"0.0.0.0/0\"]."
run_has "$f" arm_ami 'expect_failures\s*=\s*\[\s*data\.aws_ami\.report' "must expect the failure of data.aws_ami.report."
grep -qF '"vt-orders-config-test"' "$f" || fail "run \"apply_config\" must set bucket_name = \"vt-orders-config-test\"."
run_body "$f" apply_config | grep -qE 'command\s*=\s*plan' && fail "run \"apply_config\" must apply."
run_has "$f" stable 'run\.apply_config\.report_instance_id' "must compare with run.apply_config.report_instance_id."
run_has "$f" stable 'command\s*=\s*plan' "must be plan only."
order=$(grep -oE '^\s*run\s+"(apply_config|stable)"' "$f" | sed -E 's/.*"(.*)"/\1/' | xargs)
[ "$order" = "apply_config stable" ] || fail "run \"stable\" must come after run \"apply_config\"."
for r in defaults open_cidr arm_ami apply_config stable; do run_passed "$r"; done
clean_test_bucket
pass "terraform test passes all five runs and cleans up."

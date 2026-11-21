source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
f=tests/validation.tftest.hcl
no_mocks
run_tests "$f"
run_has "$f" valid 'assert\s*\{' "needs an assert block."
run_has "$f" invalid_cidr 'expect_failures\s*=\s*\[\s*var\.allowed_cidr' "must expect the failure of var.allowed_cidr."
run_has "$f" invalid_cidr '10\.20\.0\.300/16' "must set allowed_cidr = \"10.20.0.300/16\"."
for r in valid invalid_cidr; do run_passed "$r"; done
pass "terraform test passes both runs."

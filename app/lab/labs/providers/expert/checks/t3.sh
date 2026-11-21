source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_random_upgraded
[ "$(lock_version aws)" = 5.100.0 ] || fail "The lock file should still select aws 5.100.0."
grep -q '"~> 5.0"' <<< "$(awk '/hashicorp\/aws/,/^}/' .terraform.lock.hcl)" || fail "The lock file has no entry for aws."
pass "random is locked to 3.6.3, aws stays at 5.100.0, and random_integer.build kept its value."

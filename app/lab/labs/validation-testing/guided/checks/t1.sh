source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_invalid_var environment -var environment=qa
expect_invalid_var allowed_cidr -var allowed_cidr=10.20.0.300/16
expect_invalid_var allowed_cidr -var allowed_cidr=10.20.0.0
terraform plan -lock=false -input=false -refresh=false -no-color -var environment=stage > "$CHECK_TMP/ok.log" 2>&1 || fail "terraform plan -var environment=stage fails:"$'\n'"$(tail -n 12 "$CHECK_TMP/ok.log")"
pass "Invalid environment and CIDR values fail at plan time."

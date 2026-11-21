source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_invalid_var environment -var environment=qa
for b in Orders_Config ab orders-config-; do expect_invalid_var bucket_name -var "bucket_name=$b"; done
expect_invalid_var trusted_cidrs -var 'trusted_cidrs=["10.0.0.0/8","10.1.0.0"]'
expect_invalid_var trusted_cidrs -var 'trusted_cidrs=["10.0.0.0/8","10.1.0.300/16"]'
expect_invalid_var trusted_cidrs -var 'trusted_cidrs=["10.0.0.0/8","0.0.0.0/0"]'
expect_invalid_var trusted_cidrs -var 'trusted_cidrs=[]'
[ "$(block variable trusted_cidrs | grep -cE '^\s*validation\s*\{')" -ge 3 ] || fail "Use a separate validation block per rule of trusted_cidrs."
terraform plan -lock=false -input=false -refresh=false -no-color -var 'trusted_cidrs=["10.0.0.0/8"]' -var bucket_name=abc > "$CHECK_TMP/ok.log" 2>&1 || fail "A plan with valid values fails:"$'\n'"$(grep -A8 '^Error' "$CHECK_TMP/ok.log" | head -n 15)"
pass "environment, bucket_name and trusted_cidrs are validated."

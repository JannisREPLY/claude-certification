source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_invalid_var environment -var environment=qa
expect_invalid_var allowed_cidr -var allowed_cidr=10.20.0.0
expect_invalid_var allowed_cidr -var allowed_cidr=10.20.0.300/16
for b in Orders_Config ab orders-config- -orders-config "$(printf 'a%.0s' {1..64})"; do expect_invalid_var bucket_name -var "bucket_name=$b"; done
for b in abc vt-orders-config "$(printf 'a%.0s' {1..63})"; do
  terraform plan -lock=false -input=false -refresh=false -no-color -var "bucket_name=$b" -var environment=dev > "$CHECK_TMP/ok.log" 2>&1 || fail "terraform plan -var bucket_name=$b fails:"$'\n'"$(grep -A8 '^Error' "$CHECK_TMP/ok.log" | head -n 15)"
done
pass "environment, allowed_cidr and bucket_name are validated."

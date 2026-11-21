source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
sg=$(cat "$LAB_STATE/sg")
expect_tag ManagedBy terraform bucket:acme-reports-east bucket:acme-reports-west "sg:$sg"
tf_has 'default_tags' || fail "Use default_tags in the provider configurations."
expect_originals
expect_clean_plan
pass "Every resource carries ManagedBy = terraform and the plan is clean."

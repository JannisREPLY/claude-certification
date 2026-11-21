source "$LIB"
require_init
[ "$(state_attr aws_s3_bucket.shipping_manifests bucket)" = nw-bf-manifests ] || fail "aws_s3_bucket.shipping_manifests is not in state with the bucket nw-bf-manifests."
has_address aws_s3_bucket.manifests && fail "aws_s3_bucket.manifests is still in state."
aws s3api head-object --bucket nw-bf-manifests --key README.txt > /dev/null 2>&1 || fail "nw-bf-manifests was recreated or deleted."
aws s3api head-bucket --bucket nw-bf-legacy-exports 2> /dev/null || fail "The bucket nw-bf-legacy-exports was deleted."
[ "$(state_json | jq '[.. | objects | select(.type? == "aws_s3_bucket" and .values.bucket? == "nw-bf-legacy-exports")] | length')" = 0 ] || fail "nw-bf-legacy-exports is still managed in this state."
[ "$(config_json | jq '[.. | objects | select(.bucket?.constant_value? == "nw-bf-legacy-exports")] | length')" = 0 ] || fail "The configuration still declares nw-bf-legacy-exports."
expect_no_changes aws_s3_bucket.shipping_manifests
expect_nothing_destroyed
pass "nw-bf-manifests is renamed in state and nw-bf-legacy-exports is handed over."

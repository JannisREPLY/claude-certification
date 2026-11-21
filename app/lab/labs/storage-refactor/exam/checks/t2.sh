source "$LIB"
require_init
for b in nw-sto-manifests nw-sto-invoices nw-sto-archive; do
  has_address "module.storage.aws_s3_bucket.this[\"$b\"]" || fail "module.storage.aws_s3_bucket.this[\"$b\"] is not in state."
  has_address "module.storage.aws_s3_object.readme[\"$b\"]" || fail "module.storage.aws_s3_object.readme[\"$b\"] is not in state."
  [ "$(state_attr "module.storage.aws_s3_object.readme[\"$b\"]" bucket)" = "$b" ] || fail "module.storage.aws_s3_object.readme[\"$b\"] must be the README.txt of $b."
done
[ "$(grep -c '^module\.storage\.aws_s3_\(bucket\.this\|object\.readme\)\[' <<< "$(addresses)")" = 6 ] || fail "module.storage should manage exactly three buckets and three README objects."
config_json | jq -e '[.root_module.module_calls.storage.module.resources[]? | select(.address == "aws_s3_bucket.this" or .address == "aws_s3_object.readme") | select(.count_expression)] | length == 0' > /dev/null \
  || fail "aws_s3_bucket.this and aws_s3_object.readme must not use count."
pass "The buckets and README objects are keyed by bucket name."

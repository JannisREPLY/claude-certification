source "$LIB"
require_init
tags=$(aws s3api get-bucket-tagging --bucket orders-artifacts --query 'TagSet' --output json)
[ "$(echo "$tags" | jq -r '.[] | select(.Key=="Environment") | .Value')" = prod ] || fail "Environment of orders-artifacts is not prod in AWS."
[ "$(echo "$tags" | jq -r '.[] | select(.Key=="CostCenter") | .Value')" = cc-4711 ] || fail "The approved tag CostCenter is gone from orders-artifacts."
[ "$(state_attr aws_s3_bucket.artifacts tags | jq -r .CostCenter)" = cc-4711 ] || fail "CostCenter is not in the configuration of aws_s3_bucket.artifacts."
expect_no_changes aws_s3_bucket.artifacts
pass "orders-artifacts carries Environment = prod and CostCenter = cc-4711."

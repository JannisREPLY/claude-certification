source "$LIB"
require_init
tags=$(aws s3api get-bucket-tagging --bucket orders-artifacts --query 'TagSet' --output json)
[ "$(echo "$tags" | jq -r '.[] | select(.Key=="Environment") | .Value')" = prod ] || fail "Environment of orders-artifacts is not prod in AWS."
[ "$(echo "$tags" | jq -r '.[] | select(.Key=="CostCenter") | .Value')" = cc-4711 ] || fail "The approved tag CostCenter is gone from orders-artifacts."
[ "$(state_attr aws_s3_bucket.build_artifacts bucket)" = orders-artifacts ] || fail "aws_s3_bucket.build_artifacts is not in state."
has_address aws_s3_bucket.artifacts && fail "aws_s3_bucket.artifacts is still in state."
expect_no_changes aws_s3_bucket.build_artifacts
pass "The bucket is renamed in state and its tags are reconciled."

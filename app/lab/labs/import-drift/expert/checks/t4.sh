source "$LIB"
require_init
aws s3api head-bucket --bucket orders-reports 2> /dev/null || fail "The bucket orders-reports was deleted."
has_address aws_s3_bucket.reports && fail "aws_s3_bucket.reports is still in state."
[ -n "$(addresses)" ] || fail "The state is empty."
tf_has '"orders-reports"' && fail "The configuration of orders-reports is still there."
expect_clean_plan
pass "orders-reports is no longer managed here, still exists, and the plan is clean."

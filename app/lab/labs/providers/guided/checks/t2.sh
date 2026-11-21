source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_west_bucket aws_s3_bucket.replica
pass "acme-reports-west exists in us-west-2."

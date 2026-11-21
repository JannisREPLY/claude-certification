source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_west_bucket module.reports.aws_s3_bucket.replica
expect_module_aliases
pass "module.reports creates acme-reports-west in us-west-2 through the aliased provider."

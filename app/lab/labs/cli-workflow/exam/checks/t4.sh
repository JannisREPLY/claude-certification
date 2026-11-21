source "$LAB_DIR/helpers.sh"
expect_protected aws_s3_bucket.artifacts
check_output_synced
prod_plan
pass "The bucket is protected, artifacts_tags is current and the plan is clean."

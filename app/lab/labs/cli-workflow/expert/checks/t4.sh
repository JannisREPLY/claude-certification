source "$LAB_DIR/helpers.sh"
expect_protected aws_s3_bucket.artifacts 'aws_instance.web["a"]' 'aws_instance.web["b"]' 'aws_instance.web["c"]'
check_output_synced
prod_plan
pass 'The bucket and the web tier are protected, artifacts_tags is current and the plan is clean.'

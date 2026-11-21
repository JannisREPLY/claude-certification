source "$LAB_DIR/helpers.sh"
check_saved_plan
expect_web_env prod
pass "prod.tfplan was saved with prod.tfvars and applied."

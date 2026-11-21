source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_provider_auth aws.audit
expect_module_fixed
expect_deployers "arn:aws:sts::$ACCOUNT:assumed-role/terraform-audit/terraform-audit"
pass "module.audit creates the auditor roles as terraform-audit."

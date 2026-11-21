source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_module_fixed
expect_deployers "arn:aws:sts::$ACCOUNT:assumed-role/terraform-deploy/terraform"
pass "modules/audit inherits the root provider and the auditor roles exist."

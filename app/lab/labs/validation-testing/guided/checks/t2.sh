source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
check_sensitive_output db_config 'Orders-Db-2024!'
plan_hides 'Leak-Check-9876' -var db_password=Leak-Check-9876
pass "db_config is redacted but readable with -raw. Note: the password is still in plain text in terraform.tfstate."

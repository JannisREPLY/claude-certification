source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
grep -qF 'Orders-Db-2024!' <<< "$(s3_object)" || fail "config/db.json in vt-orders-config does not contain the password. Did you apply?"
check_sensitive_output db_config 'Orders-Db-2024!'
plan_hides 'Leak-Check-9876' -var db_password=Leak-Check-9876
pass "The password is hidden in plan and output, readable with -raw. It is still in plain text in terraform.tfstate."

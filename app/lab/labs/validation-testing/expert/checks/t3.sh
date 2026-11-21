source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
tf_has 'variable\s+"db_password"' && fail "var.db_password is still declared."
grep -qs db_password terraform.tfvars *.auto.tfvars && fail "The value of db_password is still set in a .tfvars file."
pw=$(state_attr random_password.db result)
[ -n "$pw" ] || fail "random_password.db is not in state. Did you apply?"
[[ $pw =~ ^[A-Za-z0-9]{24}$ ]] || fail "random_password.db must be 24 letters and digits."
[ "$(s3_object | jq -r .password)" = "$pw" ] || fail "config/db.json does not contain the generated password."
check_sensitive_output db_config "$pw"
check_sensitive_output debug_connection "$pw"
plan_hides "$pw" -var db_username=orders_ro
pass "The generated password is in config/db.json, hidden in plan and output, readable with -raw, and still in plain text in terraform.tfstate."

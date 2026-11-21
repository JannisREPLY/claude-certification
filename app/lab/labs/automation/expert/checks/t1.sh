source "$LAB_DIR/helpers.sh"
rv=$(grep -oE "required_version *= *\"[^\"]*\"" <<< "$(tf_files)" | sed -E "s/.*= *\"(.*)\"/\1/" | tr -d " ")
grep -qxE "~>1\.6(\.0)?|>=1\.6(\.[0-9]+)?,<2(\.0(\.0)?)?" <<< "$rv" || fail "required_version = \"$rv\" must accept Terraform 1.6.6 and later 1.x releases, but not 2.0."
check_script_basics
check_saved_plan_run
check_automation_mode
check_exit_codes
pass "ci.sh runs with Terraform 1.6.6 in automation mode, applies only the saved plan and handles every exit code."

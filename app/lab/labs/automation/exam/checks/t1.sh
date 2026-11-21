source "$LAB_DIR/helpers.sh"
check_script_basics
check_saved_plan_run
check_automation_mode
pass "ci.sh runs in automation mode without prompts and applies the saved plan ci.tfplan."

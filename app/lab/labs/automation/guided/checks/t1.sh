source "$LAB_DIR/helpers.sh"
check_script_basics
check_saved_plan_run
pass "ci.sh runs without prompts and applies the saved plan ci.tfplan."

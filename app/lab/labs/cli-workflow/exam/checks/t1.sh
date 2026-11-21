source "$LAB_DIR/helpers.sh"
check_lock_fix
check_saved_plan
expect_web_env prod
pass "The workspace works again and prod.tfplan was saved and applied."

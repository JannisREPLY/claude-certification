source "$LAB_DIR/helpers.sh"
check_state_kept
check_lock_wait
pass "State locking is enabled and ci.sh waits for a held lock."

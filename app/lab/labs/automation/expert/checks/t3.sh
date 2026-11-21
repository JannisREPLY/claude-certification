source "$LAB_DIR/helpers.sh"
held=$(aws dynamodb get-item --table-name payments-tf-locks --key "{\"LockID\":{\"S\":\"$LOCK_ID\"}}" --query Item.Info.S --output text 2> /dev/null || true)
grep -qF "$(cat "$LAB_STATE/stale-lock")" <<< "$held" && fail "The lock of the crashed nightly job is still held."
grep -q -- "-lock-timeout" <<< "$CI_SCRIPT" || fail "ci.sh must wait for locks with -lock-timeout."
check_state_kept
check_lock_wait
pass "The stale lock is released and ci.sh waits for locks of running jobs."

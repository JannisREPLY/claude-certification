source "$LIB"
[ -f ci.sh ] || fail "ci.sh is missing in the lab folder."

WS="$CHECK_TMP/ws"
LOCK_ID="payments-tfstate/payments/terraform.tfstate"
CI_SCRIPT=$(grep -v '^[[:space:]]*#' ci.sh)

new_version() { echo "$1.$(date +%s%N | cut -c1-12)"; }

run_ci() {
  local version=$1 start
  shift
  rm -rf "$WS"
  mkdir -p "$WS"
  tar -C . --exclude=.terraform --exclude='*.tfplan' --exclude='*.tfplan.json' --exclude='terraform.tfstate*' -cf - . | tar -C "$WS" -xf -
  start=$(date +%s)
  CI_RC=0
  (cd "$WS" && env -u TF_IN_AUTOMATION -u TF_INPUT BUILD_VERSION="$version" "$@" timeout 150 bash ci.sh < /dev/null > "$CHECK_TMP/ci.log" 2>&1) || CI_RC=$?
  CI_SECS=$(( $(date +%s) - start ))
  sed -i 's/\x1b\[[0-9;]*m//g' "$CHECK_TMP/ci.log"
  CI_LOG=$(cat "$CHECK_TMP/ci.log")
}

ci_tail() { tail -n 15 "$CHECK_TMP/ci.log"; }

expect_ci_ok() {
  [ "$CI_RC" = 0 ] || fail "BUILD_VERSION=$1 bash ci.sh exited with $CI_RC:"$'\n'"$(ci_tail)"
  grep -q "Enter a value" <<< "$CI_LOG" && fail "ci.sh waits for input:"$'\n'"$(ci_tail)"
  [ "$(released stable)" = "$1" ] || fail "After BUILD_VERSION=$1 bash ci.sh, stable/release.json shows version $(released stable)."
}

released() { aws s3 cp "s3://payments-releases/$1/release.json" - 2> /dev/null | jq -r '.version // empty' 2> /dev/null || true; }

check_script_basics() {
  local line
  grep -qE -- '(^|[[:space:]])-var[[:space:]=]' <<< "$CI_SCRIPT" && fail "ci.sh must not use -var; pass the version as TF_VAR_app_version."
  grep -q 'TF_VAR_app_version' <<< "$CI_SCRIPT" || fail "ci.sh must pass BUILD_VERSION through TF_VAR_app_version."
  if ! grep -qE 'TF_INPUT=("|'"'"')?(0|false)' <<< "$CI_SCRIPT"; then
    while read -r line; do
      [ -n "$line" ] || continue
      grep -q -- '-input=false' <<< "$line" || fail "This terraform command in ci.sh can prompt for input: $line"
    done <<< "$(grep -E '(^|[^A-Za-z_-])terraform +(init|plan|apply)' <<< "$CI_SCRIPT")"
  fi
  grep -qE 'terraform +apply[^|;&]*ci\.tfplan' <<< "$CI_SCRIPT" || fail "ci.sh must apply the saved plan file ci.tfplan."
  grep -q -- '-auto-approve' <<< "$CI_SCRIPT" && fail "ci.sh must apply the saved plan; -auto-approve is not needed."
  return 0
}

check_saved_plan_run() {
  local v
  v=$(new_version 1.1)
  run_ci "$v"
  expect_ci_ok "$v"
  [ -f "$WS/ci.tfplan" ] || fail "ci.sh did not save the plan to ci.tfplan."
  [ "$(cd "$WS" && terraform show -json -no-color ci.tfplan 2> /dev/null | jq -r '.variables.app_version.value')" = "$v" ] \
    || fail "ci.tfplan was not created with app_version = $v."
}

check_automation_mode() {
  grep -q 'TF_IN_AUTOMATION' <<< "$CI_SCRIPT" || fail "ci.sh must set TF_IN_AUTOMATION."
  grep -q 'run the following command to apply' <<< "$CI_LOG" && fail "Terraform still prints interactive next-step hints; export TF_IN_AUTOMATION."
  return 0
}

check_exit_codes() {
  local v
  grep -q -- '-detailed-exitcode' <<< "$CI_SCRIPT" || fail "ci.sh must use terraform plan -detailed-exitcode."
  v=$(new_version 1.2)
  run_ci "$v"
  expect_ci_ok "$v"
  run_ci "$v"
  [ "$CI_RC" = 0 ] || fail "With no changes, ci.sh exited with $CI_RC instead of 0:"$'\n'"$(ci_tail)"
  grep -qE 'Apply complete|Applying' <<< "$CI_LOG" && fail "With no changes, ci.sh still ran terraform apply."
  run_ci latest
  [ "$CI_RC" = 1 ] || fail "When terraform plan fails (BUILD_VERSION=latest), ci.sh must exit 1, not $CI_RC."
  grep -qE 'Apply complete|Applying' <<< "$CI_LOG" && fail "ci.sh ran terraform apply although terraform plan failed."
  [ "$(released stable)" = "$v" ] || fail "A failed run changed stable/release.json."
}

backend_attr() { jq -r --arg k "$1" '.backend.config[$k] // empty' .terraform/terraform.tfstate 2> /dev/null; }

check_state_kept() {
  [ "$(aws s3 cp "s3://payments-tfstate/payments/terraform.tfstate" - 2> /dev/null | jq -r .lineage)" = "$(cat "$LAB_STATE/lineage")" ] \
    || fail "The state at s3://payments-tfstate/payments/terraform.tfstate is gone or was replaced."
  [ "$(backend_attr bucket)" = payments-tfstate ] && [ "$(backend_attr key)" = payments/terraform.tfstate ] \
    || fail "The lab folder must still use s3://payments-tfstate/payments/terraform.tfstate. Run terraform init again."
  terraform state list -no-color > "$CHECK_TMP/list" 2>&1 || fail "terraform state list fails in the lab folder:"$'\n'"$(tail -n 8 "$CHECK_TMP/list")"
  grep -qx 'aws_s3_object.release' "$CHECK_TMP/list" || fail "aws_s3_object.release is missing from the state."
}

check_lock_wait() {
  local v info
  [ "$(backend_attr dynamodb_table)" = payments-tf-locks ] || fail "The backend of the lab folder does not use the lock table payments-tf-locks."
  info=$(jq -cn --arg p "$LOCK_ID" '{ID: "0d7e5a42-6c1b-4e8f-9a3d-5b2c1f0e4d97", Operation: "OperationTypeApply", Info: "", Who: "runner@ci-runner-04", Version: "1.6.6", Created: "2026-11-20T08:00:00Z", Path: $p}')
  aws dynamodb put-item --table-name payments-tf-locks --condition-expression 'attribute_not_exists(LockID)' \
    --item "$(jq -cn --arg id "$LOCK_ID" --arg info "$info" '{LockID: {S: $id}, Info: {S: $info}}')" 2> /dev/null \
    || fail "The state is already locked: $(aws dynamodb get-item --table-name payments-tf-locks --key "{\"LockID\":{\"S\":\"$LOCK_ID\"}}" --query 'Item.Info.S' --output text)"
  (sleep 20; aws dynamodb delete-item --table-name payments-tf-locks --key "{\"LockID\":{\"S\":\"$LOCK_ID\"}}") > /dev/null 2>&1 &
  v=$(new_version 1.3)
  run_ci "$v"
  wait
  [ "$CI_RC" = 0 ] || fail "While another job held the lock for 20 seconds, ci.sh exited with $CI_RC:"$'\n'"$(ci_tail)"
  [ "$CI_SECS" -ge 15 ] || fail "ci.sh finished in ${CI_SECS}s although another job held the lock for 20 seconds; is locking enabled for ci.sh?"
  expect_ci_ok "$v"
  grep -qE -- '-lock=false' <<< "$CI_SCRIPT" && fail "ci.sh must not disable locking."
  return 0
}

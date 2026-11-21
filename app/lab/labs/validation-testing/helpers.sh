plan_fails_with() {
  local what=$1 log="$CHECK_TMP/bad.log"; shift
  if terraform plan -lock=false -input=false -refresh=false -no-color "$@" > "$log" 2>&1; then
    fail "terraform plan $* succeeds, but should fail with '$what'."
  fi
  grep -qF "$what" "$log" || fail "terraform plan $* fails, but not with '$what':"$'\n'"$(grep -A8 '^Error' "$log" | head -n 20)"
}

expect_invalid_var() {
  local var=$1; shift
  plan_fails_with "Invalid value for variable" "$@"
  grep -qF "var.$var is" "$CHECK_TMP/bad.log" || fail "terraform plan $* fails, but not because of the validation of var.$var:"$'\n'"$(grep -A8 '^Error' "$CHECK_TMP/bad.log" | head -n 20)"
}

block() {
  python3 -I - "$@" <<'PY'
import glob, re, sys
kind, name = sys.argv[1], sys.argv[2]
files = sys.argv[3] if len(sys.argv) > 3 else "*.tf"
for f in sorted(glob.glob(files)):
    s = open(f).read()
    for m in re.finditer(r'(?m)^\s*' + re.escape(kind) + r'\s+"' + re.escape(name) + r'"\s*\{', s):
        depth, i = 0, m.end() - 1
        for j in range(i, len(s)):
            depth += {"{": 1, "}": -1}.get(s[j], 0)
            if depth == 0:
                print(s[i:j + 1])
                break
PY
}

run_names() { grep -ohE '^\s*run\s+"[^"]+"' $1 2> /dev/null | sed -E 's/.*"(.*)"/\1/'; }

run_tests() {
  local file=$1 out
  [ -f "$file" ] || fail "$file does not exist."
  out=$(terraform test -no-color 2>&1) || fail "terraform test fails:"$'\n'"$(tail -n 25 <<< "$out")"
  echo "$out" > "$CHECK_TMP/test.log"
  grep -qE '^Success! [0-9]+ passed, 0 failed' <<< "$out" || fail "terraform test did not succeed:"$'\n'"$(tail -n 15 <<< "$out")"
}

run_passed() { grep -qE "run \"$1\"\.\.\. pass" "$CHECK_TMP/test.log" || fail "run \"$1\" did not pass in terraform test."; }

run_body() { block run "$2" "$1"; }

run_has() {
  local file=$1 run=$2 pattern=$3 msg=$4 body
  body=$(run_body "$file" "$run")
  [ -n "$body" ] || fail "$file has no run \"$run\" block."
  grep -qE "$pattern" <<< "$body" || fail "run \"$run\": $msg"
}

check_sensitive_output() {
  local name=$1 secret=$2
  [ -n "$(state_attr aws_s3_object.db_config id)" ] || fail "aws_s3_object.db_config is not in state. Did you apply?"
  grep -qE "^$name = <sensitive>$" <<< "$(terraform output -no-color)" || fail "terraform output does not redact $name. Mark the output sensitive."
  grep -qF "$secret" <<< "$(terraform output -raw -no-color "$name")" || fail "terraform output -raw $name does not show the secret."
  jq -e --arg s "$secret" '.value | tostring | contains($s)' <<< "$(terraform output -json -no-color | jq '.["'"$name"'"]')" > /dev/null || fail "terraform output -json does not contain $name."
  grep -qF "$secret" terraform.tfstate || fail "The secret is not in terraform.tfstate. Did you apply?"
}

plan_hides() {
  local secret=$1; shift
  terraform plan -lock=false -input=false -no-color "$@" > "$CHECK_TMP/leak.log" 2>&1 || fail "terraform plan $* fails:"$'\n'"$(tail -n 15 "$CHECK_TMP/leak.log")"
  grep -qF "$secret" "$CHECK_TMP/leak.log" && fail "terraform plan prints the secret in clear text. Mark the variable sensitive."
  grep -qF "aws_s3_object.db_config will be updated" "$CHECK_TMP/leak.log" || fail "terraform plan with a new password does not update aws_s3_object.db_config."
}

s3_object() { aws s3api get-object --bucket vt-orders-config --key config/db.json "$CHECK_TMP/object.json" > /dev/null 2>&1 && cat "$CHECK_TMP/object.json"; }

clean_test_bucket() {
  aws s3api head-bucket --bucket vt-orders-config-test > /dev/null 2>&1 && fail "terraform test left the bucket vt-orders-config-test behind."
  return 0
}

error_text() { grep -vE '│|├|^\s*on .* line [0-9]+|^\s*[0-9]+:' "$CHECK_TMP/bad.log"; }

check_conditions() {
  plan_fails_with "Resource precondition failed" -var instance_type=m5.large
  grep -qF 'in resource "aws_instance" "report"' "$CHECK_TMP/bad.log" || fail "The precondition must be on aws_instance.report."
  [ -z "${1:-}" ] || grep -qF m5.large <<< "$(error_text)" || fail "The precondition error message does not mention the rejected type m5.large."
  plan_fails_with "Resource postcondition failed" -var 'ami_name_filter=amzn2-ami-hvm-*-arm64-gp2'
  grep -qF 'in data "aws_ami" "report"' "$CHECK_TMP/bad.log" || fail "The postcondition must be on data.aws_ami.report."
  [ -z "${1:-}" ] || grep -qF amzn2-ami-hvm-2.0 <<< "$(error_text)" || fail "The postcondition error message does not include the image name."
  block check deploy_account | grep -qE 'data\s+"aws_caller_identity"' || fail "check \"deploy_account\" has no scoped aws_caller_identity data source."
  terraform plan -lock=false -input=false -refresh=false -no-color -var expected_account_id=000000000000 > "$CHECK_TMP/acct.log" 2>&1 || fail "terraform plan -var expected_account_id=000000000000 fails; a check block should only warn:"$'\n'"$(tail -n 12 "$CHECK_TMP/acct.log")"
  grep -qF "Check block assertion failed" "$CHECK_TMP/acct.log" || fail "terraform plan -var expected_account_id=000000000000 shows no check warning."
  ensure_plan
  plan_json | jq -e '.checks[]? | select(.address.to_display == "check.deploy_account") | .status == "pass"' > /dev/null || fail "check.deploy_account does not pass with the correct account."
}

no_mocks() { grep -qsE 'mock_provider|override_' tests/*.tftest.hcl && fail "Do not use mock providers or overrides."; return 0; }

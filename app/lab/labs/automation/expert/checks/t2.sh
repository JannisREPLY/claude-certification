source "$LAB_DIR/helpers.sh"
grep -qE "backend +\"s3\" *\{ *\}" <<< "$(tf_files | tr "\n" " ")" || fail "The backend block in main.tf must be empty: backend \"s3\" {}."
[ -f prod.s3.tfbackend ] || fail "prod.s3.tfbackend is missing."
for kv in "bucket=\"payments-tfstate\"" "key=\"payments/terraform.tfstate\"" "region=\"us-east-1\"" "dynamodb_table=\"payments-tf-locks\"" "encrypt=true"; do
  grep -qxF "$kv" <<< "$(tr -d " \t" < prod.s3.tfbackend)" || fail "prod.s3.tfbackend must set ${kv%%=*} = ${kv#*=}."
done
grep -qE -- "-backend-config[= ]+(\./)?prod\.s3\.tfbackend" <<< "$CI_SCRIPT" || fail "ci.sh must initialize with -backend-config=prod.s3.tfbackend."
[ "$(backend_attr dynamodb_table)" = payments-tf-locks ] && [ "$(backend_attr encrypt)" = true ] || fail "The lab folder is not initialized with prod.s3.tfbackend."
check_state_kept
pass "The backend uses a partial configuration with locking and encryption, and the state stayed in place."

source "$LIB"
backend_block() { tf_files "$1" | awk '/backend *"/{f=1} f{print; n+=gsub(/\{/,"{"); n-=gsub(/\}/,"}"); if (n <= 0) f=0}'; }
block=$(backend_block app)
grep -q 'backend *"s3"' <<< "$block" || fail "app/ has no backend \"s3\" block."
grep -qE '^\s*(bucket|region|dynamodb_table|encrypt)\s*=' <<< "$block" && fail "The backend block of app/ sets more than key and workspace_key_prefix. Use backend.hcl."
cd platform
[ -d .terraform ] || fail "Run terraform init in platform/ first."
[ "$(terraform output -raw instance_profile_name 2> /dev/null)" = app-runtime-profile ] || fail "platform/ has no applied output instance_profile_name = app-runtime-profile."
[ "$(terraform output -raw artifacts_bucket 2> /dev/null)" = platform-artifacts ] || fail "platform/ has no applied output artifacts_bucket = platform-artifacts."
remote=$(aws s3 cp s3://tfstate-lab/platform/terraform.tfstate - 2> /dev/null) || fail "There is no platform state in S3."
[ "$(jq -r '.outputs.instance_profile_name.value // empty' <<< "$remote")" = app-runtime-profile ] || fail "The remote state in S3 has no output instance_profile_name. Did you apply?"
cd ../app
[ -f .terraform/terraform.tfstate ] || fail "app/ has no backend configured. Run terraform init."
cfg=$(jq -c '.backend.config + {type: .backend.type}' .terraform/terraform.tfstate)
[ "$(jq -r '"\(.type) \(.bucket)/\(.key) \(.workspace_key_prefix) \(.dynamodb_table) \(.encrypt)"' <<< "$cfg")" = "s3 tfstate-lab/app/terraform.tfstate envs tf-locks true" ] \
  || fail "app/ backend is $(jq -r '"\(.type) \(.bucket)/\(.key) prefix \(.workspace_key_prefix) table \(.dynamodb_table) encrypt \(.encrypt)"' <<< "$cfg"), expected s3 tfstate-lab/app/terraform.tfstate, prefix envs, table tf-locks, encrypt true."
tf_has 'data +"terraform_remote_state" +"platform"' || fail "No data \"terraform_remote_state\" \"platform\" in app/."
tf_has 'app-runtime-profile|platform-artifacts' && fail "The instance profile or bucket name is hard-coded in app/."
terraform validate -no-color > "$CHECK_TMP/validate.log" 2>&1 || fail "terraform validate fails in app/:"$'\n'"$(tail -n 10 "$CHECK_TMP/validate.log")"
pass "app/ uses the partial S3 backend and reads the platform outputs."

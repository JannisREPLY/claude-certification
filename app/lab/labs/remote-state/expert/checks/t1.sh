source "$LIB"
CHECK_TMP="$CHECK_TMP/platform"; mkdir -p "$CHECK_TMP"
backend_block() { tf_files "$1" | awk '/backend *"/{f=1} f{print; n+=gsub(/\{/,"{"); n-=gsub(/\}/,"}"); if (n <= 0) f=0}'; }
[ -f backend.hcl ] || fail "There is no backend.hcl in the lab folder."
grep -qE '^\s*bucket\s*=\s*"tfstate-lab"' backend.hcl || fail "backend.hcl does not set bucket = \"tfstate-lab\"."
block=$(backend_block platform)
grep -q 'backend *"s3"' <<< "$block" || fail "platform/ has no backend \"s3\" block."
grep -qE '^\s*(bucket|region|dynamodb_table|encrypt)\s*=' <<< "$block" && fail "The backend block of platform/ sets more than key. Move the shared settings to backend.hcl."
cd platform
[ -f .terraform/terraform.tfstate ] || fail "platform/ has no backend configured. Run terraform init."
cfg=$(jq -c '.backend.config + {type: .backend.type}' .terraform/terraform.tfstate)
[ "$(jq -r '"\(.type) \(.bucket)/\(.key) \(.region) \(.dynamodb_table) \(.encrypt)"' <<< "$cfg")" = "s3 tfstate-lab/platform/terraform.tfstate us-east-1 tf-locks true" ] \
  || fail "platform/ backend is $(jq -r '"\(.type) \(.bucket)/\(.key) \(.region) table \(.dynamodb_table) encrypt \(.encrypt)"' <<< "$cfg"), expected s3 tfstate-lab/platform/terraform.tfstate us-east-1, table tf-locks, encrypt true."
remote=$(aws s3 cp s3://tfstate-lab/platform/terraform.tfstate - 2> /dev/null) || fail "There is no state at s3://tfstate-lab/platform/terraform.tfstate."
jq -e '[.resources[] | select(.type == "aws_iam_role")] | length == 1' <<< "$remote" > /dev/null || fail "The state in S3 does not contain the platform resources."
item=$(aws dynamodb get-item --table-name tf-locks --key '{"LockID":{"S":"tfstate-lab/platform/terraform.tfstate-md5"}}' --query Item.LockID.S --output text)
[ "$item" = tfstate-lab/platform/terraform.tfstate-md5 ] || fail "tf-locks has no digest for the platform state; the state was not written with locking."
[ "$(aws iam get-role --role-name app-runtime-role --query Role.RoleId --output text 2> /dev/null)" = "$(cat "$LAB_STATE/role-id")" ] || fail "app-runtime-role was recreated or deleted."
[ "$(aws iam get-instance-profile --instance-profile-name app-runtime-profile --query InstanceProfile.InstanceProfileId --output text 2> /dev/null)" = "$(cat "$LAB_STATE/profile-id")" ] || fail "app-runtime-profile was recreated or deleted."
aws s3api head-object --bucket platform-artifacts --key README.txt > /dev/null 2>&1 || fail "platform-artifacts was recreated or deleted."
while IFS= read -r f; do
  jq -e '.resources | length > 0' "$f" > /dev/null 2>&1 && fail "platform/$f still holds resources. No local state may be left."
done <<< "$(find . -name '*.tfstate' -not -path './.terraform/*')"
expect_clean_plan
pass "The platform state is in S3 via a partial backend configuration, and nothing was recreated."

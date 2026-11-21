source "$LIB"
CHECK_TMP="$CHECK_TMP/platform"; mkdir -p "$CHECK_TMP"
cd platform
[ -f .terraform/terraform.tfstate ] || fail "platform/ has no backend configured. Run terraform init."
cfg=$(jq -c '.backend.config + {type: .backend.type}' .terraform/terraform.tfstate)
[ "$(jq -r .type <<< "$cfg")" = s3 ] || fail "platform/ uses the $(jq -r .type <<< "$cfg") backend, not s3."
[ "$(jq -r '"\(.bucket)/\(.key)"' <<< "$cfg")" = tfstate-lab/platform/terraform.tfstate ] || fail "The state goes to $(jq -r '"\(.bucket)/\(.key)"' <<< "$cfg"), expected tfstate-lab/platform/terraform.tfstate."
[ "$(jq -r .dynamodb_table <<< "$cfg")" = tf-locks ] || fail "State locking does not use the table tf-locks."
[ "$(jq -r .encrypt <<< "$cfg")" = true ] || fail "Encryption is not enabled."
remote=$(aws s3 cp s3://tfstate-lab/platform/terraform.tfstate - 2> /dev/null) || fail "There is no state at s3://tfstate-lab/platform/terraform.tfstate."
jq -e '[.resources[] | select(.type == "aws_iam_role")] | length == 1' <<< "$remote" > /dev/null || fail "The state in S3 does not contain the platform resources."
item=$(aws dynamodb get-item --table-name tf-locks --key '{"LockID":{"S":"tfstate-lab/platform/terraform.tfstate-md5"}}' --query Item.LockID.S --output text)
[ "$item" = tfstate-lab/platform/terraform.tfstate-md5 ] || fail "tf-locks has no digest for the platform state; the state was not written with locking."
[ "$(aws iam get-role --role-name app-runtime-role --query Role.RoleId --output text 2> /dev/null)" = "$(cat "$LAB_STATE/role-id")" ] || fail "app-runtime-role was recreated or deleted."
[ "$(aws iam get-instance-profile --instance-profile-name app-runtime-profile --query InstanceProfile.InstanceProfileId --output text 2> /dev/null)" = "$(cat "$LAB_STATE/profile-id")" ] || fail "app-runtime-profile was recreated or deleted."
aws s3api head-object --bucket platform-artifacts --key README.txt > /dev/null 2>&1 || fail "platform-artifacts was recreated or deleted."
for f in terraform.tfstate state/platform.tfstate; do
  [ -s "$f" ] && jq -e '.resources | length > 0' "$f" > /dev/null && fail "platform/$f still holds resources. Delete the old local state."
done
expect_clean_plan
pass "The platform state is in S3 with locking and encryption, and nothing was recreated."

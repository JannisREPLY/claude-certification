source "$LIB"
cd app
[ -f .terraform/terraform.tfstate ] || fail "app/ has no backend configured."
read -r type bucket key table <<< "$(jq -r '[.backend.type, .backend.config.bucket, .backend.config.key, .backend.config.dynamodb_table] | map(tostring) | join(" ")' .terraform/terraform.tfstate)"
[ "$type/$bucket/$key/$table" = "s3/tfstate-lab/app/terraform.tfstate/tf-locks" ] || fail "app/ backend is $type $bucket/$key (lock table $table), expected s3 tfstate-lab/app/terraform.tfstate with tf-locks."
vpc=$(cat "$LAB_STATE/vpc")
grep -q 'terraform_remote_state' *.tf || fail "No terraform_remote_state data source in app/."
grep -q "$vpc" *.tf && fail "The VPC ID is hardcoded in app/."
aws s3 cp s3://tfstate-lab/app/terraform.tfstate - 2>/dev/null | grep -q '"app-default"' || fail "The default workspace state in S3 has no security group app-default. Did you apply?"
n=$(aws ec2 describe-security-groups --filters Name=group-name,Values=app-default Name=vpc-id,Values="$vpc" --query 'length(SecurityGroups)' --output text)
[ "$n" = "1" ] || fail "Security group app-default doesn't exist in the network VPC."
pass "app reads the network state and app-default exists."

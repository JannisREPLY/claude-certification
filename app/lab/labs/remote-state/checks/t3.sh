source "$LIB"
vpc=$(cat "$LAB_STATE/vpc")
aws s3 cp s3://tfstate-lab/env:/staging/app/terraform.tfstate - 2>/dev/null | grep -q '"app-staging"' || fail "No state for workspace staging with app-staging in S3 (expected env:/staging/app/terraform.tfstate)."
n=$(aws ec2 describe-security-groups --filters Name=group-name,Values=app-staging Name=vpc-id,Values="$vpc" --query 'length(SecurityGroups)' --output text)
[ "$n" = "1" ] || fail "Security group app-staging doesn't exist in the network VPC."
n=$(aws ec2 describe-security-groups --filters Name=group-name,Values=app-default --query 'length(SecurityGroups)' --output text)
[ "$n" = "1" ] || fail "app-default is gone; each workspace must keep its own security group."
pass "staging workspace has its own state and security group."

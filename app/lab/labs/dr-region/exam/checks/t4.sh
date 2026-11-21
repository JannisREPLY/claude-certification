source "$LIB"
require_init
acct=$(aws sts get-caller-identity --query Account --output text)
has_tags() {
  local tags=$1 what=$2
  [ "$(jq -r '.[]? | select(.Key == "Project") | .Value' <<< "$tags")" = northwind-dr ] && [ "$(jq -r '.[]? | select(.Key == "ManagedBy") | .Value' <<< "$tags")" = terraform ] \
    || fail "$what does not carry Project = northwind-dr and ManagedBy = terraform."
}
has_tags "$(aws s3api get-bucket-tagging --bucket nw-dr-primary-data --query TagSet --output json 2> /dev/null || echo '[]')" nw-dr-primary-data
has_tags "$(aws ec2 describe-security-groups --group-ids "$(cat "$LAB_STATE/sg-id")" --query 'SecurityGroups[0].Tags' --output json)" "nw-dr-app-sg in us-east-1"
has_tags "$(aws s3api get-bucket-tagging --bucket "nw-dr-backup-$acct" --query TagSet --output json 2> /dev/null || echo '[]')" "nw-dr-backup-$acct"
has_tags "$(aws ec2 describe-security-groups --region us-west-2 --filters Name=group-name,Values=nw-dr-app-sg --query 'SecurityGroups[0].Tags' --output json 2> /dev/null || echo '[]')" "nw-dr-app-sg in us-west-2"
[ "$(grep -c 'default_tags' <<< "$(cat ./*.tf)")" -ge 2 ] || fail "Both provider configurations must use default_tags."
[ "$(state_attr aws_security_group.app id)" = "$(cat "$LAB_STATE/sg-id")" ] || fail "aws_security_group.app was recreated."
aws s3api head-object --bucket nw-dr-primary-data --key README.txt > /dev/null 2>&1 || fail "nw-dr-primary-data was recreated or deleted."
expect_clean_plan
pass "All resources carry the default tags, nothing was replaced, and the plan is clean."

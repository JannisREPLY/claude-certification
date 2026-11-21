source "$LIB"
require_init
vpc=$(aws ec2 describe-vpcs --region us-west-2 --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
sg=$(aws ec2 describe-security-groups --region us-west-2 --filters Name=group-name,Values=nw-dr-app-sg Name=vpc-id,Values="$vpc" --query 'SecurityGroups[0]' --output json)
[ "$sg" != null ] || fail "There is no security group nw-dr-app-sg in the default VPC of us-west-2."
[ "$(state_attr module.backup.aws_security_group.app id)" = "$(jq -r .GroupId <<< "$sg")" ] || fail "module.backup.aws_security_group.app is not nw-dr-app-sg in us-west-2."
jq -e '[.IpPermissions[] | select(.IpProtocol == "tcp" and .FromPort == 443 and .ToPort == 443 and any(.IpRanges[]; .CidrIp == "0.0.0.0/0"))] | length == 1' <<< "$sg" > /dev/null \
  || fail "nw-dr-app-sg in us-west-2 does not allow TCP 443 from 0.0.0.0/0."
jq -e '[.IpPermissionsEgress[] | select(.IpProtocol == "-1" and any(.IpRanges[]; .CidrIp == "0.0.0.0/0"))] | length == 1' <<< "$sg" > /dev/null \
  || fail "nw-dr-app-sg in us-west-2 does not allow all outbound traffic."
mod=$(tf_files modules/backup)
grep -q 'var\.app_port' <<< "$mod" || fail "The DR security group must take its port from var.app_port."
grep -qE '(from_port|to_port)\s*=\s*443' <<< "$mod" && fail "The port is hard-coded in modules/backup."
expect_no_changes module.backup.aws_security_group.app
pass "nw-dr-app-sg exists in us-west-2 with the application port from var.app_port."

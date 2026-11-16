source "$LIB"
require_init
id=$(state_attr aws_security_group.web id)
[ -n "$id" ] || fail "aws_security_group.web is missing from state."
read -r name vpc <<< "$(aws ec2 describe-security-groups --group-ids "$id" --query 'SecurityGroups[0].[GroupName,VpcId]' --output text)"
[ "$name" = "dev-web" ] || fail "The security group is named $name, expected dev-web."
[ "$vpc" = "$(cat "$LAB_STATE/vpc")" ] || fail "The security group is not in the shared VPC."
ports=$(aws ec2 describe-security-groups --group-ids "$id" --query 'SecurityGroups[0].IpPermissions[?IpProtocol==`tcp`].FromPort' --output text | tr '\t' '\n' | sort -n | xargs)
[ "$ports" = "80 443" ] || fail "TCP ingress ports are '$ports', expected '80 443'."
grep -qE 'dynamic\s+"ingress"' *.tf || fail "No dynamic \"ingress\" block found."
pass "security group has one ingress rule per port."

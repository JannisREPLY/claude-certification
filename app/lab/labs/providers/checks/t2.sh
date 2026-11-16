source "$LIB"
require_init
id=$(state_attr aws_vpc.dr id)
[ -n "$id" ] || fail "aws_vpc.dr is missing from state. Did you apply?"
read -r cidr name <<< "$(aws ec2 describe-vpcs --region us-west-2 --vpc-ids "$id" --query "Vpcs[0].[CidrBlock,Tags[?Key=='Name'].Value|[0]]" --output text 2>/dev/null)" || fail "aws_vpc.dr ($id) is not in us-west-2."
[ "$cidr $name" = "10.20.0.0/16 dr" ] || fail "aws_vpc.dr has CIDR $cidr and Name $name."
grep -qE 'alias\s*=\s*"west"' *.tf || fail "No provider configuration with alias west."
pass "aws_vpc.dr exists in us-west-2."

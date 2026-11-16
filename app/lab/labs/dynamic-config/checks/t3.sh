source "$LIB"
require_init
vpc=$(cat "$LAB_STATE/vpc")
for spec in web:10.50.1.0/24:true app:10.50.2.0/24:false db:10.50.3.0/24:false; do
  IFS=: read -r key cidr public <<< "$spec"
  id=$(state_attr "aws_subnet.this[\"$key\"]" id)
  [ -n "$id" ] || fail "aws_subnet.this[\"$key\"] is missing from state."
  read -r s_vpc s_cidr s_pub s_name <<< "$(aws ec2 describe-subnets --subnet-ids "$id" --query "Subnets[0].[VpcId,CidrBlock,MapPublicIpOnLaunch,Tags[?Key=='Name'].Value|[0]]" --output text)"
  [ "$s_vpc" = "$vpc" ] || fail "Subnet $key is not in the shared VPC."
  [ "$s_cidr" = "$cidr" ] || fail "Subnet $key has CIDR $s_cidr, expected $cidr."
  [ "${s_pub,,}" = "$public" ] || fail "Subnet $key has map_public_ip_on_launch = ${s_pub,,}, expected $public."
  [ "$s_name" = "dev-$key" ] || fail "Subnet $key is tagged Name = $s_name, expected dev-$key."
done
pass "3 subnets with the right keys, CIDRs, tags and public IP settings."

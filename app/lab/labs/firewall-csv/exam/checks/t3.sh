source "$LIB"
require_init
ensure_plan
cfg=$(config_json)
jq -e '[.root_module.resources[] | select(.mode == "data" and .type == "aws_ami")] | length > 0' <<< "$cfg" > /dev/null || fail "No aws_ami data source found."
jq -e '[.root_module.resources[] | select(.mode == "data" and .type == "aws_subnet")] | length > 0' <<< "$cfg" > /dev/null || fail "No aws_subnet data source found."
jq -e '.root_module.variables.instances' <<< "$cfg" > /dev/null || fail "The variable instances is not declared."
tf_has 'precondition\s*\{' || fail "No precondition found."
out=$(terraform plan -lock=false -input=false -no-color -refresh=false -var 'instances={web-a={instance_type="m5.large",availability_zone="us-east-1a"}}' 2>&1) \
  && fail "terraform plan with instance_type m5.large should fail."
grep -q 'Resource precondition failed' <<< "$out" || fail "An instance type m5.large should fail a precondition:"$'\n'"$(tail -n 8 <<< "$out")"
ami_data=$(jq -c '[.root_module.resources[] | select(.mode == "data" and .type == "aws_ami")]' <<< "$cfg")
jq -e 'map(select(.expressions.most_recent.constant_value == true)) | length > 0' <<< "$ami_data" > /dev/null || fail "The aws_ami data source must set most_recent = true."
ami=$(state_json | jq -r '[.values.root_module.resources[]? | select(.mode == "data" and .type == "aws_ami") | .values.id] | first // empty')
[ -n "$ami" ] || fail "The aws_ami data source is not in state. Run terraform apply."
grep -q '^amzn2-ami-hvm-' <<< "$(aws ec2 describe-images --owners amazon --image-ids "$ami" --query 'Images[0].Name' --output text 2> /dev/null)" \
  || fail "The aws_ami data source must find an Amazon Linux 2 image (owner amazon, name amzn2-ami-hvm-*)."
vpc=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
sg=$(aws ec2 describe-security-groups --filters Name=group-name,Values=nw-fw-app --query 'SecurityGroups[0].GroupId' --output text)
check() {
  local key=$1 type=$2 az=$3 i subnet
  has_address "aws_instance.app[\"$key\"]" || fail "aws_instance.app[\"$key\"] is not in state."
  i=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=nw-fw-$key" Name=instance-state-name,Values=running --query 'Reservations[].Instances[]' --output json)
  [ "$(jq length <<< "$i")" = 1 ] || fail "There should be exactly one running instance tagged Name = nw-fw-$key."
  [ "$(jq -r '.[0].InstanceId' <<< "$i")" = "$(state_attr "aws_instance.app[\"$key\"]" id)" ] || fail "nw-fw-$key is not the instance aws_instance.app[\"$key\"]."
  [ "$(jq -r '.[0].InstanceType' <<< "$i")" = "$type" ] || fail "nw-fw-$key should be $type."
  [ "$(jq -r '.[0].ImageId' <<< "$i")" = "$ami" ] || fail "nw-fw-$key should use the AMI $ami of the aws_ami data source."
  subnet=$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$vpc" Name=default-for-az,Values=true Name=availability-zone,Values="$az" --query 'Subnets[0].SubnetId' --output text)
  [ "$(jq -r '.[0].SubnetId' <<< "$i")" = "$subnet" ] || fail "nw-fw-$key should run in the default subnet $subnet of $az."
  jq -e --arg sg "$sg" '.[0].SecurityGroups | map(.GroupId) | index($sg)' <<< "$i" > /dev/null || fail "nw-fw-$key should be in the security group nw-fw-app."
}
check web-a t3.micro us-east-1a
check web-b t3.small us-east-1b
[ "$(addresses | grep -c '^aws_instance\.app\[')" = 2 ] || fail "aws_instance.app should have exactly the keys web-a and web-b."
pass "web-a and web-b run with the right type, AMI, subnet and security group, guarded by a precondition."

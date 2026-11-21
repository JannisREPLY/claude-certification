default_vpc() { aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text; }

sorted_subnets() {
  aws ec2 describe-subnets --filters Name=vpc-id,Values="$(default_vpc)" --query 'Subnets[].SubnetId' --output text | tr '\t' '\n' | LC_ALL=C sort
}

inputs_unchanged() {
  md5sum -c --quiet "$LAB_STATE/inputs.md5" > /dev/null 2>&1 || fail "A data file (rules.yaml, partner-rules.csv or terraform.tfvars) was changed. Restore it."
}

no_hardcoded_ids() {
  local hit
  hit=$(tf_files | grep -oE '"(ami|subnet|vpc|sg)-[0-9a-f]{8,}"' | head -1 || true)
  [ -z "$hit" ] || fail "Hard-coded ID $hit found in the configuration."
}

check_sg() {
  local want_keys=$1 want_rules=$2 sg name desc vpc got_keys got_rules
  sg=$(state_attr aws_security_group.web id)
  [ -n "$sg" ] || fail "aws_security_group.web is not in state. Did you apply?"
  read -r name vpc desc <<< "$(aws ec2 describe-security-groups --group-ids "$sg" --query 'SecurityGroups[0].[GroupName,VpcId,Description]' --output text)"
  [ "$name" = orders-web ] || fail "The security group is named $name, expected orders-web."
  [ "$vpc" = "$(default_vpc)" ] || fail "The security group is not in the default VPC."
  [ "$desc" = "Orders web tier" ] || fail "The security group description is '$desc', expected 'Orders web tier' from rules.yaml."
  got_keys=$(addresses | sed -n 's/^aws_vpc_security_group_ingress_rule\.this\["\(.*\)"\]$/\1/p' | LC_ALL=C sort | xargs)
  [ "$got_keys" = "$(tr ' ' '\n' <<< "$want_keys" | LC_ALL=C sort | xargs)" ] || fail "aws_vpc_security_group_ingress_rule.this keys are [$got_keys], expected [$want_keys]."
  got_rules=$(aws ec2 describe-security-group-rules --filters Name=group-id,Values="$sg" --output json \
    | jq -r '.SecurityGroupRules[] | select(.IsEgress | not) | "\(.IpProtocol):\(.FromPort):\(.ToPort):\(.CidrIpv4 // .CidrIpv6)"' | LC_ALL=C sort | xargs)
  [ "$got_rules" = "$(tr ' ' '\n' <<< "$want_rules" | LC_ALL=C sort | xargs)" ] || fail "Ingress rules of orders-web in AWS are [$got_rules], expected [$want_rules] (protocol:from:to:cidr)."
  for k in $want_keys; do expect_no_changes "aws_vpc_security_group_ingress_rule.this[\"$k\"]"; done
  expect_no_changes aws_security_group.web
}

check_instance() {
  local key=$1 type=$2 idx=$3 want_tags=$4 id info subnets want_subnet image_name
  id=$(state_attr "aws_instance.app[\"$key\"]" id)
  [ -n "$id" ] || fail "aws_instance.app[\"$key\"] is not in state. Did you apply?"
  info=$(aws ec2 describe-instances --instance-ids "$id" --query 'Reservations[0].Instances[0]' --output json)
  [ "$(jq -r .State.Name <<< "$info")" = running ] || fail "Instance $key is not running."
  [ "$(jq -r .InstanceType <<< "$info")" = "$type" ] || fail "Instance $key has type $(jq -r .InstanceType <<< "$info"), expected $type."
  mapfile -t subnets < <(sorted_subnets)
  want_subnet=${subnets[$((idx % ${#subnets[@]}))]}
  [ "$(jq -r .SubnetId <<< "$info")" = "$want_subnet" ] || fail "Instance $key is in subnet $(jq -r .SubnetId <<< "$info"), expected $want_subnet (index $idx of the sorted default-VPC subnets)."
  jq -e --arg sg "$(state_attr aws_security_group.web id)" '[.SecurityGroups[].GroupId] | index($sg)' <<< "$info" > /dev/null || fail "Instance $key does not use aws_security_group.web."
  image_name=$(aws ec2 describe-images --image-ids "$(jq -r .ImageId <<< "$info")" --query 'Images[0].Name' --output text)
  [[ $image_name == amzn2-ami-hvm-*-x86_64-gp2 ]] || fail "Instance $key uses the image $image_name, expected an amzn2-ami-hvm-*-x86_64-gp2 image."
  jq -e --argjson w "$want_tags" '(.Tags // [] | from_entries) == $w' <<< "$info" > /dev/null \
    || fail "Instance $key has tags $(jq -c '.Tags // [] | from_entries' <<< "$info"), expected $want_tags."
  expect_no_changes "aws_instance.app[\"$key\"]"
}

check_data_sources() {
  local types
  types=$(state_json | jq -r '[.values.root_module.resources[]? | select(.mode == "data") | .type] | join(" ")')
  for t in aws_ami aws_subnets aws_vpc; do
    grep -qw "$t" <<< "$types" || fail "No $t data source in state. Look up the IDs with data sources."
  done
  no_hardcoded_ids
}

check_instance_set() {
  local got
  got=$(addresses | sed -n 's/^aws_instance\.app\["\(.*\)"\]$/\1/p' | LC_ALL=C sort | xargs)
  [ "$got" = "$1" ] || fail "aws_instance.app has the keys [$got], expected [$1]."
}

outputs() { terraform output -json -no-color; }

expect_private_ips() {
  local out=$1 key ip
  for key in $2; do
    ip=$(aws ec2 describe-instances --instance-ids "$(state_attr "aws_instance.app[\"$key\"]" id)" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
    [ "$(jq -r --arg k "$key" '.private_ips.value[$k] // empty' <<< "$out")" = "$ip" ] || fail "private_ips[\"$key\"] should be $ip."
  done
  [ "$(jq -r '.private_ips.value | keys | join(" ")' <<< "$out")" = "$(tr ' ' '\n' <<< "$2" | LC_ALL=C sort | xargs)" ] || fail "private_ips should have exactly the keys $2."
}

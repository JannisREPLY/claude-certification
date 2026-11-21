asg() { aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names orders-workers --query 'AutoScalingGroups[0]' --output json; }

lt_latest() { aws ec2 describe-launch-templates --launch-template-names orders-worker --query 'LaunchTemplates[0].LatestVersionNumber' --output text; }

lt_data() { aws ec2 describe-launch-template-versions --launch-template-name orders-worker --versions '$Latest' --query 'LaunchTemplateVersions[0].LaunchTemplateData' --output json; }

default_vpc() { aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text; }

first_subnet() { aws ec2 describe-subnets --filters Name=vpc-id,Values="$(default_vpc)" --query 'Subnets[].SubnetId' --output text | tr '\t' '\n' | LC_ALL=C sort | head -1; }

change_of() { plan_json | jq -c --arg a "$1" '[.resource_changes[]? | select(.address == $a) | .change] | first // {}'; }

plan_with() {
  local name=$1; shift
  terraform plan -lock=false -input=false -no-color -out="$CHECK_TMP/$name.bin" "$@" > "$CHECK_TMP/$name.log" 2>&1 \
    || fail "terraform plan $* fails:"$'\n'"$(tail -n 15 "$CHECK_TMP/$name.log")"
  terraform show -json "$CHECK_TMP/$name.bin" > "$CHECK_TMP/$name.json"
}

actions_in() { jq -c --arg a "$2" '[.resource_changes[]? | select(.address == $a) | .change.actions] | first // ["absent"]' "$CHECK_TMP/$1.json"; }

check_lt_kept() {
  [ "$(state_attr aws_launch_template.worker id)" = "$(cat "$LAB_STATE/lt_id")" ] || fail "The launch template orders-worker was replaced."
}

check_asg() {
  local info change
  info=$(asg)
  [ "$(jq -r .AutoScalingGroupARN <<< "$info")" = "$(cat "$LAB_STATE/asg_arn")" ] || fail "The Auto Scaling group orders-workers was replaced."
  [ "$(jq -r .DesiredCapacity <<< "$info")" = 4 ] || fail "DesiredCapacity of orders-workers is $(jq -r .DesiredCapacity <<< "$info"), expected 4."
  ensure_plan
  change=$(change_of aws_autoscaling_group.worker)
  jq -e '.actions | index("delete") | not' <<< "$change" > /dev/null || fail "terraform plan would replace aws_autoscaling_group.worker."
  jq -e '.actions == ["no-op"] or .before.desired_capacity == .after.desired_capacity' <<< "$change" > /dev/null \
    || fail "terraform plan wants to change desired_capacity of aws_autoscaling_group.worker ($(jq -c '[.before.desired_capacity, .after.desired_capacity]' <<< "$change"))."
}

check_latest_version() {
  local got
  got=$(jq -r '.LaunchTemplate.Version // .MixedInstancesPolicy.LaunchTemplate.LaunchTemplateSpecification.Version // empty' <<< "$(asg)")
  [ "$got" = "$(lt_latest)" ] || fail "orders-workers uses launch template version '$got', expected the latest version $(lt_latest). Did you apply?"
  config_json | jq -e '[.. | objects | select(.address? == "aws_autoscaling_group.worker") | .expressions.launch_template[0].version.references // [] | .[]] | index("aws_launch_template.worker.latest_version")' > /dev/null \
    || fail "The group's launch template version must reference aws_launch_template.worker.latest_version."
}

check_depends_on() {
  config_json | jq -e '.root_module.resources[] | select(.address == "aws_autoscaling_group.worker") | .depends_on // [] | index("aws_iam_role_policy_attachment.worker")' > /dev/null \
    || fail "aws_autoscaling_group.worker has no explicit depends_on for aws_iam_role_policy_attachment.worker."
}

check_user_data() {
  local script
  script=$(lt_data | jq -r '.UserData // empty' | base64 -d 2> /dev/null || true)
  grep -qxF 'echo "environment=prod" > /etc/orders-worker.conf' <<< "$script" || fail "The user data of the latest launch template version does not contain the rendered environment line. Did you apply?"$'\n'"$script"
  grep -qxF 'yum install -y jq' <<< "$script" && grep -qxF 'yum install -y amazon-cloudwatch-agent' <<< "$script" \
    || fail "The user data does not install each package on its own 'yum install -y <package>' line:"$'\n'"$script"
  [ "$(grep -c '^yum install' <<< "$script")" = 2 ] || fail "The user data should have exactly two yum install lines:"$'\n'"$script"
  tf_has 'templatefile\(' || fail "Render the user data with templatefile()."
  tf_has 'bootstrap\.sh' && fail "The configuration still uses bootstrap.sh."
  check_lt_kept
}

check_sg() {
  local suffix sg info
  suffix=$(state_attr random_integer.suffix result)
  [ -n "$suffix" ] || fail "random_integer.suffix is not in state. Did you apply?"
  [ "$(state_attr random_integer.suffix min)" = 1000 ] && [ "$(state_attr random_integer.suffix max)" = 9999 ] || fail "random_integer.suffix must use min = 1000 and max = 9999."
  sg=$(state_attr aws_security_group.worker id)
  [ -n "$sg" ] || fail "aws_security_group.worker is not in state."
  info=$(aws ec2 describe-security-groups --group-ids "$sg" --query 'SecurityGroups[0]' --output json)
  [ "$(jq -r .GroupName <<< "$info")" = "orders-worker-$suffix" ] || fail "The security group is named $(jq -r .GroupName <<< "$info"), expected orders-worker-$suffix."
  [ "$(jq -r .VpcId <<< "$info")" = "$(default_vpc)" ] || fail "The security group is not in the default VPC."
  [ -z "${1:-}" ] || [ "$(jq -r .Description <<< "$info")" = "$1" ] || fail "The security group description is '$(jq -r .Description <<< "$info")', expected '$1'."
  lt_data | jq -e --arg sg "$sg" '(.SecurityGroupIds // []) + [.NetworkInterfaces[]?.Groups[]?] | index($sg)' > /dev/null || fail "The latest launch template version does not use aws_security_group.worker."
  plan_with replace_sg -replace=aws_security_group.worker
  [ "$(actions_in replace_sg aws_security_group.worker)" = '["create","delete"]' ] || fail "A replacement of aws_security_group.worker is planned as $(actions_in replace_sg aws_security_group.worker); the new group must be created before the old one is destroyed."
}

check_rules() {
  local want_keys=$1 want_rules=$2 sg got_keys got_rules
  sg=$(state_attr aws_security_group.worker id)
  [ -n "$sg" ] || fail "aws_security_group.worker is not in state."
  got_keys=$(addresses | sed -n 's/^aws_vpc_security_group_ingress_rule\.worker\["\(.*\)"\]$/\1/p' | LC_ALL=C sort | xargs)
  [ "$got_keys" = "$(tr ' ' '\n' <<< "$want_keys" | LC_ALL=C sort | xargs)" ] || fail "aws_vpc_security_group_ingress_rule.worker keys are [$got_keys], expected [$want_keys]."
  got_rules=$(aws ec2 describe-security-group-rules --filters Name=group-id,Values="$sg" --output json \
    | jq -r '.SecurityGroupRules[] | select(.IsEgress | not) | "\(.IpProtocol):\(.FromPort):\(.ToPort):\(.CidrIpv4 // .CidrIpv6)"' | LC_ALL=C sort | xargs)
  [ "$got_rules" = "$(tr ' ' '\n' <<< "$want_rules" | LC_ALL=C sort | xargs)" ] || fail "Ingress rules of the worker group in AWS are [$got_rules], expected [$want_rules]."
}

rules_for() {
  local keys="" rules="" p c
  for p in $1; do for c in $2; do
    grep -qwF "$p-$c" <<< " ${3:-} " && continue
    keys+="$p-$c "; rules+="tcp:$p:$p:$c "
  done; done
  echo "$keys|$rules"
}

check_canary() {
  local id info out
  id=$(state_attr 'aws_instance.canary[0]' id)
  [ -n "$id" ] || fail "aws_instance.canary[0] is not in state. Did you apply?"
  [ "$(state_json | jq '[.values.root_module.resources[] | select(.address | startswith("aws_instance.canary[")) | .index] == [0]')" = true ] || fail "aws_instance.canary must use count."
  info=$(aws ec2 describe-instances --instance-ids "$id" --query 'Reservations[0].Instances[0]' --output json)
  [ "$(jq -r .State.Name <<< "$info")" = running ] || fail "The canary is not running."
  [ "$(jq -r .ImageId <<< "$info")" = "$(state_json | jq -r '.values.root_module.resources[] | select(.address == "data.aws_ami.al2") | .values.id')" ] || fail "The canary does not use the AMI of data.aws_ami.al2."
  [ "$(jq -r .InstanceType <<< "$info")" = t3.micro ] || fail "The canary must use var.instance_type."
  [ "$(jq -r .SubnetId <<< "$info")" = "$(first_subnet)" ] || fail "The canary is not in the first sorted default-VPC subnet $(first_subnet)."
  jq -e --arg sg "$(state_attr aws_security_group.worker id)" '[.SecurityGroups[].GroupId] | index($sg)' <<< "$info" > /dev/null || fail "The canary does not use aws_security_group.worker."
  out=$(terraform output -json -no-color)
  [ "$(jq -r '.canary_private_ip.value // empty' <<< "$out")" = "$(jq -r .PrivateIpAddress <<< "$info")" ] || fail "Output canary_private_ip should be $(jq -r .PrivateIpAddress <<< "$info")."
  plan_with staging -var environment=staging
  actions_in staging 'aws_instance.canary[0]' | jq -e 'index("delete") and index("create")' > /dev/null || fail "A new launch template version (plan -var environment=staging) does not replace aws_instance.canary[0] (actions: $(actions_in staging 'aws_instance.canary[0]'))."
  plan_with nocanary -var enable_canary=false
  [ "$(actions_in nocanary 'aws_instance.canary[0]')" = '["delete"]' ] || fail "With enable_canary = false, aws_instance.canary[0] should be destroyed."
  jq -e '.output_changes.canary_private_ip.after == null and (.output_changes | has("canary_private_ip"))' "$CHECK_TMP/nocanary.json" > /dev/null || fail "With enable_canary = false, canary_private_ip must be null."
}

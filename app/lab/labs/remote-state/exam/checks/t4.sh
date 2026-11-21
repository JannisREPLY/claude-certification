source "$LIB"
cd app
[ -d .terraform ] || fail "Run terraform init in app/ first."
running() { aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" Name=instance-state-name,Values=pending,running --query 'Reservations[].Instances[]' --output json; }
for ws in default staging prod; do
  inst=$(running "app-$ws")
  [ "$(jq length <<< "$inst")" = 1 ] || fail "Expected one running instance tagged Name = app-$ws, found $(jq length <<< "$inst")."
  want=t3.micro; [ "$ws" = prod ] && want=t3.small
  [ "$(jq -r '.[0].InstanceType' <<< "$inst")" = "$want" ] || fail "app-$ws is $(jq -r '.[0].InstanceType' <<< "$inst"), expected $want."
  key=app/terraform.tfstate; [ "$ws" = default ] || key="env:/$ws/app/terraform.tfstate"
  state=$(aws s3 cp "s3://tfstate-lab/$key" - 2> /dev/null) || fail "There is no state for the workspace $ws at s3://tfstate-lab/$key."
  [ "$(jq -r '[.resources[] | select(.mode == "managed" and .type == "aws_instance" and .name == "app") | .instances[0].attributes.id] | first // empty' <<< "$state")" = "$(jq -r '.[0].InstanceId' <<< "$inst")" ] \
    || fail "aws_instance.app in the $ws state is not app-$ws."
  TF_WORKSPACE=$ws terraform plan -lock=false -input=false -no-color -detailed-exitcode > "$CHECK_TMP/ws-plan.log" 2>&1 || fail "terraform plan in the workspace $ws is not clean:"$'\n'"$(tail -n 15 "$CHECK_TMP/ws-plan.log")"
done
pass "default, staging and prod each have their own state and instance with the right type."

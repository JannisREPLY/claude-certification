source "$LIB"
cd app
[ -d .terraform ] || fail "Run terraform init in app/ first."
running() { aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" Name=instance-state-name,Values=pending,running --query 'Reservations[].Instances[]' --output json; }
inst=$(running app-staging)
[ "$(jq length <<< "$inst")" = 1 ] || fail "Expected one running instance tagged Name = app-staging, found $(jq length <<< "$inst")."
[ "$(running app-default | jq length)" = 1 ] || fail "app-default is gone; each workspace must keep its own instance."
state=$(aws s3 cp s3://tfstate-lab/env:/staging/app/terraform.tfstate - 2> /dev/null) || fail "There is no state for the workspace staging at s3://tfstate-lab/env:/staging/app/terraform.tfstate."
[ "$(jq -r '[.resources[] | select(.mode == "managed" and .type == "aws_instance" and .name == "app") | .instances[0].attributes.id] | first // empty' <<< "$state")" = "$(jq -r '.[0].InstanceId' <<< "$inst")" ] \
  || fail "aws_instance.app in the staging state is not app-staging."
TF_WORKSPACE=staging terraform plan -lock=false -input=false -no-color -detailed-exitcode > "$CHECK_TMP/ws-plan.log" 2>&1 || fail "terraform plan in staging is not clean:"$'\n'"$(tail -n 15 "$CHECK_TMP/ws-plan.log")"
pass "The staging workspace has its own state and instance app-staging."

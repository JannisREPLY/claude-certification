source "$LIB"
cd app
[ -f .terraform/terraform.tfstate ] || fail "app/ has no backend configured. Run terraform init."
cfg=$(jq -c '.backend.config + {type: .backend.type}' .terraform/terraform.tfstate)
[ "$(jq -r '"\(.type) \(.bucket)/\(.key) \(.dynamodb_table) \(.encrypt)"' <<< "$cfg")" = "s3 tfstate-lab/app/terraform.tfstate tf-locks true" ] \
  || fail "app/ backend is $(jq -r '"\(.type) \(.bucket)/\(.key) table \(.dynamodb_table) encrypt \(.encrypt)"' <<< "$cfg"), expected s3 tfstate-lab/app/terraform.tfstate, table tf-locks, encrypt true."
tf_has 'data +"terraform_remote_state" +"platform"' || fail "No data \"terraform_remote_state\" \"platform\" in app/."
tf_has 'app-runtime-profile' && fail "The instance profile name is hard-coded in app/. Read it from the remote state."
inst=$(aws ec2 describe-instances --filters Name=tag:Name,Values=app-default Name=instance-state-name,Values=pending,running --query 'Reservations[].Instances[]' --output json)
[ "$(jq length <<< "$inst")" = 1 ] || fail "Expected one running instance tagged Name = app-default, found $(jq length <<< "$inst")."
jq -e '.[0].IamInstanceProfile.Arn // "" | endswith("instance-profile/app-runtime-profile")' <<< "$inst" > /dev/null || fail "app-default does not use the instance profile app-runtime-profile."
state=$(aws s3 cp s3://tfstate-lab/app/terraform.tfstate - 2> /dev/null) || fail "There is no state at s3://tfstate-lab/app/terraform.tfstate."
[ "$(jq -r '[.resources[] | select(.mode == "managed" and .type == "aws_instance" and .name == "app") | .instances[0].attributes.id] | first // empty' <<< "$state")" = "$(jq -r '.[0].InstanceId' <<< "$inst")" ] \
  || fail "aws_instance.app in the default workspace state is not app-default."
TF_WORKSPACE=default terraform plan -lock=false -input=false -no-color -detailed-exitcode > "$CHECK_TMP/ws-plan.log" 2>&1 || fail "terraform plan in the default workspace is not clean:"$'\n'"$(tail -n 15 "$CHECK_TMP/ws-plan.log")"
pass "app-default runs with the instance profile read from the platform state."

source "$LIB"
cd app
[ -d .terraform ] || fail "Run terraform init in app/ first."
running() { aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" Name=instance-state-name,Values=pending,running --query 'Reservations[].Instances[]' --output json; }
tag() { jq -r --arg k "$2" '.[0].Tags[] | select(.Key == $k) | .Value' <<< "$1"; }
for ws in staging prod; do
  inst=$(running "app-$ws")
  [ "$(jq length <<< "$inst")" = 1 ] || fail "Expected one running instance tagged Name = app-$ws, found $(jq length <<< "$inst")."
  want=t3.micro; [ "$ws" = prod ] && want=t3.small
  [ "$(jq -r '.[0].InstanceType' <<< "$inst")" = "$want" ] || fail "app-$ws is $(jq -r '.[0].InstanceType' <<< "$inst"), expected $want."
  [ "$(tag "$inst" Workspace)" = "$ws" ] || fail "app-$ws has no tag Workspace = $ws."
  [ "$(tag "$inst" ArtifactsBucket)" = platform-artifacts ] || fail "app-$ws has no tag ArtifactsBucket = platform-artifacts."
  jq -e '.[0].IamInstanceProfile.Arn // "" | endswith("instance-profile/app-runtime-profile")' <<< "$inst" > /dev/null || fail "app-$ws does not use app-runtime-profile."
  state=$(aws s3 cp "s3://tfstate-lab/envs/$ws/app/terraform.tfstate" - 2> /dev/null) || fail "There is no state for $ws at s3://tfstate-lab/envs/$ws/app/terraform.tfstate."
  [ "$(jq -r '[.resources[] | select(.mode == "managed" and .type == "aws_instance" and .name == "app") | .instances[0].attributes.id] | first // empty' <<< "$state")" = "$(jq -r '.[0].InstanceId' <<< "$inst")" ] \
    || fail "aws_instance.app in the $ws state is not app-$ws."
  TF_WORKSPACE=$ws terraform plan -lock=false -input=false -no-color -detailed-exitcode > "$CHECK_TMP/ws-plan.log" 2>&1 || fail "terraform plan in the workspace $ws is not clean:"$'\n'"$(tail -n 15 "$CHECK_TMP/ws-plan.log")"
done
default=$(aws s3 cp s3://tfstate-lab/app/terraform.tfstate - 2> /dev/null || echo '{}')
[ "$(jq '[.resources[]? | select(.mode == "managed")] | length' <<< "$default")" = 0 ] || fail "The default workspace manages resources."
[ "$(running app-default | jq length)" = 0 ] || fail "app-default is running; the default workspace must not manage any resource."
pass "staging and prod have their own states under envs/ and their instances; default manages nothing."

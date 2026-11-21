source "$LIB"
running() { aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" Name=instance-state-name,Values=pending,running --query 'Reservations[].Instances[]' --output json; }
inst=$(running app-prod)
[ "$(jq length <<< "$inst")" = 1 ] || fail "There is no running instance app-prod to report on."
id=$(jq -r '.[0].InstanceId' <<< "$inst")
cd reports
CHECK_TMP="$CHECK_TMP/reports"; mkdir -p "$CHECK_TMP"
require_init
tf_has 'terraform_remote_state' && fail "reports/ must not use terraform_remote_state."
tf_has "$id|arn:aws:" && fail "reports/ hard-codes the instance ID or an ARN."
tf_has 'data +"aws_instance"' || fail "reports/ does not look the instance up with an aws_instance data source."
[ "$(state_attr aws_s3_object.inventory key)" = inventory/prod.json ] || fail "aws_s3_object.inventory with the key inventory/prod.json is not in the reports/ state."
body=$(aws s3 cp s3://platform-artifacts/inventory/prod.json - 2> /dev/null) || fail "s3://platform-artifacts/inventory/prod.json does not exist."
jq -e . <<< "$body" > /dev/null 2>&1 || fail "inventory/prod.json is not JSON."
[ "$(jq -r .instance_id <<< "$body")" = "$id" ] || fail "instance_id in inventory/prod.json is not the ID of app-prod ($id)."
[ "$(jq -r .instance_type <<< "$body")" = t3.small ] || fail "instance_type in inventory/prod.json is not t3.small."
[ "$(jq -r .role_arn <<< "$body")" = "$(aws iam get-role --role-name app-runtime-role --query Role.Arn --output text)" ] || fail "role_arn in inventory/prod.json is not the ARN of app-runtime-role."
expect_clean_plan
pass "reports/ publishes the prod inventory from data sources without remote state."

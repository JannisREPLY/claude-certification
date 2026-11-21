source "$LIB"
CHECK_TMP="$CHECK_TMP/platform"; mkdir -p "$CHECK_TMP"
cd platform
require_init
[ "$(terraform output -raw instance_profile_name 2> /dev/null)" = app-runtime-profile ] || fail "The output instance_profile_name is missing or not app-runtime-profile in the state."
[ "$(terraform output -raw artifacts_bucket 2> /dev/null)" = platform-artifacts ] || fail "The output artifacts_bucket is missing or not platform-artifacts in the state."
config_json | jq -e '.root_module.outputs.instance_profile_name.expression.references // [] | any(startswith("aws_iam_instance_profile.app"))' > /dev/null || fail "instance_profile_name must reference aws_iam_instance_profile.app."
config_json | jq -e '.root_module.outputs.artifacts_bucket.expression.references // [] | any(startswith("aws_s3_bucket.artifacts"))' > /dev/null || fail "artifacts_bucket must reference aws_s3_bucket.artifacts."
remote=$(aws s3 cp s3://tfstate-lab/platform/terraform.tfstate - 2> /dev/null) || fail "There is no platform state in S3."
[ "$(jq -r '.outputs.instance_profile_name.value // empty' <<< "$remote")" = app-runtime-profile ] || fail "The remote state in S3 has no output instance_profile_name. Did you apply?"
expect_clean_plan
pass "platform/ exposes instance_profile_name and artifacts_bucket in its remote state."

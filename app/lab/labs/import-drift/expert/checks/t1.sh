source "$LIB"
require_init
[ "$(state_attr aws_instance.legacy_api id)" = "$(cat "$LAB_STATE/instance")" ] || fail "aws_instance.legacy_api is not the instance legacy-api."
[ "$(state_attr aws_security_group.legacy_api id)" = "$(cat "$LAB_STATE/sg")" ] || fail "aws_security_group.legacy_api is not legacy-api-sg."
[ "$(state_attr aws_iam_role.legacy_api name)" = legacy-api-role ] || fail "aws_iam_role.legacy_api is not legacy-api-role."
[ "$(state_attr aws_iam_instance_profile.legacy_api name)" = legacy-api-profile ] || fail "aws_iam_instance_profile.legacy_api is not legacy-api-profile."
refs() { config_json | jq -r --arg a "$1" --arg k "$2" '.root_module.resources[] | select(.address==$a) | .expressions[$k].references // [] | join(" ")'; }
refs aws_instance.legacy_api vpc_security_group_ids | grep -q 'aws_security_group.legacy_api' || fail "The instance must reference aws_security_group.legacy_api."
refs aws_instance.legacy_api iam_instance_profile | grep -q 'aws_iam_instance_profile.legacy_api' || fail "The instance must reference aws_iam_instance_profile.legacy_api."
refs aws_iam_instance_profile.legacy_api role | grep -q 'aws_iam_role.legacy_api' || fail "The instance profile must reference aws_iam_role.legacy_api."
for a in aws_instance.legacy_api aws_security_group.legacy_api aws_iam_role.legacy_api aws_iam_instance_profile.legacy_api; do expect_no_changes "$a"; done
pass "All four legacy resources are managed, linked by references and unchanged."

source "$LIB"
require_init
for n in 1 2; do
  want=$(cat "$LAB_STATE/web-$n")
  [ "$(state_attr "aws_instance.web[\"web-$n\"]" id)" = "$want" ] || fail "aws_instance.web[\"web-$n\"] should be in state with the ID $want (nw-bf-web-$n)."
done
[ "$(state_attr aws_security_group.web id)" = "$(cat "$LAB_STATE/sg")" ] || fail "aws_security_group.web should be in state with the ID of nw-bf-web-sg."
[ "$(state_attr aws_iam_role.web unique_id)" = "$(cat "$LAB_STATE/role-id")" ] || fail "aws_iam_role.web should be in state as the existing role nw-bf-web-role."
[ "$(state_attr aws_iam_instance_profile.web unique_id)" = "$(cat "$LAB_STATE/profile-id")" ] || fail "aws_iam_instance_profile.web should be in state as the existing profile nw-bf-web-profile."
tf_has 'import *\{' || fail "No import block found."
refs() { config_json | jq -r --arg a "$1" --arg k "$2" '.root_module.resources[] | select(.address == $a) | .expressions[$k].references // [] | .[]'; }
grep -qx 'aws_security_group.web.id' <<< "$(refs aws_instance.web vpc_security_group_ids)" || fail "vpc_security_group_ids of aws_instance.web must reference aws_security_group.web.id."
grep -q '^aws_iam_instance_profile.web' <<< "$(refs aws_instance.web iam_instance_profile)" || fail "iam_instance_profile of aws_instance.web must reference aws_iam_instance_profile.web."
grep -q '^aws_iam_role.web' <<< "$(refs aws_iam_instance_profile.web role)" || fail "role of aws_iam_instance_profile.web must reference aws_iam_role.web."
for a in 'aws_instance.web["web-1"]' 'aws_instance.web["web-2"]' aws_security_group.web aws_iam_role.web aws_iam_instance_profile.web; do
  expect_no_changes "$a"
done
rules=$(aws ec2 describe-security-groups --group-ids "$(cat "$LAB_STATE/sg")" --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`] | length(@)' --output text)
[ "$rules" = 1 ] || fail "The HTTPS (443) ingress rule of nw-bf-web-sg is gone."
pass "The dispatch web tier is managed and unchanged."

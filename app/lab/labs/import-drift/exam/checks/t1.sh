source "$LIB"
require_init
want=$(cat "$LAB_STATE/instance")
[ "$(state_attr aws_instance.legacy_api id)" = "$want" ] || fail "aws_instance.legacy_api should be in state with the ID $want."
[ "$(state_attr aws_iam_role.legacy_api name)" = legacy-api-role ] || fail "aws_iam_role.legacy_api is not in state with the role legacy-api-role."
tf_has 'import *\{' || fail "No import block found."
expect_no_changes aws_instance.legacy_api
expect_no_changes aws_iam_role.legacy_api
pass "The instance and the role are managed and unchanged."

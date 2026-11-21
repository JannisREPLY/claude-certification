source "$LIB"
require_init
[ "$(state_attr aws_iam_role.legacy_api name)" = legacy-api-role ] || fail "aws_iam_role.legacy_api is not in state with the role legacy-api-role."
tf_has 'import *\{' || fail "No import block found."
expect_no_changes aws_iam_role.legacy_api
pass "legacy-api-role is managed as aws_iam_role.legacy_api."

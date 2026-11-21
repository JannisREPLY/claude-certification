source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
sg=$(cat "$LAB_STATE/sg")
west=$(state_attr aws_security_group.web_west id)
[ -n "$west" ] || fail "Create aws_security_group.web_west first."
for t in ManagedBy:terraform Project:reports; do
  expect_tag "${t%%:*}" "${t#*:}" bucket:acme-reports-east bucket:acme-reports-west "sg:$sg" "sg:$west@us-west-2"
done
tf_has 'default_tags' || fail "Use default_tags in the provider configurations."
expect_originals
expect_clean_plan
pass "Every resource in both regions carries ManagedBy = terraform and Project = reports, and the plan is clean."

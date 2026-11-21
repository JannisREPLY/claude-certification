source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
for app in orders billing; do
  expect_addresses "module.iam[\"$app\"].aws_iam_role.this" "module.iam[\"$app\"].aws_iam_instance_profile.this" \
    "module.compute[\"$app\"].aws_launch_template.this" "module.compute[\"$app\"].aws_autoscaling_group.this"
  [ "$(state_attr "module.iam[\"$app\"].aws_iam_role.this" name)" = "$app-app" ] || fail "module.iam[\"$app\"] does not hold the role $app-app."
done
expect_no_old_module
[ ! -e modules/app ] || fail "The folder modules/app still exists."
expect_ref compute instance_profile_name module.iam
[ "$(state_json | jq -c '.values.outputs.asg_names.value // empty')" = '{"billing":"billing-app","orders":"orders-app"}' ] \
  || fail "The root output asg_names should map orders and billing to their Auto Scaling group names."
expect_original_resources
pass "Both applications are split into module.iam and module.compute."

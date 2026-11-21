source "$LAB_DIR/helpers.sh"
before=$(released stable)
v=$(new_version 1.4)
run_ci "$v" TF_VAR_channel=beta
[ "$CI_RC" = 3 ] || fail "With TF_VAR_channel=beta the plan replaces aws_s3_object.release; ci.sh must exit 3, not $CI_RC:"$'\n'"$(ci_tail)"
[ -z "$(released beta)" ] || fail "ci.sh applied a plan that replaces aws_s3_object.release."
[ "$(released stable)" = "$before" ] || fail "ci.sh changed stable/release.json although the plan replaces it."
[ -f "$WS/ci.tfplan.json" ] || fail "ci.sh did not write ci.tfplan.json."
jq -e "[.resource_changes[] | select(.address == \"aws_s3_object.release\") | .change.actions | index(\"delete\")] | first != null" "$WS/ci.tfplan.json" > /dev/null 2>&1 \
  || fail "ci.tfplan.json is not the JSON plan of the replacement (terraform show -json ci.tfplan)."
run_ci "$v"
expect_ci_ok "$v"
[ "$(jq -r .variables.app_version.value "$WS/ci.tfplan.json" 2> /dev/null)" = "$v" ] || fail "ci.sh did not write ci.tfplan.json for a normal release."
pass "ci.sh writes ci.tfplan.json and blocks plans that delete or replace resources."

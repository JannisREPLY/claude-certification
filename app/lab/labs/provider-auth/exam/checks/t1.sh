source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_no_secrets
expect_provider_auth aws
[ "$(output_value caller_arn)" = "arn:aws:sts::$ACCOUNT:assumed-role/terraform-deploy/terraform" ] || fail "caller_arn is '$(output_value caller_arn)', not the session terraform of the role terraform-deploy."
[ "$(output_value issuer_arn)" = "arn:aws:iam::$ACCOUNT:role/terraform-deploy" ] || fail "issuer_arn is '$(output_value issuer_arn)', not the role terraform-deploy."
expect_output_ref caller_arn data.aws_caller_identity
expect_output_ref issuer_arn data.aws_iam_session_context
pass "The provider uses the profile ci and assumes terraform-deploy."

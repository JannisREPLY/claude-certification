source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_no_secrets
expect_provider_auth aws profile-only
caller=$(output_value caller_arn)
[ -n "$caller" ] || fail "There is no root output caller_arn. Did you apply?"
expect_output_ref caller_arn data.aws_caller_identity
[[ "$caller" != *user/moto ]] || fail "caller_arn is $caller: the provider still uses the environment credentials."
pass "The provider authenticates with the profile ci (caller: $caller)."

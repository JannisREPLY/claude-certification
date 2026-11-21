source "$LIB"
[ -f .terraform.lock.hcl ] || fail "There is no .terraform.lock.hcl."
ver=$(awk '/provider "registry.terraform.io\/hashicorp\/aws"/ {f=1} f && $1 == "version" {gsub(/"/, "", $3); print $3; exit}' .terraform.lock.hcl)
[ -n "$ver" ] || fail "The lock file has no entry for hashicorp/aws."
IFS=. read -r major minor _ <<< "$ver"
[ "$major" = 5 ] && [ "$minor" -ge 80 ] || fail "The lock file selects hashicorp/aws $ver, which does not match ~> 5.80."
grep -qE 'version *= *"~> *5\.80"' <<< "$(cat ./*.tf)" || fail "The root module no longer uses the constraint ~> 5.80."
mod=$(tf_files modules/backup)
grep -q 'required_providers' <<< "$mod" && grep -q 'hashicorp/aws' <<< "$mod" || fail "modules/backup must declare hashicorp/aws in required_providers."
grep -qE 'version *= *"[^"]*4\.' <<< "$mod" && fail "modules/backup still requires AWS provider 4.x."
[ -d .terraform ] || fail "Run terraform init first."
require_init
expect_no_changes aws_s3_bucket.primary
expect_no_changes aws_security_group.app
[ "$(state_attr aws_security_group.app id)" = "$(cat "$LAB_STATE/sg-id")" ] || fail "aws_security_group.app was recreated."
pass "terraform init works with hashicorp/aws $ver."

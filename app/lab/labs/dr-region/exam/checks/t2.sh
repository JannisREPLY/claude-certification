source "$LIB"
require_init
acct=$(aws sts get-caller-identity --query Account --output text)
bucket=nw-dr-backup-$acct
mod=$(tf_files modules/backup)
grep -q 'configuration_aliases' <<< "$mod" || fail "modules/backup does not declare configuration_aliases."
grep -qE '^\s*provider\s+"aws"' <<< "$mod" && fail "modules/backup must not contain a provider block."
grep -qE 'alias\s*=\s*"dr"' <<< "$(cat ./*.tf)" || fail "The root module has no provider configuration with alias = \"dr\"."
grep -qE 'aws\.dr\s*=\s*aws\.dr' <<< "$(cat ./*.tf)" || fail "module.backup does not receive aws.dr through providers."
tf_has 'data +"aws_caller_identity"' modules/backup || tf_has 'data +"aws_caller_identity"' || fail "No aws_caller_identity data source found."
tf_has "$acct" && fail "The account ID is hard-coded."
[ "$(state_attr module.backup.aws_s3_bucket.backup bucket)" = "$bucket" ] || fail "module.backup.aws_s3_bucket.backup is not in state with the name $bucket."
loc=$(aws s3api get-bucket-location --bucket "$bucket" --query LocationConstraint --output text 2> /dev/null) || fail "The bucket $bucket does not exist."
[ "$loc" = us-west-2 ] || fail "$bucket is in $loc, expected us-west-2."
[ "$(state_attr module.backup.aws_s3_object.manifest key)" = manifest.json ] || fail "module.backup.aws_s3_object.manifest with the key manifest.json is not in state."
body=$(aws s3 cp "s3://$bucket/manifest.json" - 2> /dev/null) || fail "s3://$bucket/manifest.json does not exist."
[ "$(jq -r .primary_bucket <<< "$body" 2> /dev/null)" = nw-dr-primary-data ] || fail "manifest.json does not contain {\"primary_bucket\": \"nw-dr-primary-data\"}."
expect_no_changes module.backup.aws_s3_bucket.backup
expect_no_changes module.backup.aws_s3_object.manifest
pass "$bucket exists in us-west-2 with manifest.json."

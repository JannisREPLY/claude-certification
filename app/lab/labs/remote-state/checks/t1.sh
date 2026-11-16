source "$LIB"
cd network
[ -f .terraform/terraform.tfstate ] || fail "network/ has no backend configured."
read -r type bucket key table encrypt <<< "$(jq -r '[.backend.type, .backend.config.bucket, .backend.config.key, .backend.config.dynamodb_table, .backend.config.encrypt] | map(tostring) | join(" ")' .terraform/terraform.tfstate)"
[ "$type" = "s3" ] || fail "network/ uses the $type backend, not s3."
[ "$bucket/$key" = "tfstate-lab/network/terraform.tfstate" ] || fail "State goes to $bucket/$key, expected tfstate-lab/network/terraform.tfstate."
[ "$table" = "tf-locks" ] || fail "State locking uses table '$table', expected tf-locks."
[ "$encrypt" = "true" ] || fail "Encryption is not enabled."
vpc=$(cat "$LAB_STATE/vpc")
aws s3 cp s3://tfstate-lab/network/terraform.tfstate - 2>/dev/null | grep -q "$vpc" || fail "The state in S3 doesn't contain the original VPC $vpc."
n=$(aws ec2 describe-vpcs --vpc-ids "$vpc" --query 'length(Vpcs)' --output text 2>/dev/null) && [ "$n" = "1" ] || fail "The original VPC $vpc is gone."
[ ! -s terraform.tfstate ] || ! jq -e '.resources | length > 0' terraform.tfstate > /dev/null || fail "network/terraform.tfstate still holds resources; the local state looks like it's still in use."
pass "network state is in S3 with locking and encryption."

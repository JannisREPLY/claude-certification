source "$LIB"
[ -f .terraform/terraform.tfstate ] || fail "No backend is configured. Run terraform init."
cfg=$(jq -c '.backend.config + {type: .backend.type}' .terraform/terraform.tfstate)
[ "$(jq -r '"\(.type) \(.bucket)/\(.key) \(.region) \(.dynamodb_table) \(.encrypt)"' <<< "$cfg")" = "s3 nw-bf-tfstate/brownfield/terraform.tfstate us-east-1 nw-bf-tf-locks true" ] \
  || fail "The backend is $(jq -r '"\(.type) \(.bucket)/\(.key) \(.region) table \(.dynamodb_table) encrypt \(.encrypt)"' <<< "$cfg"), expected s3 nw-bf-tfstate/brownfield/terraform.tfstate us-east-1, table nw-bf-tf-locks, encrypt true."
remote=$(aws s3 cp s3://nw-bf-tfstate/brownfield/terraform.tfstate - 2> /dev/null) || fail "There is no state at s3://nw-bf-tfstate/brownfield/terraform.tfstate."
jq -e '[.resources[] | select(.mode == "managed")] | length > 0' <<< "$remote" > /dev/null || fail "The state in S3 holds no resources."
item=$(aws dynamodb get-item --table-name nw-bf-tf-locks --key '{"LockID":{"S":"nw-bf-tfstate/brownfield/terraform.tfstate-md5"}}' --query Item.LockID.S --output text)
[ "$item" = nw-bf-tfstate/brownfield/terraform.tfstate-md5 ] || fail "nw-bf-tf-locks has no digest for the state; it was not written with locking."
[ -s terraform.tfstate ] && jq -e '.resources | length > 0' terraform.tfstate > /dev/null && fail "terraform.tfstate still holds resources. Delete the old local state."
require_init
expect_clean_plan
pass "The state is in S3 with locking and encryption, and the plan is clean."

source "$LIB"
require_init
tf_has 'dynamic\s+"statement"' || fail "No dynamic \"statement\" block found."
tf_has 'jsondecode\(' || fail "policy.json must be read with jsondecode."
arn=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='nw-fw-app-policy'].Arn | [0]" --output text)
[ -n "$arn" ] && [ "$arn" != None ] || fail "The IAM policy nw-fw-app-policy does not exist."
[ "$(state_attr aws_iam_policy.app arn)" = "$arn" ] || fail "aws_iam_policy.app should be the policy nw-fw-app-policy."
ver=$(aws iam get-policy --policy-arn "$arn" --query Policy.DefaultVersionId --output text)
norm='[.[] | {sid: (.Sid // .sid), effect: (.Effect // .effect), actions: ((.Action // .actions) | if type == "string" then [.] else . end | sort), resources: ((.Resource // .resources) | if type == "string" then [.] else . end | sort)}] | sort_by(.sid)'
got=$(aws iam get-policy-version --policy-arn "$arn" --version-id "$ver" --query PolicyVersion.Document --output json | jq -c 'if type == "string" then fromjson else . end | .Statement | if type == "object" then [.] else . end' | jq -c "$norm")
want=$(jq -c "$norm" "$LAB_DIR/files/policy.json")
[ "$got" = "$want" ] || fail "nw-fw-app-policy does not contain one statement per entry of policy.json:"$'\n'"$got"
out() { state_json | jq -c --arg o "$1" '.values.outputs[$o].value'; }
[ "$(out tcp_ports)" = "[22,80,443,8080,9100]" ] || fail "tcp_ports should be [22,80,443,8080,9100] (numbers), got $(out tcp_ports)."
[ "$(out public_rule_names)" = '["http-public","https-public"]' ] || fail "public_rule_names should be [\"http-public\",\"https-public\"], got $(out public_rule_names)."
want_ips=$(aws ec2 describe-instances --filters Name=tag:Name,Values=nw-fw-web-a,nw-fw-web-b Name=instance-state-name,Values=running --output json \
  | jq -cS '[.Reservations[].Instances[] | {key: (.Tags[] | select(.Key == "Name") | .Value | ltrimstr("nw-fw-")), value: .PrivateIpAddress}] | from_entries')
[ "$(out instance_private_ips | jq -cS .)" = "$want_ips" ] || fail "instance_private_ips should be $want_ips, got $(out instance_private_ips)."
expect_clean_plan
pass "The policy follows policy.json, the outputs are correct and the plan is clean."

source "$LIB"
require_init
ensure_plan
grep -qE 'version *= *"5\.' <<< "$(grep -A1 'provider "registry.terraform.io/hashicorp/aws"' .terraform.lock.hcl 2> /dev/null)" || fail "The AWS provider in .terraform.lock.hcl is not 5.x."
tf_has 'csvdecode\(' || fail "rules.csv must be read with csvdecode."
sg=$(aws ec2 describe-security-groups --filters Name=group-name,Values=nw-fw-app --query 'SecurityGroups[].GroupId' --output text)
[ -n "$sg" ] && [ "$(wc -w <<< "$sg")" = 1 ] || fail "There should be exactly one security group nw-fw-app in AWS."
[ "$(state_attr aws_security_group.app id)" = "$sg" ] || fail "aws_security_group.app should be in state with the ID $sg."
want_keys=$(tail -n +2 "$LAB_DIR/files/rules.csv" | cut -d, -f1 | sort)
got_keys=$(addresses | sed -n 's/^aws_vpc_security_group_ingress_rule\.app\["\(.*\)"\]$/\1/p' | sort)
[ "$got_keys" = "$want_keys" ] || fail "aws_vpc_security_group_ingress_rule.app should have one instance per name in rules.csv. Keys in state: $(echo $got_keys)"
want=$(tail -n +2 "$LAB_DIR/files/rules.csv" | awk -F, '{c = $4 == "admin" ? "10.20.0.0/16" : $4; print $2 "|" $3 "|" $3 "|" c "|" $5}' | sort)
got=$(aws ec2 describe-security-group-rules --filters Name=group-id,Values="$sg" --output json \
  | jq -r '.SecurityGroupRules[] | select(.IsEgress | not) | "\(.IpProtocol)|\(.FromPort)|\(.ToPort)|\(.CidrIpv4)|\(.Description)"' | sort)
[ "$got" = "$want" ] || fail "The ingress rules of nw-fw-app in AWS do not match rules.csv:"$'\n'"$got"
pass "nw-fw-app has one ingress rule per row of rules.csv, keyed by name."

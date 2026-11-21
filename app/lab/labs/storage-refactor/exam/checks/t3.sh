source "$LIB"
require_init
src=$(jq -r '.Modules[]? | select(.Key == "labels") | .Source' .terraform/modules/modules.json 2> /dev/null || true)
grep -q 'nw-sto-tagging\.git' <<< "$src" || fail "module.labels is not installed from /home/coder/git/nw-sto-tagging.git. Run terraform init."
grep -q 'ref=v1\.2\.0$' <<< "$src" || fail "module.labels must be pinned to ref=v1.2.0 (source: ${src:-none})."
cfg=$(config_json)
for m in storage access; do
  jq -e --arg m "$m" '.root_module.module_calls[$m].expressions.tags.references // [] | index("module.labels.tags")' <<< "$cfg" > /dev/null \
    || fail "The input tags of module.$m must reference module.labels.tags."
done
want='{"Company":"Northwind Logistics","DataClass":"internal","Environment":"prod","ManagedBy":"terraform","Team":"storage"}'
norm() { jq -cS 'map({(.Key): .Value}) | add // {}'; }
for b in nw-sto-manifests nw-sto-invoices nw-sto-archive; do
  got=$(aws s3api get-bucket-tagging --bucket "$b" --query TagSet --output json 2> /dev/null | norm)
  [ "$got" = "$want" ] || fail "Tags of $b are $got, expected $want."
done
got=$(aws iam list-role-tags --role-name nw-sto-reader --query Tags --output json | norm)
[ "$got" = "$want" ] || fail "Tags of the role nw-sto-reader are $got, expected $want."
arn=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='nw-sto-read'].Arn | [0]" --output text)
got=$(aws iam list-policy-tags --policy-arn "$arn" --query Tags --output json | norm)
[ "$got" = "$want" ] || fail "Tags of the policy nw-sto-read are $got, expected $want."
pass "module.labels v1.2.0 tags the buckets, the policy and the role."

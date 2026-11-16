source "$LIB"
require_init
read -r vpc s0 s1 sg < <(xargs < "$LAB_STATE/ids")
src=$(jq -r '.Modules[]? | select(.Key == "web_sg") | .Source' .terraform/modules/modules.json 2>/dev/null)
[ -n "$src" ] || fail "module.web_sg is not installed. Did you run terraform init?"
[[ "$src" == git::file:///home/coder/repos/web-sg* ]] || fail "module.web_sg comes from $src, not the platform Git repository."
[[ "$src" == *"ref=v1.1.0"* ]] || fail "module.web_sg is not pinned to the right version (source: $src)."
[ "$(state_attr module.web_sg.aws_security_group.this id)" = "$sg" ] || fail "module.web_sg.aws_security_group.this is not the original security group $sg."
desc=$(aws ec2 describe-security-groups --group-ids "$sg" --query 'SecurityGroups[0].Description' --output text 2>/dev/null) || fail "The original security group is gone."
[ "$desc" = "Web access" ] || fail "The security group description is '$desc'."
pass "security group is managed by the pinned platform module."

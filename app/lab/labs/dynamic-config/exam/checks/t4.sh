source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
out=$(outputs)
jq -e '.public_tcp_ports.value | map(tonumber) == [443, 8443]' <<< "$out" > /dev/null 2>&1 || fail "public_tcp_ports is $(jq -c '.public_tcp_ports.value // "missing"' <<< "$out"), expected [443, 8443]. Did you apply?"
expect_private_ips "$out" "web-1 web-2 batch"
want=$(jq -nc --arg a "$(state_attr 'aws_instance.app["web-1"]' id)" --arg b "$(state_attr 'aws_instance.app["web-2"]' id)" '[$a, $b]')
[ "$(jq -c '.web_instance_ids.value' <<< "$out")" = "$want" ] || fail "web_instance_ids is $(jq -c '.web_instance_ids.value // "missing"' <<< "$out"), expected $want."
pass "All three outputs are correct."

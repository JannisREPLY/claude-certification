source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
out=$(outputs)
jq -e '.public_tcp_ports.value | map(tonumber) == [443, 8443]' <<< "$out" > /dev/null 2>&1 || fail "public_tcp_ports is $(jq -c '.public_tcp_ports.value // "missing"' <<< "$out"), expected [443, 8443]. Did you apply?"
expect_private_ips "$out" "web-1 web-2 batch"
pass "public_tcp_ports and private_ips are correct."

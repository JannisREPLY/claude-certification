source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
out=$(outputs)
[ "$(jq -c '.public_tcp_ports.value' <<< "$out")" = "[80,443,8080]" ] || fail "public_tcp_ports is $(jq -c '.public_tcp_ports.value // "missing"' <<< "$out"), expected [80,443,8080] as numbers in numeric order. Did you apply?"
[ "$(jq -c '.admin_cidrs.value' <<< "$out")" = '["10.0.0.0/8","198.51.100.0/24"]' ] || fail "admin_cidrs is $(jq -c '.admin_cidrs.value // "missing"' <<< "$out"), expected [\"10.0.0.0/8\",\"198.51.100.0/24\"]."
expect_private_ips "$out" "web-1 web-2 batch"
[ "$(jq -c '.instances_by_role.value' <<< "$out")" = '{"web":["web-1","web-2"],"worker":["batch"]}' ] || fail "instances_by_role is $(jq -c '.instances_by_role.value // "missing"' <<< "$out"), expected {\"web\":[\"web-1\",\"web-2\"],\"worker\":[\"batch\"]}."
pass "All four outputs are correct."

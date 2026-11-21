source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
inputs_unchanged
tf_has 'yamldecode' || fail "Read rules.yaml with yamldecode()."
check_sg "https app ssh syslog" "tcp:443:443:0.0.0.0/0 tcp:8443:8443:0.0.0.0/0 tcp:22:22:10.0.0.0/8 udp:514:514:0.0.0.0/0"
pass "orders-web has one ingress rule per entry of rules.yaml, keyed by name."

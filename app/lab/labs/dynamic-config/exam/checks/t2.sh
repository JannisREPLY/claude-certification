source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
inputs_unchanged
check_sg "https-0.0.0.0/0 https-::/0 app-0.0.0.0/0 app-::/0 app-10.0.0.0/8 ssh-10.0.0.0/8 ssh-192.168.0.0/16 syslog-0.0.0.0/0" \
  "tcp:443:443:0.0.0.0/0 tcp:443:443:::/0 tcp:8443:8443:0.0.0.0/0 tcp:8443:8443:::/0 tcp:8443:8443:10.0.0.0/8 tcp:22:22:10.0.0.0/8 tcp:22:22:192.168.0.0/16 udp:514:514:0.0.0.0/0"
no_hardcoded_ids
pass "orders-web has one ingress rule per rule and CIDR."

source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
inputs_unchanged
tf_has 'csvdecode' || fail "Read partner-rules.csv with csvdecode()."
check_sg "http-0.0.0.0/0 https-0.0.0.0/0 https-::/0 ssh-10.0.0.0/8 syslog-0.0.0.0/0 ephemeral-10.0.0.0/8 partner-api-0.0.0.0/0 partner-api-203.0.113.0/24 partner-ssh-198.51.100.0/24" \
  "tcp:80:80:0.0.0.0/0 tcp:443:443:0.0.0.0/0 tcp:443:443:::/0 tcp:22:22:10.0.0.0/8 udp:514:514:0.0.0.0/0 tcp:32768:60999:10.0.0.0/8 tcp:8080:8080:0.0.0.0/0 tcp:8080:8080:203.0.113.0/24 tcp:22:22:198.51.100.0/24"
no_hardcoded_ids
pass "orders-web merges both rule sources without duplicates."

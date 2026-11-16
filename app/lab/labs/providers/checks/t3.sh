source "$LIB"
require_init
v=$(awk '/provider "registry.terraform.io\/hashicorp\/random"/{f=1} f && /version/{gsub(/"/,"",$3); print $3; exit}' .terraform.lock.hcl)
[[ "$v" == 3.6.* ]] || fail "The lock file pins random $v."
[ "$v" = "3.6.3" ] || fail "random $v is not the newest 3.6.x release."
[ "$(state_attr random_pet.suffix id)" = "$(cat "$LAB_STATE/pet")" ] || fail "random_pet.suffix was recreated."
pass "random is locked to $v."

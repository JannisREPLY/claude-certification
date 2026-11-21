source "$LIB"
source "$LAB_DIR/helpers.sh"
expect_init_works
bad=$(tf_files modules/reports | grep -E '^\s*version\s*=' | grep -vE '"\s*>=' || true)
[ -z "$bad" ] || fail "modules/reports must declare only minimum versions (>=):"$'\n'"$bad"
grep -qE 'version += +"~> 3\.6\.[0-9]+"' <<< "$(root_tf)" || fail "The root constraint for random must allow only 3.6.x patch releases (~> 3.6.0)."
pass "terraform init works with minimum versions in the module and a pessimistic random constraint."

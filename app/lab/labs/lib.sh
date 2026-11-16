set -euo pipefail

fail() { echo "❌ $*"; exit 1; }
pass() { echo "✅ $*"; }

require_init() {
  [ -d .terraform ] || fail "Run terraform init first."
  [ -f "$CHECK_TMP/state.json" ] || terraform show -json -no-color > "$CHECK_TMP/state.json" 2> "$CHECK_TMP/state.log" \
    || fail "terraform show fails:"$'\n'"$(tail -n 20 "$CHECK_TMP/state.log")"
}

ensure_plan() {
  [ -f "$CHECK_TMP/plan.json" ] && return
  terraform plan -lock=false -input=false -no-color -out="$CHECK_TMP/plan.bin" > "$CHECK_TMP/plan.log" 2>&1 \
    || fail "terraform plan fails:"$'\n'"$(tail -n 20 "$CHECK_TMP/plan.log")"
  terraform show -json "$CHECK_TMP/plan.bin" > "$CHECK_TMP/plan.json"
}

state_json() { cat "$CHECK_TMP/state.json"; }

plan_json() { cat "$CHECK_TMP/plan.json"; }

state_attr() {
  state_json | jq -r --arg a "$1" --arg k "$2" '[.values.root_module? // {} | .. | objects | select(.address? == $a) | .values[$k]] | first // empty'
}

plan_actions() {
  plan_json | jq -r --arg a "$1" '[.resource_changes[]? | select(.address == $a) | .change.actions | join(",")] | first // "absent"'
}

expect_no_changes() {
  local actions
  ensure_plan
  actions=$(plan_actions "$1")
  [ "$actions" = "no-op" ] || fail "terraform plan wants to change $1 (actions: $actions)."
}

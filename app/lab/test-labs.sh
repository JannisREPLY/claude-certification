#!/usr/bin/env bash
# Usage: lab/test-labs.sh [lab[:level] ...] | --exam   (stack must be running; COMPOSE_PROJECT_NAME selects the stack)
# Per level: every task fails before solutions/<lab>/<level>.sh and passes after it.
# solutions/<lab>/<level>.wrong-<task>.sh: after this wrong solution, <task> must fail.
set -uo pipefail
cd "$(dirname "$0")"
rc=0

in_lab() { docker compose -f ../compose.yaml exec -T lab bash -c "$1"; }
api() { in_lab "curl -s -XPOST localhost:7000/$1"; }
docker compose -f ../compose.yaml exec -T -u root lab bash -c "rm -rf /opt/labs/*"
docker compose -f ../compose.yaml cp labs/. lab:/opt/labs > /dev/null

results() { api "labs/$1/$2/check" | jq -r '.results[] | "\(.id) \(.ok)"'; }

test_level() {
  local lab=$1 level=$2 dir=/home/coder/lab
  echo "== $lab:$level"
  api "labs/$lab/$level/start?force=1" | jq -e .ok > /dev/null || { echo "setup failed:"; api "labs/$lab/$level/start?force=1" | jq -r .output | tail -20; rc=1; return; }
  local before after
  before=$(results "$lab" "$level")
  echo "$before" | grep -q ' true$' && { echo "passes before solving:"; echo "$before" | grep ' true$'; rc=1; }
  for wrong in solutions/$lab/$level.wrong-*.sh; do
    [ -f "$wrong" ] || continue
    local task=${wrong##*.wrong-}; task=${task%.sh}
    api "labs/$lab/$level/start?force=1" > /dev/null
    in_lab "cd $dir && bash -s" < "$wrong" > "/tmp/wrong-$lab-$level-$task.log" 2>&1
    results "$lab" "$level" | grep -qx "$task false" && echo "ok: $task fails after $(basename "$wrong")" || { echo "$task passes after $(basename "$wrong")"; rc=1; }
    api "labs/$lab/$level/start?force=1" > /dev/null
  done
  in_lab "cd $dir && bash -s" < "solutions/$lab/$level.sh" > "/tmp/solution-$lab-$level.log" 2>&1 || { echo "solution failed, see /tmp/solution-$lab-$level.log"; rc=1; }
  after=$(results "$lab" "$level")
  if [ -z "$after" ] || echo "$after" | grep -q ' false$'; then
    echo "fails after solving:"; api "labs/$lab/$level/check" | jq -r '.results[] | select(.ok | not) | "\(.id): \(.output)"'; rc=1
  else
    echo "ok: $(echo "$after" | wc -l | tr -d ' ') tasks fail before and pass after the solution"
  fi
}

test_exam() {
  echo "== mock exam"
  local start labs before after
  start=$(api "exam/start")
  echo "$start" | jq -e .ok > /dev/null || { echo "exam setup failed: $(echo "$start" | jq -r .output | tail -20)"; rc=1; return; }
  labs=$(echo "$start" | jq -r '.labs[]')
  local practice
  practice=$(ls labs | grep -v lib.sh | while read -r l; do [ "$(jq -r '.mock // false' "labs/$l/lab.json")" = false ] && echo "$l" && break; done)
  [ "$(api "labs/$practice/exam/start" | jq -r .error)" != null ] && echo "ok: practice lab start is blocked during the exam" || { echo "practice lab start not blocked"; rc=1; }
  before=$(api "exam/check" | jq -r '.labs | to_entries[] | .key as $l | .value[] | "\($l):\(.id) \(.ok)"')
  echo "$before" | grep -q ' true$' && { echo "passes before solving:"; echo "$before" | grep ' true$'; rc=1; }
  for lab in $labs; do
    in_lab "cd /home/coder/exam/$lab && bash -s" < "solutions/$lab/exam.sh" > "/tmp/solution-$lab-exam.log" 2>&1 || { echo "$lab solution failed, see /tmp/solution-$lab-exam.log"; rc=1; }
  done
  after=$(api "exam/check" | jq -r '.labs | to_entries[] | .key as $l | .value[] | "\($l):\(.id) \(.ok) \(.output | split("\n") | last)"')
  if echo "$after" | grep -q ' false '; then echo "fails after solving:"; echo "$after" | grep ' false '; rc=1
  else echo "ok: $(echo "$after" | wc -l | tr -d ' ') exam tasks fail before and pass after the solutions"; fi
}

if [ "${1:-}" = "--exam" ]; then test_exam; exit $rc; fi
targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
  for d in labs/*/; do
    [ "$(jq -r '.mock // false' "$d/lab.json")" = true ] && continue
    for level in $(jq -r '.levels | keys[]' "$d/lab.json"); do targets+=("$(basename "$d"):$level"); done
  done
fi
for t in "${targets[@]}"; do
  if [[ $t == *:* ]]; then test_level "${t%%:*}" "${t#*:}"
  else for level in $(jq -r '.levels | keys[]' "labs/$t/lab.json"); do test_level "$t" "$level"; done; fi
done
exit $rc

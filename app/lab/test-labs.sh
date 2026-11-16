#!/usr/bin/env bash
# Usage: lab/test-labs.sh [lab-id ...]  (stack must be running)
set -uo pipefail
cd "$(dirname "$0")"
labs=("$@")
[ ${#labs[@]} -gt 0 ] || labs=($(ls labs | grep -v lib.sh))
rc=0

in_lab() { docker compose -f ../compose.yaml exec -T lab bash -c "$1"; }
check() { in_lab "curl -s -XPOST localhost:7000/labs/$1/check" | jq -r '.results[] | "\(.id) \(.ok)"'; }

for lab in "${labs[@]}"; do
  echo "== $lab"
  in_lab "curl -s -XPOST localhost:7000/labs/$lab/start" | jq -e .ok > /dev/null || { echo "setup failed"; rc=1; continue; }
  before=$(check "$lab")
  echo "$before" | grep -q ' true$' && { echo "passes before solving:"; echo "$before" | grep ' true$'; rc=1; }
  in_lab "cd /home/coder/lab && bash -s" < "solutions/$lab.sh" > /tmp/solution-$lab.log 2>&1 || { echo "solution failed, see /tmp/solution-$lab.log"; rc=1; }
  after=$(check "$lab")
  if echo "$after" | grep -q ' false$'; then
    echo "fails after solving:"; in_lab "curl -s -XPOST localhost:7000/labs/$lab/check" | jq -r '.results[] | select(.ok | not) | "\(.id): \(.output)"'; rc=1
  else
    echo "ok: $(echo "$after" | wc -l | tr -d ' ') tasks fail before and pass after the solution"
  fi
done
exit $rc

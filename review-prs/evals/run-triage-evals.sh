#!/usr/bin/env bash
# Runs triage.sh against evals/triage-cases.json; prints PASS/FAIL per case, exits 1 on any failure.
set -u
here=$(cd "$(dirname "$0")" && pwd)
triage="$here/../scripts/triage.sh"
cases="$here/triage-cases.json"
command -v jq >/dev/null || { echo "jq required"; exit 2; }

fail=0
count=$(jq length "$cases")
i=0
while [ "$i" -lt "$count" ]; do
  name=$(jq -r ".[$i].name" "$cases")
  adds=$(jq -r ".[$i].additions // empty" "$cases")
  dels=$(jq -r ".[$i].deletions // empty" "$cases")
  fcount=$(jq -r ".[$i].files_count // empty" "$cases")
  args=(--json)
  [ -n "$adds" ] && args+=(--additions "$adds")
  [ -n "$dels" ] && args+=(--deletions "$dels")
  [ -n "$fcount" ] && args+=(--files "$fcount")
  got=$(jq -r ".[$i].files[]" "$cases" | "$triage" "${args[@]}")
  want=$(jq -c "{mode: .[$i].expected_mode, agents: (.[$i].expected_agents | sort), passes: (.[$i].expected_passes | sort), size: .[$i].expected_size, split: (.[$i].expected_split // false)}" "$cases")
  have=$(printf '%s' "$got" | jq -c '{mode, agents: (.agents | sort), passes: (.passes | sort), size, split: .recommend_split}')
  if [ "$want" = "$have" ]; then
    echo "PASS $name"
  else
    echo "FAIL $name"
    echo "  want $want"
    echo "  have $have"
    fail=1
  fi
  i=$((i + 1))
done
exit $fail

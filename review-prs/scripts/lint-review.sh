#!/usr/bin/env bash
# Lint a drafted review.md before it is posted. No model, no gh. Read-only.
#
# Usage: lint-review.sh <review.md> [--fetch-dir DIR]
# With --fetch-dir every `path:line` cited in Things to address is checked against the PR head
# (scripts/verify-citations.sh).
#
# FAIL = fix before posting. WARN = judge it. Exit 1 on any FAIL.
#   R1  exactly one "**Review result:** Approved|Changes requested", unless the review is incomplete (R5)
#   R2  the result agrees with the Scoreboard: Approved only with no 🔴 Fail; Changes requested only with one
#   R3  every finding is "- `path:line` - **Sev** - Rule - text" (Suggestion belongs in Suggestions)
#   R4  no finding admits an unverified line ("not re-opened", "diff offset", "as the agents reported")
#   R5  an incomplete review (Not verified says "not completed") carries no result line
#   R6  at most 3 suggestions
#   R7  Scoreboard table and "**Not verified:**" line are present
#   R8  (--fetch-dir) every cited line exists in the PR head
set -u
here=$(cd "$(dirname "$0")" && pwd)
die() { echo "lint-review: $*" >&2; exit 2; }

file="" fetch=""
while [ $# -gt 0 ]; do
  case $1 in
    --fetch-dir) fetch=${2:-}; shift ;;
    *) file=$1 ;;
  esac
  shift
done
[ -n "$file" ] && [ -f "$file" ] || die "usage: lint-review.sh <review.md> [--fetch-dir DIR]"

fails=0
fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }
warn() { echo "WARN $1: $2"; }

# Sections
things=$(awk '/^### Things to address/ { on = 1; next } /^### / { on = 0 } on' "$file")
suggest=$(awk '/^### Suggestions/ { on = 1; next } /^### / || /^\*\*/ || /^<details>/ { on = 0 } on' "$file")
verified=$(grep -i '^\*\*Not verified' "$file" || true)

# R7
grep -q '^### Scoreboard' "$file" && grep -q '^| Category | Status | To address |' "$file" || fail R7 "Scoreboard table (| Category | Status | To address |) is missing"
[ -n "$verified" ] || fail R7 "**Not verified:** line is missing (write \"none\" when nothing is unverified)"

# R1 / R5 / R2
results=$(grep -E '^\*\*Review result:\*\*' "$file" || true)
nres=$(printf '%s' "$results" | grep -c . || true)
incomplete=0
printf '%s' "$verified" | grep -qi 'not completed' && incomplete=1
if [ "$incomplete" = 1 ]; then
  [ "$nres" = 0 ] || fail R5 "Not verified says \"not completed\" but a Review result line is present: an incomplete review is comment-only with no result"
else
  if [ "$nres" != 1 ]; then
    fail R1 "expected exactly one **Review result:** line, found $nres"
  else
    result=$(printf '%s' "$results" | sed -E 's/^\*\*Review result:\*\* *//; s/[[:space:]]+$//')
    case $result in
      Approved | "Changes requested") ;;
      *) fail R1 "Review result must be exactly Approved or Changes requested, got: $result" ;;
    esac
    nfail=$(grep -c '^| .*🔴 Fail' "$file" || true)
    [ "$result" = Approved ] && [ "$nfail" -gt 0 ] && fail R2 "Approved but the Scoreboard has $nfail 🔴 Fail row(s)"
    [ "$result" = "Changes requested" ] && [ "$nfail" = 0 ] && fail R2 "Changes requested but no Scoreboard row is 🔴 Fail"
  fi
fi

# R3: top-level bullets under Things to address
n=0
while IFS= read -r line; do
  case $line in "- "*) ;; *) continue ;; esac
  n=$((n + 1))
  head=${line%% - \*\*[CHML]*}
  if ! printf '%s' "$line" | grep -qE ' - \*\*(Critical|High|Medium|Low)\*\* - (Rule|Suggestion) - ' || ! printf '%s' "$head" | grep -q '`[^`][^`]*`'; then
    fail R3 "bad finding format, want: - \`path:line\` - **Severity** - Rule - text: $(printf '%s' "$line" | cut -c1-120)"
  elif printf '%s' "$line" | grep -qE '\*\* - Suggestion - '; then
    fail R3 "a Suggestion is under Things to address (move it to Suggestions): $(printf '%s' "$line" | cut -c1-100)"
  elif ! printf '%s' "$head" | grep -qE '`[^`]*:[0-9]+'; then
    warn R3 "no line number (fine only for a file-level finding): $(printf '%s' "$line" | cut -c1-100)"
  fi
done <<EOF
$things
EOF

# R4
bad=$(grep -n -i -E 'not re-?opened|did not re-?open|without a re-?open|diff offsets?|offset [0-9]+|as the agents? reported|line not verified|unverified line' "$file" || true)
[ -z "$bad" ] || fail R4 "a finding or note admits an unverified line (verify it with scripts/verify-citations.sh, or drop it and list it under Not verified): $(printf '%s' "$bad" | head -1 | cut -c1-140)"

# R6
ns=$(printf '%s\n' "$suggest" | grep -c '^- ' || true)
[ "$ns" -le 3 ] || fail R6 "$ns suggestions, the cap is 3"

# R8
if [ -n "$fetch" ]; then
  cites=$(printf '%s\n' "$things" | awk '/^- / { i = index($0, " - **"); h = (i ? substr($0, 1, i) : $0); while (match(h, /`[^`]+`/)) { c = substr(h, RSTART + 1, RLENGTH - 2); if (c ~ /:[0-9]+(-[0-9]+)?$/) print c; h = substr(h, RSTART + RLENGTH) } }')
  if [ -n "$cites" ]; then
    out=$(printf '%s\n' "$cites" | "$here/verify-citations.sh" "$fetch" 2>&1); rc=$?
    if [ "$rc" -ne 0 ]; then
      printf '%s\n' "$out" | grep -E '^(BAD|MISMATCH|UNVERIFIABLE)' | while IFS= read -r l; do echo "FAIL R8: $l"; done
      fails=$((fails + 1))
    fi
  fi
fi

if [ "$fails" -eq 0 ]; then echo "PASS lint-review: $n finding(s) checked"; exit 0; fi
echo "lint-review: $fails failure(s)"
exit 1

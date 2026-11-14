#!/usr/bin/env bash
# Split a fetched PR into manageable review units. No model, no gh. Read-only on the fetch dir except units/.
# Usage: split-pr.sh <fetch-dir>
# Needs <fetch-dir>/{stats.txt,pr.diff} (written by fetch-pr.sh).
# Writes <fetch-dir>/units/<id>/{files.txt,stats.txt,pr.diff,plan.txt} and units/index.txt; prints the index.
# Units pack files in path order (siblings, specs and templates stay together), closing a unit at the caps
# or at a directory boundary once it is 60% full. Docs/config/assets go to one trailing "misc" unit.
# Env: SPLIT_MAX_ADDS (600), SPLIT_MAX_FILES (20), SPLIT_MAX_UNITS (12).
# Exit 3 = more units than SPLIT_MAX_UNITS: too big even to chunk, ask the author to split.
set -u
die() { echo "split-pr: $*" >&2; exit 1; }

dir=${1:-}
[ -n "$dir" ] && [ -f "$dir/stats.txt" ] && [ -f "$dir/pr.diff" ] || die "usage: split-pr.sh <fetch-dir> (needs stats.txt and pr.diff)"
here=$(cd "$(dirname "$0")" && pwd)
MAXA=${SPLIT_MAX_ADDS:-600}; MAXF=${SPLIT_MAX_FILES:-20}; MAXU=${SPLIT_MAX_UNITS:-12}

rm -rf "${dir:?}/units"; mkdir -p "$dir/units"

# unit-id <TAB> path
LC_ALL=C sort -t$'\t' -k1,1 "$dir/stats.txt" | awk -F'\t' -v MAXA="$MAXA" -v MAXF="$MAXF" '
  BEGIN { u = 1; n = 0; adds = 0; prev = "" }
  $1 == "" { next }
  {
    path = $1; a = substr($2, 2) + 0; lp = tolower(path)
    if (lp ~ /\.(md|mdx|json|ya?ml|txt|lock|svg|png|jpg|jpeg|gif|ico|woff2?|ttf)$/) { printf "99\t%s\n", path; next }
    ns = split(path, seg, "/"); key = ""
    for (i = 1; i <= 5 && i < ns; i++) key = key seg[i] "/"
    if (n > 0 && (n >= MAXF || adds + a > MAXA || (adds >= MAXA * 0.6 && key != prev))) { u++; n = 0; adds = 0 }
    n++; adds += a; prev = key
    printf "%02d\t%s\n", u, path
  }' >"$dir/units/assign.tsv"

[ -s "$dir/units/assign.tsv" ] || die "no files to split"
ids=$(cut -f1 "$dir/units/assign.tsv" | sort -u)
count=$(printf '%s\n' "$ids" | grep -vc '^99$')
if [ "$count" -gt "$MAXU" ]; then
  echo "TOO_MANY_UNITS: $count code units (max $MAXU); ask the author to split the PR"
  exit 3
fi

: >"$dir/units/index.txt"
for id in $ids; do
  name="unit-$id"; [ "$id" = 99 ] && name="unit-misc"
  ud="$dir/units/$name"; mkdir -p "$ud"
  awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$dir/units/assign.tsv" >"$ud/files.txt"
  awk -F'\t' -v list="$ud/files.txt" 'BEGIN { while ((getline l < list) > 0) want[l] = 1 } ($1 in want)' "$dir/stats.txt" >"$ud/stats.txt"
  awk -v list="$ud/files.txt" 'BEGIN { while ((getline l < list) > 0) want[l] = 1 }
    /^diff --git / { f = $4; sub(/^b\//, "", f); on = (f in want) } on { print }' "$dir/pr.diff" >"$ud/pr.diff"
  read -r adds dels nfiles < <(awk -F'\t' '{ a += substr($2, 2); d += substr($3, 2); n++ } END { print a + 0, d + 0, n + 0 }' "$ud/stats.txt")
  "$here/triage.sh" --unit --additions "$adds" --deletions "$dels" --files "$nfiles" <"$ud/files.txt" >"$ud/plan.txt"
  printf '%s\tfiles=%s\t+%s\t-%s\t%s\n' "$name" "$nfiles" "$adds" "$dels" "$(head -1 "$ud/plan.txt")" >>"$dir/units/index.txt"
done
# One PR-level simplifier pass (suggestions only): the largest added non-spec code files, none when the PR adds little or is deletion-heavy.
# Same skip rule as triage.sh (added < 30, or added < 20% of added+deleted). Writes units/simplify-files.txt (empty = skip the pass).
read -r tadds tdels < <(awk -F'\t' '{ a += substr($2, 2); d += substr($3, 2) } END { print a + 0, d + 0 }' "$dir/stats.txt")
: >"$dir/units/simplify-files.txt"
if [ "$tadds" -ge 30 ] && [ $((tadds * 5)) -ge $((tadds + tdels)) ]; then
  awk -F'\t' '$1 ~ /\.(ts|html)$/ && $1 !~ /\.(spec|test|d)\.ts$/ { a = substr($2, 2) + 0; if (a >= 30) print a "\t" $1 }' "$dir/stats.txt" | LC_ALL=C sort -t$'\t' -rn -k1,1 | head -5 | cut -f2 >"$dir/units/simplify-files.txt"
fi

echo "Units: $(printf '%s\n' "$ids" | wc -l | tr -d ' ') (fetch dir: $dir; per-unit slice in units/<name>/)"
cat "$dir/units/index.txt"
echo "Simplify: $(grep -c . "$dir/units/simplify-files.txt" || true) file(s) in units/simplify-files.txt (one PR-level pass, 0 = skip)"

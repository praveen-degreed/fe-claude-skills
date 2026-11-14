#!/usr/bin/env bash
# Evals for scripts/verify-citations.sh and scripts/lint-review.sh against evals/fixtures.
# Prints PASS/FAIL per case, exits 1 on any failure. No network, no gh.
set -u
here=$(cd "$(dirname "$0")" && pwd)
verify="$here/../scripts/verify-citations.sh"
lint="$here/../scripts/lint-review.sh"
fx="$here/fixtures/fetch"
rv="$here/fixtures/reviews"
fail=0

# check <name> <expected exit> <expected output substring (or "")> <command...>
check() {
  local name=$1 want_rc=$2 want_out=$3; shift 3
  local out rc
  out=$("$@" 2>&1); rc=$?
  if [ "$rc" = "$want_rc" ] && { [ -z "$want_out" ] || printf '%s' "$out" | grep -qF -- "$want_out"; }; then
    echo "PASS $name"
  else
    echo "FAIL $name (exit $rc, want $want_rc; want output containing: $want_out)"
    printf '%s\n' "$out" | sed 's/^/  /'
    fail=1
  fi
}

S=apps/lxp/src/app/access/audience.service.ts

# verify-citations.sh
check "verify: real line"                         0 "OK $S:11"                 "$verify" "$fx" "$S:11"
check "verify: line range"                        0 "OK $S:20-22"              "$verify" "$fx" "$S:20-22"
check "verify: token near the line"               0 "OK $S:11=MAX_PAGES"       "$verify" "$fx" "$S:11=MAX_PAGES"
check "verify: token far from the line"           1 "MISMATCH $S:19=MAX_PAGES" "$verify" "$fx" "$S:19=MAX_PAGES"
check "verify: mismatch hints the real line"      1 "line(s): 4 12"          "$verify" "$fx" "$S:19=MAX_PAGES"
check "verify: line past end of file"             1 "BAD $S:400"               "$verify" "$fx" "$S:400"
check "verify: file not in the PR"                0 "UNCHECKED apps/lxp/nothing.ts:3" "$verify" "$fx" "apps/lxp/nothing.ts:3"
check "verify: skipped binary"                    1 "UNVERIFIABLE assets/logo.png:1" "$verify" "$fx" "assets/logo.png:1"
check "verify: unique short path resolves"        0 "resolved to apps/lxp/src/app/access/audience.component.ts" "$verify" "$fx" "audience.component.ts:3"
check "verify: ambiguous short path"              1 "ambiguous"                "$verify" "$fx" "audience.service.ts:3"
check "verify: not a number"                      1 "BAD $S:abc"               "$verify" "$fx" "$S:abc"
check "verify: stdin"                             0 "1 ok"                     sh -c "printf '%s\n' '$S:11' | '$verify' '$fx'"
check "verify: --find"                            0 "$S:4:const MAX_PAGES"     "$verify" --find "$fx" "$S" "MAX_PAGES"
check "verify: bad fetch dir"                     2 "usage"                    "$verify" "$here/nope" "x.ts:1"

# lint-review.sh
check "lint: good review"                         0 "PASS lint-review"         "$lint" "$rv/good.md"
check "lint: good review, citations check out"    0 "PASS lint-review"         "$lint" "$rv/good.md" --fetch-dir "$fx"
check "lint: unverified line is posted"           1 "FAIL R4"                  "$lint" "$rv/bad-unverified-line.md"
check "lint: incomplete review with a result"     1 "FAIL R5"                  "$lint" "$rv/bad-incomplete-with-result.md"
check "lint: result disagrees with scoreboard"    1 "FAIL R2"                  "$lint" "$rv/bad-result-mismatch.md"
check "lint: bad finding format"                  1 "FAIL R3"                  "$lint" "$rv/bad-format.md"
check "lint: Suggestion-level label"              1 "Suggestion-level"         "$lint" "$rv/bad-format.md"
check "lint: more than 3 suggestions"             1 "FAIL R6"                  "$lint" "$rv/bad-format.md"
check "lint: cited lines do not exist"            1 "FAIL R8: BAD"             "$lint" "$rv/bad-wrong-line.md" --fetch-dir "$fx"
check "lint: missing file"                        2 "usage"                    "$lint" "$rv/none.md"

# review-scan.sh: seeded fixture (a copy is turned into a git checkout so git grep works)
scan_tmp=$(mktemp -d "${TMPDIR:-/tmp/}scan-eval.XXXXXX")
cp -R "$here/fixtures/scan/checkout" "$scan_tmp/checkout"; cp -R "$here/fixtures/scan/fetch" "$scan_tmp/fetch"
( cd "$scan_tmp/checkout" && git init -q . && git add -A && git -c user.email=t@t -c user.name=t commit -qm fx )
scan="$here/../scripts/review-scan.sh"
"$scan" "$scan_tmp/fetch" "$scan_tmp/checkout" >"$scan_tmp/out.txt" 2>&1
S=apps/lxp/feature/seeded.component.ts
check "scan: duplicate symbol found elsewhere"   0 "new 'formatDuration' is also defined at: libs/shared/core/utils/format.utils.ts" cat "$scan_tmp/out.txt"
check "scan: hand-rolled deep clone"             0 "shared util 'getDeepCopy' exists at libs/shared/core/utils/object.utils.ts" cat "$scan_tmp/out.txt"
check "scan: hand-rolled URL encoding"           0 "shared util 'safeEncodeURIComponent'" cat "$scan_tmp/out.txt"
check "scan: magic number"                       0 "$S:19 magic number 5000" cat "$scan_tmp/out.txt"
check "scan: magic numbers capped per file"      0 "more magic numbers in this file" cat "$scan_tmp/out.txt"
check "scan: repeated string"                    0 "string 'pending-review' repeated 3x" cat "$scan_tmp/out.txt"
check "scan: constants home is the existing file" 0 "existing apps/lxp/feature/feature.constants.ts" cat "$scan_tmp/out.txt"
check "scan: nearby utils not imported"          0 "feature.utils.ts (NOT imported by $S)" cat "$scan_tmp/out.txt"
check "scan: long method"                        0 "veryLongMethod() is 61 lines" cat "$scan_tmp/out.txt"
check "scan: innerHTML"                          0 "XSS sink" cat "$scan_tmp/out.txt"
check "scan: insecure http url"                  0 "insecure http URL" cat "$scan_tmp/out.txt"
check "scan: console output"                     0 "console output" cat "$scan_tmp/out.txt"
check "scan: exported type in a component file"  0 "exported interface SeededRow is declared in a component file" cat "$scan_tmp/out.txt"
check "scan: big pure function in a component file" 0 "module-level pure function buildRowLabel() is 13 lines" cat "$scan_tmp/out.txt"
check "scan: util imports a component (wrong direction)" 0 "placement.utils.ts:1 util file imports from a component file (./seeded.component)" cat "$scan_tmp/out.txt"
check "scan: mostly existing long method is not a lead"   1 "" grep -E "^(HELPER|PLACE)\? .*legacy.service" "$scan_tmp/out.txt"
check "scan: helper lead says how much is added"          0 "veryLongMethod() is 61 lines (61 added)" cat "$scan_tmp/out.txt"
check "scan: lines are verifiable citations"     0 "OK $S:26" "$verify" "$scan_tmp/fetch" "$S:26=innerHTML"
check "scan: no checkout still runs"             0 "no checkout: not scanned" "$scan" "$scan_tmp/fetch"
check "scan: bad fetch dir"                      1 "usage" "$scan" "$here/nope"
rm -rf "$scan_tmp"

# split-pr.sh: PR-level simplifier file selection
sp_tmp=$(mktemp -d "${TMPDIR:-/tmp/}split-eval.XXXXXX")
split="$here/../scripts/split-pr.sh"
mkstats() { # <dir> then "path adds dels" triples on stdin
  mkdir -p "$1"; : >"$1/stats.txt"; : >"$1/pr.diff"
  while read -r p a d; do
    printf '%s\t+%s\t-%s\toffset 1\n' "$p" "$a" "$d" >>"$1/stats.txt"
    printf 'diff --git a/%s b/%s\n--- a/%s\n+++ b/%s\n@@ -1,1 +1,1 @@\n+x\n' "$p" "$p" "$p" "$p" >>"$1/pr.diff"
  done
}
mkstats "$sp_tmp/a" <<'EOF2'
libs/a/big.service.ts 200 10
libs/a/mid.component.ts 120 5
libs/a/mid.component.html 90 0
libs/a/small.component.ts 10 0
libs/a/big.service.spec.ts 300 0
libs/a/notes.md 500 0
EOF2
"$split" "$sp_tmp/a" >"$sp_tmp/a.out" 2>&1
check "split: simplifier gets the largest added code files" 0 "Simplify: 3 file(s)" cat "$sp_tmp/a.out"
check "split: biggest first"                               0 "libs/a/big.service.ts" head -1 "$sp_tmp/a/units/simplify-files.txt"
check "split: specs, docs and tiny files are excluded"     1 "" grep -E 'spec|notes.md|small' "$sp_tmp/a/units/simplify-files.txt"
mkstats "$sp_tmp/b" <<'EOF2'
libs/a/big.service.ts 60 900
libs/a/mid.component.ts 40 700
EOF2
"$split" "$sp_tmp/b" >"$sp_tmp/b.out" 2>&1
check "split: deletion-heavy PR skips the simplifier"      0 "Simplify: 0 file(s)" cat "$sp_tmp/b.out"
mkstats "$sp_tmp/c" <<'EOF2'
libs/a/tiny.component.ts 12 0
EOF2
"$split" "$sp_tmp/c" >"$sp_tmp/c.out" 2>&1
check "split: PR adding under 30 lines skips the simplifier" 0 "Simplify: 0 file(s)" cat "$sp_tmp/c.out"
rm -rf "$sp_tmp"

# ci-failures.sh and the CI lint rules (fixture: a real failed Jest step from a GitHub Actions log)
ci="$here/../scripts/ci-failures.sh"
ci_tmp=$(mktemp -d "${TMPDIR:-/tmp/}ci-eval.XXXXXX")
cp -R "$here/fixtures/ci/fetch" "$ci_tmp/f"
"$ci" "$ci_tmp/f" --log "$here/fixtures/ci/jest-fail.log" --check "Build and Verify - Angular X" >"$ci_tmp/out.txt" 2>&1
SPEC=apps/lxp/src/app/maestro-studio/components/coach-builder-share/coach-builder-share.component.spec.ts
check "ci: names the failing spec and that the PR changes it" 0 "FAILING-SPEC $SPEC IN-PR" cat "$ci_tmp/out.txt"
check "ci: names the failing test"                         0 "audience model › renders the ReBAC audience access UI" cat "$ci_tmp/out.txt"
check "ci: excerpt shows the assertion"                    0 "expect(received).toBeNull()" cat "$ci_tmp/out.txt"
check "ci: excerpt shows the failing line"                 0 "> 162 |" cat "$ci_tmp/out.txt"
check "ci: excerpt stops at the next suite"                1 "" grep -E "^  *PASS " "$ci_tmp/out.txt"
check "ci: console noise is not a failing test"            1 "" grep -E "FAILING-TEST.*(NG0950|Console)" "$ci_tmp/out.txt"
check "ci: writes ci-failures.txt"                         0 "FAILING-SPEC" cat "$ci_tmp/f/ci-failures.txt"
rm -rf "$ci_tmp/g"; mkdir -p "$ci_tmp/g"; printf 'apps/other.ts\n' >"$ci_tmp/g/files.txt"; cp "$here/fixtures/ci/fetch/checks.txt" "$ci_tmp/g/"; echo '{}' >"$ci_tmp/g/meta.json"
"$ci" "$ci_tmp/g" --log "$here/fixtures/ci/jest-fail.log" --check "Build and Verify - Angular X" >"$ci_tmp/g.out" 2>&1
check "ci: a failing spec the PR does not change"          0 "(not in this PR's files)" cat "$ci_tmp/g.out"
rm -rf "$ci_tmp/h"; mkdir -p "$ci_tmp/h"; : >"$ci_tmp/h/checks.txt"
check "ci: no failing checks"                              0 "no failing checks" "$ci" "$ci_tmp/h"
rm -rf "$ci_tmp/i"; mkdir -p "$ci_tmp/i"; printf 'LXP.Web.AngularX.PR\tfail\t16m\thttps://dev.azure.com/x/_build/results?buildId=1\n' >"$ci_tmp/i/checks.txt"
check "ci: a check outside GitHub is not readable here"    0 "not readable here" "$ci" "$ci_tmp/i"
check "ci: bad directory"                                  2 "usage" "$ci" "$here/nope"
check "lint: CI line says green while checks are red"      1 "FAIL R9" "$lint" "$rv/ci-green-while-red.md" --fetch-dir "$ci_tmp/f"
check "lint: failing spec the PR changes is never named"   1 "FAIL R10" "$lint" "$rv/ci-red-spec-unnamed.md" --fetch-dir "$ci_tmp/f"
check "lint: red CI with the failing spec named"           0 "PASS lint-review" "$lint" "$rv/ci-red-named.md" --fetch-dir "$ci_tmp/f"
check "lint: ci-failures.sh not run is a warning"          0 "WARN R10" "$lint" "$rv/ci-red-named.md" --fetch-dir "$here/fixtures/ci/fetch"
rm -rf "$ci_tmp"

exit $fail

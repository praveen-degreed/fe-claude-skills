#!/usr/bin/env bash
# Deterministic leads for a human-style review of the ADDED lines of a PR. No model, no gh, read-only.
# Usage: review-scan.sh <fetch-dir> [<checkout-dir>]     (writes <fetch-dir>/scan.txt and prints it)
#
# Every line is a LEAD, not a finding: the reviewer opens the cited line and the existing code it points at,
# and reports only what holds up. Line numbers are head/<path> line numbers (same as verify-citations.sh).
# Sections:
#   NEARBY     utils/constants/helpers files next to each changed file, and whether the file imports them
#   REUSE      a new symbol that is already defined elsewhere in the repo; a hand-rolled version of a shared util
#              that still exists (checked in libs/shared/core/utils before it is named)
#   CONSTANT   magic numbers, repeated string literals, inline regexes, URL literals, and where a constants file lives
#   HELPER     methods over 50 lines or nested deeper than 3 levels that contain added lines, files over 300 lines
#   PLACEMENT  exported types or sizeable pure functions inside component/service files; util/model/constants files that import from a component/service file
#   SECURITY   greps for XSS, secrets, insecure URLs, unsafe window/storage use in added lines
# Without <checkout-dir> the REUSE symbol search and NEARBY are skipped (stated in the output).
set -u
die() { echo "review-scan: $*" >&2; exit 1; }

dir=${1:-}; co=${2:-}
[ -n "$dir" ] && [ -f "$dir/pr.diff" ] && [ -f "$dir/files.txt" ] || die "usage: review-scan.sh <fetch-dir> [<checkout-dir>]"
[ -n "$co" ] && [ ! -d "$co" ] && die "checkout dir not found: $co"

added="$dir/added.tsv"
# file <TAB> head line number <TAB> text, for every added line
awk '/^diff --git / { f = $4; sub(/^b\//, "", f); inh = 0; next }
  /^@@/ { match($0, /\+[0-9]+/); n = substr($0, RSTART + 1, RLENGTH - 1) + 0; inh = 1; next }
  !inh { next }
  /^\\/ { next }
  /^\+/ { printf "%s\t%d\t%s\n", f, n, substr($0, 2); n++; next }
  /^-/ { next }
  { n++ }' "$dir/pr.diff" >"$added"

ts_added="$dir/added-ts.tsv"
awk -F'\t' '$1 ~ /\.ts$/ && $1 !~ /\.(spec|test|d)\.ts$/' "$added" >"$ts_added"
web_added="$dir/added-web.tsv"
awk -F'\t' '($1 ~ /\.(ts|html)$/) && $1 !~ /\.(spec|test|d)\.ts$/' "$added" >"$web_added"
files_ts=$(cut -f1 "$ts_added" | sort -u)

out="$dir/scan.txt"
: >"$out"
emit() { printf '%s\n' "$*" >>"$out"; }
section() { emit ""; emit "== $1"; }
cap() { awk -v n="${1:-40}" 'NR <= n { print } NR == n + 1 { print "... (more omitted)" }'; }

gitco=0
[ -n "$co" ] && git -C "$co" rev-parse --git-dir >/dev/null 2>&1 && gitco=1
# defs <name> : where a symbol is defined in the repo (specs and typings excluded)
defs() {
  [ -n "$co" ] || return 0
  local re="(function|const|let|class|interface|type|enum)[[:space:]]+$1([^A-Za-z0-9_]|\$)"
  if [ "$gitco" = 1 ]; then
    git -C "$co" grep -n -E "$re" -- '*.ts' ':!*.spec.ts' ':!*.d.ts' 2>/dev/null | cut -c1-150 | head -4
  else
    (cd "$co" && grep -rEn --include='*.ts' --exclude='*.spec.ts' --exclude='*.d.ts' --exclude-dir=node_modules --exclude-dir=.git "$re" . 2>/dev/null | sed 's#^\./##' | cut -c1-150 | head -4)
  fi
}

emit "review-scan: leads for the added lines (not findings; open each cited line and the existing code before reporting)"

# ---------------------------------------------------------------- NEARBY
section "NEARBY (existing utils, constants and helpers next to the changed files)"
printf '%s\n' "$files_ts" | while IFS= read -r p; do
  [ -z "$p" ] && continue
  case $p in *.utils.ts | *.util.ts | *.helpers.ts | *.constants.ts | *.model.ts | *.models.ts | */constants.ts | */utils.ts) continue ;; esac
  d=$(dirname "$p")
  for base in "$d" "$(dirname "$d")"; do
    for root in "$dir/head" "$co"; do
      [ -n "$root" ] && [ -d "$root/$base" ] || continue
      for n in $(cd "$root/$base" && ls 2>/dev/null | grep -E '(\.utils?|\.helpers?|\.constants?)\.ts$|^(constants|utils|helpers)\.ts$'); do
        full="$base/$n"
        [ "$full" = "$p" ] && continue
        stem=${n%.ts}
        if [ -f "$dir/head/$p" ] && grep -qE "from '[^']*/$stem'|from '\./$stem'" "$dir/head/$p"; then use="imported by $p"; else use="NOT imported by $p"; fi
        names=$(grep -E '^export (async )?(const|function|class|enum|interface|type) ' "$root/$full" 2>/dev/null | sed -E 's/^export (async )?(const|function|class|enum|interface|type) +([A-Za-z0-9_$]+).*/\3/' | head -12 | tr '\n' ' ')
        printf '%s\n' "NEARBY $full ($use) exports: ${names:-none}"
      done
    done
  done
done | sort -u | cap 15 >>"$out"
grep -q '^NEARBY' "$out" || emit "(none found next to the changed files)"

# ---------------------------------------------------------------- REUSE
section "REUSE (already exists elsewhere: use it, do not reinvent)"
reuse_n=0
if [ -z "$co" ]; then
  emit "(no checkout: not scanned)"
else
  # new module-level symbols: functions, arrow consts, exported classes/types/enums
  syms=$(awk -F'\t' '
    { t = $3
      if (match(t, /^[ \t]*(export )?(default )?(async )?function[ \t*]+[A-Za-z_$][A-Za-z0-9_$]*/)) { s = substr(t, RSTART, RLENGTH); sub(/.*function[ \t*]+/, "", s); print $1 "\t" $2 "\t" s }
      else if (match(t, /^[ \t]*(export )?(const|let)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*[ \t]*(:[^=]+)?=[ \t]*(async )?(\(|function|[A-Za-z_$][A-Za-z0-9_$]*[ \t]*=>)/)) { s = t; sub(/^[ \t]*(export )?(const|let)[ \t]+/, "", s); sub(/[^A-Za-z0-9_$].*/, "", s); print $1 "\t" $2 "\t" s }
      else if (match(t, /^[ \t]*export (abstract )?(class|interface|type|enum)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*/)) { s = substr(t, RSTART, RLENGTH); sub(/.*(class|interface|type|enum)[ \t]+/, "", s); print $1 "\t" $2 "\t" s }
    }' "$ts_added" | awk -F'\t' 'length($3) >= 8 && !seen[$1 FS $3]++')
  total=$(printf '%s\n' "$syms" | grep -c . || true)
  # one batched search for all new symbols (git only); falls back to one search per symbol
  defs_cache=""
  if [ "$gitco" = 1 ] && [ -n "$syms" ]; then
    alt=$(printf '%s\n' "$syms" | cut -f3 | head -80 | sed 's/\$/\\$/g' | paste -sd'|' -)
    defs_cache="$dir/.defs.tsv"
    git -C "$co" grep -n -o -E "(function|const|let|class|interface|type|enum)[[:space:]]+($alt)([^A-Za-z0-9_]|\$)" -- '*.ts' ':!*.spec.ts' ':!*.d.ts' 2>/dev/null |
      awk -F: '{ m = $3; for (i = 4; i <= NF; i++) m = m ":" $i; sub(/^[a-z]+[ \t]+/, "", m); sub(/[^A-Za-z0-9_$].*$/, "", m); print m "\t" $1 ":" $2 }' >"$defs_cache"
  fi
  printf '%s\n' "$syms" | head -80 | while IFS=$'\t' read -r f l name; do
    [ -z "$name" ] && continue
    if [ -n "$defs_cache" ]; then hits=$(awk -F'\t' -v n="$name" '$1 == n { print $2 }' "$defs_cache" | awk -F: -v f="$f" '$1 != f && $1 !~ /(test-utils|\/mocks?\/|\.mock\.)/' | head -3)
    else hits=$(defs "$name" | awk -F: -v f="$f" '$1 != f && $1 !~ /(test-utils|\/mocks?\/|\.mock\.)/'); fi
    [ -n "$hits" ] && emit "REUSE? $f:$l new '$name' is also defined at: $(printf '%s' "$hits" | cut -d: -f1,2 | head -3 | tr '\n' ' ')"
  done
  [ -n "$defs_cache" ] && rm -f "$defs_cache"
  [ "$total" -gt 80 ] && emit "($((total - 80)) more new symbols not searched)"

  # hand-rolled versions of shared utils, named only when the util still exists in libs/shared/core/utils
  while IFS=$'\t' read -r re util why; do
    [ -z "$re" ] && continue
    found=$(RE="$re" awk -F'\t' '$3 ~ ENVIRON["RE"] { print $1 ":" $2 ": " substr($3, 1, 100) }' "$ts_added" | head -3)
    [ -z "$found" ] && continue
    where=""
    if [ "$gitco" = 1 ]; then
      where=$(git -C "$co" grep -n -E "export (const|function) $util([^A-Za-z0-9_]|\$)" -- 'libs/shared/core/utils' 2>/dev/null | head -1 | cut -d: -f1,2)
    fi
    [ -n "$where" ] || continue
    printf '%s\n' "$found" | while IFS= read -r hit; do emit "REUSE? ${hit%%: *} hand-rolled $why; shared util '$util' exists at $where (import from @degreed/core/utils)"; done
  done <<'EOF'
JSON\.parse\(JSON\.stringify	getDeepCopy	deep clone
(^|[^A-Za-z0-9_])encodeURIComponent\(	safeEncodeURIComponent	URL encoding
Math\.random\(\)\.toString\(36\)|crypto\.randomUUID\(	generateGuid	id generation
JSON\.stringify\(.*\) *===? *JSON\.stringify	deepEqual	deep comparison
\.startsWith\(['"]https?:	isUrlAbsolute	absolute URL check
EOF
  grep -q '^REUSE?' "$out" || emit "(no duplicate symbol or hand-rolled shared util found; the reviewer still searches for new helpers by behaviour)"
fi

# ---------------------------------------------------------------- CONSTANT
section "CONSTANT (move to a named constant; convention: <feature>.constants.ts next to the file)"
nonconst='^[ \t]*(import |export \{|export \* |//|\*|/\*)|(const|static readonly|readonly)[ \t]+[A-Z][A-Z0-9_]+[ \t]*[:=]'
NONCONST="$nonconst" awk -F'\t' '
  function clean(t) { gsub(/\x27[^\x27]*\x27|"[^"]*"|`[^`]*`/, "\"\"", t); sub(/\/\/.*/, "", t); return t }
  $3 ~ ENVIRON["NONCONST"] { next }
  { t = clean($3)
    if (match(t, /(^|[^A-Za-z0-9_.#$])[0-9][0-9]+([^A-Za-z0-9_.%]|$)/)) {
      v = substr(t, RSTART, RLENGTH); gsub(/[^0-9]/, "", v)
      if (v != "10" && v != "100" && v != "1000" && v + 0 > 1) { if (++cnt[$1] <= 5) print "CONSTANT? " $1 ":" $2 " magic number " v ": " substr($3, 1, 90); else more[$1] = cnt[$1] - 5 }
    }
  }
  END { for (f in more) print "CONSTANT? " f " +" more[f] " more magic numbers in this file" }' "$ts_added" | cap 30 >>"$out"
awk -F'\t' '
  function clean(t) { sub(/\/\/.*/, "", t); return t }
  /^[^\t]*\t[0-9]*\t[ \t]*(import |export \{)/ { next }
  { t = clean($3); if (t ~ /(^|[^A-Za-z0-9_])(import|from) /) next
    if (t ~ /\x27[ \t]*\|[ \t]|\|[ \t]*\x27/ || t ~ /^[ \t]*(export )?type[ \t]/) next
    while (match(t, /\x27[^\x27]+\x27/)) {
      s = substr(t, RSTART, RLENGTH); t = substr(t, RSTART + RLENGTH)
      if (length(s) < 6 || length(s) > 62 || s ~ /^\x27[.\/@]/ || s ~ / $/) continue
      k = $1 SUBSEP s; c[k]++; if (!(k in first)) first[k] = $2
    }
  }
  END { for (k in c) if (c[k] >= 2) { split(k, a, SUBSEP); print "CONSTANT? " a[1] ":" first[k] " string " a[2] " repeated " c[k] "x" } }' "$ts_added" | sort | cap 20 >>"$out"
awk -F'\t' '
  $3 ~ /\.(test|match|replace|split)\(\/[^\/]+\/[gimsuy]*[,)]|=[ \t]*\/[^\/* ][^\/]*\/[gimsuy]*;/ { print "CONSTANT? " $1 ":" $2 " inline regex: " substr($3, 1, 90) }
  $3 ~ /\x27https?:\/\/[^\x27]+\x27/ && $3 !~ /localhost|^[ \t]*(import|\/\/|\*)/ { print "CONSTANT? " $1 ":" $2 " URL literal: " substr($3, 1, 90) }' "$ts_added" | cap 15 >>"$out"
# where a constant would live
printf '%s\n' "$files_ts" | while IFS= read -r p; do
  [ -z "$p" ] && continue
  grep -q "^CONSTANT? $p:" "$out" || continue
  d=$(dirname "$p"); ex=""
  for base in "$d" "$d/constants" "$(dirname "$d")" "$(dirname "$d")/constants" "$(dirname "$(dirname "$d")")/constants"; do
    for root in "$dir/head" "$co"; do
      [ -n "$root" ] && [ -d "$root/$base" ] || continue
      for n in $(cd "$root/$base" && ls 2>/dev/null | grep -E '\.constants?\.ts$|^constants\.ts$'); do ex="$ex $base/$n"; done
    done
  done
  ex=$(printf '%s\n' $ex | awk 'NF && !seen[$0]++' | head -4 | tr '\n' ' ')
  if [ -n "$ex" ]; then emit "CONSTANT-HOME $p: existing ${ex}(add there or follow its naming)"; else emit "CONSTANT-HOME $p: no constants file nearby (create <feature>.constants.ts named after the feature, next to it)"; fi
done
grep -q '^CONSTANT' "$out" || emit "(none)"

# ---------------------------------------------------------------- HELPER
section "HELPER (long or deeply nested methods that contain added lines; split into small helpers)"
for p in $files_ts; do
  [ -f "$dir/head/$p" ] || continue
  tmp="$dir/.added-lines.tmp"
  awk -F'\t' -v f="$p" '$1 == f { print $2 }' "$ts_added" >"$tmp"
  nlines=$(awk 'END { print NR }' "$dir/head/$p")
  nadd=$(awk 'END { print NR }' "$tmp")
  [ "$nlines" -gt 300 ] && [ "$nadd" -ge 50 ] && emit "HELPER? $p:1 file has $nlines lines, $nadd added (over 300: more than one responsibility?)"
  awk -v f="$p" '
    function strip(t) { gsub(/\x27([^\x27\\]|\\.)*\x27|"([^"\\]|\\.)*"|`([^`\\]|\\.)*`/, "", t); sub(/\/\/.*/, "", t); return t }
    NR == FNR { add[$1] = 1; next }
    {
      t = strip($0); o = gsub(/\{/, "{", t); c = gsub(/\}/, "}", t)
      if (!inm) {
        if ($0 ~ /^[ \t]*(export )?(default )?(public |private |protected |static |async |readonly |get |set )*(async )?(function[ \t*]+)?[A-Za-z_$][A-Za-z0-9_$]*(<[^>]*>)?\(.*\)[^;=]*\{[ \t]*$/ || $0 ~ /^[ \t]*(public |private |protected |static |readonly )*[A-Za-z_$][A-Za-z0-9_$]*[ \t]*=[ \t]*(async )?\(.*\)[^;]*=>[ \t]*\{[ \t]*$/) {
          nm = $0; sub(/^[ \t]*(export )?(default )?(public |private |protected |static |async |readonly |get |set )*(async )?(function[ \t*]+)?/, "", nm); sub(/[^A-Za-z0-9_$].*/, "", nm)
          if (nm !~ /^(if|for|while|switch|catch|else|return|constructor|function|subscribe|pipe|map|tap|filter)$/ && nm != "") { inm = 1; start = FNR; depth = o - c; maxd = depth; hasadd = (FNR in add); if (depth <= 0) inm = 0 }
        }
      } else {
        depth += o - c; if (depth > maxd) maxd = depth; if (FNR in add) hasadd = 1
        if (depth <= 0) { inm = 0; len = FNR - start + 1; if (hasadd && (len > 50 || maxd >= 5)) printf "HELPER? %s:%d %s() is %d lines, max nesting %d (rule: <=50 lines, <=3 levels)\n", f, start, nm, len, maxd - 1 }
      }
    }' "$tmp" "$dir/head/$p" >>"$out"
  rm -f "$tmp"
done
grep -q '^HELPER' "$out" || emit "(none)"

# ---------------------------------------------------------------- PLACEMENT
section "PLACEMENT (where code belongs: model, util or constants file; wrong import direction)"
role='\\.(component|service|store|directive|pipe|guard|resolver)\\.ts$'
# exported types declared inside a component/service file
awk -F'\t' -v role="$role" '
  $1 ~ role && $3 ~ /^export[ \t]+(abstract class|interface|type|enum)[ \t]/ && $3 !~ /^export[ \t]+abstract class[ \t]+[A-Za-z0-9_$]+(Component|Service|Store)/ {
    k = $3; sub(/^export[ \t]+/, "", k); sub(/[ \t].*/, "", k); n = $3; sub(/^export[ \t]+(abstract class|interface|type|enum)[ \t]+/, "", n); sub(/[^A-Za-z0-9_$].*/, "", n)
    r = $1; sub(/.*\./, "", r); sub(/\.ts$/, "", r); match($1, /\.(component|service|store|directive|pipe|guard|resolver)\.ts$/); r = substr($1, RSTART + 1, RLENGTH - 4)
    print "PLACE? " $1 ":" $2 " exported " k " " n " is declared in a " r " file: if it is a shared shape or part of the public API, move it to <feature>.model.ts"
  }' "$ts_added" | cap 15 >>"$out"
# wrong import direction: utils/helpers must not import a component file; models/constants/types must not import a component or service file
# (a util importing a service class to inject() it is fine, so utils are only checked against components)
awk -F'\t' '
  { u = ($1 ~ /\.(utils?|helpers?)\.ts$/); m = ($1 ~ /\.(constants?|models?|types)\.ts$/) }
  (u || m) && $3 ~ /^[ \t]*(import|export)[ \t].*from[ \t]+[\x27"][^\x27"]*\.(component|directive|service|store)[\x27"]/ {
    t = $3; sub(/.*from[ \t]+[\x27"]/, "", t); sub(/[\x27"].*/, "", t)
    if (u && t !~ /\.(component|directive)$/) next
    print "PLACE? " $1 ":" $2 " " (u ? "util" : "model/constants") " file imports from a " (t ~ /\.(component|directive)$/ ? "component" : "service") " file (" t "): wrong direction, move the shared symbol to a model/utils file both import"
  }' "$ts_added" | cap 15 >>"$out"
# sizeable pure module-level functions inside a component/service file
for p in $files_ts; do
  case $p in *.component.ts | *.service.ts | *.store.ts | *.directive.ts | *.pipe.ts | *.guard.ts | *.resolver.ts) ;; *) continue ;; esac
  [ -f "$dir/head/$p" ] || continue
  tmp="$dir/.added-lines.tmp"
  awk -F'\t' -v f="$p" '$1 == f { print $2 }' "$ts_added" >"$tmp"
  awk -v f="$p" '
    NR == FNR { add[$1] = 1; next }
    !inf && /^(export )?(async )?function[ \t*]+[A-Za-z_$]/ { inf = 1; start = FNR; nm = $0; sub(/^(export )?(async )?function[ \t*]+/, "", nm); sub(/[^A-Za-z0-9_$].*/, "", nm); impure = 0; hasadd = (FNR in add); next }
    !inf && /^(export )?const[ \t]+[A-Za-z_$][A-Za-z0-9_$]*[ \t]*(:[^=]+)?=[ \t]*(async )?\(.*\)[^;]*=>[ \t]*[{(]?[ \t]*$/ { inf = 1; start = FNR; nm = $0; sub(/^(export )?const[ \t]+/, "", nm); sub(/[^A-Za-z0-9_$].*/, "", nm); impure = 0; hasadd = (FNR in add); next }
    inf { if (/(inject\(|this\.|document\.|window\.)/) impure = 1; if (FNR in add) hasadd = 1
          if (/^(\}|\};|\);)[ \t]*$/) { inf = 0; len = FNR - start + 1; if (hasadd && !impure && len >= 12) printf "PLACE? %s:%d module-level pure function %s() is %d lines in a component/service file: if reused or worth testing alone, move it to <feature>.utils.ts\n", f, start, nm, len } }
  ' "$tmp" "$dir/head/$p" >>"$out"
  rm -f "$tmp"
done
grep -q '^PLACE?' "$out" || emit "(none)"

# ---------------------------------------------------------------- SECURITY
section "SECURITY (verify each; most hits are fine in context)"
while IFS=$'\t' read -r re label; do
  [ -z "$re" ] && continue
  RE="$re" LABEL="$label" awk -F'\t' '$3 ~ ENVIRON["RE"] && $3 !~ /^[ \t]*(\/\/|\*)/ { print "SEC? " $1 ":" $2 " " ENVIRON["LABEL"] ": " substr($3, 1, 90) }' "$web_added" | head -5
done >>"$out" <<'EOF'
innerHTML|outerHTML	XSS sink
bypassSecurityTrust	sanitizer bypass
(^|[^A-Za-z0-9_.])eval\(|new Function\(|document\.write\(	code injection
(localStorage|sessionStorage)\.setItem\([^)]*([Tt]oken|[Pp]assword|[Ss]ecret|[Jj]wt|[Aa]uth)	secret in web storage
([Aa]pi[_-]?[Kk]ey|[Ss]ecret|[Pp]assw(or)?d|[Tt]oken|[Bb]earer)[A-Za-z_]*['"]? *[:=] *['"][A-Za-z0-9+/_=.-][A-Za-z0-9+/_=.-][A-Za-z0-9+/_=.-][A-Za-z0-9+/_=.-][A-Za-z0-9+/_=.-][A-Za-z0-9+/_=.-][A-Za-z0-9+/_=.-][A-Za-z0-9+/_=.-][A-Za-z0-9+/_=.-][A-Za-z0-9+/_=.-][A-Za-z0-9+/_=.-][A-Za-z0-9+/_=.-]+['"]	possible hardcoded secret
['"`]http://[^l]	insecure http URL
window\.open\(	window.open (validate URL, noopener)
(location\.(href|assign|replace)|window\.location) *(=|\()	redirect from data (validate target)
postMessage\(	postMessage (check target origin)
console\.(log|debug|info|warn)\(	console output (PII/token leak risk)
Math\.random\(\)	Math.random is not secure for tokens or ids
EOF
awk -F'\t' '$1 ~ /\.html$/ && $3 ~ /target="_blank"/ && $3 !~ /rel=/ { print "SEC? " $1 ":" $2 " target=_blank without rel=noopener: " substr($3, 1, 90) }' "$web_added" | head -5 >>"$out"
awk -F'\t' '$1 ~ /\.html$/ && $3 ~ /\[(href|src|srcdoc)\]/ { print "SEC? " $1 ":" $2 " bound URL (sanitised by Angular; confirm the value is not user-controlled for a redirect): " substr($3, 1, 90) }' "$web_added" | head -5 >>"$out"
awk '/^SEC\?/ { f = 1 } END { exit !f }' "$out" || emit "(none)"

emit ""
emit "review-scan: $(grep -c -E '^(REUSE|CONSTANT|HELPER|PLACE|SEC)\?' "$out") lead(s)"
rm -f "$added" "$ts_added" "$web_added"
cat "$out"

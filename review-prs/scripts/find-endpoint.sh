#!/usr/bin/env bash
# Usage: find-endpoint.sh <route fragment>   e.g. 'users/GetUser' or 'api/dg-maestro/chat'
# Env: REVIEW_BACKEND_REPOS=colon-separated backend repo paths. Read-only, max 10 hits.

frag="${1:-}"
[ -z "$frag" ] && { echo "usage: find-endpoint.sh <route fragment>"; exit 0; }

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
main=$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')
repos="${REVIEW_BACKEND_REPOS:-}"
if [ -z "$repos" ]; then
  repos="$root/../Degreed:$root/../degreed-coach-builder"
  [ -n "$main" ] && repos="$repos:$main/../Degreed:$main/../degreed-coach-builder"
fi

found=""
OLDIFS=$IFS; IFS=:
for r in $repos; do
  [ -d "$r" ] || continue
  d=$(cd "$r" && pwd)
  case ":$found:" in *":$d:"*) continue ;; esac
  found="$found:$d"
done
IFS=$OLDIFS
if [ -z "$found" ]; then
  echo "contract not verified: backend repos not found"
  exit 0
fi

path=${frag%%\?*}
segs=""
for s in $(echo "$path" | tr '/' ' '); do
  case "$s" in
    api|dgcb|v1|'{'*|*[0-9]*) ;;
    *) segs="$segs $s" ;;
  esac
done
set -- $segs
if [ $# -eq 0 ]; then echo "contract not verified: no usable route segment in '$frag'"; exit 0; fi
first=$1
for last in "$@"; do :; done

attr='(Http(Get|Post|Put|Delete|Patch)|Route)\(|@(router|app)\.(get|post|put|delete|patch)\('
nfirst=$(echo "$first" | tr -d '_-' | tr 'A-Z' 'a-z')
count=0
for d in $(echo "${found#:}" | tr ':' ' '); do
  echo "repo: $d"
  hits=""
  for pat in "($attr)[^)]*[\"/]$last([\"/?{]|\$)" "($attr).*$last"; do
    hits=$(grep -rniE --include='*.cs' --include='*.py' -e "$pat" "$d" \
      --exclude-dir=node_modules --exclude-dir=bin --exclude-dir=obj --exclude-dir=tests --exclude-dir=__pycache__ \
      --exclude-dir=.venv --exclude-dir=.claude --exclude-dir=.git --exclude-dir=worktrees 2>/dev/null | awk -F: '{print $1":"$2}' | head -300)
    [ -n "$hits" ] && break
  done
  pscoped=""; scoped=""; other=""
  for h in $hits; do
    f=${h%%:*}
    np=$(echo "${f##*/}" | tr -d '_-' | tr 'A-Z' 'a-z')
    if [ "$first" = "$last" ]; then other="$other $h"
    elif case "$np" in *"$nfirst"*) true ;; *) false ;; esac; then pscoped="$pscoped $h"
    elif grep -qiE "(Route\(|prefix=).*$first" "$f"; then scoped="$scoped $h"
    else other="$other $h"
    fi
  done
  list="$pscoped $scoped"
  [ -z "${list// /}" ] && list=$other
  top=""
  n=0
  for h in $list; do
    [ $n -ge 10 ] && break
    n=$((n+1)); count=$((count+1))
    [ -z "$top" ] && top=$h
    echo "  $h"
  done
  if [ -n "$top" ]; then
    tf=${top%%:*}; tl=${top##*:}
    echo "  candidate: ${tf##*/}"
    sig=$(sed -n "${tl},$((tl+5))p" "$tf" | grep -E 'public .*\(|def .*\(' | head -1)
    if [ -n "$sig" ]; then
      echo "  signature: $(echo "$sig" | sed 's/^[[:space:]]*//')"
      types=$(echo "$sig" | grep -oE '[A-Z][A-Za-z0-9]+' | grep -vxE 'Task|IActionResult|ActionResult|IResult|String|Int|Long|Bool|Request|Public|Async|Virtual|FromQuery|FromBody|Optional|None|True|False|Get|Post' | sort -u | head -6 | tr '\n' ' ')
      echo "  types: $types"
    fi
  fi
done
[ "$count" -eq 0 ] && echo "contract not verified: no route match for '$frag'"
exit 0

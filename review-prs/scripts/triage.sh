#!/usr/bin/env bash
# Deterministic PR triage: changed paths in, review plan out. No model. Fails open to FULL.
# Usage: triage.sh [--json] [--additions N] [--deletions N] [--files N] [path ...]   (paths also read from stdin)
set -u

ALL_AGENTS="fe-code-reviewer fe-logic-reviewer fe-test-analyzer fe-simplifier fe-architecture-reviewer fe-impact-analyzer"
ALL_PASSES="Styling Angular A11y Security Quality Test Apollo"

has() { case " $1 " in *" $2 "*) return 0 ;; esac; return 1; }
add() { eval "cur=\${$1}"; has "$cur" "$2" || eval "$1=\"\$cur $2\""; }
ordered() { local out="" x; for x in $1; do has "$2" "$x" && out="$out $x"; done; echo "${out# }"; }
commas() { local out="" x; for x in $1; do out="$out, $x"; done; echo "${out#, }"; }
jarr() { local out="" x; for x in $1; do out="$out,\"$x\""; done; echo "[${out#,}]"; }

budget_for() {
  case $1 in
    tiny) echo "2-3 min, ~10 tool calls/agent, max 6 findings/agent" ;;
    typical) echo "5-8 min, ~20 tool calls/agent, max 8 findings/agent" ;;
    large) echo "10-15 min, ~30 tool calls/agent, max 10 findings/agent" ;;
    huge) echo "do not review; ask author to split" ;;
    *) echo "size unknown: use typical budget, 5-8 min, ~20 tool calls/agent, max 8 findings/agent" ;;
  esac
}

emit() {
  local mode=$1 reason=$2 size=$3 types=$4 agents=$5 passes=$6 split=$7 nfiles=$8 loc=$9
  local notrun="" a
  for a in $ALL_AGENTS; do has "$agents" "$a" || notrun="$notrun $a"; done
  notrun="${notrun# }"
  if [ "$JSON" = 1 ]; then
    printf '{"mode":"%s","reason":"%s","size":"%s","files":%s,"loc":"%s","types":%s,"agents":%s,"passes":%s,"not_run":%s,"recommend_split":%s}\n' \
      "$mode" "$reason" "$size" "$nfiles" "$loc" "$(jarr "$types")" "$(jarr "$agents")" "$(jarr "$passes")" "$(jarr "$notrun")" "$split"
    return
  fi
  case $mode in
    full) echo "FULL: all agents in parallel - $reason" ;;
    none) echo "NONE: no agents - $reason" ;;
    *) echo "PLAN: $reason" ;;
  esac
  echo "Size: $size ($nfiles files, ~$loc LOC)"
  echo "Types: $(commas "$types")"
  echo "Agents: $(commas "$agents")"
  echo "Passes: $(commas "$passes")"
  echo "Not run: $(commas "$notrun")"
  echo "Budget: $(budget_for "$size")"
  [ "$split" = true ] && echo "SPLIT: PR too large; ask the author to split before reviewing"
  return 0
}

full() { emit full "$1" "${SIZE:-unknown}" "unknown" "$ALL_AGENTS" "$ALL_PASSES" false "${NFILES:-0}" "${ADDS:-?}"; }

lean_diff() {
  [ -z "${ADDS:-}" ] && return 1
  [ "$ADDS" -lt 30 ] && return 0
  [ -n "${DELS:-}" ] && [ $((ADDS * 5)) -lt $((ADDS + DELS)) ] && return 0
  return 1
}

plan() {
  local n=0 line status path lp unknown=""
  local t_template=0 t_component=0 t_service=0 t_model=0 t_routing=0 t_spec=0 t_styles=0 t_config=0 t_shared=0 t_auth=0 t_new=0 code=0
  while IFS= read -r line; do
    line=${line%$'\r'}
    [ -z "$line" ] && continue
    status=""
    case $line in
      *$'\t'*) status=${line%%$'\t'*}; path=${line##*$'\t'} ;;
      "A "* | "M "* | "D "*) status=${line%% *}; path=${line#* } ;;
      *) path=$line ;;
    esac
    n=$((n + 1))
    lp=$(printf %s "$path" | tr 'A-Z' 'a-z')
    case $lp in
      *.spec.ts | *.test.ts) t_spec=1 ;;
      *.scss | *.css | *.sass | *.less) t_styles=1 ;;
      *.html) t_template=1; code=1 ;;
      *.config.ts | *.config.mts | *.config.js | *.config.mjs | *.config.cjs) t_config=1 ;;
      *.md | *.mdx | *.json | *.yml | *.yaml | *.txt | *.lock | *.svg | *.png | *.jpg | *.ico) t_config=1 ;;
      *.graphql | *.gql) t_model=1; code=1 ;;
      *.ts)
        code=1
        case $lp in
          *.routes.ts | *routing*.ts | *.guard.ts | *.resolver.ts) t_routing=1 ;;
          *.model.ts | *.models.ts | *.interface.ts | *.types.ts) t_model=1 ;;
          *.service.ts | *.store.ts | *.api.ts | *-api.ts | *.effects.ts | *.facade.ts | *.resource.ts) t_service=1 ;;
          *) t_component=1 ;;
        esac
        case $lp in
          *auth* | *permission* | *rebac*) t_auth=1 ;;
        esac
        case $lp in
          */index.ts | index.ts | */public-api.ts | libs/shared/*) t_shared=1 ;;
        esac
        [ "$status" = A ] && t_new=1
        ;;
      *) unknown="$unknown $path" ;;
    esac
  done

  NFILES=${FILES:-$n}
  [ "$n" -eq 0 ] && { full "empty input: no changed files supplied"; return 0; }
  [ -n "$unknown" ] && { full "unrecognised file type:${unknown}"; return 0; }

  local loc=${ADDS:-}
  if [ -n "$loc" ]; then
    if [ "$NFILES" -gt 50 ] || [ "$loc" -gt 1500 ]; then SIZE=huge
    elif [ "$loc" -gt 600 ] || [ "$NFILES" -gt 20 ]; then SIZE=large
    elif [ "$loc" -lt 100 ] && [ "$NFILES" -le 5 ]; then SIZE=tiny
    else SIZE=typical; fi
  else
    loc="?"
    if [ "$NFILES" -gt 50 ]; then SIZE=huge
    elif [ "$NFILES" -gt 20 ]; then SIZE=large
    elif [ "$NFILES" -le 3 ]; then SIZE=tiny
    else SIZE=typical; fi
  fi

  local types="" agents="" passes=""
  [ $t_template = 1 ] && add types template
  [ $t_component = 1 ] && add types component-ts
  [ $t_service = 1 ] && add types service-rxjs
  [ $t_model = 1 ] && add types http-model
  [ $t_routing = 1 ] && add types routing-guard
  [ $t_spec = 1 ] && add types spec
  [ $t_styles = 1 ] && add types styles
  [ $t_shared = 1 ] && add types shared-api
  [ $t_auth = 1 ] && add types auth-permissions
  [ $t_new = 1 ] && add types new-files
  [ $t_config = 1 ] && add types config-docs

  if [ $code = 1 ]; then
    add agents fe-code-reviewer; add agents fe-architecture-reviewer
    add passes Angular; add passes A11y
  fi
  if [ $t_template = 1 ]; then add passes Styling; add passes Apollo; fi
  if [ $t_component = 1 ]; then
    add agents fe-logic-reviewer; add passes Security; add passes Quality
    [ "$SIZE" != tiny ] && ! lean_diff && add agents fe-simplifier
  fi
  if [ $t_service = 1 ]; then
    add agents fe-logic-reviewer; add agents fe-impact-analyzer; add passes Security; add passes Quality
  fi
  if [ $t_model = 1 ]; then
    add agents fe-logic-reviewer; add agents fe-impact-analyzer; add passes Security; add passes Quality
  fi
  if [ $t_routing = 1 ]; then
    add agents fe-impact-analyzer; add passes Security; add passes Quality
  fi
  if [ $t_shared = 1 ]; then
    add agents fe-logic-reviewer; add agents fe-impact-analyzer; add passes Security; add passes Quality
  fi
  if [ $t_auth = 1 ]; then
    add agents fe-logic-reviewer; add agents fe-impact-analyzer; add passes Security
  fi
  if [ $t_spec = 1 ]; then add agents fe-test-analyzer; add passes Test; fi
  if [ $t_styles = 1 ]; then
    add agents fe-code-reviewer; add agents fe-architecture-reviewer; add passes Styling; add passes Apollo
  fi

  agents=$(ordered "$ALL_AGENTS" "$agents")
  passes=$(ordered "$ALL_PASSES" "$passes")
  if [ "$SIZE" = tiny ] && [ -n "$agents" ]; then
    if has "$agents" fe-impact-analyzer; then agents="fe-combined-reviewer fe-impact-analyzer"; else agents="fe-combined-reviewer"; fi
  fi

  local split=false mode=plan reason="$SIZE PR, targeted agents"
  [ "$SIZE" = tiny ] && reason="tiny PR, combined reviewer"
  [ "$SIZE" = huge ] && { split=true; reason="huge PR, recommend split"; }
  if [ -z "$agents" ]; then
    mode=none; reason="config/docs-only; correctness skim only"
  fi
  emit "$mode" "$reason" "$SIZE" "$types" "$agents" "$passes" "$split" "$NFILES" "$loc"
}

JSON=0 ADDS="" DELS="" FILES="" SIZE="" NFILES=0
paths=""
while [ $# -gt 0 ]; do
  case $1 in
    --json) JSON=1 ;;
    --additions) ADDS=${2:-}; shift ;;
    --deletions) DELS=${2:-}; shift ;;
    --files) FILES=${2:-}; shift ;;
    *) paths="$paths$1"$'\n' ;;
  esac
  shift
done

bad=""
case $ADDS in *[!0-9]*) bad="invalid --additions" ;; esac
case $DELS in *[!0-9]*) bad="invalid --deletions" ;; esac
case $FILES in *[!0-9]*) bad="invalid --files" ;; esac
if [ -z "$paths" ] && [ ! -t 0 ]; then paths=$(cat); fi

if [ -n "$bad" ]; then full "$bad"; exit 0; fi
out=$(printf '%s\n' "$paths" | plan 2>/dev/null) && [ -n "$out" ] || out=$(full "internal error")
printf '%s\n' "$out"

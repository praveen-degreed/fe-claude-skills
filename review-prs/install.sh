#!/bin/bash
# Install review-prs skill and its review agents for Claude Code
# Usage: install.sh [--global]
#   env SKILLS_DIR  overrides the target skills directory
#   env AGENTS_DIR  overrides the target agents directory (default: sibling "agents" of the skills dir)
#   env FE_SKILLS_SRC  install from a local checkout of this repo instead of GitHub (for testing)
set -euo pipefail

REPO="praveen-degreed/fe-claude-skills"
PREFIX="review-prs"
GLOBAL=0

for arg in "$@"; do
    case "$arg" in
        --global) GLOBAL=1 ;;
        *) echo "Error: unknown option '$arg'. Usage: install.sh [--global]"; exit 1 ;;
    esac
done

if [ -n "${SKILLS_DIR:-}" ]; then
    BASE="$SKILLS_DIR"
elif [ "$GLOBAL" = 1 ]; then
    BASE="$HOME/.claude/skills"
else
    BASE=".claude/skills"
fi
SKILL_DIR="$BASE/$PREFIX"
AGENTS_DIR="${AGENTS_DIR:-$(dirname "$BASE")/agents}"

echo "Installing $PREFIX skill to $SKILL_DIR/ and agents to $AGENTS_DIR/ ..."

if [ -n "${FE_SKILLS_SRC:-}" ]; then
    if ! FILES=$(cd "$FE_SKILLS_SRC" && find "$PREFIX" -type f | sort | grep -v "^$PREFIX/install.sh$"); then
        echo "Error: could not list files under $FE_SKILLS_SRC/$PREFIX."
        exit 1
    fi
else
    if ! command -v gh &> /dev/null; then
        echo "Error: gh CLI not found. Install with: brew install gh"
        exit 1
    fi
    if ! FILES=$(gh api "repos/$REPO/git/trees/main?recursive=1" \
        --jq ".tree[] | select(.type == \"blob\") | .path | select(startswith(\"$PREFIX/\")) | select(. != \"$PREFIX/install.sh\")"); then
        echo "Error: could not list files for $PREFIX from $REPO (check 'gh auth status' and repo access)."
        exit 1
    fi
fi

if [ -z "$FILES" ]; then
    echo "Error: no files found under $PREFIX/."
    exit 1
fi

SKILL_COUNT=0
AGENT_COUNT=0
while IFS= read -r path; do
    [ -z "$path" ] && continue
    rel="${path#"$PREFIX"/}"
    # Agent definitions go to the agents directory, everything else to the skill directory.
    case "$rel" in
        agents/*.md) dest="$AGENTS_DIR/${rel#agents/}"; kind="agent" ;;
        *)           dest="$SKILL_DIR/$rel"; kind="skill" ;;
    esac
    mkdir -p "$(dirname "$dest")"
    if [ -n "${FE_SKILLS_SRC:-}" ]; then
        cp "$FE_SKILLS_SRC/$path" "$dest.tmp"
    elif ! gh api -H "Accept: application/vnd.github.raw" "repos/$REPO/contents/$path" < /dev/null > "$dest.tmp"; then
        rm -f "$dest.tmp"
        echo "Error: failed to download $path"
        exit 1
    fi
    mv "$dest.tmp" "$dest"
    case "$rel" in
        scripts/*) chmod +x "$dest" ;;
    esac
    if [ "$kind" = "agent" ]; then AGENT_COUNT=$((AGENT_COUNT + 1)); else SKILL_COUNT=$((SKILL_COUNT + 1)); fi
done <<< "$FILES"

echo ""
echo "Installed $SKILL_COUNT skill files to $SKILL_DIR/ and $AGENT_COUNT agents to $AGENTS_DIR/"
echo "Existing agent files with the same names were replaced; edit them in the repo, not locally."
echo ""
echo "Usage: /review-prs <PR_URL>"
echo "       /review-prs --deep <PR_URL>"

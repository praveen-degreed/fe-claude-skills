#!/bin/bash
# Install review-prs skill for Claude Code
# Usage: install.sh [--global]   (env SKILLS_DIR overrides the target skills directory)
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

echo "Installing $PREFIX skill to $SKILL_DIR/ ..."

if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install with: brew install gh"
    exit 1
fi

if ! FILES=$(gh api "repos/$REPO/git/trees/main?recursive=1" \
    --jq ".tree[] | select(.type == \"blob\") | .path | select(startswith(\"$PREFIX/\")) | select(. != \"$PREFIX/install.sh\")"); then
    echo "Error: could not list files for $PREFIX from $REPO (check 'gh auth status' and repo access)."
    exit 1
fi

if [ -z "$FILES" ]; then
    echo "Error: no files found under $PREFIX/ in $REPO."
    exit 1
fi

COUNT=0
while IFS= read -r path; do
    [ -z "$path" ] && continue
    rel="${path#"$PREFIX"/}"
    dest="$SKILL_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    if ! gh api -H "Accept: application/vnd.github.raw" "repos/$REPO/contents/$path" < /dev/null > "$dest.tmp"; then
        rm -f "$dest.tmp"
        echo "Error: failed to download $path"
        exit 1
    fi
    mv "$dest.tmp" "$dest"
    case "$rel" in
        scripts/*) chmod +x "$dest" ;;
    esac
    COUNT=$((COUNT + 1))
done <<< "$FILES"

echo ""
echo "Installed $COUNT files to $SKILL_DIR/"
echo ""
echo "Usage: /review-prs <PR_URL>"
echo "       /review-prs --deep <PR_URL>"

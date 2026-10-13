#!/bin/bash
# Install all fe-claude-skills
# Usage: gh api repos/praveen-degreed/fe-claude-skills/contents/install-all.sh --jq '.content' | base64 -d | bash -s -- [--global]
set -euo pipefail

REPO="praveen-degreed/fe-claude-skills"
ARGS=()

for arg in "$@"; do
    case "$arg" in
        --global) ARGS+=("--global") ;;
        *) echo "Error: unknown option '$arg'. Usage: install-all.sh [--global]"; exit 1 ;;
    esac
done

echo "Installing fe-claude-skills..."
echo ""

if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install with: brew install gh"
    exit 1
fi

echo "=== 1/2: review-prs ==="
gh api "repos/$REPO/contents/review-prs/install.sh" --jq '.content' | base64 -d | bash -s -- ${ARGS[@]+"${ARGS[@]}"}

echo ""

echo "=== 2/2: dev-guard ==="
gh api "repos/$REPO/contents/dev-guard/install.sh" --jq '.content' | base64 -d | bash -s -- ${ARGS[@]+"${ARGS[@]}"}

echo ""
echo "All skills installed."
echo ""
echo "  /review-prs <PR_URL>    Review a PR"
echo "  /dev-guard              Load standards on demand"
echo "  dev-guard                Also auto-loaded every session via CLAUDE.md"

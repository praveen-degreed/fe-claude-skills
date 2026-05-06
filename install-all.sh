#!/bin/bash
# Install all fe-claude-skills
# Usage: gh api repos/praveen-degreed/fe-claude-skills/contents/install-all.sh --jq '.content' | base64 -d | bash
set -e

REPO="praveen-degreed/fe-claude-skills"

echo "Installing fe-claude-skills..."
echo ""

if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install with: brew install gh"
    exit 1
fi

# Install review-prs
echo "=== 1/2: review-prs ==="
gh api "repos/$REPO/contents/review-prs/install.sh" --jq '.content' | base64 -d | bash

echo ""

# Install dev-guard
echo "=== 2/2: dev-guard ==="
gh api "repos/$REPO/contents/dev-guard/install.sh" --jq '.content' | base64 -d | bash

echo ""
echo "All skills installed."
echo ""
echo "  /review-prs <PR_URL>    Review a PR"
echo "  dev-guard                Auto-loaded every session via CLAUDE.md"

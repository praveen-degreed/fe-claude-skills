#!/bin/bash
# Install fe-review-skill for Claude Code
# Works with both public and private repos (uses gh CLI)

set -e

SKILL_DIR=".claude/skills/review-prs"
REPO="praveen-degreed/fe-review-skill"

echo "Installing review-prs skill..."

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install with: brew install gh"
    exit 1
fi

mkdir -p "$SKILL_DIR/references"

# Use gh api to download files (works for private repos)
gh api "repos/$REPO/contents/SKILL.md" --jq '.content' | base64 -d > "$SKILL_DIR/SKILL.md"
gh api "repos/$REPO/contents/references/agent-prompts.md" --jq '.content' | base64 -d > "$SKILL_DIR/references/agent-prompts.md"
gh api "repos/$REPO/contents/references/decision-rules.md" --jq '.content' | base64 -d > "$SKILL_DIR/references/decision-rules.md"
gh api "repos/$REPO/contents/references/review-template.md" --jq '.content' | base64 -d > "$SKILL_DIR/references/review-template.md"
gh api "repos/$REPO/contents/references/deep-mode.md" --jq '.content' | base64 -d > "$SKILL_DIR/references/deep-mode.md"
gh api "repos/$REPO/contents/references/codebase-patterns.md" --jq '.content' | base64 -d > "$SKILL_DIR/references/codebase-patterns.md"
gh api "repos/$REPO/contents/references/rxjs-patterns.md" --jq '.content' | base64 -d > "$SKILL_DIR/references/rxjs-patterns.md"

echo ""
echo "Installed to $SKILL_DIR/"
echo ""
echo "Usage: /review-prs <PR_URL>"
echo "       /review-prs --deep <PR_URL>"

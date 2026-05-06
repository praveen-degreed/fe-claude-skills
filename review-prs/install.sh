#!/bin/bash
# Install review-prs skill for Claude Code
set -e

SKILL_DIR=".claude/skills/review-prs"
REPO="praveen-degreed/fe-claude-skills"
PREFIX="review-prs"

echo "Installing review-prs skill..."

if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install with: brew install gh"
    exit 1
fi

mkdir -p "$SKILL_DIR/references"

gh api "repos/$REPO/contents/$PREFIX/SKILL.md" --jq '.content' | base64 -d > "$SKILL_DIR/SKILL.md"
gh api "repos/$REPO/contents/$PREFIX/references/agent-prompts.md" --jq '.content' | base64 -d > "$SKILL_DIR/references/agent-prompts.md"
gh api "repos/$REPO/contents/$PREFIX/references/decision-rules.md" --jq '.content' | base64 -d > "$SKILL_DIR/references/decision-rules.md"
gh api "repos/$REPO/contents/$PREFIX/references/review-template.md" --jq '.content' | base64 -d > "$SKILL_DIR/references/review-template.md"
gh api "repos/$REPO/contents/$PREFIX/references/deep-mode.md" --jq '.content' | base64 -d > "$SKILL_DIR/references/deep-mode.md"
gh api "repos/$REPO/contents/$PREFIX/references/codebase-patterns.md" --jq '.content' | base64 -d > "$SKILL_DIR/references/codebase-patterns.md"
gh api "repos/$REPO/contents/$PREFIX/references/rxjs-patterns.md" --jq '.content' | base64 -d > "$SKILL_DIR/references/rxjs-patterns.md"

echo ""
echo "Installed to $SKILL_DIR/"
echo ""
echo "Usage: /review-prs <PR_URL>"
echo "       /review-prs --deep <PR_URL>"

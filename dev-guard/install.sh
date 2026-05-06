#!/bin/bash
# Install dev-guard -- development-time coding standards for Claude Code
# Installs to .agent-instructions/ and registers in .claude/CLAUDE.local.md (local-only, not committed)
set -e

REPO="praveen-degreed/fe-claude-skills"
TARGET=".agent-instructions/fe-dev-guard.md"
LOCAL_MD=".claude/CLAUDE.local.md"
GUARD_REF='- **`.agent-instructions/fe-dev-guard.md`** - FE development guard: Angular, TypeScript, RxJS, a11y, security, testing rules enforced during coding. READ THIS before writing any code.'

echo "Installing dev-guard..."

if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install with: brew install gh"
    exit 1
fi

# Ensure directories exist
mkdir -p .agent-instructions
mkdir -p .claude

# Download the guard file
gh api "repos/$REPO/contents/dev-guard/fe-dev-guard.md" --jq '.content' | base64 -d > "$TARGET"

# Add reference to .claude/CLAUDE.local.md (local-only, not committed to repo)
if [ -f "$LOCAL_MD" ]; then
    if ! grep -q "fe-dev-guard.md" "$LOCAL_MD"; then
        echo "" >> "$LOCAL_MD"
        echo "$GUARD_REF" >> "$LOCAL_MD"
        echo "Added fe-dev-guard.md reference to $LOCAL_MD"
    else
        echo "fe-dev-guard.md already referenced in $LOCAL_MD"
    fi
else
    cat > "$LOCAL_MD" << 'LOCALEOF'
# Local Development Standards

## READ on every session

LOCALEOF
    echo "$GUARD_REF" >> "$LOCAL_MD"
    echo "Created $LOCAL_MD with fe-dev-guard.md reference"
fi

echo ""
echo "Installed to $TARGET"
echo "Registered in $LOCAL_MD (local-only, not committed)"
echo ""
echo "Claude will now read these rules at the start of every conversation."
echo "Code written by Claude will follow these standards automatically."

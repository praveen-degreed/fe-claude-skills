#!/bin/bash
# Install dev-guard -- development-time coding standards for Claude Code
# Installs to .agent-instructions/ so Claude reads it at every conversation start
set -e

REPO="praveen-degreed/fe-claude-skills"
TARGET=".agent-instructions/fe-dev-guard.md"
CLAUDE_MD="CLAUDE.md"
GUARD_REF='- **`.agent-instructions/fe-dev-guard.md`** - FE development guard: Angular, TypeScript, RxJS, a11y, testing rules enforced during coding'

echo "Installing dev-guard..."

if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install with: brew install gh"
    exit 1
fi

# Ensure .agent-instructions/ exists
mkdir -p .agent-instructions

# Download the guard file
gh api "repos/$REPO/contents/dev-guard/fe-dev-guard.md" --jq '.content' | base64 -d > "$TARGET"

# Add reference to CLAUDE.md if not already present
if [ -f "$CLAUDE_MD" ]; then
    if ! grep -q "fe-dev-guard.md" "$CLAUDE_MD"; then
        # Find the last .agent-instructions reference and add after it
        if grep -q "agent-instructions/" "$CLAUDE_MD"; then
            # Use awk to insert after the last .agent-instructions line in the READ THESE FILES block
            awk -v ref="$GUARD_REF" '
                /\.agent-instructions\// { last=NR; line=$0 }
                { lines[NR]=$0 }
                END {
                    for (i=1; i<=NR; i++) {
                        print lines[i]
                        if (i==last) print ref
                    }
                }
            ' "$CLAUDE_MD" > "${CLAUDE_MD}.tmp" && mv "${CLAUDE_MD}.tmp" "$CLAUDE_MD"
            echo "Added fe-dev-guard.md reference to CLAUDE.md"
        else
            echo "Warning: Could not find .agent-instructions/ block in CLAUDE.md"
            echo "Manually add this line to the 'READ THESE FILES' section:"
            echo "  $GUARD_REF"
        fi
    else
        echo "fe-dev-guard.md already referenced in CLAUDE.md"
    fi
else
    echo "Warning: CLAUDE.md not found. The guard file is installed but not auto-loaded."
    echo "Add this to your CLAUDE.md 'READ THESE FILES' section:"
    echo "  $GUARD_REF"
fi

echo ""
echo "Installed to $TARGET"
echo ""
echo "Claude will now read these rules at the start of every conversation."
echo "Code written by Claude will follow these standards automatically."

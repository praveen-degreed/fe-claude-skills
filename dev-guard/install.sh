#!/bin/bash
# Install dev-guard -- development-time coding standards
# Installs SKILL.md + references to .claude/skills/dev-guard/ (skill format)
# Also installs fe-standards.md to .agent-instructions/ for always-on loading in Claude Code
# Usage: install.sh   (project-level only; --global is accepted and skipped; env SKILLS_DIR overrides the skills directory)
set -euo pipefail

REPO="praveen-degreed/fe-claude-skills"
PREFIX="dev-guard"

for arg in "$@"; do
    case "$arg" in
        --global)
            echo "dev-guard is project-level only (it writes .agent-instructions/ and .claude/CLAUDE.local.md in the repo)."
            echo "Skipping --global install. Run dev-guard/install.sh from inside each project instead."
            exit 0
            ;;
        *) echo "Error: unknown option '$arg'. Usage: install.sh"; exit 1 ;;
    esac
done

SKILL_DIR="${SKILLS_DIR:-.claude/skills}/$PREFIX"
AGENT_INSTRUCTIONS_TARGET=".agent-instructions/fe-dev-guard.md"
LOCAL_MD=".claude/CLAUDE.local.md"
GUARD_REF='- **`.agent-instructions/fe-dev-guard.md`** - FE development guard: Angular, TypeScript, RxJS, a11y, security, testing rules enforced during coding. READ THIS before writing any code.'

echo "Installing dev-guard..."

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

# Install as Agent Skill (portable format)
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
echo "Installed $COUNT skill files to $SKILL_DIR/"

if [ ! -f "$SKILL_DIR/references/fe-standards.md" ]; then
    echo "Error: references/fe-standards.md was not found in the $PREFIX skill."
    exit 1
fi

# Also install to .agent-instructions/ for always-on loading in Claude Code
mkdir -p .agent-instructions
cp "$SKILL_DIR/references/fe-standards.md" "$AGENT_INSTRUCTIONS_TARGET"

# Add reference to .claude/CLAUDE.local.md (local-only, not committed to repo)
mkdir -p .claude
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
echo "Installed to:"
echo "  $SKILL_DIR/ (Agent Skill format - portable)"
echo "  $AGENT_INSTRUCTIONS_TARGET (always-on loading)"
echo "  Registered in $LOCAL_MD (local-only, not committed)"
echo ""
echo "Claude will read these rules at the start of every conversation."
echo "Other agents can discover the skill via $SKILL_DIR/SKILL.md."

# fe-claude-skills

Claude Code skills for Degreed frontend development. Covers the full cycle: write code right the first time, then verify with automated review.

## Skills

### dev-guard (development-time)

Condensed coding standards loaded at **every conversation start** via `.agent-instructions/`. Claude reads these before writing any code -- same rules that the PR review checks, but as positive guidance ("always do X") instead of negative flags ("you did X wrong").

**Install target:** `.agent-instructions/fe-dev-guard.md` + registered in `.claude/CLAUDE.local.md` (local-only, not committed to your repo)

### review-prs (PR review)

6-agent parallel PR review that posts APPROVE or REQUEST CHANGES directly to GitHub. Reviews Angular patterns, TypeScript quality, accessibility, memory leaks, architecture, test quality, and regression risk.

**Install target:** `.claude/skills/review-prs/`

## Installation

### Install everything (recommended)

```bash
gh api repos/praveen-degreed/fe-claude-skills/contents/install-all.sh --jq '.content' | base64 -d | bash
```

### Install individually

```bash
# Dev guard only (development standards)
gh api repos/praveen-degreed/fe-claude-skills/contents/dev-guard/install.sh --jq '.content' | base64 -d | bash

# PR review only
gh api repos/praveen-degreed/fe-claude-skills/contents/review-prs/install.sh --jq '.content' | base64 -d | bash
```

## How It Works

The dev-guard installer creates `.claude/CLAUDE.local.md` — a **local-only** file that Claude Code reads at every conversation start but is never committed to your repo. This file points Claude to `.agent-instructions/fe-dev-guard.md`, which contains the actual coding standards.

```
New conversation starts
        |
        v
  Claude reads .claude/CLAUDE.local.md (local-only)
        |
        v
  [dev-guard loaded]  <-- .agent-instructions/fe-dev-guard.md
  Claude writes code following the standards
        |
        v
  PR created
        |
        v
  /review-prs <PR_URL>  <-- .claude/skills/review-prs/
  6 agents verify the code
        |
        v
  Fewer findings because dev-guard
  prevented issues during development
```

Your shared `CLAUDE.md` is never modified. Each developer runs the install once and gets local enforcement.

## Structure

```
fe-claude-skills/
├── dev-guard/
│   ├── fe-dev-guard.md          # Coding standards (loaded every session)
│   └── install.sh               # Installs to .agent-instructions/
├── review-prs/
│   ├── SKILL.md                 # PR review skill definition
│   ├── install.sh               # Installs to .claude/skills/
│   └── references/
│       ├── agent-prompts.md     # 6 review agent prompts
│       ├── decision-rules.md    # Approve/reject criteria
│       ├── review-template.md   # GitHub comment template
│       ├── deep-mode.md         # Team consensus logic
│       ├── codebase-patterns.md # Degreed service patterns
│       └── rxjs-patterns.md     # RxJS operator guide
├── install-all.sh               # One-command setup
└── README.md
```

## Updating

Re-run the install command to pull the latest version. The install scripts are idempotent.

## License

MIT

# fe-claude-skills

Claude Code skills for Degreed frontend development, built to the [Agent Skills](https://agentskills.io) open format. Covers the full cycle: write code right the first time, then verify with automated review.

## Skills

### dev-guard (development-time)

Condensed coding standards loaded at **every conversation start** via `.agent-instructions/`. Claude reads these before writing any code -- same rules that the PR review checks, but as positive guidance ("always do X") instead of negative flags ("you did X wrong").

**Install target:** `.claude/skills/dev-guard/` (Agent Skill) + `.agent-instructions/fe-dev-guard.md` (always-on) + registered in `.claude/CLAUDE.local.md` (local-only, not committed to your repo)

### review-prs (PR review)

6-agent parallel PR review that posts one organized review to GitHub: a category scoreboard (Pass/Fail), things to address with severity labels and fixes, and a final decision. A category fails only on Critical/High findings; any failure means request changes, otherwise approve. Incomplete reviews are posted comment-only. Reviews Angular patterns, TypeScript quality, accessibility, memory leaks, architecture, test quality, and regression risk.

**Install target:** `.claude/skills/review-prs/` (or `~/.claude/skills/review-prs/` with `--global`)

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

### Global install (all projects)

Pass `--global` to install skills to `~/.claude/skills/` instead of the current project's `.claude/skills/`. Set `SKILLS_DIR` to use any other skills directory.

```bash
# Everything (review-prs global; dev-guard is skipped, see below)
gh api repos/praveen-degreed/fe-claude-skills/contents/install-all.sh --jq '.content' | base64 -d | bash -s -- --global

# PR review only
gh api repos/praveen-degreed/fe-claude-skills/contents/review-prs/install.sh --jq '.content' | base64 -d | bash -s -- --global
```

`dev-guard` is project-level only because it writes `.agent-instructions/` and `.claude/CLAUDE.local.md` into the repo; with `--global` it prints a notice and skips. Run its installer from inside each project.

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
│   ├── SKILL.md                 # Agent Skill definition (portable format)
│   ├── references/
│   │   └── fe-standards.md      # Full coding standards
│   └── install.sh               # Installs skill + .agent-instructions/
├── review-prs/
│   ├── SKILL.md                 # Agent Skill definition (portable format)
│   ├── install.sh               # Installs to .claude/skills/
│   └── references/
│       ├── agent-prompts.md     # 6 review agent prompts
│       ├── decision-rules.md    # Decision rules and severity triggers
│       ├── review-template.md   # GitHub comment template
│       ├── deep-mode.md         # Team consensus logic
│       ├── codebase-patterns.md # Degreed service patterns
│       └── rxjs-patterns.md     # RxJS operator guide
├── evals/
│   ├── review-prs-triggers.json # Trigger eval queries for review-prs
│   └── dev-guard-triggers.json  # Trigger eval queries for dev-guard
├── install-all.sh               # One-command setup
└── README.md
```

## Agent Skills Compliance

Both skills follow the [Agent Skills specification](https://agentskills.io/specification):

- **SKILL.md** with YAML frontmatter (`name`, `description`, `license`, `compatibility`, `metadata`)
- **Progressive disclosure** — lightweight SKILL.md bodies with detailed `references/` loaded on demand
- **Eval queries** in `evals/` for [description optimization](https://agentskills.io/skill-creation/optimizing-descriptions)
- **`name` matches directory name** per the spec naming convention

> **Note:** `review-prs` uses Claude Code-specific multi-agent features (`Agent`, `Team*`, `Task*` tools). The workflow phases can be followed manually by other agents, but parallel agent execution requires Claude Code.

## Updating

Re-run the install command to pull the latest version. The install scripts are idempotent.

## License

MIT

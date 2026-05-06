---
name: review-prs
description: "Frontend PR review with GitHub integration. Reviews Angular/TypeScript PRs for patterns, accessibility, Apollo design system, and test quality. Use when asked to review a PR, check a PR, or provide a GitHub PR URL. Automatically posts APPROVE or REQUEST CHANGES to GitHub."
argument-hint: "[--deep] <PR_URL> [<PR_URL2> ...]"
allowed-tools: Bash, Read, Glob, Grep, Agent, Task*, Team*
handoffs:
  - label: Run Tests
    agent: dgx-test-runner
    prompt: Run tests for the files changed in this PR
  - label: Simplify Code
    agent: simplify
    prompt: Review the changed code for simplification opportunities
---

# Review PRs (Frontend)

Frontend-focused PR review for Angular 20+, TypeScript, Apollo Design System, and Degreed FE workspace patterns.

## Usage

```
/review-prs <PR_URL>                    # Standard review (6 parallel agents)
/review-prs --deep <PR_URL>             # Deep review (2 reviewers x 5 agents)
```

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated: `gh auth status`
- Repository access to the PR

## Execution (Automatic - No User Input Required)

### Phase 0: Setup
1. Parse PR URL to extract `OWNER`, `REPO`, `PR_NUMBER`
2. Fetch PR branch: `gh pr view <PR_NUMBER> --repo <OWNER/REPO> --json headRefName,author`
3. Set `WORKTREE_PATH` to current directory, `LOCAL_ACCESS=true`

### Phase 1: Fetch Context
1. Get PR metadata: `gh pr view <PR_NUMBER> --repo <OWNER/REPO> --json title,body,files,additions,deletions,headRefName,baseRefName,state`
2. Get diff: `gh pr diff <PR_NUMBER> --repo <OWNER/REPO>`
3. Assess PR health (scope, size, breaking changes)
4. Flag "Large PR" if: >600 LOC, >20 files, or >4 modules

### Phase 1.5: Review History
1. Fetch prior reviews: `gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/reviews`
2. Fetch commits: `gh pr view <PR_NUMBER> --repo <OWNER/REPO> --json commits`
3. Build context: map prior issues to FIXED / STILL OPEN / PARTIALLY FIXED

### Phase 2-4: Agent Reviews

**Reference: `references/agent-prompts.md`**

Launch 6 agents IN PARALLEL with PR diff + review context:
1. **fe-code-reviewer** - Angular patterns, TypeScript, security, i18n
2. **fe-logic-reviewer** - Logic, edge cases, memory leaks, signals
3. **fe-test-analyzer** - Test quality, Jest/Spectator, a11y tests
4. **fe-simplifier** - Simplification opportunities (non-blocking)
5. **fe-architecture-reviewer** - Architecture, WCAG 2.2 AA, Apollo, Nx
6. **fe-impact-analyzer** - Regression, blast radius, usage validation, best practices

For `--deep` mode, see `references/deep-mode.md`.

### Phase 4.5: Practical Filter

**Reference: `references/decision-rules.md`**

Filter findings by probability x impact matrix. Drop theoretical/hyperbolic issues.

### Phase 5: Post Review

**Reference: `references/decision-rules.md`** for APPROVE/REQUEST CHANGES criteria.
**Reference: `references/review-template.md`** for comment structure.

Post to GitHub:
```bash
gh pr review <PR_NUMBER> --repo <OWNER/REPO> --approve --body "..."
# OR
gh pr review <PR_NUMBER> --repo <OWNER/REPO> --request-changes --body "..."
```

### Phase 6: Cleanup
- Report completion
- Deep mode: `TeamDelete` to shutdown team

## Safety Guardrail

If `gh` commands fail, diff is incomplete, or agents error:
- Post review with available findings
- Mark as "Review Incomplete - Manual Decision Required"
- Do NOT post --approve or --request-changes

## When NOT to Use

- Backend PRs (Angular/TypeScript only)
- Documentation-only PRs
- Generated code (schema files, lock files)
- PRs with 50+ files (split first)

## Related Skills

- `/dgx-test-runner` - Run tests for changed files
- `/simplify` - Apply simplification suggestions
- `/dgx-a11y-warn` - Deep accessibility analysis

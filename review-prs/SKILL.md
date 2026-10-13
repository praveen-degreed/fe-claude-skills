---
name: review-prs
description: >
  Frontend PR review with GitHub integration for Angular 22/TypeScript codebases.
  Triages the PR, runs only the relevant review agents, and checks patterns,
  accessibility (WCAG 2.2 AA), Apollo design system, RxJS, memory leaks, and test
  quality. Use when asked to review a PR, check a PR, or given a GitHub PR URL — even
  without the word "review." Posts one organized review (category scoreboard, things to address) with a final
  approve / request-changes decision. Not for backend PRs, docs-only changes, or generated/lock files.
license: MIT
compatibility: >
  Requires GitHub CLI (gh) installed and authenticated. Designed for Claude Code
  with multi-agent support (Agent, Team*, Task* tools).
allowed-tools: Bash Read Glob Grep Agent Task* Team*
metadata:
  author: praveen-degreed
  version: "2.0"
  argument-hint: "[--deep] <PR_URL> [<PR_URL2> ...]"
  handoffs: "dgx-test-runner (Run Tests), simplify (Simplify Code)"
---

# Review PRs (Frontend)

Frontend-focused PR review for Angular 22, TypeScript, Apollo Design System, and Degreed FE workspace patterns. Standalone: everything it needs ships in this skill.

## Usage

```
/review-prs <PR_URL>                    # Standard: triaged, only relevant agents
/review-prs --deep <PR_URL>             # Deep review (2 reviewers x 5 agents)
```

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated: `gh auth status`
- Repository access to the PR

## Optional features (degrade gracefully)

Backend contract check (`../Degreed`, `../degreed-coach-builder`, override with `REVIEW_BACKEND_REPOS`), Jira lookup, and CI-bot dedupe are best effort. If one is unavailable, continue and add an explicit line to the review: `Not verified: <what> (<why>)` (contract: `contract not verified: <reason>`). Never block on them, never guess a contract.

API contract check: when the diff adds/changes an HTTP call, GraphQL query, or `*.model.ts`, fe-impact-analyzer follows `references/contract-check.md` (uses `scripts/find-endpoint.sh`, max 3 endpoints).

## Execution (Automatic - No User Input Required)

### Step 0: Fetch once, then triage

**Reference: `references/routing-and-budgets.md`**

1. Parse the PR URL into `OWNER`, `REPO`, `PR_NUMBER`.
2. Run `<skill dir>/scripts/fetch-pr.sh <PR_NUMBER> [--repo OWNER/REPO]` ONCE. It prints a temp dir (the fetch dir) holding `pr.diff`, `files.txt`, `meta.json`, `checks.txt`, and `head/<path>` (full changed files at the PR head). No other step calls `gh` for PR content; agents never do.
3. Read `meta.json` for additions, deletions, files. Run `<skill dir>/scripts/triage.sh --additions <N> --deletions <N> --files <N>` with the changed paths (`files.txt`) on stdin. Add `--json` to parse it.
4. Print the plan at the top of the review. First line `FULL:` means fail open: run all agents and state the reason. If triage errors or a script is missing, fail open.
5. `huge` size: stop and ask the author to split. Do not review.
6. Read `checks.txt` and report failing checks first. If unreadable, add `Not verified: CI status`.

### Step 1: Understand and review history (skip for tiny PRs; degrade gracefully)

1. Read the PR body and the linked ticket if reachable. Write 5 lines: intent, acceptance criteria, risky areas. If the ticket is unreachable, say `Not verified: ticket`.
2. Prior reviews: `gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/reviews`. Map prior issues to FIXED / STILL OPEN / PARTIALLY FIXED and summarize for the agents.

### Step 2: Run Agents

**Reference: `references/agent-prompts.md`** (prompts), **`references/passes.md`** (passes, ownership, severity, rule vs suggestion).

Launch ONLY the agents the plan selects, in parallel in one message (all specialists on fail open).

- Tiny PR (<100 added lines, <=5 files): ONE `fe-combined-reviewer` (plus `fe-impact-analyzer` only when routed). It reads only the passes.md sections for the plan's Passes.
- Larger PR: specialists.

| Agent | Focus |
|---|---|
| fe-combined-reviewer | all selected passes in one agent (tiny PRs) |
| fe-code-reviewer | Angular patterns, TypeScript, styling, security, i18n |
| fe-logic-reviewer | logic, edge cases, memory leaks, signals |
| fe-test-analyzer | test quality, Jest/Spectator |
| fe-simplifier | simplification (suggestions only; skipped on deletion-heavy PRs) |
| fe-architecture-reviewer | architecture, WCAG 2.2 AA, Apollo, Nx |
| fe-impact-analyzer | regression, blast radius, usage validation |

Give every agent the review-history summary and ONLY its own section of `agent-prompts.md` preceded by the "Budget preamble", plus this brief (fill the braces; budgets per the plan: tiny ~10/6, typical ~20/8, large ~30/10). Do not paste the diff or other agents' prompts. fe-impact-analyzer also runs the capped reuse/precedent/sibling search defined in its prompt.

ORCHESTRATOR BRIEF TEMPLATE:

```
Fetch dir: {path}
Triage plan: {plan line}
Your passes: {passes}
Budget: {N} successful tool calls (failed calls do not count), max {M} findings.
Read references/passes.md whole and your own prompt section only.
Cite head/<path> lines for PR files; say "local checkout" for lines taken from the local checkout.
Read-only.
```

"No findings" is a valid result for any agent; never ask an agent to find something.

Deadline: at target time +50%, stop stragglers with TaskStop, mark their area "not completed", and post comment-only (no decision).

For `--deep` mode, see `references/deep-mode.md`.

### Step 3: Verify and Filter

**Reference: `references/decision-rules.md`**

1. Drop any finding without a `file:line` the agent actually opened; re-open the line to confirm the rest.
2. MERGE findings with the same file:line (or the same root cause) into one; keep the domain owner's version (`passes.md` ownership table). Drop findings outside the reporter's owned domain.
3. Apply the probability x impact filter. Drop theoretical issues.
4. Split by kind (`passes.md`): rules are posted; suggestions go in a separate Suggestions section, max 3.
5. Assign each finding to a category: Architecture & Quality, Logic, Angular, Tests, Accessibility, Apollo & Styling, Security & Performance, Contract. Include only categories the plan covers.
6. Compute statuses (`decision-rules.md` Decision): a category is `🔴 Fail` only with at least one Critical/High finding after the filter, else `🟢 Pass`. Medium/Low never fail.

### Step 4: Post Review

**Reference: `references/review-template.md`** (structure), **`references/decision-rules.md`** (severity triggers).

Post ONE organized review: plan and CI line, prior-issue status, Scoreboard (`| Category | Status | To address |`), Things to address (Critical/High first, grouped by category, severity labels, Fix lines), Suggestions, `Not verified`, then the final line `**Review result:** Approved` (no category failed) or `**Review result:** Changes requested` (at least one failed). No findings: all Pass, Approved.

```bash
gh pr review <PR_NUMBER> --repo <OWNER/REPO> --approve --body-file <file>          # Approved
gh pr review <PR_NUMBER> --repo <OWNER/REPO> --request-changes --body-file <file>  # Changes requested
gh pr review <PR_NUMBER> --repo <OWNER/REPO> --comment --body-file <file>          # incomplete only
```

Agents are read-only and never call `gh`; only the orchestrator decides and posts. If the PR body says it must be held/paired with another change, add a "Before merge" note; the result rule is unchanged.

Deep mode: `TeamDelete` after posting.

## Safety Guardrail

If `gh` commands fail, the diff is incomplete, or agents error or time out: post comment-only (`--comment`) with the findings so far and a `Not verified` line listing the areas `not completed`. Never approve or request changes on an incomplete review.

## When NOT to Use

- Backend PRs (Angular/TypeScript only)
- Documentation-only PRs
- Generated code (schema files, lock files)
- PRs over 50 files (split first)

## Related Skills

- `/dgx-test-runner` - Run tests for changed files
- `/simplify` - Apply simplification suggestions
- `/dgx-a11y-warn` - Deep accessibility analysis

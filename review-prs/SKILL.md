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
  version: "2.3"
  argument-hint: "[--deep] <PR_URL> [<PR_URL2> ...]"
  handoffs: "dgx-test-runner (Run Tests), simplify (Simplify Code)"
---

# Review PRs (Frontend)

Frontend-focused PR review for Angular 22, TypeScript, Apollo Design System, and Degreed FE workspace patterns. Standalone: everything it needs ships in this skill.

## Usage

```
/review-prs <PR_URL>                    # Standard: triaged, only relevant agents
/review-prs --deep <PR_URL>             # Deep review (2 reviewers x 5 agents)
# Huge PRs (>1500 added or >50 files) are auto-split into review units, reviewed fully, consolidated and posted as one review
```

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated: `gh auth status`
- Repository access to the PR
- The review agents (`fe-combined-reviewer`, `fe-code-reviewer`, `fe-logic-reviewer`, `fe-test-analyzer`, `fe-simplifier`, `fe-architecture-reviewer`, `fe-impact-analyzer`). They live in `agents/` of this skill's repo and `install.sh` installs them to `.claude/agents/` (`~/.claude/agents/` with `--global`). Without them the named agents do not exist; install again or copy them there.

## Optional features (degrade gracefully)

Backend contract check (`../Degreed`, `../degreed-coach-builder`, override with `REVIEW_BACKEND_REPOS`), Jira lookup, and CI-bot dedupe are best effort. If one is unavailable, continue and add an explicit line to the review: `Not verified: <what> (<why>)` (contract: `contract not verified: <reason>`). Never block on them, never guess a contract.

API contract check: when the diff adds/changes an HTTP call, GraphQL query, or `*.model.ts`, fe-impact-analyzer follows `references/contract-check.md` (uses `scripts/find-endpoint.sh`, max 3 endpoints).

## Execution (Automatic - No User Input Required)

### Step 0: Fetch once, then triage

**Reference: `references/routing-and-budgets.md`**

1. Parse the PR URL into `OWNER`, `REPO`, `PR_NUMBER`.
2. Run `<skill dir>/scripts/fetch-pr.sh <PR_NUMBER> [--repo OWNER/REPO]` ONCE. It prints a temp dir (the fetch dir) holding `pr.diff`, `files.txt`, `meta.json`, `checks.txt`, and `head/<path>` (full changed files at the PR head). No other step calls `gh` for PR content; agents never do. Then, still inside the repo's checkout, run `<skill dir>/scripts/pr-worktree.sh create <PR_NUMBER>`: it prints the worktree dir, then the head sha. That worktree is the PR-pinned code that every "local checkout" read and code search uses (pass it to agents as `Checkout:`); the user's own checkout is never touched. If it fails, continue with the fetch dir only and add `Not verified: PR-pinned code search (<reason>)`. Then run `<skill dir>/scripts/review-scan.sh <fetch dir> <worktree dir>` as its own Bash call (omit the worktree dir if none): it writes `<fetch dir>/scan.txt`, deterministic leads on the added lines for reuse of existing shared code, constants, long methods, code placement (what belongs in a util, model, constants file or shared lib) and security, which the agents confirm. If it fails, continue and add `Not verified: reuse/constants scan`.
3. Read `meta.json` for additions, deletions, files. Run `<skill dir>/scripts/triage.sh --additions <N> --deletions <N> --files <N>` with the changed paths (`files.txt`) on stdin. Add `--json` to parse it.
4. Print the plan at the top of the review. First line `FULL:` means fail open: run all agents and state the reason. If triage errors or a script is missing, fail open.
5. `huge` size: chunked review. Run `<skill dir>/scripts/split-pr.sh <fetch dir>` and follow `references/chunked-review.md` (Steps 1-3 run per review unit with each unit's own plan; then a cross-unit pass and one PR-level simplifier pass on the files `split-pr.sh` lists, one consolidation/verification, ONE posted review). Only if split-pr.sh exits 3 (>12 code units) ask the author to split.
6. Read `checks.txt` and report failing checks first. It lists ONLY failing checks, so an empty file means no check is failing (say "CI: no failing checks"). Add `Not verified: CI status` only if `checks.txt` is missing or fetch-pr.sh reported an error. When it lists failing checks, run `<skill dir>/scripts/ci-failures.sh <fetch dir>` as its own Bash call: it reads each GitHub Actions failed-step log and writes `<fetch dir>/ci-failures.txt` with the failing spec (marked `IN-PR` when this PR changes it), the failing test, the assertion excerpt, any TS/Angular/lint error, and whether the run is for the PR head or a stale commit. The review's CI line states the cause, never "red" alone. A check outside GitHub Actions (for example Azure) is `Not verified: CI cause (<check>: not readable here)`. Never write "green" or "no failing checks" while `checks.txt` lists a failing check.

### Step 1: Understand and review history (skip for tiny PRs; degrade gracefully)

1. Read the PR body and the linked ticket if reachable. Write 5 lines: intent, acceptance criteria, risky areas. If the ticket is unreachable, say `Not verified: ticket`.
2. Prior reviews: `gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/reviews`. Map prior issues to FIXED / STILL OPEN / PARTIALLY FIXED and summarize for the agents.

### Step 2: Run Agents

**Reference: `agents/<name>.md`** (each agent's role prompt, installed to the agents directory by `install.sh`), **`references/agent-prompts.md`** (the budget preamble and the agent index), **`references/passes.md`** (passes, ownership, severity, rule vs suggestion).

Launch ONLY the agents the plan selects, in parallel in one message (all specialists on fail open). Launch every agent with `run_in_background: false`: each call then returns that agent's findings, so there is nothing to wait for. Never poll or wait with `ScheduleWakeup`, `sleep` or status-only turns; every extra turn re-reads the whole context (a large PR once spent 9 idle turns this way).

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

Each agent already carries its own role prompt (its agent file), so give every agent the "Budget preamble" from `agent-prompts.md`, the review-history summary and this brief (fill the braces; budgets per the plan: tiny ~10/6, typical ~20/8, large ~30/10). Do not paste the diff. fe-impact-analyzer also runs the capped reuse/precedent/sibling search defined in its agent file.

ORCHESTRATOR BRIEF TEMPLATE:

```
Fetch dir: {path}
Checkout: {worktree path, or "none"}
Scan: {fetch dir}/scan.txt (leads for your files; confirm each by opening the cited line and the existing code; never a finding on its own)
CI failures: {the ci-failures.txt lines that name a spec in your files, so the test agent explains them; omit the line when there are none}
Triage plan: {plan line}
Your passes: {passes}
Skip: {Logic, only when the plan's Brief line says so (fe-logic-reviewer also runs); otherwise omit this line}
Budget: {N} successful tool calls (failed calls do not count), max {M} findings.
Read only the references/passes.md sections for your Passes plus Review method and Placement (not the whole file) and your own prompt section.
Cite head/<path> line numbers from a Read or `grep -n` of that file, never an offset into pr.diff; say "local checkout" for lines taken from the local checkout.
Read-only.
```

"No findings" is a valid result for any agent; never ask an agent to find something. But a result is only valid if the agent really read the code: check each report's `Opened:` line against the changed non-spec files it was given. If files are missing, send that agent ONE follow-up (SendMessage) naming the files to open and re-report; do not launch a new agent. If it still did not open them, list those files under `Not verified` as `not completed` for that agent's passes.

Deadline: at target time +50%, stop stragglers with TaskStop, mark their area "not completed", and post comment-only (no decision).

For `--deep` mode, see `references/deep-mode.md`. For `huge` PRs, see `references/chunked-review.md` (deep mode is not combined with chunking; chunked uses the standard agents per unit).

### Step 3: Verify and Filter

**Reference: `references/decision-rules.md`**

1. Verify EVERY citation, all severities, in one Bash call: `<skill dir>/scripts/verify-citations.sh <fetch dir> 'path:line=token' ...` with a literal path and one quoted argument per finding. `token` is a code identifier the finding relies on, so a line that exists but is about something else fails. A reuse finding cites two locations (the new code and the existing util); verify both. Act on each result: `OK` keep; `MISMATCH` or `BAD` find the real line with `<skill dir>/scripts/verify-citations.sh --find <fetch dir> <path> <token>` and re-check, or drop the finding; `UNVERIFIABLE` or `UNCHECKED` post only if labelled "local checkout" with a line you opened, else drop it and add one line to `Not verified`. A finding whose line was never opened is never posted, and no finding says it was not re-opened (a real review posted `quiz.service.spec.ts:580` for a 76-line file: a diff offset).
2. Prior-review items and agent claims you repeat are re-derived from the head code now, not copied: state only the behaviour you confirmed (a prior review said declined removals also drop adds and changes; the code showed they do not).
3. MERGE findings with the same file:line (or the same root cause) into one; keep the domain owner's version (`passes.md` ownership table). Drop findings outside the reporter's owned domain.
4. Apply the probability x impact filter. Drop theoretical issues.
5. Split by kind (`passes.md`): rules are posted; suggestions go in a separate Suggestions section, max 3. A Medium or Low "suggestion-level" item in Things to address is not allowed: it is a rule or it goes to Suggestions.
6. Assign each finding to a category: Architecture & Quality, Logic, Angular, Tests, Accessibility, Apollo & Styling, Security & Performance, Contract. Include only categories the plan covers.
7. Compute statuses (`decision-rules.md` Decision): a category is `🔴 Fail` only with at least one Critical/High finding after the filter, else `🟢 Pass`. Medium/Low never fail.

### Step 4: Post Review

**Reference: `references/review-template.md`** (structure), **`references/decision-rules.md`** (severity triggers).

Post ONE organized review (also for chunked PRs): plan, review-units line (chunked only) and CI line, prior-issue status, Scoreboard (`| Category | Status | To address |`), Things to address (Critical/High first, grouped by category, severity labels, Fix lines), Suggestions, `Not verified`, then the final line `**Review result:** Approved` (no category failed) or `**Review result:** Changes requested` (at least one failed). No findings: all Pass, Approved.

Write the review to `<fetch dir>/review.md` with the **Write tool** (the fetch dir from Step 0, so it needs no other writable location). Never create it with Bash (`cat > file <<EOF`, `echo >`, `tee`): a `D=...` prefix plus a heredoc redirect was refused in a restricted run, so the review was never written or posted.

Lint it before posting, as its own Bash call with literal paths: `<skill dir>/scripts/lint-review.sh <fetch dir>/review.md --fetch-dir <fetch dir>`. It checks the structure, that the result line matches the Scoreboard, that an incomplete review has no result line, that no finding admits an unverified line, that every cited line exists at the PR head, that the CI line never says "green" while checks are failing, and that a failing spec this PR changes is named. Fix every `FAIL` in `review.md` and lint again (`WARN` is for your judgement; a missing line number is fine only for a file-level finding). Never post a review that fails lint. Then post from it:

```bash
gh pr review <PR_NUMBER> --repo <OWNER/REPO> --approve --body-file <fetch dir>/review.md          # Approved
gh pr review <PR_NUMBER> --repo <OWNER/REPO> --request-changes --body-file <fetch dir>/review.md  # Changes requested
gh pr review <PR_NUMBER> --repo <OWNER/REPO> --comment --body-file <fetch dir>/review.md          # incomplete only
```

Run each command above as its own Bash call with literal absolute paths: no `VAR=...` prefixes, no pipes (`| tail`), no `;` or `&&` chains, no `$(...)`. Restricted runs match a command by its first words and refuse a compound command as a whole; a chained post-and-cleanup command was refused once and the review was never posted.

Agents are read-only and never call `gh`; only the orchestrator decides and posts. If the PR body says it must be held/paired with another change, add a "Before merge" note; the result rule is unchanged.

Deep mode: `TeamDelete` after posting.

### Step 5: Clean up

After posting (also after a comment-only post from the Safety Guardrail, and when the review ends without posting), remove the fetch dir and the worktree:

```bash
<skill dir>/scripts/cleanup-pr.sh <fetch dir>
<skill dir>/scripts/pr-worktree.sh cleanup <worktree dir>    # skip if no worktree was created
```

Run them as two separate Bash calls with literal paths (same rule as Step 4). Each script deletes only its own folder (`review-pr-<number>.*` and `review-wt-<number>.*`) directly inside the temp dir and refuses anything else. If one errors, say so in one line; never retry with a broader `rm`.

## Safety Guardrail

If `gh` commands fail, the diff is incomplete, or agents error or time out: post comment-only (`--comment`) with the findings so far and a `Not verified` line listing the areas `not completed`. Never approve or request changes on an incomplete review.

Cost is never a reason to skip a planned agent or a review unit. Cost control is the plan's tiering (triage, the tiny combined reviewer, the chunked lean tier), already applied by `triage.sh` and `split-pr.sh`. If you run fewer agents than the plan lists for any reason, that area is `not completed`, the review is comment-only, and there is no result line. A real review of an 83-file PR skipped its per-unit agents to save tokens and still posted `Approved`; that is the failure this rule prevents.

## When NOT to Use

- Backend PRs (Angular/TypeScript only)
- Documentation-only PRs
- Generated code (schema files, lock files)

## Related Skills

- `/dgx-test-runner` - Run tests for changed files
- `/simplify` - Apply simplification suggestions
- `/dgx-a11y-warn` - Deep accessibility analysis

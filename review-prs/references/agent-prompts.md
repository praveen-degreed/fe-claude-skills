# Agent Prompts

Tiny PRs (plan lists `fe-combined-reviewer`): use Agent 0, plus Agent 6 only if routed. Larger PRs: the specialists below.

0. fe-combined-reviewer - all selected passes in one agent (tiny PRs)
1. fe-code-reviewer - Angular patterns, TypeScript, security, i18n, dead code
2. fe-logic-reviewer - Logic, edge cases, cleanup/leaks, signals
3. fe-test-analyzer - Test quality, Jest/Spectator
4. fe-simplifier - Simplification suggestions (non-blocking)
5. fe-architecture-reviewer - Architecture, WCAG 2.2 AA, Apollo, Nx
6. fe-impact-analyzer - Regression, blast radius, usage validation, reuse/precedent search, API contract check

## Budget preamble (orchestrator prepends ONCE to every agent prompt)

```
Tool-call budget: {N} (failed calls do not count). When reached, stop and return partial findings.
Max {M} findings, highest severity first. Return file:line + one sentence per finding.
Context lives in the fetch dir <FETCH_DIR>: pr.diff, files.txt, meta.json, checks.txt,
head/<path> (full changed files at the PR head). Read from it. No gh calls, no git checkout.
Cite head/<path> line numbers you opened; lines found by searching the local checkout are labelled
"local checkout", never mixed in unlabelled. Never cite a line you did not open. A line number comes
from a Read or `grep -n` of head/<path>, never an offset into pr.diff (those do not exist in the file).
Use Grep or bash grep (Grep tool may be unavailable; quote globs: --include='*.ts'). Never cat/head whole files, use Read with offset/limit. Do not paste file contents.
Fix samples carry no comments except one one-line trap comment when genuinely needed.
Read only the references/passes.md sections for your Passes, plus Severity, Kind, Domain ownership, Review method and Placement (not the whole file).
Read the lines of <FETCH_DIR>/scan.txt for your files (reuse, constants, helpers, security leads) when it exists: confirm each lead by opening the cited line and the existing code it names; a lead alone is never a finding.
If the brief says `Skip: <pass>`, another agent owns that pass: do not review or report it.
Read head/<path> whole for every changed non-spec file you report on or judge clean; a diff-only read is not accepted. End your report with `Opened: <the head/<path> files you read>`.
Report only findings that need action; omit "checked, no action" items and anything inaccurate-but-fine.
"No findings" is a valid result; do not pad. On a deletion-only diff, check only that nothing
left behind (callers, comments, imports, tests) is now wrong.
Report only your own domain (passes.md ownership table). Never report unchanged lines (e.g. an
explicit OnPush on an unchanged line), except a context line this diff makes wrong; scope beats checklist items.
Do NOT re-raise issues marked FIXED in the review history unless the fix is incomplete.

Review history:
<REVIEW_CONTEXT_SUMMARY>
```

---

---

## Agent 0: fe-combined-reviewer

Role prompt: `agents/fe-combined-reviewer.md` (installed to the agents directory by `install.sh`).

## Agent 1: fe-code-reviewer

Role prompt: `agents/fe-code-reviewer.md` (installed to the agents directory by `install.sh`).

## Agent 2: fe-logic-reviewer

Role prompt: `agents/fe-logic-reviewer.md` (installed to the agents directory by `install.sh`).

## Agent 3: fe-test-analyzer

Role prompt: `agents/fe-test-analyzer.md` (installed to the agents directory by `install.sh`).

## Agent 4: fe-simplifier

Role prompt: `agents/fe-simplifier.md` (installed to the agents directory by `install.sh`).

## Agent 5: fe-architecture-reviewer

Role prompt: `agents/fe-architecture-reviewer.md` (installed to the agents directory by `install.sh`).

## Agent 6: fe-impact-analyzer

Role prompt: `agents/fe-impact-analyzer.md` (installed to the agents directory by `install.sh`).

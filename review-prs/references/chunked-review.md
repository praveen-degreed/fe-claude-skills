# Chunked Review (huge PRs)

A PR is `huge` (>1500 added lines or >50 files) when it cannot be reviewed in one pass. Do not stop and do not ask the author to split. Break it into review units, run the full review steps on every unit, then consolidate, verify and post ONE review.

Only if `split-pr.sh` exits 3 (more than 12 code units, roughly >7000 added lines) stop and ask the author to split; say why.

## Flow

1. **Fetch once** (SKILL.md Step 0), including `review-scan.sh` once for the whole PR (agents read only the `scan.txt` lines for their unit's files). Run `scripts/split-pr.sh <fetch dir>`. It writes `units/<name>/{files.txt,stats.txt,pr.diff,plan.txt}` and prints the index (unit, files, +/-, plan). Print the index at the top of the review.
2. **Understand once** (Step 1): one intent / acceptance criteria / prior-review summary for the whole PR, shared by every unit.
3. **Review each unit** with the normal steps. The unit's `plan.txt` is its triage plan (agents, passes, budget; a lone giant file is reviewed with the large budget). Run exactly the agents `plan.txt` lists, for every unit: the plan is already the cost-controlled tier (see "Lean tier" below), so never drop agents or whole units to save tokens. Brief per agent as in SKILL.md Step 2, with these changes:
   - `Fetch dir:` is the PR fetch dir (so `head/<path>` still resolves); add `Unit: <name>` and `Diff: <fetch dir>/units/<name>/pr.diff`. The agent reviews ONLY the files in `units/<name>/files.txt` and reads that diff slice, not the whole `pr.diff`.
   - Add one line of cross-unit context: the other units' file lists are in `units/index.txt`; the agent may Read/Grep files outside its unit to check callers/types but must not report findings on them.
   - Budgets and finding caps apply per agent per unit.
   - Run units in waves of at most 3 in parallel (all of a unit's agents in one message). Do not launch every unit at once. Launch with `run_in_background: false` so the calls return the findings; start the next wave as soon as they return, with no waiting, polling or status-only turns in between.
   - `unit-misc` (docs/config/assets) gets a correctness skim by the orchestrator, no agents.
4. **Cross-unit pass** (after all units): ONE `fe-impact-analyzer` for the whole PR, large budget (~30 calls, max 10 findings), told to look only for what per-unit review cannot see: a changed export/model/signature in one unit consumed in another, inconsistent patterns across units, duplicated helpers added in different units, contract shape (`contract-check.md`) vs. callers. Give it `units/index.txt` and the finding summaries (title + file:line only). Skip it when no unit touches service/store/model/shared/routing/auth files.
5. **Simplifier pass** (suggestions only): if `units/simplify-files.txt` is not empty, run ONE `fe-simplifier` for the whole PR on exactly those files (the largest added non-spec code files, at most 5; `split-pr.sh` writes the list and leaves it empty for deletion-heavy or tiny PRs). Brief it as in SKILL.md Step 2 with `Files:` set to that list, budget ~20 calls, max 3 suggestions. It is non-blocking: if it fails or times out, add `Not verified: simplification pass` and continue; it never makes the review incomplete. It can run in the same message as the cross-unit pass.
6. **Consolidate and verify** (Step 3) on the merged list from all units and the cross-unit pass:
   - Verify every finding's citation (all severities, not only Critical/High) with `scripts/verify-citations.sh` as in SKILL.md Step 3.1, run once on the merged list. Agents that read a unit's `pr.diff` slice tend to cite diff offsets; those fail the check and are re-located or dropped.
   - Merge duplicates across units by file:line or root cause (the same pattern repeated across files becomes ONE finding listing up to 5 locations, plus "N more").
   - Ownership, probability x impact filter, kind split, categories and statuses exactly as in Step 3. Suggestions stay capped at 3 across the whole PR.
7. **Post ONE review** (Step 4) with the template's `Review units` line. Never post per-unit reviews.

## Incomplete units

If a unit or the cross-unit pass fails, times out or is cut short, the review is incomplete: post `--comment` only, no result line, and list each unit as `not completed` in `Not verified`. Never approve or request changes with a missing unit. The deadline applies per wave (size target +50%).

## Lean tier

`split-pr.sh` writes each unit's plan with `triage.sh --unit`. A non-tiny unit with code gets:

- `fe-logic-reviewer`: its own agent and full budget, because logic bugs, races and leaks are where reviews find the most real defects;
- `fe-test-analyzer` when the unit contains specs: a measured run showed the combined reviewer missed a Medium test-quality issue (permission mocks that all return `false`) that the test specialist found;
- ONE `fe-combined-reviewer` for the other passes on the plan (Angular, A11y, Security, Quality, Styling, Apollo), told to read every changed file whole and to spend its budget on Quality and architecture (layering, model placement, naming, reuse). The plan's `Brief:` line says to give it `Skip: Logic, Test` (or just `Skip: Logic`) so the agents do not overlap;
- `fe-impact-analyzer` only when the unit routes to it (service, store, model, shared, routing, auth).

A spec-only unit keeps just `fe-test-analyzer`; a tiny unit keeps the tiny rule (one combined reviewer, plus impact when routed). `fe-simplifier` does not run per unit: it runs once for the whole PR (step 5 of the flow).

On a real 83-file PR (8 units) the previous plan listed 42 agents, which led one run to skip them all; the first lean tier listed 22 plus the cross-unit pass, and the current one (with the test specialist for units that have specs) lists about 30. Comparing the two on two units: the lean tier cost 43% fewer tokens and had no wrong citations, but found 3 issues against 13, which is why test and depth were added back.

## Cost note

Cost scales with units: about 3 to 4 agents per code unit. Keep agents' prompts to their own section; do not paste diffs into prompts.

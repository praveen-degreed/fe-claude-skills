# Chunked Review (huge PRs)

A PR is `huge` (>1500 added lines or >50 files) when it cannot be reviewed in one pass. Do not stop and do not ask the author to split. Break it into review units, run the full review steps on every unit, then consolidate, verify and post ONE review.

Only if `split-pr.sh` exits 3 (more than 12 code units, roughly >7000 added lines) stop and ask the author to split; say why.

## Flow

1. **Fetch once** (SKILL.md Step 0). Run `scripts/split-pr.sh <fetch dir>`. It writes `units/<name>/{files.txt,stats.txt,pr.diff,plan.txt}` and prints the index (unit, files, +/-, plan). Print the index at the top of the review.
2. **Understand once** (Step 1): one intent / acceptance criteria / prior-review summary for the whole PR, shared by every unit.
3. **Review each unit** with the normal steps. The unit's `plan.txt` is its triage plan (agents, passes, budget; a lone giant file is reviewed with the large budget). Brief per agent as in SKILL.md Step 2, with these changes:
   - `Fetch dir:` is the PR fetch dir (so `head/<path>` still resolves); add `Unit: <name>` and `Diff: <fetch dir>/units/<name>/pr.diff`. The agent reviews ONLY the files in `units/<name>/files.txt` and reads that diff slice, not the whole `pr.diff`.
   - Add one line of cross-unit context: the other units' file lists are in `units/index.txt`; the agent may Read/Grep files outside its unit to check callers/types but must not report findings on them.
   - Budgets and finding caps apply per agent per unit.
   - Run units in waves of at most 3 in parallel (all of a unit's agents in one message). Do not launch every unit at once.
   - `unit-misc` (docs/config/assets) gets a correctness skim by the orchestrator, no agents.
4. **Cross-unit pass** (after all units): ONE `fe-impact-analyzer` for the whole PR, large budget (~30 calls, max 10 findings), told to look only for what per-unit review cannot see: a changed export/model/signature in one unit consumed in another, inconsistent patterns across units, duplicated helpers added in different units, contract shape (`contract-check.md`) vs. callers. Give it `units/index.txt` and the finding summaries (title + file:line only). Skip it when no unit touches service/store/model/shared/routing/auth files.
5. **Consolidate and verify** (Step 3) on the merged list from all units and the cross-unit pass:
   - Drop findings without a `file:line` the agent opened; re-open every Critical/High line in `head/<path>` yourself.
   - Merge duplicates across units by file:line or root cause (the same pattern repeated across files becomes ONE finding listing up to 5 locations, plus "N more").
   - Ownership, probability x impact filter, kind split, categories and statuses exactly as in Step 3. Suggestions stay capped at 3 across the whole PR.
6. **Post ONE review** (Step 4) with the template's `Review units` line. Never post per-unit reviews.

## Incomplete units

If a unit or the cross-unit pass fails, times out or is cut short, the review is incomplete: post `--comment` only, no result line, and list each unit as `not completed` in `Not verified`. Never approve or request changes with a missing unit. The deadline applies per wave (size target +50%).

## Cost note

Cost scales with units. Typical is 4-6 units at ~5 agents each. Keep agents' prompts to their own section; do not paste diffs into prompts.

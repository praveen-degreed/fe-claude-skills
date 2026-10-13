# Routing and Budgets

`scripts/triage.sh` applies this table deterministically. Pass names are defined in `references/passes.md`.

## Routing

| Change type | Agents | Passes |
|---|---|---|
| template `.html` | code, architecture | Styling, Angular, A11y, Apollo |
| component/other `.ts` | code, logic, architecture (+ simplifier if not tiny and not lean, see Simplifier skip) | Angular, A11y, Security, Quality |
| service/store/rxjs/resource | code, logic, architecture, impact | Angular, A11y, Security, Quality |
| http/graphql/model | code, logic, architecture, impact | Angular, A11y, Security, Quality |
| any `.spec.ts` in diff | + test | Test |
| spec only | test | Test |
| routing/guard/resolver | code, architecture, impact | Angular, A11y, Security, Quality |
| shared lib / barrel / exported API | + logic, impact | Quality, Security |
| auth/permissions/rebac | + logic, impact | Security |
| styles only | code, architecture | Styling, Apollo |
| config/docs only | none | correctness skim |

Agents: code = fe-code-reviewer, logic = fe-logic-reviewer, test = fe-test-analyzer, simplifier = fe-simplifier, architecture = fe-architecture-reviewer, impact = fe-impact-analyzer.

## Baseline minimum

Any non-spec `.ts` or any `.html` change always gets Angular + A11y basics (code + architecture agents). Spec-only diffs are exempt: they get only test + Test.

The test agent runs only when a `.spec.ts` is in the diff. The "missing tests for new public methods" check belongs to the Quality pass.

Services, stores and models route to impact because a changed signature or model can break consumers.

## Fail open: run ALL agents in parallel, state the reason

- a file matches no known type; empty input; triage script error
- diff incomplete or truncated
- ambiguity about which type applies
- shared, auth, or permissions change whose blast radius is unclear

First line of the plan states the reason. Never silently narrow.

## Size classes

Sizing uses ADDED lines only (`--additions`; `--deletions` is passed for the simplifier rule).

| Class | Threshold | Budget per agent | Findings cap |
|---|---|---|---|
| tiny | <100 added, <=5 files | 2-3 min, ~10 tool calls | 6 |
| typical | <=600 added | 5-8 min, ~20 tool calls | 8 |
| large | <=1500 added or >20 files | 10-15 min, ~30 tool calls | 10 |
| huge | >1500 added or >50 files | ask the author to split; do not review | - |

## Tiny = combined-agent mode

A tiny PR runs one `fe-combined-reviewer` that covers every pass on the plan's Passes line (including Test when a `.spec.ts` is present), plus `fe-impact-analyzer` only when the change routes to it (service/store/model/shared/barrel/routing). The specialist agents are not spawned. Non-tiny PRs use the specialists per the routing table. Fail-open FULL still runs all specialists.

## Simplifier skip

`fe-simplifier` is skipped when the PR is deletion-heavy (added < 20% of added+deleted) or has fewer than 30 added lines.

## Fetch once

The orchestrator runs `scripts/fetch-pr.sh <PR> [--repo owner/name]` once and passes the printed dir path to every agent. The dir holds `pr.diff`, `files.txt`, `meta.json`, `checks.txt` (failing checks), `head/<path>` (full file at PR head) and `skipped.txt`. Agents read from it and do not call `gh`, except for files listed in `skipped.txt`.

## Cost rules

- Put in every agent prompt: "Tool-call budget: N successful calls (failed calls are not counted). When reached, stop and return partial findings. Max M findings, highest severity first."
- Pass each agent only the diff slice for its file types, not the whole diff.
- Use Grep with `files_with_matches` and a result cap (`head_limit`) before Read; read line ranges, not whole files.
- Agents run once; no re-spawning to "double check".

## Orchestrator deadline

- Default margin (tunable): at the size's time target plus 50%, stop stragglers with TaskStop.
- Post a partial review with the available findings, comment-only (`--comment`) with no approve/request-changes decision; list each timed-out area as "not completed" in the `Not verified` line.

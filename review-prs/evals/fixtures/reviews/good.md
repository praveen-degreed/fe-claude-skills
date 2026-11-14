## Review Summary

**Triage plan:** Size typical | Agents run: fe-logic-reviewer, fe-combined-reviewer | Passes: Angular, Quality
**CI:** green

### Scoreboard
| Category | Status | To address |
|---|---|---|
| Logic | 🔴 Fail | 1 High, 1 Medium |
| Architecture & Quality | 🟢 Pass | 0 |

### Things to address

#### Logic
- `apps/lxp/src/app/access/audience.service.ts:11` - **High** - Rule - `loadAll` stops at `MAX_PAGES` and returns a truncated list as if complete.
  Fix: return a `truncated` flag.
- `apps/lxp/src/app/access/audience.service.ts:20-22` - **Medium** - Rule - `forkJoin` sends every DELETE at once.
  Fix: cap concurrency.

### Suggestions (max 3)
- `apps/lxp/src/app/access/audience.component.ts:3` - consider a `switchMap` for `onSearch`.

**Not verified:** Jest, lint and tsc were not run.

**Review result:** Changes requested

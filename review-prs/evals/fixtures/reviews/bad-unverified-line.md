## Review Summary

**Triage plan:** Size typical | Agents run: fe-logic-reviewer | Passes: Angular
**CI:** green

### Scoreboard
| Category | Status | To address |
|---|---|---|
| Logic | 🟢 Pass | 1 Medium |

### Things to address

#### Logic
- `apps/lxp/src/app/access/audience.component.ts` (`onSearch`) - **Medium** - Rule - Each call subscribes with no `switchMap`. The agent cited diff offsets, so the exact line was not re-opened.
  Fix: use a `Subject` and `switchMap`.

**Not verified:** none

**Review result:** Approved

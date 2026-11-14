## Review Summary

**Triage plan:** Size tiny | Agents run: fe-combined-reviewer
**CI:** green

### Scoreboard
| Category | Status | To address |
|---|---|---|
| Logic | 🔴 Fail | 1 High |

### Things to address

#### Logic
- `apps/lxp/src/app/access/audience.service.ts:11` - **High** - Rule - `loadAll` returns a truncated list as complete.
  Fix: return a `truncated` flag.

**Not verified:** none

**Review result:** Approved

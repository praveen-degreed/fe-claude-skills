# Review Comment Template

Write the body to a temp file and post ONE review, by result (rules in `decision-rules.md` Decision):

```bash
gh pr review <PR_NUMBER> --repo <OWNER/REPO> --approve --body-file <file>
gh pr review <PR_NUMBER> --repo <OWNER/REPO> --request-changes --body-file <file>
gh pr review <PR_NUMBER> --repo <OWNER/REPO> --comment --body-file <file>
```

`--comment` only for an incomplete review (no result line).

## Finding format

Each finding:

```markdown
- `file:line` - **Critical|High|Medium|Low** - Rule|Suggestion - one-sentence issue.
  Fix: <one line>
  ```ts
  <sample code, no comments>
  ```
  Source: `in-repo/file.ts:line` (preferred), else official link ONLY if given in references. No source: omit the line. Never invent URLs.
```

## Template

```markdown
## Review Summary

**Triage plan:** Size <class> | Agents run: <list> | Not run: <list> | Passes: <list>
**CI:** green / red - [failing checks]
**Summary:** [optional, one line]

### Scoreboard
| Category | Status | To address |
|---|---|---|
| Architecture & Quality | 🟢 Pass | 2 |
| Logic | 🔴 Fail | 1 Critical/High, 1 Medium/Low |
| Accessibility | 🟢 Pass | 0 |

### Things to address
Critical/High first, then Medium/Low, grouped by category. Architecture & Quality keeps layer sub-groups (File/Module, Class/Component, Function, Naming, Statements). Omit empty groups.

#### Logic
*(Findings in the format above.)*

**Before merge:** [only if the PR body says it must be held/paired with another change]

### Suggestions (max 3)
- `file:line` - [suggestion]

<details>
<summary>Dropped/Downgraded Findings (N filtered)</summary>

| # | Finding | Severity | Outcome | Reasoning |
|---|---------|----------|---------|-----------|

</details>

**Not verified:** [unavailable checks, areas not completed, or "none"]

**Review result:** Approved | Changes requested

---
🤖 AI-assisted review (review-prs skill). Findings were checked against the PR head.
```

# Review Comment Template

Post to GitHub using HEREDOC:

```bash
gh pr review <PR_NUMBER> --repo <OWNER/REPO> --approve --body "$(cat <<'EOF'
<REVIEW_BODY>
EOF
)"
# OR
gh pr review <PR_NUMBER> --repo <OWNER/REPO> --request-changes --body "$(cat <<'EOF'
<REVIEW_BODY>
EOF
)"
```

---

## Template

```markdown
## Review Summary

**Verdict: APPROVE** or **Verdict: REQUEST CHANGES** or **Review Incomplete - Manual Decision Required**
**Review mode:** Standard (5 agents) | Deep (2 reviewers x 5 agents)
**Review confidence:** HIGH / MEDIUM / LOW
**Context level:** Full Local Access / Diff-Only
**Tool failures:** None / [list]
**Review round:** [N] (previous: [list])

### Prior Review Issues - Resolution Status
| # | Issue | Reviewer | Status |
|---|-------|----------|--------|
| 1 | [description] | @reviewer | FIXED / STILL OPEN |

*(Omit if no prior reviews)*

### Actionable Findings

#### Angular Patterns ([PASS/CONCERN/FAIL])
- `file:line` - [issue] - [correct pattern]

#### TypeScript Quality ([PASS/CONCERN/FAIL])
- `file:line` - [issue]

#### Security ([PASS/CONCERN/FAIL])
- `file:line` - [vulnerability] - [remediation]

#### i18n / Localization ([PASS/CONCERN/FAIL])
- `file:line` - [issue]

#### Logic & Edge Cases ([PASS/CONCERN/FAIL])
- `file:line` - [issue]

#### Memory & Performance ([PASS/CONCERN/FAIL/N/A])
- `file:line` - [issue]

#### SOLID & Code Organization ([PASS/CONCERN/FAIL])
- `file:line` - [issue]

#### Architecture & Patterns ([PASS/CONCERN/FAIL])
- `file:line` - [violation] - [pattern to follow]

#### Accessibility - WCAG 2.2 AA ([PASS/CONCERN/FAIL])
- `file:line` - [issue] - [WCAG criterion] - [fix]

*Categories: Focus management, keyboard access, semantic HTML, ARIA, contrast*

#### Learning Platform A11y ([PASS/CONCERN/FAIL/N/A])
- `file:line` - [issue] - [WCAG criterion] - [fix]

*Categories: Video captions (1.2.2), media controls (2.2.2), skip links (2.4.1), timing (2.2.1), progress announcements, drag alternatives (2.5.7), touch targets (2.5.8)*

#### Nx Monorepo ([PASS/CONCERN/FAIL/N/A])
- `file:line` - [issue]

#### Code Reuse & Duplication ([PASS/CONCERN/FAIL])
- `file:line` - [existing component to use]

#### Regression & Impact ([PASS/CONCERN/FAIL])
- `file:line` - [breaking change] - [N consumers affected] - [files impacted]

*Categories: Breaking Input/Output changes, removed exports, shared library impacts, incorrect API usage*

#### Apollo & Design System ([PASS/CONCERN/FAIL/N/A])
- `file:line` - [issue] - [correct pattern]

#### Test Quality ([PASS/CONCERN/FAIL/N/A])
- [Assessment]
- [Missing tests]

#### Simplification Opportunities
- `file:line` - [suggestion]

*(Deep mode only:)*
#### Consensus Findings
- `file:line` - [issue]

### PR Health
| Aspect | Status |
|--------|--------|
| Scope | Focused / Too Broad |
| Size | Good / Large - [reason] |
| Breaking Changes | None / Yes - [details] |
| Deep Mode Recommended | Yes - [reason] / No |

### Action Required (if request changes)
- [Specific changes needed]

<details>
<summary>Dropped/Downgraded Findings (N filtered)</summary>

| # | Finding | Severity | Verdict | Reasoning |
|---|---------|----------|---------|-----------|
| 1 | [desc] | Critical | Dropped | [why] |

</details>

---
*Reviewed by Claude Code - /review-prs (Frontend)*
```

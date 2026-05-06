# Deep Mode (--deep flag)

Deep mode runs 2 independent reviewers, each with 5 agents, then applies consensus logic.

## When to Use

- Authentication/authorization changes
- State management modifications
- >600 non-test LOC added
- Multiple feature modules touched
- Shared component/service changes

## Workflow

### Step 1: Create Team

```
TeamCreate with team_name: "pr-review-<PR_NUMBER>"
```

### Step 2: Spawn 2 Reviewers (Parallel)

Launch both in a single message:

**Reviewer-A prompt:**
```
You are Reviewer-A performing an independent comprehensive frontend review of PR #<PR_NUMBER>.

Working directory: <WORKTREE_PATH>
You have local codebase access. Use Glob, Grep, and Read to explore context.

PR diff:
<DIFF>

Review history:
<REVIEW_CONTEXT_SUMMARY>

INSTRUCTIONS:
1. Launch 5 Task agents IN PARALLEL (single message, multiple tool calls):
   - fe-code-reviewer - Angular patterns, TypeScript quality, security
   - fe-logic-reviewer - logic, edge cases, Observable handling, signals
   - fe-test-analyzer - test quality, Jest/Spectator patterns
   - fe-simplifier - simplification opportunities
   - fe-architecture-reviewer - architecture, accessibility, Apollo design system
2. Collect all findings from the 5 agents
3. Send ALL findings back to the team lead via SendMessage. Format as:
   - Category (implementation / logic / tests / accessibility / architecture / simplification)
   - Severity (critical / high / medium / low)
   - file:line reference
   - Description
4. Do NOT filter or drop findings - send everything.
```

**Reviewer-B prompt:** Same but "You are Reviewer-B".

### Step 3: Wait for Findings

Wait for both reviewers to send their findings via SendMessage.

### Step 4: Consensus Logic

Before applying the practical filter:

1. **Found by BOTH reviewers:** High confidence - **Keep** (skip probability check)
   - If two independent reviewers found the same issue, it's real
2. **Found by ONE reviewer only:** Moderate confidence - apply standard probability x impact filter

### Step 5: Cleanup

After posting review:
```
SendMessage to reviewers with type: "shutdown_request"
TeamDelete with team_name: "pr-review-<PR_NUMBER>"
```

## Output Additions

In the review comment, add:

```markdown
#### Consensus Findings (flagged by both reviewers independently)
- `file:line` - [issue]
```

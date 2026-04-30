# Decision Rules

## Practical Validation Filter

Filter theoretical/hyperbolic findings before making a decision.

### Step 1: Evaluate Probability

Infer from actual code, not theory:

| Level | Description |
|-------|-------------|
| **High** | Reachable in common user flows |
| **Medium** | Reachable via uncommon but realistic actions |
| **Low** | Requires unusual state combination |
| **Extremely Rare** | Requires contrived/artificial conditions |

### Step 2: Evaluate Impact

| Level | Description |
|-------|-------------|
| **Critical** | Security breach, data loss, app crash, accessibility barrier |
| **Moderate** | Incorrect UI, degraded UX, partial failure |
| **Minor** | Cosmetic issue, localized bug |
| **Cosmetic** | Style preference, no functional impact |

### Step 3: Decision Matrix

| Probability | Critical | Moderate | Minor | Cosmetic |
|-------------|----------|----------|-------|----------|
| **High** | Keep | Keep | Keep | Drop |
| **Medium** | Keep | Keep | Downgrade | Drop |
| **Low** | Keep | Downgrade | Drop | Drop |
| **Extremely Rare** | Downgrade | Drop | Drop | Drop |

**Rules:**
- **Keep** if: Probability >= Medium AND Impact >= Moderate, OR Impact = Critical AND Probability >= Low
- **Downgrade** if: flagged Critical/High but probability is Low
- **Drop** if: Probability = Extremely Rare, OR Impact = Cosmetic

---

## APPROVE Criteria

All must be true:
- No actionable findings with severity High or Critical after filtering
- Implementation follows Angular 20+ patterns
- Tests present AND meaningful (or N/A for config/docs)
- No accessibility violations
- No security vulnerabilities (XSS, exposed secrets)

---

## REQUEST CHANGES Criteria

Any of the following triggers REQUEST CHANGES:

### Bugs & Logic
- Actionable bugs or logic errors (post-filter)
- Missing error handling for likely failure modes

### Memory Leaks
- Unhandled subscriptions (missing takeUntilDestroyed/unsubscribe)
- Event listeners without cleanup
- Timers without cleanup
- DOM references held in closures

### SOLID Violations
- Components/services >300 lines with multiple responsibilities
- Methods >50 lines that should be broken down
- God services mixing HTTP + state + UI

### Tests
- Missing tests for non-trivial changes
- Low-value tests (just "should create")

### Security
- XSS vulnerabilities
- Exposed tokens/PII

### Angular Anti-Patterns
- @Input/@Output instead of input()/output()
- Missing OnPush change detection
- Constructor injection instead of inject()
- @HostBinding/@HostListener instead of host object
- standalone: true (unnecessary in Angular 20+)
- ngClass/ngStyle instead of class/style bindings
- *ngIf/*ngFor instead of @if/@for
- Globals/arrow functions/regex in templates

### Architecture
- Service layer boundary violations
- DRY violations
- Circular dependencies

### Accessibility (WCAG 2.2 AA)
- eslint-disable comments silencing a11y rules
- div/span with (click) instead of button/a
- Skipped heading levels
- Missing focus trap/restoration
- Interactive elements not keyboard accessible
- Missing da-icon ariaLabel
- aria-live inside @if
- Placeholder-as-label
- Using native disabled instead of aria-disabled
- Hardcoded colors (may fail contrast)

### Nx Monorepo
- Relative imports across library boundaries
- Missing @degreed/* prefix
- Missing barrel exports

### Code Reuse
- Creating component when similar exists
- Duplicate methods across services
- Not using Apollo/shared components

### Regression / Impact
- Breaking changes to shared components without migration
- Changed Input/Output signatures that break consumers
- Removed exports still imported elsewhere
- Shared library changes that affect multiple apps
- Library/component API used incorrectly (missing subscriptions, wrong types)

### Apollo/Design System
- Hardcoded colors instead of tokens
- Custom button styles instead of tw-btn-*
- Custom CSS instead of Tailwind

### i18n
- Hardcoded user-facing strings without translation
- Not using DgxTranslatePipe

---

## Special Cases

### Styling-only PRs
- Focus: Tailwind, design tokens, responsive
- Tests: Usually N/A

### Config-only PRs
- Focus: Correctness
- Tests: Usually N/A

### Documentation PRs
- Focus: Accuracy
- Tests: N/A

### Test-only PRs
- Apply stricter test quality standards

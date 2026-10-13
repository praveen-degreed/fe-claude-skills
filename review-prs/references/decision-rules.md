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

## Decision

Applied after the filter, per included category (categories: Architecture & Quality, Logic, Angular, Tests, Accessibility, Apollo & Styling, Security & Performance, Contract).

- Category is `🔴 Fail` only if it has at least one Critical or High finding. Otherwise `🟢 Pass` (including no findings).
- Medium and Low never fail a category; they go in "Things to address". Suggestions never affect the result.
- Result: no category failed -> `**Review result:** Approved` (`gh pr review --approve`). At least one failed -> `**Review result:** Changes requested` (`--request-changes`).
- Incomplete review (gh failure, incomplete diff, agent error/timeout, area "not completed"): `--comment` only, no result line, add `Not verified`.
- PR body says it must be held/paired with another change: add a short "Before merge" note under Things to address; the rule above is unchanged.

## Severity triggers

These classify findings (labels: Critical|High|Medium|Low). Every surviving finding is posted with its label.

### Critical
- Security vulnerabilities (XSS, exposed secrets)
- Data loss or broken core flow

### High
- Actionable bugs or logic errors (post-filter)
- Accessibility violations (WCAG 2.2 AA)
- Missing or meaningless tests for new logic (N/A for config/docs)
- Memory leaks, RxJS misuse (below)

### Medium / Low
- Medium: deviations from Angular 22 patterns with real impact
- Low: nits, e.g. redundant `OnPush` or `standalone: true` (defaults in Angular 22)

### Bugs & Logic (High)
- Actionable bugs or logic errors (post-filter)
- Missing error handling for likely failure modes

### Memory Leaks
- Unhandled subscriptions (missing takeUntilDestroyed/unsubscribe)
- takeUntilDestroyed() called outside injection context without DestroyRef
- FormGroup valueChanges/statusChanges without cleanup
- Event listeners without cleanup
- Timers without cleanup
- DOM references held in closures

### RxJS Operator Misuse
- switchMap on form submit (loses requests) → use exhaustMap
- mergeMap on search typeahead (race conditions) → use switchMap
- concatMap on typeahead (queues all, slow) → use switchMap
- Nested subscribes (callback hell) → use higher-order operators
- Missing debounceTime on search input
- Missing distinctUntilChanged on form valueChanges
- catchError outside switchMap (kills stream) → move inside
- subscribe() just to set property or signal → use async pipe or toSignal()
- BehaviorSubject for simple local state → use signal() (signals first)
- effect() that writes to a signal → use computed()/linkedSignal()
- toPromise()/firstValueFrom() when observable works

### Forms (Signal Forms are the standard)
- New reactive or template-driven forms (use Signal Forms, @angular/forms/signals); existing reactive forms are not a violation unless newly written
- Apollo controls not bound with [formField]
- ControlValueAccessor or ngDefaultControl added to an Apollo control (silently disables form binding)
- required() on an array-valued field without minLength(path, 1)
- Missing error display for invalid fields
- Existing reactive form: valueChanges subscription without takeUntilDestroyed

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
- Explicit changeDetection: OnPush (Low nit; default in v22, only Eager to opt out, with a reason)
- Constructor injection instead of inject()
- @HostBinding/@HostListener instead of host object
- standalone: true (Low nit; the default, never set it)
- @ViewChild/@ViewChildren/@ContentChild(ren) instead of signal queries
- New singleton using @Injectable({ providedIn: 'root' }) instead of @Service
- HttpClient instead of NgxHttpClient in LXP code
- mutate() on signals instead of update()/set()
- ngOnInit() {} or other empty lifecycle hooks
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
- Skipped heading levels within routed content (the LXP shell renders the page h1, so routed content starting at h2, including da-page-header, is correct)
- Missing focus trap/restoration
- Interactive elements not keyboard accessible
- Missing da-icon ariaLabel
- aria-live inside @if
- Placeholder-as-label
- Using native disabled instead of aria-disabled
- Hardcoded colors (may fail contrast)

### Learning Platform A11y (LXP-specific)
- Video without captions or transcript
- Auto-playing media without pause/stop
- Missing skip-to-content link
- Quiz/assessment timeout not adjustable
- Progress indicators not announced to screen readers
- Form errors without correction suggestions
- Drag-and-drop without keyboard alternative
- Touch targets smaller than 24x24px

### Nx Monorepo
- Relative imports across library boundaries
- Missing @degreed/* prefix
- Missing barrel exports

### Code Reuse & Duplication
- Creating component when similar exists
- Duplicate methods across services
- Not using Apollo/shared components
- Copy-pasted code blocks (DRY violation)
- Reinventing existing utilities (stopEvent, isNullOrEmpty, formatDate, etc.)
- Custom debounce/throttle instead of rxjs operators
- Custom deep clone instead of structuredClone/getDeepCopy

### Dead Code & Unused Variables
- Unused variables in computed()/functions
- Unreachable code after return/throw
- Empty catch/if/else blocks
- Commented-out code blocks (should be removed)
- TODO/FIXME without ticket reference
- Unused imports

### Common Developer Mistakes
- Custom stopEvent() instead of e.preventDefault()
- filter()[0] instead of find()
- filter().length instead of some()/every()
- indexOf() !== -1 instead of includes()
- || for defaults instead of ?? (nullish coalescing)
- && chains instead of optional chaining ?.
- document.querySelector instead of viewChild()
- innerHTML instead of Angular binding
- Observable<any> or Promise<any> return types

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

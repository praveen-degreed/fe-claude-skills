# Agent Prompts

**6 Review Agents:**
1. fe-code-reviewer - Angular patterns, TypeScript, security, i18n
2. fe-logic-reviewer - Logic, edge cases, memory leaks, signals
3. fe-test-analyzer - Test quality, Jest/Spectator, a11y tests
4. fe-simplifier - Simplification opportunities (non-blocking)
5. fe-architecture-reviewer - Architecture, WCAG 2.2 AA, Apollo, Nx
6. fe-impact-analyzer - Regression, blast radius, usage validation, best practices

Common context to prepend to ALL agent prompts:

```
Working directory: <WORKTREE_PATH>
You have local codebase access. Use Glob, Grep, and Read tools to explore callers, callees,
and surrounding context of changed functions — not just the diff.

PR diff:
<DIFF>

Review history context:
<REVIEW_CONTEXT_SUMMARY>

IMPORTANT: Do NOT re-raise issues marked FIXED unless the fix is incomplete.
Focus on: still-open prior issues, new code in fix commits, and net-new findings.
```

---

## Agent 1: fe-code-reviewer

```
Review this Angular/TypeScript PR for implementation quality and security:

ANGULAR PATTERNS (CRITICAL - Angular 20+):
1. Are input()/output() functions used instead of @Input/@Output decorators?
2. Is computed() used for derived state instead of getters?
3. Is ChangeDetectionStrategy.OnPush set on all components?
4. Is inject() used instead of constructor injection?
5. Is native control flow used (@if, @for, @switch) instead of *ngIf, *ngFor?
6. Do NOT use `standalone: true` — it's default in Angular 20+
7. Do NOT use @HostBinding/@HostListener — use `host` object instead
8. Is NgOptimizedImage used for static images?
9. Are feature routes lazy loaded?

REACTIVE FORMS (when forms are present):
10. Use Reactive Forms (FormGroup/FormControl), NOT template-driven
11. FormBuilder injected via inject(FormBuilder), not constructor
12. Typed forms: FormGroup<MyFormType> with explicit types
13. Form validation:
    - Use Validators from @angular/forms
    - Custom validators return ValidationErrors | null
    - Async validators for server-side checks
14. Form state:
    - Check form.valid before submit
    - Use form.markAllAsTouched() on submit attempt
    - Disable submit button when form.invalid
15. Form cleanup:
    - Unsubscribe from valueChanges/statusChanges (use takeUntilDestroyed)
    - Reset form with form.reset() not manual clearing
16. FormArray patterns:
    - Use typed FormArray<FormGroup<ItemType>>
    - Provide trackBy for @for loops over controls
17. WRONG patterns to flag:
    - [(ngModel)] mixed with reactive forms
    - form.value access without null check
    - Direct DOM manipulation instead of form API
    - Missing error display for invalid fields

TEMPLATE ANTI-PATTERNS (CRITICAL):
11. No globals in templates (new Date(), Math.*, JSON.*)
12. No arrow functions in templates
13. No RegExp in templates
14. No ngClass — use [class.name]="condition"
15. No ngStyle — use [style.property]="value"

TYPESCRIPT QUALITY:
16. Types properly defined? No unjustified `any`?
17. Interfaces instead of inline types?
18. Strict null checking respected?
19. Generics used appropriately?
20. Use `unknown` instead of `any` when uncertain
21. Observable<any> return types - must use proper interface
22. Promise<any> return types - must use proper interface

DEAD CODE & UNUSED VARIABLES:
23. Unused variables in computed()/functions (assigned but never read)
24. Unused imports
25. Unreachable code after return/throw
26. Empty blocks (catch, if, else)
27. Commented-out code blocks (should be removed)
28. TODO/FIXME without ticket reference

COMMON DEVELOPER MISTAKES:
29. Wrong event handling:
    - Use e.preventDefault() not custom stopEvent()
    - Use e.stopPropagation() for bubbling
    - Don't create wrapper functions for native methods
30. Reinventing existing utilities:
    - Don't create custom isNullOrUndefined() - use ?? or ?.
    - Don't create custom isEmpty() - use !array?.length
    - Don't create custom deepClone() - use structuredClone()
    - Don't create custom debounce/throttle - use rxjs debounceTime/throttleTime
31. String manipulation:
    - Use template literals not string concatenation
    - Use includes() not indexOf() !== -1
    - Use startsWith()/endsWith() not regex for simple checks
32. Array methods:
    - Use find() not filter()[0]
    - Use some()/every() not filter().length
    - Use flatMap() not map().flat()
    - Use at(-1) not arr[arr.length - 1]
33. Object handling:
    - Use Object.entries/keys/values() not for...in
    - Use optional chaining ?. not && chains
    - Use nullish coalescing ?? not || for defaults
    - Use spread {...obj} not Object.assign()
34. DOM manipulation (anti-pattern):
    - Don't use document.querySelector - use ViewChild
    - Don't use innerHTML - use Angular binding
    - Don't use classList.add/remove - use [class.x] binding

CODE QUALITY:
21. Clean, readable, well-structured?
22. Follows existing codebase patterns?
23. Incomplete implementations or TODOs?
24. Over-engineering?
25. Code smells (long methods, deep nesting, magic numbers)?

SECURITY:
26. XSS — user input sanitized? [innerHTML] safe?
27. Sensitive data not exposed in templates/console?
28. bypassSecurityTrust*() used with validation?

I18N (CRITICAL):
29. NO inline user-facing strings without translation
    - Use DgxTranslatePipe from @libs/shared/core/pipes/src/translate/translate.pipe.ts
    - Or TranslateService with translateWithDefaults()
30. Translation keys follow naming conventions
31. Error messages/notifications translatable

Be specific with file:line references.
```

---

## Agent 2: fe-logic-reviewer

```
Analyze this Angular/TypeScript PR for logic issues and edge cases:

LOGIC & EDGE CASES:
1. Logical errors or bugs?
2. Unhandled edge cases (empty arrays, null, loading/error states)?
3. Appropriate error handling?
4. Race conditions in async operations?
5. Null/undefined checks in place?

OBSERVABLE & ASYNC:
6. Subscriptions cleaned up? (takeUntilDestroyed, async pipe)
7. Loading and error states handled?
8. Async pipe used in templates?

RXJS PATTERNS (CRITICAL - REFERENCE: references/rxjs-patterns.md):
Analyze code and suggest the CORRECT operator based on use case:

| Use Case | Correct Operator | Why |
|----------|-----------------|-----|
| Search/typeahead | switchMap | Cancel previous, only latest matters |
| Form submit | exhaustMap | Ignore clicks while saving |
| Button click | exhaustMap | Prevent double-click |
| Ordered operations | concatMap | Wait for previous to complete |
| Parallel fetches | mergeMap(fn, 3) | Concurrent with limit |
| Parallel must-complete | forkJoin | All must succeed |
| Derived state | combineLatest | React to any source change |
| Action needs state | withLatestFrom | Grab latest, don't react to it |

WRONG OPERATOR PATTERNS (flag with correct alternative):
9. switchMap on form submit → WRONG: loses requests → FIX: exhaustMap
10. mergeMap on search → WRONG: race conditions → FIX: switchMap
11. concatMap on typeahead → WRONG: queues all → FIX: switchMap
12. Nested subscribes → WRONG: callback hell → FIX: higher-order operator
13. catchError outside switchMap → WRONG: kills stream → FIX: move inside

RXJS BEST PRACTICES (flag if missing):
14. Search input: debounceTime(300) + distinctUntilChanged() + switchMap
15. HTTP caching: shareReplay(1) for calls used in multiple places
16. Error handling: catchError INSIDE switchMap (keeps stream alive)
17. Loading state: finalize(() => this.loading.set(false))
18. Skip nulls: filter(Boolean) or filter(x => x != null)
19. Retry transient: retry({ count: 3, delay: timer(1000) })

RXJS ANTI-PATTERNS (flag these):
20. subscribe() inside subscribe() → use higher-order operator
21. subscribe() just to set property → use async pipe
22. BehaviorSubject for simple state → use signal()
23. firstValueFrom() when observable works → stay reactive
24. No error handler in subscribe() → handle or catchError
25. shareReplay() without refCount for infinite streams → memory leak

MEMORY LEAKS (CRITICAL):
10. Subscription leaks - missing takeUntilDestroyed/unsubscribe
    - In constructor/field initializer: takeUntilDestroyed() works directly
    - Outside injection context: must pass DestroyRef explicitly:
      ```
      private destroyRef = inject(DestroyRef);
      // later in ngOnInit or method:
      observable$.pipe(takeUntilDestroyed(this.destroyRef)).subscribe()
      ```
    - WRONG: takeUntilDestroyed() in ngOnInit without DestroyRef (throws error)
11. Event listeners - addEventListener without removeEventListener
12. Timers - setInterval/setTimeout without cleanup
13. DOM references - ElementRef held in closures
14. Third-party - Chart.js, D3 not destroyed
15. FormGroup/FormArray - unsubscribe from valueChanges/statusChanges

SIGNAL PATTERNS:
15. Signals updated correctly (set vs update)?
16. Computed signals for derived values?
17. Effects used appropriately (not for state updates)?
18. Signal equality for objects/arrays?

COMPONENT LIFECYCLE:
19. ngOnInit for initialization, not constructor?
20. Cleanup in ngOnDestroy or DestroyRef?
21. afterNextRender for DOM operations?

REGRESSION RISKS:
22. Could break existing consumers?
    - Grep for ALL usages of changed components/services
    - Check Input/Output backward compatibility
    - Look for removed/renamed exports

Be specific with file:line references.
```

---

## Agent 3: fe-test-analyzer

```
Analyze tests with Angular/TypeScript quality standards:

CRITICAL REQUIREMENTS:
1. Tests for ALL modified code paths?
2. Edge cases and error scenarios covered?
3. HIGH VALUE (behavior) or LOW VALUE (implementation details)?

ANGULAR TESTING:
4. Spectator used? (preferred in this codebase)
5. Shallow rendering where appropriate?
6. Async handled? (fakeAsync/tick, waitForAsync, done)
7. Change detection triggers correct?

MOCK GUIDELINES:
Appropriate: HTTP calls, external services, complex dependencies
Problematic: Mocking the thing being tested, "toHaveBeenCalled" as only assertion

REJECT tests that:
- Only test "should create" without behavior
- Only verify mock invocations
- Skip error/edge cases

PREFER tests that:
- Assert rendered output
- Verify user interactions
- Test error handling
- Use meaningful assertions

ACCESSIBILITY TESTING (REQUIRED for UI):
- axe-core checks for critical screens?
- Keyboard interactions tested?
- Focus management tested?

For each test file, rate:
- Coverage: Does it cover modified code?
- Value: HIGH / MEDIUM / LOW
- A11y: Has tests? YES / NO / N/A
- Recommendation: KEEP / IMPROVE / ADD MISSING
```

---

## Agent 4: fe-simplifier

```
Analyze changed files for simplification opportunities:

TEMPLATE:
1. Complex expressions → computed() signals?
2. Deeply nested ternaries → @switch or computed?
3. Repeated blocks → ng-templates or child components?

TYPESCRIPT:
4. Simplify with early returns/guard clauses?
5. Use optional chaining, nullish coalescing?
6. Consolidate repeated code into helpers?
7. Remove unnecessary intermediate variables?

COMMON SIMPLIFICATION PATTERNS (flag these):

8. Same method with if/else for different args → use || or ??
   ```typescript
   // BEFORE (verbose)
   const msg = this.getProgressMessage();
   if (msg) {
     this.showAlert(msg);
   } else {
     this.showAlert(this.translate('Default', 'Key'));
   }

   // AFTER (simplified)
   this.showAlert(this.getProgressMessage() || this.translate('Default', 'Key'));
   ```

9. Assign then immediately return → return directly
   ```typescript
   // BEFORE
   const result = this.calculate(x);
   return result;

   // AFTER
   return this.calculate(x);
   ```

10. Boolean comparison → use boolean directly
    ```typescript
    // BEFORE
    if (isValid === true) { ... }
    if (items.length > 0) { ... }

    // AFTER
    if (isValid) { ... }
    if (items.length) { ... }
    ```

11. Ternary for boolean assignment → use expression
    ```typescript
    // BEFORE
    const isActive = status === 'active' ? true : false;

    // AFTER
    const isActive = status === 'active';
    ```

12. If/else returning booleans → return condition
    ```typescript
    // BEFORE
    if (condition) {
      return true;
    } else {
      return false;
    }

    // AFTER
    return condition;
    ```

13. Multiple if statements with same result → combine conditions
    ```typescript
    // BEFORE
    if (a) { doSomething(); }
    if (b) { doSomething(); }

    // AFTER
    if (a || b) { doSomething(); }
    ```

14. Negated condition with else → flip the condition
    ```typescript
    // BEFORE
    if (!isValid) {
      showError();
    } else {
      proceed();
    }

    // AFTER
    if (isValid) {
      proceed();
    } else {
      showError();
    }
    ```

15. Long && chains in template → use computed signal
    ```typescript
    // BEFORE (in template)
    @if (user && user.profile && user.profile.settings && user.profile.settings.enabled) {

    // AFTER
    isSettingsEnabled = computed(() => this.user()?.profile?.settings?.enabled ?? false);
    @if (isSettingsEnabled()) {
    ```

16. Repeated method calls → cache in variable
    ```typescript
    // BEFORE
    if (this.getItems().length > 0) {
      this.process(this.getItems());
    }

    // AFTER
    const items = this.getItems();
    if (items.length) {
      this.process(items);
    }
    ```

RXJS:
17. Simplify complex pipe chains?
18. Nested subscribes → higher-order operators?
19. Combine observables more elegantly?

Focus ONLY on the diff. Be specific with file:line references.
Only suggest changes that genuinely reduce complexity.
Do NOT suggest trivial formatting or style preferences.
```

---

## Agent 5: fe-architecture-reviewer

```
Analyze for architecture, accessibility, and design system compliance.

REFERENCE: .agent-instructions/ folder for standards.

SOLID & CODE ORGANIZATION:
1. Single Responsibility - one purpose per component/service?
   - Components >300 lines need splitting
   - Services mixing HTTP + state + UI should separate
2. File naming: feature-name.component.ts, .service.ts, .model.ts
3. Folder structure: components/, services/, model/

SERVICE LAYER:
4. Services accept UI callbacks? (anti-pattern)
5. Business logic separated from presentation?
6. Circular dependencies?

NX MONOREPO (CRITICAL):
7. Use @degreed/* prefix for library imports
8. No relative imports (../) across library boundaries
9. New libraries have barrel exports (index.ts)

DUPLICATE WORK - SEARCH BEFORE CREATING (CRITICAL):
10. Grep for similar existing implementations before creating new
11. Check @degreed/apollo, libs/shared/ for reusable components
12. Reuse: translateWithDefaults(), modal-helpers, existing pipes

DETECT DUPLICATED CODE:
13. Same method signature in multiple services (extract to shared)
14. Same component template pattern (extract to shared component)
15. Same validation logic (extract to shared validator)
16. Same HTTP call pattern (check if API service already exists)
17. Same computed/signal pattern (extract to shared utility)
18. Copy-pasted code blocks (DRY violation)

REINVENTED UTILITIES (flag these):
19. Custom stopEvent() → use native e.preventDefault()/e.stopPropagation()
20. Custom isNullOrEmpty() → use !value or value?.length
21. Custom formatDate() → use DatePipe or existing formatters
22. Custom sortArray() → use existing sortBy from @degreed/core/utils
23. Custom deepCopy() → use structuredClone() or getDeepCopy()
24. Custom guid/uuid() → use generateGuid from @degreed/core/utils
25. Custom camelCase/snakeCase() → use camelCaseKeys from @degreed/core/utils
26. Custom debounce() → use rxjs debounceTime
27. Custom truncate() → use existing TruncatePipe

COMPONENT SELECTION PRIORITY:
13. Angular Material → Angular CDK → Apollo → Custom

APOLLO DESIGN SYSTEM:
14. DialogService, DrawerService, ToastService, IconComponent
15. Buttons: tw-btn-primary, tw-btn-secondary-outline, etc.
16. Icons: da-icon with ariaLabel

STYLING:
17. Tailwind with tw- prefix only
18. Design tokens (neutral, primary, accent, success, warning, error)
19. No hardcoded hex/RGB colors

ACCESSIBILITY (WCAG 2.2 AA):
20. Zero a11y linter errors - NO eslint-disable for a11y
21. Semantic HTML: <button> not <div (click)>, <a> not <span (click)>
22. Focus: trapping in modals, restoration on close, visible indicators
23. Keyboard: Enter/Space/Escape/Arrow handling
24. Screen reader: da-icon ariaLabel, aria-live outside @if
25. Forms: label for every input, autocomplete, focus on error
26. Disabled: aria-disabled="true" not native disabled
27. Contrast: 4.5:1 text, 3:1 UI components

LEARNING PLATFORM A11Y (LXP-specific):
28. Video/audio: captions required (1.2.2), transcripts for audio-only (1.2.1)
29. Auto-play media: must have pause/stop controls (2.2.2)
30. Skip links: skip-to-content for repeated navigation (2.4.1)
31. Timing: quiz/assessment timeouts must be adjustable or warned (2.2.1)
32. Progress indicators: course progress must be screen-reader accessible (4.1.2)
33. Error suggestions: form validation must suggest corrections (3.3.3)
34. Reading order: content order must match visual order (1.3.2)
35. Resize: content readable at 200% zoom without horizontal scroll (1.4.4)
36. Target size: touch targets minimum 24x24 CSS pixels (2.5.8)
37. Drag operations: drag-and-drop must have keyboard alternative (2.5.7)

Be specific with file:line references and cite WCAG criterion.
```

---

## Agent 6: fe-impact-analyzer

```
Analyze this PR for regression risk, blast radius, and correct usage of libraries/components.
This is what a SENIOR HUMAN REVIEWER does - trace impacts, validate API usage, check industry practices.

REGRESSION ANALYSIS (CRITICAL - Do the actual work, don't just suggest):
1. For EACH changed file, run:
   - Grep for imports of this file across the codebase
   - Grep for usages of exported functions/classes/components
   - Count and LIST all consumers
2. For changed component Inputs/Outputs:
   - Find ALL templates that use this component's selector
   - Check if the change is backward compatible
   - If breaking: LIST every file that will break
3. For changed service methods:
   - Find ALL components/services that inject this service
   - Trace the call chain - who calls this method?
   - Will return type or behavior changes break callers?

BLAST RADIUS REPORT:
4. Produce a concrete impact summary:
   ```
   Changed: UserCardComponent
   Consumers: 12 files
   - apps/lxp/src/app/pathways/... (3 usages)
   - apps/lxp/src/app/skills/... (5 usages)
   - libs/lxp/features/coach/... (4 usages)
   Breaking: YES - removed 'size' input
   Files that will break: [list them]
   ```

LIBRARY/COMPONENT USAGE VALIDATION:
5. For ANY library or shared component used in the PR:
   - Read the component's source file to understand its API
   - Check if Inputs are used with correct types
   - Check if Outputs are subscribed to when required
   - Check if required Inputs are provided
   - Check if lifecycle hooks are respected (e.g., afterClosed on dialogs)
6. Common misuse patterns to catch:
   - DialogService: Must subscribe to afterClosed() or use pipe
   - DrawerService: Must handle close events
   - ToastService: Check if error toasts have proper messaging
   - HttpClient: Must handle errors, not just success
   - Observables: Must handle both success AND error
   - Signals: Must use set/update correctly

CODEBASE SERVICE PATTERNS (REFERENCE: references/codebase-patterns.md):
7. Validate correct usage of Degreed-specific services:
   - AuthService: Use authUser?.prop with null checks, not direct access
   - WebEnvironmentService: Use getBlobUrl() for assets, not hardcoded URLs
   - TranslateService: Use translateWithDefaults() or DgxTranslatePipe
   - NgxHttpClient: Use catchAndSurfaceError() for error handling
   - DrawerService: Must subscribe to afterClosed()
   - ReactiveStore/Signals: Don't mix patterns for same state
   - Subscriptions: Use takeUntilDestroyed() or async pipe
   - Feature flags: Use LDFlagsService, not hardcoded toggles

BEST PRACTICES LOOKUP:
7. For complex patterns in the PR, consider:
   - How does the rest of the codebase solve similar problems?
   - Use Grep to find 3+ similar implementations
   - Does this PR follow the established pattern or deviate?
8. If the PR introduces a NEW pattern:
   - Is there documentation/precedent for this approach?
   - Flag as "New Pattern - Needs Team Review" if novel

DEPENDENCY CHAIN ANALYSIS:
9. For shared library changes (libs/shared/*, libs/lxp/*):
   - Which apps import this library?
   - Could this break the build for other teams?
   - Is this a breaking change that needs a migration?

OUTPUT FORMAT:
For each issue found, include:
- Severity: BREAKING / HIGH / MEDIUM / LOW
- Impact scope: How many files/features affected
- Specific files that will be impacted
- Recommended action

Be THOROUGH - actually run the greps and report real file counts.
```

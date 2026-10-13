# FE Development Guard

These rules are enforced DURING development. Write code that passes these on the first try.
Source: github.com/praveen-degreed/fe-claude-skills

## Before Writing Any Code

**READ the `.agent-instructions/` files** for the area you're working in -- they are the source of truth:
- `angular-standards.md` -- component patterns, state management, signals
- `code-standards.md` -- code quality, testing, a11y requirements, images
- `design-standards.md` -- Apollo components, Tailwind, tokens, focus, color
- `nx-standards.md` -- library boundaries, affected operations, imports
- `project-context.md` -- architecture, apps, technology stack
- `workflow-orchestration.md` -- task management, verification workflow

**USE existing skills** when they match the task:
- `/dgx-test-runner` -- for ALL unit test execution (uses correct jest config)
- `/dgx-a11y-warn` -- before implementing any UI feature (accessibility gut check)
- `/convert-simple-modal-to-confirm` -- when migrating legacy modals to Apollo
- `/convert-legacy-to-apollo` -- when migrating any legacy component to Apollo
- `/review-prs <PR_URL>` -- after PR creation for automated review

**USE existing workspace skills** for domain-specific guidance:
- `apollo-design-system` -- before using ANY Apollo component (never guess APIs)
- `angular-component-patterns` -- for Angular 22 signal/standalone patterns
- `angular-testing-patterns` -- for test setup and conventions
- `accessibility-patterns` -- for ARIA, keyboard nav, focus management
- `component-pattern-analysis` -- before creating new components (find existing ones first)

## Angular (v22)

- `input()` / `output()` -- never `@Input` / `@Output`
- `model()` for two-way bindings; signal queries (`viewChild()` etc.) -- never `@ViewChild` etc.
- `computed()` for derived state -- never getters
- `inject()` -- never constructor injection
- Never set `changeDetection: OnPush` -- it is the default in v22; set only `ChangeDetectionStrategy.Eager` to opt out, with a reason
- `@Service` over `@Injectable({ providedIn: 'root' })` for new singleton services
- Call Degreed's API through `NgxHttpClient`, not `HttpClient`
- No empty lifecycle hooks; no `mutate()` on signals -- use `update()` / `set()`
- `@if` / `@for` / `@switch` -- never `*ngIf` / `*ngFor` / `*ngSwitch`
- Never set `standalone: true` -- it's the default
- Never use `@HostBinding` / `@HostListener` -- use `host` object
- `NgOptimizedImage` for static images
- Lazy load feature routes

## Templates -- Never Do

- No globals: `new Date()`, `Math.*`, `JSON.*`
- No arrow functions
- No RegExp
- No `ngClass` -- use `[class.x]="condition"`
- No `ngStyle` -- use `[style.prop]="value"`

## TypeScript

- No unjustified `any` -- use `unknown` or proper types
- Interfaces in dedicated `.model.ts` files, not inline
- `??` for defaults (not `||`), `?.` for chains (not `&&`)
- `find()` not `filter()[0]`, `some()` not `filter().length > 0`
- `includes()` not `indexOf() !== -1`
- `flatMap()` not `map().flat()`, `at(-1)` not `arr[arr.length - 1]`
- `Object.entries/keys/values()` not `for...in`
- Spread `{...obj}` not `Object.assign()`
- `structuredClone()` not custom deep copy
- Template literals not string concatenation
- No `Observable<any>` or `Promise<any>` return types

## DOM -- Never Manipulate Directly

- `ViewChild` / `viewChild()` -- never `document.querySelector`
- Angular binding `[innerHTML]` -- never `element.innerHTML =`
- `[class.x]="condition"` -- never `classList.add/remove`
- Always use Angular's rendering; never bypass it with direct DOM

## RxJS -- Correct Operators

| Use Case | Operator |
|----------|----------|
| Search / typeahead | `switchMap` + `debounceTime(300)` + `distinctUntilChanged()` |
| Form submit / button click | `exhaustMap` |
| Ordered operations | `concatMap` |
| Parallel fetches | `mergeMap(fn, concurrency)` |
| Parallel must-complete | `forkJoin` |
| Derived state | `combineLatest` |
| Action needs latest state | `withLatestFrom` |

### Never Do

- `subscribe()` inside `subscribe()` -- use higher-order operator
- `subscribe()` just to set a property -- use `async` pipe; to set a signal -- use `toSignal()`
- `BehaviorSubject` for simple local state -- use `signal()` (signals first)
- `catchError` outside `switchMap` -- move it inside (keeps stream alive)
- `shareReplay()` without `refCount` on infinite streams

### Always Do

- Handle BOTH success AND error in every HTTP / observable call
- `finalize(() => loading.set(false))` for loading state
- `filter(Boolean)` or `filter(x => x != null)` to skip nulls

## Memory Leaks -- Prevent

- Every `subscribe()` needs `takeUntilDestroyed()` or `async` pipe
- In `ngOnInit` / methods: `takeUntilDestroyed(this.destroyRef)` -- inject `DestroyRef`
- In field initializers / constructor: `takeUntilDestroyed()` works directly
- Clean up `addEventListener`, `setInterval`, `setTimeout`
- Unsubscribe from `valueChanges` / `statusChanges` (existing reactive forms)

## Signals

- `signal()` for writable state, `computed()` for derived
- Never use `effect()` for state updates -- use `computed()` / `linkedSignal()`; `effect()` is a last resort for genuine side effects
- Use `set()` for replacement, `update()` for mutation

## Component Lifecycle

- `ngOnInit` for initialization -- not the constructor
- `afterNextRender` for one-shot DOM measurements / third-party init; `afterRenderEffect()` for focus or signal-driven post-render work; never `setTimeout(0)`
- Constructor / field initializers for DI and signal wiring only

## Forms

- Signal Forms (`@angular/forms/signals`) are the standard -- no new reactive or template-driven forms; migrate existing reactive forms as you touch them
- Apollo controls bind with `[formField]`; never add `ControlValueAccessor` or `ngDefaultControl` to one
- `required()` does not enforce on array fields -- pair with `minLength(path, 1, { message })`
- Show error messages for invalid fields; a control that renders its own errors owns the ARIA (`id`, `aria-describedby`, `aria-invalid`)
- `da-dropdown-legacy` is deprecated -- use `da-dropdown`

## i18n -- Every Visible String

- `DgxTranslatePipe` in templates or `translateWithDefaults(inject(TranslateService))` in TS
- Error messages and notifications must be translatable
- Follow existing translation key naming conventions

## Security

- Sanitize user input -- never trust `[innerHTML]` with raw user data
- Use `bypassSecurityTrust*()` only with validated, non-user content
- Never expose tokens, PII, or secrets in templates or `console.log`
- No hardcoded API keys or credentials

## Accessibility -- WCAG 2.2 AA

- `<button>` not `<div (click)>`, `<a>` not `<span (click)>`
- Headings: the LXP shell renders the page `<h1>`; routed content (including `da-page-header`) starts at `<h2>` -- only avoid skipped levels within routed content
- Every `da-icon` needs `ariaLabel`
- Every `<input>` needs a `<label>`
- Focus trap in modals, focus restoration on close
- Keyboard: Enter/Space/Escape/Arrow handling on interactive elements
- `aria-disabled="true"` not native `disabled`
- `aria-live` regions outside `@if` blocks
- No `eslint-disable` for a11y rules -- fix the issue

### LXP-Specific A11y

- Video/audio: captions required, transcripts for audio-only
- Auto-playing media: must have pause/stop controls
- Skip-to-content link for repeated navigation
- Quiz/assessment timeouts: adjustable or warned
- Progress indicators: screen-reader accessible
- Form errors: suggest corrections
- Drag-and-drop: provide keyboard alternative
- Touch targets: minimum 24x24 CSS pixels

## Architecture

- Search existing components before creating new ones (`@degreed/apollo`, `libs/shared/`)
- Component selection: Angular Material → CDK → Apollo → Custom (in that order)
- `@degreed/*` prefix for library imports -- no relative `../` across boundaries
- Barrel exports (`index.ts`) for new libraries
- Components > 300 lines need splitting
- Methods > 50 lines need breaking down
- Don't mix HTTP + state + UI in one service

## Degreed Service Patterns

- `AuthService`: always null-check `authUser?.prop` -- never direct access
- `NgxHttpClient`: use `catchAndSurfaceError()` for error handling
- `WebEnvironmentService`: use `getBlobUrl()` for assets -- no hardcoded URLs
- `LDFlagsService` for feature flags -- no hardcoded toggles
- `DrawerService`: always subscribe to `afterClosed()`
- Don't mix `ReactiveStore` and signals for the same state

## Existing Utilities -- Use, Don't Reinvent

- `translateWithDefaults()` for translations
- `generateGuid()` from `@degreed/core/utils`
- `camelCaseKeys()` from `@degreed/core/utils`
- `getDeepCopy()` or `structuredClone()` for cloning
- `debounceTime()` / `throttleTime()` from RxJS
- `TruncatePipe` for truncation
- `DatePipe` for date formatting
- `DialogService` / `DrawerService` / `ToastService` from Apollo
- `e.preventDefault()` / `e.stopPropagation()` -- no custom `stopEvent()` wrappers

## Styling

- Tailwind with `tw-` prefix only
- Design tokens: `neutral`, `primary`, `accent`, `success`, `warning`, `error`
- No hardcoded hex/RGB colors
- Buttons: `tw-btn-primary`, `tw-btn-secondary-outline`, etc.

## Dead Code -- Keep It Clean

- No unused variables, imports, or unreachable code
- Remove commented-out code blocks -- use git history
- Every `TODO` / `FIXME` must reference a ticket
- No empty `catch`, `if`, or `else` blocks

## Tests -- Write With the Code

- Spectator preferred -- `createComponentFactory` / `createServiceFactory`
- Shallow rendering for component tests
- Test behavior, not implementation -- assert rendered output, not spy calls
- Cover: happy path, error path, edge cases (empty, null, loading)
- `fakeAsync` / `tick` for async operations
- Never write "should create" as the only test
- `takeUntilDestroyed` cleanup must be tested
- A11y: keyboard interactions and focus management tested for UI components

## Before Modifying Shared Code

- Grep for all consumers of the component/service
- Check Input/Output backward compatibility
- If breaking: list every file that will break
- Read the component's source before using its API

# FE Development Guard

These rules are enforced DURING development. Write code that passes these on the first try.
Source: github.com/praveen-degreed/fe-claude-skills

## Angular (v20+)

- `input()` / `output()` -- never `@Input` / `@Output`
- `computed()` for derived state -- never getters
- `inject()` -- never constructor injection
- `ChangeDetectionStrategy.OnPush` on every component
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
- `structuredClone()` not custom deep copy
- Template literals not string concatenation
- No `Observable<any>` or `Promise<any>` return types

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
- `subscribe()` just to set a property -- use `async` pipe
- `BehaviorSubject` for simple state -- use `signal()`
- `catchError` outside `switchMap` -- move it inside (keeps stream alive)
- `shareReplay()` without `refCount` on infinite streams

## Memory Leaks -- Prevent

- Every `subscribe()` needs `takeUntilDestroyed()` or `async` pipe
- In `ngOnInit` / methods: `takeUntilDestroyed(this.destroyRef)` -- inject `DestroyRef`
- In field initializers / constructor: `takeUntilDestroyed()` works directly
- Clean up `addEventListener`, `setInterval`, `setTimeout`
- Unsubscribe from `valueChanges` / `statusChanges`

## Signals

- `signal()` for writable state, `computed()` for derived
- Never use `effect()` for state updates -- only for side effects
- Use `set()` for replacement, `update()` for mutation

## Reactive Forms

- Always Reactive Forms -- never template-driven
- `FormBuilder` via `inject(FormBuilder)`
- Typed: `FormGroup<MyFormType>`
- Check `form.valid` before submit
- `markAllAsTouched()` on submit attempt
- Show error messages for invalid fields
- Never mix `[(ngModel)]` with reactive forms

## i18n -- Every Visible String

- `DgxTranslatePipe` in templates or `translateWithDefaults(inject(TranslateService))` in TS
- Error messages and notifications must be translatable
- Follow existing translation key naming conventions

## Accessibility -- WCAG 2.2 AA

- `<button>` not `<div (click)>`, `<a>` not `<span (click)>`
- Every `da-icon` needs `ariaLabel`
- Every `<input>` needs a `<label>`
- Focus trap in modals, focus restoration on close
- Keyboard: Enter/Space/Escape/Arrow handling on interactive elements
- `aria-disabled="true"` not native `disabled`
- `aria-live` regions outside `@if` blocks
- No `eslint-disable` for a11y rules -- fix the issue

## Architecture

- Search existing components before creating new ones (`@degreed/apollo`, `libs/shared/`)
- `@degreed/*` prefix for library imports -- no relative `../` across boundaries
- Barrel exports (`index.ts`) for new libraries
- Components > 300 lines need splitting
- Methods > 50 lines need breaking down
- Don't mix HTTP + state + UI in one service

## Existing Utilities -- Use, Don't Reinvent

- `translateWithDefaults()` for translations
- `generateGuid()` from `@degreed/core/utils`
- `camelCaseKeys()` from `@degreed/core/utils`
- `getDeepCopy()` or `structuredClone()` for cloning
- `debounceTime()` / `throttleTime()` from RxJS
- `TruncatePipe` for truncation
- `DatePipe` for date formatting
- `DialogService` / `DrawerService` / `ToastService` from Apollo

## Styling

- Tailwind with `tw-` prefix only
- Design tokens: `neutral`, `primary`, `accent`, `success`, `warning`, `error`
- No hardcoded hex/RGB colors
- Buttons: `tw-btn-primary`, `tw-btn-secondary-outline`, etc.

## Tests -- Write With the Code

- Spectator preferred -- `createComponentFactory` / `createServiceFactory`
- Shallow rendering for component tests
- Test behavior, not implementation -- assert rendered output, not spy calls
- Cover: happy path, error path, edge cases (empty, null, loading)
- `fakeAsync` / `tick` for async operations
- Never write "should create" as the only test
- `takeUntilDestroyed` cleanup must be tested

## Before Modifying Shared Code

- Grep for all consumers of the component/service
- Check Input/Output backward compatibility
- If breaking: list every file that will break
- Read the component's source before using its API

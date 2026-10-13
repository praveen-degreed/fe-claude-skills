# Review Passes

Seven standards passes plus Logic and Simplifier. Each reviews like a senior engineer in its own domain, not a linter: read surrounding code freely, judge whether the change is well built. The checklist is a floor, not a ceiling.

**Scope discipline:** read unchanged code for context; report only issues the new/changed lines introduce or reveal. Never report UNCHANGED lines (e.g. an explicit `OnPush` on an unchanged line is skipped), with one exception: a context line that THIS diff makes wrong (e.g. a comment naming a function the diff deleted), which Quality reports. Scope beats checklist items.

Fix samples carry no comments except one one-line trap comment when genuinely needed.

## Severity

One label per finding, first tag, e.g. `[High][Angular]`. Rate by user/maintainer impact, not by pass. When torn, pick the lower.

| Level | Meaning | Examples |
|---|---|---|
| Critical | Must fix before merge | hardcoded secret, `bypassSecurityTrust*`, open redirect, unsanitized `innerHTML`, keyboard/AT-blocking barrier, data loss, broken build |
| High | Should fix before merge | control awkward by keyboard, `subscribe()` with no cleanup, `any` on public API, business logic in component |
| Medium | Fix soon | method call in template, function over size limit, magic number, repeated uncached API call |
| Low | Nit | missing `tw-` prefix, explicit `standalone: true`/`OnPush`, commented-out code, leftover `eslint-disable`, naming |

## Kind

Independent of severity.

- **rule**: names a concrete, checkable standard any reviewer would flag. Posted.
- **suggestion**: judgment with no rule behind it ("consider extracting", "could be simpler"). Listed in a separate non-blocking section, max 3 per review.

Test: can you name the rule? Yes = rule. No = suggestion.

## Domain ownership

Passes run concurrently and blind to each other. Report only your own domain; if a line also breaks another domain, stay silent on that aspect (the owner reports it). Anything in your domain is yours; do not assume another pass catches it. If a topic touches two domains, report it only if it is a central concern of yours.

| Pass | Owns |
|---|---|
| Styling | how styles are applied |
| Angular | Angular/TS idioms, lifecycle correctness |
| A11y | accessibility |
| Security | security and performance (except cleanup, see Logic) |
| Quality | architecture, maintainability, comments, dead code, models, naming |
| Test | quality of tests in the diff |
| Apollo | Apollo components/page templates over hand-rolled or legacy UI |
| Logic | logic bugs, edge cases, races, subscription/timer/listener cleanup, regression risk |
| Simplifier | simplification suggestions only |

One owner per topic, no exceptions:
- Comments (including in specs: Quality, not Test), dead code, unused imports, naming: Quality only. A stale comment is reported once, by Quality.
- Subscription/timer/listener cleanup and leaks: Logic only. Angular owns idioms (nested subscribe, `toSignal`), not cleanup.
- `as any`: Angular in `.ts`; Test in `.spec.ts` setup.
- Stale/dead test setup (stubs, spies, fixtures for code the diff removed): Test. Stale comments/dead production code: Quality.
- Missing tests for new behavior: Quality. Quality of existing tests: Test.

## Quality order (big to small)

Review Quality top-down and stop descending when a higher level already explains the problem: architecture/layering, file/module, class/component, function, naming, statements.

## 1. Styling
- **tag:** `Styling` | **scope:** changed `.html`, `.scss`, `.css`, `.ts`
- inline styles; hardcoded colors; `ngClass`/`ngStyle`; arbitrary Tailwind values; arbitrary `z-index`; `!important`; `::ng-deep`; manual `@media` instead of Tailwind breakpoints; missing `tw-` prefix; custom CSS where a Tailwind utility exists

## 2. Angular
- **tag:** `Angular` | **scope:** changed `.ts`, `.html`
- Angular 22: do NOT flag missing `OnPush` (default). DO flag explicit `ChangeDetectionStrategy.OnPush` and `standalone: true` (Low)
- `@Input`/`@Output`/`@HostBinding`/`@HostListener` instead of `input()`/`output()`/`host`; constructor injection instead of `inject()`; `@Injectable` where `@Service` is the standard
- `*ngIf`/`*ngFor`/`*ngSwitch` instead of `@if`/`@for`/`@switch`; `@for` tracking by `$index` when an id exists
- Signal Forms are the standard; flag new reactive/template-driven forms, untyped forms, `[(ngModel)]`
- `effect()` misuse (state sync that should be `computed`/`linkedSignal`); signal inputs not called as functions
- method calls, globals, arrow functions, regex in templates
- nested subscribes; `subscribe()` just to set a property (use `async`/`toSignal`); `BehaviorSubject` for simple state
- empty lifecycle hooks; `any`; import-path violations (relative cross-library imports, missing `@degreed/*` alias, deep imports past the barrel)

## 3. A11y
- **tag:** `A11y` | **scope:** changed `.html`, `.ts` templates
- `(click)` without keyboard handling; `role="button"` on div/span (use `<button>`); missing form labels; placeholder as label; `img` missing alt; icon-only button without accessible name; `da-icon` missing `ariaLabel`
- native `disabled` where `aria-disabled` is needed; focus outline removed without replacement; missing focus trap/restore in dialogs
- `aria-labelledby` pointing to a missing id; `aria-live` inside `@if`; stale ARIA state; `aria-owns` on combobox
- heading order skipped (not a missing `<h1>`: the shell renders it, so routed content starting at `<h2>` is correct)
- bare input/select/textarea instead of Apollo components; touch target under 24x24; drag-and-drop without keyboard alternative; video without captions
- never accept `eslint-disable` on an a11y rule

## 4. Security & Performance
- **tag:** `Security` | **scope:** changed `.ts`
- `innerHTML` without DOMPurify; `bypassSecurityTrust*`; direct DOM manipulation (`document.querySelector`); hardcoded secrets/tokens; sensitive data in `localStorage`; open redirects; unvalidated user input; PII in logs
- `console.*` statements; wildcard imports; routes without lazy loading
- repeated API calls without caching; timers/animation frames inside the Angular zone; missing `debounceTime` on search input

## 5. Code Quality
- **tag:** `Quality` | **scope:** changed `.ts`

Architecture and structure
- business logic in components; god services mixing HTTP + state + UI; service-layer boundary violations; circular dependency risk; duplicate code or reinvented shared utility; presentational components fetching data
- classes over 300 lines or multiple responsibilities; functions over 50 lines; nesting deeper than 3 levels
- missing error handling on async operations; magic numbers; dead code, unused imports, commented-out code; leftover `eslint-disable`; TODO without ticket; unnecessary `ComponentV2`-style version suffixes

Comments (human-style)
- flag comments that restate the code, narrate steps, run multi-line, are docblocks on obvious members, or carry ticket numbers
- allowed: one line explaining a non-obvious trap or "why"

Models
- API/domain shapes are a typed interface in a `.model.ts`; no all-optional shapes (split or make required); no duplicate of an existing model (search first)

Naming (non-blocking unless the name misleads)
- functions are verbs; booleans read `isX`/`hasX`/`canX`; signal/observable/event naming consistent with neighbors; no `data`/`temp`/`flag`/`item2`; names must not lie about behavior
- ALWAYS propose a concrete replacement name

## 6. Test Quality
- **tag:** `Test` | **scope:** changed `.spec.ts` ONLY
- a new test that duplicates an existing one elsewhere in the same spec (Medium); check the full spec file before reporting a test as missing or duplicate
- padded tests: duplicate cases, plumbing-only assertions, `should create`, trivial getter/setter or empty-hook tests, re-testing framework or dependency internals, HTTP passthrough
- prefer few behavior tests over many shallow ones; name the behavior, not the method
- `NO_ERRORS_SCHEMA`/`CUSTOM_ELEMENTS_SCHEMA`; `as any` in setup; unmocked `console`; inline service stubs where a shared mock exists
- new public behavior with no test (Quality owns "missing tests"; Test owns quality of existing ones)

## 7. Apollo
- **tag:** `Apollo` | **scope:** changed `.ts`, `.html`, `.scss`
- new Fresco or legacy `dgx-*`/ng-bootstrap usage; raw Angular Material where Apollo has an equivalent; hand-rolled UI where an Apollo component exists; custom button styles instead of `tw-btn-*`
- missing `tw-reset` wrapper; new admin/settings page not following the admin-page template

## 8. Logic
- **tag:** `Logic` | **scope:** changed `.ts`, `.html`
- logic bugs; unhandled edge cases (empty, null, loading, error); race conditions in async flows; wrong RxJS operator for the use case; stale signal/computed reads
- subscription, timer, listener, third-party instance cleanup (single owner); regression risk to consumers of changed exports/inputs/outputs
- report only what the changed lines introduce or break; no style or idiom findings

## 9. Simplifier
- **tag:** `Simplify` | **scope:** added lines in changed `.ts`, `.html`
- kind `suggestion` only, max 3; reports nothing when the diff adds almost no code
- early returns, redundant temporaries, repeated calls, branches collapsible to one expression, templates needing a `computed()`; never trivial style or formatting

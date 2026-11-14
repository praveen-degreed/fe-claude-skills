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
| Medium | Fix soon | method call in template, function over size limit, reinvented shared util, magic timeout/limit/path (see Review method), repeated uncached API call |
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

## Review method (like a human reviewer)

For each changed file, in this order:

1. **Read the whole file** at `head/<path>` once, not only the diff hunks: know what the file is for and what is already in it.
2. **Read the scan leads** for the file in `<fetch dir>/scan.txt` (NEARBY, REUSE, CONSTANT, HELPER, SECURITY). A lead is a question, not a finding: open the cited line and the existing code it points at, and report only what holds up.
3. **Reuse first.** Before accepting any new helper, pipe, component, constant, type or service, check the repo already lacks it: the scan's REUSE and NEARBY leads, then ONE search by behaviour (the verb and noun, e.g. `formatDuration`, `debounce`, `toast`) in `libs/shared/core/{utils,services,pipes}`, the feature's own `*.utils.ts` / `*.constants.ts`, and the file's siblings. If the file or its siblings already use a shared service or util for the same job (toasts, dialogs, HTTP error handling, translation, URL encoding, cloning, ids), new code must use it too.
4. **Place every new symbol** with the Placement section below: stays here, a feature-local util/model/constants file, a service, or a shared lib; check the scan's PLACEMENT leads (types declared in component/service files, big pure functions, wrong import direction).
5. **Name the existing thing**: a reuse finding cites two locations, the new code and the existing symbol's `path:line`, and says how to call it. No second location, no finding.

Quality rules that follow from it (kind rule; severity as stated):

- **Reinvented shared code** (a util, service, pipe, component, model or constant that already exists): Medium. High only when the hand-rolled version is demonstrably weaker on security or correctness (sanitising, encoding, auth, URL building); state the difference.
- **Magic values**: Low for a stray literal; Medium for a timeout, delay, limit, page size, threshold, API path, storage key, route or feature key, or any value used in two or more places. Fix: a named `UPPER_SNAKE_CASE` constant in the feature's `<feature>.constants.ts` (the existing one if present, per the scan's CONSTANT-HOME), `as const` or an enum for related sets. Not constants: `0`, `1`, `-1`, array indexes, a translation key used once, test fixtures.
- **Big or tangled functions**: a function over 50 lines, nesting deeper than 3, or doing two or more jobs (fetch, map, format, side effect) is Medium. Fix: name the helpers and the cut points. Pure data logic goes to a `<feature>.utils.ts` function that is testable without TestBed; component methods stay thin.
- **Security leads** (scan SECURITY section): confirm the value is reachable from user or server data before rating above Low; then use the Severity table.

## Placement (where code belongs; decide per symbol)

Ask of each new function, type or constant: "does it belong in this file, next to it, or in a shared lib?" Conventions in fe-workspace, by file count: `<feature>.utils.ts` (183, over `.util.ts` 62), `<feature>.model.ts` (449, over `.models.ts` 45), `<feature>.constants.ts` (28), `.types.ts` (7); shared generic code lives under `@degreed/core/{utils,services,pipes,models,types}`.

| Code is | Goes to | Stays in the current file when |
|---|---|---|
| a pure function (no `this`, no `inject()`, no DOM, no signals), over about 15 lines or with branching, or testable without TestBed | `<feature>.utils.ts` next to the feature | it is a few lines, used once, and reads like part of the class |
| an exported interface, type or enum; the shape of a public `input()`/`output()`; used by two or more files | `<feature>.model.ts` | it is private to the file, not exported and not part of its API |
| a literal: timeout, limit, page size, path, key, repeated string | `<feature>.constants.ts` (existing one first) | it is used once and its meaning is obvious from the call |
| logic needing DI, state, HTTP or lifecycle | a service or store (`@Service`), not a util | a component only wires UI to it |
| a generic helper with no domain words (strings, urls, dates, ids, objects, cloning) that two or more features need | `@degreed/core/*` (search it first: if it exists, use it) | only this feature uses it today: keep it a feature-local util and say "promote on second use" |
| domain logic used by two or more LXP features | an lxp shared lib (for example `libs/lxp/services`), not `@degreed/core` | one feature uses it |

Direction rules (a violation is Medium; it is a real dependency problem, not a style point):

- `*.utils.ts`, `*.model.ts`, `*.constants.ts` never import from a `*.component.ts` or `*.service.ts` file. A shared type or helper used by a util and a component belongs in a model or utils file that both import (a util importing `BuilderActionType` from a component file is the typical case).
- `@degreed/core/*` is `scope:core` and may not import LXP libs or features (`scope:lxp` and `scope:app-lxp` depend on core, never the reverse). Business vocabulary (maestro, quiz, coach, audience) in a shared-core candidate means it belongs in an lxp lib or the feature instead.
- Business logic stays out of components; UI strings and translation stay out of utils.

How to report (kind rule, severity Low unless a direction rule or a duplicated business rule applies):

- Name the symbol, where it is, and where it goes, with the file name to create or the existing file to add it to (the scan's NEARBY and CONSTANT-HOME leads show what exists).
- Leave small single-use private helpers alone: moving them is churn. The test is reuse, testability or a dependency direction, not file length alone.
- Do not propose a shared lib for something only one feature uses.

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

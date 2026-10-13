---
name: dev-guard
description: >
  Frontend development standards for Angular 22/TypeScript codebases. Enforces
  coding patterns, RxJS best practices, accessibility (WCAG 2.2 AA), security,
  testing, and Degreed workspace conventions. Use before writing any frontend
  code — load these rules at session start so code passes review on the first try.
  Activate when the user starts coding, opens a new session, or asks about Angular,
  TypeScript, RxJS, or accessibility standards.
license: MIT
compatibility: >
  Designed for Angular 22 with Nx monorepo. Standards reference Degreed-specific
  services and libraries but patterns are broadly applicable to Angular projects.
metadata:
  author: praveen-degreed
  version: "1.0"
---

# FE Development Guard

These rules are enforced DURING development. Write code that passes review on the first try.

**Read [references/fe-standards.md](references/fe-standards.md) immediately** — it contains the full coding standards for Angular, TypeScript, RxJS, accessibility, security, testing, and architecture.

These are the same rules that the `review-prs` skill checks, but framed as positive guidance ("always do X") instead of review flags ("you did X wrong"). Following these standards reduces PR review findings.

## Quick Reference

The standards in `references/fe-standards.md` cover:

- **Angular (v22)** — `input()`/`output()`, `inject()`, `@if`/`@for`, signals; OnPush is the default (don't set it; only set `Eager` to opt out)
- **Templates** — No globals, arrow functions, RegExp, ngClass, ngStyle
- **TypeScript** — No `any`, proper operators (`??`, `?.`), modern array methods
- **DOM** — Never manipulate directly; use Angular bindings
- **RxJS** — Correct operator selection, anti-patterns, cleanup
- **Memory Leaks** — `takeUntilDestroyed()`, async pipe, event listener cleanup
- **Signals** — `signal()`, `computed()`, no `effect()` for state updates
- **Reactive Forms** — Typed, validated, never template-driven
- **i18n** — Every visible string translated
- **Security** — Sanitize input, no exposed secrets
- **Accessibility (WCAG 2.2 AA)** — Semantic HTML, keyboard, focus, ARIA
- **Architecture** — Search before creating, component selection priority
- **Service Patterns** — AuthService, NgxHttpClient, DrawerService conventions
- **Tests** — Spectator, behavior-focused, edge cases covered

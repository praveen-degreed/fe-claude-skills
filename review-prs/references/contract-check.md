# Contract Check (FE vs backend)

Run by fe-impact-analyzer (Agent 6) when the diff adds or changes an HTTP call (NgxHttpClient / HttpClient), a GraphQL query/mutation, or a `*.model.ts`. Skip otherwise.

## Procedure

1. From the diff extract per call: route, verb, request model, response model (name + `file:line`). Max 3 endpoints per PR; pick the new/changed ones.
2. Run `<skill dir>/scripts/find-endpoint.sh '<route fragment>'` (drop query string and id segments; the script ignores numeric ids). Backends come from `REVIEW_BACKEND_REPOS` (default `../Degreed:../degreed-coach-builder`).
3. Open ONLY the matching action and its request/response DTO. Max 2 backend file reads per endpoint.
4. Compare and report. Cite BOTH sides: `FE reads <x> (path:line); DTO sends <y> (path:line)`.
5. No match, repos missing, or ambiguous: write `contract not verified: <reason>` and move on. Never infer a contract from the FE model, names, or memory.
6. A field absent from the checked-out backend branch only proves it is absent there: name the branch, and if the PR body mentions a paired backend PR write `not verifiable`. Never call it a bug.

## Backend layouts

- `../Degreed` (C#): controllers in `trunk/Degreed.Web.vNext/Controllers/Api/*Controller.cs`. Route = class `[Route("api/[controller]")]` or `[Route("api/dg-maestro")]` + method `[HttpGet("Action")]`. DTOs are in `trunk/Degreed.Common.Standard/Models/`, `trunk/Degreed.Data.Standard/Domain/` or `trunk/Degreed.Web.vNext/ViewModels/`.
- `../degreed-coach-builder` (Python/FastAPI): routers in `backend/app/api/*.py` (`@router.post("/x/{id}")`), mounted with a prefix in `backend/app/api/__init__.py`, served under `/dgcb/api`. Models are Pydantic in `backend/app/request_and_response/` and `backend/app/models/`.
- GraphQL: no schema file found in the backends; if a query cannot be matched, `contract not verified: graphql schema`.

## Mapping rules

- FE `NgxHttpClient` prefixes `/api` and sends `dg-casing=camel`: FE camelCase field `fooBar` maps to C# `FooBar`. Pydantic fields are as declared (snake_case unless aliased), so check the alias/config.
- Controller route and action names are case-insensitive. A `{id}`/`userKey` can be a long or an obfuscated string (`StringHelper.ResolveObfuscatedId`); check the FE type (`string` vs `number`).
- C# nullability: `?`/reference types without `[Required]` may be null; enums serialize per `dg-enum-format` (string vs number), so check which one the FE expects.

## Compare

Route, verb, request fields (required vs optional), response fields, types, nullability, enum values, casing, obfuscated-id handling. Mismatch = blocking; unverified field presence = non-blocking.

## Model quality (apply to every changed `*.model.ts`, no backend needed)

- Typed interface in `.model.ts`; no `any`; no all-optional shape; no duplicate of an existing model (Grep the name and fields first); enums or string-literal unions, not loose `string`.
- An FE interface declares shape, not backend reality: a field typed non-optional may still never be populated. Verify against the DTO before trusting it.

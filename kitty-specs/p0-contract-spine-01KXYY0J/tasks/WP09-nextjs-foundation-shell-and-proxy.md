---
work_package_id: WP09
title: Next.js Foundation Shell and Proxy
dependencies:
- WP01
- WP02
- WP03
requirement_refs:
- FR-001
- FR-002
- FR-004
- FR-015
- NFR-001
- NFR-004
- NFR-007
- C-002
tracker_refs: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch.
subtasks:
- T042
- T043
- T044
- T045
- T046
phase: Phase 3
assignee: ''
agent: codex
history: []
agent_profile: frontend-freddy
authoritative_surface: apps/web/
create_intent:
- apps/web/package.json
- apps/web/next.config.ts
- apps/web/tsconfig.json
- apps/web/eslint.config.mjs
- apps/web/vitest.config.ts
- apps/web/playwright.config.ts
- apps/web/src/app/layout.tsx
- apps/web/src/app/page.tsx
- apps/web/src/app/globals.css
- apps/web/src/lib/api/client.ts
- apps/web/src/lib/api/errors.ts
- apps/web/src/lib/api/health.ts
- apps/web/src/lib/api/server.ts
- apps/web/src/lib/contracts/index.ts
- apps/web/src/lib/contracts/wire-values.ts
- apps/web/tests/foundation/shell.test.tsx
- apps/web/tests/foundation/accessibility.test.tsx
- apps/web/tests/foundation/contract-client.test.ts
- apps/web/tests/foundation/proxy.e2e.ts
execution_mode: code_change
model: ''
owned_files:
- apps/web/package*.json
- apps/web/*config*
- apps/web/src/app/layout.tsx
- apps/web/src/app/page.tsx
- apps/web/src/app/globals.css
- apps/web/src/lib/api/**
- apps/web/src/lib/contracts/**
- apps/web/tests/foundation/**
role: implementer
tags: []
task_type: implement
---

# Work Package Prompt: WP09 – Next.js Foundation Shell and Proxy

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `frontend-freddy`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Build the smallest production-shaped Next.js App Router shell that proves the real
same-origin web-to-Zig boundary, presents health and structured failures accessibly,
and consumes contract-derived types without duplicating authoritative business rules.

The shell should feel deliberately quiet, boring, and trustworthy. Its typography,
spacing, focus behavior, and responsive layout must be careful enough to establish a
foundation for later invoice-management screens without implementing those screens now.

## Context

- WP01 establishes the root npm workspace, exact toolchain, and focused command wiring.
- WP02 establishes canonical wire values and cross-language fixtures.
- WP03 establishes base OpenAPI, generated contract types, and structured envelopes.
- Consume prerequisite outputs; do not redefine their schemas in web code.
- Read `kitty-specs/p0-contract-spine-01KXYY0J/spec.md` before implementing.
- Read IC-07 and the boundary/data-flow sections of the implementation plan.
- Read Decisions 3, 5, and 9 in `research.md` for pins and validation intent.
- Use the Next.js App Router, server components by default, and a same-origin `/api/v1`.
- Zig remains the only authoritative business backend.
- The browser must never connect directly to the Zig service origin.
- Do not expose the internal Zig origin in a `NEXT_PUBLIC_*` environment variable.
- Do not fetch backend data in a client component or `useEffect`.
- Do not access ShovelerDB, filesystem persistence, or domain services from Next.js.
- Do not duplicate authorization, money arithmetic, lifecycle, scheduling, or invoice rules.
- P0 contains only a health presentation and structured error proof.
- Do not add forms, editable fields, tables of business records, charts, dashboards,
  invoice previews, logos, authentication, client records, or project records.
- Do not commit generated OpenAPI or generated client files.

## Branch Strategy

- **Strategy**: `wp_branch`
- **Planning base branch**: `feat/p0-contract-spine`
- **Merge target branch**: `feat/p0-contract-spine`
- Start with the governed implementation action:

```bash
spec-kitty agent action implement WP09 --agent codex
```

- Work only within the exact `owned_files` patterns in frontmatter.
- Do not edit root package files, locks, contracts, Zig code, CI, or mission state.
- If WP01 omitted a required root script, record an integration request for its owner.
- If WP03 generation is incompatible, report the contract issue instead of hand-copying it.

## Design Direction

- Prefer semantic HTML and native browser behavior over component abstractions.
- Use one calm neutral surface, near-black text, restrained borders, and one accent color.
- Avoid gradients, glass effects, oversized hero typography, animations, and decorative noise.
- Use a local/system font stack so a clean build performs no remote font request.
- Use a compact typographic scale with explicit line height and letter spacing.
- Preserve strong text contrast and visible keyboard focus in light and dark preferences.
- Let narrow screens reflow naturally without horizontal page scrolling.
- Keep messages concise, safe, and derived from the structured API envelope.

## Subtasks & Detailed Guidance

### Subtask T042 – Pinned Next.js App and Build Configuration

**Purpose**

Create an independently buildable web workspace whose runtime and validation versions match
the approved P0 toolchain and root workspace conventions.

**Steps**

1. Create `apps/web/package.json` as a private workspace package.
2. Pin Next.js exactly to `16.2.10`.
3. Pin React and React DOM exactly to `19.2.7`.
4. Pin TypeScript exactly to `6.0.3` and ESLint exactly to `10.7.0`.
5. Pin every web test dependency to an exact compatible version.
6. Do not use caret, tilde, tag, floating branch, or unpublished registry references.
7. Reuse the root npm lock from WP01; do not create a competing dependency graph.
8. Provide package-local scripts for dev, lint, typecheck, test, e2e, and build.
9. Make the root `web:check` script invoke the same underlying package commands if wired.
10. Create a strict `tsconfig.json` with no implicit `any` escape hatch.
11. Configure App Router and React server behavior in `next.config.ts`.
12. Define the server-side proxy/rewrite target from a server-only environment value.
13. Fail startup or proxy resolution clearly when the internal API origin is invalid.
14. Configure ESLint Flat Config without disabling framework correctness rules globally.
15. Configure component tests with a DOM environment and deterministic setup.
16. Configure Playwright for the real production-shaped Next.js server.
17. Keep configs inside the declared `apps/web/*config*` ownership pattern.
18. Avoid Tailwind, UI frameworks, chart libraries, and speculative dependencies.

**Files**

- `apps/web/package.json`
- `apps/web/next.config.ts`
- `apps/web/tsconfig.json`
- `apps/web/eslint.config.mjs`
- `apps/web/vitest.config.ts`
- `apps/web/playwright.config.ts`

**Validation**

- Install from the root lock with `npm ci`.
- Run package-local lint, strict typecheck, tests, and production build.
- Inspect the production client bundle for server-only environment values.
- Confirm a clean build makes no network request for fonts or build inputs.

### Subtask T043 – Accessible Typographic Foundation Shell

**Purpose**

Create a restrained page shell that is readable, keyboard-accessible, responsive, and ready
to host future feature missions without pretending P0 already contains product workflows.

**Steps**

1. Create `src/app/layout.tsx` with valid document metadata and language.
2. Use a descriptive product title without inventing a brand identity.
3. Include a visible skip link targeting the main content landmark.
4. Use exactly one page-level `main` landmark and a logical heading hierarchy.
5. Create `src/app/page.tsx` as a server component by default.
6. Present a concise foundation heading, service status, and plain explanatory copy.
7. Do not render fake navigation links to features that do not exist.
8. Do not include placeholder cards for invoices, revenue, charts, clients, or projects.
9. Render loading/unavailable status with text, not color or icon alone.
10. Associate technical status labels and values semantically.
11. Ensure any error summary can receive focus when navigation returns an error.
12. Use `aria-live="polite"` only where status may update; avoid noisy announcements.
13. Create `globals.css` with design tokens for color, measure, spacing, and type.
14. Use a system-serif or carefully chosen system stack for editorial headings only if clear.
15. Use a legible system UI stack for status and body text.
16. Keep minimum body text at 16 CSS pixels and line height near 1.5 or greater.
17. Provide visible `:focus-visible` outlines with sufficient contrast and offset.
18. Preserve usability at 200% zoom and 320 CSS pixels width.
19. Prevent long request IDs and error codes from causing horizontal overflow.
20. Respect light/dark preferences without relying on low-contrast gray text.
21. Use responsive spacing with `clamp()` only where bounds remain predictable.
22. Avoid hydration solely for visual decoration or static status presentation.

**Files**

- `apps/web/src/app/layout.tsx`
- `apps/web/src/app/page.tsx`
- `apps/web/src/app/globals.css`

**Validation**

- Navigate using only the keyboard and verify the skip link and focus order.
- Test the shell at 320, 768, 1280, and 1920 CSS-pixel viewports.
- Test 200% zoom, forced-colors mode, and reduced-motion preference.
- Run automated accessibility checks and manually inspect landmark/heading structure.

### Subtask T044 – Contract-Derived Client with Exact Wire Values

**Purpose**

Expose a narrow typed health client and envelope parser derived from WP02/WP03 contracts,
while preserving exact numeric strings and keeping web code presentation-only.

**Steps**

1. Create `src/lib/contracts/index.ts` as the committed contract facade.
2. Import or re-export types produced by the WP03 generation flow.
3. Do not paste generated OpenAPI types into committed source.
4. Do not create a second hand-maintained success/error schema.
5. Keep generated contract output ignored and regenerate it before typecheck/build.
6. Create `src/lib/contracts/wire-values.ts` for presentation-safe adapters only.
7. Preserve canonical signed 64-bit decimal strings across parsing and rendering.
8. Never coerce Money `minor_units`, revisions, or large counters through JS `number`.
9. Use `bigint` only behind an explicit checked adapter when display logic needs it.
10. Never perform authoritative money arithmetic or currency conversion in the web shell.
11. Preserve EntityId, LocalDate, and UtcInstant text exactly after contract validation.
12. Create a generic API result type that retains `meta.request_id`.
13. Model structured failures with stable code, safe message, and optional field failures.
14. Preserve field-failure JSON Pointer paths; do not reinterpret them as business rules.
15. Create `src/lib/api/client.ts` with injectable fetch for deterministic tests.
16. Reject non-JSON, malformed-envelope, timeout, and unexpected-status responses safely.
17. Do not expose response bodies or transport internals in user-facing fallback messages.
18. Create `errors.ts` to map transport categories to accessible presentation copy.
19. Keep server error codes and safe server messages authoritative.
20. Do not infer success from HTTP status when the envelope shape is invalid.

**Files**

- `apps/web/src/lib/contracts/index.ts`
- `apps/web/src/lib/contracts/wire-values.ts`
- `apps/web/src/lib/api/client.ts`
- `apps/web/src/lib/api/errors.ts`
- `apps/web/src/lib/api/health.ts`

**Validation**

- Typecheck against regenerated WP03 output from a clean checkout.
- Round-trip signed 64-bit minimum and maximum decimal-string fixtures exactly.
- Test structured success, structured error, field failures, malformed JSON, and timeouts.
- Assert test helpers never use unsafe numeric literals for exact wire values.

### Subtask T045 – Server-Side Health Proxy and Structured Errors

**Purpose**

Prove the supported same-origin boundary by routing `/api/v1/health` through Next.js to the
Zig service and rendering structured responses without a browser-visible backend origin.

**Steps**

1. Configure `/api/v1/:path*` as a server-side proxy/rewrite in `next.config.ts`.
2. Read the Zig origin only from server-side configuration.
3. Validate the configured origin and restrict it to the intended HTTP(S) base URL form.
4. Preserve the request path and query string without allowing arbitrary destination input.
5. Do not accept a proxy target from a browser header, query, cookie, or route parameter.
6. Keep the public browser URL same-origin at `/api/v1/*`.
7. Do not add CORS as a substitute for the supported same-origin architecture.
8. Create `src/lib/api/server.ts` and mark its API as server-only by construction.
9. Use the contract-derived client to request `GET /api/v1/health` semantics.
10. Disable accidental stale health caching where it would misrepresent readiness.
11. Preserve upstream status and the structured success/error envelope.
12. Preserve `meta.request_id` for support correlation.
13. Render safe structured errors in the shell with an accessible summary.
14. Map transport unavailability to one stable local presentation category.
15. Never render stack traces, internal hostnames, absolute paths, or raw upstream bodies.
16. Reject redirects to unexpected origins rather than following them silently.
17. Bound request duration with an abort signal and deterministic timeout category.
18. Ensure the browser bundle contains no Zig origin and performs no direct Zig fetch.
19. Add no feature mutation route, authentication shim, or business validation.

**Files**

- `apps/web/next.config.ts`
- `apps/web/src/lib/api/server.ts`
- `apps/web/src/lib/api/health.ts`
- `apps/web/src/app/page.tsx`

**Validation**

- Start Zig and Next.js, then request `http://localhost:3000/api/v1/health`.
- Confirm the browser-visible request is same-origin and the response is contract-valid.
- Stop Zig and confirm the shell remains readable with a safe accessible failure.
- Search production assets for the configured internal API origin and require no match.

### Subtask T046 – Component, E2E, and Independent Gate Coverage

**Purpose**

Make the visual shell and web-to-Zig boundary non-vacuous with independently runnable tests
covering semantics, accessibility, exact contracts, responsive layout, and the real proxy.

**Steps**

1. Create `shell.test.tsx` for semantic structure and visible health states.
2. Assert one main landmark, one page heading, visible status text, and no fake features.
3. Create `accessibility.test.tsx` using an automated accessibility engine.
4. Test success, structured error, timeout, and unavailable service renderings.
5. Assert error information is not conveyed by color alone.
6. Assert skip-link target, labels, headings, live-region restraint, and focus visibility.
7. Create `contract-client.test.ts` against WP02/WP03 valid and invalid fixtures.
8. Cover signed 64-bit boundaries without JS-number coercion.
9. Cover success and failure envelopes including request IDs and JSON Pointer fields.
10. Cover non-JSON, malformed envelope, unexpected status, redirect, and timeout behavior.
11. Create `proxy.e2e.ts` against real running Next.js and Zig processes.
12. Request the browser-supported `http://localhost:3000/api/v1/health` path.
13. Assert success data and request metadata satisfy the canonical contract.
14. Assert the browser never calls the Zig origin directly.
15. Assert an upstream structured failure remains safe and correlated.
16. Assert an unavailable Zig process produces the designed fallback state.
17. Test narrow/mobile, tablet, desktop, 200% zoom, and dark preference snapshots.
18. Fail on horizontal page overflow at 320 CSS pixels.
19. Measure 100 local ready-health requests and enforce p99 below one second.
20. Keep component tests deterministic; reserve real boundary assertions for E2E.
21. Ensure `web:check` runs format, lint, strict types, component tests, and build.
22. Ensure `http:smoke` uses the same real proxy path as E2E.

**Files**

- `apps/web/tests/foundation/shell.test.tsx`
- `apps/web/tests/foundation/accessibility.test.tsx`
- `apps/web/tests/foundation/contract-client.test.ts`
- `apps/web/tests/foundation/proxy.e2e.ts`

**Validation**

- Run component tests without Zig to prove deterministic presentation behavior.
- Run E2E with the real Zig service to prove the supported boundary.
- Run the production build, serve it, and repeat the proxy smoke.
- Verify test output and screenshots contain only synthetic foundation data.

## Test Strategy

Install exactly from the root lock:

```bash
npm ci
```

Run the package-local gates:

```bash
npm --workspace apps/web run lint
npm --workspace apps/web run typecheck
npm --workspace apps/web run test
npm --workspace apps/web run build
```

Run the independently diagnosable repository gates wired by WP01:

```bash
npm run contracts:check
npm run web:check
npm run http:smoke
```

Run the local real-boundary proof:

```bash
npm run dev:api
npm run dev:web
```

- Request `http://localhost:3000/api/v1/health` through the Next.js origin.
- Exercise both healthy and unavailable upstream states.
- Run Playwright against a production build in addition to local development.
- Use no live external service, remote font, real customer data, or private credential.
- Run `git diff --check` over package-owned paths before review.

## Definition of Done

- [ ] T042 pins the exact approved Next.js, React, TypeScript, and ESLint versions.
- [ ] Web install, lint, typecheck, component tests, and production build pass.
- [ ] T043 presents a quiet, typographically careful, accessible foundation shell.
- [ ] The shell is usable at 320 CSS pixels and 200% zoom without horizontal overflow.
- [ ] Keyboard focus, skip link, landmark, heading, and contrast checks pass.
- [ ] T044 consumes contract-derived types and preserves every exact wire string.
- [ ] Signed 64-bit boundaries never pass through JavaScript `number`.
- [ ] No authoritative business validation is duplicated in TypeScript.
- [ ] T045 proxies `/api/v1/*` server-side with no browser-visible Zig origin.
- [ ] Health success and structured failures preserve request correlation.
- [ ] Browser code makes no direct request to the Zig service origin.
- [ ] T046 covers component, accessibility, contract, proxy, and responsive behavior.
- [ ] Ready health p99 is below one second across 100 local requests.
- [ ] The production build passes the real proxy smoke.
- [ ] No business forms, charts, dashboards, or feature placeholders exist.
- [ ] No generated aggregate or generated client is committed.
- [ ] Only exact frontmatter-owned files changed.

## Risks & Mitigations

- **Generated types drift from contracts**: generate before typecheck and never hand-copy them.
- **Exact values become JS numbers**: keep canonical strings and test signed-64-bit bounds.
- **Next.js starts owning business rules**: restrict adapters to presentation and transport.
- **Browser bypasses proxy**: expose no public backend origin and inspect browser requests.
- **Proxy becomes open redirect/SSRF surface**: configure one server-only fixed origin.
- **Health response is stale**: use explicit no-store behavior for readiness presentation.
- **Safe errors lose correlation**: retain structured codes and `meta.request_id`.
- **Raw errors leak internals**: map transport failures and never render raw bodies/stacks.
- **Quiet palette loses contrast**: test normal, dark, and forced-color modes.
- **Long IDs break mobile layout**: allow safe wrapping and test 320-pixel width.
- **Health-only gate passes vacuously**: E2E the real proxy plus error mutation cases.

## Reviewer Guidance

- Verify every changed path matches WP09 ownership.
- Confirm exact dependency pins and that the root lock remains the single lock graph.
- Inspect server/client boundaries; no internal origin may enter a client bundle.
- Use browser network tools to confirm requests remain on the Next.js origin.
- Confirm proxy destinations cannot be influenced by request input.
- Compare committed client facades with WP03 generated contract types.
- Search for duplicated JSON schemas, regex validation, or business rules in web source.
- Inspect Money and revision handling for any `Number`, `parseInt`, or unsafe coercion.
- Exercise success, structured error, malformed response, timeout, and unavailable states.
- Inspect headings, landmarks, skip link, focus order, contrast, and error announcements.
- Review at 320 pixels, 200% zoom, dark preference, and forced colors.
- Run component tests independently, then run the real Next.js-to-Zig proxy E2E.
- Inspect production output for leaked backend origins and committed generated code.
- Reject approval if browser-direct Zig access or duplicated business validation appears.

## Activity Log

> Entries must remain chronological. Append new entries at the end.

- 2026-07-20T07:11:44Z – system – Prompt created for the pinned Next.js shell,
  accessible typographic foundation, exact contract client, same-origin proxy, and gates.

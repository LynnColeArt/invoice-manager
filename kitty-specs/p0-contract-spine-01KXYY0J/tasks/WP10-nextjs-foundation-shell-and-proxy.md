---
work_package_id: WP10
title: Next.js Foundation Shell and Proxy
dependencies:
- WP01
- WP02
- WP03
- WP08
- WP09
requirement_refs:
- FR-001
- FR-002
- FR-004
- FR-015
- NFR-001
- NFR-004
- NFR-007
- NFR-012
- C-002
- C-007
- C-009
tracker_refs: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch.
subtasks:
- T043
- T044
- T045
- T046
- T047
phase: Phase 3
assignee: ''
agent: "codex-wp10-cycle2-review"
history: []
agent_profile: reviewer-renata
authoritative_surface: apps/web/
create_intent:
- apps/web/src/app/layout.tsx
- apps/web/src/app/page.tsx
- apps/web/src/app/globals.css
- apps/web/src/app/api/v1/route.ts
- "apps/web/src/app/api/v1/[...path]/route.ts"
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
- apps/web/tests/foundation/proxy-fixture.mjs
- apps/web/tests/foundation/http-smoke.mjs
execution_mode: code_change
model: ''
owned_files:
- apps/web/src/app/layout.tsx
- apps/web/src/app/page.tsx
- apps/web/src/app/globals.css
- apps/web/src/app/api/v1/**
- apps/web/src/lib/api/**
- apps/web/src/lib/contracts/**
- apps/web/tests/foundation/**
role: reviewer
tags: []
task_type: implement
shell_pid: "1807838"
---

# Work Package Prompt: WP10 – Next.js Foundation Shell and Proxy

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `node-norris`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Verify WP01's immutable npm graph read-only, then build the smallest production-shaped
Next.js App Router shell that proves the real same-origin web-to-Zig boundary and consumes
generated contracts through their stable workspace export.

The shell is quiet, typographically careful, accessible, and foundation-only. It proves
health and structured failures without implementing invoice-management features.

## Context and Boundaries

- WP01 solely owns the root manifest, both workspace manifests, toolchain pins, scripts, and root lock.
- WP02 owns canonical wire values and cross-language fixtures.
- WP03 owns contract generation, the `tools/contracts` workspace export, and the sole
  generated TypeScript path `tools/contracts/.generated/typescript/v1/`.
- WP08 supplies the real Ready Zig health boundary and structured envelopes.
- WP09 owns runtime-neutral app-local configuration with no external API rewrite or eager origin
  read; consume the corrected configuration unchanged.
- WP10 treats all npm manifests and `package-lock.json` as immutable inputs.
- Every write remains inside the owned app paths in frontmatter.
- Do not edit contracts, generated outputs, app package/config files, Zig, CI, or mission state.
- Route missing root metadata/scripts to WP01, config/metadata faults to WP09, generated-export
  faults to WP03, and Zig health/readiness faults to WP08.
- Use App Router, server components by default, and an owned catch-all Route Handler for
  same-origin `/api/v1/*` browser access.
- Never expose the Zig origin through `NEXT_PUBLIC_*` or fetch it from browser code.
- Do not duplicate authorization, money, lifecycle, scheduling, invoice, or domain rules.
- P0 contains only health presentation and structured transport-error proof.
- Add no forms, records, tables, charts, dashboards, invoices, logos, or authentication.

## Branch Strategy

- **Strategy**: `wp_branch`
- **Planning base branch**: `feat/p0-contract-spine`
- **Merge target branch**: `feat/p0-contract-spine`
- Start with the governed implementation action:

```bash
spec-kitty agent action implement WP10 --agent codex
```

- Verify accepted WP01, WP02, WP03, WP08, and WP09 outputs are present first.
- Do not merge, rebase, tag, publish, or advance mission state from this package.

## Design Direction

- Prefer semantic HTML and native behavior over component abstractions.
- Use calm neutral surfaces, near-black text, restrained borders, and one accent.
- Avoid gradients, glass, oversized hero type, animations, and decorative noise.
- Use local/system fonts so clean builds perform no remote font request.
- Preserve strong contrast, visible focus, natural narrow-screen reflow, and safe wrapping.
- Keep messages concise and derived from the structured API envelope.

## Subtasks & Detailed Guidance

### Subtask T043 – Read-Only Immutable npm Graph Verification

**Purpose**

Verify that WP01's committed root manifest, both workspace manifests, and root lock already
form the complete reproducible npm graph without modifying any package metadata or lock bytes.

**Steps**

1. Confirm `package.json`, `tools/contracts/package.json`, `apps/web/package.json`, and `package-lock.json` are WP01's accepted bytes; never edit or regenerate them.
2. Use exactly Node 24.18.0 and npm 11.16.0 as pinned by WP01.
3. Hash all four immutable graph files and capture `git diff --name-only` before validation.
4. Run root `npm run prerequisites:check`, pinned `npm ci`, and `npm run verify:substrate`.
5. Confirm root `browser:install` resolves the locked web-workspace Playwright CLI and that bare
   `http:smoke` builds production web output before delegating to WP10's owned lifecycle harness.
6. Require both workspace identities, exact dependency versions, integrity hashes, resolved sources, and links to agree with the committed lock.
7. Reject ranges, private registries, local/sibling paths, floating Git references, missing integrity, undeclared dependencies, or app-local locks.
8. Re-hash all four files and require identical bytes plus zero metadata/lock diff.
9. Route any missing dependency, script, workspace edge, browser revision, or lock drift to WP01;
   do not repair it in WP10.

**Validation**

- `npm ci` and substrate checks resolve both workspaces from committed sources without sibling checkout access.
- The four immutable graph hashes and repository diff are identical before and after every T043 command.
- Any graph defect is recorded as an upstream WP01 integration request, with no attempted local fix.

### Subtask T044 – Accessible Typographic Foundation Shell

**Purpose**

Create a restrained WCAG 2.2 AA shell for future feature missions without pretending P0
already contains product workflows.

**Steps**

1. Create `layout.tsx` with valid metadata, language, and a visible skip link.
2. Use one page-level `main`, a logical heading hierarchy, and a server-component page.
3. Present a concise foundation heading, service status, and explanatory copy.
4. Render loading/unavailable status with text, not color or icon alone.
5. Make error summaries focusable and use restrained live announcements.
6. Create `globals.css` tokens for color, measure, spacing, and typography.
7. Use legible system stacks, at least 16px body text, and line height at least 1.5.
8. Provide visible `:focus-visible` outlines, a working keyboard skip link, logical focus order, and light/dark/forced-color support.
9. Require at least 4.5:1 normal-text and 3:1 large-text contrast.
10. Preserve content and operation at 200% zoom and 320 CSS pixels with no horizontal page overflow, including long IDs/error codes.
11. Render no fake navigation or placeholders for invoices, clients, projects, or reporting.
12. Add no hydration solely for visual decoration or static status.

**Validation**

- Test keyboard-only skip/focus order and landmark/heading structure.
- Test 320, 768, 1280, and 1920 CSS-pixel viewports plus 200% zoom with no content loss or horizontal overflow.
- Configure automated WCAG 2.2 AA checks to report zero serious or critical violations; verify exact contrast ratios and inspect dark/forced-color rendering.

### Subtask T045 – Stable Contract-Workspace Client and Handwritten Adapters

**Purpose**

Expose a narrow typed health client while consuming WP03 output only through its stable
`tools/contracts` workspace export and preserving exact wire values.

**Steps**

1. Import generated version-one types only from the package export declared by
   `tools/contracts/package.json`; never import a `.generated` filesystem path directly.
2. Treat `tools/contracts/.generated/typescript/v1/` as the sole generated TypeScript path.
3. WP03's literal `npm run contracts:generate` remains the only writer; invoke it before every web typecheck/build/check, but never edit, copy, or commit its output.
4. Keep `apps/web/src/lib/contracts/**` limited to handwritten presentation/transport adapters.
5. Do not paste generated OpenAPI types or create a second hand-maintained envelope schema.
6. Preserve signed 64-bit decimal strings; never coerce money/revisions through JS `number`.
7. Use `bigint` only behind an explicit checked display adapter, never for business arithmetic.
8. Preserve EntityId, LocalDate, UtcInstant, request IDs, and JSON Pointer fields exactly.
9. Create an injectable-fetch client with typed success and structured failure results.
10. Reject non-JSON, malformed envelope, redirect, timeout, and unexpected status safely.
11. Map transport categories to accessible copy without exposing raw bodies or internals.
12. Keep authoritative server codes/safe messages and do not infer success from HTTP status.

**Validation**

- Run literal `npm run contracts:generate` first, import only the workspace export, then typecheck from a clean checkout.
- Round-trip signed-64-bit minimum/maximum fixtures without unsafe numeric literals.
- Test success, structured error, fields, malformed JSON, redirects, and timeouts.
- Search `apps/web` for generated copies and direct `.generated` imports; require none.

### Subtask T046 – Owned App Router Health Boundary

**Purpose**

Implement the sole browser-to-Zig boundary as a WP10-owned App Router Route Handler. WP09 remains
runtime-neutral configuration; all fixed-origin, redirect, timeout, body, cache, header, and safe
failure policy is executable production behavior in this package.

**Steps**

1. Add named public same-origin E2E cases while the external rewrite and Route Handler are absent;
   record genuine `RED:` results through `http://localhost:3000/api/v1/*` before production code.
2. Implement sibling create-intent paths `apps/web/src/app/api/v1/route.ts` and quoted
   `apps/web/src/app/api/v1/[...path]/route.ts`, delegating shared route/transport policy to
   server-only code under `apps/web/src/lib/api/`. The sibling route owns `/api/v1` and
   `/api/v1/`; the catch-all owns health and all other segment-bearing variants that reach
   application routing.
3. Read and validate `INVOICE_MANAGER_API_ORIGIN` only during request handling. Accept one bare
   absolute HTTP(S) origin; never derive or override it from request headers, path, query, cookies,
   form data, browser environment, `NEXT_PUBLIC_*`, or network discovery.
4. P0 sends upstream I/O only for canonical `GET /api/v1/health` with no query parameters.
   Reject every other request that reaches either owned Route Handler locally with the canonical
   route/method error envelope before upstream I/O, including `/api/v1[/]`, health with a
   trailing slash, segment-bearing paths, query variants, encoded separators, and
   double-encoded traversal.
5. Test locked Next.js pre-routing behavior separately with redirect following disabled. Raw
   repeated slash and raw backslash receive framework 308 normalization, while single-encoded
   dot traversal receives framework 404 before either owned Route Handler. For each case prove
   the handler and upstream were not reached, no internal origin or cross-origin `Location` is
   disclosed, and no browser-visible request follows the normalized target. Do not claim a
   canonical application envelope for a request the framework intercepts.
6. Construct the upstream target only as the validated fixed origin plus constant
   `/api/v1/health`, then re-check origin identity before fetch.
7. Forward only an explicit safe request-header allowlist. Never forward `Host`, `Forwarded`,
   `X-Forwarded-*`, connection headers, cookies, authorization, destination/rewrite headers, or
   browser-provided origin-selection values.
8. Use `redirect: "manual"`, reject every 3xx without returning `Location`, and enforce a hard
   750 ms abort deadline with no retry.
9. Reject declared or streamed response bodies above 16 KiB and abort the read as soon as the cap
   is crossed; never buffer an unbounded body.
10. Use `cache: "no-store"`, `dynamic = "force-dynamic"`, and non-cacheable browser response
   headers so readiness cannot become stale.
11. Forward only bounded JSON that validates as the canonical generated health success/error
    envelope and expected status; preserve a valid upstream status and `meta.request_id`.
12. Map missing/invalid configuration, connection failure, timeout, redirect, oversized body,
    non-JSON, malformed envelope, and unexpected status to canonical `503 service_not_ready` with
    a fresh valid UUIDv7 request ID and no internal detail.
13. Reconstruct response headers from a safe allowlist. Never propagate `Set-Cookie`, `Location`,
    internal hosts, raw upstream bodies, paths, stack traces, or diagnostics.
14. Export explicit unsupported-method handlers from both owned routes so callers receive
    canonical 405 rather than framework HTML. Do not add CORS as a substitute for the
    same-origin architecture.
15. Cover destination/query/header/cookie/path manipulation, encoded traversal, the explicit
    framework-intercept matrix, redirect chains, SSRF sinks, origin leakage, timeout, oversize,
    malformed/non-JSON body, stopped Zig, and canonical safe failure through the public Next.js
    origin.
16. Use real local socket processes—not mocked fetch—for redirect, slow, oversized, malformed,
    and SSRF-sink cases, then separately prove the happy path with the real Ready WP08 service.
17. Append matching chronological `GREEN:` command/results without rewriting or reordering the
    prior evidence, and inspect browser requests/assets for no direct or disclosed Zig origin.

**Validation**

- Exercise the complete charter-mandated attacker-input, redirect, SSRF, origin-leak, deadline,
  body-limit, and safe-failure matrix with chronological red-before-production-before-green evidence.
- Use raw HTTP targets with redirect following disabled for the pre-routing matrix; distinguish
  owned canonical envelopes from locked framework 308/404 responses and prove zero upstream I/O
  in both cases.
- Verify every browser-visible request remains same-origin.
- Search production assets for the internal API origin and require no match.

### Subtask T047 – Component, E2E, Gate, and Diagnostic Performance Harness

**Purpose**

Make the shell and web-to-Zig boundary non-vacuous with independent component tests, real
WP08+WP10 production E2E, a reusable proxy/performance harness, and diagnostic NFR-007 evidence.

**Steps**

1. Test semantic shell structure, visible status, structured failures, and no fake features.
2. Run WCAG 2.2 AA automation with zero configured serious/critical violations plus exact contrast, skip-link, focus, label, heading, zoom, overflow, and live-region checks.
3. Test the handwritten client against WP02/WP03 valid/invalid fixtures and int64 boundaries.
4. Cover malformed envelope, non-JSON, unexpected status, redirect, timeout, body overflow, and
   unavailability.
5. Implement `http-smoke.mjs` as the sole deterministic child-process orchestrator. For the real
   phase, create a temporary database, start WP08 Zig on loopback port `0`, parse its
   `[api:ready] listening port=N` line, and spawn the Playwright command with the resulting fixed
   server-only origin so its configured production Next.js child inherits it.
6. Implement `proxy-fixture.mjs` as a real local adversarial upstream. Run separate bounded phases
   for redirect, slow, oversized, non-JSON/malformed, and origin-leak behavior; do not route the
   canonical health proof through this fixture.
7. On success, failure, signal, startup timeout, or test timeout, terminate every child, remove the
   temporary database directory, and prove all bound ports are released. Never reuse an existing
   Next.js or Zig process.
8. Request `http://localhost:3000/api/v1/health`; never substitute a mocked or direct-Zig path.
   Also exercise the sibling base route, trailing slash, encoded, and locked pre-routing raw-path
   matrix without following redirects.
9. Assert canonical data/request metadata, safe failure envelopes for handler-owned cases,
   documented framework rejection for pre-routing cases, and no browser request to the
   Zig/fixture origin.
10. Test narrow/mobile, desktop, 200% zoom, dark preference, and 320px overflow.
11. Ensure bare `web:check` runs format, lint, strict types, component tests, and production build
    with Zig stopped and `INVOICE_MANAGER_API_ORIGIN` unset.
12. Ensure bare `http:smoke` generates contracts, builds production Next.js, provisions the exact
    locked Playwright Chromium, runs the full lifecycle, and shuts every process down without any
    caller-supplied environment setup. System-Chrome fallback is forbidden.
13. Supply only a reusable NFR-007 production proxy/performance harness and diagnostic evidence for WP12's final reference run.
14. Record runner, tools, exact candidate commit, and monotonic timing boundaries.
15. After Ready, issue 10 sequential warmups and discard them from measurement.
16. Issue exactly 100 sequential diagnostic NFR-007 requests with no concurrency or discarded samples.
17. Time each request through complete same-origin response-body read and count every invalid response as failure.
18. Sort durations, report min/median/max and nearest-rank p99 as one-based sample 99, including slow/invalid counts; diagnose whether p99 is at most 1,000 ms.
19. Keep component tests deterministic and reserve live-boundary assertions for E2E.
20. Do not claim final NFR-001 or NFR-008 acceptance; WP12 owns the clean reference bootstrap/runtime acceptance run.

**Validation**

- Run component tests without Zig, then real E2E against production Next.js plus WP08 Zig.
- Repeat the same-origin smoke after the production build and inspect browser traffic.
- Confirm a clean locked production build leaves WP09's accepted `next.config.ts`,
  `tsconfig.json`, and `next-env.d.ts` byte-identical to their T060 hashes.
- Reject undersized, concurrent, mocked, direct-Zig, non-monotonic, or cherry-picked diagnostic evidence.
- Prove the NFR-007 harness exposes the diagnostic controls and measurements WP12 needs for final NFR-001/NFR-008 acceptance.
- Require screenshots/logs to contain only synthetic foundation data.

## Test Strategy

Verify and install from WP01's immutable root graph:

```bash
npm run prerequisites:check
npm ci
npm run verify:substrate
npm run browser:install
```

Run package and repository gates without modifying package metadata or configuration:

```bash
npm --workspace apps/web run lint
npm run contracts:generate
npm --workspace apps/web run typecheck
npm --workspace apps/web run test
npm run contracts:generate
npm --workspace apps/web run build
npm run contracts:check
npm run contracts:generate
npm run web:check
npm run contracts:generate
npm run http:smoke
```

The literal materializer must complete immediately before each web typecheck,
build, or aggregate check; a stale prior output does not satisfy this ordering.

- Run Playwright through `http-smoke.mjs` against production Next.js, real WP08 Zig, and the
  separately identified adversarial socket phases.
- Use no live external service, remote font, customer data, or private credential.
- Run `git diff --check` over every package-owned change before review.

## Definition of Done

- [ ] T043 verifies WP01's root manifest, both workspace manifests, and lock read-only with pinned npm.
- [ ] `npm ci`/substrate checks leave all npm metadata and lock bytes unchanged; graph defects route to WP01.
- [ ] T044 provides an accessible, typographically careful, feature-free foundation shell.
- [ ] WCAG 2.2 AA checks report zero configured serious/critical violations, 4.5:1 normal and 3:1 large-text contrast, keyboard skip/focus, 200% zoom, and 320px without overflow.
- [ ] T045 imports generated types only through the stable `tools/contracts` export.
- [ ] All app contract files are handwritten adapters; WP03 remains sole generated writer.
- [ ] Signed 64-bit values never pass through JavaScript `number`.
- [ ] T046 proves both owned fixed-origin App Router routes, canonical safe failures for every
  handler-visible invalid request, locked framework-safe rejection for pre-routing raw paths,
  bounded redirect/deadline/body/header/cache policy, and no leaked/direct Zig origin.
- [ ] Charter security cases record chronological public-boundary red before production changes and matching green.
- [ ] T047 passes component, accessibility, contract, production E2E/adversarial socket phases,
  exact browser provisioning, bounded cleanup, and focused bare gates.
- [ ] WP10 supplies the real proxy/performance harness and records diagnostic NFR-007 sample-99 evidence.
- [ ] WP12 remains the sole final NFR-001/NFR-008 reference acceptance owner.
- [ ] Every write is inside the declared app-owned paths.
- [ ] No business feature, generated copy, config edit, or out-of-scope path is present.

## Risks & Mitigations

- **Immutable graph is incomplete**: fail read-only verification and route the gap to WP01.
- **Generated types drift or gain a second writer**: import one stable WP03 workspace export.
- **Exact values become JS numbers**: preserve canonical strings and test int64 boundaries.
- **Next.js starts owning business rules**: keep adapters presentation/transport-only.
- **Browser bypasses handler or leaks origin**: inspect network and production assets.
- **Locked Next intercepts a raw path before the handler**: test exact 308/404 behavior without
  redirect following and prove zero handler/upstream I/O or internal-origin disclosure.
- **Handler becomes SSRF/open redirect or buffers forever**: accept one server-only fixed origin,
  use constant health routing, allowlist headers, reject manual redirects, and enforce hard
  deadline/body caps through real socket tests.
- **Harness leaks processes or ports**: own one bounded orchestrator and prove teardown on every
  success, failure, timeout, and signal path.
- **Performance passes vacuously**: enforce real processes and exact NFR-007 diagnostic sample protocol while reserving final acceptance for WP12.
- **Quiet palette loses contrast**: test normal, dark, forced-color, keyboard, and zoom modes.

## Reviewer Guidance

- Treat committed `tasks.md`, committed prompt frontmatter, and committed finalized lane metadata as reviewer authority; `wps.yaml` is not the acceptance authority.
- Confirm T043 used pinned npm and left the root manifest, both workspace manifests, and lock byte-identical.
- Verify every changed path matches the app-owned patterns and no WP09 config was edited.
- Confirm both the sibling base and catch-all Route Handler paths are present under their declared
  directory glob and the root/config/package/lock/Zig surfaces are unchanged.
- Confirm imports use the `tools/contracts` package export, not `.generated` or copied types.
- Search handwritten adapters for duplicated schemas, regex validation, business rules, `Number`,
  `parseInt`, unsafe money/revision coercion, and raw upstream rendering.
- Use browser tools to confirm same-origin traffic and no internal origin disclosure; replay the
  real redirect, slow, oversized, malformed, SSRF-sink, and stopped-service sockets.
- Replay raw repeated-slash, raw-backslash, and single-encoded-dot targets with redirects
  disabled; require documented locked framework response plus zero handler/upstream activity,
  not a fabricated canonical envelope.
- Verify charter security cases are chronological public-boundary red-before-production-before-green.
- Exercise exact WCAG 2.2 AA/responsive/error states and the real WP08+WP10 production E2E.
- Recalculate diagnostic sample 99 and confirm WP10 supplies only NFR-007 harness/diagnostic evidence and does not claim WP12's final NFR-001/NFR-008 acceptance.
- Reject approval if profile, immutable-graph ownership, package ownership, or evidence authority drifts.

## Activity Log

> Entries must remain chronological. Append new entries at the end.

- 2026-07-20T07:11:44Z – system – WP10 prompt adapted from the former web package,
  split into immutable npm-graph verification, shell, stable contract client, real proxy,
  and diagnostic E2E/performance-harness evidence.
- 2026-07-21T14:46:43Z – codex – Corrective task design after blocked analysis: WP10 owns the
  fixed-origin App Router handler and complete real-process/adversarial lifecycle; WP09 supplies
  runtime-neutral configuration and WP01 supplies exact browser provisioning.
- 2026-07-21T16:20:15Z – codex-wp10-implementation – shell_pid=1807838 – Assigned agent via action command
- 2026-07-21T16:25:45Z – codex-wp10-implementation – shell_pid=1807838 – RED: T044-SHELL-01; command PATH=/home/lynn/.nvm/versions/node/v24.18.0/bin:$PATH npm run test --workspace @invoice-manager/web -- --run tests/foundation/shell.test.tsx tests/foundation/accessibility.test.tsx; expected semantic foundation shell and accessibility contract; actual both suites failed to resolve absent ../../src/app/page (exit 1), before production shell source.
- 2026-07-21T16:27:23Z – codex-wp10-implementation – shell_pid=1807838 – GREEN: T044-SHELL-01; same focused Vitest command now passes 2 files/4 tests after layout/page/CSS implementation. BUILD: Node 24.18.0; literal npm run contracts:generate then clean rm -rf apps/web/.next and npm run build --workspace @invoice-manager/web passed; accepted WP09 SHA-256 values remained next.config a6fbd459..., tsconfig edd7c53f..., next-env 7b550dda... with zero diff.
- 2026-07-21T16:28:38Z – codex-wp10-implementation – shell_pid=1807838 – RED: T045-CONTRACT-01; focused contract-client Vitest command expected stable-export typed client, exact envelope refinement, int64 boundary preservation, and safe transport mapping; actual suite failed to resolve absent src/lib/api/client before production adapter source (exit 1).
- 2026-07-21T16:30:10Z – codex-wp10-implementation – shell_pid=1807838 – GREEN: T045-CONTRACT-01; same focused contract-client command passes 17 tests: stable @invoice-manager/contracts/v1 type imports, exact closed health envelope refinement, canonical int64 min/max and unsafe boundaries without Number/parseInt, checked bigint display adapter, and safe malformed/redirect/timeout/oversize mapping.
- 2026-07-21T16:32:26Z – codex-wp10-implementation – shell_pid=1807838 – RED: T046-PUBLIC-01; isolated network namespace preserved locked http://localhost:3000 while host port was occupied; command unshare -Urn ... npm run test:e2e --workspace @invoice-manager/web -- --grep PUBLIC-RED-BOUNDARY; expected canonical public 503 for stopped origin; actual framework 404 before absent Route Handler (exit 1), with production Next and redirect following disabled.
- 2026-07-21T16:51:09Z – codex-wp10-implementation – shell_pid=1807838 – GREEN: T046-PUBLIC-01/T046-UPSTREAM-01/T046-PREROUTE-01 and T047-SHELL-01/T047-NFR007-01; literal bare npm run http:smoke passed under Node 24 with private localhost:3000, real ReleaseSafe WP08 Ready, stopped Zig, missing/invalid origins, canonical 503, redirect chain, hard deadline/abort, declared+streamed oversize, non-JSON/exact media spoof/malformed JSON+envelope/unexpected status/header-cookie-origin leak fixtures, same-origin axe/responsive/contrast checks, and released ports/temp DB. Diagnostic: 10 discarded sequential warmups + exactly 100 complete-body sequential samples, all valid; min 2.202ms, median 2.417ms, sample-99 p99 8.336ms, max 9.721ms, slow 0, invalid 0; ordered sample list emitted. WP09 and four immutable graph hashes remained exact.
- 2026-07-21T16:54:06Z – codex-wp10-implementation – shell_pid=1807838 – GATE RED (upstream): clean bare npm run web:check after removing .next passed format/lint, then failed TS2882 at accepted next-env.d.ts side-effect import ./\.next/types/routes.d.ts because the WP01-owned script runs typecheck before Next build/typegen. Routed to WP09/WP01; WP10 did not edit configuration or metadata.
- 2026-07-21T17:06:57Z – codex-wp10-implementation – shell_pid=1807838 – T043 ATTESTATION: before WP10 production source, Node 24.18.0/npm 11.16.0 ran prerequisites:check, npm ci (499 packages audited, 0 vulnerabilities), verify:substrate, locked Playwright Chromium/headless-shell revision 1228 install, and literal contracts:generate. Accepted WP01 graph hashes were root 816264f8..., contracts ee7fcc2f..., web f31c4513..., lock 6ea2ffb8... before and after with zero metadata diff; no WP10 manifest/config write.
- 2026-07-21T17:25:44Z – codex-wp10-implementation – shell_pid=1807838 – GREEN final evidence on exact WP10 commit 170d25364b9d2055f1d2d3f68f73d84436295ce9: literal bare npm run http:smoke passed production build, real Zig Ready, stopped/missing/invalid config, canonical 503, redirect, slow/slow-non-json, declared/streamed oversize, non-JSON, media-type spoof, malformed JSON/envelope, unexpected status, header leak, live same-origin shell, Axe/responsive/dark/forced-color checks, and failure/timeout/signal cleanup probes. Candidate index tree 82ba874b30a55652bd391bce8eeb881fe9616ad0; tracked_clean=true. NFR-007 100 sequential complete-body samples after 10 warmups: min=2.063ms median=2.373ms p99_sample_99=7.735ms max=8.536ms slow=0 invalid=0. Clean no-.next bare npm run web:check also passed format, lint, typecheck, 24 Vitest tests, and production build after approved WP09 correction; config hashes package=816264f8 tools=ee7fcc2f web=f31c4513 lock=6ea2ffb8 next=a6fbd459 tsconfig=c36224bb next-env=7b550dda.
- 2026-07-21T17:26:01Z – codex-wp10-implementation – shell_pid=1807838 – Ready for independent review: exact commit 170d253; clean web:check and full http:smoke green
- 2026-07-21T17:27:05Z – codex-wp10-independent-review – shell_pid=1807838 – Started review via action command
- 2026-07-21T17:38:21Z – user – shell_pid=1807838 – Moved to planned
- 2026-07-21T17:43:37Z – codex-wp10-dead-facade-fix – shell_pid=1807838 – Started implementation via action command
- 2026-07-21T17:48:39Z – codex-wp10-dead-facade-fix – shell_pid=1807838 – REVIEW CYCLE 1 CORRECTION GREEN under authority d19a3df: targeted call-site search proved zero imports/references to apps/web/src/lib/contracts/index.ts, then exact commit e8b055c753f600bc4db4919a1877351c913afe69 (tree 35ed9474202c5280bda8a9dc2b9e6370573c8eb9) deleted only that unused facade; no replacement or import edits. Node 24.18.0/npm 11.16.0 clean npm ci added 496/audited 499 with 0 vulnerabilities. Clean no-.next bare npm run web:check passed format, lint, strict typecheck, 24 Vitest tests, and production build. Full bare npm run http:smoke passed exact candidate with tracked_clean=true across real Ready, stopped/missing/invalid config, all hostile sockets, live accessibility, and failure/timeout/signal cleanup. NFR-007: 100 sequential complete-body samples after 10 warmups, min=2.130ms median=2.437ms p99_sample_99=8.782ms max=9.730ms slow=0 invalid=0. Immutable hashes exact: package=816264f8 tools=ee7fcc2f web=f31c4513 lock=6ea2ffb8 next=a6fbd459 tsconfig=c36224bb next-env=7b550dda. Scope/direct-generated-import/unsafe-number scans and git diff check passed; diff-scoped ruff: no changed Python files, exit 0. Generated/transient outputs removed; lane clean.
- 2026-07-21T17:48:48Z – codex-wp10-dead-facade-fix – shell_pid=1807838 – Review cycle 1 corrected: exact commit e8b055c, tree 35ed947, one-file dead-facade deletion; clean web:check and full http:smoke green
- 2026-07-21T17:49:33Z – codex-wp10-cycle2-review – shell_pid=1807838 – Started review via action command
- 2026-07-21T17:54:25Z – user – shell_pid=1807838 – Review passed: cycle 2 closes the sole dead-facade blocker at e8b055c/tree 35ed947; independent clean web:check passed and exact-candidate full-smoke evidence was verified; approval artifact 5babcc2

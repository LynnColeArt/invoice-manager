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
agent: codex
history: []
agent_profile: frontend-freddy
authoritative_surface: apps/web/
create_intent:
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

# Work Package Prompt: WP10 – Next.js Foundation Shell and Proxy

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `frontend-freddy`
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
- WP09 owns app-local configuration; consume it unchanged.
- WP10 treats all npm manifests and `package-lock.json` as immutable inputs.
- Every write remains inside the owned app paths in frontmatter.
- Do not edit contracts, generated outputs, app package/config files, Zig, CI, or mission state.
- Route missing root metadata/scripts to WP01, config/metadata faults to WP09, generated-export
  faults to WP03, and Zig health/readiness faults to WP08.
- Use App Router, server components by default, and same-origin `/api/v1/*` browser access.
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
5. Require both workspace identities, exact dependency versions, integrity hashes, resolved sources, and links to agree with the committed lock.
6. Reject ranges, private registries, local/sibling paths, floating Git references, missing integrity, undeclared dependencies, or app-local locks.
7. Re-hash all four files and require identical bytes plus zero metadata/lock diff.
8. Route any missing dependency, script, workspace edge, or lock drift to WP01; do not repair it in WP10.

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

### Subtask T046 – Real Server-Side Health Proxy

**Purpose**

Use WP09's accepted server-only proxy configuration and WP08's real service so the browser
reaches `/api/v1/health` only through the Next.js origin.

**Steps**

1. Consume WP09's `/api/v1/:path*` server-side proxy configuration unchanged.
2. Route a missing or unsafe proxy/config seam to WP09; do not edit config from WP10.
3. Read the fixed Zig origin only through server-only code/configuration.
4. Before each production proxy change, add a failing public same-origin E2E case through `http://localhost:3000/api/v1/*`; private helpers and mocked transports do not count.
5. Cover attacker-controlled destination, forwarding/header, query, cookie, and route inputs; redirect chains; SSRF targets; origin leakage; timeout; and safe-failure behavior.
6. Append chronological `RED:` evidence with case ID, exact `npm run http:smoke` command, expected failure, and observed failure before changing production code.
7. Only then implement the fixed-origin boundary and append the matching `GREEN:` command/result without rewriting or reordering evidence.
8. Reject all browser-controlled destination inputs while preserving only allowed path/query semantics; prevent open redirects and SSRF.
9. Do not add CORS as a substitute for the same-origin architecture.
10. Create server-only API access and request `GET /api/v1/health` semantics.
11. Bound duration, reject unexpected-origin redirects, and disable stale readiness caching.
12. Preserve upstream status, structured envelope, and `meta.request_id`.
13. Render safe correlated failures without stacks, internal hosts, paths, origins, or raw bodies.
14. Start the real WP08 Zig service, wait for Ready, and start production Next.js.
15. Request `http://localhost:3000/api/v1/health` and validate the canonical response.
16. Stop Zig and require the designed accessible unavailable state.
17. Inspect browser requests/assets and require no direct or disclosed Zig origin.

**Validation**

- Exercise the complete charter-mandated attacker-input, redirect, SSRF, origin-leak, timeout, and safe-failure matrix with chronological red-before-production-before-green evidence.
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
4. Cover malformed envelope, non-JSON, unexpected status, redirect, timeout, and unavailability.
5. Run Playwright with the real Ready WP08 Zig process and WP10 production Next.js process.
6. Request `http://localhost:3000/api/v1/health`; never substitute a mocked or direct-Zig path.
7. Assert canonical data/request metadata and no browser request to the Zig origin.
8. Test narrow/mobile, desktop, 200% zoom, dark preference, and 320px overflow.
9. Ensure `web:check` runs format, lint, strict types, component tests, and production build.
10. Ensure `http:smoke` runs this same real production same-origin path.
11. Supply a reusable production proxy/performance harness for WP11's final reference run.
12. Record runner, tools, exact candidate commit, and monotonic timing boundaries.
13. After Ready, issue 10 sequential warmups and discard them from measurement.
14. Issue exactly 100 sequential diagnostic NFR-007 requests with no concurrency or discarded samples.
15. Time each request through complete same-origin response-body read and count every invalid response as failure.
16. Sort durations, report min/median/max and nearest-rank p99 as one-based sample 99, including slow/invalid counts; diagnose whether p99 is at most 1,000 ms.
17. Keep component tests deterministic and reserve live-boundary assertions for E2E.
18. Do not claim final NFR-001 or NFR-008 acceptance; WP11 owns the clean reference bootstrap/runtime acceptance run.

**Validation**

- Run component tests without Zig, then real E2E against production Next.js plus WP08 Zig.
- Repeat the same-origin smoke after the production build and inspect browser traffic.
- Reject undersized, concurrent, mocked, direct-Zig, non-monotonic, or cherry-picked diagnostic evidence.
- Prove the harness exposes the controls and measurements WP11 needs for final NFR-001/NFR-008 acceptance.
- Require screenshots/logs to contain only synthetic foundation data.

## Test Strategy

Verify and install from WP01's immutable root graph:

```bash
npm run prerequisites:check
npm ci
npm run verify:substrate
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

- Run Playwright against production Next.js and real WP08 Zig.
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
- [ ] T046 proves server-side same-origin proxying with no leaked/direct Zig origin.
- [ ] Charter security cases record chronological public-boundary red before production changes and matching green.
- [ ] T047 passes component, accessibility, contract, production E2E, and focused gates.
- [ ] WP10 supplies the real proxy/performance harness and records diagnostic NFR-007 sample-99 evidence.
- [ ] WP11 remains the sole final NFR-001/NFR-008 reference acceptance owner.
- [ ] Every write is inside the declared app-owned paths.
- [ ] No business feature, generated copy, config edit, or out-of-scope path is present.

## Risks & Mitigations

- **Immutable graph is incomplete**: fail read-only verification and route the gap to WP01.
- **Generated types drift or gain a second writer**: import one stable WP03 workspace export.
- **Exact values become JS numbers**: preserve canonical strings and test int64 boundaries.
- **Next.js starts owning business rules**: keep adapters presentation/transport-only.
- **Browser bypasses proxy or leaks origin**: inspect network and production assets.
- **Proxy becomes SSRF/open redirect**: accept one server-only fixed origin, never request input.
- **Performance passes vacuously**: enforce real processes and exact diagnostic sample protocol while reserving final acceptance for WP11.
- **Quiet palette loses contrast**: test normal, dark, forced-color, keyboard, and zoom modes.

## Reviewer Guidance

- Treat committed `tasks.md`, committed prompt frontmatter, and committed finalized lane metadata as reviewer authority; `wps.yaml` is not the acceptance authority.
- Confirm T043 used pinned npm and left the root manifest, both workspace manifests, and lock byte-identical.
- Verify every changed path matches the app-owned patterns and no WP09 config was edited.
- Confirm imports use the `tools/contracts` package export, not `.generated` or copied types.
- Search handwritten adapters for duplicated schemas, regex validation, business rules, `Number`,
  `parseInt`, unsafe money/revision coercion, and raw upstream rendering.
- Use browser tools to confirm same-origin traffic and no internal origin disclosure.
- Verify charter security cases are chronological public-boundary red-before-production-before-green.
- Exercise exact WCAG 2.2 AA/responsive/error states and the real WP08+WP10 production E2E.
- Recalculate diagnostic sample 99 and confirm WP10 does not claim WP11's final NFR-001/NFR-008 acceptance.
- Reject approval if profile, immutable-graph ownership, package ownership, or evidence authority drifts.

## Activity Log

> Entries must remain chronological. Append new entries at the end.

- 2026-07-20T07:11:44Z – system – WP10 prompt adapted from the former web package,
  split into immutable npm-graph verification, shell, stable contract client, real proxy,
  and diagnostic E2E/performance-harness evidence.

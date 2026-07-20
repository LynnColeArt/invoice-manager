---
work_package_id: WP10
title: Next.js Foundation Shell, Lock, and Proxy
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
scope: codebase-wide
history: []
agent_profile: frontend-freddy
authoritative_surface: .
create_intent:
- package-lock.json
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
- package-lock.json
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

# Work Package Prompt: WP10 – Next.js Foundation Shell, Lock, and Proxy

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `frontend-freddy`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Perform the one serialized post-metadata root-lock integration, then build the smallest
production-shaped Next.js App Router shell that proves the real same-origin web-to-Zig
boundary and consumes generated contracts through their stable workspace export.

The shell is quiet, typographically careful, accessible, and foundation-only. It proves
health and structured failures without implementing invoice-management features.

## Context and Boundaries

- WP01 owns root workspace metadata, toolchain pins, scripts, and the initial bootstrap lock.
- WP02 owns canonical wire values and cross-language fixtures.
- WP03 owns contract generation, the `tools/contracts` workspace export, and the sole
  generated TypeScript path `tools/contracts/.generated/typescript/v1/`.
- WP08 supplies the real Ready Zig health boundary and structured envelopes.
- WP09 owns `apps/web/package.json` and app-local configuration; consume them unchanged.
- WP10 is the sole later codebase-wide root-lock integration steward.
- Only T043 may write the root lock; no task may edit root `package.json`.
- Every non-lock write remains inside the owned app paths in frontmatter.
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

### Subtask T043 – Serialized Root Lock Reconciliation

**Purpose**

Regenerate only the root `package-lock.json` after WP09 web metadata and WP03 contract-tool
workspace metadata are present, producing one authoritative reproducible npm graph.

**Steps**

1. Confirm root `package.json` is WP01's accepted version and do not edit it.
2. Confirm WP09's accepted `apps/web/package.json` and configurations are unchanged.
3. Confirm WP03's accepted `tools/contracts/package.json` stable export is present.
4. Use exactly Node 24.18.0 and npm 11.16.0 as pinned by WP01.
5. Begin from WP01's initial root lock; do not create an app-local lock.
6. Run the pinned npm's deterministic package-lock-only regeneration from repository root.
7. Permit exactly one write: root `package-lock.json`.
8. Ensure the lock includes both `apps/web` and `tools/contracts` workspace identities.
9. Verify exact WP09 dependency versions, integrity hashes, resolved sources, and workspace links.
10. Reject ranges introduced by lock reconciliation, private registries, local/sibling paths,
    floating Git references, missing integrity, or unrelated dependency churn.
11. Inspect the semantic lock diff and explain every changed package edge.
12. Restore and fail on any unexpected file write or root metadata mutation.
13. Run `npm ci` from the reconciled lock and require no subsequent lock diff.

**Validation**

- Verify `git diff --name-only` for T043 names only `package-lock.json`.
- Re-run lock-only generation and require byte-identical output.
- Confirm `npm ci` resolves the WP03 tool workspace and WP09 web workspace offline from locks
  and committed sources after normal npm cache population; no sibling checkout is allowed.

### Subtask T044 – Accessible Typographic Foundation Shell

**Purpose**

Create a restrained, readable, keyboard-accessible shell for future feature missions without
pretending P0 already contains product workflows.

**Steps**

1. Create `layout.tsx` with valid metadata, language, and a visible skip link.
2. Use one page-level `main`, a logical heading hierarchy, and a server-component page.
3. Present a concise foundation heading, service status, and explanatory copy.
4. Render loading/unavailable status with text, not color or icon alone.
5. Make error summaries focusable and use restrained live announcements.
6. Create `globals.css` tokens for color, measure, spacing, and typography.
7. Use legible system stacks, at least 16px body text, and line height at least 1.5.
8. Provide high-contrast `:focus-visible` outlines and light/dark/forced-color support.
9. Preserve usability at 320 CSS pixels, 200% zoom, and long request IDs/error codes.
10. Use responsive spacing only with predictable bounds and no horizontal page overflow.
11. Render no fake navigation or placeholders for invoices, clients, projects, or reporting.
12. Add no hydration solely for visual decoration or static status.

**Validation**

- Test keyboard-only skip/focus order and landmark/heading structure.
- Test 320, 768, 1280, and 1920 CSS-pixel viewports plus 200% zoom.
- Run automated accessibility checks and inspect dark/forced-color rendering.

### Subtask T045 – Stable Contract-Workspace Client and Handwritten Adapters

**Purpose**

Expose a narrow typed health client while consuming WP03 output only through its stable
`tools/contracts` workspace export and preserving exact wire values.

**Steps**

1. Import generated version-one types only from the package export declared by
   `tools/contracts/package.json`; never import a `.generated` filesystem path directly.
2. Treat `tools/contracts/.generated/typescript/v1/` as the sole generated TypeScript path.
3. WP03 is its only writer; WP10 never generates, edits, copies, or commits those files.
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

- Generate through WP03, import only the workspace export, then typecheck from a clean checkout.
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
4. Reject browser headers, queries, cookies, or route values as destination inputs.
5. Preserve path/query semantics while preventing open redirect and SSRF behavior.
6. Do not add CORS as a substitute for the same-origin architecture.
7. Create server-only API access and request `GET /api/v1/health` semantics.
8. Bound duration, reject unexpected-origin redirects, and disable stale readiness caching.
9. Preserve upstream status, structured envelope, and `meta.request_id`.
10. Render safe correlated failures without stacks, internal hosts, paths, or raw bodies.
11. Start the real WP08 Zig service, wait for Ready, and start production Next.js.
12. Request `http://localhost:3000/api/v1/health` and validate the canonical response.
13. Stop Zig and require the designed accessible unavailable state.
14. Inspect browser requests/assets and require no direct or disclosed Zig origin.

**Validation**

- Exercise healthy, structured-error, timeout, redirect, and unavailable upstream states.
- Verify every browser-visible request remains same-origin.
- Search production assets for the internal API origin and require no match.

### Subtask T047 – Component, E2E, Gate, and Reference Performance Proof

**Purpose**

Make the shell and web-to-Zig boundary non-vacuous with independent component tests and real
WP08+WP10 production E2E, including the exact NFR-001/NFR-007 reference protocol.

**Steps**

1. Test semantic shell structure, visible status, structured failures, and no fake features.
2. Run automated accessibility plus skip-link, focus, label, heading, and live-region checks.
3. Test the handwritten client against WP02/WP03 valid/invalid fixtures and int64 boundaries.
4. Cover malformed envelope, non-JSON, unexpected status, redirect, timeout, and unavailability.
5. Run Playwright with the real Ready WP08 Zig process and WP10 production Next.js process.
6. Request `http://localhost:3000/api/v1/health`; never substitute a mocked or direct-Zig path.
7. Assert canonical data/request metadata and no browser request to the Zig origin.
8. Test narrow/mobile, desktop, 200% zoom, dark preference, and 320px overflow.
9. Ensure `web:check` runs format, lint, strict types, component tests, and production build.
10. Ensure `http:smoke` runs this same real production same-origin path.
11. Use Linux x86_64 with at least 4 logical CPUs and at least 16 GiB RAM.
12. Record runner image, kernel, CPU/memory, filesystem, tools, and exact candidate commit.
13. Start measured runs from a clean checkout with empty dependency/build caches as specified.
14. Use monotonic timers for the full NFR-001 boundary and every health request.
15. Start NFR-001 immediately before bootstrap; include dependency resolution, builds, required
    validation, startup, and same-origin smoke; exclude checkout and prerequisite installation.
16. Require NFR-001 to complete within 15 minutes.
17. After Ready, issue 10 sequential warmups and discard them from measurement.
18. Issue exactly 100 sequential measured requests with no concurrency or discarded samples.
19. Start each sample before send and stop after the complete response body is read.
20. Require every response valid, sort monotonic durations ascending, and define nearest-rank
    p99 as one-based sample 99; require it at or below 1,000 ms.
21. Record commands, min/median/p99/max, invalid/slow counts, and total wall time.
22. Keep component tests deterministic and reserve live-boundary assertions for E2E.

**Validation**

- Run component tests without Zig, then real E2E against production Next.js plus WP08 Zig.
- Repeat the same-origin smoke after the production build and inspect browser traffic.
- Reject undersized, cached, concurrent, mocked, direct-Zig, non-monotonic, or cherry-picked
  performance evidence.
- Require screenshots/logs to contain only synthetic foundation data.

## Test Strategy

Install from the reconciled root lock:

```bash
npm ci
```

Run package and repository gates without modifying package metadata or configuration:

```bash
npm --workspace apps/web run lint
npm --workspace apps/web run typecheck
npm --workspace apps/web run test
npm --workspace apps/web run build
npm run contracts:check
npm run web:check
npm run http:smoke
```

- Run Playwright against production Next.js and real WP08 Zig.
- Use no live external service, remote font, customer data, or private credential.
- Run `git diff --check` over every package-owned change before review.

## Definition of Done

- [ ] T043 alone reconciles root `package-lock.json` with pinned npm and expected diff.
- [ ] Root `package.json`, WP09 package/config, and WP03 workspace metadata remain unchanged.
- [ ] The lock contains both WP09 web and WP03 contract-tool workspaces and passes `npm ci`.
- [ ] T044 provides an accessible, typographically careful, feature-free foundation shell.
- [ ] Shell works at 320px and 200% zoom with keyboard, contrast, and overflow checks.
- [ ] T045 imports generated types only through the stable `tools/contracts` export.
- [ ] All app contract files are handwritten adapters; WP03 remains sole generated writer.
- [ ] Signed 64-bit values never pass through JavaScript `number`.
- [ ] T046 proves server-side same-origin proxying with no leaked/direct Zig origin.
- [ ] T047 passes component, accessibility, contract, production E2E, and focused gates.
- [ ] Real WP08+WP10 health p99 is sample 99 of exactly 100 and no more than one second.
- [ ] Reference bootstrap completes within 15 minutes under the specified empty-cache protocol.
- [ ] Every non-lock write is inside the declared app-owned paths.
- [ ] No business feature, generated copy, config edit, or out-of-scope path is present.

## Risks & Mitigations

- **Lock reconciliation churns unrelated dependencies**: inspect every semantic edge and fail.
- **Codebase-wide scope expands writes**: T043 alone owns the lock; all else stays app-local.
- **Generated types drift or gain a second writer**: import one stable WP03 workspace export.
- **Exact values become JS numbers**: preserve canonical strings and test int64 boundaries.
- **Next.js starts owning business rules**: keep adapters presentation/transport-only.
- **Browser bypasses proxy or leaks origin**: inspect network and production assets.
- **Proxy becomes SSRF/open redirect**: accept one server-only fixed origin, never request input.
- **Performance passes vacuously**: enforce real processes and exact environment/sample protocol.
- **Quiet palette loses contrast**: test normal, dark, forced-color, keyboard, and zoom modes.

## Reviewer Guidance

- Compare all allowed WPMetadata fields with WP10 in `wps.yaml`.
- Confirm T043 changed only root lock, used pinned npm, and integrated both workspace packages.
- Inspect the lock diff for unexplained churn, mutable inputs, private/local sources, or bad pins.
- Verify every non-lock path matches the app-owned patterns and no WP09 config was edited.
- Confirm imports use the `tools/contracts` package export, not `.generated` or copied types.
- Search handwritten adapters for duplicated schemas, regex validation, business rules, `Number`,
  `parseInt`, unsafe money/revision coercion, and raw upstream rendering.
- Use browser tools to confirm same-origin traffic and no internal origin disclosure.
- Exercise accessibility/responsive/error states and the real WP08+WP10 production E2E.
- Independently recalculate the 100-sample nearest-rank result and inspect timing boundaries.
- Reject approval if profile, lock stewardship, ownership, or performance evidence drifts.

## Activity Log

> Entries must remain chronological. Append new entries at the end.

- 2026-07-20T07:11:44Z – system – WP10 prompt adapted from the former web package,
  split into serialized root-lock reconciliation, shell, stable contract client, real proxy,
  and exact combined E2E/performance evidence.

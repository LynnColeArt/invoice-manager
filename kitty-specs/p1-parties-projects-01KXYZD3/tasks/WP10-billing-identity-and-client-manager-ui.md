---
work_package_id: "WP10"
title: "Billing Identity and Client Manager UI"
dependencies: ["WP09"]
requirement_refs: ["FR-001", "FR-002", "FR-003", "FR-004", "FR-005", "FR-006", "FR-007", "FR-008", "FR-009", "NFR-001", "NFR-003", "NFR-006", "C-002", "C-009"]
subtasks: ["T050", "T051", "T052", "T053", "T054"]
owned_files:
  - "apps/web/src/features/billing-identities/**"
  - "apps/web/src/features/clients/**"
  - "apps/web/src/app/billing-identities/**"
  - "apps/web/src/app/clients/**"
  - "apps/web/tests/parties-projects/identities-clients/**"
authoritative_surface: "apps/web/"
execution_mode: "code_change"
agent_profile: "frontend-freddy"
role: "implementer"
agent: "codex"
model: ""
---

# Work Package Prompt: WP10 – Billing Identity and Client Manager UI

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `frontend-freddy`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Build the owner-facing Billing Identity, Remittance, Logo Asset, Client, and Billing Contact manager in Next.js. The UI must make “Invoice header / billed from” consequential choices explicit while treating Zig/HTTP responses as the only business authority.

## Context

WP10 implements `IC-10` after WP09 and runs in parallel with WP11. It consumes generated contract types and the same-origin P0 proxy. It owns only identity/client feature, route, and test paths; global navigation/layout is an integration-steward touchpoint and must not be edited here.

## Mandatory Entry, Red-First, and Evidence Gates

1. Stop unless exact P0 Frozen/merged/revalidated and accepted WP09 HTTP evidence are on the baseline.
2. Run P0 contract generation plus web type/lint/unit gates before edits; never rewrite package metadata, lock, shared layout, proxy, or generated contracts.
3. Before each visible workflow/accessibility/privacy behavior, add a failing component or Playwright case and chronological `RED:` evidence; append matching `GREEN:` after minimal implementation.
4. Client-side validation is advisory only. Render authoritative Zig field errors and preserve Draft values after rejection.
5. Remittance values are masked by default and require deliberate reveal. Domestic/hidden responses must never be reconstructed from other client state.
6. No JavaScript arithmetic for Money, no inferred Billing Market, no real data, and no UI-only lifecycle mutations.

```bash
spec-kitty agent action implement WP10 --agent codex
```

### Subtask T050: Build Billing Identity list/detail/edit workflows

**Purpose**: Let the owner create and manage Personal/Company invoice headers safely.

**Steps**:

1. Add identity list/detail/new/edit routes under the owned app path.
2. Use generated request/response types for legal/display/address/contact/tax/default-term/status fields.
3. Label the consequential selector and pages “Invoice header / billed from” with Personal/Company clarification.
4. Display Draft/readiness/Active/Inactive status and authoritative field-error summary with focus links.
5. Confirm deactivation and show affected-reference/reassignment requirements without optimistic local mutation.

**Files**: `features/billing-identities/**`, `app/billing-identities/**`, focused tests.

**Validation**: Create/edit/activate/deactivate/error flows pass with keyboard navigation and server-state reconciliation.

### Subtask T051: Build remittance and Logo Asset workflows

**Purpose**: Manage European bank configuration and optional approved PNG assets without accidental disclosure.

**Steps**:

1. Add remittance edit form with required/optional fields, field help, and authoritative completeness/checksum errors.
2. Mask stored IBAN/BIC/account-holder/bank details by default; add a deliberate, labeled reveal/hide control with no auto-focus disclosure.
3. Add bounded PNG upload/preview/status/version selection using the exact multipart contract.
4. Show digest/media/dimensions/status and replacement-as-new-version behavior, never raw storage paths.
5. Preserve entered non-sensitive form state on failure while avoiding bank values in client logs/telemetry/tests.

**Files**: Identity feature remittance/logo components and tests within WP10 paths.

**Validation**: Mask/reveal, Europe incomplete/complete, upload success/failure/retry, asset deactivate, and keyboard/screen-reader cases pass.

### Subtask T052: Build Client/contact manager workflows

**Purpose**: Provide fast searchable owner workflows for Draft/Active/Archived Clients.

**Steps**:

1. Add Client list/detail/new/edit routes with search, status, market, readiness, stable sort, and pagination.
2. Build address, tax, notes, explicit market, Other choice, default identity, currency, and terms forms from generated contracts.
3. Add contact create/edit/deactivate/reorder/primary controls with one-primary readiness messaging.
4. Save incomplete Clients as Draft and render the full readiness blocker list without discarding entered data.
5. Support archive/restore-to-Draft and visibly distinguish inactive defaults or reassignment blockers.

**Files**: `features/clients/**`, `app/clients/**`, focused tests.

**Validation**: Domestic/Europe/Other, Draft/Active/Archived, contact-primary, filters, and retry/error cases pass.

### Subtask T053: Render policy, override, and sensitive-state feedback accessibly

**Purpose**: Make consequential choices understandable without relying on color or hidden defaults.

**Steps**:

1. Show explicit market→remittance decision text and explain why Europe requires complete details while Domestic omits them.
2. Show default Billing Identity label/status and affected-reference details for reassignment/deactivation.
3. Associate errors with fields, add summary focus management, persistent labels, descriptions, and live status that does not overwhelm assistive technology.
4. Ensure reveal controls announce current masked/revealed state and reset on navigation/reload.
5. Use non-color icons/text for status/readiness and visible focus across all controls.

**Files**: Shared-within-WP10 components/styles/tests only.

**Validation**: axe, keyboard-only, focus/error-summary, mask reset, zoom/responsive, and non-color cue tests pass.

### Subtask T054: Prove owner workflow, responsiveness, and contract isolation

**Purpose**: Leave a complete independently reviewable Identity/Client UI lane.

**Steps**:

1. Exercise create Personal/Company identity, Europe remittance, logo upload, Domestic/Europe/Other Client, contact primary, activate/archive/restore workflows through real same-origin HTTP.
2. Seed 500 synthetic Clients/2,000 Project summaries through supported fixtures and measure list/search/detail interactions under two seconds.
3. Run format, lint, strict typecheck, unit/component, build, axe, keyboard, and Playwright commands.
4. Scan browser/server logs and snapshots for remittance/contact/tax/note/path canaries.
5. Verify no package/lock/generated/shared-layout/proxy/WP11 paths changed.
6. Record RED/GREEN evidence, exact commands, timings, and clean owned-file diff.

**Files**: `apps/web/tests/parties-projects/identities-clients/**`.

**Validation**: Real workflow, performance, accessibility, privacy, build, and isolation gates pass.

## Definition of Done

- [ ] Exact P0/WP09 gates precede edits.
- [ ] Identity/remittance/logo and Client/contact workflows are complete.
- [ ] Consequential issuer/market/readiness choices are explicit.
- [ ] Sensitive values are masked, deliberately revealed, and absent from logs.
- [ ] Zig errors remain authoritative and Draft input is preserved.
- [ ] WCAG 2.2 AA automated and keyboard workflows pass.
- [ ] Reference-scale interactions finish within two seconds.
- [ ] RED/GREEN evidence and WP10-only diff pass.

## Risks

- **UI policy duplication**: display server decisions; never recompute readiness.
- **Bank disclosure**: mask by default, reset reveal, and scan canaries.
- **Shared-shell collision**: publish integration request; do not edit layout/navigation.
- **Money coercion**: retain generated string representation end-to-end.

## Reviewer Guidance

Review server authority, exact generated types, mask/reveal behavior, Draft preservation, accessibility/focus semantics, reference-scale timing, real HTTP Playwright evidence, sensitive scans, and disjoint ownership from WP11/shared shell.

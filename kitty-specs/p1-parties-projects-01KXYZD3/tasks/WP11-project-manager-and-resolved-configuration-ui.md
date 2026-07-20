---
work_package_id: "WP11"
title: "Project Manager and Resolved Configuration UI"
dependencies: ["WP09"]
requirement_refs: ["FR-010", "FR-011", "FR-012", "FR-013", "FR-014", "NFR-001", "NFR-006", "C-002", "C-007", "C-009"]
subtasks: ["T055", "T056", "T057", "T058", "T059"]
owned_files:
  - "apps/web/src/features/projects/**"
  - "apps/web/src/app/projects/**"
  - "apps/web/tests/parties-projects/projects/**"
authoritative_surface: "apps/web/"
execution_mode: "code_change"
agent_profile: "frontend-freddy"
role: "implementer"
agent: "codex"
model: ""
---

# Work Package Prompt: WP11 – Project Manager and Resolved Configuration UI

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `frontend-freddy`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Build the owner-facing Project manager and current resolved invoice-configuration review in Next.js. The UI must make inherited versus overridden issuer/defaults, logo policy, remittance decision, cadence facts, and readiness blockers conspicuous before activation.

## Context

WP11 implements `IC-11` after WP09 and runs parallel to WP10 with fully disjoint paths. It consumes generated contracts and same-origin HTTP only. It may link to identity/client routes without editing their features or the shared global navigation/layout.

## Mandatory Entry, Red-First, and Evidence Gates

1. Stop unless exact P0 Frozen/merged/revalidated and accepted WP09 HTTP evidence are present.
2. Run contract generation and existing web gates before edits; never change package/lock/config/generated/shared shell/WP10 paths.
3. Add a failing component/Playwright test plus `RED:` evidence before each Project/resolution behavior; append matching `GREEN:` after minimal implementation.
4. Zig remains authoritative for readiness, resolution, Money/date, and lifecycle. The UI must not advance dates or create invoices.
5. Use generated strings for Money/date facts and synthetic test data only.

```bash
spec-kitty agent action implement WP11 --agent codex
```

### Subtask T055: Build Project list/detail/lifecycle workflows

**Purpose**: Let the owner find and manage Draft, Active, Paused, Completed, and Archived engagements.

**Steps**:

1. Add Project list/detail/new/edit routes within the owned app path.
2. Implement search, Client, status, cadence, readiness, stable sort, and bounded pagination controls.
3. Render Client label, effective issuer summary, cadence/next date, currency/amount, logo mode, and readiness state in summaries.
4. Add explicit activate/pause/resume/complete/archive actions with confirmation and server result reconciliation.
5. Preserve Draft edits and show authoritative field/readiness errors on rejection.

**Files**: `features/projects/**`, `app/projects/**`, focused tests.

**Validation**: Search/filter/detail plus every legal/illegal lifecycle transition passes via real HTTP.

### Subtask T056: Build inheritance and explicit-override editing

**Purpose**: Make the invoice header choice impossible to overlook.

**Steps**:

1. Provide ClientDefault versus Explicit identity choice labeled “Invoice header / billed from.”
2. Show current Client default and active override candidates from server-provided data.
3. Display a persistent non-color “Inherited” or “Project override” indicator and source revision.
4. Require an Active identity when Explicit and surface inactive/missing/stale revision errors.
5. Prove a Client-default change updates inherited resolution while explicit override remains stable.

**Files**: Project identity/default editor components and tests.

**Validation**: Inherited/override switching, default change, inactive override, revision conflict, keyboard, and screen-reader cases pass.

### Subtask T057: Build resolved configuration review

**Purpose**: Show the exact current configuration before Project activation.

**Steps**:

1. Render effective issuer/recipient, market/remittance decision, currency/terms, cadence facts, logo decision, and provenance from the resolved endpoint.
2. Structurally omit bank sections for Domestic/Other Hide; show masked complete details for Show with deliberate reveal if provided by API.
3. Show logo Off versus selected Project/Identity asset and source/digest metadata without raw paths.
4. Present all readiness blockers with links to relevant Project or external Identity/Client pages.
5. Mark the view clearly as current configuration, not an issued invoice snapshot.

**Files**: Resolved summary components/tests under WP11 paths.

**Validation**: All WP08 valid/invalid market/identity/logo fixtures render expected visible and absent content.

### Subtask T058: Build cadence and billing-default editing

**Purpose**: Capture valid monthly/quarterly facts without implementing scheduling.

**Steps**:

1. Add currency, payment terms, service description, optional decimal-string minor-unit amount, cadence, anchor, next date, and optional end date controls.
2. Preserve exact strings; perform no floating-point conversion or recurrence calculation.
3. Render lightweight client checks only as guidance and map authoritative server errors to fields/summary.
4. Explain that next billing date is stored configuration and will later be advanced by the scheduling mission.
5. Cover amount/currency mismatch, invalid/ordered dates, terms bounds, and monthly/quarterly selection.

**Files**: Project billing/cadence form components/tests.

**Validation**: Exact request payloads and error rendering match generated contracts; no schedule/amount arithmetic appears in source.

### Subtask T059: Prove Project workflow accessibility, responsiveness, and isolation

**Purpose**: Close the independent Project UI lane for final acceptance.

**Steps**:

1. Exercise inherited and overridden Domestic/Europe Projects with logo Off/On, cadence/default edits, activation, pause, completion, and archive through real same-origin HTTP.
2. Run reference-scale Project search/filter/detail interactions under two seconds.
3. Run format, lint, typecheck, unit/component, build, axe, keyboard, and Playwright gates.
4. Verify visible focus, error-summary movement, non-color provenance/status, zoom, and responsive layout.
5. Scan browser/server logs/snapshots for remittance/contact/tax/path canaries.
6. Verify no WP10 or shared shell/package/config/generated path changed and record exact evidence.

**Files**: `apps/web/tests/parties-projects/projects/**`.

**Validation**: Workflow, performance, accessibility, privacy, build, and ownership gates pass.

## Definition of Done

- [ ] Exact P0/WP09 gates precede edits.
- [ ] Project list/detail/edit/lifecycle workflows are complete.
- [ ] Identity inheritance/override and provenance are conspicuous.
- [ ] Resolved review displays exact server decisions and structural omissions.
- [ ] Cadence/default UI performs no recurrence or floating-point arithmetic.
- [ ] WCAG 2.2 AA, keyboard, privacy, and two-second performance pass.
- [ ] RED/GREEN evidence and WP11-only diff pass.

## Risks

- **Override ambiguity**: persistent text/icon/source detail, never color alone.
- **Schedule scope creep**: render/edit facts only.
- **Hidden bank leakage**: rely on server omission and scan rendered output.
- **Parallel UI collision**: do not edit WP10 or shared shell; request steward integration.

## Reviewer Guidance

Review issuer/provenance clarity, server authority, structural omission, exact Money/date strings, schedule exclusion, accessibility, real workflow/performance evidence, privacy canaries, and strict disjointness from WP10/shared files.

---
work_package_id: "WP12"
title: "P1 Compatibility, Accessibility, Durability, and Consumer Handoff"
dependencies: ["WP08", "WP09", "WP10", "WP11"]
requirement_refs: ["FR-001", "FR-002", "FR-003", "FR-004", "FR-005", "FR-006", "FR-007", "FR-008", "FR-009", "FR-010", "FR-011", "FR-012", "FR-013", "FR-014", "FR-015", "FR-016", "FR-017", "FR-018", "NFR-001", "NFR-002", "NFR-003", "NFR-004", "NFR-005", "NFR-006", "NFR-007", "NFR-008", "NFR-009", "NFR-010", "C-001", "C-002", "C-003", "C-004", "C-005", "C-006", "C-007", "C-008", "C-009"]
subtasks: ["T060", "T061", "T062", "T063", "T064", "T065", "T066"]
owned_files:
  - "services/api/tests/parties_projects/acceptance/**"
  - "apps/web/tests/parties-projects/acceptance/**"
  - "contracts/manifests/p1.json"
  - "docs/integration-requests/p1/**"
  - "docs/program-handoffs/p1/**"
create_intent:
  - "contracts/manifests/p1.json"
authoritative_surface: "services/api/tests/parties_projects/acceptance/"
execution_mode: "code_change"
agent_profile: "implementer-ivan"
role: "implementer"
agent: "codex"
model: ""
---

# Work Package Prompt: WP12 – P1 Compatibility, Accessibility, Durability, and Consumer Handoff

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Close P1 with exact contract compatibility, full owner workflows, privacy/security, accessibility, reference-scale performance, durable restart/concurrency proof, GPL-compatible dependency evidence, and an immutable consumer handoff. This package records and validates producer evidence; it does not repair producer code in its acceptance paths.

## Context

WP12 implements `IC-12` after WP08–WP11 and transitively every producer. It is the sole creator/promoter of canonical `contracts/manifests/p1.json` and owns dedicated acceptance/handoff paths. Any producer defect is routed to the owning WP for correction/re-review. Shared navigation, root CI/package/build, and program ledger remain integration-steward owned.

## Mandatory Entry, Red-First, and Evidence Gates

1. Stop unless P0 is merged, exact consumed contracts are `Frozen` or later with immutable version/content digest, and the complete P1 branch has been revalidated against that baseline.
2. Require accepted review receipts for WP01–WP11 and exact commits in the dependency closure.
3. Run focused producer gates before authoring acceptance code. For every missing end-to-end invariant, first add a failing public acceptance case and `RED:` evidence, route producer fixes to their owner, then record `GREEN:` after accepted correction.
4. WP12 may write only its acceptance tests, canonical P1 manifest, and P1 integration/handoff documents. It must not edit production, fixtures, mission planning, root tools, shared shell, CI, or program ledger.
5. Use real Zig HTTP, real P0-backed storage, and production Next.js. Mocks, direct repositories, cached state, and generated-only claims cannot satisfy acceptance.
6. All evidence/data is synthetic and sanitized.

```bash
spec-kitty agent action implement WP12 --agent codex
```

### Subtask T060: Revalidate exact P0 input and promote the P1 manifest

**Purpose**: Bind shipped P1 outputs to immutable upstream and owned content identity.

**Steps**:

1. Read the accepted WP01 Draft manifest and exact canonical P0 manifest from the current baseline.
2. Recompute P0 manifest SHA/content digest and require exact version/state/input match; reject branch names, pending evidence, or changed Frozen content.
3. Hash P1 API/event/module/fixture/migration outputs and compute the canonical immutable projection through P0 tooling.
4. Create `contracts/manifests/p1.json` without mutating WP01's Draft input.
5. Advance Draft → Frozen → Implemented → Verified only through legal transitions and only as evidence becomes complete.
6. Preserve content identity through all post-Frozen states; any changed byte requires a new version.

**Files**: `contracts/manifests/p1.json`, manifest acceptance tests.

**Validation**: Independent digest recomputation and mutation/illegal-transition tests pass; exact P0/P1 pins are recorded.

### Subtask T061: Run the complete contract, service, HTTP, and web gate matrix

**Purpose**: Verify every focused producer command remains independently diagnosable and the aggregate is green.

**Steps**:

1. Run contract composition/check/generation determinism and verify generated tracked-file cleanliness.
2. Run P1 shared/domain/persistence/application/security/HTTP focused tests and coverage.
3. Run migration positive/negative, persistence integration/crash, and black-box HTTP commands.
4. Run web format/lint/type/unit/build/accessibility/Playwright focused commands for both UI lanes.
5. Run the repository aggregate verification command and route any failure to the first focused owner.
6. Record tool versions, commits, commands, exit status, and stable output hashes.

**Files**: Acceptance command matrix/tests/docs within WP12-owned paths.

**Validation**: Every focused and aggregate command passes independently from committed inputs.

### Subtask T062: Prove durability, restart, retry, and concurrency end to end

**Purpose**: Accept FR-015/017/018 and NFR-004/009 through observable behavior.

**Steps**:

1. Create identities/assets/Clients/Projects through real HTTP and production persistence.
2. Checkpoint, close, reopen, and compare list/detail/resolved state plus idempotent replay result.
3. Fault commit/checkpoint/directory sync/process boundaries and verify no false success or blind replay.
4. Race default/override/asset deactivation/reassignment/Project activation and idempotency keys repeatedly.
5. Require one valid serialized outcome, zero dangling references, and exactly one event/result after reopen.
6. Capture and scan logs/errors for sensitive/SQL/path/engine canaries.

**Files**: `services/api/tests/parties_projects/acceptance/durability_*`, `concurrency_*`.

**Validation**: Real restart/crash/concurrency suite passes with durable, privacy-safe outcomes.

### Subtask T063: Prove complete accessible owner workflows

**Purpose**: Accept the user scenarios through production UI and same-origin HTTP.

**Steps**:

1. Create Personal and Company Billing Identities, configure Europe remittance and optional logo, and exercise deactivation/reassignment blockers.
2. Create Domestic, Europe, and Other Clients with contacts/readiness and activate/archive/restore them.
3. Create inherited and overridden monthly/quarterly Projects, logo Off/On, inspect resolved configuration, and exercise lifecycle.
4. Complete every flow keyboard-only with visible focus, associated errors, focus summary, non-color state/provenance, zoom, and responsive layout.
5. Run axe WCAG 2.2 AA checks at each primary page/state.
6. Verify masked-by-default bank details and reveal reset behavior.

**Files**: `apps/web/tests/parties-projects/acceptance/workflows_*`, accessibility evidence.

**Validation**: All primary workflows and accessibility checks pass against production builds.

### Subtask T064: Prove reference-scale responsiveness and determinism

**Purpose**: Accept NFR-001 and NFR-008 on a documented reference deployment.

**Steps**:

1. Load exactly 500 synthetic Clients and 2,000 synthetic Projects through supported seed/API mechanisms.
2. Warm only as documented, then measure representative list/search/filter/detail/resolution interactions monotonically.
3. Require each owner interaction to complete within two seconds and record samples/environment.
4. Repeat resolution against unchanged revisions and compare canonical bytes.
5. Change one source revision/default and prove only documented output/provenance fields change.
6. Keep currencies separate and perform no cross-currency aggregation.

**Files**: Acceptance performance/determinism tests and evidence under WP12 paths.

**Validation**: Thresholds and byte-equivalence checks pass reproducibly.

### Subtask T065: Prove privacy, asset safety, licensing, and public evidence

**Purpose**: Close open-source and sensitive-data safety gates.

**Steps**:

1. Run the full WP08 canary catalog across API/UI logs, responses, events, snapshots, error summaries, and handoff documents.
2. Require Domestic/Other Hide payloads/fixtures to contain no remittance field names or values.
3. Re-run logo malformed/oversized/discordant/path cases through HTTP and UI upload flows.
4. Run the repository GPL-2.0-only runtime license/notice audit without changing shared tooling.
5. Verify every public fixture, screenshot, database, and document contains invented data only.
6. Route incompatible or missing dependency evidence to its producer owner.

**Files**: WP12 acceptance tests and handoff evidence only.

**Validation**: Canary, structural omission, asset, license, notice, and synthetic-data scans pass.

### Subtask T066: Publish consumer and integration-steward handoff

**Purpose**: Give P2/P5/P6 and the integration steward immutable, actionable P1 evidence.

**Steps**:

1. Record canonical P1 version/state/content digest, exact P0 input, fixture inventory/hashes, route/event/module/migration roots, and acceptance commands/results.
2. Document P2/P5/P6 consumer responsibilities: preview, immutable issuance snapshot, and cadence advancement respectively.
3. State explicitly that current P1 master data cannot mutate issued invoice history.
4. Create integration requests for shared navigation/route/CI/program-ledger updates without editing those surfaces.
5. Record known supported limits: USD/EUR, PNG 2 MiB/pixel bounds, one serialized DB handle, snapshot/storage constraints inherited from P0.
6. Verify every referenced commit/path/hash exists and all governed planning documents remain unchanged.
7. Finish with clean status and exact changed-file inventory.

**Files**: `docs/integration-requests/p1/**`, `docs/program-handoffs/p1/**`.

**Validation**: A consumer can validate fixtures/contracts offline from exact commits; steward requests name every shared change and owner.

## Definition of Done

- [ ] Exact Frozen/merged P0 and accepted WP01–WP11 evidence is verified.
- [ ] Canonical P1 manifest reaches only the legally justified lifecycle state.
- [ ] Every focused and aggregate contract/service/web gate passes.
- [ ] Real restart/retry/concurrency proves durable serialized behavior.
- [ ] Full workflows meet WCAG 2.2 AA and keyboard requirements.
- [ ] Reference-scale interactions meet two seconds and resolution is deterministic.
- [ ] Privacy, asset, licensing, notice, and synthetic-evidence gates pass.
- [ ] Consumer/steward handoff is immutable and planning/shared surfaces are untouched.

## Risks

- **Acceptance package repairs producers**: route failures back and require re-review.
- **Premature lifecycle promotion**: leave the last justified state unchanged on any missing evidence.
- **Mock/cached evidence**: require real production boundaries and committed inputs.
- **Shared-surface collision**: author integration requests only.
- **Sensitive handoff leakage**: synthetic data and allowlist/canary scans are mandatory.

## Reviewer Guidance

Independently recompute P0/P1 digests, inspect legal lifecycle transitions, rerun focused/aggregate and real restart/workflow gates, verify accessibility/performance protocols, scan public evidence, and compare the diff to WP12-owned paths. Reject any production repair, shared-file edit, or premature Verified claim.

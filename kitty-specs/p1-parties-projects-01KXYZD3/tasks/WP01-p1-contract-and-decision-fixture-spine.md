---
work_package_id: "WP01"
title: "P1 Contract and Decision-Fixture Spine"
dependencies: []
requirement_refs: ["FR-008", "FR-011", "FR-012", "FR-013", "FR-014", "FR-016", "NFR-002", "NFR-008", "NFR-010", "C-001", "C-008", "C-009"]
subtasks: ["T001", "T002", "T003", "T004", "T005", "T006"]
owned_files:
  - "contracts/api/v1/fragments/p1/**"
  - "contracts/events/v1/catalogs/p1/**"
  - "contracts/events/v1/payloads/p1/**"
  - "contracts/modules/p1/**"
  - "contracts/manifests/drafts/p1.json"
  - "contracts/fixtures/p1/v1/decisions/**"
create_intent:
  - "contracts/manifests/drafts/p1.json"
authoritative_surface: "contracts/"
execution_mode: "code_change"
agent_profile: "node-norris"
role: "implementer"
agent: "codex"
model: ""
---

# Work Package Prompt: WP01 – P1 Contract and Decision-Fixture Spine

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `node-norris`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Publish P1's additive contract spine against the exact Frozen P0 foundation without editing a shared aggregate. The result defines owner-scoped HTTP, event, module, manifest, and decision-fixture inputs that every later P1 lane can consume deterministically.

## Context

P1 owns mutable Billing Identity, Client, Project, Logo Asset, and current resolved-configuration facts. P0 owns common wire values, envelopes, lifecycle rules, composition tooling, and generated aggregates. This package is the only P1 writer for contract fragments and the Draft P1 implementation manifest; later packages consume these files read-only.

This package addresses plan concern `IC-01`. It opens WP02 and WP06, and indirectly all other P1 implementation. It must not add business implementation, edit P0 files, write generated outputs, or promote `contracts/manifests/p1.json`; WP12 owns final promotion.

## Mandatory Entry, Red-First, and Evidence Gates

1. Do not start production changes unless the current P1 baseline contains the merged P0 implementation and canonical `contracts/manifests/p0.json` in `Frozen`, `Implemented`, or `Verified` state.
2. Record the exact P0 version, baseline commit, manifest SHA-256, and immutable content digest. They must match P1's declared input; a Draft, pending digest, moving branch, or sibling checkout is a hard stop.
3. Run P0 contract composition/check commands before editing and record their green baseline. If the commands or generated-output conventions are absent, stop and report the missing P0 handoff.
4. Before each contract behavior change, add a failing public composition/lifecycle/fixture test and append `RED:` evidence to the WP Activity Log: case ID, exact command, expected failure, observed failure, and exit status.
5. After the smallest production change, append matching `GREEN:` evidence. A test first observed green, a private-helper-only case, or an assertion against fabricated aggregates does not count.
6. Keep all writes inside `owned_files`. Generated aggregates, root manifests, root package files, global route inventories, and P0-P8 owner paths are read-only.
7. Use only synthetic identities, addresses, account values, and assets. No real bank or customer data may enter a fixture, log, or review receipt.

Start implementation only after these gates pass:

```bash
spec-kitty agent action implement WP01 --agent codex
```

### Subtask T001: Materialize the P1 Draft implementation manifest

**Purpose**: Create the owner manifest that binds P1 to the exact Frozen P0 contract and declares only P1-owned outputs and integration surfaces.

**Steps**:

1. Read P0's canonical manifest schema and lifecycle tool from the merged baseline.
2. Create `contracts/manifests/drafts/p1.json` through the supported tooling or exact schema shape; never invent a second dialect.
3. Record P1 contract ID/version, owner, mission, stable planning baseline, and the exact P0 input version/content digest.
4. Declare only P1 API fragments, event catalogs/payloads, module contribution, decision fixtures, owner migration root, and approved shared touchpoints.
5. Keep lifecycle state Draft until WP12 has real implementation and acceptance evidence.
6. Reject pending evidence where the Frozen-input schema forbids it, moving refs, duplicate owners, traversal, and content-digest mismatch.

**Files**: `contracts/manifests/drafts/p1.json`.

**Validation**: Schema validation passes offline; substituting a wrong P0 digest, owner, path, or lifecycle transition fails with a stable diagnostic.

### Subtask T002: Publish additive P1 OpenAPI fragments

**Purpose**: Define P1 operations beneath P0 `/api/v1` without editing the aggregate OpenAPI document.

**Steps**:

1. Add namespaced operations for Billing Identities/remittance/assets, Clients/contacts, Projects/lifecycle, and current resolved configuration.
2. Reuse P0 IDs, Money, dates, instants, success/error envelopes, JSON Pointer field failures, and correlation identifiers by canonical reference.
3. Require idempotency keys for creates, uploads, and lifecycle transitions; require expected revision for updates and atomic reassignments.
4. Define stable pagination, sorting, filter, archive/restore, mask/reveal, and multipart PNG upload shapes.
5. Model Domestic and Other/Hide payloads so the `remittance` property is structurally absent, not nullable.
6. Keep invoice issuance, rendering, numbering, payments, schedule advancement, and analytics routes absent.

**Files**: `contracts/api/v1/fragments/p1/**`.

**Validation**: Each fragment validates alone and composes twice to byte-identical output; deliberate route/method/operation/schema collisions fail before publication.

### Subtask T003: Publish configuration event contracts

**Purpose**: Define privacy-safe P1 lifecycle facts using the P0 event envelope.

**Steps**:

1. Define versioned payloads for identity, asset, client, and project created/changed/status events plus atomic reassignment completion.
2. Include consumer-safe identifiers, revisions, status, market/cadence facts, and event purpose only.
3. Prohibit IBAN, BIC, account-holder, bank instructions, addresses, tax values, contact emails, internal notes, and raw artifact paths.
4. Add the P1 catalog contribution with unique event names, payload versions, owner, and stable schema references.
5. Validate representative JSONL envelopes through P0's public event validator.
6. Prove unknown event, wrong owner/version, bad envelope, and sensitive-field sentinels are rejected.

**Files**: `contracts/events/v1/catalogs/p1/**`, `contracts/events/v1/payloads/p1/**`.

**Validation**: Offline catalog/payload composition and positive/negative envelope cases pass; canary values are absent from generated material and diagnostics.

### Subtask T004: Declare the P1 module contribution

**Purpose**: Make P1 discoverable by P0's additive module mechanism without touching a global registry or shared router.

**Steps**:

1. Create the P1 module contribution using the canonical module schema.
2. Declare only P1 route mounts, event catalog, fixture root, migration root, and ownership metadata.
3. Use the P0 access-policy vocabulary; do not invent temporary authentication while P3 remains concurrent.
4. Keep shared navigation and route aggregate changes as explicit integration requests, never direct edits.
5. Add collision cases for duplicate mounts, duplicate owners, conflicting route/method pairs, and escaping paths.

**Files**: `contracts/modules/p1/**`.

**Validation**: Module discovery is deterministic and rejects every collision/escape case without changing prior generated outputs.

### Subtask T005: Freeze decision-table fixtures for downstream lanes

**Purpose**: Encode the approved identity, remittance, logo, currency, terms, and cadence decisions as synthetic contract inputs.

**Steps**:

1. Add compact cases for ClientDefault versus ProjectOverride identity provenance.
2. Add Domestic, Europe, Other/Show, Other/Hide, and missing Other choice cases.
3. Add logo Off, project asset, identity default asset, and unavailable asset cases.
4. Add USD/EUR Money, payment terms, monthly/quarterly cadence, and invalid date-order cases.
5. Record expected valid/error category and stable field paths without embedding implementation-specific storage rows.
6. Canonicalize object ordering and compare repeated fixture materialization byte-for-byte.

**Files**: `contracts/fixtures/p1/v1/decisions/**`.

**Validation**: Every plan decision-table row has at least one fixture; mutation tests prove omitted remittance, provenance, and error expectations are meaningful.

### Subtask T006: Prove contract isolation and deterministic handoff

**Purpose**: Produce executable evidence that WP01 is an additive, exact-input contract contribution.

**Steps**:

1. Run the focused P0 contract checker with network disabled and exact P1 files.
2. Generate twice and compare output inventory and bytes while keeping ignored outputs untracked.
3. Mutate one P0 input digest, stable schema ID, route, event name, module mount, fixture expectation, and owner path; each must fail.
4. Verify `git diff --name-only` contains only WP01-owned paths.
5. Record the exact P0 commit/digest and focused commands in the review handoff.
6. Restore every mutation and finish with a clean focused rerun and `git diff --check`.

**Files**: Tests/fixtures within the WP01-owned contract directories only.

**Validation**: Determinism, lifecycle, collision, privacy, and ownership checks all pass from committed public inputs.

## Definition of Done

- [ ] P0 Frozen/merged/revalidated evidence precedes every production edit.
- [ ] Draft P1 manifest pins exact P0 immutable content identity.
- [ ] API, event, module, and decision fixtures compose without shared-file edits.
- [ ] Domestic/hidden outputs cannot carry a remittance property.
- [ ] Event schemas exclude all listed sensitive values.
- [ ] Every production behavior has chronological RED then GREEN evidence.
- [ ] Repeated generation is byte-identical and leaves generated files untracked.
- [ ] Only WP01-owned paths changed and all examples are synthetic.

## Risks

- **Draft used as implementation authorization**: block until exact Frozen P0 evidence is on the current baseline.
- **Second contract dialect**: reuse P0 schemas and lifecycle tooling exclusively.
- **Privacy leak through events/fixtures**: enforce structural deny lists and sentinel scans.
- **Parallel collision**: never edit aggregates, global registries, shared routers, or other owners' fragments.
- **False conformance**: test exact committed artifacts, not fabricated replacements.

## Reviewer Guidance

Review the exact P0 pin, ownership boundaries, omitted-versus-null remittance modeling, event deny list, decision-table coverage, and deletion/mutation-test evidence. Reject moving refs, pending Frozen evidence, generated tracked outputs, or any edit beyond the declared contract paths.

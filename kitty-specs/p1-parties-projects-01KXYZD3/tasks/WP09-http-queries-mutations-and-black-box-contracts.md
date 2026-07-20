---
work_package_id: "WP09"
title: "HTTP Queries, Mutations, and Black-Box Contracts"
dependencies: ["WP01", "WP07", "WP08"]
requirement_refs: ["FR-001", "FR-005", "FR-006", "FR-007", "FR-008", "FR-009", "FR-010", "FR-011", "FR-012", "FR-013", "FR-014", "FR-015", "FR-017", "FR-018", "NFR-001", "NFR-003", "NFR-004", "NFR-009", "NFR-010", "C-002", "C-008"]
subtasks: ["T044", "T045", "T046", "T047", "T048", "T049"]
owned_files:
  - "services/api/src/domains/parties_projects/http/**"
  - "services/api/tests/parties_projects/http/**"
authoritative_surface: "services/api/src/domains/parties_projects/http/"
execution_mode: "code_change"
agent_profile: "node-norris"
role: "implementer"
agent: "codex"
model: ""
---

# Work Package Prompt: WP09 – HTTP Queries, Mutations, and Black-Box Contracts

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `node-norris`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Expose the accepted P1 application surface through exact WP01 `/api/v1` fragments and P0 envelopes. Black-box tests must prove validation, idempotency, revisions, persistence, privacy, and route isolation without reaching repositories or implementation internals.

## Context

WP09 implements `IC-09` after WP01, WP07, and WP08. It owns only P1 HTTP handlers/adapters/tests; it does not edit shared router/build/generated files. P0's module/route discovery consumes WP01 metadata. WP10 and WP11 start in parallel after this boundary is accepted.

## Mandatory Entry, Red-First, and Evidence Gates

1. Stop unless exact P0 Frozen/merged/revalidated, WP01 contracts, WP07 services, and WP08 fixtures are accepted on the dependency base.
2. Materialize generated contracts using P0's exact command before compiling HTTP code; never handwrite alternate envelope types.
3. Before each operation/error/privacy behavior, add a failing black-box request/response case and chronological `RED:` evidence; append matching `GREEN:` after minimal handler work.
4. Tests call only the externally served HTTP interface. No repository/domain private imports or direct function assertions satisfy this WP.
5. Preserve checkpoint-before-success and stable diagnostic redaction from WP07; raw engine/SQL/path/sensitive values must never reach responses/logs.
6. Do not invent temporary auth; P3 owns authorization. Keep P1 test/internal-only per the plan.

```bash
spec-kitty agent action implement WP09 --agent codex
```

### Subtask T044: Implement P1 route groups and request adapters

**Purpose**: Connect exact contract operations to typed application commands/queries.

**Steps**:

1. Implement handlers for Billing Identities/remittance/assets, Clients/contacts, Projects/status, and resolved configuration under WP01 paths.
2. Parse P0 IDs, revisions, Money/date/instant values, enums, filters, and bodies strictly.
3. Map each operation to one WP07 public application method; never access repositories directly.
4. Register through P0 module discovery/convention without editing shared router or route inventory.
5. Reject unknown content type, method, path, field, enum, and malformed JSON deterministically.

**Files**: `http/routes/**`, `http/request_mapping.zig`, black-box tests.

**Validation**: Exact route inventory matches WP01; undeclared/shared route edits and malformed requests fail.

### Subtask T045: Implement P0 envelopes, field errors, revisions, and idempotency

**Purpose**: Preserve canonical boundary semantics for all mutations.

**Steps**:

1. Serialize success and error responses through P0 envelopes with correlation metadata.
2. Map domain/application errors to stable status/code and JSON Pointer field failures without raw rejected values.
3. Require/validate idempotency keys on create/upload/transition and expected revisions on update/reassignment.
4. Return original response for identical replay, conflict for different reuse, and revision conflict for stale state.
5. Map durability uncertainty distinctly and never report success before confirmation.

**Files**: `http/response_mapping.zig`, middleware/adapters within owned path, tests.

**Validation**: WP08 invalid/idempotency/durability cases match exact response shapes and logs remain redacted.

### Subtask T046: Implement bounded multipart Logo Asset upload

**Purpose**: Stream one approved PNG upload to WP07 without trusting client metadata or buffering unbounded data.

**Steps**:

1. Enforce request/content length, one file part, bounded metadata, and accepted content type before/while reading.
2. Stop at the configured 2 MiB limit and pass bounded bytes/declared facts to the Zig asset service.
3. Ignore original filename for storage; preserve only sanitized optional display name.
4. Require idempotency and return stable validation fields for malformed multipart, size, media, content, and dimensions.
5. Clean temporary buffers/files on every failure and never log bytes or names.

**Files**: `http/logo_upload.zig`, black-box upload tests.

**Validation**: Valid, empty, oversized, truncated, multi-part, discordant, traversal-name, retry, and cleanup cases pass externally.

### Subtask T047: Implement list/detail/filter and resolved endpoints

**Purpose**: Serve manager views with bounded, deterministic, privacy-safe queries.

**Steps**:

1. Parse stable search/status/market/readiness/sort/cursor/limit options.
2. Return bounded lists and detail shapes matching WP01, with deterministic tie-breaking/cursors.
3. Keep remittance masked/absent by default; require deliberate reveal operation if the contract permits it.
4. Serve current resolved configuration with exact provenance/readiness and structural omission rules.
5. Reject out-of-range limits, invalid cursors, unknown filters, and archived/inactive access errors as specified.

**Files**: `http/queries.zig`, `http/resolution.zig`, black-box tests.

**Validation**: Search/filter/order/pagination, mask/reveal, Domestic/Europe/Other, and changed-default/override scenarios pass.

### Subtask T048: Prove black-box mutation durability and concurrency

**Purpose**: Validate externally observable correctness through real HTTP plus storage.

**Steps**:

1. Start the real Zig service on a temporary database and exercise representative create/update/activate/reassign/upload flows.
2. Close/reopen between accepted responses and re-query exact state.
3. Run concurrent idempotency, revision, deactivation/reassignment, and Project activation requests.
4. Fault checkpoint/sync completion and require `durability_unconfirmed`, then confirm original outcome without duplicate event/state.
5. Capture logs and scan all WP08 canaries.

**Files**: `tests/parties_projects/http/durability_*`, `concurrency_*`.

**Validation**: External responses, restart state, one-winner concurrency, replay, and log scans pass.

### Subtask T049: Prove contract/route isolation and HTTP coverage

**Purpose**: Leave an exact boundary for both UI lanes.

**Steps**:

1. Validate every WP01 operation has at least one success and one relevant failure black-box case.
2. Compare generated route inventory to exact P1 module contribution and reject collisions/unclassified routes.
3. Run HTTP-focused, contract, service, persistence, migration-negative, and aggregate gates.
4. Require 90% domain HTTP/application coverage and all enumerated privacy/durability branches.
5. Scan diff for shared router/build/generated edits and forbidden private-layer imports.
6. Record exact P0/P1 pins, commands, route inventory hash, and clean owned-file diff.

**Files**: WP09-owned HTTP tests only.

**Validation**: Coverage map, black-box suite, route isolation, aggregate gates, scans, and `git diff --check` pass.

## Definition of Done

- [ ] Exact P0/WP01/WP07/WP08 evidence precedes edits.
- [ ] Every declared P1 operation has a real handler and black-box tests.
- [ ] P0 envelopes, field errors, revisions, idempotency, and durability map exactly.
- [ ] Uploads are bounded and path/privacy safe.
- [ ] Lists/details/resolution are deterministic and structurally private.
- [ ] Restart/concurrency/uncertainty behavior passes externally.
- [ ] RED/GREEN, route, coverage, and canary evidence pass.
- [ ] No shared router/build/generated or non-owned file changed.

## Risks

- **Transport becomes authority**: handlers only parse/map and call WP07.
- **Mocked black-box claims**: require real served HTTP and real P0 persistence seam.
- **Upload exhaustion**: enforce streaming bounds and cleanup.
- **Route collision**: module discovery and exact inventory are mandatory.

## Reviewer Guidance

Review exact contract-to-route coverage, P0 envelope mappings, black-box purity, multipart bounds, structural privacy, restart/concurrency evidence, generated-route isolation, and forbidden imports. Reject direct repository access or temporary authentication.

---
work_package_id: WP06
title: Parallel-Safe Migration Runner
dependencies:
- WP04
- WP05
requirement_refs:
- FR-009
- FR-010
- NFR-003
- NFR-006
- NFR-009
- C-003
- C-005
tracker_refs: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch.
subtasks:
- T025
- T026
- T027
- T028
- T029
- T030
phase: Phase 3
assignee: ''
agent: codex
history: []
agent_profile: implementer-ivan
authoritative_surface: services/api/src/platform/persistence/migrations
create_intent:
- services/api/migrations/p0/018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f/manifest.json
- services/api/migrations/p0/018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f/up.sql
- services/api/src/platform/persistence/migrations.zig
- services/api/tests/persistence/migrations_test.zig
- services/api/tests/persistence/migrations_integration_test.zig
- services/api/tests/persistence/migrations_digest_vector.json
execution_mode: code_change
model: ''
owned_files:
- services/api/migrations/p0/**
- services/api/src/platform/persistence/migrations*
- services/api/tests/persistence/migrations*
role: implementer
tags: []
task_type: implement
---

# Work Package Prompt: WP06 – Parallel-Safe Migration Runner

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Implement an owner-scoped, forward-only Zig migration runner that discovers migrations
without a shared sequence or registry, verifies immutable descriptor and script content,
plans a deterministic dependency DAG, and records only durably completed applications.

The runner must fail safely when discovery, validation, DDL, checkpointing, or Linux
parent-directory synchronization fails. A successful migration is observable only after
the store reaches `DirectorySynchronized`.

## Context

- WP04 supplies reproducible ShovelerDB consumption and its narrow dependency adapter.
- WP05 supplies the serialized persistence boundary, checkpoint, directory sync, and reopen.
- This package consumes those seams; it must not bypass or broaden them.
- Read `kitty-specs/p0-contract-spine-01KXYY0J/spec.md` for FR-009 and FR-010.
- Read `kitty-specs/p0-contract-spine-01KXYY0J/plan.md`, especially IC-04.
- Read the `MigrationDescriptor` and `AppliedMigration` records in `data-model.md`.
- Read Decisions 7 and 8 in `research.md` before implementing recovery semantics.
- Consume the canonical migration schema from `contracts/migrations/v1/manifest.schema.json`.
- Use UUIDv7 identities; the UUID is not a global sequence and conveys no dependency order.
- Discover descriptors recursively beneath owner-scoped migration roots.
- Dependencies, not timestamps or directory enumeration, determine execution order.
- Use the UUID string only as a deterministic tie-break among simultaneously ready nodes.
- Store `depends_on` in ascending canonical UUID-string order.
- Treat descriptor and script bytes as immutable after application.
- Reject drift instead of repairing, overwriting, renumbering, or silently accepting it.
- P0 owns only the bootstrap schema and generic migration mechanism.
- Do not add invoice, client, project, payment, reporting, authentication, or PDF tables.
- Do not create a shared migration registry, global next-number file, or domain registry.
- Do not implement down migrations or destructive rollback scripts.

## Branch Strategy

- **Strategy**: `wp_branch`
- **Planning base branch**: `feat/p0-contract-spine`
- **Merge target branch**: `feat/p0-contract-spine`
- Begin with the governed implementation action:

```bash
spec-kitty agent action implement WP06 --agent codex
```

- Stay inside the exact `owned_files` patterns from frontmatter.
- Do not edit WP04/WP05 files to make their APIs more convenient.
- Do not edit root build scripts, package scripts, CI, mission state, or task metadata.

## Normative Migration Layout

```text
services/api/migrations/<owner>/<uuid-v7>/manifest.json
services/api/migrations/<owner>/<uuid-v7>/up.sql
```

- The concrete P0 bootstrap ID for this package is
  `018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f`.
- Treat it as a documented bootstrap identity, not as a pattern to copy sequentially.
- The manifest `id` must exactly equal the containing directory name.
- The manifest `owner` must exactly equal the owner directory name.
- `script_path` is exactly `up.sql` for version one.
- `script_digest` is SHA-256 over the exact committed `up.sql` bytes.
- `descriptor_digest` is SHA-256 over canonical descriptor projection bytes.
- The descriptor projection includes only `id`, `owner`, `name`, sorted `depends_on`,
  `script_path`, and `script_digest`.
- The projection explicitly excludes `descriptor_digest` itself.

## Subtasks & Detailed Guidance

### Subtask T025 – Bootstrap Descriptor, Script, and Published Digests

**Purpose**

Create the first real forward migration that bootstraps the migration-history table and
publishes immutable script and descriptor evidence.

**Steps**

1. Create the concrete UUIDv7 directory listed in `create_intent`.
2. Create `up.sql` containing only the P0 bootstrap DDL needed by the generic runner.
3. Create `app_schema_migrations` with storage-compatible columns for:
   - migration ID;
   - owner;
   - descriptor digest;
   - script digest;
   - canonical UTC application instant.
4. Use only compile-time SQL identifiers compatible with the WP04/WP05 safety seam.
5. Do not create feature-domain tables or a table that assigns migration sequence numbers.
6. Keep the script forward-only and omit `down.sql`, rollback DDL, or destructive reset logic.
7. End the SQL file with exactly one LF and document the byte policy in the test.
8. Compute `script_digest` from exact file bytes without newline normalization.
9. Populate `manifest.json` using the canonical version-one migration schema.
10. Set `depends_on` to an empty array for the bootstrap descriptor.
11. Compute the RFC 8785/JCS descriptor bytes from the defined projection.
12. Populate the exact SHA-256 `descriptor_digest` from those canonical bytes.
13. Validate the directory ID, manifest ID, and owner path agree.
14. Make the fixture synthetic and free of client, bank, invoice, or secret material.

**Files**

- `services/api/migrations/p0/018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f/manifest.json`
- `services/api/migrations/p0/018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f/up.sql`

**Validation**

- Validate the manifest against the canonical contract schema.
- Recompute both digests independently in the test suite.
- Fail if an editor changes one byte, including final-newline changes.
- Verify there is no down script and no non-P0 table in the bootstrap SQL.

### Subtask T026 – Recursive Discovery and RFC 8785 Descriptor Hashing

**Purpose**

Discover additive owner migrations without central coordination and convert valid files
into deterministic, immutable in-memory descriptors.

**Steps**

1. Implement recursive discovery in `services/api/src/platform/persistence/migrations.zig`.
2. Accept one or more configured owner roots supplied by the persistence boundary.
3. Walk owner directories recursively without relying on filesystem enumeration order.
4. Select only exact `<uuid-v7>/manifest.json` and declared `up.sql` pairs.
5. Normalize repository-relative paths and reject absolute paths or parent traversal.
6. Reject symlink escapes and files outside the configured migration root.
7. Parse strict JSON and reject unknown or missing descriptor fields.
8. Validate canonical lowercase UUIDv7 IDs and exact owner-directory agreement.
9. Require the manifest directory name to equal the descriptor ID.
10. Require `script_path` to be the relative file name `up.sql`.
11. Require `depends_on` to be unique and lexicographically ascending.
12. Do not silently sort malformed source and accept it; reject noncanonical storage order.
13. Read exact script bytes and verify the declared SHA-256 digest.
14. Build the descriptor projection with only the six normative fields.
15. Sort dependency IDs lexicographically before canonical serialization.
16. Serialize the projection using RFC 8785 JSON Canonicalization Scheme semantics.
17. Hash the exact JCS UTF-8 bytes with SHA-256 and verify `descriptor_digest`.
18. Return stable typed errors for discovery, schema, path, script, and digest failures.
19. Free all parsed paths and buffers on every success and failure branch.

**Files**

- `services/api/src/platform/persistence/migrations.zig`
- Package-owned `migrations*` helper files only when separation is justified.

**Validation**

- Discover the same fixture from deliberately varied directory enumeration orders.
- Assert the resulting descriptor set and diagnostics are byte-identical.
- Reject malformed UUIDs, owner mismatch, directory mismatch, traversal, and symlink escape.
- Reject missing scripts, extra descriptor fields, nonascending dependencies, and bad digests.

### Subtask T027 – DAG Planning, Collisions, Missing Edges, and Cycles

**Purpose**

Produce one deterministic application plan from independently contributed owner migrations,
while rejecting every graph state that could make schema history ambiguous.

**Steps**

1. Index discovered descriptors by canonical UUIDv7 ID in memory only.
2. Reject duplicate IDs even when owner, descriptor, and script bytes are identical.
3. Reject one physical descriptor discovered through multiple normalized paths.
4. Resolve every dependency against the complete discovered descriptor set.
5. Reject a missing dependency before opening or mutating a database handle.
6. Build explicit indegree and adjacency structures for the dependency DAG.
7. Use Kahn-style topological planning or an equivalently auditable algorithm.
8. Select the lexicographically smallest UUID among all currently ready nodes.
9. Never infer edges from UUID timestamp bits, owner names, paths, or discovery order.
10. Detect self-dependencies and multi-node cycles.
11. Return cycle diagnostics containing stable IDs in deterministic order.
12. Keep graph validation pure: no SQL, checkpoints, files, or history mutations.
13. Ensure cross-owner dependencies work without a shared registry edit.
14. Ensure independent owner roots can contribute concurrently.
15. Bound allocations and cleanly report malformed or unexpectedly large graphs.

**Files**

- `services/api/src/platform/persistence/migrations.zig`
- `services/api/tests/persistence/migrations_test.zig`

**Validation**

- Plan a diamond DAG and assert exact deterministic order.
- Plan independent roots and prove UUID is used only as the ready-node tie-break.
- Reject duplicate IDs across two owners.
- Reject missing, self, two-node, and longer cyclic dependencies.
- Assert graph rejection occurs before any persistence call is observed.

### Subtask T028 – Applied-Migration Records and Idempotent Re-runs

**Purpose**

Compare the validated plan with durable history, apply only pending descriptors, and make
identical rediscovery an observable no-op while treating any applied-content drift as fatal.

**Steps**

1. Read applied rows through the serialized WP05 persistence seam.
2. Model an applied record with ID, owner, descriptor digest, script digest, and UTC instant.
3. Validate stored IDs and digests before using them for plan filtering.
4. Reject duplicate applied-history rows or corrupt stored values.
5. Match discovered and applied migrations by exact canonical migration ID.
6. Treat exact owner plus both exact digests as already applied and skip DDL.
7. Reject changed owner, descriptor digest, or script digest as immutable-history drift.
8. Do not repair the row, rewrite the manifest, rerun DDL, or continue past drift.
9. Apply pending descriptors in the deterministic topological order from T027.
10. Record history only as part of the application operation supplied by the storage seam.
11. Store a canonical fixed-millisecond UTC `applied_at` value.
12. Never use `applied_at` to determine future execution order.
13. Return explicit counts for discovered, already applied, newly applied, and rejected.
14. Make a second identical migration run an observable no-op with zero DDL execution.

**Files**

- `services/api/src/platform/persistence/migrations.zig`
- `services/api/tests/persistence/migrations_integration_test.zig`

**Validation**

- Apply the bootstrap migration to an empty temporary store.
- Re-run and assert zero DDL calls and an unchanged applied-history row.
- Reject mutations of ID, owner, descriptor digest, and script digest separately.
- Reopen the store and prove the applied record survives through the application seam.

### Subtask T029 – Failed DDL Discard, Reopen, and Durable Success Boundary

**Purpose**

Honor ShovelerDB's non-transactional DDL behavior by abandoning dirty in-memory state on
failure and acknowledging startup migration completion only after durable synchronization.

**Steps**

1. Run migrations only during startup before traffic readiness.
2. Acquire the single serialized database handle through WP05.
3. Apply one planned migration at a time using the documented migration operation.
4. On any DDL failure, do not checkpoint the dirty handle.
5. Close/discard the dirty uncheckpointed handle using the prerequisite recovery API.
6. Reopen the last durable snapshot before returning the migration failure.
7. Prove the failed descriptor has no durable applied-history row.
8. Prove partial schema effects are absent after reopen.
9. Stop processing all later migrations after the first failure.
10. After the complete set succeeds, checkpoint the committed generation.
11. On Linux, synchronize the database parent directory after checkpoint.
12. Treat only `DirectorySynchronized` as successful migration completion.
13. Do not report ready or serve traffic from merely `Committed` or `Checkpointed` state.
14. Propagate `DurabilityUnconfirmed` when checkpoint or directory sync fails.
15. Retry only persistence completion for an already committed generation.
16. Never replay migration DDL blindly after a committed-but-not-durable result.
17. On unsupported directory-sync semantics, fail readiness instead of weakening guarantees.
18. Leave recovery ownership in WP05; this package orchestrates its public operations only.

**Files**

- `services/api/src/platform/persistence/migrations.zig`
- `services/api/tests/persistence/migrations_integration_test.zig`

**Validation**

- Inject DDL failure after a visible in-memory schema change, then discard and reopen.
- Assert durable schema and applied history exactly match the pre-run snapshot.
- Inject checkpoint failure and directory-sync failure independently.
- Assert neither failure reaches ready or migration-success state.
- Prove the success path ends at `DirectorySynchronized` before acknowledgement.

### Subtask T030 – Negative Matrix and Fixed Digest Vector

**Purpose**

Make migration integrity non-vacuous with a fixed JCS digest vector and data-driven tests
covering every documented collision, graph, mutation, and durability failure branch.

**Steps**

1. Create `services/api/tests/persistence/migrations_digest_vector.json`.
2. Publish descriptor projection input, exact RFC 8785 canonical UTF-8 text,
   exact canonical-byte hex or equivalent byte assertion, and expected SHA-256 digest.
3. Include at least two dependency IDs intentionally supplied in noncanonical test order.
4. Prove the runtime rejects the stored nonlexicographic manifest form.
5. Prove canonical projection sorting yields the published digest vector.
6. Mutate each covered descriptor field separately and require hard failure.
7. Mutate `up.sql` bytes without updating either digest and require script-drift failure.
8. Mutate script bytes plus script digest but retain descriptor digest and require failure.
9. Mutate both digests for an already applied migration and require immutable-history failure.
10. Cover duplicate identity, missing dependency, self-edge, and cycle cases.
11. Cover missing manifest, missing script, malformed JSON, and invalid UUIDv7 cases.
12. Cover owner mismatch, directory mismatch, traversal, and symlink escape cases.
13. Cover DDL, checkpoint, reopen, and directory-sync injected failures.
14. Assert every failure has a stable Zig error or diagnostic category.
15. Assert every error branch releases owned allocations and handles.
16. Keep all fixtures synthetic and deterministic.
17. Exercise each documented error branch regardless of aggregate coverage percentage.
18. Maintain at least 90% automated coverage over migration logic.

**Files**

- `services/api/tests/persistence/migrations_test.zig`
- `services/api/tests/persistence/migrations_integration_test.zig`
- `services/api/tests/persistence/migrations_digest_vector.json`

**Validation**

- Compare the vector with an independent RFC 8785 implementation during review.
- Run unit and real-adapter integration suites separately.
- Run the focused migration-negative command if WP01 exposes it.
- Confirm all negative cases produce zero destructive replacement attempts.

## Test Strategy

Run formatting before tests:

```bash
zig fmt --check services/api/src/platform/persistence/migrations.zig \
  services/api/tests/persistence/migrations_test.zig \
  services/api/tests/persistence/migrations_integration_test.zig
```

Run the service's focused Zig unit tests using WP01/WP04 build wiring:

```bash
zig build test --build-file services/api/build.zig
```

Run the independently diagnosable service and persistence gates:

```bash
npm run api:check
npm run persistence:integration
```

If the build exposes a migration-specific step, also run:

```bash
zig build migration-test --build-file services/api/build.zig
```

- Do not edit root scripts if the optional focused step is absent.
- Record the missing wiring as integration feedback for the owning work package.
- Use real ShovelerDB integration only through WP04/WP05 application seams.
- Use temporary per-test database directories and delete them after handles close.
- Run no-op, failure-reopen, checkpoint, and directory-sync cases repeatedly.
- Verify a failed run never replaces the last durable store.
- Verify `git diff --check` on all package-owned paths.

## Definition of Done

- [ ] T025 bootstrap descriptor and forward-only script are valid and digested.
- [ ] Bootstrap creates only generic P0 migration history.
- [ ] T026 recursively discovers owner migrations without a registry.
- [ ] Dependency arrays are required to be lexicographically ordered.
- [ ] RFC 8785/JCS descriptor hashing matches a fixed published vector.
- [ ] Exact script bytes are hashed without normalization.
- [ ] T027 produces a deterministic DAG plan and rejects every collision/cycle class.
- [ ] UUID is used only as a ready-node tie-break.
- [ ] T028 records both immutable digests and makes exact reruns no-ops.
- [ ] Applied descriptor or script drift is a hard failure.
- [ ] T029 discards dirty DDL state without checkpoint and reopens durable state.
- [ ] Migration success is reported only after `DirectorySynchronized`.
- [ ] Checkpoint and directory-sync failure never make the service ready.
- [ ] T030 covers every documented error branch and at least 90% migration logic.
- [ ] No down migration or destructive reset path exists.
- [ ] No shared sequence, migration registry, or domain registry exists.
- [ ] All focused tests and commands pass.
- [ ] Only frontmatter-owned files changed.

## Risks & Mitigations

- **Ordinary sorted JSON substituted for JCS**: use RFC 8785 semantics and a fixed vector.
- **Descriptor self-reference**: hash the defined projection and exclude only its digest.
- **Editor newline drift**: hash exact script bytes and assert the committed byte vector.
- **Filesystem nondeterminism**: normalize identities, then sort before planning.
- **UUID timestamp mistaken for dependency**: order solely by DAG edges, then tie-break IDs.
- **Shared registry reintroduced**: recursively scan owner roots and reject registry files.
- **Applied content silently changed**: compare owner and both digests before any DDL.
- **DDL failure checkpointed accidentally**: discard dirty handle and reopen durable state.
- **Committed state acknowledged too early**: require checkpoint plus Linux directory sync.
- **Recovery replays DDL**: retry persistence completion only after committed outcomes.
- **Feature schema leaks into P0**: keep bootstrap limited to migration history.
- **Test fakes hide integration behavior**: pair pure unit tests with real-adapter tests.
- **Error paths leak allocations/handles**: use scoped cleanup and allocator checks.

## Reviewer Guidance

- Verify frontmatter ownership before examining behavior.
- Recompute the bootstrap script digest from exact bytes.
- Recompute the descriptor digest from the published RFC 8785 canonical bytes.
- Confirm `depends_on` is stored lexicographically and rejected when unsorted.
- Confirm descriptor digest excludes only `descriptor_digest` itself.
- Confirm recursive discovery needs no root registry or next-number edit.
- Confirm duplicate IDs fail even when their content matches.
- Inspect the ready-node tie-break and prove it does not replace dependency edges.
- Inspect cycle diagnostics for deterministic, actionable identifiers.
- Verify applied records store owner, both digests, and canonical UTC instant.
- Verify an exact rerun performs no DDL and does not rewrite applied history.
- Mutate every covered descriptor and script field after application.
- Confirm each mutation produces hard failure before database changes.
- Trace DDL failure through discard-without-checkpoint and reopen.
- Trace success through Committed, Checkpointed, and DirectorySynchronized.
- Reject approval if Committed or Checkpointed alone is treated as successful.
- Confirm checkpoint or directory-sync failures block readiness.
- Confirm no down migration, reset path, or destructive repair exists.
- Confirm no P1-P8 domain table appears in P0 bootstrap SQL.
- Confirm the suite covers all documented branches and meets the 90% threshold.
- Confirm test logs and fixtures contain only synthetic information.

## Activity Log

> Entries must remain chronological. Append new entries at the end.

- 2026-07-20T07:05:23Z – system – Prompt created for WP06 migration discovery,
  integrity, deterministic planning, durable application, and negative evidence.

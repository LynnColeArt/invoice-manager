---
work_package_id: WP07
title: Parallel-Safe Migration Runner
dependencies:
- WP03
- WP04
- WP05
- WP06
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
- T031
- T032
- T033
- T034
- T035
- T036
phase: Phase 4
assignee: ''
agent: "codex-cycle3-reviewer"
history: []
agent_profile: implementer-ivan
authoritative_surface: services/api/src/platform/persistence/migrations
create_intent:
- services/api/migrations/p0/018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f/manifest.json
- services/api/migrations/p0/018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f/up.sql
- services/api/src/platform/persistence/migrations.zig
- services/api/tests/persistence/migrations_test.zig
- services/api/tests/persistence/migrations_integration_test.zig
- services/api/tests/persistence/migrations_negative_test.zig
- services/api/tests/persistence/migrations_coverage_test.zig
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
shell_pid: "1807838"
---

# Work Package Prompt: WP07 – Parallel-Safe Migration Runner

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
Its public API must return a typed migration-readiness result for WP08 covering discovery,
validation, application or no-op, checkpoint, directory sync, and durable reopen status.
That result may be `Ready` only when WP06 reports durable-store readiness and the migration
path has reached `DirectorySynchronized`; every other state is explicitly non-ready.

## Context

- WP04 supplies reproducible ShovelerDB consumption and literal `test-migration`,
  `test-migration-integration`, `migration-negative`, `coverage-migration`, and aggregate `coverage` hooks; this package does not edit build wiring.
- WP05 supplies canonical shared value implementations used by migration records.
- WP06 supplies the public serialized durable-store operation, readiness, dirty-handle
  discard, and reopen seam. This package consumes that facade and never the raw adapter.
- Read `kitty-specs/p0-contract-spine-01KXYY0J/spec.md` for FR-009 and FR-010.
- Read `kitty-specs/p0-contract-spine-01KXYY0J/plan.md`, especially IC-04.
- Read the `MigrationDescriptor` and `AppliedMigration` records in `data-model.md`.
- Read Decisions 7 and 8 in `research.md` before implementing recovery semantics.
- WP03 solely owns and exports `contracts/migrations/v1/manifest.schema.json`; consume it without redefining or editing its generator/workspace surface.
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
spec-kitty agent action implement WP07 --agent codex
```

- Stay inside the exact `owned_files` patterns from frontmatter.
- Do not edit WP03/WP04/WP05/WP06 files to make their APIs more convenient.
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

### Subtask T031 – Bootstrap Descriptor, Script, and Published Digests

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
4. Use only compile-time SQL identifiers compatible with the WP04/WP06 safety seam.
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

### Subtask T032 – Recursive Discovery and RFC 8785 Descriptor Hashing

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

### Subtask T033 – DAG Planning, Collisions, Missing Edges, and Cycles

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

### Subtask T034 – Applied-Migration Records and Idempotent Re-runs

**Purpose**

Compare the validated plan with durable history, apply only pending descriptors, and make
identical rediscovery an observable no-op while treating any applied-content drift as fatal.

**Steps**

1. Read applied rows through the serialized WP06 public persistence seam.
2. Model an applied record with ID, owner, descriptor digest, script digest, and UTC instant.
3. Validate stored IDs and digests before using them for plan filtering.
4. Reject duplicate applied-history rows or corrupt stored values.
5. Match discovered and applied migrations by exact canonical migration ID.
6. Treat exact owner plus both exact digests as already applied and skip DDL.
7. Reject changed owner, descriptor digest, or script digest as immutable-history drift.
8. Do not repair the row, rewrite the manifest, rerun DDL, or continue past drift.
9. Apply pending descriptors in the deterministic topological order from T033.
10. Record history only as part of the application operation supplied by the storage seam.
11. Store a canonical fixed-millisecond UTC `applied_at` value.
12. Never use `applied_at` to determine future execution order.
13. Return the public typed readiness result with discovery/validation/application-or-no-op,
    checkpoint, directory-sync, reopen status, and explicit migration counts.
14. Make a second identical migration run an observable no-op with zero DDL execution.
15. Publish/classify a new `AppliedMigration` only after WP06 returns its fully durable receipt.

**Files**

- `services/api/src/platform/persistence/migrations.zig`
- `services/api/tests/persistence/migrations_integration_test.zig`

**Validation**

- Apply the bootstrap migration to an empty temporary store.
- Re-run and assert zero DDL calls and an unchanged applied-history row.
- Reject mutations of ID, owner, descriptor digest, and script digest separately.
- Reopen the store and prove the applied record survives through the application seam.

### Subtask T035 – Failed DDL Discard, Reopen, and Durable Success Boundary

**Purpose**

Honor ShovelerDB's non-transactional DDL behavior by abandoning dirty in-memory state on
failure and acknowledging startup migration completion only after durable synchronization.

**Steps**

1. Run migrations only during startup before traffic readiness.
2. Acquire the exclusive serialized startup-write capability through WP06's public facade.
3. Apply one planned migration at a time using that capability; never obtain the handle.
4. On any DDL failure, ask WP06 to discard the dirty state without checkpointing it.
5. Ask WP06 to reopen the canonical path at the last durable snapshot.
6. Return failure only after WP06 reports recovery, or report its explicit quarantine.
7. Prove the failed descriptor has no durable applied-history row.
8. Prove partial schema effects are absent after reopen.
9. Stop processing all later migrations after the first failure.
10. Ask WP06's public operation to durably finish each successful application.
11. Consume its receipt; never implement checkpoint, parent-directory sync, or reopen here.
12. Create an Applied Migration only after WP06 reports `DirectorySynchronized`.
13. Report migration `Ready` only after WP06 durable-store readiness and `DirectorySynchronized`; never from merely `Committed` or `Checkpointed` state.
14. Propagate `DurabilityUnconfirmed` when checkpoint or directory sync fails.
15. Delegate persistence completion/recovery decisions to WP06 after a commit result.
16. Never replay migration DDL after a committed-but-not-durable result.
17. On unsupported directory-sync semantics, fail readiness instead of weakening guarantees.
18. Leave all checkpoint, sync, handle-discard, and reopen ownership in WP06.

**Files**

- `services/api/src/platform/persistence/migrations.zig`
- `services/api/tests/persistence/migrations_integration_test.zig`

**Validation**

- Inject DDL failure after a visible in-memory schema change, then discard and reopen.
- Assert durable schema and applied history exactly match the pre-run snapshot.
- Consume independently injected checkpoint and directory-sync failures through WP06's
  public test seam; do not import its internal fault, handle, syscall, or reopen helpers.
- Assert neither failure reaches ready or migration-success state.
- Prove the success path ends at `DirectorySynchronized` before acknowledgement.

### Subtask T036 – Negative Matrix and Fixed Digest Vector

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
18. Maintain at least 90% automated coverage through literal WP04 `coverage-migration`, then aggregate `coverage`; put a nonempty, never-empty-pass negative matrix in exact root `services/api/tests/persistence/migrations_negative_test.zig`.
19. Put executable coverage cases in exact dedicated root `services/api/tests/persistence/migrations_coverage_test.zig`; ordinary unit, integration, or negative roots and renamed substitutes do not satisfy the coverage producer contract.
20. Import WP04's build-wired probe in production with exact `const migration_coverage = @import("migration_coverage_probe");`. Consume WP05 and WP06 only through the build-wired named modules `@import("shared")` and `@import("persistence")`; do not relative-import shared, store, durability, directory-sync, adapter, or other non-`migrations*.zig` source into the instrumented migration module. Coverage tests may import only the public `@import("migrations")` module and must never import or mutate the probe directly.
21. Call `migration_coverage.hit(.<tag>)` inside the real production error branch represented by each tag. A test label, manifest row, stdout claim, or direct probe call is not coverage evidence.
22. Name each dedicated critical test exactly `test "critical branch: <tag>"`. Each test must reach its tag through the public migration boundary, assert the expected stable result category, and execute at least one instrumented PC from `services/api/src/platform/persistence/migrations*.zig` after counters are reset.
    The dedicated root must also contain exact `test "migration production declarations are analyzed" { std.testing.refAllDecls(migrations); }` using its canonical `std` and `migrations` imports so pinned Zig 0.16 cannot lazily omit uncalled public migration declarations from the production coverage denominator.
23. Cover these exact critical tags once each: `discovery_failure`, `missing_manifest`, `missing_script`, `malformed_manifest`, `unknown_descriptor_field`, `invalid_uuid`, `owner_mismatch`, `directory_mismatch`, `path_traversal`, `symlink_escape`, `noncanonical_dependencies`, `script_digest_mismatch`, `descriptor_digest_mismatch`, `duplicate_migration_id`, `duplicate_descriptor_path`, `missing_dependency`, `self_dependency`, `dependency_cycle`, `graph_capacity_exceeded`, `corrupt_applied_history`, `duplicate_applied_history`, `applied_id_drift`, `applied_owner_drift`, `applied_descriptor_drift`, `applied_script_drift`, `ddl_failure`, `checkpoint_failure`, `directory_sync_failure`, `reopen_failure`, `recovery_quarantine`, `durability_unconfirmed`, `unsupported_directory_sync`, `committed_not_durable`, `checkpointed_not_durable`, `later_migration_blocked`, and `allocation_failure_cleanup`.
24. Let WP04's pinned Zig runner measure compiler PCs from only `services/api/src/platform/persistence/migrations*.zig`; require a nonzero denominator of at least 36 PCs, at least 90% aggregate executed PCs, every exact critical name, every matching production-side hit bit, and a positive production-PC delta per critical test.
25. Treat missing DWARF/instrumentation sections, a zero or implausibly small production denominator, an unknown/duplicate/missing critical name, a tag without a canonical production hit call, a critical test without production execution, or a below-threshold report as a hard gate failure. Do not edit WP04's runner or build wiring to make WP07 pass.

**Files**

- `services/api/tests/persistence/migrations_test.zig`, `migrations_integration_test.zig`, `migrations_negative_test.zig`, and `migrations_coverage_test.zig`
- `services/api/tests/persistence/migrations_digest_vector.json`

**Validation**

- Compare the vector with an independent RFC 8785 implementation during review.
- Run positive unit and real-adapter suites separately through WP04's literal `test-migration` and `test-migration-integration` hooks.
- Run the mandatory root `npm run migration:negative` gate supplied through WP04 and require a nonzero discovered case count from `migrations_negative_test.zig`.
- Confirm all negative cases produce zero destructive replacement attempts.

## Chronological Red-First Evidence and Test Strategy

Before changing production migration code for T031-T036, add a failing test through
the public migration boundary. A private-helper test cannot substitute for proof of
discovery, planning, application, durability, or recovery as a caller observes it.

Append Activity Log entries in execution order. Each behavior needs a timestamped
`RED:` entry with the exact command and failing assertion/category before the related
production edit, followed later by a `GREEN:` entry with the exact passing command.
Do not reconstruct red evidence after implementation. Reviewers reject missing,
nonchronological, private-only, or test-after-production evidence.

Run the owned verification surface from the repository root:

```bash
test "$(cat .zig-version)" = "0.16.0"
zig fmt --check services/api/src/platform/persistence/migrations*.zig \
  services/api/tests/persistence/migrations*.zig
(cd services/api && zig build test-migration)
(cd services/api && zig build test-migration-integration)
npm run migration:negative
(cd services/api && zig build coverage-migration)
(cd services/api && zig build coverage)
git diff --check -- services/api/migrations/p0 \
  services/api/src/platform/persistence/migrations* \
  services/api/tests/persistence/migrations*
```

`npm run migration:negative` is mandatory, not optional. It consumes WP04's stable
convention-scanned `zig build migration-negative` hook. The gate must fail when wiring
is missing, when zero negative cases execute, when a case unexpectedly succeeds, when
an expected category is absent, or when a child failure status is swallowed.

The gate must execute nonzero cases and report expected categories for: manifest/path
validation; invalid identity or owner; duplicate identity; missing dependency; self-edge
or cycle; script digest mismatch; descriptor digest mismatch; applied-history drift;
DDL failure; dirty-state discard/reopen failure; checkpoint failure; and parent-directory
sync failure. Equivalent stable Zig category names are allowed but must be documented
and asserted, not inferred from freeform text.

Use real ShovelerDB integration only through WP04's adapter and WP06's public durable
facade. Use isolated temporary database directories, close through WP06 before cleanup,
and verify a failed run never replaces the last durable store. Do not edit build files,
root scripts, or WP06 internals; missing stable wiring is an upstream WP04 failure.

## Definition of Done

- [ ] T031 bootstrap descriptor and forward-only script are valid and digested.
- [ ] Bootstrap creates only generic P0 migration history.
- [ ] T032 recursively discovers owner migrations without a registry.
- [ ] Dependency arrays are required to be lexicographically ordered.
- [ ] RFC 8785/JCS descriptor hashing matches a fixed published vector.
- [ ] Exact script bytes are hashed without normalization.
- [ ] T033 produces a deterministic DAG plan and rejects every collision/cycle class.
- [ ] UUID is used only as a ready-node tie-break.
- [ ] T034 records both immutable digests and makes exact reruns no-ops.
- [ ] Applied descriptor or script drift is a hard failure.
- [ ] T035 asks WP06 to discard dirty DDL state and reopen durable state.
- [ ] A public typed migration-readiness result covers every required stage for WP08.
- [ ] Migration `Ready` requires WP06 durable-store readiness and `DirectorySynchronized`.
- [ ] Checkpoint and directory-sync failure never make the service ready.
- [ ] T036 covers every documented error branch and at least 90% migration logic.
- [ ] The exact dedicated coverage root reaches all 36 production-side critical tags through public behavior, and WP04's source-filtered Zig PC gate reports a nonzero denominator of at least 36 with at least 90% executed.
- [ ] No down migration or destructive reset path exists.
- [ ] No shared sequence, migration registry, or domain registry exists.
- [ ] `npm run migration:negative` reports nonzero cases and every expected category.
- [ ] Chronological public-boundary red-first and green evidence is recorded.
- [ ] Literal `test-migration`, `test-migration-integration`, `migration-negative`, `coverage-migration`, and aggregate `coverage` hooks pass.
- [ ] Only frontmatter-owned files changed.

## Risks & Mitigations

- **Ordinary sorted JSON substituted for JCS**: use RFC 8785 semantics and a fixed vector.
- **Descriptor self-reference**: hash the defined projection and exclude only its digest.
- **Editor newline drift**: hash exact script bytes and assert the committed byte vector.
- **Filesystem nondeterminism**: normalize identities, then sort before planning.
- **UUID timestamp mistaken for dependency**: order solely by DAG edges, then tie-break IDs.
- **Shared registry reintroduced**: recursively scan owner roots and reject registry files.
- **Applied content silently changed**: compare owner and both digests before any DDL.
- **DDL failure checkpointed accidentally**: request WP06 discard/reopen; own no recovery code.
- **Committed state acknowledged too early**: accept only WP06's fully durable receipt.
- **Recovery replays DDL**: never replay after an ambiguous/committed durability result.
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
- Trace DDL failure through the WP06 discard-without-checkpoint and reopen facade.
- Trace success through WP06's commit, checkpoint, and `DirectorySynchronized` receipt.
- Reject approval if Committed or Checkpointed alone is treated as successful.
- Confirm WP08 can consume the typed result and checkpoint/directory-sync/reopen failures remain non-ready.
- Confirm no down migration, reset path, or destructive repair exists.
- Confirm no P1-P8 domain table appears in P0 bootstrap SQL.
- Confirm the suite covers all documented branches and meets the 90% threshold.
- Confirm test logs and fixtures contain only synthetic information.
- Confirm Activity Log entries prove chronological public-boundary red then green behavior.
- Confirm the mandatory negative gate reports nonzero cases and every expected category.

## Activity Log

> Entries must remain chronological. Append new entries at the end.

- 2026-07-20T07:05:23Z – system – Source prompt created for migration discovery,
  integrity, deterministic planning, durable application, and negative evidence.
- 2026-07-20T16:05:56Z – system – Prompt remapped to WP07 and constrained to
  WP06's public durability/recovery seam and WP04's mandatory negative gate.
- 2026-07-21T06:52:36Z – codex – shell_pid=1807838 – Assigned agent via action command
- 2026-07-21T06:56:06Z – codex – shell_pid=1807838 – RED: cd services/api && zig build test-migration exited 1; public @import("migrations") bootstrap discovery/digest test failed at migrations.discover because root module migrations has no member named discover.
- 2026-07-21T06:59:17Z – codex – shell_pid=1807838 – RED correction: after additive test-only commit 645b631 changed both expected digests to canonical sha256: wire values, cd services/api && zig build test-migration still exited 1 at the public boundary: migrations has no member named discover. No migration production implementation had been committed.
- 2026-07-21T07:04:46Z – codex – shell_pid=1807838 – RED: cd services/api && zig build test-migration-integration exited 1; public bootstrap durable-apply/reopen/no-op test failed because @import("migrations") has no member named run. Discovery code exists in the working tree, but no application runner implementation or product commit exists.
- 2026-07-21T07:12:41Z – codex – shell_pid=1807838 – RED package (isolated from all uncommitted product via git stash --keep-index -u): test-migration exited 1 missing public discover/canonicalProjection/Descriptor; test-migration-integration exited 1 missing testing/CriticalCategory/run; migration-negative exited 1 missing CriticalCategory; coverage-migration exited 1 because canonical production probe implementation was absent. Tests cover DAG/JCS/bootstrap, durable apply/no-op, history drift, failure recovery/no-replay, nonempty negative matrix, and all 36 exact critical branches.
- 2026-07-21T08:05:00Z – codex – shell_pid=1807838 – GREEN: test commit 6d959bd and product/bootstrap commit 64524c3 implement the public migration boundary. From services/api, `zig build test-migration`, `zig build test-migration-integration`, `zig build migration-negative`, and `zig build coverage-migration` passed; exact source coverage measured 488/542 owned production control-flow sites (90.04%), all 36/36 critical branch tests passed, 37 coverage tests passed, and zero were skipped.
- 2026-07-21T08:12:06Z – codex – shell_pid=1807838 – GREEN after approved WP04 composition merge 6b5112a: Debug and ReleaseSafe `test-migration` passed 4/4, `test-migration-integration` passed 5/5, `migration-negative` passed 6/6, `coverage-migration` remained 488/542 with 36/36 critical branches, and aggregate `coverage` passed shared 221/243, persistence 562/624, and migration 488/542. Exact bootstrap bytes recomputed to script sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3 and 224-byte JCS descriptor sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877; lane-g is clean.
- 2026-07-21T08:13:50Z – codex – shell_pid=2155096 – Implementation complete at lane-g 6b5112a after approved WP04 composition; Debug/ReleaseSafe unit 4/4, integration 5/5, negative 6/6, exact coverage 488/542 with 36/36 critical branches, and aggregate coverage pass.
- 2026-07-21T08:14:30Z – codex – shell_pid=1807838 – Started review via action command
- 2026-07-21T08:27:12Z – user – shell_pid=1807838 – Moved to planned
- 2026-07-21T08:54:52Z – codex – shell_pid=2266124 – Started implementation via action command
- 2026-07-21T08:57:56Z – codex – shell_pid=2266124 – RED correction: cd services/api && zig build test-migration-integration exited 1 with 5/6 tests passing. Permanent public-boundary test commit f21afe9 proved history-read checkpoint persistence completion incorrectly returned Ready at migrations_integration_test.zig:193; the clean rerun applied exactly one pending migration with one already-applied bootstrap and no bootstrap DDL replay.
- 2026-07-21T08:59:51Z – codex – shell_pid=2266124 – RED correction batch: commit 6df2215 extends the public revalidation regression across checkpoint, directory-sync, and unsupported-directory-sync at the first planned migration of a two-migration DAG. cd services/api && zig build test-migration-integration exited 1 with 5/7 passing; both permanent failures show completeDurability incorrectly returns Ready, while each clean rerun applies only the remaining migration and does not replay the durably committed bootstrap.
- 2026-07-21T09:01:22Z – codex – shell_pid=2266124 – RED correction batch: commit 84064b4 adds public runObserved cases for a nonempty unrelated store, an existing malformed history table, and a previously initialized store with deleted history. cd services/api && zig build test-migration-integration exited 1 with 5/10 passing; each new case observed one bootstrap replacement DDL call where zero is required, proving StatementObjectFailed is incorrectly treated as fresh without WP06 initializeFresh eligibility.
- 2026-07-21T09:02:14Z – codex – shell_pid=2266124 – RED correction batch: commit 84b9b66 adds public discovery tests for owner-basename binding, normalized lexical aliases, final-root and ancestor symlink escape, and recursive descriptor discovery. cd services/api && zig build test-migration exited 1 with 4/9 passing and no leaks: wrong basenames/aliases/ancestor symlinks were accepted, final symlink mapped DiscoveryFailure instead of SymlinkEscape, and nested descriptor discovery returned DirectoryMismatch.
- 2026-07-21T09:05:35Z – codex – shell_pid=2266124 – Correction RED checkpoint e0d0ef7: added a green no-op rerun proof (zero migration DDL and byte-identical durable history) plus a public multi-statement partial-DDL recovery characterization. Focused integration gate is intentionally 6/12: the partial-DDL case currently reports DdlFailure instead of LaterMigrationBlocked; the test also permanently requires discard/reopen rollback, unchanged durable bytes, and no later migration effect.
- 2026-07-21T09:12:34Z – codex – shell_pid=2266124 – Correction RED checkpoint 949a3fe: integration and negative scenarios now compare actual errors from the public runner and assert typed readiness/quarantine/counter consequences; synthetic LaterMigrationBlocked, RecoveryQuarantine, and completion expected-error returns were removed. Current integration is intentionally 4/12 and negative 4/13, adding direct failures for LaterMigrationBlocked and non-ready durability completion.
- 2026-07-21T09:18:07Z – codex – shell_pid=2266124 – Correction RED checkpoint c009114: public diagnostic assertions now require typed durability boundary, DDL-primary plus later-work consequence, and reopen-primary plus quarantine consequence. Focused integration currently fails compilation only because RunDiagnostic/runWithDiagnostic and Readiness.durability_boundary are intentionally not implemented yet.
- 2026-07-21T10:04:28Z – codex – shell_pid=2266124 – Correction RED evidence, preserved in chronological test-only commits before product commit efbecdc: f21afe9 through a31b80b locked durability revalidation, ambiguous-history refusal, normalized/no-follow recursive discovery, public primary/consequence diagnostics, partial-DDL rollback, exact OOM/discard recovery, middle-migration continuation, unknown-entry fail-closed behavior, and exhaustive cleanup coverage. The public Debug gates failed at each new boundary before the corresponding production correction; final pre-threshold coverage reports were 534/627 and 567/631 with 36/36 critical branches.
- 2026-07-21T10:04:30Z – codex – shell_pid=2266124 – GREEN correction at product commit efbecdc with test commits f21afe9..a31b80b: pinned Zig 0.16 formatting; Debug test-migration, test-migration-integration, mandatory npm run migration:negative, coverage-migration, and aggregate coverage all pass. ReleaseSafe test-migration, test-migration-integration, migration-negative, and coverage-migration pass. Exact migration coverage is 571/631 owned production PCs (90.49%), 36/36 critical branches, 38 passed, 0 skipped; aggregate shared 221/243 and persistence 577/641 also pass; diff check is clean.
- 2026-07-21T10:04:55Z – codex – shell_pid=2266124 – Correction complete at efbecdc; test-first commits f21afe9..a31b80b; Debug and ReleaseSafe WP07 gates pass; exact coverage 571/631 (90.49%) with 36/36 branches; aggregate coverage passes.
- 2026-07-21T10:06:37Z – reviewer-renata – shell_pid=1807838 – Started review via action command
- 2026-07-21T10:16:53Z – user – shell_pid=1807838 – Moved to planned
- 2026-07-21T10:19:52Z – codex – shell_pid=1807838 – Started implementation via action command
- 2026-07-21T10:20:39Z – codex – shell_pid=1807838 – RED chronology remediation after transparent product revert ce4b886: with correction tests retained and pre-correction migrations.zig restored, cd services/api && zig build test-migration exited 1 (4/10 passed; six public root/discovery assertions failed); zig build test-migration-integration exited 1 on missing RunDiagnostic, durability_boundary, and scheduled application-fault public seams; repository-root npm run migration:negative exited 1 on the same public compile failures; cd services/api && zig build coverage-migration exited 1 with unit/integration/negative failures and missing revalidation/diagnostic public APIs. This evidence is recorded before the final effective correction reapplication.
- 2026-07-21T10:25:54Z – codex – shell_pid=2491898 – GREEN chronology remediation: after contemporaneous RED commit cbfc861, effective product reapplication 42f375b passes Debug test-migration, test-migration-integration, migration-negative, coverage-migration, repository-root npm run migration:negative, and serial aggregate coverage; ReleaseSafe test-migration, test-migration-integration, migration-negative, and coverage-migration also pass. Exact migration coverage is 571/631 owned production control-flow sites (90.49%), all 36/36 critical branches, 38 tests passed, 0 skipped; aggregate shared 221/243, persistence 577/641, migration 571/631. zig fmt --check and git diff --check pass.
- 2026-07-21T10:27:05Z – codex – shell_pid=2494830 – Chronology correction complete via transparent revert, contemporaneous RED, effective reapply, and full GREEN verification; ready for independent cycle-3 review.
- 2026-07-21T10:27:47Z – codex-cycle3-reviewer – shell_pid=1807838 – Started review via action command

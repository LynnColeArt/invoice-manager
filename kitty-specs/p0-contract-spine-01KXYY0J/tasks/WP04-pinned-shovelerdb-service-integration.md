---
work_package_id: WP04
title: Pinned ShovelerDB Service Integration
dependencies:
- WP01
requirement_refs:
- FR-011
- FR-012
- NFR-009
- NFR-011
- NFR-012
- C-001
- C-004
- C-005
- C-009
tracker_refs: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch.
subtasks:
- T015
- T016
- T017
- T018
- T019
phase: Phase 2 - Service Dependency Integration
assignee: ''
agent: "codex:gpt-5:implementer-ivan:implementer"
history: []
agent_profile: implementer-ivan
authoritative_surface: deps/shovelerdb/
create_intent:
- services/api/build.zig
- services/api/build.zig.zon
- services/api/src/platform/persistence/shovelerdb.zig
- services/api/tests/persistence/shovelerdb_build_discovery.zig
- services/api/tests/persistence/shovelerdb_integration.zig
- THIRD_PARTY_NOTICES.md
execution_mode: code_change
model: ''
owned_files:
- deps/shovelerdb/**
- services/api/build.zig*
- services/api/src/platform/persistence/shovelerdb*
- services/api/tests/persistence/shovelerdb*
- THIRD_PARTY_NOTICES*
role: implementer
tags: []
task_type: implement
shell_pid: "1807838"
---

# Work Package Prompt: WP04 – Pinned ShovelerDB Service Integration

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## ⚠️ IMPORTANT: Mandatory Red-First and Review Evidence

Before implementation, check `spec-kitty agent status` and the Activity Log for a review reference.
Before each production change, run a failing public-adapter case for persistence, serialization, commit, checkpoint, close/reopen, or literal-encoding security as applicable.
Append chronological `RED:` evidence with case ID, exact command, expected failure, and observed failure; only then change production and append the matching `GREEN:` result.
Private-helper-only, test-after-production, reconstructed, or first-seen-green evidence does not count.
Address every review item and keep remediation evidence chronological before declaring completion.

## Objectives & Success Criteria

Consume the public ShovelerDB repository at exactly commit `fc7539a3874293540a4de6d228b3ea670a8ca2e8` from a clean clone.
Integrate its real C embedding ABI into the Zig `0.16.0` service build through one narrow, replaceable dependency adapter.
Prove borrowed result values are copied before result release, SQL text literals are encoded centrally, and the real engine survives checkpoint, close, and reopen.
Preserve complete GPL-2.0 dependency attribution and immutable source provenance.

Success means no build depends on `/home/lynn/projects/shovelerdb`, another sibling checkout, a private registry, or a floating branch.
Success also means no ShovelerDB handle, result, row, borrowed slice, SQL construction detail, or engine diagnostic leaks beyond the adapter.

## Context & Constraints

This package is the implementation point for plan concern `IC-05`.
It depends only on WP01's pinned repository substrate and Zig `0.16.0` policy.
WP05 and later service packages depend on this stable integration boundary.
As sole `services/api/build.zig` owner, WP04 also publishes every stable Zig
test/coverage hook that later shared, durable-store, migration, and HTTP WPs
consume without editing the build graph.
The canonical upstream repository is `https://github.com/LynnColeArt/ShovelerDB.git`.
The approved public commit is `fc7539a3874293540a4de6d228b3ea670a8ca2e8`.
The approved commit exposes embedding ABI version `0.1.0` in `include/shovelerdb.h`.

At the approved commit, upstream has no `build.zig.zon`, installed consumer module, installed header, or ready-made linkable ABI library.
Treat that as a packaging limitation to bridge narrowly, not permission to import arbitrary engine internals.
Prefer a committed exact-commit source snapshot under `deps/shovelerdb/` with auditable provenance.
Do not use a git submodule unless its required repository metadata is explicitly brought into owned scope by the integration steward.
This WP does not own `.gitmodules`, so an unrecorded gitlink is not an acceptable result.

ShovelerDB's C header is the authoritative connector contract.
The service adapter must compile against the vendored `include/shovelerdb.h` and link the exported ABI implementation.
Do not call internal Zig database, parser, executor, transaction, snapshot, or row-store modules from invoice-manager code.
Do not duplicate upstream ABI declarations manually when Zig `@cImport` can consume the header.

The ABI owns database handles and result memory.
Rows and text, blob, vector, column-name, and detailed-diagnostic views are borrowed from their owning result or handle.
Any data surviving result release or a later ABI call must be copied into invoice-manager-owned memory first.
Every non-null result must be released exactly once on every success and error path.
Every non-null database handle must be closed exactly once.

The engine accepts SQL strings and has no bound-parameter API at this commit.
Only compile-time SQL identifiers and one centralized, tested text-literal encoder are permitted.
Reject embedded NUL bytes.
Do not add a general SQL builder or dynamic identifier encoder.

## Strict Ownership and Scope Boundary

Modify only the five ownership patterns in frontmatter.
The planned authored files are:

- `services/api/build.zig`
- `services/api/build.zig.zon`
- `services/api/src/platform/persistence/shovelerdb.zig`
- `services/api/tests/persistence/shovelerdb_build_discovery.zig`
- `services/api/tests/persistence/shovelerdb_integration.zig`
- `THIRD_PARTY_NOTICES.md`

The vendored upstream snapshot and its provenance evidence belong under `deps/shovelerdb/`.
Do not modify upstream source merely to make integration convenient.
If a patch is genuinely unavoidable, keep it as a separate, documented shim within `deps/shovelerdb/` and prove the pristine source identity independently.

This WP must not create domain records or domain repositories.
Do not create clients, projects, invoices, billing identities, payments, analytics, or document records.
Do not implement a general store, persistence state machine, durability receipt, directory-sync policy, or application service.
Do not create a migration runner, migration descriptors, bootstrap schema, or application tables.
Do not add an HTTP server, route, handler, API envelope, or health endpoint.
Do not add Next.js files, npm dependencies, CI workflows, containers, or deployment configuration.
Do not edit root package files owned by WP01.

The integration test may create one synthetic probe table in a temporary database.
That table is test-only ABI evidence and must not become an application schema.

## Branch Strategy

- **Strategy**: `wp_branch`
- **Planning base branch**: `feat/p0-contract-spine`
- **Merge target branch**: `feat/p0-contract-spine`
- **Dependency base**: accepted WP01 output

Start implementation with:

```bash
spec-kitty agent action implement WP04 --agent codex
```

Allow Spec Kitty to create and manage the dependency-aware WP branch.
Do not manually choose a different base.
Land completed changes back on `feat/p0-contract-spine` unless the human explicitly redirects the merge target.

## Requirement Traceability

- `FR-011`: immutable, clean-clone-consumable storage dependency resolution.
- `FR-012`: one application-owned adapter for transactions, diagnostics, checkpoint, close, and reopen.
- `NFR-009`: no silent fallback, destructive recovery, or substitute engine on failure.
- `NFR-011`: notice and license evidence for every distributed ShovelerDB component.
- `NFR-012`: commit-addressed, reproducible service dependency graph.
- `C-001`: preserve GPL-2.0-only compatibility and notices.
- `C-004`: use only ShovelerDB commit `fc7539a3874293540a4de6d228b3ea670a8ca2e8`.
- `C-005`: one adapter instance owns one handle and serializes calls sharing it.
- `C-009`: build from public repository inputs without sibling paths or private data.

## Subtasks & Detailed Guidance

### Subtask T015 – Pin the Exact Public ShovelerDB Source

- **Purpose**: make the dependency immutable, inspectable, and available from a public clean clone.
- **Source URL**: `https://github.com/LynnColeArt/ShovelerDB.git`.
- **Commit**: `fc7539a3874293540a4de6d228b3ea670a8ca2e8`.
- **Authoritative destination**: `deps/shovelerdb/`.

#### Steps

1. Fetch the public repository into an isolated temporary directory.
2. Resolve the requested revision and assert the resulting `HEAD` equals the full 40-character commit.
3. Reject a tag, branch name, abbreviated hash, or default-branch checkout as the recorded pin.
4. Export a source snapshot from that detached commit into `deps/shovelerdb/` without nested `.git` state.
5. Preserve the upstream `LICENSE`, `include/shovelerdb.h`, ABI implementation sources, and all build-required sources.
6. Exclude caches, build outputs, local databases, editor files, private configuration, and unrelated checkout state.
7. Add machine-readable or plainly parseable provenance under `deps/shovelerdb/` containing the source URL, exact commit, export method, and source-tree digest.
8. Compute the digest deterministically over a sorted path list and file contents; document exclusions.
9. Compare critical ABI files with `git show <commit>:<path>` or a fresh detached checkout.
10. Prove no symlink or build reference escapes the repository to a sibling checkout.

Do not alter the recorded commit when regenerating the snapshot.
If upstream later publishes package metadata, replacing this shim is a separate reviewed change.

#### Validation

- A fresh public fetch resolves the commit.
- The provenance commit matches the required hash byte for byte.
- `include/shovelerdb.h` declares ABI `0.1.0`.
- The source-tree digest is stable across two exports of the same commit.
- `rg` finds no `/home/`, `../shovelerdb`, floating `main`, or private registry dependency in build metadata.

### Subtask T016 – Integrate the Real ABI with the Zig 0.16 Service Build

- **Purpose**: make the real ABI buildable and publish the sole convention-scanned Zig test/coverage surface for every later service WP.
- **Files**: `services/api/build.zig`, `services/api/build.zig.zon`, `services/api/tests/persistence/shovelerdb_build_discovery.zig`, and build-required files under `deps/shovelerdb/`.

#### Steps

1. Write service package metadata compatible with exactly Zig `0.16.0`.
2. Keep dependency resolution local to the committed `deps/shovelerdb/` snapshot.
3. Do not declare a network URL, floating revision, sibling path, or user cache path as the build source of truth.
4. In `services/api/build.zig`, construct the smallest source shim needed to compile upstream `src/abi/c_api.zig` as a linkable library.
5. Give the upstream ABI module access only to its committed source tree and standard library requirements.
6. Expose `deps/shovelerdb/include/` to the invoice adapter for `@cImport`.
7. Link the ABI library into the adapter test artifact.
8. Do not expose upstream `src/lib.zig` as an invoice-manager import.
9. Keep all test-root discovery and named build-step registration in `build.zig`; no later WP may edit it.
10. Scan only the declared service test roots and sort normalized repository-relative paths bytewise before classification.
11. Accept regular `.zig` files only; reject symlinks, escaping paths, hidden/cache/output directories, non-UTF-8 paths, and non-Zig files as roots.
12. Normalize separators to `/` and reject two registrations resolving to the same normalized path.
13. Reject duplicate step names, duplicate logical group/path keys, overlapping root declarations, and one test classified into multiple groups.
14. Reject any discovered `.zig` test beneath a declared root that matches no documented group; never omit it silently.
15. Keep grouping rules explicit and stable:
    - WP04 adapter/integration: `tests/persistence/shovelerdb*`;
    - WP05 shared: `tests/shared/**`;
    - WP06 persistence unit/integration/crash: `tests/persistence/store*`, `durability*`, and `directory_sync*`;
    - WP07 migration: exact positive unit/integration basenames, `*negative*` cases, all migration coverage inputs, and `migrations/p0/**` producer sentinels;
    - WP08 HTTP: `tests/http/**` plus `src/main.zig` and `src/http/**` producer sentinels.
16. Within WP06, classify `*_crash*` before `*_integration*`, then all remaining owned roots as unit tests; ambiguity is an error.
17. Classify exact `migrations_test.zig` as `test-migration`, exact `migrations_integration_test.zig` as `test-migration-integration`, and `*negative*` as `migration-negative`; producer presence makes every group and `coverage-migration` nonempty, with ambiguity/unclassified roots failing.
18. Classify WP05/WP08 roots strictly; make `test-http` depend on exact repository-root `npm run contracts:generate` materialization from WP03 before compiling WP08 source or tests.
19. A producer is present when any owned source/test sentinel for that WP exists; once present, its required root groups may not be empty.
20. Before a producer is present, invoking its hook fails with a precise diagnostic naming the missing path class and owning WP, not success or skip.
21. After a producer is present, missing, empty, duplicate, or unclassified roots fail with the same owner-specific diagnostic discipline.
22. Compile each discovered root with the same target/optimization/module wiring as the service and preserve deterministic execution order.
23. Add an ABI compatibility build assertion that requires runtime/header version `0.1.0`.
24. Preserve target and optimization options so Debug and ReleaseSafe builds exercise the same discovery graph.
25. Keep service build integration here; later WPs add files only inside their owned roots and consume these hooks unchanged.

#### Stable named build steps

Expose these exact names in `zig build --help`:

- `test-shovelerdb-adapter` — adapter unit/lifetime/literal tests;
- `test-shovelerdb-integration` — real ABI filesystem integration;
- `test-build-discovery` — synthetic discovery/classification diagnostics;
- `test-shared` and `coverage-shared` — WP05 shared values and coverage;
- `test-persistence`, `test-persistence-integration`, and `test-persistence-crash` — WP06 persistence groups;
- `coverage-persistence` — WP06 persistence coverage;
- `test-migration`, `test-migration-integration`, `migration-negative`, and `coverage-migration` — distinct WP07 positive, negative, and coverage gates;
- `test-http` — WP08 HTTP/route-policy tests, after exact `npm run contracts:generate` materialization;
- `coverage` — aggregate shared/persistence/migration coverage, requiring at least 90% migration logic and every enumerated critical branch;
- `test` — aggregate service test gate in deterministic group order.

WP01's root `migration:negative` command delegates to `zig build
migration-negative --build-file services/api/build.zig`. WP04 must not edit the
root package to add that delegation. A missing delegation is reported to WP01;
the Zig step remains mandatory and must never become optional or empty-success
once WP07 producer sentinels exist.

Diagnostics must name the stable step, expected root/pattern, owning WP, and
observed count or duplicate paths. Do not print absolute checkout paths. Do not
silently fall back to an in-memory fake, skip a category, or turn a missing
producer into a passing aggregate.

Use Zig 0.16 build APIs as installed, not code copied from older Zig documentation.
Fail clearly if the vendored header, source entry point, or expected ABI symbols are missing.

#### Validation

From `services/api/`, run:

```bash
zig version
zig fmt --check build.zig src/platform/persistence/shovelerdb.zig tests/persistence/shovelerdb_integration.zig
zig build
zig build test-build-discovery
zig build test-shovelerdb-adapter
zig build test-shovelerdb-integration
zig build -Doptimize=ReleaseSafe test-shovelerdb-integration
zig build --help
```

The first command must report `0.16.0`.
The integration executable must contain and call real `shovelerdb_*` ABI symbols.
A missing vendored source must fail the build with a dependency-specific message.

In `shovelerdb_build_discovery.zig`, construct synthetic directory layouts and
prove canonical ordering is unchanged by creation order. Cover every exact step
name, exact WP07 positive basenames, all valid groups, missing producer roots,
producer-present/zero-tests, duplicate/overlapping/unclassified roots, symlink
escape, and absolute-path redaction. Assert every WP07 positive/negative/coverage
group becomes nonempty, `test-http` materializes via exact `npm run contracts:generate`
before compilation, and aggregate `test`/`coverage` order and failures propagate.

### Subtask T017 – Implement the Narrow Borrow-Safe Adapter and Literal Encoder

- **Purpose**: isolate the C ABI, enforce resource ownership, and provide the only permitted dynamic SQL text encoding path.
- **File**: `services/api/src/platform/persistence/shovelerdb.zig`.

#### Adapter rules

1. Import `shovelerdb.h` with `@cImport`.
2. Keep opaque C database, result, and row handles private to this module.
3. Let one adapter instance own exactly one non-null database handle.
4. Serialize all calls sharing that handle with a narrow synchronization guard.
5. Prevent use after close and make cleanup safe on partially initialized instances.
6. Release each ABI result with `shovelerdb_result_release` on all paths.
7. Close the handle once with `shovelerdb_close`.
8. Offer only dependency-level operations needed by this package: open/create, execute, checkpoint, close, ABI version, and diagnostic translation.
9. Represent transaction control only by executing compile-time `BEGIN`, `COMMIT`, and `ROLLBACK` statements through the ABI.
10. Do not add domain CRUD, repositories, migration discovery, durability acknowledgment, or application schema knowledge.

Result materialization must copy column names and every selected value before releasing the result.
Copy text bytes, blob bytes, and vector elements into caller-owned allocations.
Copy detailed engine diagnostics only into a non-production test assertion seam using synthetic sentinels.
Represent null, integer, float, boolean, text, blob, and `vector_f32` distinctly.
Provide deterministic deinitialization for every owned aggregate.
Use `errdefer` or equivalent structured cleanup so allocation failure cannot leak results or partial copies.

Map upstream statuses into a small stable dependency-error category.
Production logs/diagnostics may contain only that stable category plus correlation metadata; forbid raw engine prose, SQL, paths, values, and sensitive/user data.
Inject distinctive SQL/path/value sentinels and prove none reaches production logs or public diagnostics; never translate engine failure into success.

#### Literal encoder rules

Implement one text-literal encoder in this module.
It must surround output with single quotes and double every embedded single quote.
It must reject embedded NUL before emitting a partial literal.
It must preserve semicolons, `--`, `/* */`, backslashes, forward slashes, Unicode UTF-8, tabs, carriage returns, and newlines as literal content.
It must not accept a table name, column name, keyword, ordering expression, or arbitrary SQL fragment.
All identifiers remain compile-time constants reviewed in source.

Required exact cases include:

- empty input becomes `''`;
- `O'Reilly` becomes `'O''Reilly'`;
- `a'; DROP TABLE wp04_probe; --` remains one quoted literal with its quote doubled;
- `/* comment */; -- comment` remains quoted data;
- a Unicode and newline sample round-trips byte-for-byte through the engine;
- any input containing `0x00` returns the stable embedded-NUL error and emits no usable SQL.

### Subtask T018 – Prove Clean-Clone and Real-ABI Integration

- **Purpose**: distinguish a real embedded-engine integration from a compiling mock or sibling-checkout accident.
- **File**: `services/api/tests/persistence/shovelerdb_integration.zig`.

Use a temporary directory and a unique synthetic database path per test.
Use only synthetic values such as `wp04_probe`, `alpha`, and `O'Reilly`.
Remove temporary artifacts through defer-based cleanup.
Never read or write a developer database.

The real-ABI suite must:

1. assert header/runtime ABI version `0.1.0`;
2. open or create a filesystem-backed database through the adapter;
3. create a test-only table using compile-time SQL identifiers;
4. begin a transaction through the documented ABI execution path;
5. insert scalar and hostile-looking text values through the literal encoder;
6. commit and verify the mutation result kind/count;
7. select rows and materialize owned results;
8. release the underlying ABI result before asserting copied column and value bytes;
9. checkpoint, close, reopen, and verify the committed synthetic rows persist;
10. begin a second transaction, insert a sentinel, roll back, and prove it is absent;
11. trigger typed errors and prove stable categorization while SQL/path/value sentinels never reach production logs or public diagnostics;
12. exercise text, blob, and vector borrowed views when supported by the probe schema;
13. run under an allocation-checking test allocator and report zero leaks;
14. prove cleanup after an intermediate allocation or execution failure;
15. prove calls sharing one adapter handle are serialized or rejected deterministically.

Do not mock any `shovelerdb_*` symbol in this integration suite.
Do not import upstream internal Zig modules from the test.
Do not claim Linux parent-directory-sync or the full durable-acknowledgment state machine here; that belongs to the durable storage package.
Checkpoint/reopen in WP04 proves the real engine boundary only.

For clean-clone evidence, copy or clone the invoice repository into an isolated path with no sibling ShovelerDB checkout.
Initialize no private registries and clear dependency path overrides.
Run the pinned Zig build and both named ShovelerDB test steps.
Search build logs and cache metadata for absolute references to the developer checkout.
Repeat after deleting `services/api/.zig-cache` and repository-local Zig output.

### Subtask T019 – Record Notices and License Evidence

- **Purpose**: preserve the provenance and GPL obligations of the distributed engine source.
- **Files**: `THIRD_PARTY_NOTICES.md` and upstream license/provenance files under `deps/shovelerdb/`.

Add a concise ShovelerDB notice containing:

- component name;
- public source URL;
- exact commit `fc7539a3874293540a4de6d228b3ea670a8ca2e8`;
- the license identity supported by the upstream `LICENSE` evidence;
- the repository-relative path to the preserved full license text;
- whether the source is unmodified or which packaging shim files are invoice-manager-authored;
- a statement that the source snapshot is distributed with the application.

Preserve the complete upstream `LICENSE` file verbatim.
Compare its digest with the same file at the pinned commit.
Do not replace the full license with an SPDX identifier or short notice.
Do not add legal claims unsupported by the upstream source.
Do not include author email, access tokens, private URLs, or local paths.

Add a focused notice verification step to the service build if it can remain within owned files.
The check must fail if the notice omits the source URL, full commit, license path, or preserved license file.

## Test Strategy

Run checks independently so failures remain diagnosable.
The minimum acceptance sequence is:

```bash
test "$(cat .zig-version)" = "0.16.0"
git diff --check -- deps/shovelerdb services/api/build.zig services/api/build.zig.zon services/api/src/platform/persistence services/api/tests/persistence THIRD_PARTY_NOTICES.md
cd services/api
zig fmt --check build.zig src/platform/persistence/shovelerdb.zig tests/persistence/shovelerdb_integration.zig
zig build test-shovelerdb-adapter
zig build test-shovelerdb-integration
zig build -Doptimize=ReleaseSafe test-shovelerdb-integration
```

Run the literal encoder cases as focused Zig tests before the engine suite.
Run the real integration from an empty temporary database at least twice.
Run the clean-clone check with the sibling `/home/lynn/projects/shovelerdb` path unavailable.
Record the resolved source commit, source-tree digest, Zig version, ABI version, and test commands in the Activity Log.

Negative checks must prove:

- a changed provenance commit is rejected;
- a missing vendored ABI header or source fails the build;
- an ABI version mismatch fails before storage use;
- embedded NUL is rejected;
- borrowed values are not exposed after result release;
- diagnostic SQL/path/value sentinels are neither leaked nor silently replaced or retried;
- no alternate in-memory store activates when ShovelerDB fails;
- notice validation fails when required attribution is absent.

## Risks & Mitigations

- **Upstream package metadata is absent**: keep the service build shim minimal, local, and replaceable; do not fork engine behavior.
- **A source snapshot drifts from its recorded commit**: verify deterministic tree digest and critical files against a detached public checkout.
- **The build accidentally uses a sibling checkout**: test in a clean clone and scan configuration/cache metadata for absolute paths.
- **Zig build APIs differ from older examples**: implement and verify only with pinned Zig `0.16.0`.
- **Borrowed ABI values outlive results**: copy all outward values before a single structured release point and test after release.
- **Error cleanup leaks C results or Zig allocations**: use defer/errdefer and an allocation-checking test allocator.
- **SQL injection enters through string concatenation**: expose one literal encoder, reject NUL, and keep identifiers compile-time constants.
- **The adapter expands into a general store**: restrict it to ABI lifecycle, execution, owned result materialization, and diagnostic mapping.
- **Concurrency violates handle rules**: serialize calls inside one adapter and keep the raw handle private.
- **License evidence is incomplete**: preserve the full upstream license and verify the notice against the exact commit.

## Definition of Done

- [ ] `deps/shovelerdb/` is an auditable export of public commit `fc7539a3874293540a4de6d228b3ea670a8ca2e8`.
- [ ] No dependency path references a sibling checkout, floating branch, private registry, or unpublished source.
- [ ] The service build uses Zig `0.16.0` and links the real ShovelerDB C ABI.
- [ ] `build.zig` exposes every exact stable adapter/shared/persistence/migration/HTTP/coverage/service step named in T016.
- [ ] Discovery is canonically ordered and rejects duplicate, overlapping, escaping, or unclassified roots with owning-WP diagnostics.
- [ ] Distinct WP07 positive/negative/coverage gates are nonempty, and aggregate coverage includes migration at 90% plus every critical branch.
- [ ] Later service WPs can add owned tests and consume hooks without editing `build.zig`.
- [ ] Header and runtime ABI versions are checked as `0.1.0`.
- [ ] The adapter is the only invoice-manager import of ShovelerDB ABI details.
- [ ] Opaque handles and borrowed views never escape the adapter.
- [ ] Every result and handle is released exactly once on all tested paths.
- [ ] The literal encoder passes empty, quote, semicolon, comment, slash, Unicode, newline, and NUL cases.
- [ ] Real integration proves transaction, rollback, diagnostics, checkpoint, close, reopen, and owned result copies.
- [ ] Debug and ReleaseSafe integration builds pass from a clean clone without a sibling ShovelerDB repository.
- [ ] `THIRD_PARTY_NOTICES.md` records source, exact commit, license identity, license path, and modification status.
- [ ] The full upstream license is preserved and digest-checked against the pin.
- [ ] No domain record, general store, migration runner, application API, or feature behavior was added.
- [ ] Only paths matched by WP04 ownership changed.
- [ ] The Activity Log proves chronological public-adapter RED-before-production-before-GREEN commands and outcomes.

## Review Guidance

Review chronological public-adapter red-first evidence before dependency pin and adapter ergonomics.
Independently resolve the full commit from the public GitHub repository.
Confirm the committed source and preserved license match that revision.
Compare `zig build --help` with T016 and run the synthetic discovery diagnostic matrix.
Reject missing-producer success, silent skips, unstable ordering, or a second build-step registry.
Confirm WP01 `migration:negative` delegates to the mandatory Zig step without WP04 editing root metadata.
Reject any build that works only because a sibling checkout or developer cache is present.
Confirm service code uses the C embedding ABI rather than upstream internal Zig modules.
Trace every C result through success, error, and allocation-failure cleanup.
Verify copied text/blob/vector data remains valid after result release.
Exercise literal encoding with hostile-looking but valid text and embedded NUL.
Confirm production logs/public diagnostics contain only stable category/correlation metadata and reject raw engine prose, SQL, paths, values, or sensitive data.
Confirm checkpoint/reopen proof does not claim the later directory-sync durability guarantee.
Reject domain tables, repository abstractions, migration orchestration, or application routes in this package.
Run the real integration with the sibling ShovelerDB checkout unavailable.
Review `THIRD_PARTY_NOTICES.md` and the complete upstream license as acceptance-critical artifacts.

## Activity Log

> Append entries at the bottom in chronological order using `YYYY-MM-DDTHH:MM:SSZ – agent_id – action`.

- 2026-07-20T07:06:04Z – system – Prompt created for WP04 pinned ShovelerDB service integration.
- 2026-07-20T19:15:40Z – codex:gpt-5:implementer-ivan:implementer – shell_pid=1807838 – Assigned agent via action command

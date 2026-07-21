---
work_package_id: WP08
title: Zig Health and Route-Policy Boundary
dependencies:
- WP03
- WP05
- WP06
- WP07
requirement_refs:
- FR-002
- FR-004
- FR-006
- FR-015
- NFR-007
- NFR-009
- C-003
tracker_refs: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch.
subtasks:
- T037
- T038
- T039
- T040
- T041
phase: Phase 4 - Application Boundaries
assignee: ''
agent: "codex-wp08-shutdown-proof-fix"
history: []
agent_profile: implementer-ivan
authoritative_surface: services/api/src/http/
create_intent:
- services/api/src/main.zig
- services/api/src/http/root.zig
- services/api/src/http/server.zig
- services/api/src/http/health.zig
- services/api/src/http/envelope.zig
- services/api/src/http/error_mapping.zig
- services/api/src/http/route_policy.zig
- services/api/src/http/route_inventory.zig
- services/api/tests/http/health_test.zig
- services/api/tests/http/envelope_test.zig
- services/api/tests/http/route_policy_test.zig
- services/api/tests/http/black_box_test.zig
- services/api/tests/http/health_performance_test.zig
- services/api/tests/http/startup_readiness_test.zig
execution_mode: code_change
model: ''
owned_files:
- services/api/src/main.zig
- services/api/src/http/**
- services/api/tests/http/**
role: implementer
tags: []
task_type: implement
shell_pid: "1807838"
---

# Work Package Prompt: WP08 – Zig Health and Route-Policy Boundary

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

Then begin through the governed runtime surface:

```bash
spec-kitty agent action implement WP08 --agent codex
```

---

## ⚠️ IMPORTANT: Review Feedback

Before editing, query WP08 status and read every referenced reviewer finding.
Treat unresolved findings as required owned work, append remediation evidence
chronologically, and move state only through Spec Kitty commands.

## Objective

Deliver the real Zig 0.16 service boundary for `GET /api/v1/health`, canonical
success/error envelopes, and protected-by-default route classification. Prove
the process never becomes ready until the configured store opens and all startup
migrations complete successfully.

P0 success is intentionally boring: one explicitly public health operation,
no feature APIs, and black-box evidence that the backend contract is real.

## Context and Constraints

- WP03's literal `npm run contracts:generate` solely writes the canonical runtime inventory at `tools/contracts/.generated/runtime/v1/route-inventory.json`.
- WP04's `test-http` hook must run that exact materializer before compiling any WP08 Zig source or test.
- WP08 reads, parses, and embeds only that artifact through its public route-inventory boundary; it never writes generated output or maintains a second registry.
- WP05 owns RequestId and other canonical Zig shared values.
- WP06 owns the migration-agnostic durable store and its typed readiness result.
- WP07 owns migration discovery/application and its separate typed readiness result.
- Consume those implementations; do not copy, weaken, or edit their authoritative files.
- The API major prefix is `/api/v1`.
- The only P0 operation is `GET /api/v1/health`, operation ID `P0Health`.
- Health is public only because the generated effective access metadata records WP03's validated OpenAPI/module-policy agreement.
- Missing, invalid, or mismatched access metadata is protected for enforcement.
- Protected-by-default is a route-policy classification rule, not authentication implementation.
- Do not create credentials, sessions, tokens, users, middleware, or authorization behavior.
- Success responses contain `data` and `meta.request_id` only.
- Failure responses contain `error` and `meta.request_id` only.
- Field failures use JSON Pointer paths plus stable code and safe message.
- Every response request ID must satisfy WP05's canonical RequestId type.
- Do not disclose database paths, engine diagnostics, stack traces, or raw request bodies.
- Traffic must not bind or accept before both WP06 durable-store readiness and WP07 migration readiness succeed.
- Startup failure must not activate an in-memory fallback, replace a corrupt store, or serve false readiness.
- WP08's black-box boundary is the real Zig service exercised by `test-http`.
  The repository-level Next.js proxy smoke belongs to WP10 and is not a WP08
  implementation or acceptance dependency.
- Use the repository-pinned Zig 0.16 APIs; do not add compatibility branches for older Zig releases.
- All fixtures, temporary paths, logs, and request bodies must be synthetic.

## Scope Boundary

Modify only `services/api/src/main.zig`, `services/api/src/http/**`, and
`services/api/tests/http/**`. Do not edit contracts, composition tooling,
shared values, persistence/migration source, service build files, root scripts,
web code, CI, task metadata, or status logs.
Do not create, rewrite, delete, normalize, or copy generated contract artifacts.

P0 must not add billing identity, client, project, invoice, payment, remittance,
logo, recurrence, reporting, PDF, authentication, or other domain routes.

## Branch Strategy

- **Strategy**: `wp_branch`
- **Planning base**: `feat/p0-contract-spine`
- **Merge target**: `feat/p0-contract-spine`
- **Dependency base**: accepted WP03, WP05, WP06, and WP07 outputs.

Let Spec Kitty resolve the worktree base. Do not manually retarget the branch,
merge unrelated work, or bypass the implement-review lane.

## Requirement Traceability

- `FR-002`: run a real healthy Zig business-service boundary.
- `FR-004`: emit canonical success, error, field-failure, and correlation shapes.
- `FR-006`: consume a collision-checked route inventory rather than overwriting routes silently.
- `FR-015`: expose independently runnable service and HTTP checks.
- `NFR-007`: at least 99 of 100 ready local health requests finish within one second.
- `NFR-009`: storage, migration, and contract failures have no silent or destructive fallback.
- `C-003`: the Zig service owns authoritative request and readiness behavior.

## Subtasks and Detailed Guidance

### Subtask T037 – Start the Service and Implement the Health Endpoint

**Purpose**: Create a minimal production-shaped Zig entry point and the single
P0 HTTP operation without introducing feature behavior.

**Steps**:

1. Create `services/api/src/main.zig` as a thin composition root.
2. Parse only infrastructure startup configuration: bind address, port, and database path.
3. Reject missing, malformed, or unsafe configuration with a nonzero exit and safe diagnostic.
4. Keep secrets and business settings out of P0 startup configuration.
5. Create `services/api/src/http/root.zig` as the narrow HTTP export surface.
6. Create `services/api/src/http/server.zig` for listener lifecycle and request dispatch.
7. Require an opaque ready context created by `main.zig` only after both dependency readiness results succeed before constructing or starting the listener.
8. Keep HTTP modules independent of persistence internals; only the composition root may call WP06/WP07 public seams.
9. Use the standard or already-pinned HTTP implementation; do not add an unapproved dependency.
10. Bound request-line, header, and body sizes and reject malformed input deterministically.
11. Implement exactly `GET /api/v1/health` in `services/api/src/http/health.zig`.
12. When ready, respond `200` with JSON `{data:{status:"ready"},meta:{request_id}}`.
13. Set the correct JSON content type and deterministic response encoding.
14. Generate a canonical RequestId for every request; do not trust an inbound value as authority.
15. Return the same request ID in success or failure metadata for that request.
16. Keep health data limited to `status: "ready"`; expose no path, version, migration, or storage detail.
17. Reject unsupported methods and unknown paths through T038 error mapping.
18. Shut the listener down cleanly and release all request allocations and handles.

**Files**:

- `services/api/src/main.zig`
- `services/api/src/http/root.zig`
- `services/api/src/http/server.zig`
- `services/api/src/http/health.zig`
- `services/api/tests/http/health_test.zig`

**Validation**:

- Handler tests assert status, content type, closed shape, canonical RequestId, and exact ready value.
- Repeated requests receive individually valid IDs without reused mutable buffers.
- POST health and unknown paths never execute the health handler.
- Leak checks pass across success, disconnect, parse failure, and shutdown.

### Subtask T038 – Implement Standard Envelopes and Safe Error Mapping

**Purpose**: Give every JSON response one stable P0 shape while preventing
internal Zig, migration, and ShovelerDB details from becoming public contracts.

**Steps**:

1. Create `services/api/src/http/envelope.zig` with typed success and failure writers.
2. Emit exactly one of `data` or `error`, always with `meta.request_id`.
3. Keep success envelopes generic enough for health without adding domain payloads.
4. Define error bodies with stable snake-case `code` and safe `message`.
5. Represent optional field failures as `{path, code, message}`.
6. Validate field `path` as a logical JSON Pointer before serialization.
7. Create `services/api/src/http/error_mapping.zig` as the only public error translation table.
8. Map malformed HTTP/JSON input to a stable 400-class response.
9. Map an unknown route to 404 and unsupported method to 405.
10. Map controlled not-ready state to 503 with the canonical error envelope.
11. Map unexpected internal failures to a generic 500 response.
12. Never include raw engine prose, filesystem paths, SQL, stack traces, or request bodies.
13. Preserve internal typed errors for logs/tests without exposing them on the wire.
14. Bound error message and field-list output so hostile input cannot amplify responses.
15. Serialize deterministically and reject allocation/writer failure without partial second responses.

**Files**:

- `services/api/src/http/envelope.zig`
- `services/api/src/http/error_mapping.zig`
- `services/api/tests/http/envelope_test.zig`

**Validation**:

- Validate success, 400, 404, 405, 500, and 503 examples against WP03's OpenAPI schemas.
- Assert every response contains one canonical request ID.
- Assert data/error mutual exclusion and rejection of extra members.
- Inject diagnostic strings and prove none appears in public response bytes.

### Subtask T039 – Enforce the Composed Route Inventory and Access Policy

**Purpose**: Make actual dispatch agree with WP03's deterministic contract
inventory and ensure no route becomes public by omission or typo.

**Steps**:

1. Create `services/api/src/http/route_inventory.zig` as the sole public load/parse/query boundary for immutable runtime route records.
2. Embed exactly `../../../../tools/contracts/.generated/runtime/v1/route-inventory.json` once with `@embedFile`; no other WP08 module may read or embed generated files.
3. Parse only WP03's closed version-one shape: `format_version: 1` plus routes containing exactly `path`, lowercase `method`, `operation_id`, `owner`, `mount_key`, and `access`.
4. Reject missing input at compile time and invalid JSON, wrong version/type, missing/unknown fields, invalid normalization/access, or duplicate method/path and operation IDs at the boundary.
5. Treat an inventory as stale when its operation IDs do not agree one-for-one with the compiled handler bindings; reject stale, missing, or extra bindings before listening.
6. Bind code to inventory operations only by `operation_id`; derive method, path, owner, mount, and access solely from the parsed artifact, never a handwritten mirror.
7. Create `services/api/src/http/route_policy.zig` for access classification only.
8. Treat missing, unknown, malformed, or mismatched access metadata as protected.
9. Permit public dispatch only when the canonical artifact's validated effective access is explicitly `public`; do not recreate module policy in Zig.
10. Assert `P0Health` is the sole public P0 operation and maps to GET `/api/v1/health`.
11. Do not implement login, token verification, session lookup, principals, roles, or permissions.
12. For protected synthetic mutation cases, prove the target handler is never invoked.
13. Fail startup on route-inventory contract drift rather than guessing or silently dropping routes.
14. Keep generated inventories ignored and read-only; tests may mutate owned in-memory/temporary copies only, never the canonical artifact.
15. Before route-policy/dispatch production changes, add a failing public-boundary test driven by WP03 composed metadata and the actual dispatch entry point.
16. Use stable cases for public health, missing/invalid metadata becoming protected, manifest/OpenAPI disagreement, and protected-handler non-invocation.
17. Record the case ID, exact repository-root `zig build test-http --build-file services/api/build.zig` command, expected failure, and observed red result in the Activity Log before the production change.
18. After implementation, append the matching green command/result chronologically; do not rewrite or reorder the red entry.
19. Direct tests of a private classifier, mocked composed metadata, or tests first observed green do not satisfy red-first evidence.

**Files**:

- `services/api/src/http/route_inventory.zig`
- `services/api/src/http/route_policy.zig`
- `services/api/tests/http/route_policy_test.zig`

**Validation**:

- Accept the exact composed P0 health inventory.
- Reject missing, stale, invalid, duplicate, missing-handler, extra-handler, and public-policy disagreement cases through the public boundary.
- Starting from freshly materialized bytes, mutate method/path/operation/access in isolated copies and prove actual dispatch/policy changes or startup fails; no private-only parser assertion counts.
- Add an undeclared synthetic route and prove default-protected behavior without authentication code.
- Prove red-first cases traverse composed metadata, route resolution, and dispatch far enough to observe handler invocation or non-invocation.
- Reviewer-visible Activity Log evidence must show red before production behavior and green afterward for each critical case.

### Subtask T040 – Prove the Boundary Black-Box and Meet Health Performance

**Purpose**: Exercise the listening process over TCP so handler-only tests
cannot create a vacuous architecture gate.

**Steps**:

1. Create `services/api/tests/http/black_box_test.zig` that starts the real service on loopback.
2. Allocate an ephemeral port and isolated temporary database path per test.
3. Start the process with successful WP06 durable-store and WP07 migration readiness dependencies.
4. Wait for explicit process readiness with a bounded timeout; never use an arbitrary long sleep.
5. Send a real GET request to `/api/v1/health` and parse the complete response.
6. Validate status, headers, body, RequestId, envelope shape, and connection completion.
7. Exercise unknown path, unsupported method, malformed request, and client disconnect cases.
8. Prove no invoice-manager domain route exists in the P0 inventory.
9. Create `services/api/tests/http/health_performance_test.zig` for NFR-007.
10. Warm the ready local process before measurement and use a monotonic clock.
11. Issue exactly 100 measured local requests using the reference Debug/ReleaseSafe mode selected by CI.
12. Require all 100 responses to be valid ready responses.
13. Require at least 99 response durations to be at or below 1,000 milliseconds.
14. Record min, median, p99, maximum, mode, and failure count without machine-specific absolute paths.
15. Keep the test bounded and independently runnable through the exact repository-root
    `zig build test-http --build-file services/api/build.zig` command.
16. Shut down the child process and remove temporary data on every success/error path.

**Files**:

- `services/api/tests/http/black_box_test.zig`
- `services/api/tests/http/health_performance_test.zig`

**Validation**:

- Prove the test fails if routing bypasses the real listener or returns a fabricated body.
- Prove the 99-of-100 threshold counts invalid responses as failures.
- Repeat `zig build test-http --build-file services/api/build.zig` twice and
  confirm no leaked process, port, or store remains.

### Subtask T041 – Couple Startup Readiness to Store Open and Migrations

**Purpose**: Prevent a listening or healthy service from masking an unusable,
unmigrated, corrupt, or durability-uncertain persistence state.

**Steps**:

1. Create `services/api/tests/http/startup_readiness_test.zig` around the real composition root.
2. Keep `main.zig` as the composition root; HTTP modules must not import WP06 or WP07 internals.
3. Validate configuration before creating, binding, listening on, or accepting from any socket.
4. Initialize/open the configured store only through WP06's public durable-store seam.
5. Require WP06's typed durable-store readiness result before advancing startup.
6. Treat open/corruption, handle/serialization, checkpoint, directory-sync, and unsupported-filesystem failures as not ready.
7. Pass only WP06's public store seam into WP07's public migration discovery/application seam.
8. Require WP07's typed migration readiness result after validated discovery, application or no-op, and durable completion.
9. Keep readiness false for missing migration dependencies, cycles, duplicate identities, descriptor/script digest drift, DDL failure, and propagated durability failure.
10. Construct the opaque HTTP ready context and listener only after both typed readiness results succeed.
11. Do not create, bind, listen on, accept from, or announce a ready socket before both results succeed.
12. Do not return `200 ready` from merely opened, committed, checkpointed, or migration-applied state.
13. Inject each WP06 and WP07 failure class and prove nonzero exit, no listening port, no readiness log, and no fallback.
14. Use a bounded connection probe to prove failed startup leaves the configured address unbound rather than serving 200 or 503.
15. On failure, close/discard only through public dependency seams and preserve the last durable store snapshot.
16. Never delete, replace, truncate, reset, silently recreate, or substitute an in-memory/alternate store.
17. Never replay migration DDL blindly after a committed-but-not-durable result.
18. Keep public startup diagnostics stable and safe; retain detailed typed causes only internally.
19. Test the direct not-ready handler as canonical 503 even though process-level startup keeps the port closed.
20. On normal shutdown, stop accepting work before closing the store through its public seam.
21. Do not absorb WP06 durable-store or WP07 migration-runner implementation into this package.

**Files**:

- `services/api/src/main.zig`
- `services/api/src/http/server.zig`
- `services/api/src/http/health.zig`
- `services/api/tests/http/startup_readiness_test.zig`

**Validation**:

- A new temporary store applies the bootstrap migration, becomes ready, and returns 200.
- A second startup observes a migration no-op and becomes ready.
- Every injected WP06 store-readiness failure exits nonzero with the configured address unbound.
- Every injected WP07 migration-readiness failure exits nonzero with the configured address unbound.
- No failure case emits readiness, serves 200/503, activates fallback storage, or mutates the last durable snapshot destructively.
- Reopen after failed DDL or durability completion proves the last durable store remains usable and was not replaced.

## Test Strategy and Commands

Run from the repository root with the dependency-resolved worktree:

```bash
zig version
npm run contracts:generate
zig fmt --check services/api/src/main.zig services/api/src/http services/api/tests/http
zig build test-http --build-file services/api/build.zig
zig build test-http --build-file services/api/build.zig
zig build test --build-file services/api/build.zig
npm run api:check
```

The first command must report `0.16.0`. The service build/test commands must
consume WP03/WP05/WP06/WP07 through their public seams rather than copying their
files. Every Zig HTTP compilation must follow literal materialization; WP04's
`test-http` must enforce that dependency itself. If the stable hook is missing,
report that dependency integration defect to its owner and do not edit
`services/api/build.zig` from WP08.

Mandatory test classes:

- handler-level health and error-envelope tests;
- red-first composed-route dispatch cases and protected-default mutations;
- freshly materialized inventory mutation cases proving runtime dispatch/policy observes changed metadata;
- missing/stale/invalid/duplicate inventory and one-to-one handler-binding rejection;
- black-box TCP success and failure requests;
- 100-request ready-path performance evidence;
- WP06 durable-store and WP07 migration readiness success/no-op results;
- injected store-open/corruption, checkpoint, directory-sync, and unsupported-filesystem failures;
- injected migration dependency, cycle, duplicate, digest-drift, DDL, and durability failures;
- bounded proof that every startup failure leaves the configured address unbound;
- allocation, disconnect, shutdown, and sensitive-diagnostic cleanup.

Before handoff, run `git diff --check`, `git status --short`, and
`git diff --name-only`; every changed path must match WP08 ownership.

## Definition of Done

- [ ] `main.zig` composes configuration, persistence/migrations, and HTTP without domain behavior.
- [ ] GET `/api/v1/health` is the sole P0 operation and returns exact ready data.
- [ ] Every success and failure uses the canonical envelope and RequestId.
- [ ] Error mapping exposes stable safe codes/messages and no internal details.
- [ ] Composed routes and actual handlers agree exactly before startup.
- [ ] One public boundary embeds/parses only the canonical generated inventory after materialization.
- [ ] Missing, stale, invalid, duplicate, or independently mirrored route metadata fails closed.
- [ ] Duplicate, missing, extra, or mismatched route bindings fail closed.
- [ ] Only explicitly agreed `P0Health` metadata is public.
- [ ] Missing or invalid access metadata is protected by default.
- [ ] No authentication implementation or invoice-manager domain API was added.
- [ ] Black-box tests exercise the real listener, parser, dispatch, and writer.
- [ ] All 100 performance responses are valid; at least 99 finish within one second.
- [ ] `main.zig` consumes WP06 and WP07 typed readiness results only through public seams.
- [ ] Socket construction, bind, listen, accept, and ready announcement follow both successful results.
- [ ] Injected WP06 and WP07 failures exit nonzero with no bound port or fallback store.
- [ ] Failed startup preserves the last durable snapshot and emits no false readiness.
- [ ] Direct controlled not-ready response is canonical HTTP 503.
- [ ] Process and resource cleanup passes success, error, disconnect, and shutdown cases.
- [ ] Zig formatting, service tests, API checks, and the focused `test-http`
      boundary pass independently, including two consecutive `test-http` runs.
- [ ] Route-policy Activity Log evidence records public-boundary red before matching green.
- [ ] Only WP08-owned files changed and all Activity Log evidence is chronological.

## Risks and Mitigations

- **Vacuous health test**: exercise the spawned listener, not only a handler function.
- **Premature readiness**: require both typed dependency results before socket construction, bind, listen, accept, or ready announcement.
- **Dependency seam bypass**: compose WP06 and WP07 public APIs in `main.zig`; keep HTTP modules free of persistence internals.
- **Permissive policy fallback**: map missing or invalid metadata to protected.
- **Vacuous route-policy test**: drive WP03 composed metadata through route resolution and actual dispatch with chronological red-first evidence.
- **Accidental authentication scope**: classify protected routes without building auth machinery.
- **Contract/runtime drift**: compare composed inventory and handler bindings at startup.
- **Generated-registry fork**: allow only WP03's materializer to write the canonical artifact; WP08 embeds it once and binds handlers by operation ID.
- **Diagnostic leak**: centralize safe error mapping and test hostile internal strings.
- **Request ID reuse**: create one owned canonical ID per request and test concurrent lifetimes.
- **Performance flakiness**: use loopback, monotonic time, bounded warmup, and the explicit 99/100 rule.
- **Destructive recovery**: fail closed on corrupt/open/migration errors; never reset or substitute storage.
- **Partial response**: buffer bounded envelopes or track writer state to avoid a second response.
- **Ownership collision**: route build, contracts, shared values, and migration changes to their owners.
- **Feature creep**: assert the inventory contains no P0 domain routes.

## Reviewer Guidance

Review the real wire bytes against WP03's OpenAPI and route-policy artifacts.
Do not approve based only on direct handler tests.

Confirm specifically:

- `main.zig` consumes WP06 store readiness and WP07 migration readiness through public seams;
- no socket is constructed, bound, listened on, accepted from, or announced ready before both results succeed;
- injected WP06 and WP07 failures exit nonzero with the configured address unbound;
- startup failures emit no readiness and cause no destructive replacement or fallback;
- health is the sole public operation and exactly matches `P0Health` metadata;
- literal materialization precedes compilation, and the canonical artifact is embedded only through the public route-inventory boundary;
- malformed, duplicate, or stale inventory fails before listening, while isolated metadata mutations change real dispatch/policy behavior;
- omitted, invalid, or mismatched access policy fails protected;
- red-first evidence exercises composed metadata, route resolution, and actual dispatch before matching green evidence;
- no authentication/session/token/principal implementation appears;
- success and all mapped failures contain one canonical RequestId;
- internal errors and paths never reach response bodies;
- black-box tests traverse a real loopback socket and spawned service;
- the 100-request measurement counts every invalid/slow response honestly;
- handler/inventory mismatch prevents startup;
- no domain API or out-of-scope file was added.

Reject implementations that hardcode a permissive public route table independent
of WP03, write generated files, maintain a second registry, test only a private policy classifier, bind before both readiness
results, fake performance at handler level, or treat a storage/migration failure
as healthy degraded operation.

## Activity Log

> Append entries in chronological UTC order. Include agent, exact commands,
> route-policy red/green case IDs and results, route/test counts, readiness
> failure matrix, performance statistics, reviewer remediation, and dependency
> coordination.

No implementation entries yet.

### Updating Status

Use `spec-kitty agent tasks move-task WP08 --to <status>`; never edit status
events or frontmatter state by hand.
- 2026-07-21T10:38:55Z – codex-wp08-implementer – shell_pid=1807838 – Assigned agent via action command
- 2026-07-21T11:24:36Z – codex-wp08-implementer – shell_pid=1807838 – RED WP08-ROUTE-POLICY-001: exact repository-root command 'zig build test-http --build-file services/api/build.zig' materialized fresh canonical inventory (format_version=1, routes=1), mutated owned in-memory P0Health access public->protected, traversed actual dispatch, and failed as expected: handler_calls expected 0, observed 1; 5/6 HTTP tests passed and only this qualifying case failed. Test commit 6a63d78 precedes route-policy enforcement.
- 2026-07-21T11:48:08Z – codex-wp08-implementer – shell_pid=1807838 – Refined route-policy RED at commit f58f651 after approved WP04 inventory mapping. Exact repository-root command: zig build test-http --build-file services/api/build.zig. Result: RED, 12/14 passed. WP08-ROUTE-POLICY-001 expected handler_calls=0, observed=1 for a protected canonical metadata mutation; invalid-effective-access case expected handler_calls=0, observed=1. Parser, binding, and isolated method/path/operation mutation cases were green. No route_policy production enforcement existed.
- 2026-07-21T11:52:22Z – codex-wp08-implementer – shell_pid=1807838 – Matching route-policy GREEN at product commit febfd2d. Exact repository-root command: zig build test-http --build-file services/api/build.zig. Result: GREEN, 14/14 passed. WP08-ROUTE-POLICY-001 protected canonical metadata and invalid-effective-access mutations both stopped before the actual handler; handler_calls=0. Canonical inventory parsing, one-to-one bindings, and method/path/operation drift tests also passed.
- 2026-07-21T14:06:28Z – codex-wp08-implementer – shell_pid=1807838 – FINAL GREEN WP08 integration at lane tip 54f90ed after approved WP04/WP05/WP07 corrections. Product/test commits 438e397, 6a63d78, ea0c4ee, f58f651, 4079342, febfd2d, 4774d2e, 4e881eb, 108e946, 75904ab, 21d2740, 2a46be8, 31ebb16, 2361349 implement the real health listener, canonical envelopes, inventory-bound protected-default dispatch, typed store/migration readiness, fail-closed startup, bounded parsing, graceful SIGINT/SIGTERM shutdown, snapshot preservation, and slow-client deadline proof. Exact root command zig build test-http --build-file services/api/build.zig passed twice in Debug with 100/100 valid responses and zero failures: median/p99/max 281/356/358 us and 273/339/341 us. Exact ReleaseSafe command zig build -Doptimize=ReleaseSafe test-http --build-file services/api/build.zig passed 100/100 with median/p99/max 198/247/250 us. Exact zig build test --build-file services/api/build.zig --summary all passed 12/12 deterministic groups; integrated HTTP was 100/100 with median/p99/max 276/316/319 us. Exact zig build coverage --build-file services/api/build.zig --summary all passed: shared 221/243 plus 24/24 critical branches, persistence 577/641 plus 20/20, migration 571/631 plus 36/36. Exact npm run api:check passed with final HTTP 100/100, median/p99/max 277/336/339 us. zig fmt --check services/api/build.zig services/api/src services/api/tests and git diff --check passed. T041 causal startup matrix covers store open/corruption/checkpoint/directory-sync/unsupported-filesystem and migration dependency/cycle/duplicate/digest/DDL/lease/transaction/executor/recovery/quarantine/reopen failures: every case exits nonzero before bind/readiness, preserves seeded durable snapshots, and activates no fallback.
- 2026-07-21T14:07:53Z – codex-wp08-implementer – shell_pid=1807838 – WP08 lane tip cbb08ff fully green; code tip 54f90ed; final evidence 22fded6
- 2026-07-21T14:08:03Z – codex-wp08-cycle1-reviewer – shell_pid=1807838 – Started review via action command
- 2026-07-21T14:25:17Z – user – shell_pid=1807838 – Moved to planned
- 2026-07-21T14:25:27Z – codex-wp08-shutdown-proof-fix – shell_pid=1807838 – Started implementation via action command

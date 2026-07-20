---
work_package_id: WP08
title: Zig Health and Route-Policy Boundary
dependencies:
- WP03
- WP05
- WP06
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
agent: codex
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

- WP03 owns composed OpenAPI, module route policy, and deterministic route inventory evidence.
- WP05 owns RequestId and other canonical Zig shared values.
- WP06 owns migration discovery, validation, application, and failure semantics.
- Consume those implementations; do not copy, weaken, or edit their authoritative files.
- The API major prefix is `/api/v1`.
- The only P0 operation is `GET /api/v1/health`, operation ID `P0Health`.
- Health is public only because both OpenAPI metadata and module policy declare it public.
- Missing, invalid, or mismatched access metadata is protected for enforcement.
- Protected-by-default is a route-policy classification rule, not authentication implementation.
- Do not create credentials, sessions, tokens, users, middleware, or authorization behavior.
- Success responses contain `data` and `meta.request_id` only.
- Failure responses contain `error` and `meta.request_id` only.
- Field failures use JSON Pointer paths plus stable code and safe message.
- Every response request ID must satisfy WP05's canonical RequestId type.
- Do not disclose database paths, engine diagnostics, stack traces, or raw request bodies.
- Traffic must not begin before store open and migrations reach their successful completion boundary.
- Startup failure must not activate an in-memory fallback, replace a corrupt store, or serve false readiness.
- Use the repository-pinned Zig 0.16 APIs; do not add compatibility branches for older Zig releases.
- All fixtures, temporary paths, logs, and request bodies must be synthetic.

## Scope Boundary

Modify only `services/api/src/main.zig`, `services/api/src/http/**`, and
`services/api/tests/http/**`. Do not edit contracts, composition tooling,
shared values, persistence/migration source, service build files, root scripts,
web code, CI, task metadata, or status logs.

P0 must not add billing identity, client, project, invoice, payment, remittance,
logo, recurrence, reporting, PDF, authentication, or other domain routes.

## Branch Strategy

- **Strategy**: `wp_branch`
- **Planning base**: `feat/p0-contract-spine`
- **Merge target**: `feat/p0-contract-spine`
- **Dependency base**: accepted WP03, WP05, and WP06 outputs.

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
7. Use the standard or already-pinned HTTP implementation; do not add an unapproved dependency.
8. Bound request-line, header, and body sizes and reject malformed input deterministically.
9. Implement exactly `GET /api/v1/health` in `services/api/src/http/health.zig`.
10. When ready, respond `200` with JSON `{data:{status:"ready"},meta:{request_id}}`.
11. Set the correct JSON content type and deterministic response encoding.
12. Generate a canonical RequestId for every request; do not trust an inbound value as authority.
13. Return the same request ID in success or failure metadata for that request.
14. Keep health data limited to `status: "ready"`; expose no path, version, migration, or storage detail.
15. Reject unsupported methods and unknown paths through T038 error mapping.
16. Shut the listener down cleanly and release all request allocations and handles.

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

1. Create `services/api/src/http/route_inventory.zig` for immutable runtime route records.
2. Include method, normalized path, operation ID, access classification, and handler key.
3. Consume WP03's composed route inventory/build evidence; do not create a second source registry.
4. Require exact agreement between the composed inventory and registered handlers at startup.
5. Reject duplicate method/path, operation ID, or handler bindings before listening.
6. Reject an inventory operation with no handler and a handler with no contract operation.
7. Create `services/api/src/http/route_policy.zig` for access classification only.
8. Treat missing, unknown, malformed, or mismatched access metadata as protected.
9. Permit public dispatch only when composed metadata and module policy explicitly agree.
10. Assert `P0Health` is the sole public P0 operation and maps to GET `/api/v1/health`.
11. Do not implement login, token verification, session lookup, principals, roles, or permissions.
12. For protected synthetic mutation cases, prove the target handler is never invoked.
13. Fail startup on route-inventory contract drift rather than guessing or silently dropping routes.
14. Keep generated inventories ignored; never commit a generated aggregate from tests.

**Files**:

- `services/api/src/http/route_inventory.zig`
- `services/api/src/http/route_policy.zig`
- `services/api/tests/http/route_policy_test.zig`

**Validation**:

- Accept the exact composed P0 health inventory.
- Reject duplicates, missing handlers, extra handlers, and public-policy disagreement.
- Mutate health metadata to missing/invalid and prove it becomes protected, never public.
- Add an undeclared synthetic route and prove default-protected behavior without authentication code.

### Subtask T040 – Prove the Boundary Black-Box and Meet Health Performance

**Purpose**: Exercise the listening process over TCP so handler-only tests
cannot create a vacuous architecture gate.

**Steps**:

1. Create `services/api/tests/http/black_box_test.zig` that starts the real service on loopback.
2. Allocate an ephemeral port and isolated temporary database path per test.
3. Wait for explicit process readiness with a bounded timeout; never use an arbitrary long sleep.
4. Send a real GET request to `/api/v1/health` and parse the complete response.
5. Validate status, headers, body, RequestId, envelope shape, and connection completion.
6. Exercise unknown path, unsupported method, malformed request, and client disconnect cases.
7. Prove no invoice-manager domain route exists in the P0 inventory.
8. Create `services/api/tests/http/health_performance_test.zig` for NFR-007.
9. Warm the ready local process before measurement and use a monotonic clock.
10. Issue exactly 100 measured local requests using the reference Debug/ReleaseSafe mode selected by CI.
11. Require all 100 responses to be valid ready responses.
12. Require at least 99 response durations to be at or below 1,000 milliseconds.
13. Record min, median, p99, maximum, mode, and failure count without machine-specific absolute paths.
14. Keep the test bounded and independently runnable through the HTTP smoke command.
15. Shut down the child process and remove temporary data on every success/error path.

**Files**:

- `services/api/tests/http/black_box_test.zig`
- `services/api/tests/http/health_performance_test.zig`

**Validation**:

- Prove the test fails if routing bypasses the real listener or returns a fabricated body.
- Prove the 99-of-100 threshold counts invalid responses as failures.
- Repeat the smoke test twice and confirm no leaked process, port, or store remains.

### Subtask T041 – Couple Startup Readiness to Store Open and Migrations

**Purpose**: Prevent a listening or healthy service from masking an unusable,
unmigrated, corrupt, or durability-uncertain persistence state.

**Steps**:

1. Create `services/api/tests/http/startup_readiness_test.zig` around the real composition root.
2. In `main.zig`, validate configuration before opening any listener.
3. Open the configured ShovelerDB file through the dependency-provided application adapter.
4. Discover and validate the complete WP06 migration set before serving traffic.
5. Apply pending startup migrations through WP06's runner.
6. Treat the runner's successful durable completion/no-op result as a readiness prerequisite.
7. Bind or accept traffic only after store open and migration success are both confirmed.
8. Keep readiness false for missing dependencies, cycles, digest drift, DDL failure, checkpoint failure, directory-sync failure, corrupt store, and open failure.
9. On failure, stop startup, close/discard according to the dependency contract, and exit nonzero.
10. Never delete, replace, truncate, reset, or silently recreate a corrupt configured store.
11. Never switch to an in-memory or alternate backend.
12. Never replay migration DDL blindly after a committed-but-not-durable result.
13. Do not return `200 ready` from merely opened, committed, or checkpointed state.
14. Keep public startup diagnostics stable and safe; retain detailed typed causes only internally.
15. Test the direct not-ready handler as canonical 503 even when process-level startup policy keeps the port closed.
16. On normal shutdown, stop accepting work before closing the store through its supported seam.
17. Do not absorb WP07 durability state-machine implementation into this package.

**Files**:

- `services/api/src/main.zig`
- `services/api/src/http/server.zig`
- `services/api/src/http/health.zig`
- `services/api/tests/http/startup_readiness_test.zig`

**Validation**:

- A new temporary store applies the bootstrap migration, becomes ready, and returns 200.
- A second startup observes a migration no-op and becomes ready.
- Every injected open/migration/durability failure exits nonzero without a listening ready service.
- Reopen after failed DDL proves the last durable store was not destructively replaced.

## Test Strategy and Commands

Run from the repository root with the dependency-resolved worktree:

```bash
zig version
zig fmt --check services/api/src/main.zig services/api/src/http services/api/tests/http
zig build test --build-file services/api/build.zig
npm run api:check
npm run http:smoke
```

The first command must report `0.16.0`. The service build/test commands must
consume WP03/WP05/WP06 rather than copying their files. If the build graph lacks
an HTTP test hook, report that dependency integration defect to its owner; do
not edit `services/api/build.zig` from WP08.

Mandatory test classes:

- handler-level health and error-envelope tests;
- composed route inventory and protected-default mutations;
- black-box TCP success and failure requests;
- 100-request ready-path performance evidence;
- real store-open and startup-migration success/no-op;
- store, migration, checkpoint, and directory-sync startup failures;
- allocation, disconnect, shutdown, and sensitive-diagnostic cleanup.

Before handoff, run `git diff --check`, `git status --short`, and
`git diff --name-only`; every changed path must match WP08 ownership.

## Definition of Done

- [ ] `main.zig` composes configuration, persistence/migrations, and HTTP without domain behavior.
- [ ] GET `/api/v1/health` is the sole P0 operation and returns exact ready data.
- [ ] Every success and failure uses the canonical envelope and RequestId.
- [ ] Error mapping exposes stable safe codes/messages and no internal details.
- [ ] Composed routes and actual handlers agree exactly before startup.
- [ ] Duplicate, missing, extra, or mismatched route bindings fail closed.
- [ ] Only explicitly agreed `P0Health` metadata is public.
- [ ] Missing or invalid access metadata is protected by default.
- [ ] No authentication implementation or invoice-manager domain API was added.
- [ ] Black-box tests exercise the real listener, parser, dispatch, and writer.
- [ ] All 100 performance responses are valid; at least 99 finish within one second.
- [ ] Store open and migration completion precede traffic readiness.
- [ ] Corrupt/open/migration/durability failures produce no ready listener or fallback store.
- [ ] Direct controlled not-ready response is canonical HTTP 503.
- [ ] Process and resource cleanup passes success, error, disconnect, and shutdown cases.
- [ ] Zig formatting, service tests, API checks, and HTTP smoke pass independently.
- [ ] Only WP08-owned files changed and Activity Log evidence is chronological.

## Risks and Mitigations

- **Vacuous health test**: exercise the spawned listener, not only a handler function.
- **Premature readiness**: open store and complete migrations before binding/accepting traffic.
- **Permissive policy fallback**: map missing or invalid metadata to protected.
- **Accidental authentication scope**: classify protected routes without building auth machinery.
- **Contract/runtime drift**: compare composed inventory and handler bindings at startup.
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

- the process cannot report ready before store open and migration completion;
- startup failures exit nonzero without destructive replacement or fallback;
- health is the sole public operation and exactly matches `P0Health` metadata;
- omitted, invalid, or mismatched access policy fails protected;
- no authentication/session/token/principal implementation appears;
- success and all mapped failures contain one canonical RequestId;
- internal errors and paths never reach response bodies;
- black-box tests traverse a real loopback socket and spawned service;
- the 100-request measurement counts every invalid/slow response honestly;
- handler/inventory mismatch prevents startup;
- no domain API or out-of-scope file was added.

Reject implementations that hardcode a permissive public route table independent
of WP03, bind before readiness, fake performance at handler level, or treat a
storage/migration failure as healthy degraded operation.

## Activity Log

> Append entries in chronological UTC order. Include agent, exact commands,
> route/test counts, readiness failure matrix, performance statistics, reviewer
> remediation, and dependency coordination.

No implementation entries yet.

### Updating Status

Use `spec-kitty agent tasks move-task WP08 --to <status>`; never edit status
events or frontmatter state by hand.

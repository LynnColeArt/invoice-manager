---
work_package_id: WP03
title: Composable Contract and Lifecycle Tooling
dependencies:
- WP01
- WP02
requirement_refs:
- FR-004
- FR-005
- FR-006
- FR-007
- FR-008
- FR-015
- NFR-002
- NFR-003
- NFR-004
- NFR-009
- NFR-010
- C-007
tracker_refs: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch.
subtasks:
- T008
- T009
- T010
- T011
- T012
- T013
- T014
phase: Phase 2 - Shared Contracts
assignee: ''
agent: "codex:gpt-5:node-norris:implementer"
shell_pid: "1807838"
history:
- at: '2026-07-20T07:01:00Z'
  actor: system
  action: Prompt generated via /spec-kitty.tasks
agent_profile: node-norris
authoritative_surface: contracts/
create_intent:
- contracts/api/v1/base.openapi.yaml
- contracts/events/v1/envelope.schema.json
- contracts/events/v1/catalog.schema.json
- contracts/modules/v1/schema.json
- contracts/modules/p0/module.json
- contracts/manifests/v1/schema.json
- contracts/migrations/v1/manifest.schema.json
- contracts/manifests/drafts/p0.json
- contracts/conformance/p0-p4-inputs.json
- contracts/fixtures/p0/v1/valid/module-pair.json
- contracts/fixtures/p0/v1/invalid/module-duplicate-mount.json
- contracts/fixtures/p0/v1/valid/lifecycle-draft.json
- contracts/fixtures/p0/v1/invalid/lifecycle-frozen-pending-digest.json
- tools/contracts/.gitignore
- tools/contracts/src/main.ts
execution_mode: code_change
model: ''
owned_files:
- contracts/api/**
- contracts/events/**
- contracts/modules/**
- contracts/manifests/drafts/p0.json
- contracts/manifests/v1/**
- contracts/migrations/**
- contracts/fixtures/p0/v1/valid/module-*
- contracts/fixtures/p0/v1/invalid/module-*
- contracts/fixtures/p0/v1/valid/lifecycle-*
- contracts/fixtures/p0/v1/invalid/lifecycle-*
- contracts/conformance/**
- tools/contracts/.gitignore
- tools/contracts/src/**
- tools/contracts/tests/**
- tools/contracts/.generated/**
role: implementer
tags: []
task_type: implement
---

# Work Package Prompt: WP03 – Composable Contract and Lifecycle Tooling

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter,
and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `node-norris`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for
this work package's `task_type` and `authoritative_surface`.

Run `spec-kitty agent action implement WP03 --agent codex` before implementation.
Confirm WP01 and WP02 are available before relying on their repository shell or values.

---

## Objective

Build the deterministic contract-composition and lifecycle-validation toolchain that makes
parallel feature missions additive instead of registry-driven.

The result must turn the P0 Draft planning contracts into canonical repository contracts,
validate their lifecycle evidence against real files, compose owner contributions without
committed generated aggregates, and fail safely on every defined collision or mutation.

This package owns contract mechanics only. It does not implement invoice, client, project,
payment, reporting, authentication, PDF, or deployment behavior.

## Context and Normative Inputs

- Treat mission `spec.md`, `plan.md`, `data-model.md`, and `research.md` as requirements,
  strategy, lifecycle semantics, and rationale respectively.
- Treat every file in `kitty-specs/p0-contract-spine-01KXYY0J/contracts/` as a Draft input.
- Preserve the canonical common-schema ID supplied by WP02.
- Use JSON Schema 2020-12 and OpenAPI 3.1.
- Use Node/TypeScript only inside the package-owned contract tool surface.
- Keep paths normalized, root-relative, slash-separated; reject absolute, traversing,
  duplicate-normalized, or escaping-symlink paths.
- Never fetch a schema over the network during validation or composition.
- Never hand-maintain a global owner, route, event, schema, or migration registry.
- Discover owner contributions by deterministic convention scans beneath `contracts/`, sort by
  semantic identity, and prove byte-identical composition across two runs.
- Resolve conformance only from committed full-commit/digest pins; never inspect a current or
  moving branch head, tag, `HEAD`, sibling checkout, or working-tree version as input.
- Do not commit composed OpenAPI, route inventories, schema bundles, or generated TypeScript.

## Branch and Ownership Boundaries

- Planning base: `feat/p0-contract-spine`.
- Merge target: `feat/p0-contract-spine`.
- Work only in paths matched by `owned_files` in the frontmatter.
- Do not edit any package manifest, root lock, application code, CI, or downstream mission file.
- WP01 is the sole immutable owner of root and workspace npm metadata, command wiring, and lock.
- Consume WP01's root `package-lock.json` as-is; this package must not edit or regenerate it.
- Consume WP01's `tools/contracts/package.json` export and scripts as-is; do not recreate it.
- WP02 owns common values and their cross-runtime fidelity.
- If a missing root script or ignore rule blocks acceptance, record an integration request.
- Do not cross the ownership boundary merely to make a command look convenient.
- WP03 owns `tools/contracts/.gitignore`, `src/**`, `tests/**`, and `.generated/**` only.
- WP03 is the sole writer of generated TypeScript at
  `tools/contracts/.generated/typescript/v1/` and the deterministic runtime route inventory at
  `tools/contracts/.generated/runtime/v1/route-inventory.json`.
- Those exact versioned destinations are ignored build outputs; no alternate writer or copy is allowed.
- A clean validation run must leave tracked files byte-for-byte unchanged.

## Required Deliverables

- Canonical P0-health OpenAPI plus event, module, lifecycle, and migration schemas/manifests.
- Draft P0 lifecycle manifest at `contracts/manifests/drafts/p0.json` using the canonical shape.
- Committed immutable P1-P4 conformance-input lock with exact provenance and digests.
- Valid/invalid fixtures and a deterministic CLI rooted at `tools/contracts/src/main.ts`.
- Version-one generated bindings satisfying WP01's predeclared stable package export.

## Test-First Evidence Order

- Before production logic, record named red/green lifecycle, protected-default route, and
  deterministic collision cases with exact commands and intended failures in the Activity Log.

## T008 — Canonical Lifecycle, Content Identity, and State Gate

### Implementation

- Create `contracts/manifests/v1/schema.json` with a stable canonical `$id`.
- Create `contracts/manifests/drafts/p0.json` from the P0 Draft planning manifest.
- Do not create canonical `contracts/manifests/p0.json`; WP12 alone promotes the accepted Draft.
- Preserve `baseline_commit` as the exact planning base, never the manifest publication commit.
- Model states exactly as Draft, Frozen, Implemented, Verified, and Superseded.
- Enforce only these forward transitions:
  - Draft to Frozen or Superseded.
  - Frozen to Implemented or Superseded.
  - Implemented to Verified or Superseded.
  - Verified to Superseded.
  - Superseded has no outgoing transition.
- Reject skipped, backward, or post-Superseded transitions.
- Permit `pending` evidence only while state is Draft.
- Require concrete SHA-256 evidence in Frozen, Implemented, Verified, and Superseded states.
- Define `content_digest` as SHA-256 over RFC 8785 JSON Canonicalization Scheme bytes.
- Hash only contract ID, version, sorted inputs, sorted outputs, and sorted fixtures.
- Exclude lifecycle state, baseline commit, ownership metadata, and `content_digest` itself.
- Keep the same content identity from Frozen through Verified.
- Reject Frozen-or-later manifests whose recomputed content identity differs.
- Normalize and uniqueness-check every output, fixture, owned path, and touchpoint path.
- Verify every concrete output and fixture path exists beneath the repository root.
- Verify every declared file digest against its exact bytes.
- Require at least one valid and one invalid integration fixture before freezing.
- Enforce a dependency/input bijection.
- Each declared dependency owner must have exactly one corresponding input.
- Every input owner must occur exactly once in `dependencies`.
- Reject undeclared input owners, unused dependency owners, and duplicate input owners.
- Reject duplicate or conflicting input contract identities.
- Verify each input manifest has the declared contract ID, owner, version, content digest,
  and at least the declared `required_state`.
- Treat the state gate as a repository operation, not schema validation alone.
- Return stable machine-readable error codes and JSON Pointer paths for every rejection.
- Ensure validation failure writes no generated artifact and mutates no lifecycle manifest.

### Tests

- Validate Draft `pending` evidence and reject it after changing state to Frozen.
- Freeze a complete manifest and compare the expected RFC 8785 content digest.
- Prove key order and formatting changes do not change the JCS-derived identity.
- Prove file-byte mutation fails while lifecycle-only changes preserve content identity.
- Test every permitted transition and representative forbidden transitions.
- Test dependency/input missing, extra, duplicate, wrong-owner/digest and every invalid path class.
- Test the all-or-nothing failure guarantee by inspecting the working tree afterward.

## T009 — Module Contribution and Route-Access Policy

### Implementation

- Create `contracts/modules/v1/schema.json` with a stable canonical `$id`.
- Create `contracts/modules/p0/module.json` as the P0 owner contribution.
- Require module version, module ID, owner mission, and globally unique mount key.
- Declare owner-scoped API fragments, event catalogs, and migration root.
- Reject referenced paths outside the declaring owner's contribution convention.
- Make contribution discovery convention-based and deterministic.
- Do not add a central array that feature missions must edit.
- Define `route_policy.default_access` as exactly `protected`.
- Define an explicit, unique list of public operation IDs.
- Require every OpenAPI operation to declare `x-invoice-manager-access`.
- Allow only `protected` or `public` as explicit metadata values.
- Treat absent or unrecognized access metadata as protected for enforcement.
- Still report absent or invalid metadata as a contract-quality error.
- Require public OpenAPI metadata and the module public-operation list to agree exactly.
- Reject a public list entry that does not resolve to one owned operation.
- Reject an operation marked public but absent from the module list.
- Keep P0 health explicitly public in both base OpenAPI and P0 module policy.
- Keep every future route protected by default unless both declarations opt it out.

### Tests

- Validate P0 public health plus two synthetic owners discovered without a registry edit.
- Reject duplicate mounts, owner/convention mismatch, and owner-scope escapes.
- Reject missing, misspelled, duplicated, and unresolved public operation IDs.
- Reject policy/OpenAPI disagreement and prove undeclared routes remain protected.

## T010 — Event Discriminator and Payload Binding

### Implementation

- Create `contracts/events/v1/envelope.schema.json` with its canonical `$id`.
- Create `contracts/events/v1/catalog.schema.json` with its canonical `$id`.
- Preserve UUIDv7 event IDs and canonical decimal-string aggregate revisions.
- Preserve fixed-millisecond UTC instants and nullable correlation/causation IDs.
- Keep `data` producer-owned and validate it in a second stage.
- Require each catalog entry to bind source, event type, event version,
  aggregate type, and payload-schema ID.
- Define the event identity tuple as source plus event type plus event version.
- Reject duplicate event identities locally or across owner catalogs.
- Reject conflicting reuse of an event type/version with another payload schema.
- Resolve the payload schema by exact stable `$id`, never by guessed path.
- Validate a full event against the envelope first.
- Resolve exactly one matching catalog discriminator second.
- Validate `data` against that entry's payload schema third.
- Reject zero matches, multiple matches, aggregate mismatch, and source mismatch.
- Preserve signed 64-bit fidelity by never coercing revisions through JS `number`.
- Support LF-terminated UTF-8 JSONL fixture batches.
- Report the failing JSONL line, stable code, and JSON Pointer without leaking data.

### Tests

- Validate an envelope with a maximum signed-64-bit-safe decimal revision string.
- Reject unsafe numeric, noncanonical decimal, negative revision, and malformed instant forms.
- Validate the full two-stage flow; reject wrong payload or discriminator independently.
- Reject duplicate catalog identities and unresolved payload-schema IDs.
- Validate multi-line JSONL and reject malformed or non-LF-terminated batches deterministically.

## T011 — Deterministic OpenAPI and Schema Composition

### Implementation

- Create `contracts/api/v1/base.openapi.yaml` rooted at `/api/v1`.
- Include only the P0 health operation and shared response-envelope components.
- Name P0-owned components so their identity is explicit and collision-checkable.
- Discover module manifests, then discover only their declared fragments and catalogs.
- Parse all inputs before writing any output.
- Canonically order modules, paths, HTTP methods, operations, components, and schemas.
- Define and document the method ordering used during serialization.
- Reject duplicate normalized path/method pairs.
- Reject duplicate operation IDs even when paths differ.
- Reject duplicate component names even when definitions are byte-identical.
- Reject duplicate or conflicting schema `$id` values.
- Reject mount-key and event-identity collisions in the same preflight.
- Preserve external stable-ID references; do not rewrite them to machine-local paths.
- Emit deterministic YAML or JSON with fixed newline and formatting policy.
- Compose into an ignored build location selected by the CLI.
- Write via a temporary file and atomic replacement only after all checks pass.
- Delete temporary output after a failed run.
- Run the composer twice over the same source tree and compare exact bytes in tests.

### Tests

- Compose multiple owners in different discovery orders and assert byte-identical repeats.
- Reject path/method, operation-ID, component, schema-ID, mount, and event collisions.
- Reject route-policy disagreement before any output becomes visible.
- Verify failures preserve prior output and no aggregate is tracked by Git.

## T012 — Stable-ID Registry and Deterministic Runtime Generation

### Implementation

- Build an in-memory registry from canonical schema `$id` to normalized source path.
- Populate it from deterministic scans of owned P0 and discovered owner contracts.
- Reject missing `$id`, duplicate `$id`, fragment-only ambiguity, and path aliasing.
- Resolve JSON Schema and OpenAPI references from this registry without network access.
- Resolve URI fragments against the registered document and report unresolved pointers.
- Detect reference cycles safely without treating legitimate recursive schemas as duplicates.
- Generate TypeScript types only from the validated composed contract graph.
- Preserve Money minor units and other signed 64-bit values as strings or `bigint` adapters,
  never an unguarded TypeScript `number`.
- Make literal `npm run contracts:generate` the sole materializer of all generated outputs.
- It writes TypeScript only to `tools/contracts/.generated/typescript/v1/` and the route
  inventory only to `tools/contracts/.generated/runtime/v1/route-inventory.json`.
- Reject every destination override, alternate generated destination, and authoritative-source destination.
- Create `tools/contracts/.gitignore` to ignore exactly `tools/contracts/.generated/`.
- Consume WP01's stable version-one package export unchanged; later web code imports that export
  and never copies bindings beneath `apps/web/`.
- Treat the generator as the sole writer; consumers have read/import access only.
- Put a generated-file banner on output while keeping generation byte-deterministic.
- Never import generated types back into canonical schema sources.
- Never commit generated TypeScript or a generated schema registry.
- Validate every stable reference, exact P1-P4 pin, and prohibition on moving refs before
  creating a temporary output; a moving branch, tag, `HEAD`, abbreviated commit, or inferred
  working-tree/sibling value must fail with no generated output change.

The route inventory derives only from validated composed module/OpenAPI metadata and uses this format:

- top-level `format_version` is integer `1`;
- `routes` sorts by normalized path, canonical method order, then operation ID;
- every route contains exactly `path`, lowercase `method`, `operation_id`, `owner`, `mount_key`,
  and effective `access` (`public` or `protected`);
- values come from the operation and owner module, never timestamps, host paths, randomness,
  branches, or manual entries; duplicate routes, unresolved owners, or access disagreement/errors
  fail before either generated destination changes.

WP08 consumes this inventory as generated runtime input for route-policy and dispatch checks.
It must never infer public access independently or maintain a second route registry.

### Tests

- Resolve the canonical common schema from event and migration schemas by stable ID.
- Resolve real P1-P4 Draft contract references through the same registry.
- Reject unknown IDs, duplicate IDs, unresolved fragments, and attempted network refs.
- Run literal `npm run contracts:generate` twice and compare exact TypeScript and inventory bytes.
- Assert inventory order and fields derive from composed metadata, including P0 public health.
- Assert canonical int64 fields do not become plain `number` declarations.
- Assert `.generated/**` is ignored and absent from `git ls-files`, and generated bindings are
  reachable through WP01's stable tool-workspace export after generation.
- Assert attempts to generate or copy either artifact anywhere else fail without writes.
- Assert every moving-reference failure occurs before output and preserves the previous good pair.

## T013 — Real Draft Inputs, Collision Matrix, and Freeze Mutations

### Implementation

- Commit `contracts/conformance/p0-p4-inputs.json` with exactly one canonically sorted P1-P4
  record containing owner, contract ID/version, repository-relative manifest path, full commit,
  manifest byte SHA-256, and RFC 8785 contract-content digest computed at that commit.
- Pin and verify these exact commit / manifest SHA-256 / content-digest triples:
  - P1 `47638a9d95427697c1fcc74c7279f40f314450f5` / `3f28ddb033e5259163671b34c8c64f6214c5524f0f941e4dc5d03c38485a7987` / `73457636636187ff5537564a0f13ed29030d931746dbcc2740da3636cb2747f5`.
  - P2 `8830e8bbdfb1a7ecb92015359aa28c58d9f2b078` / `24bf9f15fad1d598fae394e5ec40e7a50e6f166e7bd1202e3c51c4576c89bbc7` / `c12f5c79c21689f146c705cef5b454bca684e5e86e0ac7a326df8dc7db1f9a70`.
  - P3 `1a83ce0523ccc793c62d7bcd3b6992eb761ec506` / `1b2013f7876a0015af7a18ed9bdc89675520c7dcf0c68f98253357af5c96c11f` / `48d85d152ab9e46efd052c4e3b02dba47a8e6bbfeac8315864cc6d470d274bf3`.
  - P4 `860ee50cd959e75391753cafe841b4da82882a0b` / `2da1496e68aa9577a91af647af34268181c9a58ff5aec529cc71121db4159a24` / `453c138255cd525587a07049a04576c9d22919979c0c2ac45ce37f46e2e54636`.
- Compute manifest hashes from exact `git show <full-commit>:<manifest-path>` bytes and content
  hashes from T008's canonical projection; never copy the Draft manifest's `pending` value.
- Reject branches, tags, abbreviated commits, `HEAD`, merge-base/current-head inference, and
  working-tree or sibling-checkout resolution. Fail closed when an exact commit is unavailable.
- Changing a pin requires an explicit tool-local baseline-refresh operation, a committed lock
  diff recording old/new pins, and revalidation of every affected composition and fixture.
- Exercise actual shapes, ownership, dependencies, inputs, schema IDs, and integration edges;
  toy-only substitutes cannot satisfy conformance.
- Do not edit downstream mission branches or claim ownership of their contracts.
- Include all four real owners in at least one successful concurrent composition case.
- Mutate one property at a time so each rejection proves a precise guardrail.
- Cover route path/method, operation ID, component name, schema ID, mount key,
  event identity/version, and public-access collisions.
- Cover unresolved stable-ID references and payload/catalog disagreement.
- Cover lifecycle pending evidence, file mutation, digest mutation, missing output,
  missing fixture, invalid path, dependency/input mismatch, and illegal transitions.
- Cover frozen migration descriptor and script mutations using real Draft metadata.
- Verify every expected rejection has a stable code and actionable JSON Pointer.
- Verify every mutation failure is safe: no partial aggregate, manifest rewrite,
  generated type update, or tracked-file mutation.

### Fixtures

- The valid/invalid `module-pair`, `module-duplicate-mount`, `lifecycle-draft`, and
  `lifecycle-frozen-pending-digest` fixtures prove discovery, collision, and freeze gating.
- Use synthetic business values only; include no real client, invoice, bank, or secret data.

### Tests

- Run the full mutation table as data-driven cases.
- Assert each mutation triggers only its intended stable error category.
- Assert the unmutated P1-P4 set composes successfully and deterministically.
- Assert all four exact commits and both recorded digests are verified before composition.
- Reject moving references, unavailable commits, digest drift, and an unrefreshed pin change.
- Exercise baseline refresh and prove its committed candidate records old/new pins and reruns all
  affected composition and fixture cases without silently rewriting the lock during checks.
- Assert every real dependency is matched by exactly one input and vice versa.
- Assert descriptor and script digests are independently checked.
- Assert a second run after every failed mutation starts from a clean state and passes.

## T014 — Focused Contracts Command

### Implementation

- Implement the CLI entry point at `tools/contracts/src/main.ts`.
- Keep orchestration thin and put validators/composers in testable tool-local modules.
- Provide one focused `contracts:check` flow for schemas, lifecycle, references,
  composition determinism, access policy, generated-type checks, and fixtures.
- Reuse WP01's literal root `contracts:generate` and `contracts:check` wiring.
- `contracts:check` must invoke `npm run contracts:generate` twice, snapshot and byte-diff both
  generated destinations, and fail on any drift before completing its remaining checks.
- Consume WP01's installed scripts, workspace manifest, and lock unchanged; expose missing
  implementation only in owned `src/**` or `tests/**`, otherwise log an integration request.
- Do not modify root package files outside this package's ownership.
- Make help output list inputs, outputs, check mode, and stable exit meanings.
- Use nonzero exit status for validation, collision, mutation, or determinism failure.
- Keep human diagnostics concise and machine diagnostics structured.
- Avoid timestamps, absolute paths, random ordering, or host-specific data in output.
- Ensure the command can run from a clean clone without sibling repositories.
- Ensure the command can run repeatedly without changing tracked files.

### Tests

- Run the focused command from the repository root.
- Prove its two internal generator runs produce identical diagnostics and artifact bytes.
- Run representative failing fixtures and assert nonzero status plus stable codes.
- Verify failures do not overwrite a previously valid generated artifact.
- Verify a moving reference fails before either generated output is touched.
- Verify the repository remains clean except for intentional source changes.

## Acceptance and Verification

- All schemas validate; canonical `$id` values are stable, unique, and locally resolved.
- P0 health is the only base operation and is explicitly public in both declarations.
- All unspecified routes are protected by default.
- Content identity uses RFC 8785/SHA-256, dependencies/inputs are bijective, and lifecycle rules hold.
- P1-P4 real Draft inputs participate in successful and mutated test cases.
- P1-P4 inputs resolve only through the exact-commit/digest lock.
- Every defined collision class has a rejection test.
- Event discriminators resolve exactly one payload schema before payload validation.
- Composition, type generation, and route inventory are byte-deterministic across repeated runs.
- WP01's export is the only TS consumer path; T012 inventory is WP08's sole route-policy input.
- No generated aggregate is committed or left as a tracked worktree change.
- The focused contracts command passes from a clean checkout.
- `git diff --check` reports no whitespace errors in package-owned changes.

## Risks and Mitigations

- Schema-only lifecycle checks: keep file, digest, transition, and dependency checks in the runtime gate.
- Accidental public routes: default protected and require two matching explicit declarations.
- Copied-fixture drift: resolve exact commits and verify both immutable digests before composition.
- Moving/hand-edited P1-P4 pins: forbid moving refs and require recorded baseline refresh plus revalidation.
- Generated merge surfaces: one WP03 writer, ignored `.generated/**`, and stable consumer boundaries.
- Post-hoc tests: capture named red-first lifecycle, route-policy, and composition evidence.
- JS int64 loss: validate canonical strings and use bigint-aware paths only.

## Review Guidance

- Review schema and runtime semantics, including lifecycle transitions and the dependency/input
  bijection, then independently recompute one RFC 8785 content digest.
- Recompute one pinned manifest SHA and content digest directly from its exact commit.
- Reject review if any conformance path resolves a branch, tag, `HEAD`, or working tree.
- Inspect every route for explicit access metadata and module-policy agreement.
- Run the collision matrix and verify each failure occurs before writes.
- Inspect stable-ID resolution for hidden network or absolute-path fallback.
- Run literal `npm run contracts:generate` twice, then compare exact TS and inventory bytes.
- Confirm `.gitignore`, WP01's package export, and imports establish one writer/path/consumer contract.
- Confirm the route inventory contains only composed metadata and moving refs fail before writes.
- Confirm generated OpenAPI, TypeScript, inventories, and registries are not tracked.
- Inspect the recorded red-first commands and ensure each failed for its intended missing logic.
- Reject the package if it replaces real P1-P4 cases with toy-only evidence.

## Completion Checklist

- [ ] T008 lifecycle schema, P0 manifest, JCS identity, and state gate complete.
- [ ] T009 module schema, P0 contribution, and access policy complete.
- [ ] T010 event envelope, catalog binding, and payload validation complete.
- [ ] T011 deterministic OpenAPI/schema composition complete.
- [ ] T012 stable-ID registry, ignored TypeScript, and runtime inventory generation complete.
- [ ] T013 real P1-P4 collision and freeze-mutation evidence complete.
- [ ] T014 focused contracts command complete.
- [ ] Immutable P1-P4 commit/digest lock and baseline-refresh guard complete.
- [ ] Lifecycle, route-policy, and composition red-first evidence recorded.
- [ ] Sole TS and route-inventory outputs are ignored and exposed through their stable consumers.
- [ ] Package tests and the focused command's two generation passes succeed.
- [ ] No generated aggregate is tracked and no out-of-scope path is edited.
- [ ] Reviewer evidence includes commands, exit status, and key mutation results.
- [ ] WP01 root tooling lock was consumed without modification.

## Activity Log

- 2026-07-20T07:01:00Z — system — Prompt generated for WP03 with WP01/WP02
  dependencies, exact ownership/requirement metadata, real P1-P4 evidence, and
  deterministic no-committed-aggregate constraints.
- 2026-07-20T19:43:00Z – codex:gpt-5:node-norris:implementer – shell_pid=1807838 – Assigned agent via action command

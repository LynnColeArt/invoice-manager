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
agent: codex
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
- contracts/manifests/p0.json
- contracts/fixtures/p0/v1/valid/module-pair.json
- contracts/fixtures/p0/v1/invalid/module-duplicate-mount.json
- contracts/fixtures/p0/v1/valid/lifecycle-draft.json
- contracts/fixtures/p0/v1/invalid/lifecycle-frozen-pending-digest.json
- tools/contracts/src/main.ts
execution_mode: code_change
model: ''
owned_files:
- contracts/api/**
- contracts/events/**
- contracts/modules/**
- contracts/manifests/**
- contracts/migrations/**
- contracts/fixtures/p0/v1/valid/module-*
- contracts/fixtures/p0/v1/invalid/module-*
- contracts/fixtures/p0/v1/valid/lifecycle-*
- contracts/fixtures/p0/v1/invalid/lifecycle-*
- tools/contracts/**
role: implementer
tags: []
task_type: implement
---

# Work Package Prompt: WP03 – Composable Contract and Lifecycle Tooling

## ⚡ Do This First: Load Agent Profile

- Load `.kittify/agent-profiles/node-norris.md` before editing code.
- Adopt the `implementer` role and its quality boundaries for this package.
- Execute as agent `codex`; do not substitute a different profile silently.
- Start the governed implementation with:

```bash
spec-kitty agent action implement WP03 --agent codex
```

- Re-read this prompt after the profile because this file is the package contract.
- Confirm WP01 and WP02 are available before relying on their repository shell or values.

## Objective

Build the deterministic contract-composition and lifecycle-validation toolchain that makes
parallel feature missions additive instead of registry-driven.

The result must turn the P0 Draft planning contracts into canonical repository contracts,
validate their lifecycle evidence against real files, compose owner contributions without
committed generated aggregates, and fail safely on every defined collision or mutation.

This package owns contract mechanics only. It does not implement invoice, client, project,
payment, reporting, authentication, PDF, or deployment behavior.

## Context and Normative Inputs

- Treat `kitty-specs/p0-contract-spine-01KXYY0J/spec.md` as the requirement source.
- Treat `kitty-specs/p0-contract-spine-01KXYY0J/plan.md` as the implementation strategy.
- Treat `kitty-specs/p0-contract-spine-01KXYY0J/data-model.md` as lifecycle semantics.
- Treat `kitty-specs/p0-contract-spine-01KXYY0J/research.md` as decision rationale.
- Treat every file in `kitty-specs/p0-contract-spine-01KXYY0J/contracts/` as a Draft input.
- Preserve the canonical common-schema ID supplied by WP02.
- Use JSON Schema 2020-12 and OpenAPI 3.1.
- Use Node/TypeScript only inside the package-owned contract tool surface.
- Keep all repository paths normalized, relative to the repository root, and slash-separated.
- Reject absolute paths, parent traversal, duplicate normalized paths, and escaping symlinks.
- Never fetch a schema over the network during validation or composition.
- Never hand-maintain a global owner, route, event, schema, or migration registry.
- Discover owner contributions by deterministic convention scans beneath `contracts/`.
- Sort inputs by documented semantic identity before hashing or composing.
- Produce byte-identical output for byte-identical repository inputs.
- Run deterministic composition twice in tests and compare exact bytes.
- Do not commit composed OpenAPI, generated TypeScript, route inventories, or schema bundles.

## Branch and Ownership Boundaries

- Planning base: `feat/p0-contract-spine`.
- Merge target: `feat/p0-contract-spine`.
- Work only in paths matched by `owned_files` in the frontmatter.
- Do not edit root `package.json`, locks, application code, CI, or downstream mission files.
- WP01 owns repository-level command wiring and ignore scaffolding.
- WP02 owns common values and their cross-runtime fidelity.
- If a missing root script or ignore rule blocks acceptance, record an integration request.
- Do not cross the ownership boundary merely to make a command look convenient.
- Generated output may be written only to already ignored build or temporary directories.
- A clean validation run must leave tracked files byte-for-byte unchanged.

## Required Deliverables

- Canonical base OpenAPI with only P0 health behavior.
- Canonical event envelope and event-catalog schemas.
- Canonical module-contribution schema and P0 module manifest.
- Canonical contract-lifecycle and migration-manifest schemas.
- P0 lifecycle manifest using the canonical repository shape.
- Valid and invalid module and lifecycle fixtures.
- A deterministic TypeScript contract CLI rooted at `tools/contracts/src/main.ts`.
- Focused tests covering schemas, lifecycle gates, composition, references, and mutations.
- A single focused contracts command suitable for local use and CI integration.

## T008 — Canonical Lifecycle, Content Identity, and State Gate

### Implementation

- Create `contracts/manifests/v1/schema.json` with a stable canonical `$id`.
- Create `contracts/manifests/p0.json` from the P0 Draft planning manifest.
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

- Validate Draft evidence containing `pending` digests.
- Reject the same pending evidence after changing state to Frozen.
- Freeze a complete manifest and compare the expected RFC 8785 content digest.
- Prove key order and formatting changes do not change the JCS-derived identity.
- Prove output or fixture byte mutation changes evidence and fails the gate.
- Prove lifecycle-only state changes do not change content identity.
- Test every permitted transition and representative forbidden transitions.
- Test dependency/input missing, extra, duplicate, wrong-owner, and wrong-digest cases.
- Test absolute, traversing, duplicate-normalized, missing, and escaping-symlink paths.
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

- Validate the P0 module and public health operation.
- Validate two synthetic owner modules discovered without a registry edit.
- Reject duplicate mount keys across otherwise valid modules.
- Reject module ID and owner convention mismatches.
- Reject fragments, catalogs, or migration roots escaping owner scope.
- Reject missing, misspelled, duplicated, and unresolved public operation IDs.
- Reject disagreement between module policy and OpenAPI access metadata.
- Prove an undeclared route remains protected and cannot become public accidentally.

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
- Validate a catalog-bound payload through the full two-stage flow.
- Reject correct envelope/wrong payload and correct payload/wrong discriminator cases.
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

- Compose base plus multiple synthetic owner fragments in different discovery orders.
- Assert byte-identical results across both orders and repeated runs.
- Reject path/method, operation-ID, component, schema-ID, mount, and event collisions.
- Reject route-policy disagreement before any output becomes visible.
- Verify a failed composition leaves the previous good output untouched.
- Verify no generated aggregate is tracked by Git after the test suite.

## T012 — Stable-ID Reference Registry and Ignored TypeScript Generation

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
- Generate into an ignored directory owned by the contract build.
- Make output location explicit and reject destinations inside authoritative sources.
- Put a generated-file banner on output while keeping generation byte-deterministic.
- Never import generated types back into canonical schema sources.
- Never commit generated TypeScript or a generated schema registry.
- Expose a check mode that validates generation without modifying the worktree.

### Tests

- Resolve the canonical common schema from event and migration schemas by stable ID.
- Resolve real P1-P4 Draft contract references through the same registry.
- Reject unknown IDs, duplicate IDs, unresolved fragments, and attempted network refs.
- Generate twice and compare exact TypeScript bytes.
- Assert canonical int64 fields do not become plain `number` declarations.
- Assert generated paths are ignored and absent from `git ls-files`.
- Assert check mode leaves no persistent output or source mutation.

## T013 — Real Draft Inputs, Collision Matrix, and Freeze Mutations

### Implementation

- Exercise the tool against the recorded real P1, P2, P3, and P4 Draft manifests.
- Use their actual contract shapes, owner metadata, dependencies, inputs, and schema IDs.
- Do not replace downstream inputs with toy manifests that omit real integration edges.
- If byte-exact test copies are needed, store only representative `module-*` or
  `lifecycle-*` fixtures under this package's owned fixture globs.
- Record source mission, source path, and source digest in test descriptions.
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

- `contracts/fixtures/p0/v1/valid/module-pair.json` proves additive module discovery.
- `contracts/fixtures/p0/v1/invalid/module-duplicate-mount.json` proves mount rejection.
- `contracts/fixtures/p0/v1/valid/lifecycle-draft.json` proves Draft pending semantics.
- `contracts/fixtures/p0/v1/invalid/lifecycle-frozen-pending-digest.json` proves freeze gating.
- Add further files only when their names retain the `module-*` or `lifecycle-*` prefix.
- Use synthetic business values only; include no real client, invoice, bank, or secret data.
- Keep fixture output deterministic and fixture purpose obvious from the case ID.

### Tests

- Run the full mutation table as data-driven cases.
- Assert each mutation triggers only its intended stable error category.
- Assert the unmutated P1-P4 set composes successfully and deterministically.
- Assert every real dependency is matched by exactly one input and vice versa.
- Assert descriptor and script digests are independently checked.
- Assert a second run after every failed mutation starts from a clean state and passes.

## T014 — Focused Contracts Command

### Implementation

- Implement the CLI entry point at `tools/contracts/src/main.ts`.
- Keep orchestration thin and put validators/composers in testable tool-local modules.
- Provide one focused `contracts:check` flow for schemas, lifecycle, references,
  composition determinism, access policy, generated-type checks, and fixtures.
- Reuse WP01's root command wiring if it exists.
- Otherwise expose the equivalent tool-local command and log the root integration request.
- Do not modify root package files outside this package's ownership.
- Make help output list inputs, outputs, check mode, and stable exit meanings.
- Use nonzero exit status for validation, collision, mutation, or determinism failure.
- Keep human diagnostics concise and machine diagnostics structured.
- Avoid timestamps, absolute paths, random ordering, or host-specific data in output.
- Ensure the command can run from a clean clone without sibling repositories.
- Ensure the command can run repeatedly without changing tracked files.

### Tests

- Run the focused command from the repository root.
- Run it a second time and assert identical diagnostics and artifacts.
- Run representative failing fixtures and assert nonzero status plus stable codes.
- Verify failures do not overwrite a previously valid generated artifact.
- Verify the repository remains clean except for intentional source changes.

## Acceptance and Verification

- All canonical schemas validate against JSON Schema 2020-12 metaschemas.
- All canonical `$id` values are stable, unique, and resolved locally.
- P0 health is the only base operation and is explicitly public in both declarations.
- All unspecified routes are protected by default.
- Contract content identity uses RFC 8785 canonical bytes and SHA-256.
- Dependency owners and manifest inputs form an exact bijection.
- Draft-to-Frozen-to-Implemented-to-Verified/Superseded rules are enforced.
- P1-P4 real Draft inputs participate in successful and mutated test cases.
- Every defined collision class has a rejection test.
- Event discriminators resolve exactly one payload schema before payload validation.
- Composition and type generation are byte-deterministic across repeated runs.
- No generated aggregate is committed or left as a tracked worktree change.
- The focused contracts command passes from a clean checkout.
- `git diff --check` reports no whitespace errors in package-owned changes.

## Risks and Mitigations

- Risk: RFC 8785 is approximated with ordinary key-sorted JSON.
  Mitigation: use a standards-conforming JCS implementation and published vectors.
- Risk: manifest self-reference makes content digests unstable.
  Mitigation: hash only the explicitly defined immutable projection.
- Risk: schema validation is mistaken for repository lifecycle validation.
  Mitigation: keep file, digest, transition, and dependency checks in the runtime gate.
- Risk: additive scans become nondeterministic across filesystems.
  Mitigation: normalize and sort semantic identities before every operation.
- Risk: public endpoints appear through missing metadata.
  Mitigation: default to protected and require two matching explicit declarations.
- Risk: a failed composition corrupts the last good artifact.
  Mitigation: validate fully, write temporary output, then replace atomically.
- Risk: real downstream contracts drift from copied fixtures.
  Mitigation: retain provenance digests and compare against recorded Draft inputs.
- Risk: generated TypeScript becomes a shared merge surface.
  Mitigation: keep it ignored, reproducible, and regenerated during validation.
- Risk: JavaScript numeric coercion loses signed 64-bit fidelity.
  Mitigation: validate canonical strings and use bigint-aware code paths only.

## Review Guidance

- Review schema semantics and runtime semantics separately; both must hold.
- Recompute at least one content digest independently using RFC 8785.
- Inspect the dependency/input bijection against real P1-P4 manifests.
- Verify the lifecycle transition table includes no undocumented shortcut.
- Inspect every route for explicit access metadata and module-policy agreement.
- Confirm health is public and all other undeclared routes resolve protected.
- Run the collision matrix and verify each failure occurs before writes.
- Inspect stable-ID resolution for hidden network or absolute-path fallback.
- Run composition and generation twice, then compare exact bytes.
- Confirm generated OpenAPI, TypeScript, inventories, and registries are not tracked.
- Confirm the implementation stays inside declared owned paths.
- Reject the package if it replaces real P1-P4 cases with toy-only evidence.

## Completion Checklist

- [ ] T008 lifecycle schema, P0 manifest, JCS identity, and state gate complete.
- [ ] T009 module schema, P0 contribution, and access policy complete.
- [ ] T010 event envelope, catalog binding, and payload validation complete.
- [ ] T011 deterministic OpenAPI/schema composition complete.
- [ ] T012 stable-ID registry and ignored TypeScript generation complete.
- [ ] T013 real P1-P4 collision and freeze-mutation evidence complete.
- [ ] T014 focused contracts command complete.
- [ ] Package-owned tests pass.
- [ ] Focused contracts command passes twice.
- [ ] No generated aggregate is tracked.
- [ ] No out-of-scope path was edited.
- [ ] Reviewer evidence includes commands, exit status, and key mutation results.

## Activity Log

- 2026-07-20T07:01:00Z — system — Prompt generated for WP03 with WP01/WP02
  dependencies, exact ownership/requirement metadata, real P1-P4 evidence, and
  deterministic no-committed-aggregate constraints.

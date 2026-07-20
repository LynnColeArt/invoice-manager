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
- contracts/conformance/p0-p4-inputs.json
- contracts/fixtures/p0/v1/valid/module-pair.json
- contracts/fixtures/p0/v1/invalid/module-duplicate-mount.json
- contracts/fixtures/p0/v1/valid/lifecycle-draft.json
- contracts/fixtures/p0/v1/invalid/lifecycle-frozen-pending-digest.json
- tools/contracts/.gitignore
- tools/contracts/package.json
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
- contracts/conformance/**
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
- Resolve conformance only from committed full-commit/digest pins; never inspect a current or
  moving branch head, tag, `HEAD`, sibling checkout, or working-tree version as input.
- Do not commit composed OpenAPI, route inventories, schema bundles, or generated TypeScript.

## Branch and Ownership Boundaries

- Planning base: `feat/p0-contract-spine`.
- Merge target: `feat/p0-contract-spine`.
- Work only in paths matched by `owned_files` in the frontmatter.
- Do not edit root `package.json`, locks, application code, CI, or downstream mission files.
- WP01 owns repository-level command wiring and the initial root tooling lock.
- Consume WP01's root `package-lock.json` as-is; this package must not edit or regenerate it.
- WP02 owns common values and their cross-runtime fidelity.
- If a missing root script or ignore rule blocks acceptance, record an integration request.
- Do not cross the ownership boundary merely to make a command look convenient.
- WP03 owns `tools/contracts/.gitignore`, the tool-workspace export, and is the sole writer of
  generated TypeScript at `tools/contracts/.generated/typescript/v1/`.
- That exact versioned directory is the only ignored generated TypeScript location.
- A clean validation run must leave tracked files byte-for-byte unchanged.

## Required Deliverables

- Canonical base OpenAPI with only P0 health behavior.
- Canonical event envelope and event-catalog schemas.
- Canonical module-contribution schema and P0 module manifest.
- Canonical contract-lifecycle and migration-manifest schemas.
- P0 lifecycle manifest using the canonical repository shape.
- Committed immutable P1-P4 conformance-input lock with exact provenance and digests.
- Valid and invalid module and lifecycle fixtures.
- A deterministic TypeScript contract CLI rooted at `tools/contracts/src/main.ts`.
- A tool workspace whose stable package export exposes the version-one generated bindings.

## Test-First Evidence Order

- Before production logic, run failing lifecycle state/digest, protected-default route-policy,
  and deterministic composition/collision tests; each must fail for its intended missing logic.
- Record case names, commands, expected failures, red results, and matching green results in the
  Activity Log without committing deliberately broken production code.

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
- Generate only into `tools/contracts/.generated/typescript/v1/`; reject every override,
  alternate generated-TypeScript destination, and destination inside authoritative sources.
- Create `tools/contracts/.gitignore` to ignore that directory and no broader source tree.
- Create the `tools/contracts` workspace package with one stable version-one package export;
  later web code imports that export and never copies bindings beneath `apps/web/`.
- Treat the generator as the sole writer; consumers have read/import access only.
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
- Assert the sole generated path is ignored, absent from `git ls-files`, and reachable through
  the stable tool-workspace export after generation.
- Assert attempts to generate or copy TypeScript anywhere else fail without writes.
- Assert check mode leaves no persistent output or source mutation.

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
- Reuse WP01's root command wiring if it exists.
- Consume WP01's installed root scripts and lock; expose any missing capability tool-locally and
  log an integration request instead of changing root package metadata or `package-lock.json`.
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
- P1-P4 inputs resolve only through the committed exact-commit/digest conformance lock.
- Every defined collision class has a rejection test.
- Event discriminators resolve exactly one payload schema before payload validation.
- Composition and type generation are byte-deterministic across repeated runs.
- The stable tool-workspace export is the only consumer path to the sole ignored TS output.
- No generated aggregate is committed or left as a tracked worktree change.
- The focused contracts command passes from a clean checkout.
- `git diff --check` reports no whitespace errors in package-owned changes.

## Risks and Mitigations

- Risk: schema validation is mistaken for repository lifecycle validation.
  Mitigation: keep file, digest, transition, and dependency checks in the runtime gate.
- Risk: public endpoints appear through missing metadata.
  Mitigation: default to protected and require two matching explicit declarations.
- Risk: real downstream contracts drift from copied fixtures.
  Mitigation: resolve exact commits and verify both immutable digests before composition.
- Risk: a branch head or hand-edited pin silently changes P1-P4 acceptance.
  Mitigation: forbid moving references and require an explicit committed baseline refresh with
  old/new provenance plus full affected-suite revalidation.
- Risk: generated TypeScript becomes a shared merge surface.
  Mitigation: one WP03 writer, one exact ignored directory, and one stable workspace export.
- Risk: tests are added after logic and pass without proving the guardrail.
  Mitigation: capture named red-first lifecycle, route-policy, and composition evidence.
- Risk: JavaScript numeric coercion loses signed 64-bit fidelity.
  Mitigation: validate canonical strings and use bigint-aware code paths only.

## Review Guidance

- Review schema and runtime semantics, including lifecycle transitions and the dependency/input
  bijection, then independently recompute one RFC 8785 content digest.
- Recompute one pinned manifest SHA and content digest directly from its exact commit.
- Reject review if any conformance path resolves a branch, tag, `HEAD`, or working tree.
- Inspect every route for explicit access metadata and module-policy agreement.
- Run the collision matrix and verify each failure occurs before writes.
- Inspect stable-ID resolution for hidden network or absolute-path fallback.
- Run composition and generation twice, then compare exact bytes.
- Confirm `.gitignore`, package exports, and imports establish one writer/path/consumer contract.
- Confirm generated OpenAPI, TypeScript, inventories, and registries are not tracked.
- Inspect the recorded red-first commands and ensure each failed for its intended missing logic.
- Reject the package if it replaces real P1-P4 cases with toy-only evidence.

## Completion Checklist

- [ ] T008 lifecycle schema, P0 manifest, JCS identity, and state gate complete.
- [ ] T009 module schema, P0 contribution, and access policy complete.
- [ ] T010 event envelope, catalog binding, and payload validation complete.
- [ ] T011 deterministic OpenAPI/schema composition complete.
- [ ] T012 stable-ID registry and ignored TypeScript generation complete.
- [ ] T013 real P1-P4 collision and freeze-mutation evidence complete.
- [ ] T014 focused contracts command complete.
- [ ] Immutable P1-P4 commit/digest lock and baseline-refresh guard complete.
- [ ] Lifecycle, route-policy, and composition red-first evidence recorded.
- [ ] Sole TS output is ignored and exposed only through the stable workspace export.
- [ ] Package-owned tests pass.
- [ ] Focused contracts command passes twice.
- [ ] No generated aggregate is tracked.
- [ ] No out-of-scope path was edited.
- [ ] Reviewer evidence includes commands, exit status, and key mutation results.
- [ ] WP01 root tooling lock was consumed without modification.

## Activity Log

- 2026-07-20T07:01:00Z — system — Prompt generated for WP03 with WP01/WP02
  dependencies, exact ownership/requirement metadata, real P1-P4 evidence, and
  deterministic no-committed-aggregate constraints.

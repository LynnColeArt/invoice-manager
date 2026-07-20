---
work_package_id: WP11
title: Foundation Acceptance and Program Handoff
dependencies:
- WP03
- WP04
- WP05
- WP06
- WP07
- WP08
- WP09
- WP10
requirement_refs:
- FR-001
- FR-002
- FR-008
- FR-015
- FR-016
- NFR-001
- NFR-002
- NFR-003
- NFR-005
- NFR-007
- NFR-008
- NFR-010
- NFR-011
- NFR-012
- C-001
- C-007
- C-008
- C-009
- C-010
tracker_refs: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch.
subtasks:
- T048
- T049
- T050
- T051
- T052
- T053
- T054
phase: Phase 5
assignee: ''
agent: codex
scope: codebase-wide
history: []
agent_profile: implementer-ivan
authoritative_surface: .
create_intent:
- .github/workflows/foundation.yml
- tools/licenses/src/main.ts
- README.md
- docs/program-ledger.md
- contracts/manifests/p0.json
execution_mode: code_change
model: ''
owned_files:
- .github/workflows/foundation*
- tools/licenses/**
- README*
- docs/program-ledger.md
- contracts/manifests/p0.json
role: implementer
tags: []
task_type: implement
---

# Work Package Prompt: WP11 – Foundation Acceptance and Program Handoff

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Close P0 with auditable evidence: independently diagnosable CI, one bounded full
verification target, deterministic GPL-2.0-only runtime licensing, a clean-clone proof,
legal P0 manifest promotion, immutable real P1-P4 conformance, a real Zig-to-Next.js
proxy/performance proof, and an accurate program handoff.

This package runs producer-owned checks and records results. It does not author missing
producer code, tests, fixtures, contracts, package locks, or build wiring.

## Context and Gate Posture

- WP03 through WP10 must be accepted before WP11 can report P0 acceptance.
- Require evidence that the orchestrator completed its pre-acceptance governed-doc sync.
- Read synchronized `spec.md`, `plan.md`, `data-model.md`, `research.md`, and `quickstart.md`.
- Verify governed artifacts have not drifted since that sync; absence or drift blocks closure.
- Never edit `kitty-specs/` or the quickstart from this code work package.
- Run contributor and CI commands exactly; never convert a failure to a warning.
- Route producer failures with command, exit status, focused diagnostic, and owning path.
- Re-run the complete affected gate after the producer supplies a fix.
- Keep evidence synthetic and redact tokens, secrets, customer data, and private paths.

## Codebase-Wide Ownership

- `scope: codebase-wide` permits repository-wide inspection for acceptance.
- Writes remain limited to the exact `owned_files` frontmatter patterns.
- `contracts/manifests/p0.json` is an explicit owned path, not an implied exception.
- Manifest writes may only fill verified evidence and perform a legal lifecycle transition.
- Do not redesign the schema, alter contract semantics, or edit P1-P4 artifacts.
- Every transition must pass WP03's lifecycle command and preserve content identity.

## Branch Strategy

- **Strategy**: `wp_branch`
- **Planning base branch**: `feat/p0-contract-spine`
- **Merge target branch**: `feat/p0-contract-spine`
- Start with the governed implementation action:

```bash
spec-kitty agent action implement WP11 --agent codex
```

- Verify the branch includes accepted outputs from WP03 through WP10.
- Do not merge, rebase, tag, publish, or advance downstream missions here.
- Record the candidate commit and program baseline used by final evidence.

## Required Acceptance Matrix

| Gate | Mandatory focused command | Primary owner on failure |
| --- | --- | --- |
| Contracts | `npm run contracts:check` | WP03; WP02 for common values |
| Web | `npm run web:check` | WP09 or WP10 by failing surface |
| Zig service | `npm run api:check` | WP05/WP08; WP04 for build integration |
| Migration negative | `npm run migration:negative` | WP07 |
| Persistence | `npm run persistence:integration` | WP06; WP04/WP07 at seams |
| HTTP/proxy | `npm run http:smoke` | WP08 or WP10 by failing boundary |
| Runtime license | `npm run licenses:check` | WP11 policy/report; dependency owner for fix |
| Aggregate | `npm run verify:foundation` | First focused failing owner |

- Every focused command runs independently and the aggregate invokes those exact commands.
- `npm run migration:negative` is mandatory; aliases or producer-defined substitutes fail.
- HTTP/proxy uses the real WP08 Zig service and WP10 production Next.js proxy, and owns
  acceptance traceability for FR-002 and NFR-007.

## Subtasks & Detailed Guidance

### Subtask T048 – Independent Foundation CI Jobs

**Purpose**

Create independently diagnosable contract, web, Zig, migration, persistence, proxy, and
license jobs with one strict final foundation conclusion.

**Steps**

1. Create `.github/workflows/foundation.yml` for pull requests and protected pushes.
2. Pin every action revision to an immutable SHA with a readable version comment.
3. Use Linux x86_64 and exact Node 24.18.0, npm 11.16.0, and Zig 0.16.0.
4. Checkout submodules recursively and require the pinned ShovelerDB source.
5. Run `npm ci`; never rewrite the root lock in CI or this package.
6. Create separate jobs for every focused command in the acceptance matrix.
7. Invoke `npm run migration:negative` literally in its own required job.
8. Give jobs narrow stable names suitable for branch protection.
9. Prevent one failure from cancelling other focused diagnostics.
10. Add bounded timeouts, readiness retries, and useful sanitized failure logs.
11. Start real services only for the jobs that need them.
12. Use temporary paths and synthetic persistence/proxy data.
13. Add a required aggregation job depending on every focused job.
14. Fail aggregation when any dependency fails, is cancelled, or is skipped.
15. Reuse producer commands; do not duplicate their implementation inline.

**Validation**

- Lint workflow YAML and inspect action pins and permissions.
- Break one gate at a time and verify direct attribution plus aggregate failure.
- Confirm logs contain no secrets, client, bank, invoice, or private-key data.

### Subtask T049 – Full Verification and Reference Performance Protocol

**Purpose**

Prove `npm run verify:foundation` matches CI, completes within 15 minutes, and measures
the real same-origin WP08+WP10 health path exactly as the specification requires.

**Steps**

1. Treat `npm run verify:foundation` as the sole canonical aggregate command.
2. Confirm WP01 wiring invokes every mandatory focused command exactly.
3. Do not edit root package metadata or locks; route missing wiring to WP01.
4. Require real contract mutations, migration negatives, durability, web, and proxy tests.
5. Run licensing last without masking earlier output; fail on the first required failure.
6. Use Linux x86_64 with at least 4 logical CPUs and at least 16 GiB RAM.
7. Record runner image, kernel, CPU count/model, memory, filesystem, tool versions, and commit.
8. Start every measured run from a clean checkout with empty dependency/build caches.
9. Use monotonic timers for bootstrap, validation, and every health sample.
10. For NFR-001, start immediately before bootstrap and stop after same-origin health passes;
    include dependencies, builds, validation, startup, and smoke, but exclude checkout/tools.
11. For NFR-008, time the full validation command through its final required result.
12. Require both NFR-001 and NFR-008 durations to be no more than 15 minutes.
13. Build production Next.js from WP10 and start a Ready real Zig service from WP08.
14. Send health through `http://localhost:3000/api/v1/health`, never directly for acceptance.
15. Issue 10 sequential warmups and discard them from the measured sample.
16. Issue exactly 100 sequential measured requests with no concurrency or discarded samples.
17. Start each monotonic sample before send and stop after the full body is read.
18. Require valid responses, sort durations ascending, and select one-based sample 99 as p99.
19. Require nearest-rank p99 at or below 1,000 ms and record min/median/p99/max.
20. Emit machine-readable commands, durations, invalid/slow counts, and wall-clock totals.

**Validation**

- Confirm each focused command remains independently runnable.
- Verify the aggregate fails when any focused gate is deliberately failed.
- Reject undersized, cached, concurrent, mocked, direct-Zig, or non-monotonic evidence.

### Subtask T050 – Deterministic Runtime License Policy

**Purpose**

Audit the actual distributed runtime closure deterministically and fail closed unless every
component has explicit GPL-2.0-only-compatible evidence and preserved notices.

**Steps**

1. Implement the audit at `tools/licenses/src/main.ts` with package-owned tests/policy data.
2. Enumerate locked transitive production npm dependencies, Zig modules, source/submodules,
   distributed fonts/assets, and built runtime/container contents when applicable.
3. Include ShovelerDB at its exact pinned commit and verify its attribution.
4. Sort records by stable component identity; exclude timestamps, absolute paths, and host order.
5. Record identity, version/commit, source, runtime role, SPDX expression, selected license,
   notice path, dependency path, evidence path/digest, and compatibility disposition.
6. Require SPDX identifiers/expressions plus committed license/notice evidence.
7. For dual- or multi-licensed components, require a committed explicit selection of the
   compatible SPDX branch; never guess, auto-select, or silently change that selection.
8. Fail on unknown, missing, ambiguous, custom, conflicting, or unselected license evidence.
9. Fail GPL-3.0-only, incompatible Apache-2.0 combined-runtime code, and other incompatibility.
10. Allow separate build/orchestration tools only with deterministic proof they are not shipped.
11. Keep nuanced linking/exception cases failing until explicit human legal review is recorded.
12. Preserve every required copyright, license, and notice in the distribution.
13. Resolve solely from committed policy, lockfiles, source trees, and produced artifacts;
    forbid unpinned registry, web, API, or other network-dependent classification.
14. Emit byte-identical machine-readable reports for unchanged committed inputs.

**Validation**

- Run `npm run licenses:check` twice and compare exact report bytes.
- Inject unknown, incompatible, and unselected dual-license cases; each must block acceptance.
- Verify the diagnostic identifies component, dependency path, evidence, and policy reason.

### Subtask T051 – Public Clean-Clone Reproduction Proof

**Purpose**

Prove an exact candidate builds from public committed inputs without sibling repositories,
private registries, warm artifacts, floating revisions, or hidden state.

**Steps**

1. Clone the public origin recursively into a fresh directory outside existing worktrees.
2. Checkout the exact candidate commit detached and require a clean working tree.
3. Use a fresh HOME/cache boundary and empty project build/dependency outputs.
4. Reject sibling paths, absolute local paths, private registries, and moving references.
5. Verify npm lock integrity plus immutable Zig and submodule identities.
6. Run `npm ci` and reject lockfile modification.
7. Run `npm run verify:foundation` exactly as documented.
8. Start the documented real Zig and production Next.js services.
9. Request same-origin `/api/v1/health` and require its structured success boundary.
10. Apply the T049 reference timing protocol and record exact environment/candidate evidence.
11. Require `git status --porcelain` to remain empty after verification.

**Validation**

- Repeat on the reference CI runner, not only a developer workstation.
- Fail on any hidden, unpublished, unpinned, cached, or manually repaired input.
- Route dependency packaging failures to WP04 and bootstrap/root failures to WP01.

### Subtask T052 – Stable Digests and Legal P0 Manifest Promotion

**Purpose**

Replace Draft pending evidence with exact immutable digests and advance the explicitly owned
`contracts/manifests/p0.json` only through lifecycle states proven by repository evidence.

**Steps**

1. Modify only the owned canonical path `contracts/manifests/p0.json`.
2. Preserve `baseline_commit` as the planning base; never make it self-referential.
3. Normalize, existence-check, and SHA-256 hash exact output/fixture file bytes.
4. Require valid and invalid frozen fixtures; reject traversal, duplicates, and symlink escape.
5. Sort inputs, outputs, and fixtures by documented semantic identity.
6. Compute the immutable contract ID/version/input/output/fixture projection.
7. Serialize with RFC 8785 JCS and SHA-256 hash the exact UTF-8 bytes.
8. Exclude lifecycle state, baseline, ownership, and `content_digest` from that projection.
9. Use WP03's lifecycle tool; never hand-edit around a failure.
10. Advance Draft → Frozen → Implemented → Verified without skips or regressions.
11. Require identical content identity from Frozen through Verified.
12. Permit Verified only after T048-T051, T053, and governed-doc sync/drift checks pass.
13. Record commands, old/new states, candidate commit, digests, and evidence IDs.
14. Leave the last justified state unchanged and fail WP11 when evidence is incomplete.

**Validation**

- Independently recompute one output, one fixture, and the RFC 8785 content digest.
- Mutate one covered byte and confirm promotion fails without rewriting the manifest.
- Confirm Verified is impossible while any required evidence is absent.

### Subtask T053 – Immutable P1-P4 Conformance and Ownership

**Purpose**

Prove the pinned downstream Drafts consume P0 without ownership conflicts or a second dialect,
using only the immutable committed conformance lock produced by WP03.

**Steps**

1. Consume `contracts/conformance/p0-p4-inputs.json` exactly as committed by WP03.
2. Require exactly P1-P4 records with full 40-hex commits, manifest SHA-256 values, and
   contract content digests; verify both digests before parsing/composition.
3. Resolve each manifest/output from its pinned commit only.
4. Reject branches, tags, abbreviations, `HEAD`, current/target branch discovery, merge-base,
   sibling checkout, working-tree input, unavailable commit, missing owner, or digest drift.
5. Changing a pin requires WP03's explicit committed baseline-refresh procedure and complete
   affected composition/fixture revalidation; WP11 never rewrites the lock.
6. Validate lifecycle shape, identity/version, owner, baseline, evidence, and state.
7. Verify dependency/input bijections and canonical stable `$id` references without network.
8. Compose real P1-P4 fragments, catalogs, and modules with P0 twice; compare exact bytes.
9. Reject route/method, operation, schema, event, mount, and access-policy collisions.
10. Verify migration/fixture roots are owner-scoped and exclusive owned paths do not overlap.
11. Require documented integration-steward touchpoints and reject shared registry edits.
12. Use real pinned Draft inputs; toy-only surrogates cannot satisfy acceptance.
13. Do not edit downstream artifacts; route exact failures to P1, P2, P3, or P4.
14. Record pins, digests, commands, and results in `docs/program-ledger.md`.

**Validation**

- Run `npm run contracts:check` against the committed lock with network disabled.
- Mutate a digest, moving ref, ownership overlap, and canonical reference to prove rejection.
- Confirm checks do not mutate the lock, downstream artifacts, or generated tracked files.

### Subtask T054 – README, Governed-Doc Check, and Program Handoff

**Purpose**

Document only executed commands and evidence, prove the orchestrator's governed-doc sync is
still current, and make every next program action or blocker explicit.

**Steps**

1. Require the orchestrator's committed pre-acceptance governed-doc sync receipt/evidence ID.
2. Verify synchronized spec, plan, data model, quickstart, canonical examples, architecture
   notes, and glossary have no drift at the candidate; fail and route drift to the orchestrator.
3. Never edit quickstart or any `kitty-specs/` artifact from WP11.
4. Create a concise README with purpose, GPL-2.0-only status, supported baseline, immutable
   quickstart link, prerequisites, clone/bootstrap, focused gates, aggregate, and local run.
5. Document the same-origin health path and generated/owner-contribution rules.
6. Document common failures with focused command and responsible owner.
7. Update the ledger's P0 state, manifest state/digest, candidate commit, and evidence paths.
8. Record immutable P1-P4 conformance pins/results without replacing them with branch heads.
9. Record focused/aggregate results, clean-clone environment/timings, proxy statistics,
   license report/notice evidence, governed-sync receipt, and drift-check result.
10. Name remaining blockers and owning missions; never use vague TBD text.
11. State that downstream implementation requires P0 merge and baseline revalidation.
12. Never mark P1-P4 Implemented, Accepted, or Merged from Draft conformance alone.
13. Keep prior ledger context auditable and make no unsupported release claim.

**Validation**

- Execute every README command from the clean clone used by T051.
- Cross-check every commit, digest, state, timing, statistic, and evidence path.
- Confirm governed documents remain byte-identical to the completed sync baseline.
- Confirm README and ledger agree on versions, states, pins, blockers, and next owners.

## Failure Routing Rules

- Contract lifecycle, composition, collision, conformance-lock, or generated-type → WP03.
- Common schema or cross-runtime value mismatch → WP02 or WP05 by source.
- ShovelerDB fetch, pin, build, adapter, or dependency notice → WP04.
- Transaction, checkpoint, directory sync, close, reopen, or durability → WP06.
- Migration discovery, graph, drift, DDL-reopen, or `migration:negative` → WP07.
- Zig health, readiness, route policy, or direct service smoke → WP08.
- Next.js package/config → WP09; shell, proxy, client, E2E, or root lock → WP10.
- Root script or toolchain bootstrap → WP01.
- P1-P4 artifact/ownership failure → exact downstream owner; governed-doc drift → orchestrator.
- License policy/report → WP11; incompatible dependency → its producer owner.
- Every route includes command, candidate, exit code, reproducer, diagnostic, and owning path.
- Do not implement a producer fix inside WP11.

## Definition of Done

- [ ] T048 exposes all independent jobs and strict aggregation.
- [ ] Exact `npm run migration:negative` is independently required and aggregated.
- [ ] T049 executes the full matrix within 15 minutes under the exact reference protocol.
- [ ] Real WP08+WP10 proxy p99 uses sample 99 of exactly 100 sequential measured requests.
- [ ] T050 deterministically audits the runtime, explicit dual-license selections, and notices.
- [ ] Unknown, incompatible, network-dependent, or ambiguous license evidence fails closed.
- [ ] T051 passes from a fresh public detached clone with empty caches and a clean final tree.
- [ ] T052 legally promotes the explicitly owned P0 manifest with stable content identity.
- [ ] T053 validates immutable digest-pinned P1-P4 inputs and rejects moving heads.
- [ ] T054 proves governed-doc sync/no-drift and does not edit quickstart or `kitty-specs/`.
- [ ] README and ledger contain only commands, states, pins, timings, and evidence that passed.
- [ ] Producer/downstream failures are routed instead of absorbed.

## Risks & Mitigations

- **Closure absorbs unfinished work**: route producer defects to their owners.
- **A moving head changes conformance**: accept only committed full-commit/digest pins.
- **Performance evidence cherry-picks samples**: enforce environment, cache, timer, and exact
  warmup/sample/nearest-rank rules in CI and machine-readable evidence.
- **License output varies or guesses dual licensing**: sort committed evidence, select one SPDX
  branch explicitly, forbid unpinned network classification, and fail unknowns.
- **Lifecycle advances optimistically**: require every gate before legal manifest promotion.
- **Governed docs drift or closure edits quickstart**: require sync receipt/no-drift and route it.
- **Codebase-wide scope erases ownership**: restrict writes to the five declared surfaces.
- **Evidence leaks sensitive data**: use synthetic inputs and redact logs.

## Reviewer Guidance

- Confirm frontmatter ownership, scope, dependencies, requirements, and T048-T054 traceability.
- Inspect CI action pins, permissions, timeouts, exact commands, and aggregation dependencies.
- Confirm `migration:negative` is literal, mandatory, independent, and aggregated.
- Repeat the real proxy protocol and clean clone on the qualifying Linux reference runner.
- Inspect license enumeration, SPDX selections, notices, deterministic bytes, and offline policy.
- Independently recompute manifest/content digests and resolve P1-P4 pins without moving refs.
- Trace legal manifest transitions and verify content identity remains stable.
- Verify orchestrator sync evidence and no governed-doc drift; reject any quickstart edit.
- Confirm no producer or downstream artifact was modified to manufacture green results.
- Compare workflow, README, manifest, and ledger claims against raw evidence.

## Activity Log

> Entries must remain chronological. Append new entries at the end.

- 2026-07-20T07:15:58Z – system – WP11 prompt adapted from the original closure package,
  remapped to T048-T054, and tightened for immutable conformance, real combined proxy timing,
  exact migration-negative, deterministic licensing, governed-doc sync, and manifest ownership.

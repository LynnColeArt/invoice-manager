---
work_package_id: WP10
title: Foundation Acceptance and Program Handoff
dependencies:
- WP03
- WP04
- WP05
- WP06
- WP07
- WP08
- WP09
requirement_refs:
- FR-001
- FR-008
- FR-015
- FR-016
- NFR-001
- NFR-002
- NFR-003
- NFR-005
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
- T047
- T048
- T049
- T050
- T051
- T052
- T053
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
execution_mode: code_change
model: ''
owned_files:
- .github/workflows/foundation*
- tools/licenses/**
- README*
- docs/program-ledger.md
role: implementer
tags: []
task_type: implement
---

# Work Package Prompt: WP10 – Foundation Acceptance and Program Handoff

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Close P0 with auditable evidence: independently diagnosable CI jobs, one bounded full
verification target, a transitive GPL-2.0-only runtime audit, a true clean-clone proof,
legal manifest promotion, real P1-P4 conformance checks, and an accurate program handoff.

This is an integration and verification gate. It runs producer-owned checks and records
their results; it does not become the author of missing producer code, tests, fixtures,
contracts, notices, or build wiring.

## Context and Gate Posture

- Every producing WP must be complete before WP10 can report P0 acceptance.
- Read `spec.md`, `plan.md`, `data-model.md`, `research.md`, and `quickstart.md` first.
- Run their commands exactly as contributors and CI will run them.
- Do not patch producer surfaces from this package when a command fails.
- Route the failure to the owning WP with command, exit status, and focused diagnostics.
- Re-run the entire relevant gate after the owner supplies a fix.
- Never convert a failing check into a warning to make the closure package green.
- Keep evidence synthetic and redact tokens, private paths, and environment secrets.

## Codebase-Wide Exemption

- `scope: codebase-wide` permits this package to inspect every repository surface.
- Its normal writes remain limited to the exact `owned_files` frontmatter patterns.
- One narrow write exemption permits updating `contracts/manifests/p0.json`.
- That exemption exists only to fill verified evidence and advance legal lifecycle state.
- Do not use it to redesign the manifest schema or change contract semantics.
- Do not edit another producer's source or tests under the exemption.
- Do not edit P1-P4 artifacts, branches, or manifests.
- The planning copy of a Draft contract is historical input, not a shortcut around WP03.
- Every manifest transition must pass the WP03 lifecycle command and be evidence-backed.

## Branch Strategy

- **Strategy**: `wp_branch`
- **Planning base branch**: `feat/p0-contract-spine`
- **Merge target branch**: `feat/p0-contract-spine`
- Start with the governed implementation action:

```bash
spec-kitty agent action implement WP10 --agent codex
```

- Verify the branch includes accepted outputs from WP03 through WP09.
- Do not merge, rebase, tag, publish, or advance downstream missions from this package.
- Record the exact candidate commit and program baseline used by every final evidence run.

## Required Acceptance Matrix

| Gate | Focused command | Primary owner on failure |
| --- | --- | --- |
| Contracts | `npm run contracts:check` | WP03; WP02 for common wire sources |
| Web | `npm run web:check` | WP09 |
| Zig service | `npm run api:check` | WP05/WP08; WP04 for build integration |
| Migration negative | producer-defined migration gate | WP06 |
| Persistence | `npm run persistence:integration` | WP07; WP04/WP06 at their seams |
| HTTP/proxy | `npm run http:smoke` | WP08 or WP09 by failing boundary |
| Runtime license | `npm run licenses:check` | WP10 report; dependency owner for fix |
| Aggregate | `npm run verify:foundation` | Route to the first focused failing owner |

- Each focused command must be runnable without first running the aggregate command.
- A focused failure must name the owning surface without hiding unrelated job results.
- The aggregate target must call the same underlying commands as the focused jobs.

## Subtasks & Detailed Guidance

### Subtask T047 – Independent Foundation CI Jobs

**Purpose**

Create CI that reports contract, web, Zig, migration, persistence, HTTP, and licensing
failures independently while retaining one required foundation conclusion.

**Steps**

1. Create `.github/workflows/foundation.yml` for pull requests and protected pushes.
2. Pin action revisions to immutable commit SHAs and retain readable version comments.
3. Use the approved Linux x86_64 reference runner.
4. Install Node.js 24.18.0, npm 11.16.0, and Zig 0.16.0 exactly.
5. Checkout submodules recursively and fail when the pinned ShovelerDB source is absent.
6. Run `npm ci`; never use `npm install` to rewrite the lock in CI.
7. Define separate jobs for contracts, web, Zig API, migration-negative,
   persistence integration, HTTP/proxy smoke, and runtime-license audit.
8. Give each job a narrow descriptive name suitable for branch protection.
9. Keep jobs independent enough that one failure does not cancel all diagnostics.
10. Add explicit timeouts; no job may wait indefinitely for a service or port.
11. Start real services only in the jobs that need them.
12. Wait for readiness with bounded retries and preserve startup logs on failure.
13. Use temporary paths and synthetic values for persistence and smoke tests.
14. Upload only useful failure diagnostics; do not upload databases or secret-bearing env.
15. Add a final required aggregation job that depends on every focused job.
16. Make the aggregation job fail if any required dependency failed or was skipped.
17. Avoid duplicating producer commands inline when a focused script already exists.

**Files**

- `.github/workflows/foundation.yml`

**Validation**

- Lint workflow YAML and inspect action pins.
- Mutate one gate at a time and verify only the responsible focused job fails directly.
- Verify the final aggregation job blocks acceptance for every focused failure.
- Confirm logs contain no token, customer, bank, invoice, password, or private key.

### Subtask T048 – Full Verification Target and Runtime Budget

**Purpose**

Prove that one documented command runs the same complete foundation suite as CI and finishes
within the 15-minute reference-runner target without masking focused diagnostics.

**Steps**

1. Treat `npm run verify:foundation` as the canonical aggregate command.
2. Confirm WP01 already wires it; do not edit root package files here.
3. Confirm it invokes every required focused command from the acceptance matrix.
4. Confirm it invokes the producer-owned migration-negative gate explicitly.
5. Ensure the aggregate exits nonzero on the first failed required command.
6. Keep output sectioned so the responsible command remains evident.
7. Do not replace real persistence or HTTP tests with mocks in the aggregate.
8. Run contract composition twice and compare byte-identical output.
9. Run all documented collision mutation cases.
10. Run Zig formatting, build, tests, and required coverage thresholds.
11. Run web lint, strict types, component tests, and production build.
12. Run migration first-use, no-op, collision, dependency, cycle, and drift tests.
13. Run 20 persistence durability cycles plus injected checkpoint/sync failures.
14. Run black-box Zig health and Next.js same-origin proxy smoke tests.
15. Run the transitive runtime-license audit last without suppressing prior output.
16. Measure wall-clock duration on the reference CI class.
17. Require the full validation to complete within 15 minutes.

**Files**

- `.github/workflows/foundation.yml`
- `README.md`

**Validation**

- Run `time npm run verify:foundation` on the supported Linux baseline.
- Confirm every focused command can still run independently.
- Confirm a deliberately failed focused gate makes the aggregate fail.
- Route missing or broken root wiring to WP01 instead of editing it here.

### Subtask T049 – Transitive GPL-2.0-Only Runtime License Audit

**Purpose**

Audit the actual distributed runtime closure, preserve notices, and fail closed on unknown or
incompatible licensing without confusing separate build tools with combined runtime code.

**Steps**

1. Implement the audit entry point at `tools/licenses/src/main.ts`.
2. Read the locked npm dependency graph, including transitive production dependencies.
3. Inspect Zig modules, vendored/source dependencies, and submodule revisions.
4. Include ShovelerDB at its exact pinned commit and verify its attribution.
5. Inspect any fonts or other assets actually distributed by P0.
6. Inspect produced runtime/container contents if P0 builds a distributable image.
7. Exclude development-only tools only when the lock and build prove they are not shipped.
8. Classify every discovered component by identity, version/commit, source, license,
   runtime role, notice path, and compatibility disposition.
9. Require SPDX evidence or a reviewed license file; do not trust package metadata alone.
10. Fail on missing, ambiguous, custom, conflicting, or unknown license evidence.
11. Fail on dependencies incompatible with a GPL-2.0-only combined runtime.
12. Treat GPL-3.0-only as incompatible with GPL-2.0-only.
13. Treat Apache-2.0 code as incompatible when combined into the GPL-2.0-only runtime.
14. Allow a separate Apache-2.0 build/orchestration program only with recorded separation.
15. Do not make an automatic legal conclusion for nuanced linking or exception terms.
16. Route nuanced cases for explicit review and keep the gate failing meanwhile.
17. Verify required copyright and license notices exist in the distribution.

**Files**

- `tools/licenses/src/main.ts`
- Additional `tools/licenses/**` tests and reviewed policy data when necessary.

**Validation**

- Run `npm run licenses:check` against the clean locked tree.
- Inject one unknown license and one known incompatible runtime license.
- Verify each blocks acceptance with the exact component and dependency path.
- Verify all distributed third-party components have preserved notices.

### Subtask T050 – Public Clean-Clone Reproduction Proof

**Purpose**

Prove a new contributor can build and validate the candidate using only committed public,
pinned inputs—without sibling repositories, private registries, warm artifacts, or hidden state.

**Steps**

1. Perform the proof from an exact candidate commit, never a dirty working tree.
2. Create a fresh temporary directory outside all existing worktrees.
3. Clone with submodules recursively using the same public origin a contributor uses.
4. Checkout the exact candidate commit in detached mode.
5. Confirm no dependency resolves through a sibling checkout or absolute local path.
6. Confirm no npm dependency uses an unpinned tag, range, branch, or private registry.
7. Confirm every Zig dependency resolves by immutable version, digest, or commit.
8. Begin with empty project build outputs and no copied `node_modules`.
9. Use a fresh temporary HOME/cache boundary or record any unavoidable toolchain cache.
10. Run `npm ci` and reject any lockfile modification.
11. Run `npm run verify:foundation` exactly as documented.
12. Start the local Zig and Next.js services using documented commands.
13. Request `http://localhost:3000/api/v1/health` through the same-origin proxy.
14. Verify no undocumented manual edit is needed.
15. Measure bootstrap plus foundation verification under the 15-minute goal.
16. Record OS, architecture, exact tool versions, candidate commit, and elapsed time.
17. Run `git status --porcelain` and require a clean result after verification.

**Commands**

```bash
git clone --recurse-submodules <public-invoice-manager-origin> <fresh-directory>
git -C <fresh-directory> checkout --detach <candidate-commit>
npm --prefix <fresh-directory> ci
npm --prefix <fresh-directory> run verify:foundation
git -C <fresh-directory> status --porcelain
```

**Validation**

- Require empty final status output.
- Repeat once on the reference CI runner, not only the developer workstation.
- Fail if any input comes from an unpublished sibling path or floating revision.
- Route packaging failures to WP04 and root/bootstrap failures to WP01.

### Subtask T051 – Stable Digests and Legal P0 Manifest Promotion

**Purpose**

Replace Draft `pending` evidence with exact immutable content, then advance the canonical P0
manifest only through states whose definitions are proven by real repository evidence.

**Steps**

1. Use `contracts/manifests/p0.json` as the canonical implementation manifest.
2. Exercise only the narrow codebase-wide manifest-write exemption defined above.
3. Preserve `baseline_commit` as the original planning base; do not make it self-referential.
4. Normalize and verify every output and integration-fixture path.
5. Compute each output digest as SHA-256 over exact committed file bytes.
6. Compute each fixture digest as SHA-256 over exact committed file bytes.
7. Require at least one valid and one invalid frozen integration fixture.
8. Reject missing files, duplicate normalized paths, traversal, or symlink escape.
9. Sort inputs, outputs, and fixtures by their documented semantic identity.
10. Form the immutable content projection from contract ID, version, inputs,
    outputs, and integration fixtures only.
11. Serialize the projection using RFC 8785 JSON Canonicalization Scheme.
12. Compute `content_digest` as SHA-256 over the exact JCS UTF-8 bytes.
13. Exclude lifecycle state, baseline, ownership, and `content_digest` itself.
14. Run the WP03 lifecycle tool; do not hand-edit around a failed gate.
15. Advance Draft to Frozen only after sources, fixtures, paths, and digests pass.
16. Advance Frozen to Implemented only after all producer code and focused gates exist.
17. Advance Implemented to Verified only after T047-T050 and T052 pass for real.
18. Never jump Draft directly to Implemented or Verified.
19. Never regress, reuse a version after content change, or advance from Superseded.
20. Require the content digest to remain identical from Frozen through Verified.
21. Record transition commands, prior/new states, candidate commit, and evidence IDs.
22. If any evidence is missing, leave the manifest at its last justified state and fail WP10.

**Files**

- Narrow exemption: `contracts/manifests/p0.json` only.
- Evidence references in `docs/program-ledger.md`.

**Validation**

- Independently recompute the RFC 8785 content digest during review.
- Verify all concrete output and fixture digests against exact bytes.
- Mutate one covered byte and confirm promotion fails without rewriting the manifest.
- Confirm final Verified state exists only after all acceptance evidence passes.

### Subtask T052 – Actual P1-P4 Draft Conformance and Ownership Boundaries

**Purpose**

Prove the current downstream Drafts really consume the implemented P0 contract spine and can
continue as independent missions without conflicting ownership or a second contract dialect.

**Steps**

1. Resolve the current target branch and exact head for P1, P2, P3, and P4.
2. Do not rely on stale hashes currently recorded in the ledger.
3. Read each actual Draft manifest and contract output at its resolved immutable head.
4. Fail if a target branch, mission handle, manifest, or referenced output is unavailable.
5. Validate all four manifests against the canonical P0 lifecycle schema.
6. Require state Draft unless the owner has separately supplied valid later-state evidence.
7. Verify contract ID, mission handle, owner, version, baseline, and content evidence shape.
8. Verify each dependency owner has exactly one input and every input owner is declared.
9. Verify P0 references use canonical stable `$id` values, not planning-copy file paths.
10. Resolve all downstream external references without network access.
11. Compose the real P1-P4 fragments/catalogs/modules with P0 twice.
12. Compare exact bytes and run route, operation, schema, event, and mount collision checks.
13. Verify route-access policy remains protected by default with explicit public exceptions.
14. Verify migration roots and fixture roots remain owner-scoped.
15. Compare `owned_paths` across missions after normalization.
16. Reject exclusive-path overlaps and undocumented shared touchpoints.
17. Verify shared touchpoints name the integration steward and a coordination reason.
18. Reject edits to root registries, generated aggregates, or another mission's domain paths.
19. Use real Draft inputs; toy-only surrogate fragments cannot satisfy this gate.
20. Do not edit downstream artifacts to make validation pass.
21. Route a conformance failure to P1, P2, P3, or P4 with exact path and diagnostic.
22. Re-run against the owner's new immutable head after correction.
23. Record final heads and results in the program ledger.

**Validation**

- Run `npm run contracts:check` with the resolved real P1-P4 inputs.
- Compare ownership results with the program ledger's ownership table.
- Mutate one overlap and one canonical-reference error to prove the checks are active.
- Confirm downstream implementation remains blocked until P0 is merged/revalidated.

### Subtask T053 – README and Program-Ledger Handoff

**Purpose**

Replace planning promises with commands and evidence that were actually executed, while
making the next program wave and every remaining blocker explicit.

**Steps**

1. Create a concise root `README.md` with project purpose, GPL-2.0-only status,
   supported baseline, quickstart link, and foundation verification command.
2. Keep the README foundation-scoped; do not advertise unimplemented product features.
3. Treat the existing P0 quickstart as immutable planning evidence: verify its commands and report contradictions to the mission owner instead of editing files under `kitty-specs/`.
4. Document exact supported Node, npm, Zig, Linux, and Git/submodule prerequisites.
5. Document clone, `npm ci`, focused gates, aggregate verification, and local run commands.
6. Document the same-origin health URL and expected structured response boundary.
7. Document generated-artifact and owner-contribution rules.
8. Document common failures with the responsible focused command and owner.
9. Update the program ledger's P0 mission state, contract state, and current branch head.
10. Record the final content digest and exact evidence paths without self-referential commits.
11. Update planning snapshots to actual current P1-P4 heads verified in T052.
12. Update the contract register, dependency register, and P0 foundation checkpoint.
13. Record focused/aggregate command results, clean-clone environment, and elapsed time.
14. Record license report result and preserved-notice evidence.
15. Name any remaining blocker and owning mission; never replace it with vague TBD text.
16. State that P1-P4 implementation unlock requires P0 merge and baseline revalidation.
17. Do not mark P1-P4 Implemented, Accepted, or Merged on the basis of Draft conformance.
18. Do not claim a command is supported unless T047-T050 executed it successfully.
19. Keep ledger history auditable rather than deleting prior planning context silently.

**Files**

- `README.md`
- `docs/program-ledger.md`

**Validation**

- Execute every command copied into README from a clean clone.
- Check the planning quickstart's commands for drift and route any correction to the mission-planning owner; do not mutate the governed planning artifact from this WP.
- Cross-check every recorded commit, digest, state, duration, and evidence path.
- Confirm the ledger names exact downstream next actions and owners.
- Confirm documentation makes no unsupported implementation or release claim.

## Failure Routing Rules

- Contract schema, lifecycle, composition, collision, or generated-type failure → WP03.
- Common-value schema or cross-runtime wire mismatch → WP02 or WP05 by source.
- ShovelerDB fetch, pin, build, ABI adapter, or dependency notice failure → WP04.
- Migration discovery, graph, digest, DDL-reopen, or negative-test failure → WP06.
- Transaction, checkpoint, directory sync, close, reopen, or durability failure → WP07.
- Zig health envelope, readiness, route policy, or service smoke failure → WP08.
- Next.js build, accessibility, client, proxy, or web E2E failure → WP09.
- Root npm script, lock, or toolchain bootstrap failure → WP01.
- P1-P4 manifest, reference, fixture, or ownership failure → the exact downstream owner.
- License policy/report implementation failure → WP10; incompatible dependency → its owner.
- For every route, include command, candidate commit, exit code, minimal reproducer,
  stable diagnostic, expected behavior, and the exact owning path.
- Do not apply the producer fix inside WP10.

## Definition of Done

- [ ] T047 exposes independent required CI jobs plus a strict aggregation result.
- [ ] T048 runs all focused gates through `npm run verify:foundation`.
- [ ] Full foundation validation finishes within 15 minutes on the reference runner.
- [ ] T049 audits the full transitive distributed runtime and preserves all notices.
- [ ] Unknown and incompatible licenses fail closed with dependency paths.
- [ ] T050 passes from a fresh public clone with no hidden or floating dependency.
- [ ] T051 replaces all pending P0 evidence with exact file and content digests.
- [ ] P0 follows Draft → Frozen → Implemented → Verified without a skipped state.
- [ ] Stable content identity remains unchanged across post-Frozen state changes.
- [ ] T052 validates actual current P1-P4 Drafts and ownership boundaries.
- [ ] Downstream failures are routed to owners rather than absorbed.
- [ ] T053 documents only commands and evidence that actually passed.
- [ ] README and ledger agree on versions, states, heads, and next steps; the immutable
  planning quickstart contains no unreported contradiction.

## Risks & Mitigations

- **Closure package absorbs unfinished work**: route every producer defect to its owner.
- **Clean clone reuses local state**: use a fresh detached clone and empty build outputs.
- **License audit trusts incomplete metadata**: verify SPDX plus actual license/notice files.
- **Nuanced license terms are auto-approved**: fail pending explicit human legal review.
- **Lifecycle state is advanced optimistically**: require evidence at each legal transition.
- **Toy contracts make conformance vacuous**: require actual P1-P4 Draft artifacts.
- **Codebase-wide scope erases ownership**: restrict writes to owned files and one manifest.
- **Evidence leaks environment data**: retain safe diagnostics and redact secrets/paths.

## Reviewer Guidance

- Verify the package did not modify producer code or tests to manufacture green results.
- Inspect every CI action pin, permission, timeout, and required aggregation dependency.
- Inspect the runtime license closure, dependency paths, and preserved notices manually.
- Repeat the clean-clone proof from the exact candidate commit on reference Linux.
- Independently compute one output digest, one fixture digest, and the JCS content digest.
- Trace all manifest transitions and confirm content identity remains stable.
- Reject Verified state if any T047-T050 or T052 evidence is missing.
- Resolve P1-P4 heads independently and compare them with the ledger.
- Inspect canonical references, dependency/input bijections, and ownership overlaps.
- Confirm no downstream artifact was edited by WP10.
- Compare README, workflow, manifest, and ledger claims line by line, using the planning
  quickstart only as immutable intent evidence.

## Activity Log

> Entries must remain chronological. Append new entries at the end.

- 2026-07-20T07:15:58Z – system – Prompt created for independent acceptance jobs,
  full verification, runtime licensing, clean-clone proof, legal manifest promotion,
  real P1-P4 conformance, failure routing, and program handoff.

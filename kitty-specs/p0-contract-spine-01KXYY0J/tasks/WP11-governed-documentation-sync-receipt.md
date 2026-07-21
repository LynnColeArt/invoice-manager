---
work_package_id: WP11
title: Governed Documentation Sync Attestation
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
- FR-015
- FR-016
- NFR-010
- C-007
- C-010
tracker_refs: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch.
subtasks:
- T048
- T049
- T050
phase: Phase 5
assignee: ''
agent: "reviewer-renata"
history: []
agent_profile: curator-carla
authoritative_surface: docs/governance/
create_intent:
- docs/governance/p0-governed-doc-sync.json
execution_mode: planning_artifact
model: ''
owned_files:
- docs/governance/p0-governed-doc-sync.json
role: curator
tags: []
task_type: implement
shell_pid: "1807838"
---

# Work Package Prompt: WP11 – Governed Documentation Sync Attestation

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter,
and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `curator-carla`
- **Role**: `curator`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for
this work package's `task_type` and `authoritative_surface`.

---

## Objective

Read and reconcile the exact governed P0 artifact inventory against accepted WP03-WP10
behavior, route any required mission-document update to the authorized external Spec Kitty
orchestrator, and create one schema-exact attestation at
`docs/governance/p0-governed-doc-sync.json`.

This is a `planning_artifact` operation with one owned path. WP11 never writes a mission
artifact, charter, contract, source, generated, CI, task, lane, or state file. WP12 remains the
sole closure and acceptance package.

## Context and Governance Boundary

- Execute only after WP03 through WP10 are implemented, reviewed, and present together on
  `feat/p0-contract-spine`.
- Treat `contracts/governed-doc-sync-v1.schema.json` as the authoritative receipt contract.
- Apply Living Documentation Sync (`DIRECTIVE_037`) to observable behavior and canonical terms.
- Read the schema's exact 18 `required_artifacts`; never infer inventory from the receipt.
- Compare commands, fixtures, examples, security boundaries, ownership, and acceptance claims
  with accepted producer evidence.
- If any mission artifact needs a change, pause WP11. Send the exact required edits and the
  schema's exact `commands.sync_safe_commit` to the authorized external Spec Kitty orchestrator.
- Resume only after that orchestrator reports the full synchronization commit and the working
  tree contains it. WP11 does not perform or authorize those external edits itself.
- If no mission artifact needs a change, no synchronization commit is created.
- Keep all examples synthetic and free of client, bank, invoice, credential, token, private-key,
  production-path, or other sensitive material.
- WP12 consumes only the full lowercase receipt commit returned through the accepted Spec Kitty
  review handoff and independently verifies its parent, diff, message, receipt, and drift. It
  must never rediscover trust from receipt contents, branch HEAD, or a latest-path Git query.

## Hard Ownership Rules

- Write only `docs/governance/p0-governed-doc-sync.json`.
- That receipt is the sole `owned_files` and `create_intent` entry.
- All 18 `required_artifacts`, including `.kittify/charter/charter.md`, are read-only to WP11.
- Never edit any `kitty-specs/` path, charter/doctrine path, application file, contract,
  generated surface, task prompt, `tasks.md`, `wps.yaml`, `lanes.json`, or event log.
- Never stage or commit the 18 read-only artifacts from this WP.
- Begin from a clean tracked tree at the accepted producer baseline; unrelated dirt blocks work.
- Do not merge, rebase, tag, publish, or advance mission lifecycle state from this package.

## Branch and Baseline Strategy

- Start the governed implementation action:

```bash
spec-kitty agent action implement WP11 --agent codex
```

- Require `git branch --show-current` to equal `feat/p0-contract-spine`.
- Capture `git rev-parse HEAD` before reconciliation as `producer_baseline_commit`.
- Require it to be one full lowercase 40-hex commit containing accepted WP03-WP10.
- If external synchronization is required, set `synchronized_baseline_commit` to the full
  commit produced by the orchestrator's exact sync safe-commit.
- If no synchronization is required, set `synchronized_baseline_commit` equal to
  `producer_baseline_commit`.
- The receipt is computed from the synchronized baseline and is committed in a later,
  receipt-only commit.

## Exact Read-Only Artifact Inventory

Both `required_artifacts` and `checked_artifacts` use this exact ordered 18-path inventory:

```text
.kittify/charter/charter.md
kitty-specs/p0-contract-spine-01KXYY0J/contracts/README.md
kitty-specs/p0-contract-spine-01KXYY0J/contracts/api-v1.openapi.yaml
kitty-specs/p0-contract-spine-01KXYY0J/contracts/common-v1.schema.json
kitty-specs/p0-contract-spine-01KXYY0J/contracts/contract-manifest-v1.schema.json
kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-catalog-v1.schema.json
kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-envelope-v1.schema.json
kitty-specs/p0-contract-spine-01KXYY0J/contracts/governed-doc-sync-v1.schema.json
kitty-specs/p0-contract-spine-01KXYY0J/contracts/migration-manifest-v1.schema.json
kitty-specs/p0-contract-spine-01KXYY0J/contracts/module-contribution-v1.schema.json
kitty-specs/p0-contract-spine-01KXYY0J/contracts/p0-contract-manifest.json
kitty-specs/p0-contract-spine-01KXYY0J/data-model.md
kitty-specs/p0-contract-spine-01KXYY0J/plan.md
kitty-specs/p0-contract-spine-01KXYY0J/quickstart.md
kitty-specs/p0-contract-spine-01KXYY0J/research.md
kitty-specs/p0-contract-spine-01KXYY0J/research/evidence-log.csv
kitty-specs/p0-contract-spine-01KXYY0J/research/source-register.csv
kitty-specs/p0-contract-spine-01KXYY0J/spec.md
```

Run the schema's exact `commands.resolver`:

```bash
git ls-files --error-unmatch -- .kittify/charter/charter.md kitty-specs/p0-contract-spine-01KXYY0J/contracts/README.md kitty-specs/p0-contract-spine-01KXYY0J/contracts/api-v1.openapi.yaml kitty-specs/p0-contract-spine-01KXYY0J/contracts/common-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/contract-manifest-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-catalog-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-envelope-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/governed-doc-sync-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/migration-manifest-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/module-contribution-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/p0-contract-manifest.json kitty-specs/p0-contract-spine-01KXYY0J/data-model.md kitty-specs/p0-contract-spine-01KXYY0J/plan.md kitty-specs/p0-contract-spine-01KXYY0J/quickstart.md kitty-specs/p0-contract-spine-01KXYY0J/research.md kitty-specs/p0-contract-spine-01KXYY0J/research/evidence-log.csv kitty-specs/p0-contract-spine-01KXYY0J/research/source-register.csv kitty-specs/p0-contract-spine-01KXYY0J/spec.md
```

Require exactly these 18 unique, tracked, regular, non-symlink files. Discovery commands,
globs, directory arguments, and receipt-provided paths are forbidden.

## Subtasks & Detailed Guidance

### Subtask T048 – Reconcile and Establish the Synchronized Baseline

**Purpose**

Determine whether the read-only governed inventory matches accepted producer behavior and
establish the exact baseline the attestation will cover.

**Steps**

1. Capture and validate `producer_baseline_commit` before reading claims.
2. Run the exact resolver and validate all 18 paths without editing them.
3. Read accepted WP03-WP10 prompts, evidence, and producer outputs read-only.
4. Map every artifact claim and canonical example to accepted evidence or an explicit blocker.
5. Decide, path by path, whether accepted behavior requires a mission-document change.
6. If no path requires a change, record the evidence and set
   `synchronized_baseline_commit = producer_baseline_commit`.
7. If one or more paths require changes, stop all WP11 writes and give the authorized external
   orchestrator the exact path-scoped edits, evidence, and command below.
8. Resume only after the synchronization commit is present on the target branch and its full
   lowercase 40-hex hash is known. Require exactly one synchronization commit directly after
   `producer_baseline_commit`: its sole parent equals that baseline, its subject is exactly
   `docs: synchronize governed P0 artifacts`, and its nonempty file list is a subset of the 17
   writable mission paths enumerated by `commands.sync_safe_commit`, with no charter or other path.
9. Set that full commit as `synchronized_baseline_commit` and re-run reconciliation read-only.
10. The charter must remain unchanged; a charter correction routes to charter governance.

The external orchestrator, not WP11, uses exact `commands.sync_safe_commit`:

```bash
spec-kitty safe-commit kitty-specs/p0-contract-spine-01KXYY0J/contracts/README.md kitty-specs/p0-contract-spine-01KXYY0J/contracts/api-v1.openapi.yaml kitty-specs/p0-contract-spine-01KXYY0J/contracts/common-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/contract-manifest-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-catalog-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-envelope-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/governed-doc-sync-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/migration-manifest-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/module-contribution-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/p0-contract-manifest.json kitty-specs/p0-contract-spine-01KXYY0J/data-model.md kitty-specs/p0-contract-spine-01KXYY0J/plan.md kitty-specs/p0-contract-spine-01KXYY0J/quickstart.md kitty-specs/p0-contract-spine-01KXYY0J/research.md kitty-specs/p0-contract-spine-01KXYY0J/research/evidence-log.csv kitty-specs/p0-contract-spine-01KXYY0J/research/source-register.csv kitty-specs/p0-contract-spine-01KXYY0J/spec.md --message "docs: synchronize governed P0 artifacts" --to-branch feat/p0-contract-spine
```

**Validation**

- The producer and synchronized baselines are full lowercase 40-hex commits.
- All 18 paths remain read-only to WP11 and reconcile at the synchronized baseline.
- Any external sync is separately authorized and verified as the one exact-path, exact-message
  commit directly after the producer baseline before WP11 resumes.

### Subtask T049 – Create and Validate the Governance Attestation

**Purpose**

Create the sole owned receipt with deterministic digests, dispositions, traceability, and
commands that independently attest the synchronized baseline.

**Steps**

1. Compute SHA-256 over each artifact's exact synchronized-baseline bytes as a bare 64-character
   lowercase hexadecimal value matching `^[0-9a-f]{64}$`.
2. Set each status by comparing synchronized-baseline bytes with producer-baseline bytes:
   `changed` or `no_change`, with a nonempty evidence-based rationale.
3. Require the charter entry status to be `no_change`.
4. Create `docs/governance/p0-governed-doc-sync.json` as deterministic UTF-8 JSON ending in LF.
5. Validate it against `contracts/governed-doc-sync-v1.schema.json` and reject extra fields.
6. Recompute every digest and serialize twice with byte-identical output.

#### Exact Receipt Contract

The top-level object contains only:

- `schema`: exactly `invoice-manager.governed-doc-sync/v1`;
- `producer_baseline_commit`: the pre-reconciliation baseline;
- `synchronized_baseline_commit`: the verified post-sync baseline, or the producer baseline
  when reconciliation required no changes;
- `required_artifacts`: the exact ordered 18-path schema constant;
- `checked_artifacts`: exactly 18 entries in the same order;
- `example_mappings`: exactly eight schema-defined mappings in fixed order;
- `architecture` and `glossary`: exact `not_applicable` dispositions; and
- `commands`: exact `resolver`, `sync_safe_commit`, `drift`, and
  `receipt_safe_commit` constants.

Each `checked_artifacts` entry contains only `path`, `sha256`, `status`, and `rationale`.
Each `example_mappings` entry contains only `path`, `requirement_refs`, and
`acceptance_refs`. The fixed mapping paths, in order, are:

1. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/api-v1.openapi.yaml`
2. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/common-v1.schema.json`
3. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/contract-manifest-v1.schema.json`
4. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-catalog-v1.schema.json`
5. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-envelope-v1.schema.json`
6. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/migration-manifest-v1.schema.json`
7. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/module-contribution-v1.schema.json`
8. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/p0-contract-manifest.json`

Architecture and glossary objects contain only `status` and `rationale`, with status exactly
`not_applicable` and a nonempty rationale. Timestamps, absolute paths, usernames, host data,
and nondeterministic output are forbidden.

Store exact `commands.drift`:

```bash
test -n "$accepted_wp11_receipt_commit" && test "$accepted_wp11_receipt_commit" = "$(git log -1 --format=%H -- docs/governance/p0-governed-doc-sync.json)" && git diff --exit-code "$accepted_wp11_receipt_commit" -- .kittify/charter/charter.md kitty-specs/p0-contract-spine-01KXYY0J/contracts/README.md kitty-specs/p0-contract-spine-01KXYY0J/contracts/api-v1.openapi.yaml kitty-specs/p0-contract-spine-01KXYY0J/contracts/common-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/contract-manifest-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-catalog-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-envelope-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/governed-doc-sync-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/migration-manifest-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/module-contribution-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/p0-contract-manifest.json kitty-specs/p0-contract-spine-01KXYY0J/data-model.md kitty-specs/p0-contract-spine-01KXYY0J/plan.md kitty-specs/p0-contract-spine-01KXYY0J/quickstart.md kitty-specs/p0-contract-spine-01KXYY0J/research.md kitty-specs/p0-contract-spine-01KXYY0J/research/evidence-log.csv kitty-specs/p0-contract-spine-01KXYY0J/research/source-register.csv kitty-specs/p0-contract-spine-01KXYY0J/spec.md docs/governance/p0-governed-doc-sync.json
```

**Validation**

- The receipt matches the schema's exact fields, fixed arrays, dispositions, and four commands.
- Every digest and status recomputes from the two attested baselines.
- The receipt alone is modified in the WP11 working diff.

### Subtask T050 – Receipt-Only Safe Commit and Drift Proof

**Purpose**

Commit only the attestation receipt, prove its parent is the synchronized baseline, and establish
the immutable drift check handed to WP12.

**Steps**

1. Recheck branch, clean baseline, receipt schema validation, and the one-path allowed diff.
2. Run exact `commands.receipt_safe_commit` once.
3. Locate the receipt commit, require one full lowercase 40-hex hash, and require its sole parent
   to equal `synchronized_baseline_commit`.
4. Require the commit subject to equal `docs: attest governed P0 artifacts` and its exact diff to
   contain only `docs/governance/p0-governed-doc-sync.json`.
5. Run exact `commands.drift` and require exit zero.
6. Return that full hash as the sole Spec Kitty review-handoff candidate. Once WP11 review accepts
   it, the hash is the accepted handoff commit WP12 must consume without rediscovery.

Run exactly:

```bash
spec-kitty safe-commit docs/governance/p0-governed-doc-sync.json --message "docs: attest governed P0 artifacts" --to-branch feat/p0-contract-spine
```

Do not substitute a directory, wildcard, alternate message, alternate branch, `git add`, or
ordinary `git commit`.

## Validation

- The resolver returns exactly 18 tracked, regular, non-symlink read-only paths.
- The synchronized baseline decision follows the required no-sync or single exact external-sync
  commit branch.
- Receipt fields, arrays, digests, statuses, mappings, dispositions, and commands validate.
- The WP11 diff and receipt commit contain only `docs/governance/p0-governed-doc-sync.json`.
- Exact drift exits zero after the receipt commit.
- `git diff --check` and `git status --short` expose no unauthorized mutation.

## Definition of Done

- [ ] T048 captured the producer baseline and reconciled all 18 read-only artifacts.
- [ ] Any required mission sync was paused, externally authorized, committed, and reverified.
- [ ] The synchronized baseline equals the producer baseline when no sync was required.
- [ ] T049 emitted the schema-exact receipt at the sole owned path.
- [ ] All 18 digests/statuses and eight mappings validate from the attested baselines.
- [ ] Architecture and glossary use exact `not_applicable` dispositions.
- [ ] All four command values equal the schema constants byte-for-byte.
- [ ] T050 committed only the receipt and proved its exact parent, diff, message, and zero drift.
- [ ] The full lowercase receipt commit was returned as the sole review-handoff candidate.
- [ ] WP12 received the accepted handoff commit without Git/receipt rediscovery; WP11 made no
      mission acceptance claim.

## Risks & Mitigations

- **WP11 edits governed mission data illegally**: every required artifact is explicitly read-only.
- **A needed sync is hidden**: pause and route exact edits plus sync command to the orchestrator.
- **Baseline ambiguity corrupts status**: record both commits and define the no-sync equality case.
- **Receipt scope expands**: own, create, stage, and commit exactly one `docs/governance/` path.
- **Drift omits the receipt**: use the exact self-resolving schema command.
- **Attestation claims acceptance**: reserve mission closure and acceptance for WP12.

## Reviewer Guidance

- Start with profile, dependencies, one-path ownership, and clean producer baseline.
- Confirm WP11 never writes or commits a `kitty-specs/` or charter path.
- Verify external synchronization evidence whenever the two baseline commits differ.
- Recompute all 18 digests and compare status against producer-to-synchronized bytes.
- Audit the eight mappings, synthetic data, and both `not_applicable` dispositions.
- Compare all four stored commands byte-for-byte with the formal schema.
- Inspect the receipt commit parent, exact one-file list, message, and drift exit.
- Confirm the full lowercase receipt commit is the sole review-handoff candidate and WP12 is
  instructed to consume only its accepted value, never a rediscovered latest-path commit.
- Confirm WP11 hands evidence to WP12 without making a final P0 acceptance claim.

## Activity Log

> Append chronological UTC entries with both baselines, resolver result, reconciliation decisions,
> external sync routing/result if any, receipt validation, exact commit/drift results, reviewer
> remediation, and WP12 handoff.

No implementation entries yet.
- 2026-07-21T17:56:38Z – codex-wp11-curator – shell_pid=1807838 – Started implementation via action command
- 2026-07-21T18:21:01Z – codex-wp11-curator – shell_pid=1807838 – WP11 implementation complete: producer=263b8a25190775f54b280788da0135a7862d2b4e; synchronized=03818d8573ce50443a863d6ed9fdcc5b0cd1b921; exact resolver=18 tracked regular non-symlinks; governed sync changed exactly 7 paths; receipt schema and deterministic serialization passed with locked Ajv 8.20.0 Draft 2020-12; receipt=83820584b5f22e4be061e53d16d839856edfef92; exact parent, subject, receipt-only diff, 18 digests/statuses, 8 mappings, dispositions, command constants, synthetic safety, and drift exit 0 verified. WP12 must consume only the accepted full receipt commit from review handoff.
- 2026-07-21T18:21:04Z – codex-wp11-curator – shell_pid=1807838 – Ready for review: receipt 83820584b5f22e4be061e53d16d839856edfef92; producer 263b8a25190775f54b280788da0135a7862d2b4e; synchronized 03818d8573ce50443a863d6ed9fdcc5b0cd1b921; schema, topology, exact one-file diff, digests, mappings, commands, synthetic safety, and drift verified.
- 2026-07-21T18:22:46Z – codex-wp11-reviewer – shell_pid=1807838 – Started review via action command
- 2026-07-21T18:43:15Z – user – shell_pid=1807838 – Review passed: immutable receipt 83820584b5f22e4be061e53d16d839856edfef92 independently verified against producer 263b8a25190775f54b280788da0135a7862d2b4e and sync 03818d8573ce50443a863d6ed9fdcc5b0cd1b921; exact topology, 7-path sync, receipt-only diff, Draft 2020-12 schema, 18 digests/statuses/rationales, 8 mappings, dispositions, command constants, deterministic JSON/LF, synthetic safety, and explicitly bound drift all pass. Anti-patterns: dead code N/A; synthetic fixture N/A; silent empty return N/A; FR coverage PASS; frozen surface PASS; locked decision PASS; shared ownership PASS; production fragility N/A.
- 2026-07-21T20:27:59Z – codex-wp11-reviewer – shell_pid=1807838 – Moved to planned
- 2026-07-21T22:28:00Z – codex – shell_pid=1807838 – Started implementation via action command
- 2026-07-21T22:45:53Z – codex – shell_pid=1807838 – Ready for review: immutable receipt 97b4094de279a0b568760f2e9a202f98dc64021d; no-sync baseline 65ca5ac70870b984a5aa527ca061542c7021a9c5; exact 18-artifact schema, digest, status, mapping, command, synthetic-safety, one-file topology, and drift checks pass; ruff diff-scoped check has no changed Python files, exit 0
- 2026-07-21T22:47:13Z – reviewer-renata – shell_pid=1807838 – Started review via action command

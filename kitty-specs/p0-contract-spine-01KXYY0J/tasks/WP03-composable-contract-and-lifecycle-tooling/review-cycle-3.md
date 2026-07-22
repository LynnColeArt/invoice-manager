---
affected_files:
  - tools/contracts/src/generate.ts
  - tools/contracts/src/migrations.ts
  - tools/contracts/src/modules.ts
  - tools/contracts/src/paths.ts
  - tools/contracts/src/pinned-conformance.ts
  - tools/contracts/src/real-conformance.ts
  - tools/contracts/src/registry.ts
  - tools/contracts/tests/conformance-generation.test.ts
  - tools/contracts/tests/path-security.test.ts
blocking_findings: 0
cycle_number: 3
implementation_commit: d686a6bd5397739df79ebbe68f1626d1c13e8d1e
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-20T22:05:52Z'
reviewed_lane_tip: 2072a91293a4891ce00ce18c15794d648a372ece
reviewer_agent: 'codex:gpt-5:reviewer-renata:reviewer'
verdict: approved
wp_id: WP03
---

# WP03 Review Cycle 3

Verdict: **APPROVE**

Implementation commit: `d686a6bd5397739df79ebbe68f1626d1c13e8d1e`.

Cycle 3 closes both cycle-two findings without regressing the previously corrected
contract, lifecycle, event, path, generation, or publication behavior.

## Finding closure

### Exact pinned P1-P4 evidence is honest and artifact-derived

- `real-conformance.ts` and its fabricated `/conformance/pN` routes, modules, components,
  and event catalogs are deleted. No production or test call site remains.
- Production preflight calls `inspectPinnedConformance` and returns only exact material read
  from each immutable commit: the full manifest, manifest byte hash, content digest,
  dependency/input edges, output schema blob/hash/stable ID/reference graph, declared fixture
  edges, and migration strategy/root availability.
- Independent inspection matched the four accepted commits and hashes. It resolved 52 schema
  references across the four exact output documents, recorded all eight Draft fixture edges
  as absent with pending evidence, recorded the three owner-scoped migration roots as absent,
  and represented P2's migration mode as `none`.
- The returned material has no `routes`, `modules`, or `catalogs` fields and contains none of
  the removed fabricated names. The general module/route/event collision tests remain scoped
  to contract mechanics; they are no longer mislabeled as real downstream P1-P4 evidence.
- Exact-material mutation cases exercise every pinned owner and use the production inspector
  for dependency/input mismatch, missing output, invalid fixture edge, and migration strategy
  rejection, followed by a clean four-owner rerun. Exact schema documents additionally cover
  duplicate stable IDs and unresolved references with actionable pointers. Existing real-Draft
  lifecycle/file/digest/fixture/transition and migration-script/descriptor cases remain green.

### File-kind and snapshot traversal failures are stable and fail loud

- The centralized repository resolver distinguishes files from directories. A directory used
  as a declared fragment now fails as `path_not_file` at `/api_fragments/0` instead of leaking
  raw `EISDIR`.
- Repository file reads, module/migration/registry directory traversal, and metadata errors are
  translated to stable `ContractError` codes and caller pointers.
- `snapshotTree` suppresses only `ENOENT` at a root explicitly marked optional. Required-root,
  regular-file-as-root, unreadable nested directory/file, symlink, and special-entry failures
  fail with stable `generation_snapshot_*` diagnostics.
- The focused snapshot-failure test proves the failure occurs before generation changes the
  prior TypeScript tree or route inventory. The existing five-point paired-publication matrix
  still restores both outputs byte-for-byte.

## Deletion-test evidence

The reviewer temporarily removed each focused production guard, ran its named test, and
restored the source exactly:

- deleting the regular-file kind check changed the result to `path_read_failed`, causing the
  `path_not_file` test to fail;
- restoring the old silent snapshot catch caused `checkContracts` to resolve, causing the
  fail-loud traversal test to fail; and
- deleting the pinned migration-root guard allowed the mutated P1 material to resolve,
  causing the exact-edge mutation test to fail.

After restoration, all three focused tests passed and `git diff d686a6b` was empty for the
temporarily touched source files.

## Independent verification

- Toolchain: Node.js `24.18.0`, npm `11.16.0`, Zig `0.16.0`.
- Offline `npm ci`: pass; install audit reports zero vulnerabilities.
- Strict TypeScript source-and-test compile: pass.
- Vitest: 6 files, 42 tests, all pass.
- Offline `npm audit --audit-level=low`: zero vulnerabilities.
- `npm run verify:substrate`: pass.
- Literal `npm run contracts:generate` twice: pass with identical diagnostics and hashes:
  - inventory `44bf91cb0b165fb58288e3d87887b6dd95d8c9a1d416aa7426c7533878a14d44`;
  - `index.ts` `6236c77ece5a8ce83669bcf55ddcd2077ccb3ca7a410b6d61c599747b16591f0`;
  - `types.gen.ts` `8099d9a6c86802fa17e56c201a8c77bb73df14e60da67668069d6a96467a6720`.
- `npm run contracts:check`: pass.
- Independent P2 exact-commit recomputation matched manifest SHA-256
  `24bf9f15fad1d598fae394e5ec40e7a50e6f166e7bd1202e3c51c4576c89bbc7`
  and RFC 8785 content digest
  `c12f5c79c21689f146c705cef5b454bca684e5e86e0ac7a326df8dc7db1f9a70`.
- Independent path/snapshot reproduction returned:
  - `path_not_file:/api_fragments/0` for directory-as-file;
  - `generation_snapshot_read_failed:/blocked` for unreadable traversal;
  - `generation_snapshot_entry_invalid:/link` for a snapshot symlink;
  - `generation_snapshot_read_failed:` for a required missing root; and
  - an empty map only for the explicitly optional missing root.
- `git diff --check` passes for both the cycle-three correction and the full lane diff.
- The cycle-three diff changes exactly nine WP03-owned source/test paths. WP01 manifests,
  lock, package metadata, and WP02 common contracts are untouched.
- Generated outputs remain ignored and absent from `git ls-files`.
- All seven WP01 substrate hashes are unchanged before and after review.
- The requested charter `section:code-review-checklist` selector was unavailable; the full
  generated capsule and its embedded checklist governed the review.

## Anti-pattern checklist

1. Dead code: **PASS** - `pinned-conformance.ts` is called by production preflight; all new
   exported functions have live production callers.
2. Synthetic-fixture test: **PASS** - exact conformance assertions invoke production preflight,
   immutable Git reads, the registry, lifecycle validator, and pinned inspector. Fabricated
   downstream contributions are removed.
3. Silent empty return: **PASS** - snapshot absence is limited to documented optional-root
   `ENOENT`; pinned artifact absence is explicit material for pending Draft edges.
4. FR coverage: **PASS** - existing and correction tests collectively cover every referenced
   contract/lifecycle/composition/generation behavior.
5. Frozen surface: **PASS** - cycle 3 modifies only WP03-owned source and tests.
6. Locked decision: **PASS** - no moving references, network resolution, tracked aggregates,
   alternate destinations, or fabricated real-owner claims remain.
7. Shared-file ownership: **PASS** - no shared implementation file is crossed in cycle 3.
8. Production fragility: **PASS** - new failures are deliberate fail-loud boundaries with stable
   codes and pointers, and the prior generated pair is preserved.

## Subtask disposition

- T008: **PASS** - lifecycle and concrete evidence gates retain stable path/file diagnostics.
- T009: **PASS** - deterministic module discovery and access policy remain green.
- T010: **PASS** - live envelope/discriminator/payload/JSONL validation remains green.
- T011: **PASS** - deterministic composition and collision preflight remain green.
- T012: **PASS** - stable-ID generation, exact ignored outputs, paired publication, and fail-loud
  snapshot behavior pass.
- T013: **PASS** - exact P1-P4 pins and all actually available artifact/edge evidence are
  inspected and mutated without toy downstream claims.
- T014: **PASS** - the focused command runs twice deterministically, preserves prior outputs on
  failure, and leaves tracked files unchanged.

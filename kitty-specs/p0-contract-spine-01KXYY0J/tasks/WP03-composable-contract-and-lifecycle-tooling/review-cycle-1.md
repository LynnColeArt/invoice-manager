---
affected_files:
  - contracts/api/v1/base.openapi.yaml
  - contracts/conformance/p0-p4-inputs.json
  - contracts/events/v1/catalog.schema.json
  - contracts/events/v1/envelope.schema.json
  - contracts/fixtures/p0/v1/invalid/lifecycle-frozen-pending-digest.json
  - contracts/fixtures/p0/v1/invalid/module-duplicate-mount.json
  - contracts/fixtures/p0/v1/valid/lifecycle-draft.json
  - contracts/fixtures/p0/v1/valid/module-pair.json
  - contracts/manifests/drafts/p0.json
  - contracts/manifests/v1/schema.json
  - contracts/migrations/v1/manifest.schema.json
  - contracts/modules/p0/module.json
  - contracts/modules/v1/schema.json
  - tools/contracts/.gitignore
  - tools/contracts/src/conformance.ts
  - tools/contracts/src/errors.ts
  - tools/contracts/src/events.ts
  - tools/contracts/src/fixtures.ts
  - tools/contracts/src/generate.ts
  - tools/contracts/src/json.ts
  - tools/contracts/src/lifecycle.ts
  - tools/contracts/src/main.ts
  - tools/contracts/src/migrations.ts
  - tools/contracts/src/modules.ts
  - tools/contracts/src/paths.ts
  - tools/contracts/src/registry.ts
  - tools/contracts/tests/conformance-generation.test.ts
  - tools/contracts/tests/events-registry.test.ts
  - tools/contracts/tests/lifecycle.test.ts
  - tools/contracts/tests/migrations.test.ts
  - tools/contracts/tests/modules.test.ts
blocking_findings: 5
cycle_number: 1
implementation_commit: 5eda01c9b2a5ba4a93240ec67ad3389bdba1255a
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-20T20:41:31Z'
reviewed_lane_tip: 202425446a8665dd9f31b8c2a2b9ba04a0c7ca9d
reviewer_agent: 'codex:gpt-5:reviewer-renata:reviewer'
verdict: rejected
wp_id: WP03
---

# WP03 Review Cycle 1

Verdict: **REJECT**

Implementation commit: `5eda01c9b2a5ba4a93240ec67ad3389bdba1255a`.

## Blocking findings

### 1. Baseline refresh does not perform the revalidation it records, and the required real-owner mutation matrix is absent

`buildBaselineRefreshCandidate` calls only `verifyConformanceLock`, then emits
`validation: "all-pins-and-fixtures-revalidated"`. It does not rerun composed
module/OpenAPI/event/migration validation or `validateCanonicalFixtures` with
the candidate pins. The CLI therefore creates a candidate that claims broader
validation than it performed.

The committed tests independently verify the four exact manifest and content
hashes, but the mutation evidence changes only a commit/hash pin and composes
only the P0 module. The full T013 matrix over real P1–P4 shapes, dependency and
input edges, schema IDs, fixtures, lifecycle/file/digest failures, access, and
all collision classes is not present. Existing collision tests use locally
constructed P7/P8 examples and cannot establish the required concurrent
real-input case or post-failure clean rerun.

Required correction:

- make refresh validation run the same affected composition, reference,
  migration, lifecycle, and canonical-fixture gates before writing the
  candidate or claiming revalidation;
- exercise the exact pinned P1–P4 material together, not just their top-level
  manifest hashes; and
- add the required data-driven real-input mutation table with stable code and
  pointer assertions plus a clean successful rerun after each failure.

### 2. Declared contract paths can escape through symlinks, and structured inputs are not strict UTF-8

The repository path policy is enforced for lifecycle evidence through
`resolveRepositoryFile`, but module fragments/catalogs and baseline-refresh
inputs/candidates use direct joined `readFile`/write paths. `readStructuredFile`
therefore follows symlinks without checking the resolved target remains below
the repository root.

Independent reproduction created
`contracts/api/v1/fragments/p7/api.openapi.json` as a symlink to an external
temporary file. `composeModules` accepted it and returned the external route:

```json
{"accepted_symlink_escape":true,"routes":[{"path":"/api/v1/escaped","method":"get","operation_id":"EscapedRead","owner":"p7","mount_key":"synthetic_p7","access":"protected"}]}
```

Likewise, `discoverStableIdRegistry` reads with Node's replacement-decoding
`"utf8"` mode. An otherwise valid schema containing byte `0xff` inside its
description was accepted and registered as `"synthetic �"`:

```json
{"accepted_non_utf8":true,"decoded_description":"synthetic �"}
```

Required correction: centralize all declared repository reads and writes on a
root-contained realpath/symlink policy, validate exact UTF-8 bytes before JSON
or YAML parsing, and add escape-symlink plus invalid-UTF-8 tests for every
relevant discovery/CLI boundary.

### 3. Paired output publication can delete the previous TypeScript tree on a backup failure

`publishPair` suppresses every error while renaming prior outputs to backup
locations. It treats permission, collision, and filesystem errors as if the
prior path were simply absent. Its recovery then deletes the final paths and
restores only outputs whose backup flag was set.

Independent reproduction pre-created a stale nonempty backup directory for
the deterministic publish token. The TypeScript backup rename failed, the new
directory rename then failed, and recovery deleted the prior TypeScript output
without restoring it:

```json
{"generation_failed":true,"types_survived":false,"inventory_survived":true}
```

The existing rollback test mutates a pin, so it fails in preflight before
publication and cannot detect this defect.

Required correction: handle only a true missing prior output as nonfatal,
preserve both prior outputs on every other backup/publish failure, clean stale
publish state safely, and add fault-injection tests for failures before,
between, and after the two replacements. A failure must leave the exact prior
pair or no pair, never a mixed or partial pair.

### 4. Draft manifests bypass verification of concrete evidence

`assertEvidence` immediately returns for every Draft, and
`validateLifecycleManifest` returns before file/content verification whenever
the state is Draft. Pending evidence is correctly permitted in Draft, but a
Draft that supplies concrete evidence must still have that evidence checked.

Independent reproduction supplied a Draft with a concrete but incorrect
content digest, concrete incorrect file digests, and three nonexistent paths.
It was accepted:

```json
{"accepted_draft_with_concrete_wrong_digest_and_missing_files":true}
```

This contradicts the requirements to verify every concrete output/fixture path
and every declared concrete digest. Required correction: distinguish pending
Draft evidence from concrete Draft evidence; verify every concrete digest and
path, and recompute a concrete content identity even before Frozen. Add both
positive and negative Draft-concrete cases.

### 5. The event runtime validator is not reachable from production or the focused command

`validateCatalogSet`, `validateDomainEvent`, and `validateEventJsonl` are
imported only by `events-registry.test.ts`. No production module calls
`events.ts`, and `contracts:check` has no event fixture/input path that executes
envelope validation, exact discriminator selection, payload validation, or
JSONL handling. The focused command can therefore pass even if the T010 runtime
surface is absent from the real validation flow.

Required correction: wire canonical event fixtures/batches through the
focused contract check or expose the validator through an explicitly consumed
production contract-tool surface, then prove the full two-stage and JSONL
paths through that live entry point. Retain direct unit tests, but do not leave
the implemented validator test-only dead code.

## Passing evidence retained

- Commit `5eda01c` changes exactly 31 files, all within WP03 ownership; WP01
  manifests/lock and WP02 common contracts are unchanged. `git diff --check`
  passes.
- Exact Node.js `24.18.0` and npm `11.16.0`: offline `npm ci` passes; strict
  source-and-test TypeScript compile passes with Node types; all 5 Vitest files
  and 26 tests pass.
- `npm audit --offline --audit-level=low`: zero vulnerabilities.
- `npm run verify:substrate`: passes; all seven WP01 hashes remain unchanged.
- `npm run contracts:generate` twice produces byte-identical inventory,
  `index.ts`, and `types.gen.ts`; the restored hashes are stable. Generated
  outputs are ignored and untracked.
- `npm run contracts:check`: passes and performs its two internal generation
  calls, reporting `modules=1 routes=1 conformance=4`.
- The generated route inventory contains only effective
  `/api/v1/health`, `get`, `P0Health`, owner `p0`, mount `foundation`, public;
  the composed OpenAPI retains server-relative `/health` under `/api/v1`.
- Generated Money minor units remain the canonical string alias, not
  TypeScript `number`; generator input contains only embedded local refs.
- Independent exact-commit recomputation matches all four committed P1–P4
  manifest SHA-256 and RFC 8785 content digests.
- The implemented lifecycle transition table, explicit code-unit comparators,
  stable schema registry, event two-stage unit behavior, and migration
  descriptor/script/dependency/cycle unit behavior are otherwise coherent.
- Committed fixtures and test business values are synthetic only.

## Subtask disposition

- T008: **FAIL** — transition/content foundations pass, but concrete Draft
  evidence bypasses repository and digest verification.
- T009: **FAIL** — additive discovery and policy logic pass, but owner path
  reads accept escaping symlinks.
- T010: **FAIL** — unit behavior passes, but the event validator is test-only
  and absent from the focused production validation flow.
- T011: **PASS with dependency on fixes** — deterministic ordering and current
  collision preflight work, but the required full real mutation evidence is
  incomplete under T013.
- T012: **FAIL** — local embedding and deterministic generation pass, but
  strict input encoding/path safety and paired publication rollback do not.
- T013: **FAIL** — exact pins recompute, but refresh truthfulness and the full
  real-owner mutation/concurrent-composition matrix are incomplete.
- T014: **FAIL** — the focused command passes its implemented checks but omits
  the live event and candidate-refresh validation required above.

## Anti-pattern checklist

1. Dead code: **FAIL** — `events.ts` is called only by tests, not by the
   production/focused contract tool.
2. Synthetic-fixture test: **PASS** for existing unit paths — tests invoke the
   real production validators, but toy fixtures cannot substitute for the
   separately required P1–P4 mutation evidence.
3. Silent empty return: **FAIL** — `publishPair` uses empty catches for all
   backup rename failures, silently conflating missing paths with destructive
   filesystem failures.
4. FR coverage: **FAIL** — FR-004/FR-006/FR-007/FR-008 and related NFR safety
   surfaces lack the live refresh/event/rollback/path evidence described above.
5. Frozen surface: **PASS** — implementation scope is confined to the declared
   WP03 patterns; WP01 and WP02 immutable files are untouched.
6. Locked decision: **FAIL** — escaping-symlink acceptance and refresh claims
   without the required revalidation contradict explicit MUST/MUST NOT rules.
7. Shared-file ownership: **PASS** — lane-c is exclusive and no out-of-map
   implementation file changed.
8. Production fragility: **PASS** — fail-loud `ContractError` use is deliberate;
   the destructive risk is the silent backup handling captured in item 3.

# Mission Review Report: p0-contract-spine-01KXYY0J

**Reviewer**: Codex, with independent swarm reviewers  
**Date**: 2026-07-22  
**Mission**: `p0-contract-spine-01KXYY0J` — P0 Contract Spine  
**Baseline commit**: `25bb794142c1e30c8e9f97a61ad0cc82a38a9ed9`  
**Merged mission target**: `44115f7e4cfbb1298a96057e802a205394c1f7f5`  
**HEAD at final review**: `2594092bc51b9195c3e200fd5af51eaa86d1fa52`  
**Implementation candidate**: `57b3724f63b3600d1bd84fbb744561ace19b9e6d`  
**WPs reviewed**: WP01–WP12

The public implementation candidate is strong on reproducibility, durability,
performance, licensing, and security. The mission review nevertheless fails:
WP12 claimed real P1–P4 contract composition even though the exact pinned
commits contain no downstream route fragments, event catalogs, or module
contributions. Generic synthetic composition works, but it does not satisfy the
explicit non-toy acceptance contract in WP12 T056.

## Gate Results

### Gate 1 — Spec Kitty contract tests

- Repository: `/home/lynn/projects/spec-kitty` at
  `1cb51fb32515771215f5fe7bc676ecc1b22da57a`
- Command: `SPEC_KITTY_ENABLE_SAAS_SYNC=1 uv run --frozen python -m pytest tests/contract/ -v -p no:cacheprovider`
- Exit code: `0`
- Result: **PASS**
- Notes: 292 passed, 3 skipped, 0 failed in 64.81 seconds. The repository was
  tracked-clean before and after the run.

### Gate 2 — Spec Kitty architectural tests

- Canonical command: `PYTHONDONTWRITEBYTECODE=1 uv run --frozen --all-extras python -m pytest tests/architectural/ -v -p no:cacheprovider`
- Exit code: `0`
- Result: **PASS**
- Notes: 846 passed, 4 skipped, 0 failed in 743.49 seconds. The first
  diagnostic run used an incompletely provisioned existing venv and found 843
  passed, 4 skipped, and 3 failed. One failure came from ignored sourceless
  `__pycache__` residue under retired charter import paths; two nested
  isolation probes correctly rejected a venv without `pytest-xdist`. Both
  retired paths contained no tracked files. After removing only that ignored
  residue and using the repository's canonical `--all-extras` provisioning,
  the focused legacy-path test passed, both xdist isolation tests passed, and
  the full architectural suite passed. Spec Kitty remained tracked-clean at
  unchanged HEAD `1cb51fb32515771215f5fe7bc676ecc1b22da57a`.

### Gate 3 — Cross-repository E2E

- Repository: `/home/lynn/projects/spec-kitty-end-to-end-testing`
- Initial upstream: `e278ad76552b954f9c7f4ea1e7a364978678b3ca`
- Repaired local commit: `95181ccf26253fbaf06be50d26301346c105ed1d`
- Command: `SPEC_KITTY_ENABLE_SAAS_SYNC=1 SPEC_KITTY_REPO=/home/lynn/projects/spec-kitty uv run pytest scenarios/ -v --color=no`
- Exit code: `0` after repair
- Result: **PASS WITH ENVIRONMENT NOTE**
- Notes: The upstream run failed before its drift assertion because the
  harness-created venv omitted the Python `build` package. The narrow repair
  installs `build>=1.2,<2.0` and installs the deliberate fake drift package last
  with `--no-deps`. The focused scenario passed; the full suite finished with
  5 passed and 1 expected SaaS xfail in 36.23 seconds. The SaaS scenario was
  not executed because neither `SPEC_KITTY_SAAS_ENDPOINT` nor
  `SK_E2E_SAAS_URL` was configured. GitHub publication of the harness repair
  is blocked by this account's read-only permission; commit `95181ccf` is clean
  and ready for a maintainer to cherry-pick.

### Gate 4 — Issue matrix

- File: `kitty-specs/p0-contract-spine-01KXYY0J/issue-matrix.md`
- Rows: 1 (`no-linked-issues`)
- Empty, `unknown`, or disallowed verdicts: 0
- `deferred-with-followup` rows missing a follow-up: 0
- Result: **PASS after governance repair**
- Notes: The merged target did not contain the required artifact, so the first
  audit correctly hard-failed Gate 4. Commit
  `2594092bc51b9195c3e200fd5af51eaa86d1fa52` adds a truthful matrix: `spec.md`
  references no external GitHub issues, and the single row has terminal verdict
  `verified-already-fixed`.

## FR Coverage Matrix

| FR | Brief contract | WP owner(s) | Principal evidence | Adequacy | Finding |
| --- | --- | --- | --- | --- | --- |
| FR-001 | Documented clean bootstrap | WP01, WP09, WP10, WP12 | `README.md`; bootstrap job `88803305129` | ADEQUATE | — |
| FR-002 | Runnable Zig/Next boundary | WP08, WP10, WP12 | `services/api/tests/http/`; `apps/web/e2e/`; jobs `88803305095`, `88803305126` | ADEQUATE | — |
| FR-003 | Canonical shared values | WP02, WP05 | `tools/contracts/tests/common-values.test.ts`; `services/api/tests/shared/` | ADEQUATE | — |
| FR-004 | Structured response contract | WP03, WP08, WP10 | contract composition and real HTTP/proxy suites | ADEQUATE | — |
| FR-005 | Additive module contracts | WP03 | `tools/contracts/tests/modules.test.ts`; `conformance-generation.test.ts` | PARTIAL | DRIFT-1 |
| FR-006 | Collision detection | WP03, WP08 | contract collision matrix, migration-negative, route-inventory tests | ADEQUATE | — |
| FR-007 | Event and fixture envelope | WP03 | event catalog, JSONL, discriminator, and payload fixture tests | ADEQUATE | — |
| FR-008 | Contract lifecycle manifest | WP03, WP12 | lifecycle tests; Verified manifest SHA `def2cc7f…` | ADEQUATE | — |
| FR-009 | Parallel-safe migrations | WP07 | `services/api/tests/persistence/migrations_integration_test.zig` | ADEQUATE | — |
| FR-010 | Migration integrity | WP07 | migration-negative and applied-history drift tests | ADEQUATE | — |
| FR-011 | Reproducible ShovelerDB | WP04 | exact commit/source verification and public clean build | ADEQUATE | — |
| FR-012 | Serialized storage seam | WP04, WP06 | store and ShovelerDB integration suites | ADEQUATE | — |
| FR-013 | Durable acknowledgement | WP06 | checkpoint, parent-sync, close/reopen, and crash-boundary tests | ADEQUATE | — |
| FR-014 | Durability uncertainty | WP06 | typed uncertainty and persistence-only completion tests | ADEQUATE | — |
| FR-015 | Independent validation gates | WP01, WP03, WP04, WP08, WP10, WP11, WP12 | ten independently runnable public jobs | ADEQUATE | — |
| FR-016 | Program ownership evidence | WP11, WP12 | governed sync receipt and program ledger | PARTIAL | GOV-2 |

## NFR Coverage Matrix

| NFR | Brief contract | Principal evidence | Adequacy | Finding |
| --- | --- | --- | --- | --- |
| NFR-001 | First run under 15 minutes | bootstrap 320.665s internal / 326.706s external | ADEQUATE | — |
| NFR-002 | Byte-deterministic composition | repeated generation plus exact commit/digest pins | ADEQUATE | DRIFT-1 limits downstream non-vacuity |
| NFR-003 | Closed collision rejection | route, operation, schema, event, mount, migration, owner/path cases | ADEQUATE | — |
| NFR-004 | Signed-i64 fidelity | contract, Zig, and TypeScript boundary fixtures | ADEQUATE | — |
| NFR-005 | Twenty durable cycles | injected checkpoint/sync and process-termination boundaries | ADEQUATE | — |
| NFR-006 | Critical branch coverage | owned-source coverage gates at or above 90% plus probes | ADEQUATE | — |
| NFR-007 | Health p99 below one second | exact-100 nearest-rank p99 20.275ms | ADEQUATE | — |
| NFR-008 | Validation under 15 minutes | 326.696s internal / 331.845s external | ADEQUATE | — |
| NFR-009 | No silent destructive fallback | negative contract, storage, migration, and license suites | ADEQUATE | — |
| NFR-010 | Synthetic-only evidence | fixture/privacy scans and redacted public logs | ADEQUATE | — |
| NFR-011 | GPL-3.0-only closure | deterministic license audit; Sharp/libvips obligations recorded | ADEQUATE | — |
| NFR-012 | Reproducible dependency graph | exact npm/tool/action/source/commit pins | ADEQUATE | — |

## Drift Findings

### DRIFT-1 — Real P1–P4 composition was not exercised

**Type**: PUNTED-FR / ACCEPTANCE-EVIDENCE MISMATCH  
**Severity**: HIGH  
**References**: FR-005, SC-002, WP12 T056 steps 8 and 12

WP12 requires composition of real pinned P1–P4 fragments, event catalogs, and
modules with P0 twice, and explicitly says toy-only surrogates cannot satisfy
acceptance. `tools/contracts/tests/conformance-generation.test.ts` instead
asserts that every exact pinned entry has no `routes`, `catalogs`, or `modules`.
All four pinned commits lack `contracts/modules/p1` through `p4`; the accepted
run reports `modules=1 routes=1 conformance=4`, meaning one P0 module and four
metadata/schema inputs. Synthetic P7/P8 tests adequately constrain the generic
mechanism, but they cannot prove the non-toy T056 claim. The acceptance matrix
therefore overstates FR-005/SC-002 evidence.

This is not a demand for P0 runtime plugin loading: the domain language
expressly defers that behavior, and C-007 allows steward-owned shared runtime
integration. The repair is either to supply and pin real downstream
contributions, or to run a formally governed amendment that makes the intended
manifest/schema-plus-synthetic boundary explicit before re-acceptance.

No non-goal invasion or locked-decision violation was found.

## Risk and Governance Findings

### RISK-1 — Production migration timestamps are permanently fixed

**Type**: ERROR-PATH / AUDIT SEMANTICS  
**Severity**: MEDIUM  
**Location**: `services/api/src/main.zig`

Production startup and durability revalidation pass
`2026-07-21T00:00:00.000Z` for every migration. The migration boundary validates
and stores that value as `AppliedMigration.applied_at`, so future rows will be
well-formed but historically false. Tests inject deterministic timestamps and
therefore do not catch misuse by the production composition root. A follow-up
must supply the real UTC clock through a deterministic seam and add a
production-side regression test.

### RISK-2 — First feature integration needs unlisted shared edits

**Type**: CROSS-WP INTEGRATION  
**Severity**: MEDIUM  
**Locations**: `services/api/src/main.zig`,
`services/api/src/http/route_inventory.zig`, `apps/web/src/lib/api/server.ts`

The live service and web proxy intentionally expose only P0 health. That is in
scope for the foundation, but P1/P4 manifests do not list the composition root,
route inventory, or proxy allowlist as steward-owned shared touchpoints. Add
those touchpoints before the first domain route is integrated.

### GOV-1 — Status history contains broken review references

**Severity**: MEDIUM

Commit `1c181a1` deleted 18 review-cycle artifacts. At the merged target, 13
`status.events.jsonl` review references point to absent files across WP01,
WP03, WP04, WP09, WP11, and WP12. The blobs remain recoverable from Git history,
so implementation evidence is not lost, but the materialized audit trail is
incomplete and one surviving review incorrectly claims all prior reviews were
preserved.

### GOV-2 — Program ledger retains pre-acceptance state

**Severity**: LOW

`docs/program-ledger.md` still says WP12 review, P0 acceptance, and Spec Kitty
merge are pending. Public-main integration is genuinely pending because this
review fails, but WP12 review and mission acceptance did complete. Update the
ledger through a new governed sync receipt rather than mutating the accepted
WP11 receipt in place.

## Silent Failure Candidates

No blocking silent-failure path was found. Contract loading, migration
discovery, applied-history validation, storage corruption, checkpoint/sync
failure, proxy destination validation, and licensing all fail closed. The
fixed migration timestamp in RISK-1 is the closest candidate: it silently
records false audit data while remaining structurally valid.

## Security Notes

| Finding | Location | Risk class | Recommendation |
| --- | --- | --- | --- |
| No blocking path traversal or shell injection | contract tooling and build/test launchers | PATH-TRAVERSAL / SHELL-INJECTION | Preserve repository-bound canonical path checks and fixed-binary argument arrays. |
| Loopback-only service bind | `services/api/src/main.zig` | UNBOUND-HTTP | Preserve exact `127.0.0.1` / `::1` validation unless a later authenticated deployment design replaces it. |
| Server-owned, bounded upstream | `apps/web/src/lib/api/server.ts` | UNBOUND-HTTP | Preserve fixed-origin validation, manual redirects, time/body limits, and allowlisted forwarding. |
| No credentials or client data in fixtures/logs | repository evidence surfaces | CREDENTIAL-RACE | Keep NFR-010 scans required as feature fixtures are added. |

No raw storage diagnostics, internal origins, tokens, bank details, client data,
or destructive storage fallback were found in the reviewed paths or evidence.

## Final Verdict

**FAIL**

### Verdict rationale

The shipped foundation mechanics are unusually well tested, and no blocking
security, durability, licensing, performance, or reproducibility defect was
found. Release remains blocked because the acceptance record says real P1–P4
composition passed when the committed test proves those contributions are
absent. This HIGH spec-to-code fidelity failure is independent of the external
hard-gate repairs and must be resolved through real downstream evidence or a
formally reviewed contract amendment before P0 can be described as mission
reviewed or fast-forwarded to public `main`.

### Open items

1. Resolve DRIFT-1 through a doctrine-compliant remediation mission.
2. Replace the hard-coded migration audit timestamp and add a production-clock
   regression test.
3. Add the runtime composition/proxy touchpoints to affected downstream
   manifests before implementation.
4. Restore or reconcile broken review references and publish a new governed
   ledger sync receipt.
5. Have a writer on `Priivacy-ai/spec-kitty-end-to-end-testing` cherry-pick
   local harness commit `95181ccf`.

## Retrospective Reminder

The runtime authored
`kitty-specs/p0-contract-spine-01KXYY0J/retrospective.yaml` at the merge
terminus. After this review, run `spec-kitty retrospect summary` and
`spec-kitty agent retrospect synthesize --mission p0-contract-spine-01KXYY0J`
in dry-run mode. Keep product defects above separate from process-improvement
proposals; do not apply doctrine changes automatically.

The 2026-07-22 closeout run exposed a tooling mismatch: `retrospect summary`
reported all eight discovered missions as `terminus_no_retro` / `missing` even
though this mission's 512-line runtime-authored record exists at the path
above. Dry-run synthesis reported `planned=0 applied=0 conflicts=0 rejected=0`.
No proposal was applied and no duplicate retrospective was fabricated; the
discovery mismatch should be corrected in Spec Kitty separately.

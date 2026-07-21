---
affected_files: []
blocking_findings: 0
cycle_number: 12
implementation_commit: 69458f99517c8e431a5c4fccf1cbcd0fc7de6b64
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T05:32:00Z'
reviewed_lane_tip: 25cf951a24af910dde27402a0b6188fefe85649a
reviewer_agent: 'codex-wp04-pc-review:reviewer-renata'
runner_commit: 40d6661
verdict: approved
wp_id: WP04
---

# WP04 Review Cycle 12

Verdict: **APPROVE — cycle 10/11 are retracted as a false technical premise**

No blocking finding remains. The original exact-PC ownership runner is correct
for Zig 0.16's `__sancov_pcs1` table. Review cycles 10 and 11 incorrectly
treated its PC-table entries as return addresses and applied `pc - 1`. This
approval preserves those rejected artifacts and the additive RED/revert commits
as audit history, but explicitly supersedes their verdict and required changes.

## Independent sanitizer-PC semantics proof

- Zig 0.16's installed `lib/fuzzer.zig` reads `__sancov_pcs1`, requires a
  one-to-one pairing with `__sancov_cntrs`, hashes and persists each PC exactly
  as emitted, and never subtracts one. The coverage runner follows that same
  exact-address contract.
- The live WP06 coverage executable contains a `0xd98`-byte PC section and a
  `0x1b3`-byte counter section: exactly 435 eight-byte PCs paired with 435
  counters. All 435 PC values are exact machine-instruction starts; 129 are
  also exact function-symbol starts.
- Exact GDB source lookup reconciles every table entry to an owned source:
  `store.zig` 249, `durability.zig` 159, `directory_sync.zig` 17, `root.zig`
  9, and `diagnostics.zig` 1. Adapter, standard-library, test-root, probe,
  unknown, and other sources are all zero. The total is 435/435.
- The cycle-10 `pc - 1` map instead yields store 219, durability 122,
  directory-sync 16, root 6, adapter 27, std 28, test root 9, probe 6, and
  unknown 2. Those 72 alleged non-owned sites are created by moving away from
  the emitted PC, not discovered in the table.
- Two disassembly examples make the error conclusive. PC `0x1209b00` is the
  exact entry and first instruction of `store.beginClosing`; its paired inline
  counter increments later in that function at `+0x5a`. `pc - 1` lands in the
  preceding `shovelerdb.Adapter.close`. PC `0x1214fb0` is the exact entry and
  first instruction of `durability.neutralResult`; its counter increments at
  `+0x45`. `pc - 1` lands in a preceding generated enum helper. A return-address
  bias is therefore semantically inapplicable to this inline-counter PC table.
- Running the real artifact reaches the ratio gate with `352/435` and 20/20
  critical probes, then reports `BelowThreshold`. That current WP06 coverage
  result is separate work for WP06; importantly, exact ownership validation
  succeeds before the ratio gate and does not admit an out-of-scope PC.

## False-audit reversion and product drift

- Commits `0c83f9c` and `4b280ef` added tests encoding the false return-address
  premise. They are additively reverted by `9a1df00` and `d873184`.
- `git diff 8d157aa..d873184` is empty. The current lane has no product-file
  difference from `8d157aa`; only governed coordination/status history follows
  it. The runner remains the accepted exact-PC implementation from `40d6661`.
- No runner, build graph, adapter, vendored source, notice, license, or test
  content was changed to obtain this approval. The review did not introduce
  `pc - 1` or an ownership mask that excludes emitted PCs.

## Independent regression, privacy, and provenance evidence

- Zig 0.16 format and base build pass. Adapter tests pass 4/4 in Debug and
  ReleaseSafe; real-ABI integration passes 5/5 in Debug and ReleaseSafe; build
  discovery and coverage-contract adversarial tests pass 17/17.
- The real-ABI error test again proves SQL and database-path sentinels do not
  enter public diagnostics. In an isolated adversarial build with only adapter
  `.fuzz = false` removed, the exact runner fails before ratio with stable
  `coverage-persistence`, `WP06`, expected relative pattern,
  `shovelerdb.zig`, and `OutOfScopeCoverageSite` fields. Its diagnostic contains
  no absolute checkout path, raw address, SQL, value, or source trace.
- Public GitHub `refs/heads/main` resolves exactly
  `021e3b3d9247a181252329d6ba7ec8d2ed943a97`. Recomputed vendored source digest
  is `6bb2b4215aa50a8ffbbff3278aea4f32c4fc0f906da817037c44095cfd19480b`;
  LICENSE and header hashes remain `240a15a1...` and `177535ee...`. Provenance,
  ABI 0.1.0, full GPL-2.0-only license, and third-party notice are unchanged.
- The lane has no nested Git metadata or vendored symlink. Generated Zig and
  Spec Kitty caches were removed before the final status transition.

## Subtask disposition

- T015: **PASS** — exact public pin and deterministic export are intact.
- T016: **PASS** — exact-PC ownership is sound; discovery and stable build gates
  remain green.
- T017: **PASS** — narrow borrow-safe adapter and centralized literal encoding
  remain independently green.
- T018: **PASS** — Debug/ReleaseSafe real-ABI persistence and cleanup tests pass.
- T019: **PASS** — notice, preserved license, and provenance hashes match.

## Anti-pattern checklist

1. Dead code: **PASS** — all public adapter/build surfaces retain production
   consumers; this review adds no code.
2. Synthetic-fixture test: **PASS** — regressions execute the real ABI and the
   live sanitizer artifact; the PC conclusion is backed by section bytes,
   symbols, source maps, and disassembly.
3. Silent empty return: **PASS** — no production change or swallowed failure.
4. FR coverage: **PASS** — FR-011, FR-012, FR-015 and associated pin, ABI,
   ownership, privacy, and reproducibility constraints retain executable proof.
5. Frozen surface: **PASS** — the false tests were additively reverted and the
   resulting product diff is empty.
6. Locked decision: **PASS** — exact instrumentation ownership, compile-time SQL
   fragments, one runtime statement, and stable diagnostics remain intact.
7. Shared-file ownership: **PASS** — no shared product file changed; downstream
   WP06 supplied read-only live-artifact evidence.
8. Production fragility: **PASS** — no production path changed.

## Arbiter/stale-rejection disposition

Cycle 10 and its cycle-11 transition receipt are stale rejected artifacts whose
sole blocker is disproved above. This review is the explicit independent
arbiter evidence required to override them. Approval must reference this file
and state that the override retracts the `pc - 1` premise while preserving the
historical artifacts and commits.

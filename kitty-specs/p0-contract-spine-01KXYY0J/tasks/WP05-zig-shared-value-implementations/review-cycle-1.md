---
affected_files: []
cycle_number: 1
mission_slug: p0-contract-spine-01KXYY0J
reproduction_command:
reviewed_at: '2026-07-21T03:06:13Z'
reviewer_agent: unknown
verdict: rejected
wp_id: WP05
review_artifact_override_at: "2026-07-21T03:43:01Z"
review_artifact_override_actor: "operator"
review_artifact_override_wp_id: "WP05"
review_artifact_override_reason: "Cycle-2 arbiter override: review-cycle-1.md correctly records the fixed pre-correction defect and is superseded by commit 610c72c plus independent cycle-2 evidence. Exact malformed 36-byte input and all 32 noncanonical hyphen offsets now return InvalidSyntax; deletion check reverts to the documented abort; Chicago/Auckland Debug and ReleaseSafe pass 41/41; Debug/ReleaseSafe coverage passes 221/243 and 24/24; fixtures pass 42 valid, 73 invalid, 8 runtime; contracts, format, scope, and anti-pattern gates pass."
---

# WP05 Review Cycle 1 — REJECTED

Reviewed implementation commit: `43c76a3` (`feat(WP05): implement canonical shared values`)

## Blocking finding

### B1 — malformed canonical-length EntityId input can abort instead of returning `InvalidSyntax`

`services/api/src/shared/entity_id.zig:31-39` skips every hyphen encountered while decoding, rather than rejecting hyphens outside the four canonical offsets. If an unexpected hyphen occupies the high nibble of the final byte, the skip advances `text_index` and the subsequent low-nibble read indexes past the 36-byte input.

Fresh Zig 0.16.0 Debug reproducer through the public `shared.EntityId.parse` boundary:

```zig
try std.testing.expectError(
    shared.EntityIdParseError.InvalidSyntax,
    shared.EntityId.parse("01890f3e-2c4a-7d5e-8abc-0123456789-b"),
);
```

Observed result:

```text
panic: index out of bounds: index 36, len 36
services/api/src/shared/entity_id.zig:37:39
test command terminated with signal ABRT
```

This violates T020 steps 3, 5, and 8 (fixed hyphen positions, rejection of malformed hyphens, and stable typed syntax errors), FR-003's canonical representation, and the Definition of Done requirement that EntityId accept only canonical lowercase hyphenated UUIDv7 values. It also fails the review deletion/error-reachability standard because the existing syntax tests do not exercise this reachable malformed-hyphen path.

Required remediation:

1. Reject every hyphen outside offsets 8, 13, 18, and 23 before or during decoding, with bounds-safe logic that returns `EntityIdParseError.InvalidSyntax` for every canonical-length malformed-hyphen input.
2. Add a permanent regression through the public shared boundary using the exact high-nibble unexpected-hyphen shape above (and preferably enumerate every noncanonical hyphen position). Confirm it fails against `43c76a3` and passes only with the fix.
3. Keep the existing `entity_id_syntax` production coverage probe on the real rejection branch, then rerun `zig fmt --check`, both Debug timezone runs, ReleaseSafe, and Debug/ReleaseSafe `coverage-shared`; the owned-PC ratio must remain at least 90% and all 24 critical branches must remain covered.

## Fresh passing evidence before the blocker

- `zig fmt --check src/shared tests/shared`: passed.
- `TZ=America/Chicago zig build test-shared -Doptimize=Debug --summary all`: 40/40 tests passed.
- `TZ=Pacific/Auckland zig build test-shared -Doptimize=Debug --summary all`: 40/40 tests passed.
- `TZ=America/Chicago zig build test-shared -Doptimize=ReleaseSafe --summary all`: 40/40 tests passed.
- `zig build coverage-shared -Doptimize=Debug`: 217/241 owned PCs, 24/24 critical branches, 25 tests, 0 skipped.
- `zig build coverage-shared -Doptimize=ReleaseSafe`: 217/241 owned PCs, 24/24 critical branches, 25 tests, 0 skipped.
- Owned diff: all 16 changed paths are within `services/api/src/shared/**` or `services/api/tests/shared/**`; `git diff --check 43c76a3^ 43c76a3` passed.
- Fixture round trip: the exact WP02 corpora are consumed in place; declared/required/visited counts are 42/42 valid and 73/73 invalid, including all 8 runtime-layer cases. The in-scope mission common schema and generated schema have identical closed value shapes and patterns; their byte differences are descriptions/formatting only. Other mission contracts reference these common definitions and introduce no contradictory shared-value example.

## Requirement and subtask verdicts

- T020: **REJECTED** — B1 is a reachable canonical-length malformed-hyphen abort.
- T021: passed review evidence; exact signed i64 endpoints, negative Money, checked arithmetic, and open structural currency are covered without floating point or FX.
- T022: passed review evidence; Gregorian dates, UTC millisecond instants, and prefixed lowercase SHA-256 values align with the frozen shapes.
- T023: passed review evidence; distinct RequestId, owned JSON lifetimes, quoted integers, closed Money objects, and stable non-sensitive enum errors are exercised.
- T024: **REJECTED transitively** — the current critical syntax inventory does not protect B1, despite the aggregate 90%/24-of-24 report being green.

## Anti-pattern checklist

1. Dead code: **PASS** — all nine modules are exported through the production shared root; composed converters call the value parsers/formatters, and the remaining public value operations are explicit contract deliverables.
2. Synthetic-fixture test: **PASS** — tests load the canonical WP02 fixture files and invoke production parsers; focused JSON tests invoke the production converter boundary.
3. Silent empty return: **PASS** — no silent empty/null return exists in owned production code; empty catches occur only in coverage-driving tests.
4. FR coverage: **FAIL** — FR-003's malformed-hyphen rejection is not behaviorally covered and currently aborts.
5. Frozen surface: **PASS** — commit `43c76a3` modifies only WP05-owned files and no frozen contract/build/dependency file.
6. Locked decision: **PASS** — no floats, FX, currency allowlist, invoice policy, or alternate wire spelling was introduced.
7. Shared-file ownership: **PASS** — lane-e is exclusive to WP05 and the 16 paths match the owned globs.
8. Production fragility: **FAIL** — B1 exposes a user-input-reachable bounds panic in a fallible parser that promises a stable typed error.

## Governance note

The WP entered review with `agent_profile: implementer-ivan` and `role: implementer`; the generated review prompt required loading that profile. It was loaded and the review remained read-only. Set the reviewer profile before the next review claim so the review capsule carries reviewer-specific directives.

Downstream packages WP07, WP08, WP11, and WP12 depend on WP05 and must not consume or rebase onto this cycle as approved work.

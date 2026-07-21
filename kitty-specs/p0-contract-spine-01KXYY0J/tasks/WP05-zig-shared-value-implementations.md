---
work_package_id: WP05
title: Zig Shared Value Implementations
dependencies:
- WP02
- WP04
requirement_refs:
- FR-003
- NFR-004
- NFR-006
- C-003
- C-006
tracker_refs: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch.
subtasks:
- T020
- T021
- T022
- T023
- T024
phase: Phase 2 - Canonical Contract Foundation
assignee: ''
agent: "codex"
history: []
agent_profile: implementer-ivan
authoritative_surface: services/api/src/shared/
create_intent:
- services/api/src/shared/entity_id.zig
- services/api/src/shared/currency.zig
- services/api/src/shared/money.zig
- services/api/src/shared/local_date.zig
- services/api/src/shared/utc_instant.zig
- services/api/src/shared/digest.zig
- services/api/src/shared/request_id.zig
- services/api/src/shared/json_http.zig
- services/api/src/shared/root.zig
- services/api/tests/shared/entity_id_test.zig
- services/api/tests/shared/money_test.zig
- services/api/tests/shared/temporal_test.zig
- services/api/tests/shared/digest_test.zig
- services/api/tests/shared/json_http_test.zig
- services/api/tests/shared/boundary_fixtures_test.zig
- services/api/tests/shared/boundary_coverage_test.zig
execution_mode: code_change
model: ''
owned_files:
- services/api/src/shared/**
- services/api/tests/shared/**
role: implementer
tags: []
task_type: implement
shell_pid: "1417471"
---

# Work Package Prompt: WP05 – Zig Shared Value Implementations

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

After loading the profile, run:

```bash
spec-kitty agent action implement WP05 --agent codex
```

---

## ⚠️ IMPORTANT: Review Feedback

Query WP status before editing. Treat every unresolved `review_ref` finding as
required owned work, append remediation chronologically, and move state only
through Spec Kitty commands.

## Objective

Implement the Zig 0.16 shared values that enforce the P0 canonical wire contract
without importing invoice-manager business behavior. Prove exact representation,
semantic validation, conversion, and error handling against WP02's valid and
invalid boundary fixtures.

Completion means service code has one authoritative implementation for UUIDv7
entity identifiers, signed integer-minor Money, structural currency values,
Gregorian local dates, exact UTC millisecond instants, SHA-256 digests, request
identifiers, and JSON/HTTP boundary conversion.

## Context and Constraints

- WP02 publishes `contracts/common/v1/schema.json` and the canonical boundary fixtures.
- WP04 supplies the pinned Zig 0.16 service build surface and ShovelerDB adapter boundary.
- This package must consume both dependencies; do not duplicate their contract or build ownership.
- The JSON Schema proves syntax and shape, but Zig must prove semantic ranges and calendar validity.
- `services/api/src/shared/**` is the reusable service value layer, not a feature-domain directory.
- `services/api/tests/shared/**` is the only test surface owned by this package.
- The Zig service is the business authority under C-003, but P0 defines no business policies.
- Preserve every wire spelling exactly; parsing and formatting must round-trip canonically.
- Do not use binary floating point for money, counters, timestamps, or conversions.
- Do not introduce implicit foreign exchange, rounding, tax, invoice, payment, or billing logic.
- Currency syntax is exactly three uppercase ASCII letters.
- Do not add a USD/EUR launch allowlist; later domain missions own permitted-currency policy.
- Money uses a checked signed `i64` count of minor units plus explicit currency.
- Negative Money is valid in this shared layer.
- UUIDv7 is canonical lowercase and opaque; do not expose timestamp ordering as business behavior.
- LocalDate is a Gregorian civil date with no time or timezone.
- UtcInstant is UTC-only with exactly three fractional digits and uppercase `Z` on the wire.
- Sha256Digest is `sha256:` followed by exactly 64 lowercase hexadecimal characters.
- RequestId has the same wire rules as EntityId but remains a distinct semantic type.
- All test data must be synthetic and free of client, bank, invoice, credential, or private-key data.
- Keep Zig 0.16 APIs explicit about ownership; never return temporary-buffer slices or add version-compatibility branches.

## Scope Boundary

Create or modify only `services/api/src/shared/**` and `services/api/tests/shared/**`.
Do not edit WP02 contracts/fixtures, WP04 build/storage, later HTTP routing,
generated web types, root/CI/mission metadata, or feature-domain paths.

If WP04's build graph cannot discover these owned tests, report the missing
integration seam to the WP04 owner. Do not claim or edit WP04's build files.

## Branch Strategy

- **Strategy**: `wp_branch`
- **Planning base branch**: `feat/p0-contract-spine`
- **Merge target branch**: `feat/p0-contract-spine`
- **Dependencies**: WP02 and WP04 must be available in the implementation workspace.

Let Spec Kitty choose the dependency-resolved base. Do not manually retarget,
merge unrelated branches, or bypass review.

## Requirement Traceability

Implement FR-003 and IC-02 in authoritative Zig per C-003. Preserve all signed
i64 values for NFR-004, use checked integer-minor Money without floats or FX per
C-006, and meet NFR-006's coverage and critical-branch requirements.

## Owned Deliverables

Create the value, converter, export, and focused test files enumerated by
`create_intent`. Keep `root.zig` a small export surface, not a service locator,
domain registry, storage adapter, or router. Record any in-glob naming change.

## Subtasks and Detailed Guidance

### Subtask T020 – Implement Canonical UUIDv7 Entity IDs

**Purpose**: Provide an opaque, strongly typed EntityId that accepts and emits
only the exact lowercase, hyphenated UUIDv7 wire representation.

**Steps**:

1. Create `services/api/src/shared/entity_id.zig` with a value type backed by the 16 UUID bytes.
2. Expose a fallible parser from the canonical 36-byte textual form.
3. Require hyphens at byte offsets 8, 13, 18, and 23.
4. Require lowercase ASCII hexadecimal everywhere else.
5. Reject uppercase, braces, URN prefixes, missing hyphens, extra bytes, and non-ASCII input.
6. Decode and require UUID version nibble `7`.
7. Require the RFC variant nibble to be one of `8`, `9`, `a`, or `b`.
8. Return stable typed errors that distinguish length, syntax, version, and variant failures.
9. Provide equality over canonical bytes.
10. Provide canonical formatting into a caller-owned fixed buffer or writer.
11. Guarantee parse-format-parse identity without heap allocation.
12. Do not expose the embedded timestamp as sorting or business-order semantics.
13. Avoid a generic UUID dependency unless WP04 already provides one and its behavior is proven exact.
14. Export the type through `services/api/src/shared/root.zig`.

**Files**:

- `services/api/src/shared/entity_id.zig`
- `services/api/src/shared/root.zig`
- `services/api/tests/shared/entity_id_test.zig`

**Validation**:

- Accept WP02 valid UUIDv7 cases for each permitted variant nibble.
- Reject wrong version, wrong variant, uppercase, malformed hyphens, bad hex, and wrong lengths.
- Assert emitted text matches the input bytes exactly.
- Assert equality is byte equality and no temporal ordering API exists.

### Subtask T021 – Implement Exact Money and Structural Currency Values

**Purpose**: Represent money as explicit currency plus checked signed integer
minor units, with no precision loss and no P1 business policy.

**Steps**:

1. Create `services/api/src/shared/currency.zig` as a three-byte value type.
2. Accept only three uppercase ASCII letters.
3. Reject lowercase, mixed case, digits, symbols, whitespace, Unicode, and wrong lengths.
4. Do not encode or consult a list of known, launch, legal-tender, or supported currencies.
5. Ensure a synthetic non-launch value such as `ZZZ` remains structurally valid.
6. Create `services/api/src/shared/money.zig` with `currency` and signed `i64 minor_units` fields.
7. Parse the wire `minor_units` as a canonical decimal string, never a JSON number.
8. Accept `0`, positive values, negative values, `-9223372036854775808`, and `9223372036854775807`.
9. Reject leading plus, leading zeroes, negative zero, whitespace, fractions, exponents, and overflow.
10. Format back to the unique canonical decimal spelling without allocation where practical.
11. Implement checked addition and subtraction for equal currencies.
12. Return a distinct currency-mismatch error instead of converting or aggregating currencies.
13. Return overflow errors rather than wrapping, saturating, trapping unexpectedly, or using floats.
14. Keep negative values legal; invoice-specific nonnegative rules belong to later domains.
15. Do not add display decimals, locale formatting, tax rounding, FX rates, or currency exponents.
16. Export Currency and Money through `services/api/src/shared/root.zig`.

**Files**:

- `services/api/src/shared/currency.zig`
- `services/api/src/shared/money.zig`
- `services/api/src/shared/root.zig`
- `services/api/tests/shared/money_test.zig`

**Validation**:

- Round-trip both signed i64 endpoints and values above JavaScript's safe integer limit.
- Exercise zero, positive, and negative Money.
- Test checked addition/subtraction success, overflow, underflow, and currency mismatch.
- Prove `ZZZ` is accepted structurally and no currency allowlist exists.
- Search the owned source for `f16`, `f32`, `f64`, or float conversion in money paths.

### Subtask T022 – Implement LocalDate, UtcInstant, and Sha256Digest

**Purpose**: Enforce the semantic rules that JSON Schema patterns cannot prove,
while retaining exact canonical strings at the wire boundary.

**Steps**:

1. Create `services/api/src/shared/local_date.zig` with explicit year, month, and day fields.
2. Parse exactly ten ASCII bytes in `YYYY-MM-DD` form.
3. Validate Gregorian month lengths and leap-year rules, including century exceptions.
4. Reject impossible dates, year/month/day zero, missing padding, extra text, and time suffixes.
5. Define and document the supported four-digit year range consistently with the contract.
6. Format every accepted date back to exactly ten canonical bytes.
7. Do not attach a timezone, offset, time of day, locale, or recurrence meaning.
8. Create `services/api/src/shared/utc_instant.zig` for exact `YYYY-MM-DDTHH:mm:ss.SSSZ` input.
9. Require uppercase `T` and `Z`, UTC only, and exactly three fractional digits.
10. Validate the embedded Gregorian date plus hour, minute, second, and millisecond ranges.
11. Reject offsets, lowercase markers, absent fractions, variable precision, epoch numbers, and leap-second spellings unless the frozen contract explicitly permits them.
12. Preserve milliseconds exactly through parse and format; do not round from finer precision.
13. Keep the representation deterministic across local timezone and locale settings.
14. Create `services/api/src/shared/digest.zig` for the Sha256Digest value.
15. Require literal prefix `sha256:` and 64 lowercase hexadecimal characters.
16. Store the decoded 32 bytes or a canonical fixed-size spelling, then emit the exact canonical form.
17. Reject uppercase hex, missing prefix, wrong algorithms, wrong lengths, bad characters, and whitespace.
18. Export all three values through `services/api/src/shared/root.zig`.

**Files**:

- `services/api/src/shared/local_date.zig`
- `services/api/src/shared/utc_instant.zig`
- `services/api/src/shared/digest.zig`
- `services/api/src/shared/root.zig`
- `services/api/tests/shared/temporal_test.zig`
- `services/api/tests/shared/digest_test.zig`

**Validation**:

- Test leap years 2000 and 2024 as valid and 1900/2100 leap days as invalid.
- Test month ends, invalid month/day zero, and canonical zero padding.
- Test exact millisecond endpoints, invalid hours/minutes/seconds, offsets, and fraction lengths.
- Test digest prefix, case, length, hexadecimal decoding, and exact formatting.
- Run date and instant tests under a non-UTC process timezone to prove independence.

### Subtask T023 – Implement JSON/HTTP Converters and Request IDs

**Purpose**: Centralize lossless wire conversion so HTTP and future domain code
cannot invent alternate parsers or serialize exact integers as JSON numbers.

**Steps**:

1. Create `services/api/src/shared/request_id.zig` as a distinct wrapper around EntityId semantics.
2. Reuse EntityId validation internally without making RequestId freely interchangeable with entity identities.
3. Preserve distinct type identity at compile time.
4. Create `services/api/src/shared/json_http.zig` as a narrow conversion layer.
5. Parse canonical JSON strings for EntityId, RequestId, Currency, LocalDate, UtcInstant, Sha256Digest, and signed i64 values.
6. Parse Money only as a closed object with exactly `currency` and `minor_units`.
7. Reject missing fields, unknown fields, duplicate fields, wrong JSON types, null, and trailing content.
8. Never accept a JSON number for `minor_units` or other canonical i64 wire values.
9. Emit `minor_units` as a JSON string and preserve the exact signed value.
10. Keep HTTP header conversion limited to values the frozen P0 boundary identifies, especially request correlation.
11. Reject surrounding whitespace or alternate header spellings when canonical text is required.
12. Return stable shared conversion errors suitable for later mapping, not HTTP status codes or response bodies.
13. Do not import a router, handler, server, storage layer, or feature-domain module.
14. Make allocation behavior explicit and accept an allocator only where the chosen Zig JSON API requires it.
15. Ensure parsed data does not borrow from a buffer with a shorter lifetime.
16. Keep secret or raw input values out of error strings and logs.
17. Export RequestId and converters through `services/api/src/shared/root.zig`.

**Files**:

- `services/api/src/shared/request_id.zig`
- `services/api/src/shared/json_http.zig`
- `services/api/src/shared/root.zig`
- `services/api/tests/shared/json_http_test.zig`

**Validation**:

- Round-trip every shared value through JSON.
- Assert i64 boundary values are emitted as quoted decimal strings.
- Assert Money rejects extra/missing fields and JSON-number minor units.
- Assert RequestId is wire-compatible with EntityId but not type-interchangeable.
- Assert every failure is deterministic and contains no raw sensitive input.

### Subtask T024 – Drive Red-First Boundary and Coverage Proof

**Purpose**: Convert WP02's contract fixtures into executable proof for every
documented acceptance and error branch before implementation is declared done.

**Steps**:

1. Create `services/api/tests/shared/boundary_fixtures_test.zig`.
2. Load the valid and invalid common-boundary corpora from WP02 through repository-relative paths.
3. Do not copy fixture payloads into Zig tests as a second source of truth.
4. Start with failing tests for each fixture category, then implement until they pass.
5. Assert every valid fixture case is visited and accepted by the named value parser.
6. Assert every invalid fixture case is visited and rejected at its declared structural or semantic layer.
7. For runtime-only invalid cases, prove their canonical syntax is accepted before semantic rejection.
8. Track stable case IDs and fail if a required category becomes empty.
9. Cover EntityId length, syntax, UUID version, and variant branches.
10. Cover canonical i64 syntax, both overflow directions, and signed endpoints.
11. Cover Currency syntax without an allowlist and Money object/checked-arithmetic failures.
12. Cover LocalDate shape, Gregorian validity, leap-year, and range failures.
13. Cover UtcInstant shape, UTC marker, exact milliseconds, date, and clock failures.
14. Cover digest prefix, case, length, and alphabet failures.
15. Cover RequestId and JSON/HTTP type/shape failures.
16. Add direct unit tests for internal branches that fixtures cannot naturally reach.
17. Keep all examples synthetic and verify no production-looking data enters logs or snapshots.
18. Record the test count, fixture count, and critical-branch inventory in the Activity Log.
19. Obtain the shared-value coverage report through WP04's build step.
20. Require at least 90% automated coverage for owned shared code and 100% of enumerated critical error branches.
21. Add a mutation or sentinel test that fails if negative Money, non-launch currency, exact milliseconds, or i64 overflow cases disappear.
22. Do not weaken a fixture, skip a case, or catch-all an error merely to reach green.

### Executable Shared Coverage Contract

Use WP04's exact `coverage-shared` mechanism. Every production file that owns one
of the following branches must import the build-wired probe with exact
`const shared_coverage = @import("shared_coverage_probe");` and call
`shared_coverage.hit(.<tag>)` inside the real error branch:

`entity_id_length`, `entity_id_syntax`, `entity_id_version`,
`entity_id_variant`, `currency_length`, `currency_alphabet`,
`money_decimal_syntax`, `money_overflow`, `money_currency_mismatch`,
`money_add_overflow`, `money_sub_overflow`, `local_date_shape`,
`local_date_invalid`, `utc_instant_shape`, `utc_instant_invalid_date`,
`utc_instant_invalid_clock`, `digest_prefix`, `digest_length`,
`digest_alphabet`, `json_wrong_type`, `json_unknown_field`,
`json_duplicate_field`, `json_missing_field`, and `json_trailing_content`.

Put executable cases in exact dedicated root
`services/api/tests/shared/boundary_coverage_test.zig`. It may import only `std`
and public `@import("shared")`, with exact canonical binding
`const shared = @import("shared");`. Include exact executable declaration test
`test "shared production declarations are analyzed" { std.testing.refAllDecls(shared); }`.
Name each critical test exactly `test "critical branch: <tag>"`; reach the tag
through the public shared boundary, assert the stable error, and execute a
positive owned-production PC delta after WP04 resets counters. Tests must never
import or mutate the probe directly. Missing or renamed roots, a denominator
below 24 owned production PCs, below 90%, unknown, duplicate, or missing names,
skipped or logged-error tests, missing production hits, or zero per-test
production deltas are hard failures.

**Files**:

- `services/api/tests/shared/boundary_fixtures_test.zig`
- all focused test files listed by prior subtasks

**Validation**:

- Demonstrate red-first evidence in the Activity Log without committing temporary broken code.
- Run the focused shared test step twice from an unchanged checkout.
- Confirm the same cases and deterministic results execute both times.
- Confirm coverage and critical-branch gates fail when their sentinels are removed.

## Test Strategy and Commands

Run from the repository root unless a command explicitly changes directory.
Use the exact focused build steps exposed by WP04; do not modify its build files.

```bash
zig version
zig fmt --check services/api/src/shared services/api/tests/shared
cd services/api
zig build test-shared
zig build coverage-shared
```

`test-shared` and `coverage-shared` are literal WP04 hook names. Do not
substitute aliases or documented equivalents. A missing hook is a WP04 dependency
defect to route to its owner, not permission to edit `build.zig` in this package.
Do not require aggregate `zig build test` while WP06-WP08 producers are absent;
WP04 intentionally fails those missing downstream categories closed.

Required test classes include parser/formatter round trips; all WP02 fixtures;
signed i64 endpoints, unsafe-JavaScript values, and overflow; signed Money and
checked arithmetic; non-allowlisted structural Currency; Gregorian and exact
UTC millisecond boundaries; digest form; RequestId type separation; JSON type,
object-closure, duplicate-member, and lifetime failures; safe diagnostics; and
90% coverage plus every enumerated critical branch.

Before handoff, run `git diff --check`, `git status --short`, and
`git diff --name-only`; every changed path must remain within WP05's owned globs.

## Definition of Done

- [ ] EntityId accepts only canonical lowercase hyphenated UUIDv7 with the RFC variant.
- [ ] EntityId round-trips through fixed-size text without allocation or spelling drift.
- [ ] Currency accepts exactly three uppercase ASCII letters.
- [ ] No currency allowlist or launch policy exists in shared source or tests.
- [ ] Money stores explicit Currency and signed `i64` minor units.
- [ ] Money accepts signed endpoints, rejects noncanonical/overflow input, and uses checked same-currency arithmetic.
- [ ] No binary floating-point operation appears in Money or canonical-integer paths.
- [ ] LocalDate, UtcInstant, and Sha256Digest enforce their exact semantic and canonical forms.
- [ ] RequestId is a distinct semantic type with EntityId wire validation.
- [ ] JSON/HTTP converters accept and emit only frozen P0 wire representations.
- [ ] Canonical signed integers always cross JSON as strings.
- [ ] Money JSON is closed and rejects missing, extra, duplicate, and wrong-type fields.
- [ ] Every WP02 valid fixture is accepted and every invalid fixture is rejected at the declared layer.
- [ ] Runtime-only invalid fixtures prove structural acceptance before semantic rejection.
- [ ] Fixture category counts and mutation sentinels prevent vacuous test success.
- [ ] Shared Zig code reaches 90% coverage and every critical error branch has an explicit assertion.
- [ ] Formatting, focused shared tests, measured shared coverage, and diff checks pass.
- [ ] All examples and logs are synthetic and contain no sensitive material.
- [ ] Only WP05-owned files changed.
- [ ] The Activity Log records commands, counts, coverage, and reviewer remediation chronologically.

## Risks and Mitigations

- **Schema-only confidence**: patterns cannot prove i64 range or Gregorian validity; test Zig semantic parsers directly.
- **Precision loss**: never route canonical integers through JSON numbers or floating-point intermediates.
- **Money policy leakage**: keep negative Money and non-launch currency cases as permanent sentinels.
- **Integer overflow**: use checked operations and explicit errors for parsing and arithmetic.
- **UUID library normalization**: reject uppercase and alternate forms before any permissive dependency can normalize them.
- **Temporal drift**: use explicit Gregorian rules and reject offsets or variable fractions without normalization.
- **Digest ambiguity**: retain the algorithm prefix and lowercase canonical alphabet.
- **Type collapse**: keep RequestId distinct even when it delegates validation to EntityId.
- **Borrowed-memory bugs**: copy or own parsed results whose input buffers may expire.
- **Sensitive diagnostics**: errors identify category and location without echoing raw data.
- **Vacuous evidence**: assert fixture IDs/counts/sentinels and all error branches regardless of coverage percentage.
- **WP ownership collision**: coordinate missing build hooks with WP04 instead of editing build files.
- **Feature creep**: reject any invoice, client, payment, FX, display, or scheduling behavior from this layer.

## Reviewer Guidance

Review against WP02's schema and fixtures, not against permissive library defaults.
Trace every public shared type to FR-003 and every integer conversion to NFR-004.

Confirm specifically:

- each parser has one canonical formatter and round-trips exactly;
- UUIDv7 version and RFC variant are both checked;
- `RequestId` cannot be accidentally passed as an `EntityId`;
- signed i64 limits are checked semantically;
- Money never uses binary floating point and permits negative values;
- checked Money arithmetic rejects overflow and mismatched currencies;
- `ZZZ` or another non-launch uppercase code proves there is no allowlist;
- LocalDate applies Gregorian rules and UtcInstant requires exact UTC milliseconds;
- Sha256Digest includes the literal prefix and lowercase 64-hex body;
- JSON converters reject numeric minor units and non-closed Money objects;
- runtime-only fixture failures are not mislabeled as schema failures;
- every invalid branch is asserted and shared coverage is at least 90%;
- errors are safe and no out-of-scope file changed.

Reject the package if representation is merely normalized after permissive
parsing, if tests duplicate rather than consume WP02 fixtures, if a currency
allowlist appears, or if a percentage report masks an untested critical branch.

## Activity Log

> Append entries in chronological order, oldest first and newest last. Use UTC.
> Include agent, commands, test/fixture counts, coverage, remediation, and coordination.

No implementation entries yet.

### Updating Status

Use `spec-kitty agent tasks move-task WP05 --to <status>`; never edit status
logs or frontmatter state by hand.
- 2026-07-21T02:08:27Z – codex – shell_pid=1807838 – Assigned agent via action command
- 2026-07-21T02:34:12Z – codex – shell_pid=1807838 – 2026-07-21T02:13:59Z red-first evidence: before production edits, cd services/api && zig build test-shared -Doptimize=Debug exited 1 with the WP04 fail-closed diagnostic that the WP05 shared producer was absent (count 0).
- 2026-07-21T02:34:35Z – codex – shell_pid=1807838 – 2026-07-21T02:31:37Z implementation evidence at 43c76a3: zig fmt --check clean; test-shared 40/40 twice under America/Chicago and Pacific/Auckland, plus ReleaseSafe 40/40; WP02 fixtures consumed in place, 42/42 valid accepted and 73/73 invalid rejected with 8 runtime-only structural-before-semantic cases; coverage-shared measured 217/241 production PCs (90% minimum), 24/24 exact critical branches, 25 coverage tests, 0 skipped in Debug and ReleaseSafe. Adversarial sentinels: removing a production probe or renaming a critical test failed the static gate; removing edge execution failed 198/241 BelowThreshold. WP04 regressions: adapter 4/4, ABI integration 3/3, discovery 16/16. Diff-scoped zig fmt: 0 issues, exit 0; ownership: 16/16 paths under services/api/src/shared/** or services/api/tests/shared/**.
- 2026-07-21T02:35:08Z – codex – shell_pid=1807838 – Ready for independent review: commit 43c76a3; 40/40 Debug and ReleaseSafe; 42 valid + 73 invalid fixtures; measured 217/241 PCs and 24/24 critical branches; three adversarial coverage sentinels fail closed; owned diff and formatting clean.
- 2026-07-21T02:58:50Z – codex – shell_pid=1807838 – Started review via action command
- 2026-07-21T03:06:13Z – user – shell_pid=1807838 – Moved to planned
- 2026-07-21T03:32:53Z – codex – shell_pid=1417471 – Started implementation via action command

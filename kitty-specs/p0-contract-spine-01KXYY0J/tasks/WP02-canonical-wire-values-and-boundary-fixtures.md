---
work_package_id: WP02
title: Canonical Wire Values and Boundary Fixtures
dependencies:
- WP01
requirement_refs:
- FR-003
- NFR-004
- NFR-006
- NFR-010
- C-006
tracker_refs: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch.
subtasks:
- T005
- T006
- T007
phase: Phase 2 - Canonical Contract Foundation
assignee: ''
agent: "codex:gpt-5:reviewer-renata:reviewer"
shell_pid: "1807838"
history:
- at: '2026-07-20T06:59:16Z'
  actor: system
  action: Prompt generated via /spec-kitty.tasks-packages
agent_profile: implementer-ivan
authoritative_surface: contracts/common/v1/
create_intent:
- contracts/common/v1/schema.json
- contracts/fixtures/p0/v1/valid/common-boundaries.json
- contracts/fixtures/p0/v1/invalid/common-boundaries.json
execution_mode: code_change
model: ''
owned_files:
- contracts/common/v1/**
- contracts/fixtures/p0/v1/valid/common-*
- contracts/fixtures/p0/v1/invalid/common-*
role: implementer
tags: []
task_type: implement
---

# Work Package Prompt: WP02 – Canonical Wire Values and Boundary Fixtures

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## ⚠️ IMPORTANT: Review Feedback

- Before implementation, inspect the WP status and event log for a `review_ref`.
- Treat every unresolved reviewer item as an implementation requirement.
- Append progress and review-remediation notes to the Activity Log in chronological order.
- Do not modify status logs directly; use the Spec Kitty task commands.

## Objective

Publish the stable P0 JSON Schema for canonical cross-language wire values and
two exhaustive synthetic boundary corpora that future Zig, TypeScript, API,
event, migration, and composition work can consume without redefining values.

Completion means the schema has the exact stable identifier, fixtures distinguish
structural validation from mandatory semantic runtime validation, and the handoff
proves signed Money and unrestricted structural currency codes remain intact.

## Context and Architectural Constraints

- WP02 depends on WP01's reproducible root toolchain and command substrate.
- WP03 will own `tools/contracts/**` and schema composition; do not implement its tooling here.
- WP05 will own Zig parsers and semantic validators; do not create Zig source here.
- WP03 is the sole generated-TypeScript generator and workspace exporter; do not implement its tooling here.
- WP10 is the only web consumer of those exports; WP09 remains config-only and consumes no fixtures.
- The planning Draft is `kitty-specs/p0-contract-spine-01KXYY0J/contracts/common-v1.schema.json`.
- The implementation destination is `contracts/common/v1/schema.json`.
- The stable schema ID is `https://invoice-manager.invalid/contracts/common/v1/schema.json`.
- This URL is an identifier resolved from the repository registry; validation must not fetch the network.
- JSON Schema 2020-12 supplies the structural contract.
- Zig runtime parsing remains authoritative for signed-64-bit range and semantic calendar validity.
- `Money.minor_units` stays a canonical signed decimal string.
- Negative Money is valid at the shared wire layer even if a later domain forbids it contextually.
- `CurrencyCode` stays exactly three uppercase ASCII letters.
- Do not add an enum for USD, EUR, or any business currency allowlist.
- P1 owns launch currency policy; P0 owns only the structural representation.
- `UtcInstant` is UTC-only with exactly three fractional-second digits and uppercase `Z`.
- `LocalDate` has no timezone or time-of-day meaning.
- UUIDv7 is canonical lowercase and opaque; timestamp order is not a business guarantee.
- Request IDs are aliases of the exact EntityId representation.
- SHA-256 digests use `sha256:` followed by 64 lowercase hexadecimal characters.
- Fixtures must contain invented boundary data only and no client or secret material.
- Stay within `owned_files`; if an unexpected change outside them appears necessary, stop and route it to the owning WP.

## Branch Strategy

- **Strategy**: Planning artifacts were generated on `feat/p0-contract-spine`; completed changes must merge back into `feat/p0-contract-spine`.
- **Planning base branch**: `feat/p0-contract-spine`
- **Merge target branch**: `feat/p0-contract-spine`
- Start implementation with `spec-kitty agent action implement WP02 --agent codex`.
- Let Spec Kitty select the execution lane and worktree; do not choose a different base manually.

## Owned Deliverables

Create exactly these primary deliverables:

1. `contracts/common/v1/schema.json`
2. `contracts/fixtures/p0/v1/valid/common-boundaries.json`
3. `contracts/fixtures/p0/v1/invalid/common-boundaries.json`

No test runner belongs to WP02. The fixture files themselves are executable
contract inputs for WP03, WP05, and WP10, and their format must be explicit
enough that those packages do not need private assumptions.

## Subtasks and Detailed Guidance

### Subtask T005 – Relocate and Publish Stable Common Schema Identifiers

**Purpose**: Move the approved planning representation into its permanent
repository-owned location without semantic drift or sibling-relative references.

**Steps**:

1. Create `contracts/common/v1/schema.json` as JSON Schema 2020-12.
2. Set `$id` exactly to the stable repository identifier documented above.
3. Preserve these `$defs` names exactly:
   - `EntityId`
   - `CurrencyCode`
   - `CanonicalInt64`
   - `NonNegativeInt64`
   - `Money`
   - `LocalDate`
   - `UtcInstant`
   - `Sha256Digest`
   - `RequestId`
4. Keep `EntityId` as a lowercase, hyphenated UUIDv7 with an RFC-compatible variant nibble.
5. Keep `CurrencyCode` as the structural pattern `^[A-Z]{3}$`.
6. Keep `CanonicalInt64` as a JSON string with no plus sign, exponent, decimal, whitespace, leading zero, or negative zero.
7. Keep `NonNegativeInt64` as the analogous nonnegative canonical string.
8. Keep `Money` closed with `additionalProperties: false` and require both `currency` and `minor_units`.
9. Reference `CurrencyCode` and signed `CanonicalInt64` from Money; do not use `NonNegativeInt64` there.
10. Keep `LocalDate` in canonical `YYYY-MM-DD` form and retain the `date` format annotation.
11. Keep `UtcInstant` in canonical `YYYY-MM-DDTHH:mm:ss.SSSZ` form and retain the `date-time` format annotation.
12. Keep `Sha256Digest` lowercase and algorithm-prefixed.
13. Define `RequestId` by `$ref` to `EntityId`, not by copying its pattern.
14. Add descriptions or `$comment` where they clarify the schema/runtime boundary.
15. State that regex-valid int64 spellings still require checked runtime range validation.
16. State that regex/format-valid dates still require real Gregorian runtime validation.
17. Do not add business entities, API envelopes, event payloads, tax behavior, or currency policy.
18. Format the final JSON deterministically with a trailing newline.

**Files**:

- Create `contracts/common/v1/schema.json`.
- Do not modify the planning Draft under `kitty-specs/**`.
- Do not modify API, event, manifest, migration, or module schemas owned by WP03.

**Validation**:

- Parse the file as JSON from a clean process.
- Confirm `$schema`, `$id`, and every required `$defs` key by exact equality.
- Confirm every internal `$ref` resolves within this schema.
- Confirm the schema contains no `USD`/`EUR` enum and no network-relative `$ref`.
- Confirm Money accepts a negative canonical minor-unit spelling structurally.
- Confirm the file has no unresolved planning path or Draft-only identifier.

### Subtask T006 – Create Exhaustive Valid Boundary Fixtures

**Purpose**: Publish valid examples that pin precision, canonical spelling,
calendar, timestamp, digest, alias, and open structural currency behavior.

**Fixture envelope**:

1. Create one deterministic JSON object with `fixture_version`, `schema_id`, `purpose`, `consumer_handoff`, and `cases`.
2. Set `schema_id` to the stable common schema ID.
3. In `consumer_handoff`, list the exact `$defs` consumers must resolve.
4. Record that range/date semantics are rechecked by Zig and TypeScript consumers.
5. Give every case a stable `case_id`, `definition`, `value`, and short `reason`.
6. Mark each case `expectation: "valid"`.
7. Sort cases first by definition and then by case ID.
8. Keep values as their actual JSON types; do not stringify Money objects.

**Required EntityId and RequestId cases**:

- A normal lowercase UUIDv7 with variant `8`.
- Valid variant nibble examples for `9`, `a`, and `b`.
- Hex-boundary-heavy lowercase examples that still satisfy version and variant bits.
- A RequestId case identical in representation to EntityId.
- A note that UUID time ordering is not asserted by this fixture.

**Required integer cases**:

- `-9223372036854775808` and `9223372036854775807` for CanonicalInt64.
- `-1`, `0`, and `1`.
- `-9007199254740993` and `9007199254740993` to exceed JavaScript safe integer range.
- `0`, `1`, and `9223372036854775807` for NonNegativeInt64.
- Preserve every integer value as a JSON string.

**Required Money and currency cases**:

- Negative, zero, positive, int64-minimum, and int64-maximum minor units.
- At least USD and EUR examples for familiar consumption.
- At least one structurally valid non-launch code such as `JPY` or `ZZZ`.
- Explicit evidence that a non-launch uppercase code is valid at P0.
- Closed object shape with exactly `currency` and `minor_units`.

**Required LocalDate cases**:

- A normal mid-month date.
- Gregorian leap day `2000-02-29`.
- A divisible-by-four leap day such as `2024-02-29`.
- Valid month-end examples for 30-day and 31-day months.
- Conservative supported-year boundary examples agreed with the Zig handoff.

**Required UtcInstant cases**:

- Unix epoch with `.000Z`.
- A leap-day instant.
- Millisecond values `.001Z` and `.999Z`.
- A date/year boundary instant.
- Every valid case must have uppercase `T` and `Z` and exactly three fractional digits.

**Required digest cases**:

- `sha256:` plus 64 zeroes.
- `sha256:` plus 64 lowercase `f` characters.
- A mixed lowercase hexadecimal digest.

**Files**:

- Create `contracts/fixtures/p0/v1/valid/common-boundaries.json`.
- Target roughly 35–50 focused cases rather than repetitive permutations.

**Validation**:

- Every schema-valid case must validate against the referenced `$defs` entry.
- Every runtime-semantic valid case must be independently calculable by inspection.
- Parse int64 boundary strings with a checked arbitrary-precision reference and prove they lie within signed 64-bit range.
- Verify at least one Money case would lose precision if incorrectly converted to JavaScript `number`.
- Verify the corpus contains no business currency allowlist assertion.

### Subtask T007 – Create Invalid Boundaries and Consumer-Handoff Evidence

**Purpose**: Make invalid structural and semantic cases explicit so later
validators cannot pass by testing regexes alone or by silently coercing values.

**Fixture envelope**:

1. Mirror the valid fixture's deterministic metadata and case ordering.
2. Give every case `expectation: "invalid"`.
3. Add `expected.code`, `expected.path`, and `expected.validation_layer`.
4. Use an empty JSON Pointer for an invalid scalar root.
5. Use `/currency` or `/minor_units` for a failing Money member.
6. Use `schema`, `runtime`, or `schema_and_runtime` as the validation layer.
7. A runtime-only case must explain why JSON Schema cannot prove the invariant.
8. Do not expect coercion, trimming, case folding, or numeric conversion.

**Required invalid EntityId and RequestId cases**:

- Uppercase hexadecimal.
- UUID version other than 7.
- Variant nibble outside `8`, `9`, `a`, or `b`.
- Missing hyphens, extra braces, invalid hex, wrong length, and surrounding whitespace.
- Repeat at least one representative failure through RequestId to pin alias behavior.

**Required invalid CanonicalInt64 cases**:

- Empty string, `+1`, `-0`, `01`, `-01`, leading/trailing whitespace, decimal, and exponent.
- JSON numeric values instead of strings.
- `-9223372036854775809` and `9223372036854775808` as runtime range failures.
- Very long digit strings that match spelling but must fail bounded parsing safely.

**Required invalid NonNegativeInt64 cases**:

- `-1`, `+1`, `01`, whitespace, decimal, exponent, and numeric JSON.
- One above signed-int64 maximum as a runtime range failure.

**Required invalid Money cases**:

- Missing currency and missing minor units as separate cases.
- Extra property, null member, wrong member type, lowercase code, two-letter code, and four-letter code.
- Noncanonical and out-of-range minor-unit strings.
- Do not mark `JPY`, `GBP`, `CHF`, or another uppercase three-letter code invalid merely because it is outside launch policy.

**Required invalid LocalDate cases**:

- Non-leap `2023-02-29`.
- Impossible day `2024-02-30`.
- Month `00` and `13`, day `00`, missing zero padding, timestamp suffix, and surrounding whitespace.
- Distinguish shape failures from semantic Gregorian failures.

**Required invalid UtcInstant cases**:

- Missing fractional seconds.
- One, two, four, and six fractional digits.
- Numeric UTC offset, lowercase `z`, space instead of `T`, and missing `Z`.
- Impossible month/day/time and surrounding whitespace.
- These cases must not be normalized into the accepted form.

**Required invalid digest cases**:

- Missing `sha256:` prefix.
- Uppercase algorithm name or uppercase hex.
- Too few and too many hex characters.
- Non-hex character, whitespace, and bare digest bytes represented incorrectly.

**Consumer-handoff evidence**:

1. The two fixture roots must identify the same stable `schema_id`.
2. Record schema-valid/runtime-invalid cases explicitly rather than mislabeling the schema as sufficient.
3. State that WP03 must enable JSON Schema format assertion and resolve IDs locally without network fetch.
4. State that WP05 must execute all runtime range and Gregorian semantic cases.
5. State that WP03 must generate and export integer-string or BigInt-safe types, WP10 must consume them without authoritative `number` arithmetic, and WP09 is config-only.
6. State that domain missions may narrow Money or currencies only in their own schemas and validators.
7. Provide counts by definition and validation layer so reviewers can detect an accidentally empty category.
8. Do not implement or edit `tools/contracts/**` to produce this evidence.

**Files**:

- Create `contracts/fixtures/p0/v1/invalid/common-boundaries.json`.
- Target roughly 55–75 focused invalid cases.

**Validation**:

- Each schema-layer case fails for its named definition and intended reason.
- Each runtime-only case passes structural validation first, then fails the documented semantic boundary.
- Expected error pointers address the logical subject root, not array positions inside the corpus.
- Mutation checks prove deleting the int64 overflow, invalid Gregorian date, exact-millisecond, negative-Money, or open-currency evidence is detectable by case IDs/counts.

## Test Strategy

Run the narrowest available commands from WP01 without claiming ownership of
WP03's future contract runner:

1. Parse all three deliverables as strict JSON.
2. Verify exact file paths, stable schema ID, and required `$defs` names.
3. Resolve all internal common-schema references locally.
4. Validate every structural valid/invalid case against its named `$defs` target.
5. Enable JSON Schema `date` and `date-time` format assertions for schema-layer cases.
6. Use a checked reference parser to classify signed-int64 boundaries.
7. Use a real Gregorian reference parser for semantic LocalDate cases.
8. Assert UTC instant byte shape before semantic timestamp parsing.
9. Compare fixture case IDs against an explicit required-case inventory.
10. Run `git diff --check` and inspect the diff for files outside `owned_files`.

If `npm run contracts:check -- --focus common` is already executable after WP01,
run it. If WP01 intentionally provides only the command substrate and WP03 has
not yet supplied the runner, do not create a competing runner in WP02. Record
the exact manual/reference validation evidence in the Activity Log for WP03.

## Definition of Done

- [ ] `contracts/common/v1/schema.json` exists with the exact stable `$id`.
- [ ] All nine required `$defs` exist with the planned names and meanings.
- [ ] Money remains signed and structurally closed.
- [ ] CurrencyCode remains three uppercase letters with no business allowlist.
- [ ] UtcInstant requires UTC and exactly three millisecond digits.
- [ ] LocalDate and int64 descriptions preserve mandatory semantic runtime validation.
- [ ] Valid fixtures cover UUIDv7 variants, signed bounds, JS-unsafe integers, Money signs, dates, instants, digests, and RequestId.
- [ ] Invalid fixtures cover canonical spelling, types, ranges, dates, exact instants, digests, Money shape, UUID version/variant, and RequestId.
- [ ] Runtime-only invalid cases pass structural validation before semantic rejection.
- [ ] Both corpora publish stable case IDs, logical JSON Pointers, layer metadata, and consumer handoff.
- [ ] At least one valid non-launch currency proves P0 has no USD/EUR allowlist.
- [ ] At least one valid negative Money case prevents accidental nonnegative narrowing.
- [ ] All fixture content is synthetic and contains no client or secret material.
- [ ] No file outside the exact WP02 `owned_files` patterns changed.
- [ ] JSON parsing, local reference resolution, boundary classification, and diff checks pass.
- [ ] The Activity Log records commands, case counts, validation results, and any deferred WP03 runner evidence.

## Risks and Mitigations

- **Regex mistaken for range validation**: keep overflow strings as runtime-only invalid cases.
- **Format annotation treated as semantic proof**: require format assertion plus Zig Gregorian tests.
- **Money narrowed to invoice-only behavior**: retain negative Money and defer contextual constraints.
- **Currency policy leaks into P0**: include a valid uppercase non-launch code.
- **JavaScript precision loss**: fixture values remain strings and include values above `2^53 - 1`.
- **Timestamp normalization drift**: reject offsets, variable fractions, lowercase `z`, and missing milliseconds.
- **UUID mistaken for ordering key**: fixtures validate representation only and make no temporal-order promise.
- **Fixture suite passes vacuously**: stable case IDs, per-definition counts, and required-case inventory prevent empty categories.
- **WP overlap**: do not modify contract tooling, Zig source, generated web types, API/event schemas, manifests, or mission artifacts.
- **Network-dependent resolution**: resolve the stable schema ID through a local registry only.

## Reviewer Guidance

Reviewers should reconstruct the wire contract using only the schema and fixtures,
then compare it with FR-003, NFR-004, NFR-006, NFR-010, and C-006.

Confirm specifically:

- the stable `$id` and `$defs` names are exact;
- EntityId is lowercase UUIDv7 with the correct variant;
- signed 64-bit limits are runtime-checked rather than regex-claimed;
- Money is signed and no currency allowlist was introduced;
- LocalDate semantic failures and UtcInstant exact-millisecond failures are distinct;
- digest and RequestId aliases are exercised;
- valid and invalid corpora are non-vacuous and independently understandable;
- every runtime-only invalid case first satisfies the structural schema;
- the handoff names WP03 generation/workspace-export, WP05 Zig, and WP10 web-consumer responsibilities, and records WP09 as config-only, without editing their surfaces;
- the diff contains only the three declared deliverables.

Reject the WP if a tool can pass by ignoring format assertions, runtime-only
cases, required case IDs, or the non-launch/negative-Money sentinels.

## Activity Log

> Append entries in chronological order, oldest first and newest last. Use UTC.

- 2026-07-20T06:59:16Z – system – Prompt created for WP02 canonical wire values and boundary fixtures.

### Updating Status

Status is managed through `status.events.jsonl`. Use
`spec-kitty agent tasks move-task WP02 --to <status>` instead of editing logs or
frontmatter status by hand.
- 2026-07-20T19:15:29Z – codex:gpt-5:implementer-ivan:implementer – shell_pid=1807838 – Assigned agent via action command
- 2026-07-20T19:32:37Z – codex:gpt-5:implementer-ivan:implementer – shell_pid=1807838 – Implementation commit 49a34e3 published schema plus 42 valid and 73 invalid synthetic cases (51 schema, 8 runtime, 14 schema_and_runtime). Exact Node 24.18.0/npm 11.16.0 checks: strict JSON parse; AJV 2020-12 with full date/date-time assertion; nine local ref resolutions; independent BigInt signed-i64, Gregorian 0001..9999, and exact-UTC-millisecond validation; 115 required IDs/counts/sort; negative-Money, ZZZ-open-currency, JS-precision, and five deletion-mutation sentinels; Prettier; git diff --check; verify:substrate. WP01 package/lock hashes remained unchanged. npm run contracts:check -- --focus common stopped at the expected missing tools/contracts/src/main.ts WP03 producer boundary. Governance section selectors terminology-canon and code-review-checklist were unavailable; approved mission terminology/checklist applied directly.
- 2026-07-20T19:32:51Z – codex:gpt-5:implementer-ivan:implementer – shell_pid=1807838 – Ready for review at 49a34e3: exact stable schema ID and nine defs; 42 valid plus 73 invalid synthetic cases with AJV format assertion and independent BigInt/Gregorian/UTC classification green; 115 required IDs and five mutation sentinels; signed Money and ZZZ open currency preserved; WP01 manifests/lock unchanged; only three WP02-owned files committed. WP03 contracts:check producer remains intentionally deferred.
- 2026-07-20T19:34:05Z – codex:gpt-5:reviewer-renata:reviewer – shell_pid=1807838 – Started review via action command
- 2026-07-20T19:40:50Z – user – shell_pid=1807838 – Review passed: commit 49a34e3 changes exactly three WP02 files; exact 2020-12 schema ID, nine local defs, signed int64 Money, open ZZZ currency, JS-precision strings, Gregorian/runtime and exact-UTC-millisecond boundaries pass; AJV full formats validates 42 valid, rejects 65 structural invalid, and admits exactly 8 runtime-only cases; independent semantics reject all 22 runtime-relevant invalids; 42/73 stable inventories and five deletion sentinels pass; fixtures are synthetic only, WP03 boundary is actionable, and WP01 hashes remain immutable.

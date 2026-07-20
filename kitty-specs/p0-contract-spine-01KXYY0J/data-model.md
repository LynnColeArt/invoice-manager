# P0 Contract Spine Data Model

P0 defines shared contract and infrastructure records, not invoice-manager
business entities. Billing Identity, Client, Project, Invoice, Payment,
Remittance Block, and Schedule belong to later missions.

## Shared value objects

### EntityId

- Canonical lowercase hyphenated UUIDv7 string.
- Opaque outside validation; temporal ordering is not a business guarantee.
- Equality uses canonical bytes, not case-folded or alternative spellings.

### Money

- `currency`: three uppercase ASCII letters; P1 owns allowed currencies.
- `minor_units`: canonical decimal string parsed to signed 64-bit integer.
- Invariants: checked arithmetic; identical currencies for arithmetic; no
  implicit conversion or aggregation across currencies.

### LocalDate

- Canonical `YYYY-MM-DD` string.
- Gregorian semantic validation including leap years.
- No timezone or time-of-day meaning.

### UtcInstant

- Canonical `YYYY-MM-DDTHH:mm:ss.SSSZ` string.
- Always UTC with fixed millisecond precision.
- No local offset or numeric epoch representation on the wire.

## Contract records

### ContractManifest

- `contract_id`: stable namespaced identifier.
- `owner_mission`: P0-P8 program identifier.
- `version`: semantic version.
- `state`: Draft, Frozen, Implemented, Verified, or Superseded.
- `baseline_commit`: git commit that supplied the manifest.
- `sources`: ordered relative paths and SHA-256 digests.
- `fixtures`: ordered relative paths and SHA-256 digests.
- Invariant: a frozen version is immutable; changes create a new version.

### ApiEnvelope

- Success: `data` plus `meta.request_id`.
- Failure: `error.code`, safe `error.message`, optional `error.fields`, and
  `meta.request_id`.
- Field failures contain JSON Pointer `path`, stable `code`, and safe `message`.
- Invariant: exactly one of `data` or `error` is present.

### DomainEventEnvelope

- `envelope_version`: positive integer.
- `event_id`: EntityId and consumer deduplication key.
- `event_type`: stable dotted semantic name.
- `event_version`: positive payload-schema version.
- `source`: bounded-context name.
- `aggregate`: type, EntityId, and canonical decimal-string revision.
- `occurred_at`, `recorded_at`: UtcInstant.
- `correlation_id`, `causation_id`: nullable EntityId.
- `data`: payload owned by the producing mission.
- Invariants: immutable once recorded; ordering only within one aggregate
  revision; unknown fields may be ignored but known fields are never
  reinterpreted.

### ContractFixture

- `case_id`: stable identifier within an owner/version.
- `kind`: Valid or Invalid.
- `input_path`: synthetic payload or JSONL batch.
- `expected_path`: expected canonical output or failure record.
- `contract_version`: exact consumed version.
- Invariant: contains no real client, bank, invoice, password, or secret data.

## Migration records

### MigrationDescriptor

- `id`: UUIDv7.
- `owner`: mission/domain key.
- `name`: stable descriptive slug.
- `depends_on`: zero or more migration IDs.
- `checksum`: SHA-256 of immutable migration content.
- `script_path`: owner-relative forward script.
- Invariants: no duplicate ID; dependency graph is acyclic and complete; an
  applied descriptor is never edited or deleted.

### AppliedMigration

- `id`, `owner`, and `checksum` copied from MigrationDescriptor.
- `applied_at`: UtcInstant.
- State transition: Discovered -> Applying -> Committed -> Checkpointed.
- Only Checkpointed is reported as successfully applied.
- Re-discovery with the same checksum is a no-op; a different checksum is a
  hard failure.

## Persistence boundary records

### DatabaseHandleLease

- `database_path`: canonical application-owned path.
- `state`: Closed, Opening, Ready, TransactionActive, DurabilityUnconfirmed,
  or Closing.
- Invariant: at most one owned handle and one serialized operation per path.

### DurableMutationReceipt

- `operation_id`: idempotency/deduplication key.
- `commit_state`: Committed or RolledBack.
- `checkpoint_state`: Confirmed or Unconfirmed.
- `checkpoint_error_code`: nullable stable application category.
- Invariant: success is returned only for Committed + Confirmed. An
  Unconfirmed receipt is retried at the checkpoint boundary, not by replaying
  domain writes.

## Relationships

- ContractManifest owns many ContractFixtures.
- Domain fragments consume shared value objects and contribute to one composed
  API or event-contract build artifact.
- MigrationDescriptor may depend on other descriptors and yields at most one
  AppliedMigration record.
- DatabaseHandleLease serializes migration and mutation operations.
- DurableMutationReceipt describes the observable durability outcome of one
  consequential mutation.

## Ownership boundary

P0 owns every type in this document. Later missions may consume these types and
add domain payloads or migrations, but changes to their meaning require a
versioned P0 contract update and consumer review.

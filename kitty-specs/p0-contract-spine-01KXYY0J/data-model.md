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

- `manifest_version`: canonical manifest schema version, initially `1`.
- `contract_id`: stable namespaced identifier.
- `owner_mission`: P0-P8 program identifier.
- `mission`: immutable Spec Kitty mission slug.
- `version`: semantic version.
- `state`: Draft, Frozen, Implemented, Verified, or Superseded.
- `baseline_commit`: exact program base consumed by planning, not the
  self-referential commit containing the manifest.
- `content_digest`: stable SHA-256 of RFC 8785 JCS bytes for contract ID,
  version, inputs, outputs, and integration fixtures after entries are sorted by
  their documented identity. It excludes lifecycle state, base commit,
  ownership, and itself, and remains unchanged from Frozen through Verified.
- `dependencies`: owning mission identifiers.
- `inputs`: exact consumed contract IDs, owners, versions, required states, and
  manifest digests.
- `outputs`: repository-relative paths, artifact kinds, and SHA-256 digests.
- `owned_paths`: primary mission-owned paths or globs.
- `shared_touchpoints`: paths, named steward, and coordination reason.
- `migration_strategy`: none or one owner-scoped forward-only root.
- `integration_fixtures`: valid/invalid paths and SHA-256 digests.
- Invariants: a frozen version is immutable; changes create a new version;
  non-Draft states contain no pending evidence; the runtime freeze gate proves
  normalized unique paths, actual digests, both valid and invalid fixtures,
  dependency states, and a legal lifecycle transition. Draft may advance to
  Frozen or Superseded; Frozen to Implemented or Superseded; Implemented to
  Verified or Superseded; Verified to Superseded; Superseded is terminal.
  Every dependency owner has exactly one input, inputs name no undeclared owner,
  and contract identities do not repeat or conflict.

### ModuleContribution

- `module_id`, `owner_mission`, and globally unique `mount_key`.
- owner-scoped OpenAPI fragments, event catalogs, and migration root.
- route policy with `default_access = protected` and explicit public operation
  IDs.
- Invariants: every referenced path remains within the owner's convention;
  public operation declarations agree with OpenAPI access metadata; generated
  mount and route inventories are deterministic ignored build outputs.

### EventCatalog

- owner mission and bounded-context `source`.
- one or more entries binding event type, event version, aggregate type, and
  payload schema ID.
- Invariant: a full event validates the P0 envelope, resolves exactly one
  catalog entry, and validates `data` against that payload schema.

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
- `depends_on`: zero or more migration IDs stored in ascending canonical UUID
  string order.
- `script_path`: owner-relative forward script, initially `up.sql`.
- `script_digest`: SHA-256 of exact script bytes.
- `descriptor_digest`: SHA-256 of RFC 8785 JSON Canonicalization Scheme bytes
  containing ID, owner, name, lexicographically ordered dependencies, script
  path, and script digest; it excludes itself. A committed fixture publishes
  both the canonical bytes and expected digest.
- Invariants: no duplicate ID; dependency graph is acyclic and complete; an
  applied descriptor is never edited or deleted.

### AppliedMigration

- `id`, `owner`, `descriptor_digest`, and `script_digest` copied from
  MigrationDescriptor.
- `applied_at`: UtcInstant.
- State transition: Discovered -> Applying -> Committed -> Checkpointed ->
  DirectorySynchronized.
- Only DirectorySynchronized is reported as successfully applied on Linux.
- Re-discovery with both identical digests is a no-op; a different descriptor
  or script digest is a hard failure.

## Persistence boundary records

### DatabaseHandleLease

- `database_path`: canonical application-owned path.
- `state`: Closed, Opening, Ready, TransactionActive, DurabilityUnconfirmed,
  Checkpointed, DirectorySynchronized, or Closing.
- Invariant: at most one owned handle and one serialized operation per path.

### DurableMutationReceipt

- `operation_id`: idempotency/deduplication key.
- `commit_state`: Committed or RolledBack.
- `checkpoint_state`: Confirmed or Unconfirmed.
- `directory_sync_state`: Confirmed, Unconfirmed, or NotAttempted.
- `checkpoint_error_code`: nullable stable application category.
- `directory_sync_error_code`: nullable stable application category.
- Invariant: success is returned only for Committed + checkpoint Confirmed +
  directory sync Confirmed on Linux. An Unconfirmed receipt is retried at the
  persistence boundary, not by replaying domain writes.

## Relationships

- ContractManifest owns immutable content identity plus output and
  integration-fixture evidence and references exact consumed content digests.
- ModuleContribution points to owner OpenAPI fragments, EventCatalog records,
  and a migration root.
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

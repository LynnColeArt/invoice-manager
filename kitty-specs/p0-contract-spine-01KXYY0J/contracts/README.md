# P0 Draft Contracts

These planning contracts publish version `0.1.0-draft.1` for P1-P4
specification and planning. Draft status does not authorize downstream
implementation.

Files:

- `common-v1.schema.json`: canonical shared wire values.
- `api-v1.openapi.yaml`: base HTTP health and response/error contract.
- `event-envelope-v1.schema.json`: immutable event/JSONL record envelope.
- `migration-manifest-v1.schema.json`: owner-scoped migration descriptor.
- `contract-manifest-v1.schema.json`: contract lifecycle and digest record.
- `p0-contract-manifest.json`: P0's current Draft publication.

Implementation must relocate the schemas to the repository-level `contracts/`
layout described by `plan.md`, add canonical valid/invalid fixtures, and record
real SHA-256 digests before promoting them to Frozen.

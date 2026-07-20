# P0 Draft Contracts

These planning contracts publish version `0.1.0-draft.1` for P1-P4
specification and planning. Draft status does not authorize downstream
implementation.

Files:

- `common-v1.schema.json`: canonical shared wire values.
- `api-v1.openapi.yaml`: base HTTP health and response/error contract.
- `event-envelope-v1.schema.json`: immutable event/JSONL record envelope.
- `event-catalog-v1.schema.json`: owner event discriminators and payload binding.
- `module-contribution-v1.schema.json`: convention-scanned API, event,
  migration, mount, and route-access contribution.
- `migration-manifest-v1.schema.json`: owner-scoped migration descriptor.
- `contract-manifest-v1.schema.json`: canonical swarm metadata, lifecycle, and
  digest record.
- `p0-contract-manifest.json`: P0's current Draft publication.

Implementation must relocate the schemas to the repository-level `contracts/`
layout described by `plan.md`, add canonical valid/invalid fixtures, and record
real SHA-256 digests before promoting them to Frozen. P1-P4 Draft schemas must
resolve common values from the stable P0 schema identifier, and every mission
manifest must validate against the canonical P0 manifest schema.

The runtime freeze gate supplements JSON Schema by checking normalized unique
repository paths, actual file digests, at least one valid and invalid fixture,
exact dependency manifest digests and states, and legal lifecycle transitions.

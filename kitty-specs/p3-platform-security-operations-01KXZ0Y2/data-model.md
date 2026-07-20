# Data Model: P3 Platform Security and Operations

## Administrator

- `id: EntityId`.
- immutable normalized lowercase-ASCII `username`.
- libsodium encoded Argon2id `password_hash`.
- canonical `credential_version`, `failed_login_count`.
- optional `login_blocked_until`.
- created/password-changed instants.

Zig enforces singleton cardinality. Reset increments credential version and
revokes every session in the same durable operation.

## Session

- `id`, `administrator_id`.
- 32-byte token digest and 32-byte CSRF digest; raw values never persist.
- credential-version snapshot.
- created/last-seen, idle-expiry, absolute-expiry instants.
- optional revocation instant and stable reason.

Creation/revocation is commit/checkpoint durable. Last-seen persistence may be
batched without weakening the defined idle upper bound.

## SecurityAuditRecord

- ID, occurrence instant, optional request ID.
- allowlisted category/action/outcome/safe reason.
- optional administrator ID and non-reversible truncated correlation value.
- schema-controlled detail object.

Repository interfaces expose append/query only; update/delete are unavailable.

## PlatformState

- singleton restore/security epoch.
- last successful restore provenance and manifest digest.
- application and consumed-contract versions.

## BackupManifestV1

- format, backup ID, created instant.
- application version/source commit and P0/P3 contract versions.
- sorted applied migration IDs/owners/checksums.
- sorted entries: safe relative path, regular-file type, mode, byte count, SHA-256.
- optional P0 checkpoint identity/digest.
- `complete: true`, present only in the manifest written last.

TLS keys and deployment secrets are excluded. Database, assets, issued invoices,
and audit roots are registered opaque persistent content.

## ExposureProfile

- Development: insecure HTTP only on loopback with disposable/synthetic data.
- LoopbackProduction: HTTPS on explicit `127.0.0.1` and `::1` mappings.
- PrivateNetwork: HTTPS on one explicit private/VPN host address.

There is no Public profile. Wildcards, direct API/web ports, invalid origin/TLS,
or unsafe proxy trust produce startup failure.

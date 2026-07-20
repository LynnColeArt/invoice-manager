# Research: P3 Platform Security and Operations

## Scope and Gate

P3 consumes P0 `0.1.0-draft.1` for planning only. Implementation waits for a
Frozen, merged P0 durable-write, event, migration, value, and one-handle contract.

## Decision 1: Single Local Administrator

The system supports exactly one administrator. Bootstrap, password reset,
session revocation, unlock, backup, verification, and restore are offline Zig CLI
commands requiring exclusive storage ownership. There is no web bootstrap or
remote recovery route. Host filesystem authority is the recovery root of trust.

## Decision 2: Password and Session Defaults

Use a pinned libsodium password-hashing adapter (Argon2id), never a handwritten
password algorithm. Passwords are 15–128 Unicode code points, NFC-normalized,
not trimmed/case-folded, accept spaces/paste, reject a pinned common/compromised
blocklist, and have no arbitrary composition or periodic-change policy.

Sessions are server-side opaque 256-bit tokens; only digests persist. The
production cookie is `__Host-invoice_session`, Secure, HttpOnly, SameSite=Strict,
Path=/, no Domain. Idle expiry is 30 minutes and absolute expiry eight hours.

Sources: https://pages.nist.gov/800-63-4/sp800-63b.html and
https://doc.libsodium.org/password_hashing

## Decision 3: Default-Deny and Stateful CSRF

Zig wraps the fully composed route table. Only health/login are public. Unsafe
same-origin JSON requests require the opaque session, a per-session synchronizer
token, exact configured Origin (Referer only as fallback), and conservative Fetch
Metadata validation. SameSite is defense in depth, not the primary control.

Sources:
https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
and
https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html

## Decision 4: Private-by-Default Compose

Production supports explicit loopback binds or one private/VPN address. Only a
pinned nginx proxy publishes a port; web and API are internal. Wildcard/public
binds, direct API/web publication, missing TLS, and untrusted forwarding chains
are startup failures. Require Docker Engine 28+ because Docker documents older
localhost-publishing behavior.

Containers use numeric non-root users, read-only roots, all capabilities dropped,
no-new-privileges, bounded tmpfs, health checks, no Docker socket, and digest-
pinned images. Production never silently falls back to HTTP.

Sources: https://docs.docker.com/engine/network/port-publishing/ and
https://docs.docker.com/reference/compose-file/services/

## Decision 5: Offline Backup over Online Complexity

Brief downtime is accepted. Backup takes exclusive ownership, opens through the
P0 seam, validates migrations, checkpoints, closes, then copies the database and
registered artifact roots. This avoids a competing handle and mixed-time
database/artifact capture.

Every regular file is listed by safe relative path, mode, length, and SHA-256.
The complete manifest is written/synced last, then the partial directory is
renamed and the destination parent synced. Backup destinations are separate and
non-nested. Automatic retention deletion and built-in encryption are deferred;
operators are told to keep protected encrypted off-host copies.

## Decision 6: Fresh-Target Restore

Restore verifies format, paths, types, modes, sizes, digests, contracts, and
migrations before any target mutation. It rejects symlinks/special files and
materializes only into an empty staging/data root. It opens the restored database
through real ShovelerDB, revokes sessions/increments the security epoch, records
provenance, checkpoints, closes/reopens, then publishes the new root. It never
deletes or overwrites the current root in place.

NIST emphasizes that backups must be maintained and tested, not merely created:
https://csrc.nist.gov/pubs/other/2020/04/24/protecting-data-from-ransomware-and-other-data-los/final

## Decision 7: Redacted Operational Evidence

Logs and append-only audit records use allowlisted categories/outcomes/safe codes.
They never include passwords, session/CSRF tokens, private keys, bank details,
invoice/PDF contents, or absolute internal paths. Canary scans are acceptance
evidence, not just documentation.

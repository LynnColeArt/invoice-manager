# Implementation Plan: P3 Platform Security and Operations

**Branch**: `feat/p3-platform-security-operations` | **Date**: 2026-07-19 | **Spec**: [spec.md](spec.md)  
**Contract state**: `0.1.0-draft.1` (planning only)  
**Consumes**: P0 `0.1.0-draft.1`  
**Status**: Planned; implementation blocked until P0 contracts are Frozen and merged

## Summary

Create the narrow security and operations envelope for one privately deployed
administrator: offline bootstrap/recovery, Argon2id credentials, opaque durable
sessions, default-deny Zig authorization, synchronizer-token CSRF, hardened
HTTPS Compose deployment, explicit persistent-path permissions, graceful
checkpointed shutdown, offline manifest backups, and verified fresh-target
restore. P3 owns no business-domain behavior.

## Technical Context

**Language/Version**: Zig 0.16.0; TypeScript 6.0.3; Node.js 24.18.0 LTS  
**Primary Dependencies**: Next.js 16.2.10; React 19.2.7; P0
`0.1.0-draft.1`; ShovelerDB commit
`fc7539a3874293540a4de6d228b3ea670a8ca2e8`; pinned libsodium Argon2id;
Docker Engine 28+; Docker Compose; digest-pinned nginx  
**Storage**: One exclusive P0-serialized ShovelerDB handle and registered private
artifact roots; offline backup destination is separate and non-nested  
**Testing**: Zig unit/coverage, black-box auth/CSRF, checkpoint-close-reopen,
route inventory, Compose inspection, permission/secret canaries, crash injection,
real backup/verify/fresh-restore loops, and clean-host runbooks  
**Target Platform**: Linux x86_64 Docker Compose; loopback or explicit private/VPN
HTTPS production exposure  
**Project Type**: One repository with Zig API/CLI, Next.js web, nginx proxy, and
operator documentation  
**Performance Goals**: Argon2 under one second after calibration; 1 GiB verify
and restore within 30 minutes; clean private deploy within 20 minutes  
**Constraints**: GPL-2.0-only, one admin/process/database/handle, no public profile,
no online backup, no in-place restore, no secrets in argv/env/repository  
**Scale/Scope**: One internal organization and administrator; one host and one
application stack

## Charter Check

| Rule | Plan evidence | Result |
| --- | --- | --- |
| Zig authority | Auth, CSRF, CLI, readiness, persistence, backup, restore, and route gate are Zig-owned. | Pass |
| P0 durability | Security mutations and shutdown acknowledge only after commit/checkpoint. | Pass |
| One ShovelerDB handle | Network service or offline command exclusively owns the path, never both. | Pass |
| Privacy | Secret/business canaries scan logs, errors, argv, environment, Compose, and manifests. | Pass |
| Test-first critical paths | Auth/CSRF/path/backup/crash/restore branches start red-first. | Pass |
| 90% Zig coverage | Platform security/durability code and every stable failure branch are gated. | Pass |
| GPL-2.0-only | Libraries, images, nginx, blocklist, and notices pass compatibility review. | Pass |
| Concurrent ownership | P3 adds namespaced modules/contracts/migrations; steward composes shared router/roots. | Pass |

No charter exception is planned.

## Owned Structure

```text
contracts/api/v1/fragments/p3/
contracts/events/v1/payloads/p3/
contracts/platform/v1/p3/
contracts/fixtures/p3/v1/
contracts/manifests/p3.json
services/api/migrations/p3/<uuidv7>/
services/api/src/domains/platform_security/
services/api/src/platform/auth/
services/api/src/platform/backup_restore/
services/api/src/cli/
services/api/tests/platform_security/
apps/web/src/features/session/
deploy/p3/
docs/operations/
```

Shared router wrapping, aggregate OpenAPI security defaults, generated clients,
root build/lock/CI, global Next entry points, and final P2/P5 image composition
are integration-steward changes.

## Runtime Architecture

```text
Browser -- HTTPS --> nginx (only published container)
                         |                  |
                         v                  v
                    Next.js web        Zig /api/v1
                                            |
                                  outer auth + CSRF gate
                                            |
                                  P0 serialized seam
                                            |
                                    private data root
```

The proxy strips inbound forwarding headers and supplies its own. One configured
public origin drives CSRF checks. Credentialed CORS is disabled. Web redirects
are convenience only; direct API calls cross the Zig gate.

## Authentication and Recovery Design

The offline CLI requires the network stack down and acquires the exclusive P0
data-path lease. Bootstrap reads the password twice from a terminal and creates
the sole administrator. Reset replaces the Argon2id record, increments credential
version, revokes sessions, appends a safe audit record, checkpoints, closes, and
reopens before success. Unlock clears throttle state without changing credentials.

Passwords are NFC-normalized but never trimmed/case-folded. The adapter uses a
pinned libsodium encoded Argon2id record with unique salt; its floor is 19 MiB,
two iterations, one lane, calibrated upward while staying under one second.
Unknown usernames execute a dummy verify path. Failures delay after five; twenty
requires offline unlock.

## Session and CSRF Design

A CSPRNG produces separate 256-bit session and CSRF secrets. Only digests persist.
The server checks idle (30 minutes), absolute (eight hours), credential version,
revocation, and restore/security epoch. Logout revokes durably before clearing
the `__Host-invoice_session` cookie.

Unsafe browser requests require:

1. valid session;
2. matching in-memory `X-CSRF-Token` synchronizer value;
3. exact configured Origin, with Referer only as defined fallback;
4. `Sec-Fetch-Site: same-origin` under the conservative policy;
5. expected JSON content type.

Login is origin/Fetch-Metadata protected without a session token. `GET /session`
returns session state plus a CSRF token after reload. Safe methods never mutate.

## Route and Response Security

The P3 gate wraps the fully composed route table. Health and login are the only
public API operations. A generated non-vacuous inventory fails if an operation
bypasses policy. Sensitive responses use `Cache-Control: no-store`. Production
headers include a nonce-based CSP, `frame-ancestors 'none'`, `object-src 'none'`,
`base-uri 'self'`, nosniff, restrictive referrer policy, and HSTS.

## Deployment and Filesystem Design

Production profiles:

- LoopbackProduction explicitly maps `127.0.0.1` and `::1` to nginx HTTPS.
- PrivateNetwork maps exactly one validated private/VPN address.
- Development allows conspicuous loopback HTTP with disposable synthetic data.

There is no Public profile. Wildcards, direct web/API ports, missing HTTPS origin
or TLS files, unsafe forwarded-host trust, invalid owner/mode, corruption, or
migration failure block readiness.

All production containers use numeric non-root identities, read-only roots,
`cap_drop: ALL`, no-new-privileges, bounded tmpfs, health checks, private internal
network, no Docker socket/privilege/host network/devices/PID namespace, and
digest-pinned images. Only the API mounts the writable persistent root; only nginx
reads the TLS secret.

Persistent directories are 0700 and sensitive regular files 0600. Installation
preflight creates and validates host paths with long bind syntax and no automatic
host-path creation. P3 registers database, assets, invoices, audit, locks, and
runtime roots; domain owners define their contents.

## Graceful Shutdown

SIGTERM stops admission, waits for or rolls back in-flight work, handles the P0
committed-but-uncheckpointed state explicitly, checkpoints committed state,
closes the sole handle, then exits. Tests inject termination during idle, active
transaction, commit-before-checkpoint, and backup states and assert no acknowledged
data loss.

## Backup Protocol

Backup is an offline one-shot command:

1. reject nested/unsafe destination and acquire exclusive data-path ownership;
2. open through P0, validate migrations, checkpoint, and close;
3. copy registered regular-file roots to `.partial-<backup-id>` while rejecting
   traversal, absolute names, symlinks, devices, sockets, and hard-link surprises;
4. sync copied files/directories;
5. write and sync the sorted `BackupManifestV1` last;
6. verify the staged tree, rename to final name, and sync destination parent;
7. reopen source, append safe `platform.backup_created.v1`, checkpoint, close.

The destination is a separate host path. P3 performs no automatic deletion and
no built-in encryption. Documentation recommends 7 daily, 4 weekly, 12 monthly,
with at least one encrypted off-host copy. Backups remain sensitive plaintext.

## Restore Protocol

1. Require the service stack down and a fresh empty target.
2. Before target mutation, validate manifest/schema/version, every safe path,
   type/mode/size/digest, P0/P3 compatibility, and migration compatibility.
3. Materialize into a staging directory; never touch the active root.
4. Open/close the restored database through real ShovelerDB with automatic
   migrations disabled.
5. Revoke all sessions, increment security/restore epoch, record provenance,
   checkpoint, close, and reopen.
6. Atomically publish the new root; normal startup may apply only known forward
   migrations; run health and fixture reconciliation.

Restore rejects partial/corrupt/future/unsafe input and never offers downgrade or
in-place overwrite.

## API, Event, and Migration Integration

P3 adds `POST/GET/DELETE /api/v1/session` plus optional reauthentication. Login is
public but origin-protected; all others require auth. Backup/restore are never HTTP
mutations.

P3 events use the P0 envelope: administrator bootstrapped, credential reset,
sessions revoked, backup created, restore completed. Payloads contain IDs,
timestamps, safe reasons/counts, and manifest digests only. Login attempts remain
local append-only security audit records.

Owner `p3` migrations create administrator/throttle, sessions, security audit,
and platform state. UUIDv7 descriptors declare dependencies/checksums and never
edit a global registry.

## Verification Strategy

- Argon2 known/error/calibration, password policy, dummy verification, throttle.
- Session entropy/digest, expiry, credential epoch, close/reopen, cookie headers.
- Route-inventory and every unsafe CSRF origin/token/metadata combination.
- Compose render/inspection for bind, TLS, proxy, user, caps, roots, networks,
  secrets, health, and image pins.
- Permission/symlink/owner/type and secret-canary negative suites.
- Backup crash injection at every stage plus manifest/path/digest tamper tests.
- Twenty real ShovelerDB fresh-restore cycles including later opaque artifact roots.
- SIGTERM durability model and clean-host deploy/restore runbooks.
- GPL/license/vulnerability/SBOM evidence for distributed dependencies/images.

## Contract Lifecycle

P3 `0.1.0-draft.1` permits concurrent planning only. Before implementation, the
integration steward records exact Frozen P0 digests. P3 promotion requires real
auth/CSRF, route, Compose, shutdown, backup/restore, canary, and runbook evidence.
P8 later verifies final P2/P5 artifact roots and combined release images; this
does not make P3 own their domain semantics.

## Implementation Concerns

| Concern | Scope | Depends on | Parallel opportunity |
| --- | --- | --- | --- |
| IC-01 | P3 contracts, threat model, negative fixtures | P0 Draft | Opens all lanes |
| IC-02 | libsodium/password/entropy adapter spike | IC-01 | Parallel with deployment and backup format |
| IC-03 | Compose topology, exposure, TLS, permission preflight | IC-01 | Parallel with auth |
| IC-04 | Backup manifest and path-safety model | IC-01 | Synthetic-tree tests immediately |
| IC-05 | Auth/session/audit migrations and repositories | IC-02; P0 Frozen | Parallel repository units |
| IC-06 | Offline bootstrap/reset/revoke/unlock CLI | IC-05 | Independent of web |
| IC-07 | Login/session/default-deny middleware | IC-05 | Parallel with CLI |
| IC-08 | CSRF, web session UX, security headers | IC-07 | Web/API-owned paths |
| IC-09 | Container hardening, TLS, permissions, shutdown | IC-03 | Operational lane |
| IC-10 | Offline backup publisher and verifier | IC-04, IC-09, P0 seam | Crash tests parallelize |
| IC-11 | Fresh-target restore and restored-session invalidation | IC-05, IC-10 | Negative fixtures parallelize |
| IC-12 | Full acceptance, clean-host drills, runbooks, handoff | IC-06–IC-11 | Integration lane |

These are concerns, not work packages. Task generation waits for the Wave A Draft
review.

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Compose exposes services | Explicit binds, resolved-model inspection, wildcard/direct-port rejection. |
| Custom crypto defects | Pinned libsodium high-level adapter and known/error vectors. |
| New route bypasses auth | Outer default-deny gate and generated inventory. |
| SameSite mistaken for CSRF | Synchronizer token, exact origin, Fetch Metadata, no safe-method mutations. |
| Proxy spoofing changes origin | Strip/recreate forwarding headers; configured origin is authority. |
| Backup captures mixed state | Offline lease and checkpoint/close before copying all roots. |
| Partial backup looks valid | Partial name, manifest last, verify, atomic rename, directory sync. |
| Malicious backup escapes root | Safe relative paths and special-file/link rejection before mutation. |
| Restored sessions remain valid | Mandatory epoch/revocation and checkpoint before readiness. |
| Plaintext backup leaks | Restrictive modes and explicit encrypted/off-host operator guidance. |
| Future artifact types are unknown | Registered roots copied as opaque digest-addressed bytes. |
| Shared release files collide | P3 publishes modules/fragments; steward integrates shared surfaces. |

## Planning Exit Criteria

- Auth/session/CSRF/deployment/backup/restore decisions are mutually consistent.
- Draft backup schema and manifest parse and record the P0 dependency.
- Offline/exclusive/fresh-target invariants are explicit.
- Secret and durability claims have executable evidence plans.
- No unresolved marker or charter exception remains.
- Mission is parked before task generation pending cross-mission Draft review.


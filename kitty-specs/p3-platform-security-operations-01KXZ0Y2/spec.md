# Mission Specification: P3 Platform Security and Operations

**Mission Branch**: `feat/p3-platform-security-operations`  
**Created**: 2026-07-19  
**Status**: Ready for Planning  
**Input**: Secure one private single-administrator deployment with durable
sessions, recovery, shutdown, backup, and verified restore.

## Intent Summary

P3 puts a private-by-default operational envelope around the Zig service. A
local operator bootstraps the sole administrator offline, authenticates through
an opaque server-side session, deploys behind one HTTPS reverse proxy, and can
checkpoint, back up, verify, and restore the complete installation without a
second ShovelerDB handle or destructive in-place recovery.

P3 is not a general identity platform and is not a public-internet hardening
mission. It owns no business-domain behavior.

## User Scenarios & Testing

### User Story 1 - Bootstrap and Recover Offline (Priority: P1)

As the operator, I can create or recover the sole administrator using host-level
access without opening a remote account-creation or password-reset path.

**Independent Test**: Bootstrap, repeat bootstrap, reset password, unlock, and
attempt each command while the service owns the database.

**Acceptance Scenarios**:

1. **Given** an empty store and exclusive lease, **When** bootstrap reads a
   password twice from the terminal, **Then** exactly one administrator is
   committed and checkpointed before readiness.
2. **Given** an administrator exists, **When** bootstrap repeats, **Then** no
   mutation occurs.
3. **Given** the service owns the data path, **When** an offline command starts,
   **Then** it refuses rather than opening a competing handle.
4. **Given** password reset, **When** it succeeds, **Then** credential version
   increments, all sessions revoke, an audit record persists, and no browser
   session is created.

---

### User Story 2 - Use a Secure Session (Priority: P1)

As the administrator, I can log in, use protected routes, expire, and log out
without exposing reusable credentials.

**Independent Test**: Exercise valid/invalid credentials, idle/absolute expiry,
logout, revoked/stale tokens, and checkpoint-close-reopen persistence.

**Acceptance Scenarios**:

1. **Given** valid credentials, **When** login succeeds, **Then** a 256-bit opaque
   session is created, only its digest persists, and the production cookie is
   `Secure`, `HttpOnly`, `SameSite=Strict`, `Path=/`, with no Domain.
2. **Given** unknown or wrong credentials, **When** login fails, **Then** the
   public response is indistinguishable while safe internal reasons differ.
3. **Given** 30 minutes idle or eight hours absolute, **When** a protected request
   arrives, **Then** the server rejects the session.
4. **Given** logout, **When** acknowledged, **Then** revocation has checkpointed
   and browser state is cleared.

---

### User Story 3 - Default-Deny Every Route and Unsafe Request (Priority: P1)

As the owner, I can trust that new routes are protected automatically and that
cross-site requests cannot mutate application state.

**Independent Test**: Generate the composed route inventory and attack every
unsafe operation with missing/mismatched token, origin, and Fetch Metadata.

**Acceptance Scenarios**:

1. **Given** the composed router, **When** inventoried, **Then** only health and
   login are public and every other operation crosses the Zig auth gate.
2. **Given** an unsafe method, **When** session, CSRF token, exact origin, or
   same-origin Fetch Metadata is absent/invalid, **Then** dispatch is rejected.
3. **Given** a newly added route without annotation, **When** tested, **Then** it
   is protected by default.
4. **Given** `GET`, `HEAD`, or `OPTIONS`, **When** invoked, **Then** no business or
   security state mutates.

---

### User Story 4 - Deploy Privately with HTTPS (Priority: P1)

As the operator, I can run a hardened Compose deployment without accidentally
publishing the API or web service.

**Independent Test**: Render and inspect development, loopback-production, and
private-network Compose profiles including every invalid bind/TLS/permission case.

**Acceptance Scenarios**:

1. **Given** production defaults, **When** Compose resolves, **Then** only nginx
   publishes explicit IPv4/IPv6 loopback ports.
2. **Given** a private/VPN profile, **When** configured, **Then** one explicit
   private address is accepted; wildcard/direct API/web publication is rejected.
3. **Given** missing HTTPS origin/certificate/key, **When** production starts,
   **Then** readiness fails without fallback.
4. **Given** running containers, **When** inspected, **Then** they are non-root,
   read-only, capability-free, no-new-privileges, private-networked, and have no
   Docker socket.

---

### User Story 5 - Back Up and Restore Safely (Priority: P1)

As the operator, I can create a complete offline backup and restore it into a
fresh target with proof that records and artifacts survived.

**Independent Test**: Run 20 checkpoint/backup/verify/fresh-restore/reopen cycles
and inject corruption or crashes at every publication phase.

**Acceptance Scenarios**:

1. **Given** exclusive storage ownership, **When** backup runs, **Then** it
   checkpoints/closes before copying known data/artifact roots.
2. **Given** an interrupted backup, **When** inspected, **Then** it is only a
   non-restorable partial tree; the manifest is written last before final rename.
3. **Given** traversal, symlink, special file, unknown format, future migration,
   missing file, checksum drift, or non-empty target, **When** restore verifies,
   **Then** no target mutation begins.
4. **Given** a valid backup, **When** restored to a fresh root, **Then** the real
   database reopens, all digests match, restored sessions revoke, and provenance
   checkpoints before readiness.

---

### User Story 6 - Diagnose Without Disclosure (Priority: P2)

As the operator, I can distinguish startup/auth/backup/restore failures through
safe codes and runbooks without secrets or business data entering logs.

**Independent Test**: Seed password, token, CSRF, key, bank, PDF, and path
canaries and scan every log/error/argv/environment/manifest output.

### Edge Cases

- No administrator exists when the network process starts.
- Argon2 parameters in an older hash need verification/upgrade.
- Unknown username and wrong password take distinguishable paths internally.
- CSRF token is valid but origin or Fetch Metadata is cross-site.
- Proxy forwards attacker-controlled forwarding headers.
- SIGTERM occurs during a transaction, after commit before checkpoint, or backup.
- Backup target is nested in the live root or contains hard-link surprises.
- Restore is valid structurally but contains future migration IDs.
- A restored session token would otherwise remain valid.
- IPv6 wildcard publication slips past an IPv4-only bind check.

## Requirements

### Functional Requirements

| ID | Title | User Story | Priority | Status |
| --- | --- | --- | --- | --- |
| FR-001 | Offline bootstrap | As the operator, I can create exactly one administrator from a terminal under exclusive storage ownership. | High | Approved |
| FR-002 | Password policy | As the administrator, I can use a 15–128 code-point NFC password with spaces/paste and no composition/periodic-change rule; common/compromised values are blocked. | High | Approved |
| FR-003 | Argon2id adapter | As the owner, passwords are hashed by a pinned libsodium Argon2id interface with unique salt and encoded parameters. | High | Approved |
| FR-004 | Opaque session | As the administrator, login creates at least 256 CSPRNG bits and persists only token/CSRF digests. | High | Approved |
| FR-005 | Production cookie | As the administrator, production uses only `__Host-invoice_session` with Secure/HttpOnly/Strict/Path attributes. | High | Approved |
| FR-006 | Session invalidation | As the owner, idle, absolute, logout, credential-version, restore, and explicit revocation are enforced server-side. | High | Approved |
| FR-007 | Generic auth failure | As the owner, unknown/wrong credentials share one public response and a dummy verification path. | High | Approved |
| FR-008 | Persistent throttle | As the owner, failures progressively delay after five and require offline unlock at twenty. | High | Approved |
| FR-009 | Durable security mutations | As the owner, session create/revoke and credential changes acknowledge only after P0 commit/checkpoint. | High | Approved |
| FR-010 | Default-deny authorization | As the owner, every route is protected in Zig unless it is health or login. | High | Approved |
| FR-011 | Stateful CSRF | As the owner, every unsafe browser request needs session token, synchronizer token, exact configured origin, and acceptable Fetch Metadata. | High | Approved |
| FR-012 | Same-origin API | As the owner, credentialed CORS is disabled and safe methods never mutate. | High | Approved |
| FR-013 | Security headers | As the owner, sensitive responses use no-store and production applies CSP/frame/object/base/nosniff/referrer/HSTS controls. | High | Approved |
| FR-014 | Offline recovery CLI | As the operator, I can reset password, revoke sessions, unlock, back up, verify, and restore without argv/environment secrets. | High | Approved |
| FR-015 | Append-only audit | As the operator, bootstrap/auth/credential/session/backup/restore outcomes have schema-allowlisted, redacted audit records. | High | Approved |
| FR-016 | Readiness preflight | As the operator, invalid origin/bind/proxy/TLS/storage/permissions/migration/bootstrap state blocks readiness. | High | Approved |
| FR-017 | Private exposure | As the operator, production defaults to explicit loopback and optionally one private/VPN address; wildcard/public exposure is unsupported. | High | Approved |
| FR-018 | Hardened Compose | As the operator, nginx alone publishes; all containers are non-root, read-only, cap-dropped, no-new-privileges, bounded, pinned, and private-networked. | High | Approved |
| FR-019 | Filesystem contract | As the operator, persistent dirs are 0700 and sensitive files 0600; symlinks/unexpected owners/types are rejected. | High | Approved |
| FR-020 | Graceful shutdown | As the owner, SIGTERM stops admission, resolves active work, checkpoints committed state, closes the handle, then exits. | High | Approved |
| FR-021 | Checkpointed backup | As the operator, offline backup checkpoints/closes and copies the database plus registered artifact roots under an exclusive lease. | High | Approved |
| FR-022 | Backup manifest | As the operator, every regular file has sorted path/type/mode/length/SHA-256 and migration identities in a versioned manifest written last. | High | Approved |
| FR-023 | Atomic publication | As the operator, backup stages under a partial name, syncs files/directories, verifies, renames, and syncs the parent. | High | Approved |
| FR-024 | Safe destination | As the operator, backup destination is separate and non-nested; special files/symlinks/hard-link surprises are rejected. | High | Approved |
| FR-025 | Read-only verification | As the operator, I can verify the complete manifest without changing live state. | High | Approved |
| FR-026 | Fresh-target restore | As the operator, restore never deletes/overwrites the current root and materializes only into an empty target. | High | Approved |
| FR-027 | Pre-mutation restore gate | As the operator, all format/path/type/size/digest/migration checks finish before target mutation. | High | Approved |
| FR-028 | Restored session revocation | As the operator, restore revokes sessions and records provenance before readiness. | High | Approved |
| FR-029 | Contract fixtures | As a consumer, I receive additive auth/session/backup/deployment schemas and synthetic valid/invalid fixtures. | High | Approved |
| FR-030 | Operator runbooks | As the operator, clean deploy, shutdown, backup, verify, restore drill, reset, unlock, certificate, and upgrade procedures are executable. | High | Approved |

### Non-Functional Requirements

| ID | Title | Requirement | Category | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| NFR-001 | Security coverage | P3 Zig code maintains at least 90% coverage and covers every security/durability branch. | Testability | High | Approved |
| NFR-002 | Token entropy | Session and CSRF secrets contain at least 256 CSPRNG bits. | Security | High | Approved |
| NFR-003 | Argon2 floor | Parameters never fall below 19 MiB, two iterations, one lane and calibrate below one second. | Security | High | Approved |
| NFR-004 | Session windows | Idle timeout is 30 minutes; absolute timeout is eight hours. | Security | High | Approved |
| NFR-005 | Route protection proof | 100% of non-public composed operations require authorization. | Security | High | Approved |
| NFR-006 | CSRF proof | 100% of missing/mismatched/cross-site/expired unsafe cases reject before dispatch. | Security | High | Approved |
| NFR-007 | Secret absence | Zero password/token/CSRF/key/bank/PDF/path canaries appear in outputs, argv, environment, or rendered Compose. | Privacy | High | Approved |
| NFR-008 | Container hardening | Production containers run non-root with read-only roots, zero ambient capabilities, no-new-privileges, and one published proxy. | Hardening | High | Approved |
| NFR-009 | Backup integrity | 100% of completed manifest entries verify by SHA-256 before success. | Integrity | High | Approved |
| NFR-010 | Crash-safe publication | Injection at every backup phase leaves a prior complete backup or invalid partial, never false completion. | Reliability | High | Approved |
| NFR-011 | Restore safety | 100% of restore checks complete before any target mutation. | Safety | High | Approved |
| NFR-012 | Recovery target | A representative 1 GiB install verifies/restores within 30 minutes on the reference host. | Recoverability | Medium | Approved |
| NFR-013 | Repeated recovery | Twenty backup/restore/reopen cycles preserve all fixture records and artifact digests. | Durability | High | Approved |
| NFR-014 | Shutdown durability | SIGTERM cases produce zero acknowledged data loss. | Reliability | High | Approved |
| NFR-015 | Clean-host operation | A clean Linux host reaches healthy private deployment within 20 minutes using published instructions. | Operability | Medium | Approved |
| NFR-016 | No silent fallback | Production has zero fallback for TLS, binds, secrets, permissions, corruption, or migrations. | Safety | High | Approved |
| NFR-017 | Compliance | Runtime images/libraries/notices pass GPL-2.0-only compatibility and vulnerability gates. | Compliance | High | Approved |

### Constraints

| ID | Title | Constraint | Category | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| C-001 | Draft gate | P3 plans against P0 `0.1.0-draft.1` but implementation waits for Frozen/merged evidence. | Dependency | High | Approved |
| C-002 | Zig security authority | Authentication, authorization, CSRF, persistence, CLI, backup, and restore are Zig-owned. | Architecture | High | Approved |
| C-003 | Web not boundary | Next.js redirects/rendering are usability only and never authorize. | Security | High | Approved |
| C-004 | One-handle system | One organization, administrator, service process, database path, and ShovelerDB handle. | Scope | High | Approved |
| C-005 | Reference platform | Linux x86_64 Docker Compose with Docker Engine 28+ is the production reference. | Platform | High | Approved |
| C-006 | Private only | Loopback or explicit private/VPN production access only; direct public internet and wildcards are unsupported. | Security | High | Approved |
| C-007 | HTTPS production | Production sessions require HTTPS and Secure cookie semantics. | Security | High | Approved |
| C-008 | Secret handling | Secrets are file-mounted or terminal-entered, never committed, public-prefixed, argv, or Compose environment values. | Security | High | Approved |
| C-009 | Backup sensitivity | Backups exclude TLS/deployment secrets but remain sensitive plaintext business records requiring protected/off-host storage. | Privacy | High | Approved |
| C-010 | Offline backup | Backup/restore require exclusive P0 storage ownership and never use a concurrent handle. | Durability | High | Approved |
| C-011 | Fresh restore only | Restore never overwrites the active root in place. | Safety | High | Approved |
| C-012 | Owner-scoped paths | P3 owns platform/session/deployment/backup paths and p3 fragments/migrations; shared router/root/CI use the steward. | Delivery | High | Approved |
| C-013 | GPL distribution | Distributed code and runtime dependencies remain GPL-2.0-only compatible. | Compliance | High | Approved |

### Key Entities

- **Administrator**: Sole immutable username, Argon2id record, credential version, and persistent throttle state.
- **Session**: Server-side token/CSRF digests, credential version, expiry, and revocation facts.
- **SecurityAuditRecord**: Append-only schema-controlled security outcome with no secret or sensitive payload.
- **PlatformState**: Restore/security epoch and minimal operational metadata.
- **BackupManifestV1**: Complete sorted inventory, migration set, application/contract versions, and file digests.
- **ExposureProfile**: Development, LoopbackProduction, or PrivateNetwork with exact origin/bind/TLS validation.

## Success Criteria

- **SC-001**: Bootstrap/login/protected access/CSRF/expiry/logout/reset/unlock and
  restored-session revocation pass black-box and close/reopen tests.
- **SC-002**: The composed production model publishes nginx only and rejects
  wildcard, direct service, missing TLS, and invalid permission configurations.
- **SC-003**: Twenty real backup/verify/fresh-restore/reopen cycles preserve every
  synthetic record and artifact digest.
- **SC-004**: Corrupt, partial, traversal, symlink, future-schema, and non-empty
  restores fail without target mutation.
- **SC-005**: Secret/sensitive canary scans find zero disclosure across logs,
  errors, argv, environment, manifests, or fixtures.
- **SC-006**: A clean private deployment and fresh-host restore complete within
  the documented reference targets.

## Explicit Exclusions

Multiple users/admins/roles/tenants; MFA/passkeys/TOTP/SSO/LDAP; email/SMS reset;
public-internet deployment, ACME/CDN/WAF/VPN provisioning; Kubernetes/multi-host
or replicas; online/scheduled/cloud backup, retention deletion, built-in backup
encryption; destructive in-place restore; SIEM/alerts/audit UI; and every
invoice/client/project/rendering/scheduling/reporting behavior.

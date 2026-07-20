# Mission Specification: P0 Contract Spine

**Mission Branch**: `feat/p0-contract-spine`  
**Created**: 2026-07-19  
**Status**: Ready for Tasking after cross-mission Draft corrections
**Input**: Establish the initial repository baseline, specify the smallest
foundation mission, and expose stable draft contracts that allow P1 through P4
to proceed as a coordinated swarm.

## Intent Summary

The primary actor is an Invoice Manager contributor beginning from a clean
checkout or adding one independently owned domain. The trigger is either the
first project bootstrap or a mission consuming a frozen shared contract. The
successful outcome is a runnable application shell and an auditable contract
spine that lets parallel missions add domain behavior without editing shared
registries or inventing incompatible representations. P0 must never absorb
invoice-manager feature behavior merely to make the foundation look complete.

The main exception is an incompatible or unpackageable required dependency. In
that case the foundation must fail with a precise, documented blocker; it must
not silently substitute a different database, float to a newer revision, or
weaken the durability contract.

## User Scenarios & Testing

### User Story 1 - Reproduce the Foundation (Priority: P1)

As a contributor, I can begin with a clean checkout, follow one documented
bootstrap path, and reach a running web shell and healthy business service with
all foundation checks passing.

**Why this priority**: Every feature mission depends on a reproducible baseline.

**Independent Test**: Start from a clean environment with the documented
prerequisites, execute the bootstrap and validation commands, open the web
shell, and observe a healthy response through the same-origin service boundary.

**Acceptance Scenarios**:

1. **Given** a clean checkout and supported prerequisites, **When** the
   contributor follows the quickstart, **Then** the web shell and business
   service start without undocumented manual edits.
2. **Given** a missing or incompatible prerequisite, **When** bootstrap runs,
   **Then** it stops with the exact unsupported component and remediation.
3. **Given** the required storage dependency cannot be reproduced at its
   approved revision, **When** dependency validation runs, **Then** it fails
   without selecting another storage engine or revision.

---

### User Story 2 - Add an Independent Domain (Priority: P1)

As a contributor working in P1, P2, P3, or P4, I can consume shared identifiers,
money, dates, response envelopes, event envelopes, fixtures, and migration
rules while adding only domain-owned files.

**Why this priority**: This is the contract that converts the program from a
serial backlog into safe concurrent missions.

**Independent Test**: Add two synthetic domain fragments and migrations in
separate owner directories, compose them deterministically, and prove neither
change edits a shared registry or collides with the other.

**Acceptance Scenarios**:

1. **Given** two valid domain-owned contract fragments, **When** the contract
   build runs, **Then** one deterministic aggregate is produced.
2. **Given** duplicate routes, operation identifiers, schemas, event types, or
   migration identifiers, **When** validation runs, **Then** it rejects the
   collision and identifies both owners.
3. **Given** a frozen contract fixture, **When** a consumer changes a formerly
   valid representation incompatibly, **Then** contract validation fails before
   the change can be accepted.
4. **Given** a recorded P1-P4 conformance input, **When** composition resolves
   it, **Then** the source is identified by a full commit plus manifest/content
   digest and can change only through an explicit baseline refresh that
   revalidates every affected input.

---

### User Story 3 - Prove Durable Storage (Priority: P1)

As a maintainer, I can prove that an acknowledged consequential mutation is
still present after the application closes and reopens its approved storage
file.

**Why this priority**: A financial system cannot build on an ambiguous
commit-versus-durability boundary.

**Independent Test**: Through the application-owned storage boundary, apply a
bootstrap migration, commit a synthetic record, make it durable, close, reopen,
and verify the record. Exercise rollback, corrupt-file refusal, and durability
failure separately.

**Acceptance Scenarios**:

1. **Given** a valid mutation, **When** it is acknowledged as successful,
   **Then** it survives close and reopen.
2. **Given** a rolled-back mutation, **When** storage closes and reopens,
   **Then** no part of that mutation is visible.
3. **Given** the mutation commits but durable persistence fails, **When** the
   caller receives the result, **Then** the result distinguishes unconfirmed
   durability and does not instruct the caller to replay domain writes.
4. **Given** a corrupt existing store, **When** the service opens it, **Then**
   startup fails without replacing or overwriting the file.

---

### User Story 4 - Trust the Program Gates (Priority: P2)

As a maintainer reviewing concurrent mission work, I can see focused validation
for contracts, service code, web code, persistence, HTTP boundaries, migrations,
and distribution licensing.

**Why this priority**: Independent lanes remain fast only when contract and
quality drift is detected automatically.

**Independent Test**: Introduce one controlled failure in each gate category
and prove that the relevant gate fails for the intended reason while unrelated
jobs remain independently diagnosable.

**Acceptance Scenarios**:

1. **Given** a contract, type, formatting, build, persistence, or license
   violation, **When** required validation runs, **Then** acceptance is blocked
   with the responsible surface identified.
2. **Given** a feature mission that touches a shared integration file without
   ownership, **When** program validation runs, **Then** the change is rejected
   or routed to the named integration steward.

### Edge Cases

- Two missions independently create migrations at nearly the same time.
- A contract fragment is valid alone but collides after composition.
- A signed 64-bit monetary value exceeds JavaScript's exact numeric range.
- A money string contains a plus sign, exponent, decimal point, whitespace, or
  a non-canonical leading zero.
- A civil date is structurally correct but not a real Gregorian date.
- An event consumer receives an unknown optional field or a newer payload
  version.
- A previously applied migration changes content without changing identity.
- A migration dependency is absent or cyclic.
- A migration checkpoint succeeds but supported Linux parent-directory
  synchronization fails; it must not be recorded as Applied or permit traffic.
- Storage commits in memory but the durable checkpoint fails.
- Storage checkpoint returns but parent-directory synchronization fails.
- The process exits after commit, checkpoint, or directory synchronization but
  before acknowledgment.
- Shutdown occurs while a mutation or migration is active.
- A storage string contains quotes, NUL, comment markers, Unicode, or newlines.
- Dependency resolution points at a sibling checkout or floating branch.
- A dependency is individually open source but incompatible with the
  GPL-2.0-only combined runtime.
- A contract is moved to terminal Superseded and a later change attempts to
  transition it back, reuse its version for changed content, or redirect a
  pinned consumer silently.

## Requirements

### Functional Requirements

| ID | Title | User Story | Priority | Status |
| --- | --- | --- | --- | --- |
| FR-001 | Documented bootstrap | As a contributor, I want one documented setup and validation path so that a clean checkout becomes usable without private knowledge. | High | Approved |
| FR-002 | Runnable service boundary | As a contributor, I want a visible application shell and a healthy business-service response through the supported origin so that the real boundary is proven before feature work. | High | Approved |
| FR-003 | Shared value representations | As a domain contributor, I want one canonical representation for identifiers, exact money, currencies, civil dates, UTC instants, and large counters so that web and service code cannot disagree silently. | High | Approved |
| FR-004 | Structured response contract | As a UI contributor, I want versioned success, error, field-failure, and request-correlation shapes so that user feedback remains accessible without duplicating business rules. | High | Approved |
| FR-005 | Additive module contracts | As a domain contributor, I want to add a namespaced module manifest, HTTP fragment, event catalog, fixtures, and migrations without editing a global registry so that missions can proceed independently. | High | Approved |
| FR-006 | Collision detection | As a maintainer, I want composition to reject duplicate paths, operations, schemas, events, and generated mount keys so that parallel work cannot overwrite another mission silently. | High | Approved |
| FR-007 | Event and fixture envelope | As a producer or consumer contributor, I want a versioned immutable event envelope and synthetic fixture-batch format so that reporting work can proceed against frozen examples. | High | Approved |
| FR-008 | Contract lifecycle manifest | As an orchestrator, I want every shared contract to record owner, mission, state, version, exact planning base, dependencies, full-commit and manifest/content-digest pins for P1-P4 conformance inputs, outputs, ownership, shared touchpoints, migration strategy, integration fixtures, and digests so that Draft, Frozen, Implemented, Verified, and terminal Superseded have enforceable meanings. Superseded is reachable from any non-Superseded state, has no outgoing transition, and never permits same-version content changes or silent consumer redirection. | High | Approved |
| FR-009 | Parallel-safe migrations | As a domain contributor, I want owner-scoped forward migrations with collision-resistant identities and explicit dependencies so that no shared next-number registry is required. | High | Approved |
| FR-010 | Migration integrity | As a maintainer, I want missing dependencies, cycles, duplicate identities, and any changed applied descriptor or script content rejected so that schema history is deterministic and append-only. | High | Approved |
| FR-011 | Reproducible storage dependency | As a contributor, I want the approved storage engine resolved at one immutable revision through a clean-clone-consumable boundary so that builds never depend on a sibling checkout or floating branch. | High | Approved |
| FR-012 | Serialized storage seam | As a domain contributor, I want one application-owned storage boundary for transactions, diagnostics, migrations, durability, close, and reopen so that storage implementation details never leak into domain work. | High | Approved |
| FR-013 | Durable acknowledgement | As a maintainer, I want consequential mutations acknowledged only after commit, checkpoint, and supported Linux parent-directory synchronization so that a reported success survives restart and snapshot rename. | High | Approved |
| FR-014 | Durability uncertainty | As an operator, I want a committed-but-not-durable result distinguished from a rolled-back failure so that recovery retries persistence rather than replaying business effects. | High | Approved |
| FR-015 | Independent validation gates | As a contributor, I want separately diagnosable contract, service, web, persistence, HTTP, migration-negative, and license checks so that one lane's failure does not obscure another. | Medium | Approved |
| FR-016 | Program ownership evidence | As an orchestrator, I want P0's contract versions, shared paths, integration steward, baseline, and validation evidence reflected in the program ledger so that downstream mission readiness is visible. | High | Approved |

### Non-Functional Requirements

| ID | Title | Requirement | Category | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| NFR-001 | First-run time | Under the reference measurement protocol, a contributor with documented prerequisites completes bootstrap, required foundation validation, and the health smoke path within 15 minutes. | Usability | High | Approved |
| NFR-002 | Deterministic composition | Repeated contract composition from an unchanged checkout and unchanged full-commit/digest-pinned P1-P4 conformance inputs produces byte-identical aggregates in 100% of validation runs. | Reliability | High | Approved |
| NFR-003 | Collision rejection | The validation suite rejects every case in the closed P0 collision matrix: duplicate normalized method-plus-path, operation ID, schema ID or component name, event identity plus version, module mount key, migration ID, and owner/path disagreement. | Integrity | High | Approved |
| NFR-004 | Numeric fidelity | Round trips preserve every supported signed 64-bit monetary and revision boundary value exactly between contract fixtures, service validation, and web type checks. | Correctness | High | Approved |
| NFR-005 | Durability cycles | The persistence acceptance suite passes at least 20 consecutive commit-checkpoint-directory-sync-close-reopen cycles with no acknowledged record loss and rejects injected checkpoint/sync failures plus external-process termination after each boundary. | Durability | High | Approved |
| NFR-006 | Critical branch coverage | Shared service value, migration, and durability code maintains at least 90% automated coverage and covers every documented error branch regardless of aggregate percentage. | Testability | High | Approved |
| NFR-007 | Health responsiveness | Under the reference health protocol, the nearest-rank p99 of exactly 100 sequential measured requests completes within one second while the service is Ready. | Performance | Medium | Approved |
| NFR-008 | Validation duration | Under the reference measurement protocol, required P0 validation completes within 15 minutes, with jobs independently runnable for focused feedback. | Delivery | Medium | Approved |
| NFR-009 | Failure safety | Corrupt storage, unresolved dependencies, contract drift, and license incompatibility produce zero silent fallbacks or destructive replacement attempts in acceptance tests. | Safety | High | Approved |
| NFR-010 | Synthetic evidence | 100% of committed fixtures, examples, and logs contain synthetic data and no client, bank, invoice, password, token, or private-key material. | Privacy | High | Approved |
| NFR-011 | License cleanliness | The distribution audit reports zero known runtime components incompatible with GPL-2.0-only and records notices for every distributed third-party component. | Compliance | High | Approved |
| NFR-012 | Reproducible dependency graph | Every service and web dependency used by a clean build is pinned by immutable version, lockfile integrity, source digest, or commit. | Reproducibility | High | Approved |

#### Reference Measurement Protocol

- The reference runner is Linux x86_64 with at least 4 logical CPUs and 16 GiB
  RAM, pinned prerequisite toolchains preinstalled, and no deliberate competing
  workload. Each measured run starts from a clean checkout with empty dependency
  and build caches where applicable.
- All durations use a monotonic clock. The NFR-001 timer starts immediately
  before the documented bootstrap command and stops after its same-origin health
  smoke succeeds; it includes dependency resolution, builds, required validation,
  startup, and smoke, but excludes checkout and prerequisite-tool installation.
- The NFR-008 timer starts immediately before the documented full P0 validation
  command and stops when its final required gate reports a result; dependency
  resolution, builds, tests, and audits are inside the boundary.
- For NFR-007, first reach Ready, issue 10 unmeasured sequential warmup requests,
  then issue exactly 100 sequential measured health requests with no concurrency.
  Each sample starts immediately before request send and stops after the complete
  response body is read. Sort monotonic durations ascending; nearest-rank p99 is
  sample `ceil(0.99 * 100) = 99`.

### Constraints

| ID | Title | Constraint | Category | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| C-001 | Project license | Distributed project code is GPL-2.0-only; combined runtime dependencies must be compatible and notices preserved. | Licensing | High | Approved |
| C-002 | Presentation boundary | The web application presents and submits data but does not own authoritative business validation, lifecycle, money, persistence, scheduling, or document-generation rules. | Architecture | High | Approved |
| C-003 | Business authority | The Zig service is the only business backend and owns future authorization, domain rules, persistence, and rendering orchestration. | Architecture | High | Approved |
| C-004 | Required store | ShovelerDB at approved commit `021e3b3d9247a181252329d6ba7ec8d2ed943a97` is the embedded transactional store; no silent substitute or floating revision is allowed. | Dependency | High | Approved |
| C-005 | Single handle | One service process owns and serializes one storage handle for each database path; multiple replicas may not share one path. | Durability | High | Approved |
| C-006 | Exact money | Monetary values use integer minor units with explicit currency and checked arithmetic; binary floating point and implicit foreign exchange are prohibited. | Correctness | High | Approved |
| C-007 | Additive ownership | Feature missions add domain-owned fragments, fixtures, and migrations; shared builds, generated aggregates, and root configuration require the named integration steward. | Delivery | High | Approved |
| C-008 | No feature absorption | P0 contains no billing identity, client, project, invoice, payment, remittance, logo, authentication, dashboard, PDF, numbering, or recurrence behavior. | Scope | High | Approved |
| C-009 | Public reproducibility | The repository must build without private registries, unpublished sibling paths, or non-public data. | Distribution | High | Approved |
| C-010 | PR-bound mission | P0 remains on its dedicated mission/coordination branches and is reviewed and merged through the project gates rather than pushed directly to `main`. | Governance | High | Approved |

### Key Entities

- **Contract Manifest**: The canonical lifecycle, dependency, ownership,
  artifact, migration, and fixture evidence for one shared contract.
- **Domain Contract Fragment**: A mission-owned additive contribution composed
  into an API or event-contract build artifact.
- **Contract Fixture**: An immutable synthetic valid or invalid example tied to
  an exact contract version.
- **Migration Descriptor**: An owner-scoped forward schema change with
  collision-resistant identity, dependencies, script digest, and canonical
  descriptor digest.
- **Applied Migration**: Durable evidence that a descriptor committed,
  ShovelerDB checkpoint succeeded, and the supported Linux database parent
  directory synchronized. Earlier committed or checkpointed-but-unsynchronized
  states are pending durability evidence, not Applied.
- **Storage Handle Lease**: Exclusive serialized ownership of one storage path.
- **Durable Mutation Receipt**: The distinction between rollback, commit with
  unconfirmed durability, and fully durable success.

## Domain Language

- **Contract Spine**: The smallest shared representations, composition rules,
  fixtures, persistence seam, and validation needed by independent missions.
- **Domain Fragment**: An owner-scoped additive contract contribution. Avoid
  calling it a plugin; runtime plugin loading is not part of P0.
- **Frozen Contract**: A version with immutable sources and fixture digests that
  consumers may implement against.
- **Superseded Contract**: A terminal contract state reachable from Draft,
  Frozen, Implemented, or Verified with no transition out. Supersession preserves
  the old version and pins; replacement behavior requires a new version and an
  explicit baseline refresh rather than silent consumer redirection.
- **Durable Success**: A mutation that committed, checkpointed, and completed
  supported parent-directory synchronization. Avoid using commit, checkpoint,
  and durable interchangeably.
- **Integration Steward**: The owner who applies approved shared-file changes.
  This is a coordination role, not a new business service.

## Assumptions and Dependencies

- “Invoice Manager” is the approved working product name; visual identity is
  deferred to release integration unless the owner changes it explicitly.
- The first supported development and deployment platform is Linux x86_64.
- P0 may require a narrowly scoped upstream ShovelerDB packaging change. Until
  then, an exact-commit source shim is acceptable only if clean-clone
  reproducibility is proven and the engine is not copied or modified silently.
- P2 owns the LuaLaTeX distribution, fonts, templates, and PDF regression
  harness. P3 owns authentication, deployment composition, backup, and restore.
- The program ledger is the authoritative cross-mission readiness view; each
  mission's Spec Kitty artifacts remain authoritative for its own gates.
- P1-P4 conformance inputs are immutable full-commit and manifest/content-digest
  pins. Changing any pin requires an explicit baseline refresh that records the
  old and new pins and revalidates every affected composition and fixture.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A new contributor with documented prerequisites reaches the
  healthy application shell and completes foundation validation within 15
  minutes without private assistance.
- **SC-002**: Four synthetic domain owners can contribute contracts, fixtures,
  and migrations concurrently without editing a shared registry or overwriting
  another owner's contribution.
- **SC-003**: Every closed-matrix incompatible contract, duplicate identity, missing
  dependency, cycle, route/event mismatch, manifest freeze violation, and
  descriptor/script digest mutation is rejected before acceptance; conformance
  pin drift and illegal transitions out of Superseded are rejected as well.
- **SC-004**: Every acknowledged record survives at least 20 consecutive
  checkpoint-directory-sync-close-reopen acceptance cycles, while rollback,
  injected sync failure, process-crash boundary, and durability-uncertain cases
  remain distinguishable.
- **SC-005**: All exact-money boundary fixtures round-trip without precision
  loss between the user-facing application and business service.
- **SC-006**: Every required P0 quality and licensing gate passes independently,
  and the program ledger records P1-P4 contract readiness without unresolved
  ownership conflicts.
- **SC-007**: The foundation shell meets WCAG 2.2 AA with zero configured
  automated serious or critical violations, normal-text contrast of at least
  4.5:1, large-text contrast of at least 3:1, visible keyboard focus and working
  skip link, usable 200% zoom, and no horizontal overflow at 320 CSS pixels.

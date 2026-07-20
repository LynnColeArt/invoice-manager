# Mission Specification: P1 Parties and Projects

**Mission Branch**: `feat/p1-parties-projects`
**Created**: 2026-07-19
**Status**: Ready for Planning
**Input**: Deliver the owner-facing client and project manager with explicit
Billing Identity, remittance, currency, cadence, payment-term, and logo policy.

## Intent Summary

The business owner creates the legal identities that may issue invoices, then
creates clients and projects whose consequential billing defaults are complete
and visible. The happy path ends with an Active Project whose resolved
configuration can be consumed by document, issuance, and scheduling missions.
The main exception is an incomplete or inactive identity/remittance/logo choice;
the system must preserve the draft but refuse to mark it Ready or Active.

The canonical domain term is **Billing Identity**. The UI may clarify it as
**Invoice header / billed from**. P1 owns mutable configuration, never historical
invoice contents or downstream billing lifecycle behavior.

## User Scenarios & Testing

### User Story 1 - Configure Billing Identities (Priority: P1)

As the owner, I can configure personal and LLC Billing Identities with their
legal/contact details, remittance profile, payment terms, and optional logos so
each future invoice has an explicit issuer source.

**Independent Test**: Create both identity kinds, validate European remittance,
set defaults, deactivate one, and verify new references cannot use it.

**Acceptance Scenarios**:

1. **Given** complete personal or company details, **When** the owner activates
   the identity, **Then** it becomes selectable as an invoice header.
2. **Given** incomplete European remittance details, **When** activation or
   Europe resolution is attempted, **Then** stable field errors identify every
   missing/invalid value without logging account data.
3. **Given** active clients/projects still depend on an identity, **When** the
   owner deactivates it without reassigning them, **Then** the operation is
   rejected atomically.

---

### User Story 2 - Manage Clients and Contacts (Priority: P1)

As the owner, I can create a client, record its billing contacts/address/market,
select its required default Invoice header, currency, and payment terms, and see
whether it is ready for projects.

**Independent Test**: Create domestic, European, and Other clients and verify
their remittance decisions and readiness errors.

**Acceptance Scenarios**:

1. **Given** a domestic client, **When** its resolved configuration is viewed,
   **Then** no bank fields are present.
2. **Given** a European client, **When** its default identity has a complete
   profile, **Then** the resolved view includes that profile; otherwise the
   client cannot become Ready.
3. **Given** an Other client, **When** no explicit remittance choice exists,
   **Then** readiness fails until Show or Hide is selected.
4. **Given** an incomplete new client, **When** it is saved, **Then** it remains
   Draft with actionable readiness errors rather than losing entered data.

---

### User Story 3 - Configure Billable Projects (Priority: P1)

As the owner, I can create a monthly or quarterly project, inherit the client's
issuer/currency/terms, visibly override allowed values, choose logo On/Off, and
see the exact resolved configuration before activation.

**Independent Test**: Configure one inherited and one overridden project across
domestic and European clients, including logo success/failure.

**Acceptance Scenarios**:

1. **Given** client-default identity mode, **When** the client default changes,
   **Then** the current resolved project reflects the new identity and provenance.
2. **Given** explicit override mode, **When** the project is reviewed, **Then**
   the override is conspicuous and does not change when the client default changes.
3. **Given** logo On, **When** no active compatible asset resolves, **Then** the
   project cannot activate; logo Off requires and exposes no asset.
4. **Given** valid cadence dates and configuration, **When** activation occurs,
   **Then** consumers receive the exact cadence facts while P1 performs no
   schedule advancement or draft creation.

---

### User Story 4 - Operate the Internal Client Manager (Priority: P2)

As the owner, I can search, filter, open, update, archive, and understand clients
and projects without exposing sensitive remittance values by default.

**Independent Test**: Use keyboard-only navigation to find an Active European
client, reveal masked bank details deliberately, edit its contact, and archive a
completed project.

**Acceptance Scenarios**:

1. **Given** hundreds of clients/projects, **When** the owner searches or filters,
   **Then** matching records and relevant readiness/status labels appear promptly.
2. **Given** a remittance profile, **When** the page opens, **Then** account data
   is masked until an explicit reveal action.
3. **Given** referenced master data, **When** deletion is attempted, **Then** the
   system offers archival/deactivation rather than breaking references.

### Edge Cases

- A client default identity is deactivated concurrently with project activation.
- Project override references an identity that becomes inactive.
- Domestic resolution accidentally serializes hidden bank fields.
- IBAN has valid shape but invalid check digits; BIC has incorrect length/case.
- Logo MIME declaration disagrees with decoded content or exceeds 2 MiB.
- Logo content is replaced under the same filename.
- Client changes from Europe to Domestic or Other with incomplete explicit mode.
- Default amount currency differs from Project currency.
- Next billing date precedes anchor or exceeds end date.
- Two retries upload the same asset or submit the same create request.
- Archived data remains referenced by future invoice history.

## Requirements

### Functional Requirements

| ID | Title | User Story | Priority | Status |
| --- | --- | --- | --- | --- |
| FR-001 | Billing Identity management | As the owner, I can create, view, update, activate, and deactivate Personal and Company Billing Identities. | High | Approved |
| FR-002 | Identity legal details | As the owner, I can maintain legal/contact/address details, labeled tax identifiers, default terms, and a preferred display label for each identity. | High | Approved |
| FR-003 | European remittance profiles | As the owner, I can maintain account holder, bank name, IBAN, BIC/SWIFT, currency, and optional bank address/instructions for an identity. | High | Approved |
| FR-004 | Remittance validation and redaction | As the owner, I receive field-specific completeness/format errors while sensitive values remain absent from logs, summaries, and unrelated responses. | High | Approved |
| FR-005 | Logo asset management | As the owner, I can upload, validate, select, replace-by-new-version, deactivate, and inspect approved PNG logo assets. | High | Approved |
| FR-006 | Client drafts and readiness | As the owner, I can save incomplete Client drafts and see the exact blockers before activation. | High | Approved |
| FR-007 | Client defaults | As the owner, I must select an Active default Billing Identity, enabled currency, payment terms, billing address, primary contact, and explicit Billing Market for every Active Client. | High | Approved |
| FR-008 | Explicit remittance policy | As the owner, Domestic always hides remittance, Europe always requires it, and Other requires an explicit Show/Hide decision. | High | Approved |
| FR-009 | Client/contact manager | As the owner, I can search, filter, view, edit, archive, and restore Client drafts with their contacts and readiness/status. | Medium | Approved |
| FR-010 | Project lifecycle | As the owner, I can create, activate, pause, complete, and archive Projects without deleting referenced records. | High | Approved |
| FR-011 | Identity inheritance/override | As the owner, each Project either inherits the Client default identity or visibly selects an explicit Active override. | High | Approved |
| FR-012 | Project billing defaults | As the owner, I can configure currency, payment terms, default service description/amount, monthly or quarterly cadence, anchor, next billing date, and optional end date. | High | Approved |
| FR-013 | Project logo policy | As the owner, every Project explicitly chooses logo On or Off; On resolves an approved project or identity asset and Off resolves none. | High | Approved |
| FR-014 | Resolved configuration view | As the owner and downstream consumer, I can inspect effective issuer, recipient, market/remittance, currency/terms, cadence, and logo with inheritance provenance and readiness errors. | High | Approved |
| FR-015 | Atomic reassignment | As the owner, I can reassign affected Client/Project defaults in the same durable operation required to deactivate an identity or asset. | High | Approved |
| FR-016 | Configuration events | As a downstream mission, I can consume versioned identity/client/project/asset lifecycle facts without reading P1 storage internals. | Medium | Approved |
| FR-017 | Idempotent retries | As a caller, retried creates/uploads with the same idempotency key return the original result rather than duplicating records/assets. | High | Approved |
| FR-018 | Durable mutation | As the owner, successful configuration changes remain after close/reopen and committed-but-uncheckpointed results are not falsely reported as success. | High | Approved |

### Non-Functional Requirements

| ID | Title | Requirement | Category | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| NFR-001 | Client-manager responsiveness | Search/filter/detail interactions complete within two seconds for 500 Clients and 2,000 Projects on the reference deployment. | Performance | Medium | Approved |
| NFR-002 | Sensitive-data absence | 100% of Domestic resolved payloads and fixtures contain no remittance field names or values. | Privacy | High | Approved |
| NFR-003 | Log redaction | Automated tests find zero full IBAN, BIC, account-holder, or bank-instruction values in application logs and audit summaries. | Security | High | Approved |
| NFR-004 | Durable configuration | Every successful P1 mutation survives checkpoint-close-reopen acceptance testing. | Durability | High | Approved |
| NFR-005 | Domain coverage | P1 Zig domain code maintains at least 90% coverage and covers every readiness, resolution, lifecycle, and retry error branch. | Testability | High | Approved |
| NFR-006 | Accessibility | All P1 primary workflows meet WCAG 2.2 AA automated checks and complete keyboard-only acceptance without color-only status/override cues. | Accessibility | High | Approved |
| NFR-007 | Asset limits | Logo ingestion rejects files over 2 MiB, unsupported/discordant media, malformed content, and unsafe paths in 100% of acceptance fixtures. | Safety | High | Approved |
| NFR-008 | Resolution consistency | Repeating resolution against unchanged revisions produces byte-equivalent canonical data in 100% of tests. | Correctness | High | Approved |
| NFR-009 | Concurrency safety | Covered concurrent default/override/deactivation races produce one valid serialized outcome and zero dangling references. | Integrity | High | Approved |
| NFR-010 | Contract isolation | P1 implementation modifies no P2-P8 primary-owned path or generated aggregate and passes P0 contract compatibility checks. | Delivery | High | Approved |

### Constraints

| ID | Title | Constraint | Category | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| C-001 | P0 dependency state | P1 may plan against P0 `0.1.0-draft.1` but may not implement until consumed contracts are Frozen and available on its current baseline. | Dependency | High | Approved |
| C-002 | Zig authority | All validation, resolution, lifecycle, file ingestion, persistence, and event behavior is authoritative in Zig; Next.js is presentation only. | Architecture | High | Approved |
| C-003 | Exact currencies | Launch currencies are USD and EUR; no conversion or cross-currency aggregation exists. | Scope | High | Approved |
| C-004 | Explicit market | Billing Market is stored explicitly and never inferred from Postal Address. | Correctness | High | Approved |
| C-005 | No historical mutation | P1 master-data changes cannot alter an issued Invoice or retained artifact. | Integrity | High | Approved |
| C-006 | No invoice lifecycle | P1 does not create Invoice lines/snapshots, allocate numbers, issue/void, record payments, or render documents. | Scope | High | Approved |
| C-007 | No schedule behavior | P1 stores Project cadence facts but never derives Due Project, advances dates, or creates draft proposals. | Scope | High | Approved |
| C-008 | Owner-scoped additions | P1 contributes only namespaced contracts, fixtures, migrations, domain/UI paths, and approved integration requests. | Delivery | High | Approved |
| C-009 | Synthetic public evidence | Public fixtures contain only invented identities, clients, addresses, bank values, and assets. | Privacy | High | Approved |

### Key Entities

- **Billing Identity**: The Personal or Company legal party that may issue an
  invoice; UI label “Invoice header / billed from.”
- **Remittance Profile**: A validated bank-information set associated with one
  Billing Identity and revealed only when policy resolves to Show.
- **Logo Asset**: Immutable approved artwork content identified by digest and
  active state.
- **Client**: The billed party that owns contact/address/market and required
  issuer/currency/term defaults.
- **Billing Contact**: A recipient contact belonging to a Client.
- **Project**: A billable engagement with identity inheritance/override,
  currency/terms, cadence facts, and logo policy.
- **Resolved Invoice Configuration**: Current effective configuration plus
  provenance/readiness, not an issued snapshot.

## Success Criteria

- **SC-001**: The owner can configure Personal and LLC identities plus Domestic
  and European Clients and activate two Projects within ten minutes after login.
- **SC-002**: Every Active Client and Project resolves one Active Billing
  Identity with visible inheritance/override provenance and zero unresolved
  readiness errors.
- **SC-003**: 100% of Domestic acceptance payloads omit remittance data, while
  100% of European acceptance cases either include a complete profile or fail
  before activation.
- **SC-004**: Logo On/Off and identity/project asset selection remain consistent
  across resolution retries and later master-data revisions.
- **SC-005**: All successful P1 changes survive restart, and no covered
  concurrent reassignment leaves a dangling or inactive reference.
- **SC-006**: P2, P5, and P6 can consume one versioned resolved-configuration
  fixture set without reading P1 database records or UI state.

## Assumptions

- “Invoice Manager” remains the working name.
- USD and EUR cover launch; adding another currency is a separately validated
  configuration change.
- P3 supplies authenticated single-administrator access and persistent-volume
  protection. P1 still applies privacy-by-default response/log behavior.
- P5 freezes the current resolved configuration into issued records.

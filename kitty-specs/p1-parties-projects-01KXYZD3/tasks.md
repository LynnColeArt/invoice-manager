# Work Packages: p1-parties-projects-01KXYZD3

_Generated from `wps.yaml` for Spec Kitty finalization. Do not edit directly after finalization._

---

## Work Package WP01: P1 Contract and Decision-Fixture Spine

**Dependencies**: None
**Requirement Refs**: FR-008, FR-011, FR-012, FR-013, FR-014, FR-016, NFR-002, NFR-008, NFR-010, C-001, C-008, C-009
**Plan Concerns**: IC-01
**Owned Files**: contracts/api/v1/fragments/p1/**, contracts/events/v1/catalogs/p1/**, contracts/events/v1/payloads/p1/**, contracts/modules/p1/**, contracts/manifests/drafts/p1.json, contracts/fixtures/p1/v1/decisions/**
**Subtasks**: T001, T002, T003, T004, T005, T006
**Prompt**: `tasks/WP01-p1-contract-and-decision-fixture-spine.md`

---

## Work Package WP02: Shared Domain Values, Readiness, and Policy Tables

**Dependencies**: WP01
**Requirement Refs**: FR-004, FR-006, FR-007, FR-008, FR-010, FR-011, FR-012, FR-013, FR-014, NFR-005, NFR-008, NFR-009, C-002, C-003, C-004
**Plan Concerns**: IC-02
**Owned Files**: services/api/src/domains/parties_projects/root.zig, services/api/src/domains/parties_projects/shared/**, services/api/tests/parties_projects/shared/**
**Subtasks**: T007, T008, T009, T010, T011
**Prompt**: `tasks/WP02-shared-domain-values-readiness-and-policy-tables.md`

---

## Work Package WP03: Billing Identity, Remittance, and Logo Asset Domain

**Dependencies**: WP02
**Requirement Refs**: FR-001, FR-002, FR-003, FR-004, FR-005, FR-015, NFR-003, NFR-005, NFR-007, NFR-009, C-002, C-005, C-009
**Plan Concerns**: IC-03
**Owned Files**: services/api/src/domains/parties_projects/billing_identity/**, services/api/src/domains/parties_projects/remittance/**, services/api/src/domains/parties_projects/logo_asset/**, services/api/tests/parties_projects/billing_identity/**, services/api/tests/parties_projects/remittance/**, services/api/tests/parties_projects/logo_asset/**
**Subtasks**: T012, T013, T014, T015, T016
**Prompt**: `tasks/WP03-billing-identity-remittance-and-logo-asset-domain.md`

---

## Work Package WP04: Client and Billing Contact Domain

**Dependencies**: WP02
**Requirement Refs**: FR-006, FR-007, FR-008, FR-009, FR-015, NFR-001, NFR-003, NFR-005, NFR-009, C-002, C-004, C-005, C-009
**Plan Concerns**: IC-04
**Owned Files**: services/api/src/domains/parties_projects/client/**, services/api/src/domains/parties_projects/billing_contact/**, services/api/tests/parties_projects/client/**, services/api/tests/parties_projects/billing_contact/**
**Subtasks**: T017, T018, T019, T020, T021
**Prompt**: `tasks/WP04-client-and-billing-contact-domain.md`

---

## Work Package WP05: Project Domain and Current Configuration Resolver

**Dependencies**: WP02
**Requirement Refs**: FR-010, FR-011, FR-012, FR-013, FR-014, FR-015, NFR-005, NFR-008, NFR-009, C-002, C-003, C-004, C-005, C-007
**Plan Concerns**: IC-05
**Owned Files**: services/api/src/domains/parties_projects/project/**, services/api/src/domains/parties_projects/resolution/**, services/api/tests/parties_projects/project/**, services/api/tests/parties_projects/resolution/**
**Subtasks**: T022, T023, T024, T025, T026
**Prompt**: `tasks/WP05-project-domain-and-current-configuration-resolver.md`

---

## Work Package WP06: Owner-Scoped Migrations and Repositories

**Dependencies**: WP01
**Requirement Refs**: FR-015, FR-017, FR-018, NFR-004, NFR-005, NFR-009, C-001, C-002, C-008, C-009
**Plan Concerns**: IC-06
**Owned Files**: services/api/migrations/p1/**, services/api/src/domains/parties_projects/persistence/**, services/api/tests/parties_projects/persistence/**
**Subtasks**: T027, T028, T029, T030, T031, T032
**Prompt**: `tasks/WP06-owner-scoped-migrations-and-repositories.md`

---

## Work Package WP07: Durable Services, Idempotency, and Configuration Events

**Dependencies**: WP03, WP04, WP05, WP06
**Requirement Refs**: FR-001, FR-005, FR-006, FR-009, FR-010, FR-015, FR-016, FR-017, FR-018, NFR-003, NFR-004, NFR-009, C-002, C-005, C-006, C-007, C-008
**Plan Concerns**: IC-07
**Owned Files**: services/api/src/domains/parties_projects/application/**, services/api/src/domains/parties_projects/events/**, services/api/tests/parties_projects/application/**, services/api/tests/parties_projects/events/**
**Subtasks**: T033, T034, T035, T036, T037, T038
**Prompt**: `tasks/WP07-durable-services-idempotency-and-configuration-events.md`

---

## Work Package WP08: Resolved Configuration and Negative Security Fixtures

**Dependencies**: WP03, WP04, WP05, WP07
**Requirement Refs**: FR-004, FR-008, FR-013, FR-014, FR-016, NFR-002, NFR-003, NFR-005, NFR-007, NFR-008, C-004, C-009
**Plan Concerns**: IC-08
**Owned Files**: contracts/fixtures/p1/v1/valid/**, contracts/fixtures/p1/v1/invalid/**, contracts/fixtures/p1/v1/security/**, services/api/tests/parties_projects/resolved_configuration/**, services/api/tests/parties_projects/security/**
**Subtasks**: T039, T040, T041, T042, T043
**Prompt**: `tasks/WP08-resolved-configuration-and-negative-security-fixtures.md`

---

## Work Package WP09: HTTP Queries, Mutations, and Black-Box Contracts

**Dependencies**: WP01, WP07, WP08
**Requirement Refs**: FR-001, FR-005, FR-006, FR-007, FR-008, FR-009, FR-010, FR-011, FR-012, FR-013, FR-014, FR-015, FR-017, FR-018, NFR-001, NFR-003, NFR-004, NFR-009, NFR-010, C-002, C-008
**Plan Concerns**: IC-09
**Owned Files**: services/api/src/domains/parties_projects/http/**, services/api/tests/parties_projects/http/**
**Subtasks**: T044, T045, T046, T047, T048, T049
**Prompt**: `tasks/WP09-http-queries-mutations-and-black-box-contracts.md`

---

## Work Package WP10: Billing Identity and Client Manager UI

**Dependencies**: WP09
**Requirement Refs**: FR-001, FR-002, FR-003, FR-004, FR-005, FR-006, FR-007, FR-008, FR-009, NFR-001, NFR-003, NFR-006, C-002, C-009
**Plan Concerns**: IC-10
**Owned Files**: apps/web/src/features/billing-identities/**, apps/web/src/features/clients/**, apps/web/src/app/billing-identities/**, apps/web/src/app/clients/**, apps/web/tests/parties-projects/identities-clients/**
**Subtasks**: T050, T051, T052, T053, T054
**Prompt**: `tasks/WP10-billing-identity-and-client-manager-ui.md`

---

## Work Package WP11: Project Manager and Resolved Configuration UI

**Dependencies**: WP09
**Requirement Refs**: FR-010, FR-011, FR-012, FR-013, FR-014, NFR-001, NFR-006, C-002, C-007, C-009
**Plan Concerns**: IC-11
**Owned Files**: apps/web/src/features/projects/**, apps/web/src/app/projects/**, apps/web/tests/parties-projects/projects/**
**Subtasks**: T055, T056, T057, T058, T059
**Prompt**: `tasks/WP11-project-manager-and-resolved-configuration-ui.md`

---

## Work Package WP12: P1 Compatibility, Accessibility, Durability, and Consumer Handoff

**Dependencies**: WP08, WP09, WP10, WP11
**Requirement Refs**: FR-001, FR-002, FR-003, FR-004, FR-005, FR-006, FR-007, FR-008, FR-009, FR-010, FR-011, FR-012, FR-013, FR-014, FR-015, FR-016, FR-017, FR-018, NFR-001, NFR-002, NFR-003, NFR-004, NFR-005, NFR-006, NFR-007, NFR-008, NFR-009, NFR-010, C-001, C-002, C-003, C-004, C-005, C-006, C-007, C-008, C-009
**Plan Concerns**: IC-12
**Owned Files**: services/api/tests/parties_projects/acceptance/**, apps/web/tests/parties-projects/acceptance/**, contracts/manifests/p1.json, docs/integration-requests/p1/**, docs/program-handoffs/p1/**
**Subtasks**: T060, T061, T062, T063, T064, T065, T066
**Prompt**: `tasks/WP12-p1-compatibility-accessibility-durability-and-consumer-handoff.md`

---

---
schema_version: 1
artifact_type: spec-kitty.analysis-report
command: /spec-kitty.analyze
mission_slug: p0-contract-spine-01KXYY0J
mission_id: 01KXYY0J76QBNSWXX0SHMZNXC4
generated_at: '2026-07-20T08:18:23.851045+00:00'
analyzer_agent: unknown
input_artifacts:
  spec.md:
    path: /home/lynn/projects/invoice-manager/kitty-specs/p0-contract-spine-01KXYY0J/spec.md
    sha256: 7d2e4fd1a1bc30cd8bb2fd19d8f73e42a0eaa22d1df698b5b38ac6d6e1afe053
  plan.md:
    path: /home/lynn/projects/invoice-manager/kitty-specs/p0-contract-spine-01KXYY0J/plan.md
    sha256: 3ba0a0ba84246ce1242c2d8b93c3ef26081f396b6fcdef37ae935239d397c29b
  tasks.md:
    path: /home/lynn/projects/invoice-manager/kitty-specs/p0-contract-spine-01KXYY0J/tasks.md
    sha256: 772a53f30c1aa2cd603da9deee6e6430c1a9e1eb3331e324e84affd77e3147c3
  charter:
    path: /home/lynn/projects/invoice-manager/.kittify/charter/charter.md
    sha256: a1176517b273e322d3dc408e369ef836c40e3bb84c69ae140ad554cffbb53f0f
verdict: blocked
issue_counts:
  critical: 1
  low: 0
  high: 6
  medium: 5
  info: 0
findings:
- id: A1
  severity: critical
  category: dependency
  summary: Migration durability, durable storage, and HTTP readiness form an unimplementable dependency cycle.
- id: A2
  severity: high
  category: ownership
  summary: Later npm workspaces cannot update the WP01-owned root lockfile.
- id: A3
  severity: high
  category: integration
  summary: Later Zig packages require focused build steps that no package is authorized and instructed to add.
- id: A4
  severity: high
  category: ordering
  summary: WP09 requires a real Zig proxy E2E test without depending on WP08.
- id: A5
  severity: high
  category: governance
  summary: Closure authority for manifest promotion and living-document synchronization is inconsistent across plan and tasks.
- id: A6
  severity: high
  category: validation
  summary: The mandatory migration-negative gate has no stable producer command.
- id: A7
  severity: high
  category: reproducibility
  summary: P1-P4 conformance depends on moving branch heads instead of committed immutable inputs.
- id: A8
  severity: medium
  category: architecture
  summary: Generated TypeScript and ignored-output ownership is not defined consistently.
- id: A9
  severity: medium
  category: testability
  summary: Reference Linux and CI performance environments lack a reproducible measurement protocol.
- id: A10
  severity: medium
  category: terminology
  summary: Applied Migration is described as checkpointed while readiness requires directory synchronization.
- id: A11
  severity: medium
  category: scope
  summary: The plan adds Superseded lifecycle behavior that the specification does not define.
- id: A12
  severity: medium
  category: consistency
  summary: The plan's concern dependencies and finalized task graph disagree about migration sequencing.
---

## Specification Analysis Report

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| A1 | Dependency | CRITICAL | `plan.md:284-325,391-434`; `tasks.md:62-91`; `tasks/WP06-*.md:288-314`; `tasks/WP07-*.md:93-96`; `tasks/WP08-*.md:292-315` | WP06 needs checkpoint, parent-directory sync, and reopen recovery that WP07 owns; WP07 depends on WP06; WP08 then requires WP07 readiness without depending on WP07. The current graph cannot deliver the real readiness path. | Make WP07 depend on WP04 only, make WP06 depend on WP05 and WP07, and make WP08 consume WP07/WP06. Keep pure migration discovery in WP06 and durable operations behind WP07's public seam. |
| A2 | Ownership | HIGH | `plan.md:357-378,460-475`; `tasks.md:7-25,95-102`; `tasks/WP01-*.md:166-182`; `tasks/WP09-*.md:147-182` | WP01 exclusively owns `package-lock.json` while intentionally excluding application dependencies. WP09 later adds Next.js/React/test dependencies yet requires the root lock to remain authoritative. | Add a serialized integration-steward lock update after package metadata producers, or move root lock ownership to one package that runs after WP03/WP09 metadata is known. |
| A3 | Integration | HIGH | `plan.md:402-434,460-475`; `tasks.md:40-91`; `tasks/WP04-*.md:200-232`; WP05-WP08 test-strategy sections | WP04 owns `services/api/build.zig*` but only defines ShovelerDB steps. WP05-WP08 require shared, migration, persistence, coverage, and HTTP steps while explicitly forbidding build-file edits. | Make WP04 provide a documented convention-based extension mechanism and every required stable step, or add one exclusive Zig build-integration package before the consuming WPs. |
| A4 | Ordering | HIGH | `spec.md:27-48,177-184`; `plan.md:327-354,426-456`; `tasks.md:84-102`; `tasks/WP09-*.md:277-363` | WP09's acceptance requires real Next.js and Zig processes, but WP09 does not depend on WP08 and its lane cannot see the Zig HTTP implementation. | Either make WP09 depend on WP08 or keep deterministic web tests in WP09 and move the real proxy E2E/performance proof, with FR-002/NFR-007 traceability, to WP10. |
| A5 | Governance | HIGH | `spec.md:163,171,222-234`; `plan.md:436-448,460-479`; `tasks.md:106-113`; `tasks/WP10-*.md:99-108,393-433` | The plan assigns quickstart synchronization and manifest promotion to closure. The validated WP10 task omits the quickstart because code WPs cannot own `kitty-specs/`, and its narrow manifest exception is absent from `tasks.md`. This makes the living-document and lifecycle handoff authority non-auditable from the core task artifact. | Define an explicit planning-artifact/documentation handoff for quickstart sync and expose the exact manifest-promotion exception in the canonical task graph. |
| A6 | Validation | HIGH | `spec.md:166,181`; `plan.md:327-354`; `tasks/WP01-*.md:184-220`; `tasks/WP06-*.md:368-401`; `tasks/WP10-*.md:127-172` | CI requires an independent migration-negative job, but WP01 declares no root command and WP06 treats `zig build migration-test` as optional. | Define one mandatory `migration:negative` root command and one mandatory Zig build step with a single owning package. |
| A7 | Reproducibility | HIGH | `spec.md:54-74,163,236-247`; `plan.md:253-265,327-354`; `tasks/WP03-*.md:324-364`; `tasks/WP10-*.md:353-391` | WP03 and WP10 resolve actual/current P1-P4 branch heads, so P0 acceptance inputs can change without a P0 commit. | Pin full P1-P4 commit IDs plus byte digests in a committed conformance-input manifest, fetch hermetically, and require explicit baseline refresh to change them. |
| A8 | Architecture | MEDIUM | `plan.md:117-165,228-265`; `tasks.md:29-39,95-102`; `tasks/WP03-*.md:294-322`; `tasks/WP09-*.md:232-272` | WP03 describes generated TypeScript in an unspecified ignored directory while WP09 owns a committed contract-client tree. No canonical writer, ignored path, or import alias is named. | Name one ignored generated path and writer, keep hand-written adapters separate, and assign the relevant ignore rule to an owned surface. |
| A9 | Testability | MEDIUM | `spec.md:177,183-184`; `plan.md:38-61`; WP08/WP09/WP10 performance steps | The 15-minute bootstrap/CI limits and 100-request p99 gate do not define CPU/RAM, cache state, warmup, timing boundaries, concurrency, or percentile calculation. | Record a pinned runner/image and exact cold/warm measurement protocol in WP10 evidence. |
| A10 | Terminology | MEDIUM | `spec.md:205-220`; `plan.md:284-325` | `Applied Migration` is defined as durable evidence at the checkpointed state, while migration readiness requires `DirectorySynchronized`. | Define applied evidence as directory-synchronized on supported Linux, or use separate committed/checkpointed/applied terms. |
| A11 | Scope | MEDIUM | `spec.md:163,222-234`; `plan.md:194-226` | The plan adds terminal `Superseded` transitions, but FR-008 and domain language define only Draft, Frozen, Implemented, and Verified. | Add Superseded semantics and acceptance criteria to the spec, or remove it from P0. |
| A12 | Consistency | MEDIUM | `plan.md:391-410,450-455`; `tasks.md:62-80`; `lanes.json` | IC-04 is described as depending on IC-01/IC-02 and proceeding independently, but WP06 depends on WP04/WP05 and semantically needs WP07. | Update the concern map and parallel-delivery narrative after repairing A1 so plan and runtime share one DAG. |

## Coverage Summary

| Requirement Key | Has Task? | Work Packages | Notes |
|-----------------|-----------|---------------|-------|
| FR-001 | Yes | WP01, WP09, WP10 | Bootstrap and handoff |
| FR-002 | Yes | WP08, WP09 | Real combined ownership needs A4 repair |
| FR-003 | Yes | WP02, WP05 | Contract and Zig values |
| FR-004 | Yes | WP03, WP08, WP09 | Envelope through both boundaries |
| FR-005 | Yes | WP03 | Additive modules |
| FR-006 | Yes | WP03, WP08 | Composition and runtime inventory |
| FR-007 | Yes | WP03 | Events and fixtures |
| FR-008 | Yes | WP03, WP10 | Closure authority needs A5 repair |
| FR-009 | Yes | WP06 | Sequencing needs A1 repair |
| FR-010 | Yes | WP06 | Sequencing needs A1 repair |
| FR-011 | Yes | WP04 | Pinned ShovelerDB |
| FR-012 | Yes | WP04, WP07 | Adapter and application seam |
| FR-013 | Yes | WP07 | Directory-synchronized acknowledgment |
| FR-014 | Yes | WP07 | Durability uncertainty |
| FR-015 | Yes | WP01, WP03, WP08, WP09, WP10 | Migration command needs A6 repair |
| FR-016 | Yes | WP10 | Program ledger |
| NFR-001 | Yes | WP01, WP09, WP10 | Protocol needs A9 clarification |
| NFR-002 | Yes | WP03, WP10 | Byte determinism |
| NFR-003 | Yes | WP03, WP06, WP10 | Closed mutation inventory exists in prompts |
| NFR-004 | Yes | WP02, WP03, WP05, WP09 | Exact values |
| NFR-005 | Yes | WP07, WP10 | Durability cycles |
| NFR-006 | Yes | WP02, WP05, WP06, WP07 | Coverage gates |
| NFR-007 | Yes | WP08, WP09 | Ordering needs A4 repair |
| NFR-008 | Yes | WP01, WP10 | Protocol needs A9 clarification |
| NFR-009 | Yes | WP03, WP04, WP06, WP07, WP08 | Fail-closed behavior |
| NFR-010 | Yes | WP02, WP03, WP10 | Synthetic evidence and log checks |
| NFR-011 | Yes | WP04, WP10 | Transitive runtime audit |
| NFR-012 | Yes | WP01, WP04, WP10 | Lock ownership needs A2 repair |
| C-001 | Yes | WP04, WP10 | GPL-2.0-only closure |
| C-002 | Yes | WP09 | Presentation boundary |
| C-003 | Yes | WP05, WP06, WP07, WP08 | Zig authority |
| C-004 | Yes | WP04, WP07 | Required store |
| C-005 | Yes | WP04, WP06, WP07 | Single handle |
| C-006 | Yes | WP02, WP05 | Exact money |
| C-007 | Yes | WP03, WP10 | Additive ownership |
| C-008 | Yes | WP10 | No feature absorption |
| C-009 | Yes | WP01, WP04, WP10 | Public reproducibility |
| C-010 | Yes | WP10 | Governed mission merge |

## Charter Alignment Issues

- A1 and A5 conflict with non-negotiable durability and living-documentation
  boundaries and therefore block implementation.
- The detailed WP prompts do include accessibility and Playwright coverage,
  persistence concurrency/shutdown cases, transitive license closure, synthetic
  log checks, and protected-route mutation tests; these are not additional gaps.
- Conventional Commit handoffs are enforced by the Spec Kitty implement-review
  workflow rather than duplicated as a P0 application requirement.

## Unmapped Tasks

None. All 10 work packages carry requirement references and T001-T053 are unique.
The detailed WP prompt files supply the individual subtask descriptions omitted
from the generated `tasks.md` summary.

## Metrics

- Total Requirements: 28 requirements plus 10 binding constraints
- Total Tasks: 53 subtasks in 10 work packages
- Coverage: 100% of FR, NFR, and constraint identifiers map to at least one WP
- Ambiguity Count: 3
- Duplication Count: 0
- Critical Issues Count: 1
- High Issues Count: 6
- Medium Issues Count: 5

## Next Actions

1. Do not begin WP implementation while A1-A7 remain unresolved.
2. Repair the plan, WP ownership/dependencies, and exact command/input contracts.
3. Re-run task finalization so `tasks.md` and `lanes.json` reflect the repaired DAG.
4. Re-run `/spec-kitty.analyze`; implementation may start only after it records a ready verdict.

# Invoice Manager Spec Kitty Program Ledger

- Status: program design approved; missions not yet created
- Program baseline: pending initial repository commit
- Source brief: `docs/planning-brief.md`
- Governance source: `.kittify/charter/charter.md`

## Purpose

This is the cross-mission coordination ledger for the Invoice Manager program.
It does not replace any mission's Spec Kitty state, acceptance gate, review, or
retrospective. It records the dependencies and contracts that allow several
missions to proceed safely at the same time.

Update this ledger whenever a mission is created, a contract is frozen, an
implementation dependency becomes ready, ownership changes, or a mission
merges. Evidence belongs in the owning mission; this document links or
summarizes only the latest authoritative state.

## Program invariants

- Sequence dependencies rather than serializing the program.
- Keep P0 small enough to unblock the feature swarm quickly.
- Specify and plan downstream missions before all implementation dependencies
  are ready.
- Give each mission exclusive primary ownership of its domain paths.
- Treat shared-file edits as integration work with a named owner.
- Use versioned contracts and synthetic fixtures to decouple producers and
  consumers.
- Revalidate every mission against the latest program baseline before
  acceptance.
- Preserve independent mission review, accept, merge, mission-review, and
  retrospective gates.

## Mission board

| ID | Mission handle | State | Implementation dependencies | Contract state | Primary owner | Merge wave |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | TBD | Not created | None | Not drafted | Unassigned | Foundation |
| P1 | TBD | Not created | P0 | Waiting for P0 | Unassigned | A |
| P2 | TBD | Not created | P0 | Waiting for P0 | Unassigned | A |
| P3 | TBD | Not created | P0 | Waiting for P0 | Unassigned | A |
| P4 | TBD | Not created | P0 | Waiting for P0 | Unassigned | A |
| P5 | TBD | Not created | P1 and P2 | Waiting for P1/P2 | Unassigned | B |
| P6 | TBD | Not created | P1 and P2 draft contract | Waiting for P1/P2 | Unassigned | B |
| P7 | TBD | Not created | P4, P5, and P6 | Waiting for P4/P5/P6 | Unassigned | C |
| P8 | TBD | Not created | P3, P5, P6, and P7 | Waiting for all release missions | Unassigned | C |

Allowed states are `Not created`, `Specifying`, `Planning`, `Tasking`,
`Implementing`, `Reviewing`, `Accepted`, `Merged`, `Mission reviewed`,
`Remediating`, and `Closed`. A blocked mission retains its current state and
records the blocker in the dependency register.

## Contract register

| Contract | Owner | Consumers | Version or commit | State | Evidence |
| --- | --- | --- | --- | --- | --- |
| Identifier, money, currency, and date primitives | P0 | P1, P2, P4, P5, P6 | TBD | Not drafted | TBD |
| API envelope and structured error format | P0 | P1-P6 | TBD | Not drafted | TBD |
| Domain event envelope and reporting fixture format | P0 | P1, P4, P5, P6 | TBD | Not drafted | TBD |
| Migration naming and schema-version protocol | P0 | P1-P6 | TBD | Not drafted | TBD |
| Billing identity, client, and project snapshot inputs | P1 | P2, P5, P6 | TBD | Not drafted | TBD |
| Invoice draft, snapshot, preview, and artifact interfaces | P2 | P5, P6 | TBD | Not drafted | TBD |
| Issuance, payment, overdue, and void events | P5 | P7, P8 | TBD | Not drafted | TBD |
| Billing-period, due-work, and draft-proposal events | P6 | P7, P8 | TBD | Not drafted | TBD |
| Backup, restore, and deployment contract | P3 | P8 | TBD | Not drafted | TBD |

Contract states are `Not drafted`, `Draft`, `Frozen`, `Implemented`, `Verified`,
and `Superseded`. A consumer may plan against a draft, implement against a
frozen contract and synthetic fixtures, and pass final acceptance only against
an implemented and verified dependency.

## Ownership and shared touchpoints

Exact paths are established by P0. Until then, these logical boundaries govern
mission plans.

| Surface | Primary mission | Parallel-edit rule |
| --- | --- | --- |
| Root builds, dependency locks, CI, aggregate contract generation | P0, then P7 | Other missions contribute domain fragments and request integration |
| Shared Zig primitives and infrastructure interfaces | P0 | Changes require a versioned contract update and consumer review |
| Identity, client, contact, and project domain/UI | P1 | P1 owns feature paths |
| Invoice document model, renderer, templates, preview UI | P2 | P2 owns feature paths |
| Session, authorization, deployment, backup, restore | P3 | P3 owns platform paths |
| Reporting projections, dashboard API/UI | P4 | P4 owns reporting paths |
| Issuance lifecycle, numbering, payments, retained artifacts | P5 | P5 owns lifecycle paths |
| Scheduling, recurring proposals, due-work UI | P6 | P6 owns scheduling paths |
| Real-producer reporting adapters and reporting E2E tests | P7 | P7 integrates only through frozen P4-P6 contracts |
| Global navigation, deployment composition, release docs and E2E assembly | P8 | P8 integrates after domain owners expose stable entry points |

## Dependency and blocker register

| Consumer | Dependency or blocker | Required state | Current state | Owner | Next evidence |
| --- | --- | --- | --- | --- | --- |
| P1-P4 | P0 shared contracts | Frozen | Not drafted | P0 | P0 spec and contract fixtures |
| P5 | P1 configuration contract and P2 document contract | Implemented | Not drafted | P1/P2 | Contract tests passing on program baseline |
| P6 | P1 project contract and P2 draft interface | Implemented | Not drafted | P1/P2 | Contract tests passing on program baseline |
| P7 | P4 projections and P5/P6 producer events | Verified | Not drafted | P4-P6 | Real-producer projection tests |
| P8 | All release missions | Mission reviewed | Not created | P3, P5-P7 | Mission review verdicts and integration baseline |

## Merge waves

1. **Foundation:** merge P0 after its contract spine and harnesses pass.
2. **Wave A:** run and merge P1, P2, P3, and P4 in dependency-safe
   order; revalidate every mission against the latest merged baseline.
3. **Wave B:** run P5 and P6 concurrently once their consumed contracts are
   implemented.
4. **Wave C:** run P7 against real producer events, then run P8 cross-domain
   acceptance and public-release work.

After every wave, record the baseline commit, run the program integration
checkpoint, and list any remediation mission before opening the next merge
wave.

## Program checkpoints

| Checkpoint | Baseline | Result | Evidence | Open remediation |
| --- | --- | --- | --- | --- |
| Initial repository baseline | Pending | Pending | TBD | None recorded |
| P0 foundation | Pending | Pending | TBD | TBD |
| Wave A integration | Pending | Pending | TBD | TBD |
| Wave B integration | Pending | Pending | TBD | TBD |
| Release candidate | Pending | Pending | TBD | TBD |

## Decision routing

Decision ownership is defined in section 17 of the planning brief. A decision
that changes a shared contract must be recorded before that contract freezes.
Later changes require an explicit compatibility or migration plan and updates
to every affected consumer mission.

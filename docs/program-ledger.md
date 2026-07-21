# Invoice Manager Spec Kitty Program Ledger

- Status: P0 is implementing; WP01-WP11 are approved and WP12 has a local
  GPL-3.0-only source-distribution candidate with all focused and aggregate
  gates passing. Public-repository and GitHub Actions evidence remain pending.
- Review-bearing baseline: accepted WP11 receipt commit
  `97b4094de279a0b568760f2e9a202f98dc64021d`; the WP12 lane was reconciled to
  accepted target `9e16701452bac3883a26ec6b893043de1ac6dff3` before implementation.
- Contract posture: canonical P0 `0.1.0-draft.1` is Frozen at content digest
  `sha256:6ff2126ce659465dfdded2e33aab6fa61c1ded90bf3ef22f2d6daceb30864a15`;
  P1-P4 remain immutable `0.1.0-draft.1` planning inputs.
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

## Planning snapshots

| ID | Mission handle | Target branch | Coordination branch | Planning head | Planning base |
| --- | --- | --- | --- | --- | --- |
| P0 | `p0-contract-spine-01KXYY0J` | `feat/p0-contract-spine` | `kitty/mission-p0-contract-spine-01KXYY0J` | `231b858` | `a71448b` |
| P1 | `p1-parties-projects-01KXYZD3` | `feat/p1-parties-projects` | `kitty/mission-p1-parties-projects-01KXYZD3` | `47638a9` | `ee5ac9e` |
| P2 | `p2-invoice-document-engine-01KXZ0ET` | `feat/p2-invoice-document-engine` | `kitty/mission-p2-invoice-document-engine-01KXZ0ET` | `8830e8b` | `78a7aaa` |
| P3 | `p3-platform-security-operations-01KXZ0Y2` | `feat/p3-platform-security-operations` | `kitty/mission-p3-platform-security-operations-01KXZ0Y2` | `1a83ce0` | `78a7aaa` |
| P4 | `p4-reporting-dashboard-01KXZ1AJ` | `feat/p4-reporting-dashboard` | `kitty/mission-p4-reporting-dashboard-01KXZ1AJ` | `860ee50` | `78a7aaa` |

## Mission board

| ID | Mission handle | Branch | State | Implementation dependencies | Contract state | Primary owner | Merge wave |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P0 | `p0-contract-spine-01KXYY0J` | `feat/p0-contract-spine` | Implementing (WP01-WP11 approved; WP12 local candidate) | None | `0.1.0-draft.1` Frozen | Integration steward | Foundation |
| P1 | `p1-parties-projects-01KXYZD3` | `feat/p1-parties-projects` | Tasking (parked; no WPs) | P0 Frozen and merged | `0.1.0-draft.1` Draft | Parties/projects owner | A1 |
| P2 | `p2-invoice-document-engine-01KXZ0ET` | `feat/p2-invoice-document-engine` | Tasking (parked; no WPs) | P0 and P1 Frozen and merged | `0.1.0-draft.1` Draft | Document-engine owner | A2 |
| P3 | `p3-platform-security-operations-01KXZ0Y2` | `feat/p3-platform-security-operations` | Tasking (parked; no WPs) | P0 Frozen and merged | `0.1.0-draft.1` Draft | Platform owner | A1 |
| P4 | `p4-reporting-dashboard-01KXZ1AJ` | `feat/p4-reporting-dashboard` | Tasking (parked; no WPs) | P0 Frozen and merged; P4 normalized-input review approved | `0.1.0-draft.1` Draft | Reporting owner | A1 |
| P5 | TBD | — | Not created | P1 and P2 | Waiting for P1/P2 | Unassigned | B |
| P6 | TBD | — | Not created | P1 and P2 draft contract | Waiting for P1/P2 | Unassigned | B |
| P7 | TBD | — | Not created | P4, P5, and P6 | Waiting for P4/P5/P6 | Unassigned | C |
| P8 | TBD | — | Not created | P3, P5, P6, and P7 | Waiting for all release missions | Unassigned | C |

Allowed states are `Not created`, `Specifying`, `Planning`, `Tasking`,
`Implementing`, `Reviewing`, `Accepted`, `Merged`, `Mission reviewed`,
`Remediating`, and `Closed`. A blocked mission retains its current state and
records the blocker in the dependency register.

## Contract register

| Contract | Owner | Consumers | Version or commit | State | Evidence |
| --- | --- | --- | --- | --- | --- |
| Identifier, money, currency, date, and digest primitives | P0 | P1, P2, P4, P5, P6 | `0.1.0-draft.1` / `sha256:6ff2126c…` | Frozen | `contracts/manifests/p0.json`; accepted WP11 receipt `97b4094…` |
| API envelope, structured errors, and route-access metadata | P0 | P1-P6 | `0.1.0-draft.1` / `sha256:6ff2126c…` | Frozen | `contracts/manifests/p0.json`; accepted WP11 receipt `97b4094…` |
| Domain event envelope and discriminator catalog | P0 | P1, P3, P4, P5, P6 | `0.1.0-draft.1` / `sha256:6ff2126c…` | Frozen | `contracts/manifests/p0.json`; accepted WP11 receipt `97b4094…` |
| Migration naming, descriptor/script digests, and schema-version protocol | P0 | P1, P3, P4, P5, P6 | `0.1.0-draft.1` / `sha256:6ff2126c…` | Frozen | `contracts/manifests/p0.json`; accepted WP11 receipt `97b4094…` |
| Mutable Resolved Invoice Configuration | P1 | P2, P5, P6 | `0.1.0-draft.1` / `47638a9` | Draft | `feat/p1-parties-projects:kitty-specs/p1-parties-projects-01KXYZD3/contracts/resolved-invoice-configuration-v1.schema.json` |
| Invoice document input; snapshot, preview, digest, and staged-artifact interfaces remain planned | P2 | P5, P6 | `0.1.0-draft.1` / `8830e8b` | Draft | `feat/p2-invoice-document-engine:kitty-specs/p2-invoice-document-engine-01KXZ0ET/contracts/` |
| Backup manifest; restore, auth, and private-deployment contracts remain planned | P3 | P8 | `0.1.0-draft.1` / `1a83ce0` | Draft | `feat/p3-platform-security-operations:kitty-specs/p3-platform-security-operations-01KXZ0Y2/contracts/` |
| Normalized reporting snapshot input | P4 | P7 | `0.1.0-draft.1` / `860ee50` | Draft | `feat/p4-reporting-dashboard:kitty-specs/p4-reporting-dashboard-01KXZ1AJ/contracts/normalized-reporting-snapshot-v1.schema.json` |
| Issuance, payment, overdue, and void events | P5 | P7, P8 | TBD | Not drafted | TBD |
| Billing-period, due-work, and draft-proposal events | P6 | P7, P8 | TBD | Not drafted | TBD |

Contract states are `Not drafted`, `Draft`, `Frozen`, `Implemented`, `Verified`,
and `Superseded`. A consumer may plan against a draft, implement against a
frozen contract and synthetic fixtures, and pass final acceptance only against
an implemented and verified dependency.

## Ownership and shared touchpoints

Exact paths are established by P0. Until then, these logical boundaries govern
mission plans.

| Surface | Primary mission | Parallel-edit rule |
| --- | --- | --- |
| Root builds, dependency locks, CI, aggregate contract generation | P0, then the named program integration steward | Other missions contribute domain fragments and request integration |
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
| P0 tasking | Cross-mission Draft review | Approved | Complete; WP01-WP11 approved and accepted receipt fixed at `97b4094…` | P0/integration steward | Finish WP12 publication evidence, review, accept, and merge |
| P0-P4 task generation | Healthy registered topology and current target branch | Healthy and refreshed per mission gate | Workspace doctor passes; P0 consumed `a71448b`; P1-P4 retain aligned Draft heads but still predate current `main` | Integration steward | Refresh each remaining target branch immediately before generating its WPs; coordination branches remain planning infrastructure |
| P1, P3, P4 | P0 shared contracts | Frozen and merged | `0.1.0-draft.1` Frozen on the WP12 lane; not accepted or merged | P0 | Finish public/CI closure, approve and merge P0, then refresh consumer baselines |
| P2 | P0 shared contracts | Frozen and merged | `0.1.0-draft.1` Frozen on the WP12 lane; not accepted or merged | P0 | Same P0 publication, acceptance, and merge evidence |
| P2 | P1 Resolved Invoice Configuration | Frozen | `0.1.0-draft.1` Draft | P1 | Decision fixtures, schema compatibility, and Frozen P1 manifest |
| P4 | P4 normalized reporting input | Frozen | `0.1.0-draft.1` Draft | P4 | Golden/invalid fixtures and cross-mission Draft review |
| P5 | P1 configuration contract and P2 document contract | Implemented | Not drafted | P1/P2 | Contract tests passing on program baseline |
| P6 | P1 project contract and P2 draft interface | Implemented | Not drafted | P1/P2 | Contract tests passing on program baseline |
| P7 | P4 projections and P5/P6 producer events | Verified | Not drafted | P4-P6 | Real-producer projection tests |
| P8 | All release missions | Mission reviewed | Not created | P3, P5-P7 | Mission review verdicts and integration baseline |

## Merge waves

1. **Foundation:** complete cross-mission Draft review, refresh P0 from `main`,
   then task, implement, accept, and merge P0 only after its real fixtures,
   digests, clean-clone evidence, and contract harnesses pass.
2. **Wave A1:** after P0 is Frozen and merged, implement P1, P3, and P4 in
   parallel. P4 uses its normalized synthetic input seam; P7 owns later producer
   adapters.
3. **Wave A2:** begin P2 implementation after the P1 Resolved Invoice
   Configuration is Frozen and P1 is merged; P2 may overlap the remainder of P3
   and P4 but cannot pass acceptance until its real dependencies are
   Implemented/Verified.
4. **Wave B:** run P5 and P6 concurrently once their consumed contracts are
   implemented.
5. **Wave C:** run P7 against real producer events, then run P8 cross-domain
   acceptance and public-release work.

After every wave, record the baseline commit, run the program integration
checkpoint, and list any remediation mission before opening the next merge
wave.

## Program checkpoints

| Checkpoint | Baseline | Result | Evidence | Open remediation |
| --- | --- | --- | --- | --- |
| Initial repository baseline | `e185ecc` | Pass | Governance, planning brief, canonical GPL-2.0-only license, worktree ignore | P0-P4 feature branches must refresh from this baseline before tasking |
| P0-P4 planning snapshot | `78a7aaa`; heads `84f0be0`, `cf74aae`, `1575fcd`, `c691dd5`, `bb010e4` | Pass for planning only | Five specs, plans, manifests, schemas, and quickstarts | Cross-mission Draft review pending; implementation blocked |
| P0-P4 Draft contract review | Corrected heads `63d0543`, `47638a9`, `8830e8b`, `1a83ce0`, `860ee50` | Ready with corrections applied for P0 tasking | `docs/draft-contract-review-2026-07-20.md`; canonical schemas compile and all five manifests conform | Later-mission correction queue remains gated to each mission's task review |
| P0 task generation | `231b858` | Pass | 12 finalized WPs, complete FR-001–FR-016 coverage, ownership-safe DAG, generated lanes | Implement-review advanced through WP11; WP12 remains active |
| P0 governed documentation sync | `97b4094de279a0b568760f2e9a202f98dc64021d` | Pass | Accepted WP11 receipt `docs/governance/p0-governed-doc-sync.json`; immutable P1-P4 Draft inputs preserved | Receipt commit is fixed and may not be replaced |
| P0 WP12 local foundation candidate | WP12 lane, pre-publication | Local pass | Frozen manifest digest `sha256:6ff2126c…`; focused contracts 5.19s, web 18.37s, API 50.15s, migration-negative 0.61s, persistence 0.34s, HTTP 116.63s, license 0.54s; aggregate `verify:foundation` 148.33s | Exact clean candidate commit, public clone/bootstrap, GitHub Actions, lifecycle Verified, review, accept, and merge remain pending |
| Wave A integration | Pending | Pending | TBD | TBD |
| Wave B integration | Pending | Pending | TBD | TBD |
| Release candidate | Pending | Pending | TBD | TBD |

## Decision routing

Decision ownership is defined in section 17 of the planning brief. A decision
that changes a shared contract must be recorded before that contract freezes.
Later changes require an explicit compatibility or migration plan and updates
to every affected consumer mission.

# Invoice Manager Spec Kitty Program Ledger

- Status: P0 is implementing; WP01-WP11 are approved and WP12 has a
  public-verified GPL-3.0-only source-distribution candidate ready for review.
  Spec Kitty review, acceptance, and merge remain pending.
- Review-bearing baseline: accepted WP11 receipt commit
  `97b4094de279a0b568760f2e9a202f98dc64021d`; the WP12 lane was reconciled to
  accepted target `9e16701452bac3883a26ec6b893043de1ac6dff3` before implementation.
- Contract posture: canonical P0 `0.1.0-draft.1` is Verified at content digest
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

| ID  | Mission handle                             | Target branch                          | Coordination branch                                      | Planning head | Planning base |
| --- | ------------------------------------------ | -------------------------------------- | -------------------------------------------------------- | ------------- | ------------- |
| P0  | `p0-contract-spine-01KXYY0J`               | `feat/p0-contract-spine`               | `kitty/mission-p0-contract-spine-01KXYY0J`               | `231b858`     | `a71448b`     |
| P1  | `p1-parties-projects-01KXYZD3`             | `feat/p1-parties-projects`             | `kitty/mission-p1-parties-projects-01KXYZD3`             | `47638a9`     | `ee5ac9e`     |
| P2  | `p2-invoice-document-engine-01KXZ0ET`      | `feat/p2-invoice-document-engine`      | `kitty/mission-p2-invoice-document-engine-01KXZ0ET`      | `8830e8b`     | `78a7aaa`     |
| P3  | `p3-platform-security-operations-01KXZ0Y2` | `feat/p3-platform-security-operations` | `kitty/mission-p3-platform-security-operations-01KXZ0Y2` | `1a83ce0`     | `78a7aaa`     |
| P4  | `p4-reporting-dashboard-01KXZ1AJ`          | `feat/p4-reporting-dashboard`          | `kitty/mission-p4-reporting-dashboard-01KXZ1AJ`          | `860ee50`     | `78a7aaa`     |

## Mission board

| ID  | Mission handle                             | Branch                                 | State                                                             | Implementation dependencies                               | Contract state                   | Primary owner          | Merge wave |
| --- | ------------------------------------------ | -------------------------------------- | ----------------------------------------------------------------- | --------------------------------------------------------- | -------------------------------- | ---------------------- | ---------- |
| P0  | `p0-contract-spine-01KXYY0J`               | `feat/p0-contract-spine`               | Implementing (WP01-WP11 approved; WP12 public-verified candidate) | None                                                      | `0.1.0-draft.1` Verified         | Integration steward    | Foundation |
| P1  | `p1-parties-projects-01KXYZD3`             | `feat/p1-parties-projects`             | Tasking (parked; no WPs)                                          | P0 Frozen and merged                                      | `0.1.0-draft.1` Draft            | Parties/projects owner | A1         |
| P2  | `p2-invoice-document-engine-01KXZ0ET`      | `feat/p2-invoice-document-engine`      | Tasking (parked; no WPs)                                          | P0 and P1 Frozen and merged                               | `0.1.0-draft.1` Draft            | Document-engine owner  | A2         |
| P3  | `p3-platform-security-operations-01KXZ0Y2` | `feat/p3-platform-security-operations` | Tasking (parked; no WPs)                                          | P0 Frozen and merged                                      | `0.1.0-draft.1` Draft            | Platform owner         | A1         |
| P4  | `p4-reporting-dashboard-01KXZ1AJ`          | `feat/p4-reporting-dashboard`          | Tasking (parked; no WPs)                                          | P0 Frozen and merged; P4 normalized-input review approved | `0.1.0-draft.1` Draft            | Reporting owner        | A1         |
| P5  | Not opened                                 | —                                      | Not created                                                       | P1 and P2                                                 | Waiting for P1/P2                | Unassigned             | B          |
| P6  | Not opened                                 | —                                      | Not created                                                       | P1 and P2 draft contract                                  | Waiting for P1/P2                | Unassigned             | B          |
| P7  | Not opened                                 | —                                      | Not created                                                       | P4, P5, and P6                                            | Waiting for P4/P5/P6             | Unassigned             | C          |
| P8  | Not opened                                 | —                                      | Not created                                                       | P3, P5, P6, and P7                                        | Waiting for all release missions | Unassigned             | C          |

Allowed states are `Not created`, `Specifying`, `Planning`, `Tasking`,
`Implementing`, `Reviewing`, `Accepted`, `Merged`, `Mission reviewed`,
`Remediating`, and `Closed`. A blocked mission retains its current state and
records the blocker in the dependency register.

## Contract register

| Contract                                                                                         | Owner | Consumers          | Version or commit                    | State       | Evidence                                                                                                                         |
| ------------------------------------------------------------------------------------------------ | ----- | ------------------ | ------------------------------------ | ----------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Identifier, money, currency, date, and digest primitives                                         | P0    | P1, P2, P4, P5, P6 | `0.1.0-draft.1` / `sha256:6ff2126c…` | Verified    | `contracts/manifests/p0.json`; accepted WP11 receipt `97b4094…`; public run `29881539727`                                        |
| API envelope, structured errors, and route-access metadata                                       | P0    | P1-P6              | `0.1.0-draft.1` / `sha256:6ff2126c…` | Verified    | `contracts/manifests/p0.json`; accepted WP11 receipt `97b4094…`; public run `29881539727`                                        |
| Domain event envelope and discriminator catalog                                                  | P0    | P1, P3, P4, P5, P6 | `0.1.0-draft.1` / `sha256:6ff2126c…` | Verified    | `contracts/manifests/p0.json`; accepted WP11 receipt `97b4094…`; public run `29881539727`                                        |
| Migration naming, descriptor/script digests, and schema-version protocol                         | P0    | P1, P3, P4, P5, P6 | `0.1.0-draft.1` / `sha256:6ff2126c…` | Verified    | `contracts/manifests/p0.json`; accepted WP11 receipt `97b4094…`; public run `29881539727`                                        |
| Mutable Resolved Invoice Configuration                                                           | P1    | P2, P5, P6         | `0.1.0-draft.1` / `47638a9`          | Draft       | `feat/p1-parties-projects:kitty-specs/p1-parties-projects-01KXYZD3/contracts/resolved-invoice-configuration-v1.schema.json`      |
| Invoice document input; snapshot, preview, digest, and staged-artifact interfaces remain planned | P2    | P5, P6             | `0.1.0-draft.1` / `8830e8b`          | Draft       | `feat/p2-invoice-document-engine:kitty-specs/p2-invoice-document-engine-01KXZ0ET/contracts/`                                     |
| Backup manifest; restore, auth, and private-deployment contracts remain planned                  | P3    | P8                 | `0.1.0-draft.1` / `1a83ce0`          | Draft       | `feat/p3-platform-security-operations:kitty-specs/p3-platform-security-operations-01KXZ0Y2/contracts/`                           |
| Normalized reporting snapshot input                                                              | P4    | P7                 | `0.1.0-draft.1` / `860ee50`          | Draft       | `feat/p4-reporting-dashboard:kitty-specs/p4-reporting-dashboard-01KXZ1AJ/contracts/normalized-reporting-snapshot-v1.schema.json` |
| Issuance, payment, overdue, and void events                                                      | P5    | P7, P8             | Not drafted                          | Not drafted | P5 mission specification and contract artifacts must be created after P1/P2 merge                                                |
| Billing-period, due-work, and draft-proposal events                                              | P6    | P7, P8             | Not drafted                          | Not drafted | P6 mission specification and contract artifacts must be created after P1/P2 contract readiness                                   |

Contract states are `Not drafted`, `Draft`, `Frozen`, `Implemented`, `Verified`,
and `Superseded`. A consumer may plan against a draft, implement against a
frozen contract and synthetic fixtures, and pass final acceptance only against
an implemented and verified dependency.

## Ownership and shared touchpoints

Exact paths are established by P0. Until then, these logical boundaries govern
mission plans.

| Surface                                                                  | Primary mission                                | Parallel-edit rule                                                 |
| ------------------------------------------------------------------------ | ---------------------------------------------- | ------------------------------------------------------------------ |
| Root builds, dependency locks, CI, aggregate contract generation         | P0, then the named program integration steward | Other missions contribute domain fragments and request integration |
| Shared Zig primitives and infrastructure interfaces                      | P0                                             | Changes require a versioned contract update and consumer review    |
| Identity, client, contact, and project domain/UI                         | P1                                             | P1 owns feature paths                                              |
| Invoice document model, renderer, templates, preview UI                  | P2                                             | P2 owns feature paths                                              |
| Session, authorization, deployment, backup, restore                      | P3                                             | P3 owns platform paths                                             |
| Reporting projections, dashboard API/UI                                  | P4                                             | P4 owns reporting paths                                            |
| Issuance lifecycle, numbering, payments, retained artifacts              | P5                                             | P5 owns lifecycle paths                                            |
| Scheduling, recurring proposals, due-work UI                             | P6                                             | P6 owns scheduling paths                                           |
| Real-producer reporting adapters and reporting E2E tests                 | P7                                             | P7 integrates only through frozen P4-P6 contracts                  |
| Global navigation, deployment composition, release docs and E2E assembly | P8                                             | P8 integrates after domain owners expose stable entry points       |

## Dependency and blocker register

| Consumer              | Dependency or blocker                                 | Required state                         | Current state                                                                                                     | Owner                  | Next evidence                                                                                                                    |
| --------------------- | ----------------------------------------------------- | -------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ---------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| P0 tasking            | Cross-mission Draft review                            | Approved                               | Complete; WP01-WP11 approved, receipt fixed at `97b4094…`, and WP12 public evidence green                         | P0/integration steward | Review, accept, and merge WP12/P0                                                                                                |
| P0-P4 task generation | Healthy registered topology and current target branch | Healthy and refreshed per mission gate | Workspace doctor passes; P0 consumed `a71448b`; P1-P4 retain aligned Draft heads but still predate current `main` | Integration steward    | Refresh each remaining target branch immediately before generating its WPs; coordination branches remain planning infrastructure |
| P1, P3, P4            | P0 shared contracts                                   | Frozen and merged                      | `0.1.0-draft.1` Verified on the WP12 lane; not accepted or merged                                                 | P0                     | Review, accept, and merge P0, then refresh consumer baselines                                                                    |
| P2                    | P0 shared contracts                                   | Frozen and merged                      | `0.1.0-draft.1` Verified on the WP12 lane; not accepted or merged                                                 | P0                     | Same P0 review, acceptance, merge, and baseline refresh                                                                          |
| P2                    | P1 Resolved Invoice Configuration                     | Frozen                                 | `0.1.0-draft.1` Draft                                                                                             | P1                     | Decision fixtures, schema compatibility, and Frozen P1 manifest                                                                  |
| P4                    | P4 normalized reporting input                         | Frozen                                 | `0.1.0-draft.1` Draft                                                                                             | P4                     | Golden/invalid fixtures and cross-mission Draft review                                                                           |
| P5                    | P1 configuration contract and P2 document contract    | Implemented                            | Not drafted                                                                                                       | P1/P2                  | Contract tests passing on program baseline                                                                                       |
| P6                    | P1 project contract and P2 draft interface            | Implemented                            | Not drafted                                                                                                       | P1/P2                  | Contract tests passing on program baseline                                                                                       |
| P7                    | P4 projections and P5/P6 producer events              | Verified                               | Not drafted                                                                                                       | P4-P6                  | Real-producer projection tests                                                                                                   |
| P8                    | All release missions                                  | Mission reviewed                       | Not created                                                                                                       | P3, P5-P7              | Mission review verdicts and integration baseline                                                                                 |

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

## P0 closure evidence

WP03's lifecycle tool promoted the canonical manifest from Implemented SHA-256
`16e74ea6cf81e5cf1ebd998ef1543c48eb01c65c2f4e0d0dd673daa5d69a941f`
to Verified SHA-256
`def2cc7f3d54595b4af123fd6d5e44ee0d2dbaa4a094a2802c52a22be4d1b3e4`.
The immutable content digest stayed
`sha256:6ff2126ce659465dfdded2e33aab6fa61c1ded90bf3ef22f2d6daceb30864a15`.
The transition consumed candidate
`57b3724f63b3600d1bd84fbb744561ace19b9e6d`, accepted WP11 receipt
`97b4094de279a0b568760f2e9a202f98dc64021d`, and closure-evidence digest
`sha256:59b953c4c36f8596263014c445ae1ceebd3b2da47d987e28e9229b3bedac7b89`.

| Gate                    | Evidence ID                                            | SHA-256 of evidence bytes                                          |
| ----------------------- | ------------------------------------------------------ | ------------------------------------------------------------------ |
| Foundation CI           | `github-actions-run:29881539727`                       | `a05d6025c04dcc16c78e160ce283b640c6bbf5ffef55df69f643b76eacdf3038` |
| Bootstrap foundation    | `github-actions-job:88803305129`                       | `2ddb01bd27a73147a0884b266f659b2db0b0c06c847fdfde743f4aca29097597` |
| Verify foundation clean | `github-actions-job:88803305124`                       | `b219d491d56cb782d7e74f0052825871d4b4ddb97c079b0d94f67971fafc2e32` |
| Proxy performance       | `github-actions-job:88803305126`                       | `9e67f53a913afe775c0377319aeaf9100e043ee13b6fd4238ee6bba2a597a2a5` |
| Runtime license         | `github-actions-job:88803305108`                       | `40fe4189a84bf5487d8d19c31c32fb36536fc237e5a0230e510e20f72c3972a1` |
| Public clean clone      | `github-public-tag:p0-implemented-57b3724f`            | `4edda8125d6438cf2169e2134bcc9850132f671a7ff845486bf6e6b0c7e553ee` |
| P1-P4 conformance       | `github-actions-job:88803305110`                       | `bb1ec2603cce21b6a2a0d41b065cb97680d466b93c7d3084d6d8505f31361e18` |
| Governed-document drift | `git-receipt:97b4094de279a0b568760f2e9a202f98dc64021d` | `7e80784b275e9686a4b51a7b3c467adac244792241997388cfdf47eb03760260` |

The Foundation workflow completed successfully at the exact candidate on
[`main`](https://github.com/LynnColeArt/invoice-manager/actions/runs/29881539727)
and
[`feat/p0-contract-spine`](https://github.com/LynnColeArt/invoice-manager/actions/runs/29881539752).
Both runs contain ten successful foundation jobs plus a successful
`foundation / required` conclusion. The main run began at `00:53:17Z` and
completed at `00:59:16Z` on 2026-07-22.

| Main-run job                        | Job ID        | Started     | Completed   | Result  |
| ----------------------------------- | ------------- | ----------- | ----------- | ------- |
| `foundation / api`                  | `88803305093` | `00:53:20Z` | `00:55:32Z` | Success |
| `foundation / web`                  | `88803305095` | `00:53:20Z` | `00:54:17Z` | Success |
| `foundation / migration-negative`   | `88803305106` | `00:53:20Z` | `00:54:54Z` | Success |
| `foundation / runtime-license`      | `88803305108` | `00:53:20Z` | `00:53:53Z` | Success |
| `foundation / contracts`            | `88803305110` | `00:53:20Z` | `00:54:07Z` | Success |
| `foundation / verify-clean`         | `88803305124` | `00:53:20Z` | `00:59:10Z` | Success |
| `foundation / http-proxy`           | `88803305126` | `00:53:20Z` | `00:57:50Z` | Success |
| `foundation / bootstrap-clean`      | `88803305129` | `00:53:20Z` | `00:59:07Z` | Success |
| `foundation / persistence`          | `88803305137` | `00:53:20Z` | `00:54:46Z` | Success |
| `foundation / aggregate-diagnostic` | `88803305139` | `00:53:20Z` | `00:59:04Z` | Success |
| `foundation / required`             | `88804134412` | `00:59:13Z` | `00:59:15Z` | Success |

The clean jobs ran on GitHub's `ubuntu-24.04` image with four logical AMD EPYC
7763 CPUs, at least 16 GiB RAM, Node.js 24.18.0, npm 11.16.0, and Zig 0.16.0.
Both provisioned Playwright Chromium and headless-shell revision 1228 inside
their empty-cache timed boundaries. Bootstrap recorded 320.665 seconds
internally and 326.706 seconds externally; verify-clean recorded 326.696
seconds internally and 331.845 seconds externally. Both are below 15 minutes.
The public proxy job's exact 100 sequential samples had nearest-rank p99
20.275 ms, maximum 22.765 ms, `slow=0`, and `invalid=0`. A supplemental local
four-core `taskset` run of literal `npm run http:smoke` passed every real Ready,
stopped, invalid, adversarial, performance, and cleanup phase with p99 9.790 ms,
`slow=0`, and `invalid=0`.

Evidence digests are reproducible from canonical bytes. The Foundation digest
is the sorted JSON projection produced by:

```bash
gh run view 29881539727 --repo LynnColeArt/invoice-manager \
  --json databaseId,headBranch,headSha,event,status,conclusion,url,createdAt,startedAt,updatedAt,jobs \
  --jq '{id:.databaseId,branch:.headBranch,sha:.headSha,event,status,conclusion,url,createdAt,startedAt,updatedAt,jobs:[.jobs|sort_by(.databaseId)[]|{id:.databaseId,name,status,conclusion,startedAt,completedAt}]}' \
  | jq -cS . | sha256sum
```

Each job digest hashes the raw response body from
`gh api repos/LynnColeArt/invoice-manager/actions/jobs/JOB_ID/logs`. The public
ref digest hashes the byte-sorted unauthenticated output of:

```bash
env -u GH_TOKEN -u GITHUB_TOKEN GIT_TERMINAL_PROMPT=0 \
  git -c credential.helper= ls-remote --refs \
  https://github.com/LynnColeArt/invoice-manager.git \
  refs/heads/main refs/heads/feat/p0-contract-spine \
  refs/tags/p0-implemented-57b3724f | LC_ALL=C sort | sha256sum
```

All three public refs resolved to `57b3724f63b3600d1bd84fbb744561ace19b9e6d`.
A fresh unauthenticated recursive detached clone of the tag was clean at Git
tree `060a7c0e89cfb598b9851cf7e2ef5d5056b70815`. The governed-document digest
hashes the raw receipt blob from
`git show 97b4094de279a0b568760f2e9a202f98dc64021d:docs/governance/p0-governed-doc-sync.json`;
the receipt's exact `commands.drift` completed with no difference.

### Immutable P1-P4 conformance inputs

`contracts/conformance/p0-p4-inputs.json` remained unchanged. Public contracts
job `88803305110` validated all four exact Draft pins; Draft conformance does
not make any downstream mission Implemented, Accepted, or Merged.

| Owner | Commit                                     | Manifest SHA-256                                                   | Content digest                                                     |
| ----- | ------------------------------------------ | ------------------------------------------------------------------ | ------------------------------------------------------------------ |
| P1    | `47638a9d95427697c1fcc74c7279f40f314450f5` | `3f28ddb033e5259163671b34c8c64f6214c5524f0f941e4dc5d03c38485a7987` | `73457636636187ff5537564a0f13ed29030d931746dbcc2740da3636cb2747f5` |
| P2    | `8830e8bbdfb1a7ecb92015359aa28c58d9f2b078` | `24bf9f15fad1d598fae394e5ec40e7a50e6f166e7bd1202e3c51c4576c89bbc7` | `c12f5c79c21689f146c705cef5b454bca684e5e86e0ac7a326df8dc7db1f9a70` |
| P3    | `1a83ce0523ccc793c62d7bcd3b6992eb761ec506` | `1b2013f7876a0015af7a18ed9bdc89675520c7dcf0c68f98253357af5c96c11f` | `48d85d152ab9e46efd052c4e3b02dba47a8e6bbfeac8315864cc6d470d274bf3` |
| P4    | `860ee50cd959e75391753cafe841b4da82882a0b` | `2da1496e68aa9577a91af647af34268181c9a58ff5aec529cc71121db4159a24` | `453c138255cd525587a07049a04576c9d22919979c0c2ac45ce37f46e2e54636` |

## Program checkpoints

| Checkpoint                                 | Baseline                                                                  | Result                                        | Evidence                                                                                                                                                                                                         | Open remediation                                                                     |
| ------------------------------------------ | ------------------------------------------------------------------------- | --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Initial repository baseline                | `e185ecc`                                                                 | Pass                                          | Governance, planning brief, canonical GPL-2.0-only license, worktree ignore                                                                                                                                      | P0-P4 feature branches must refresh from this baseline before tasking                |
| P0-P4 planning snapshot                    | `78a7aaa`; heads `84f0be0`, `cf74aae`, `1575fcd`, `c691dd5`, `bb010e4`    | Pass for planning only                        | Five specs, plans, manifests, schemas, and quickstarts                                                                                                                                                           | Cross-mission Draft review pending; implementation blocked                           |
| P0-P4 Draft contract review                | Corrected heads `63d0543`, `47638a9`, `8830e8b`, `1a83ce0`, `860ee50`     | Ready with corrections applied for P0 tasking | `docs/draft-contract-review-2026-07-20.md`; canonical schemas compile and all five manifests conform                                                                                                             | Later-mission correction queue remains gated to each mission's task review           |
| P0 task generation                         | `231b858`                                                                 | Pass                                          | 12 finalized WPs, complete FR-001–FR-016 coverage, ownership-safe DAG, generated lanes                                                                                                                           | Implement-review advanced through WP11; WP12 remains active                          |
| P0 governed documentation sync             | `97b4094de279a0b568760f2e9a202f98dc64021d`                                | Pass                                          | Accepted WP11 receipt `docs/governance/p0-governed-doc-sync.json`; immutable P1-P4 Draft inputs preserved                                                                                                        | Receipt commit is fixed and may not be replaced                                      |
| P0 WP12 initial local foundation candidate | WP12 lane, pre-publication                                                | Local pass                                    | Implemented manifest digest `sha256:6ff2126c…`; focused contracts 5.19s, web 18.37s, API 50.15s, migration-negative 0.61s, persistence 0.34s, HTTP 116.63s, license 0.54s; aggregate `verify:foundation` 148.33s | Superseded by the exact public candidate below after producer and runner corrections |
| P0 WP12 public verification                | `57b3724f63b3600d1bd84fbb744561ace19b9e6d`; tag `p0-implemented-57b3724f` | Pass; canonical manifest Verified             | Main run `29881539727`, feature run `29881539752`, required jobs green, clean wrappers below 15 minutes, proxy p99 20.275 ms, deterministic GPL-3.0-only report, conformance=4, governed drift clean             | Spec Kitty WP12 review, P0 accept, and P0 merge remain pending                       |
| Wave A integration                         | Not started                                                               | Waiting on P0 merge                           | P1, P3, and P4 baselines must be refreshed from merged P0 before their implementation work packages are generated                                                                                                | P0 integration steward must complete WP12 review, mission acceptance, and merge      |
| Wave B integration                         | Not started                                                               | Waiting on P1/P2 implementation               | P5 and P6 missions do not yet exist; their specifications and contracts must consume the merged P1/P2 outputs                                                                                                    | P1/P2 owners must finish Wave A2 before the program opens P5/P6                      |
| Release candidate                          | Not started                                                               | Waiting on Waves A-C                          | No release-candidate evidence exists until P3 and P5-P8 complete their acceptance and public-release gates                                                                                                       | Program integration steward must complete all dependency waves and release review    |

## Decision routing

Decision ownership is defined in section 17 of the planning brief. A decision
that changes a shared contract must be recorded before that contract freezes.
Later changes require an explicit compatibility or migration plan and updates
to every affected consumer mission.

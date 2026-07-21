# P0-P4 Cross-Mission Draft Contract Review

- Review date: 2026-07-20
- Point-cut: post-plan, before P0 task generation
- Verdict at reviewed heads: **Not ready for P0 tasking**
- Review question: Are the P0-P4 Draft specs, plans, contracts, and manifests
  coherent enough to task P0 without freezing incompatible shared primitives,
  fakeable gates, ownership collisions, or unstable integration seams?

## Reviewed snapshots

| Mission | Immutable planning head |
| --- | --- |
| P0 Contract Spine | `84f0be0` |
| P1 Parties and Projects | `cf74aae` |
| P2 Invoice Document Engine | `1575fcd` |
| P3 Platform Security and Operations | `c691dd5` |
| P4 Reporting Dashboard | `bb010e4` |

The review used three independent doctrine lenses: architecture and bounded
contexts, adversarial contract and test quality, and work-package sequencing.
All three reached the same verdict. No implementation source existed or was
reviewed.

## Convergent blockers

1. **One canonical contract manifest is missing.** P0 publishes a strict
   lifecycle schema, while P1-P4 use a mutually incompatible vocabulary. The
   canonical form also cannot record all swarm metadata required by the
   planning brief and permits non-Draft states with pending or empty evidence.
2. **Shared primitives are documentary rather than executable.** P1-P4 copy
   identifier, money, date, instant, revision, and digest definitions locally;
   several copies are weaker than P0. Consumers must resolve canonical P0
   schema identifiers and P0 must compose representative real Draft fragments.
3. **Composition inputs are underspecified.** P0 promises API, event, module
   mount, and collision validation without defining the normative owner-scoped
   contribution document, event discriminator catalog, route-access metadata,
   discovery paths, or reference-resolution rules.
4. **The durability name exceeds the recorded guarantee.** P0 acknowledges a
   successful checkpoint as durable while its research routes missing
   parent-directory synchronization after snapshot rename to P3. The P0
   acknowledgment boundary must include Linux parent-directory synchronization
   or use a weaker state name and block consequential consumers.
5. **Migration integrity is ambiguous.** The schema and data model disagree on
   `script` versus `script_path`, and one checksum does not state whether it
   protects the descriptor, the script, or both.
6. **The P0 branch is stale relative to the program baseline.** P0 must refresh
   from current `main` after these review findings are recorded. Spec Kitty's
   registered coordination worktrees are healthy; tasking belongs in the
   refreshed target-branch checkout, not in a coordination worktree.
7. **P0 concern ownership needs a sharper slice.** The substrate, web shell,
   Zig service, storage adapter, and closure gate currently imply overlapping
   root and CI ownership. Work packages must use exclusive paths, with one
   explicit final cross-cutting acceptance package.

## Required P0 dispositions

- Extend one P0-owned manifest schema to record lifecycle, exact base commit,
  inputs, outputs, dependencies, owned paths, shared touchpoints, migration
  strategy, and integration fixtures. Define `baseline_commit` as the exact
  program base consumed by planning, never as the self-referential commit
  containing the manifest.
- Make non-Draft lifecycle states reject pending digests. The runtime freeze
  gate must additionally verify normalized repository-relative unique paths,
  files and digests, at least one valid and one invalid integration fixture,
  dependency states, and legal state transitions.
- Give P0 common values stable final schema identifiers and add the shared
  digest type. Replace downstream copies with external references before
  considering the Draft review resolved.
- Define convention-scanned owner module manifests, OpenAPI fragments with
  explicit access metadata, event catalogs that bind envelope discriminators to
  payload schemas, migrations, fixtures, and ignored generated aggregates.
- Make protected the default route posture. Public operations, including P0
  health, must be explicit and inventory-visible to P3 without a hand-written
  global allowlist.
- Define descriptor and script digests separately and test mutation of every
  applied descriptor field.
- Include parent-directory synchronization after ShovelerDB checkpoint rename
  in P0's Linux durability boundary; failed synchronization returns durability
  unconfirmed. Verify orderly reopen, injected sync failures, and process-crash
  boundaries.
- Refresh P0 from the review-bearing `main` baseline, then generate dependency-
  safe, ownership-disjoint work packages.

## Later-mission correction queue

These findings do not expand P0 business scope, but each must be resolved before
the named mission is tasked or frozen:

- **P1/P2:** Encode the complete billing-market/remittance decision matrix so
  Domestic and Other/Hide cannot contain bank data and Europe cannot omit it.
- **P1:** Repair the closed `Party`/`Client` composition and define the billing
  contact shape.
- **P2:** Reject zero quantities such as `0.0`, prohibit negative business
  amounts where required, and condition tax fields on treatment.
- **P3:** Reject leading and embedded traversal path segments at runtime, make
  backup contract inventory extensible to all installed contracts, and resolve
  the persisted-CSRF-digest versus raw-token-after-reload contradiction.
- **P4:** Bind wrapper `source_kind` to payload `kind` and remove duplicated P0
  aggregate identity/revision or enforce an exact equality rule.
- **Ledger:** Describe P2 and P3 artifacts as partially drafted until their
  planned snapshot/artifact and auth/deployment contracts exist.

## Approval rule

This review becomes **Ready with corrections applied** for P0 tasking only when
the required P0 dispositions are committed, P1-P4 manifests conform to the
canonical Draft shape, downstream shared primitives reference P0, the P0 target
branch is refreshed from the review-bearing baseline, and the task finalizer
reports complete requirement coverage with no unresolved ownership errors.

The overall mission topology was affirmed: P0 first; P1, P3, and P4 after P0;
P2 after P1; then P5/P6, P7, and P8 at their recorded dependency gates.

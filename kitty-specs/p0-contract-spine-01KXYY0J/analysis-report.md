---
schema_version: 1
artifact_type: spec-kitty.analysis-report
command: /spec-kitty.analyze
mission_slug: p0-contract-spine-01KXYY0J
mission_id: 01KXYY0J76QBNSWXX0SHMZNXC4
generated_at: '2026-07-20T16:32:48.637468+00:00'
analyzer_agent: unknown
input_artifacts:
  spec.md:
    path: /home/lynn/projects/invoice-manager/kitty-specs/p0-contract-spine-01KXYY0J/spec.md
    sha256: 146a017a06ca340ce653e04d36e2f4f7825e444fcaed2666258089dc21cff18b
  plan.md:
    path: /home/lynn/projects/invoice-manager/kitty-specs/p0-contract-spine-01KXYY0J/plan.md
    sha256: 308d6220e81c4a941f29462854c7891b30d114ea965c8f295dae5bebb05f9afa
  tasks.md:
    path: /home/lynn/projects/invoice-manager/kitty-specs/p0-contract-spine-01KXYY0J/tasks.md
    sha256: 663bee04a212a49c2c32f23ab6a99725c7f8c8858587a61fbc5bb81f30082581
  charter:
    path: /home/lynn/projects/invoice-manager/.kittify/charter/charter.md
    sha256: a1176517b273e322d3dc408e369ef836c40e3bb84c69ae140ad554cffbb53f0f
verdict: blocked
issue_counts:
  medium: 7
  low: 1
  critical: 5
  high: 8
  info: 0
findings:
- id: B1
  severity: critical
  category: charter
  summary: WP04 persistence and checkpoint behavior lacks mandatory chronological red-first evidence.
- id: B2
  severity: critical
  category: charter
  summary: WP10 implements a proxy security boundary without mandatory failing behavior tests before production changes.
- id: B3
  severity: critical
  category: privacy
  summary: WP04 permits raw engine diagnostics in internal logs despite the charter sensitive-logging prohibition.
- id: B4
  severity: critical
  category: governance
  summary: Quickstart omits the mandatory migration-negative command and violates living-document synchronization.
- id: B5
  severity: critical
  category: dependency
  summary: Ownership collapse produces a cyclic execution-lane projection despite an acyclic WP graph.
- id: B6
  severity: high
  category: dependency
  summary: WP07 consumes the WP03 migration schema without depending on WP03.
- id: B7
  severity: high
  category: reproducibility
  summary: WP03 adds workspace package metadata after WP01 freezes the root lock and cannot run cleanly before WP10.
- id: B8
  severity: high
  category: validation
  summary: WP04 cannot classify positive migration tests or enforce WP07 migration coverage.
- id: B9
  severity: high
  category: integration
  summary: Generated TypeScript has no stable materialization command ordered before web consumers compile.
- id: B10
  severity: high
  category: integration
  summary: WP08 has no defined build-time bridge from WP03 composed route metadata to the Zig runtime inventory.
- id: B11
  severity: high
  category: execution
  summary: WP03 requires a nonexistent profile file instead of the canonical profile loader.
- id: B12
  severity: high
  category: testability
  summary: WP10 must pass a full acceptance timer before downstream WP11 creates one of its required gates.
- id: B13
  severity: high
  category: governance
  summary: The lifecycle event log still projects superseded 10-WP identities and dependencies.
- id: B14
  severity: medium
  category: testability
  summary: Accessibility acceptance lacks a named conformance level and measurable violation or contrast thresholds.
- id: B15
  severity: medium
  category: governance
  summary: The mandatory governed-document sync has no exact operation or committed receipt contract.
- id: B16
  severity: medium
  category: consistency
  summary: WP02 still assigns generated TypeScript responsibilities to metadata-only WP09.
- id: B17
  severity: medium
  category: validation
  summary: WP05 permits alternate build-hook names despite the exact stable WP04 command contract.
- id: B18
  severity: medium
  category: performance
  summary: The timed NFR-008 aggregate does not concretely include clean dependency resolution.
- id: B19
  severity: medium
  category: consistency
  summary: Research says always checkpoint before close while dirty or uncertain recovery must discard without checkpoint.
- id: B20
  severity: medium
  category: validation
  summary: WP05's documented shell sequence changes into the same relative directory repeatedly and cannot execute as written.
- id: B21
  severity: low
  category: governance
  summary: Two reviewer checklists refer to transient wps.yaml instead of committed task authority.
---

## Specification Analysis Report

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| B1 | Charter | CRITICAL | `.kittify/charter/charter.md:9`; `tasks/WP04-*.md:300-346` | Adapter persistence, serialization, checkpoint, close, and reopen behavior is not explicitly red-first. | Require named public-adapter failing cases and chronological red/green Activity Log evidence before production behavior. |
| B2 | Charter | CRITICAL | `.kittify/charter/charter.md:9`; `tasks/WP10-*.md:226-256` | The SSRF/open-redirect/origin-disclosure boundary lacks pre-production failing tests. | Require red-first attacker-input, redirect, origin-leak, timeout, and safe-failure proxy cases. |
| B3 | Privacy | CRITICAL | `.kittify/charter/charter.md:91`; `tasks/WP04-*.md:317` | Detailed engine prose is allowed in internal logs and may contain SQL, paths, or future user data. | Production logs must contain stable categories/correlation data only; add sentinel leak tests. |
| B4 | Governance | CRITICAL | `quickstart.md:32-44`; `spec.md:179`; `plan.md:342-345`; charter `DIRECTIVE_037` | The independently diagnosable command list omits `npm run migration:negative`. | Add the literal command through governed-doc sync and keep quickstart, CI, and closure matrices identical. |
| B5 | Dependency | CRITICAL | `lanes.json:8-25,144-184,187-243` | WP01/WP10 and WP03/WP11 overlap collapse creates `lane-a↔lane-b`, `lane-c↔lane-h`, and other cycles. | Reslice shared-file authority so early and late WPs remain separate, then regenerate and assert an acyclic lane graph. |
| B6 | Dependency | HIGH | `plan.md:515-537`; `tasks.md:73-80`; `tasks/WP07-*.md:4-7,90` | WP07 requires the WP03-owned migration schema but omits WP03. | Add WP03/IC-03 as an explicit dependency or move schema production upstream. |
| B7 | Reproducibility | HIGH | `tasks/WP01-*.md:184-200,294-301`; `tasks/WP03-*.md:55-57,132-139,326-327` | WP03 creates workspace metadata after WP01 freezes the root lock but cannot update it. | Predeclare workspace metadata before the lock or introduce an acyclic earlier lock integration. |
| B8 | Validation | HIGH | `spec.md:191`; `tasks/WP04-*.md:220-255`; `tasks/WP07-*.md:37-38,399-401,440` | Positive migration tests are unclassified and migration code is absent from coverage. | Add stable migration unit/integration/negative groups plus nonzero 90% migration coverage and critical-branch inventory. |
| B9 | Integration | HIGH | `tasks/WP03-*.md:320-344,402-415`; `tasks/WP10-*.md:205-221,298-316` | Ignored TypeScript output is not materialized by a stable command before typecheck/build. | Publish one WP03 generation command and make web checks invoke it first. |
| B10 | Integration | HIGH | `tasks/WP03-*.md:282-308`; `tasks/WP08-*.md:234-247,349-366` | Zig route inventory has no implementable bridge from composed contract metadata. | Define one deterministic generated/runtime interface and order its materialization before HTTP compilation/tests. |
| B11 | Execution | HIGH | `tasks/WP03-*.md:79-88` | The prompt points at absent `.kittify/agent-profiles/node-norris.md`. | Use the canonical profile-load capsule and governed implement action. |
| B12 | Testability | HIGH | `tasks/WP10-*.md:256-288,327-336`; `tasks/WP11-*.md:182-203` | WP10 claims final NFR-001 acceptance before WP11 creates the license gate included in validation. | WP10 supplies the proxy/performance harness; WP11 owns final NFR-001/NFR-008 acceptance. |
| B13 | Governance | HIGH | `status.events.jsonl:10-18`; `tasks.md:62-124` | Lifecycle events retain deleted prompt identities, old dependencies, and a 10-WP completion count. | Rebuild through supported lifecycle tooling; never hand-edit the append-only event log. |
| B14 | Testability | MEDIUM | `tasks/WP10-*.md:168,265` | Accessibility criteria are qualitative. | Require WCAG 2.2 AA, zero configured automated violations, numeric contrast, keyboard, zoom, and overflow assertions. |
| B15 | Governance | MEDIUM | `plan.md:685-698`; `tasks/WP11-*.md:97-101,347-374` | Closure cannot verify the planning sync reproducibly. | Define the exact operation, receipt path/schema, baseline commit, artifact list, no-change rationale, and drift command. |
| B16 | Consistency | MEDIUM | `tasks/WP02-*.md:77-80,116-118,312-320` | WP02 names WP09 as generator/browser owner. | Name WP03 as generator/exporter and WP10 as browser consumer; keep WP09 metadata/config-only. |
| B17 | Validation | MEDIUM | `tasks/WP05-*.md:362-365`; `plan.md:333-345` | WP05 allows renamed equivalents for stable hooks. | Require the literal WP04 hook names and route absence upstream. |
| B18 | Performance | MEDIUM | `spec.md:199-216`; `quickstart.md:20-25`; `tasks/WP01-*.md:254-258`; `tasks/WP11-*.md:182-203` | `npm ci` sits outside the timed aggregate. | Define one clean wrapper that includes dependency resolution and every required gate. |
| B19 | Consistency | MEDIUM | `research.md:167-173`; `tasks/WP06-*.md:289-311` | “Always checkpoint” contradicts fail-safe dirty-handle discard. | Limit checkpoint-before-close to ordinary successful shutdown and exempt dirty/uncertain recovery. |
| B20 | Validation | MEDIUM | `tasks/WP05-*.md:354-360` | Repeated `cd services/api` commands fail after the first directory change. | Use one directory change followed by the exact commands or isolated subshells. |
| B21 | Governance | LOW | `tasks/WP09-*.md:231`; `tasks/WP10-*.md:353` | Reviewer guidance cites uncommitted `wps.yaml`. | Cite committed `tasks.md`, prompt frontmatter, and `lanes.json`. |

## Coverage Summary

| Requirement Key | Has Task? | Task IDs | Notes |
|-----------------|-----------|----------|-------|
| FR-001–FR-016 | Yes | T001–T054 | All functional requirements map to at least one WP. |
| NFR-001–NFR-012 | Yes | T001–T054 | Coverage exists; B8, B12, B14, and B18 affect enforceability. |
| C-001–C-010 | Yes | T001–T054 | All binding constraints map to at least one WP. |

## Charter Alignment Issues

- B1 and B2 violate the charter's mandatory TDD boundary.
- B3 violates the sensitive-data logging prohibition.
- B4 violates Living Documentation Sync.

## Unmapped Tasks

None. T001–T054 are unique and all 11 WPs carry requirement references.

## Metrics

- Total Requirements: 38
- Total Tasks: 54
- Coverage: 100%
- Ambiguity Count: 7
- Duplication Count: 0
- Critical Issues Count: 5

## Next Actions

1. Do not begin implementation while B1–B13 remain unresolved.
2. Repair the lane-safe ownership model, dependency/build/materialization contracts, charter TDD/logging rules, and governed docs.
3. Re-finalize tasks, rebuild lifecycle projection through supported commands, and verify lane acyclicity.
4. Re-run and record `/spec-kitty.analyze`; implementation may start only with a ready verdict.

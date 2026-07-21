---
schema_version: 1
artifact_type: spec-kitty.analysis-report
command: /spec-kitty.analyze
mission_slug: p0-contract-spine-01KXYY0J
mission_id: 01KXYY0J76QBNSWXX0SHMZNXC4
generated_at: '2026-07-21T14:45:07.567455+00:00'
analyzer_agent: Codex
input_artifacts:
  spec.md:
    path: /tmp/invoice-analysis-record.uJnhBn/kitty-specs/p0-contract-spine-01KXYY0J/spec.md
    sha256: cbf96c32d255558dd1464b73a21ad4d101c171f0e3af45823b85823dfbf87420
  plan.md:
    path: /tmp/invoice-analysis-record.uJnhBn/kitty-specs/p0-contract-spine-01KXYY0J/plan.md
    sha256: e115aa7d51ec98694f475a4fe589e5124a4a56296c9322bdd602afcb40546ce3
  tasks.md:
    path: /tmp/invoice-analysis-record.uJnhBn/kitty-specs/p0-contract-spine-01KXYY0J/tasks.md
    sha256: 1213ecc62e23f3c79e51d8c2f7a13178be2a192dc42f3f48e97989e4ff4cbfd5
  charter:
    path: /tmp/invoice-analysis-record.uJnhBn/.kittify/charter/charter.md
    sha256: a1176517b273e322d3dc408e369ef836c40e3bb84c69ae140ad554cffbb53f0f
verdict: blocked
issue_counts:
  medium: 0
  high: 3
  critical: 1
  low: 0
  info: 0
findings:
- id: I1
  severity: critical
  category: inconsistency
  summary: WP10 must consume the accepted WP09 proxy unchanged while also producing red-first security evidence and changing that proxy, but its owned files contain no enforceable public proxy boundary.
- id: C1
  severity: high
  category: coverage
  summary: The required bare web:check and http:smoke gates have no runtime-origin/startup contract even though the accepted Next config fails when INVOICE_MANAGER_API_ORIGIN is absent.
- id: C2
  severity: high
  category: coverage
  summary: The accepted external rewrite cannot enforce WP10 redirect rejection, bounded timeout, or canonical safe-failure requirements from any WP10-owned file.
- id: U1
  severity: high
  category: underspecification
  summary: The pinned Playwright browser revision is neither installed by the immutable npm graph nor declared as a reproducible prerequisite, so the required clean smoke gate cannot run.
---

## Specification Analysis Report

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| I1 | Inconsistency / charter alignment | CRITICAL | `plan.md:635-649,705-720`; `WP09:145-170,197-204`; `WP10:89-103,215-244` | WP09 owns and has already implemented the external rewrite. WP10 is forbidden to edit configuration and must consume it unchanged, yet T046 requires a public-boundary RED before each production proxy change and then requires WP10 to implement the fixed-origin security boundary. WP10 owns no Route Handler path. This makes the charter-required red-first security-boundary proof and black-box Playwright acceptance impossible. | Choose one structural owner before implementation. Recommended: reopen WP09 to remove the external rewrite and make configuration runtime-compatible, expand WP10 ownership/create-intent to an App Router `api/v1/[...path]/route.ts` boundary, then let WP10 add failing same-origin redirect/timeout/SSRF cases before implementing the new handler. Update plan, tasks, and both WP prompts together. |
| C1 | Coverage / gate contract | HIGH | `spec.md:27-48,165-166,179,186,193`; `WP10:237-240,261-266,284-307`; accepted WP01 root `web:check`/`http:smoke`; accepted WP09 `next.config.ts:5-47` | Both required commands are specified as bare commands, but no command or Playwright config supplies `INVOICE_MANAGER_API_ORIGIN` or defines the Zig/Next startup handoff. The accepted config throws while loading if the variable is absent, and the current shell is unset. The independently runnable web and smoke gates therefore fail before exercising WP10 behavior. | Define one deterministic gate-owned lifecycle: fixed synthetic API port or a harness that starts Zig, waits for Ready, supplies a server-only origin to production Next, and shuts both down. Route root-script changes to WP01 and config startup/env changes to WP09; reflect the exact bare-command contract in WP10. |
| C2 | Coverage / architecture | HIGH | `WP10:224-246`; accepted WP09 `next.config.ts:49-56` | The accepted Next external rewrite delegates to framework proxy behavior. It forwards upstream redirects/Location, uses a framework-scale timeout, and emits a noncanonical proxy failure. WP10's owned client/server presentation adapters cannot change the observable public `/api/v1/*` rewrite behavior, so redirect rejection, bounded duration, origin-safe failure, and preserved canonical envelope requirements have no implementable task. | Replace the external rewrite with the owned Route Handler boundary described in I1. Pin redirect mode, request deadline, response/body limits, cache policy, origin disclosure rules, and canonical failure mapping in executable public-boundary tests. |
| U1 | Underspecification / reproducibility | HIGH | `spec.md:186,193,197,201-211`; `WP09:165-170`; `WP10:261-266,286-307`; accepted Playwright config | Playwright 1.61.1 pins Chromium/headless-shell revision 1228, but the host cache contains only 1223/1217 and neither `npm ci`, the root scripts, nor the quickstart installs revision 1228. The required Playwright smoke is therefore not reproducible from the declared clean graph. | Route a pinned browser-install/prerequisite command to WP01 and the documented bootstrap/clean-validation protocol. Keep the Playwright-managed revision; do not silently fall back to unpinned system Chrome. Record whether browser installation is a prerequisite or part of the measured clean bootstrap. |

### Coverage Summary

| Requirement Key | Has Task? | Task IDs | Notes |
|-----------------|-----------|----------|-------|
| FR-001 documented bootstrap | Yes | WP01, WP09, WP10, WP12 | Blocked at WP10 gate lifecycle and browser prerequisite. |
| FR-002 runnable service boundary | Yes | WP08, WP10, WP12 | Zig boundary exists; same-origin web boundary is blocked. |
| FR-003 shared value representations | Yes | WP02, WP05 | Covered. |
| FR-004 structured response contract | Yes | WP03, WP08, WP10 | Public proxy safe-failure mapping is not implementable in current ownership. |
| FR-005 additive module contracts | Yes | WP03 | Covered. |
| FR-006 collision detection | Yes | WP03, WP08 | Covered. |
| FR-007 event and fixture envelope | Yes | WP03 | Covered. |
| FR-008 contract lifecycle manifest | Yes | WP03, WP12 | Covered. |
| FR-009 parallel-safe migrations | Yes | WP07 | Covered. |
| FR-010 migration integrity | Yes | WP07 | Covered. |
| FR-011 reproducible storage dependency | Yes | WP04 | Covered. |
| FR-012 serialized storage seam | Yes | WP04, WP06 | Covered. |
| FR-013 durable acknowledgement | Yes | WP06 | Covered. |
| FR-014 durability uncertainty | Yes | WP06 | Covered. |
| FR-015 independent validation gates | Yes | WP01, WP03, WP04, WP08, WP10, WP11, WP12 | Web/smoke gate entry contracts are currently incomplete. |
| FR-016 program ownership evidence | Yes | WP11, WP12 | Covered after producer correction. |
| NFR-001 first-run time | Yes | WP01, WP10, WP12 | Browser install and process lifecycle are undefined inside/outside measurement. |
| NFR-002 deterministic composition | Yes | WP03, WP12 | Covered. |
| NFR-003 collision rejection | Yes | WP03, WP07, WP12 | Covered. |
| NFR-004 numeric fidelity | Yes | WP02, WP03, WP10 | Covered by WP10 client work once unblocked. |
| NFR-005 durability cycles | Yes | WP06, WP12 | Covered. |
| NFR-006 critical branch coverage | Yes | WP02, WP04, WP05, WP06, WP07 | Covered. |
| NFR-007 health responsiveness | Yes | WP08, WP10, WP12 | Same-origin harness is blocked by I1/C1. |
| NFR-008 validation duration | Yes | WP01, WP12 | Browser acquisition boundary needs definition. |
| NFR-009 failure safety | Yes | WP03, WP04, WP06, WP07, WP08 | Covered. |
| NFR-010 synthetic evidence | Yes | WP02, WP03, WP11, WP12 | Covered. |
| NFR-011 license cleanliness | Yes | WP04, WP12 | Covered. |
| NFR-012 reproducible dependency graph | Yes | WP01, WP04, WP09, WP10, WP12 | npm graph is pinned; Playwright executable artifact is not provisioned. |

### Charter Alignment Issues

- I1 conflicts with the charter's mandatory TDD rule for security boundaries and its required real Playwright workflow. The conflict must be corrected in plan/tasks; the charter must not be weakened.
- C1/C2 conflict with the charter rule that required validation gates may not be skipped or silently replaced by mocks.
- U1 conflicts with the required reproducible, green Playwright quality gate.

### Unmapped Tasks

None. Every WP maps to at least one approved requirement, but mapping alone does not make WP10 executable under its current ownership contract.

### Metrics

- Total requirements: 28
- Total work packages: 12
- Requirement coverage: 100% have at least one mapped WP
- Ambiguity/underspecification findings: 1
- Inconsistency findings: 1 critical
- Coverage-gap findings: 2 high
- Critical issues: 1

### Next Actions

1. Do not start WP10 implementation while this report is blocked.
2. Reconcile plan/task ownership around a real App Router proxy handler and preserve red-first public-boundary chronology.
3. Route the gate lifecycle and pinned Playwright browser prerequisite to WP01/WP09, then revalidate the exact bare commands.
4. Re-run Spec Kitty analysis after the corrected artifacts and upstream packages are reviewed.

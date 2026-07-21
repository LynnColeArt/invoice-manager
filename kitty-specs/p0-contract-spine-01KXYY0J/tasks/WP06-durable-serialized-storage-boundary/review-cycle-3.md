---
affected_files: []
cycle_number: 3
mission_slug: p0-contract-spine-01KXYY0J
reproduction_command:
reviewed_at: '2026-07-21T08:31:15Z'
reviewer_agent: codex
verdict: rejected
wp_id: WP06
---

---
affected_files:
  - services/api/src/platform/persistence/store.zig
  - services/api/src/platform/persistence/diagnostics.zig
  - services/api/tests/persistence/store_test.zig
  - services/api/tests/persistence/durability_coverage_test.zig
blocking_findings: 1
cycle_number: 3
implementation_commit: 8f0bded353a94da9762f2ae8705e4e370ce13dae
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T08:30:00Z'
reviewed_lane_tip: 5c5ffeb110e97f322838d7ad06b7bd2b8a0f76e5
reviewer_agent: 'codex:reviewer-renata:integration-correction'
verdict: rejected
wp_id: WP06
---

# WP06 Review Cycle 3 — DEPENDENCY-INTEGRATION CORRECTION REQUIRED

WP06 cycle 2 remains valid for its approved durability, capability, recovery,
and coverage claims. WP07 review exposed one missing migration-agnostic public
capability that makes the dependent migration boundary unable to fail closed.

## B1 — the public Store cannot prove first initialization is genuinely fresh

ShovelerDB maps a missing table, unknown column, and malformed object shape to
the same stable object-error category. `Store` exposes no immutable open origin
and no atomic first-initialization operation. Consequently WP07 cannot
distinguish a genuinely newly created database from an existing database whose
migration-history table was deleted or malformed. Treating every missing-object
error as fresh can recreate history over nonempty/corrupt storage; treating all
of them as corruption makes safe first bootstrap impossible.

Required correction:

1. Add a narrow, application-neutral `Store.initializeFresh` operation that
   executes a `StartupWriteOperation` only when the canonical database path was
   absent after lease acquisition and immediately before adapter open, and no
   Store operation has yet completed durably.
2. Perform the eligibility check and callback under the existing Store mutex.
   Return a typed `not_fresh` outcome without running the callback otherwise.
   Do not expose a path, adapter, raw handle, or race-prone `wasCreated` boolean.
3. Existing empty files are not fresh. Allocation, callback, rollback,
   commit, checkpoint, directory-sync, reopen, shutdown, and capability rules
   must remain identical to the approved startup-write boundary.
4. Add permanent red-first public-facade tests for newly created success,
   existing-empty denial, existing-nonempty denial, second-call denial,
   concurrent denial, failure recovery, durability completion, and cleanup.
5. Preserve the exact WP06 owned-PC coverage threshold and all previously
   approved Debug/ReleaseSafe, crash, adapter, and ABI regression gates.

This is an upstream dependency correction for WP07's rejected ambiguous
bootstrap finding. It does not authorize migration-specific schema, descriptor,
SQL, readiness, or replay logic inside WP06.

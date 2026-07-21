---
affected_files:
  - package.json
blocking_findings: 2
cycle_number: 3
implementation_commit: 46d7aadf47713812c4a0628f0f4f0da1dc63136a
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T15:00:13Z'
reviewed_lane_tip: 46d7aadf47713812c4a0628f0f4f0da1dc63136a
reviewer_agent: 'codex:gpt-5:reviewer-renata:reviewer'
verdict: rejected
wp_id: WP01
review_artifact_override_at: "2026-07-21T15:25:29Z"
review_artifact_override_actor: "operator"
review_artifact_override_wp_id: "WP01"
review_artifact_override_reason: "Arbiter override: superseded rejected review-cycle-3 is closed by committed parseable approval review-cycle-7 at 4e8f592 after independent empty-cache rev1228 provisioning, idempotency, exact substrate, ownership, and immutable-hash verification; implementation e89d3bb passes all corrective requirements."
---

# WP01 Review Cycle 3

Verdict: **REJECT**

This is a governed upstream correction triggered by persisted mission analysis, not a
regression in the previously approved dependency graph.

## Blocking findings

1. **The locked Playwright package does not provision its matching browser artifact.**
   `@playwright/test` is pinned at `1.61.1`, whose Chromium/headless-shell revision is 1228,
   but neither the root command surface nor the clean bootstrap installs it. The required
   bare and clean E2E gates therefore depend on undeclared machine state.
2. **The bare HTTP smoke does not own a complete production lifecycle.** It delegates directly
   to Playwright without an unconditional production build, exact browser provisioning, or a
   WP10-owned Zig/Next/adversarial child-process harness.

## Required correction

- Implement prompt subtask T058 in `package.json` only.
- Add exact locked `browser:install` delegation and make `http:smoke` generate contracts, build
  production web output, install the pinned browser, then invoke
  `apps/web/tests/foundation/http-smoke.mjs`.
- Update substrate assertions for the corrected command contract.
- Leave both workspace manifests and `package-lock.json` byte-identical.
- Prove revision 1228 from an empty isolated browser cache and reject every system-browser
  fallback.

Reapproval requires chronological missing-browser RED evidence, corrected delegation GREEN
evidence, exact changed-path proof, and immutable manifest/lock hashes.

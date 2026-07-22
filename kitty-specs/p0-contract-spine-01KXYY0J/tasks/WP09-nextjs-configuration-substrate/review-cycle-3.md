---
affected_files: []
cycle_number: 3
mission_slug: p0-contract-spine-01KXYY0J
reproduction_command:
reviewed_at: '2026-07-21T15:01:13Z'
reviewer_agent: codex-wp09-lock-review
verdict: rejected
wp_id: WP09
---

---
affected_files:
  - apps/web/next.config.ts
blocking_findings: 2
cycle_number: 2
implementation_commit: 289cbb4b5ae5ed276cf8944e1585ce0879fe407f
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T15:00:13Z'
reviewed_lane_tip: 289cbb4b5ae5ed276cf8944e1585ce0879fe407f
reviewer_agent: 'codex:gpt-5:reviewer-renata:reviewer'
verdict: rejected
wp_id: WP09
---

# WP09 Review Cycle 2

Verdict: **REJECT**

The previous static review was accurate for the old task contract. Persisted cross-artifact
analysis proved that contract incompatible with the public security boundary assigned to WP10.

## Blocking findings

1. **Configuration loading eagerly requires `INVOICE_MANAGER_API_ORIGIN`.** Literal bare
   `npm run web:check` has no runtime origin and therefore cannot satisfy its process-free
   format/lint/type/component/build contract.
2. **The external rewrite preempts WP10's public RED-first boundary.** Next.js owns redirect,
   timeout, body, and failure behavior outside every WP10-owned file, so WP10 cannot first make
   public attacker cases fail and then implement the production fix.

## Required correction

- Implement prompt subtask T059 in `apps/web/next.config.ts` only.
- Remove eager origin parsing and the external `/api/v1/:path*` rewrite.
- Preserve unrelated accepted Next settings and the other four config files byte-for-byte.
- Prove config/build loading is origin-independent through static WP09 evidence; WP10 owns the
  later literal runtime gates and App Router handler.
- Leave root metadata, both workspace manifests, and `package-lock.json` byte-identical.

Reapproval requires a one-file substantive diff, no origin/rewrite token in Next config, exact
locked-dependency re-attestation, and no runtime acceptance overclaim.

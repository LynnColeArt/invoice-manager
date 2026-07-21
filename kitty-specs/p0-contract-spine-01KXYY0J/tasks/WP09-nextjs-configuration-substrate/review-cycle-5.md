---
affected_files:
  - apps/web/next.config.ts
  - apps/web/tsconfig.json
blocking_findings: 5
cycle_number: 5
implementation_commit: 50295b884652f2f4067c605fc707b831ce08f3e0
mission_slug: p0-contract-spine-01KXYY0J
reproduction_command: 'See committed review-cycle-4.md for exact static, build, source, and path probes.'
reviewed_at: '2026-07-21T15:50:57Z'
reviewed_lane_tip: 9b8707dac7ddcf4c025c18f55a85a92060d3b2d9
reviewer_agent: 'codex-wp09-review:reviewer-renata'
verdict: rejected
wp_id: WP09
---

# WP09 Review Cycle 5

Verdict: **REJECT**

This is the parseable formal rollback pointer generated for the transition to `planned`.
The complete evidence, exact hashes, source inspection, path matrix, anti-pattern checklist,
and subtask disposition are committed in sibling artifact `review-cycle-4.md` and are incorporated
here by reference. The generated wrapper originally nested cycle 4 behind a second YAML document;
this file repairs only that serialization defect and does not change the verdict or findings.

## Required corrections

1. Make `apps/web/tsconfig.json` stable under exact locked Next 16.2.10 by including ES2024,
   setting `jsx: "react-jsx"`, setting `incremental: true`, and adding
   `.next/dev/types/**/*.ts`; preserve all unrelated strict settings.
2. Add `skipTrailingSlashRedirect: true` to `apps/web/next.config.ts` while retaining no eager
   origin read and no external rewrite.
3. Assign or explicitly ignore generated `apps/web/next-env.d.ts` in mission ownership before
   reapproval; WP10 must not silently absorb the unowned path.
4. Route Next's unavoidable pre-handler raw repeated-slash/backslash 308, encoded-dot 404, and
   `/api/v1[/]` route gap to planning/WP10; these are not a WP09-only config fix.
5. Re-run the exact static inventory and a disposable clean double-build, proving both configs
   remain byte-stable and package metadata, both workspace manifests, and the lock remain exact.

The proven candidate reference hashes are
`edd7c53f09f208e547ecb9f5fae6b8dbe60298b08d6e3ab52112a3942e95392c` for tsconfig and
`a6fbd459fab2c5103b177f0d50d19e7941e006a91a7aece417be37ecd6319496` for Next config.
They are evidence targets, not authorization to skip independent validation.

No arbiter override was used or required. The narrow eager-origin/rewrite deletion in `50295b8`
passed; the complete WP09 substrate remains rejected for the five blockers above.

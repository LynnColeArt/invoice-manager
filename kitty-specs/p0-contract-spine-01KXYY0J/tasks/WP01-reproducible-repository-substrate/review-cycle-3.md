---
affected_files: []
cycle_number: 3
mission_slug: p0-contract-spine-01KXYY0J
reproduction_command:
reviewed_at: '2026-07-20T23:01:35Z'
reviewer_agent: codex
verdict: rejected
wp_id: WP01
---

# WP01 correction feedback: newly published js-yaml advisory

WP01 was correctly approved against the registry/audit state available at that time. A fresh immutable install on 2026-07-20 now reports four high findings through the direct development tool `@hey-api/openapi-ts@0.99.0`:

- `@hey-api/json-schema-ref-parser@1.4.4` pins `js-yaml@4.2.0`;
- GitHub-reviewed advisory `GHSA-52cp-r559-cp3m` / `CVE-2026-59869` marks `js-yaml >=4.0.0 <4.3.0` affected and `4.3.0` patched;
- `npm audit --json` reports the affected direct/transitive chain and proposes an unsafe generator rollback to `@hey-api/openapi-ts@0.97.0` because the upstream package still pins `js-yaml@4.2.0` exactly.

Required owned correction:

1. Keep the approved exact direct tool graph, including `@hey-api/openapi-ts@0.99.0`.
2. Add the narrowest exact npm override that resolves only this parser chain to `js-yaml@4.3.0`; do not use a floating range or broad dependency churn.
3. Update WP01's exact substrate assertion for the approved override map.
4. Regenerate only `package-lock.json` under Node `24.18.0` / npm `11.16.0`, with install scripts disabled except the existing allowlist policy.
5. Prove the lock contains `js-yaml@4.3.0` at the affected parser edge, public registry resolution, SHA-512 integrity, and no unexpected direct-version change.
6. Run immutable `npm ci`, `npm audit --audit-level=high`, `npm ls --all`, `verify:substrate`, license checks, and the existing WP01 validation matrix.
7. Rerun WP03 contract generation/check/determinism and statically revalidate WP09's lock/integrity assumptions after the lock correction; no downstream source change is expected.
8. Record the pre-fix audit JSON and post-fix zero-high audit as correction-cycle evidence.

This is a time-of-check correction caused by a newly published advisory, not a defect in the original review evidence.

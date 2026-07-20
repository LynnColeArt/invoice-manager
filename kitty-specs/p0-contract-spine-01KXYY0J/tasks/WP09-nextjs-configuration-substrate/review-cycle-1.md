---
affected_files: []
cycle_number: 1
mission_slug: p0-contract-spine-01KXYY0J
reproduction_command:
reviewed_at: '2026-07-20T23:37:28Z'
reviewer_agent: codex
verdict: rejected
wp_id: WP09
---

# WP09 dependency revalidation required

WP01 was reopened after publication of GHSA-52cp-r559-cp3m and corrected its exact transitive `js-yaml` resolution from 4.2.0 to 4.3.0 while retaining every direct web dependency. WP09 was approved against the former root lock bytes, so its static declaration/lock/integrity attestation must be refreshed even though all five WP09-owned configuration files are expected to remain byte-identical.

Perform only WP09-authorized read-only static checks: confirm the five configs are unchanged, every app declaration remains an exact full version with matching public-registry lock resolution and SHA-512 integrity, both workspace links and the WP03 export remain exact, the patched `js-yaml` lock and override are present, syntax/strictness/server-only policy remain valid, and no install tree or generated side effect exists. Do not run package tools or install dependencies.

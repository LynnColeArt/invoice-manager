---
affected_files:
  - apps/web/next.config.ts
  - apps/web/tsconfig.json
blocking_findings: 5
cycle_number: 4
implementation_commit: 50295b884652f2f4067c605fc707b831ce08f3e0
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T15:49:45Z'
reviewed_lane_tip: 9b8707dac7ddcf4c025c18f55a85a92060d3b2d9
reviewer_agent: 'codex-wp09-review:reviewer-renata'
verdict: rejected
wp_id: WP09
---

# WP09 Review Cycle 4

Verdict: **REJECT**

The narrow T059 correction in `50295b8` is correct: it removes only the eager origin parser and
external rewrite, preserves the four other accepted configs, and passes the exact static
metadata/lock checks. WP09 nevertheless remains incompatible with WP10's literal production
build and public-path contract, so it cannot be approved.

## Passing evidence that must be preserved

- Approved WP01 commit `e89d3bb` is an ancestor through dependency merge `9f7403f`; accepted
  WP02 and WP03 implementation ancestry is also present.
- The substantive corrective commit changes exactly `apps/web/next.config.ts`, with 54
  deletions and no additions. `git diff --check` passes.
- Root `package.json` is exactly
  `816264f8552943384dad5e4a72502b95c8975568487308115dc5481298a37bfd` and the corrected Next
  config is exactly `413cf432c7fcc61c12240566f9fc286b1aaa971f18c4c2d28f9170a58f439a3d`.
- `apps/web/package.json`, `tools/contracts/package.json`, and `package-lock.json` retain their
  accepted hashes. ESLint, TypeScript, Vitest, and Playwright configs remain byte-identical to
  accepted commit `c396d18`.
- Pinned Node `v24.18.0` syntax and JSON checks pass. All 20 exact app declarations map to the
  canonical lock: 19 external public-registry entries have matching versions and SHA-512
  integrity, and the contracts declaration resolves through the expected workspace link/export.
- The Next config contains none of `API_ORIGIN_ENVIRONMENT_VARIABLE`, `readApiOrigin`,
  `apiOrigin`, `process.env`, `rewrites`, `destination`, or `/api/v1/:path*`.
- No package metadata, lock, source, generated output, dependency tree, or build artifact was
  changed in the reviewed lane. This review makes no runtime acceptance claim for WP09.

## Blocking findings

### 1. The accepted TypeScript config is not build-stable

In a disposable clean clone of the corrected lane with exact Node 24.18.0, npm 11.16.0, and
locked Next 16.2.10, a minimal WP10 App Router shell followed by literal
`npm run build --workspace @invoice-manager/web` rewrites WP09-owned `tsconfig.json`:

- mandatory `jsx: "preserve"` becomes `jsx: "react-jsx"`;
- suggested `incremental: true` is added; and
- `.next/dev/types/**/*.ts` is added to `include`.

Locked `next/dist/lib/typescript/writeConfigurationDefaults.js` independently confirms all
three behaviors and writes the file whenever any action is missing. WP10 is required to consume
WP09 configuration byte-identically, so this mutation is a blocking dependency defect.

### 2. The production build fails under the accepted library surface

The same literal build exits 1 at
`node_modules/next/dist/client/components/segment-cache/cache.d.ts:104:21` with
`Cannot find name 'PromiseWithResolvers'`. Current `lib` stops at ES2023 and
`skipLibCheck` is deliberately false. Exact locked TypeScript 6.0.3 defines
`PromiseWithResolvers` in `lib.es2024.promise.d.ts`; the present config therefore cannot satisfy
the exact locked Next type surface.

### 3. Next preempts the canonical trailing-slash rejection

Current `next.config.ts` omits `skipTrailingSlashRedirect`. Locked Next 16.2.10
`load-custom-routes.js` installs a priority internal `/:path+/` permanent redirect when that
option is false or absent; the exact redirect-status implementation maps permanent to 308.
Consequently `/api/v1/health/` is answered before WP10's Route Handler and cannot return T046's
canonical local error envelope.

### 4. `next-env.d.ts` has no explicit owner or ignore decision

The clean production build generates unowned and unignored `apps/web/next-env.d.ts` containing
Next image types and an import of `./.next/types/routes.d.ts`. WP09 currently prohibits creating
generated declarations, WP10 does not own the path, and the repository does not ignore it.
This side effect must receive an explicit ownership/commit or routed-ignore decision; WP10 must
not silently absorb an out-of-map file.

### 5. Some T046 literal paths never reach the Route Handler

Exact production path probes with trailing-slash redirects disabled show:

- `/api/v1/health/` reaches the catch-all with its raw trailing slash preserved;
- `/api/v1[/]` requires a sibling route rather than the current catch-all;
- raw repeated slash and backslash are framework-normalized with 308 before route matching;
- a single encoded `..` segment is answered by the framework with 404; and
- encoded slash/backslash variants reach the handler.

Locked `base-server.js` independently confirms unconditional pre-routing 308 normalization for
raw `//` and backslash, with no relevant config guard. This portion cannot be fixed solely by
WP09. Planning/WP10 acceptance must state which framework-owned responses are admissible or
move the public boundary outside Next's pre-router; the Route Handler must not claim envelopes
for requests it never receives.

## Required correction and routing

1. In WP09-owned `tsconfig.json`, use the exact locked-build-stable values:
   `lib` including ES2024, `jsx: "react-jsx"`, `incremental: true`, and
   `.next/dev/types/**/*.ts` in `include`. Preserve every unrelated strict setting.
2. In WP09-owned `next.config.ts`, add `skipTrailingSlashRedirect: true` while retaining the
   runtime-neutral, no-origin, no-rewrite boundary.
3. Resolve `apps/web/next-env.d.ts` explicitly in mission ownership/ignore artifacts before
   reapproval; do not assign it implicitly to WP10.
4. Route the raw repeated-slash/backslash, encoded-dot, and `/api/v1[/]` observations to
   planning/WP10. They are not implementable as a WP09 config-only fix.
5. Re-run the exact static declaration/lock inventory and immutable-input hashes. In a disposable
   integration preflight, delete `.next`, build twice, and prove both configs remain byte-stable.
   A proven corrected candidate produced stable hashes
   `edd7c53f09f208e547ecb9f5fae6b8dbe60298b08d6e3ab52112a3942e95392c` for tsconfig and
   `a6fbd459fab2c5103b177f0d50d19e7941e006a91a7aece417be37ecd6319496` for Next config.
6. Do not edit either workspace manifest, root metadata, or the canonical lock.

## Superseded artifact handling

Review cycle 3 is a stale mechanically wrapped duplicate of cycle 2 with two YAML document
headers. It is preserved unchanged as historical evidence. This parseable cycle-4 rejection is
the current review authority and points the formal rollback directly to this file; no arbiter
override is used or required.

## Anti-pattern checklist

1. Dead code: **PASS** - T059 only deletes obsolete code and adds no public function or module.
2. Synthetic-fixture test: **N/A** - WP09 owns static configuration, while behavioral tests are
   WP10-owned.
3. Silent empty return: **PASS** - the correction introduces no empty fallback.
4. FR coverage: **FAIL** - the exact build and canonical public-path preconditions are not
   satisfiable with the accepted configs.
5. Frozen surface: **PASS** - `50295b8` changes only the owned Next config; the required follow-up
   must remain inside explicit ownership decisions.
6. Locked decision: **FAIL** - default framework redirects currently preempt the locked WP10
   canonical-envelope boundary.
7. Shared-file ownership: **PASS** - dependency merge and substantive config commit remain
   separately attributable; `next-env.d.ts` is rejected pending an explicit owner.
8. Production fragility: **PASS** - T059 adds no production raise or transient request path.

## Subtask disposition

- T042: **FAIL** - exact locked Next/TypeScript integration proves the accepted config is neither
  production-build-stable nor type-compatible and leaves a generated path unowned.
- T059: **PASS (narrowly)** - eager origin parsing and external rewrite removal are correct, but
  they do not make the complete WP09 substrate approvable.

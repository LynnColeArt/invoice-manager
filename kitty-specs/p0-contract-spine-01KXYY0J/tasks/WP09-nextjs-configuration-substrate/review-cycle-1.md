---
affected_files:
  - path: apps/web/eslint.config.mjs
  - path: apps/web/next.config.ts
  - path: apps/web/playwright.config.ts
  - path: apps/web/tsconfig.json
  - path: apps/web/vitest.config.ts
blocking_findings: 0
cycle_number: 1
implementation_commit: c396d1895ed620f82c386f148fc27813e4adebbb
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-20T22:32:06Z'
reviewed_lane_tip: 5d7d8765e2c3d5fd072f4dd4bd87acc717e023a7
reviewer_agent: 'codex:gpt-5:reviewer-renata:reviewer'
verdict: approved
wp_id: WP09
---

# WP09 Review Cycle 1

Verdict: **APPROVE**

Implementation commit: `c396d1895ed620f82c386f148fc27813e4adebbb`.

WP09 stays within its configuration-only boundary and provides a deterministic substrate for
WP10 without claiming runtime acceptance. No blocking findings were identified.

## Changed-path and ownership gate

- The substantive parent-to-implementation diff contains exactly the five mapped
  `apps/web/*config*` files: 217 additions and no other path.
- The review-start merge does not alter those five files after the implementation commit.
- `git diff --check` passes.
- No package manifest, lock, npm policy, version file, contract, generated output, app source,
  app test, dependency tree, framework output, cache, coverage, screenshot, or build artifact is
  present in the WP diff.
- `apps/web/` contains only WP01's package manifest and WP09's five configuration files; no
  `src/`, `tests/`, `node_modules/`, `.next/`, or generated surface exists.

## Exact declaration, lock, integrity, and workspace inventory

The reviewer reparsed the root manifest, app manifest, contract-workspace manifest, and root
lock read-only. All 20 app declarations are exact full versions. Each of the 19 external rows
maps to `node_modules/<package>` at the identical version, a public
`https://registry.npmjs.org/` resolution, and SHA-512 integrity. The cached bytes for every one
of those 19 external artifacts independently hash to the exact lock integrity value.

| Package | Exact declaration | Configuration relationship | Lock result |
| --- | --- | --- | --- |
| `@invoice-manager/contracts` | `0.0.0` | stable WP03 export consumer | workspace link to `tools/contracts`; `./v1` export verified |
| `@axe-core/playwright` | `4.12.1` | reserved for WP10 accessibility evidence | exact registry version and SHA-512 match |
| `@playwright/test` | `1.61.1` | E2E config API and `playwright` CLI | exact registry version and SHA-512 match |
| `@testing-library/dom` | `10.4.1` | reserved for WP10 tests | exact registry version and SHA-512 match |
| `@testing-library/jest-dom` | `6.9.1` | reserved for WP10 tests | exact registry version and SHA-512 match |
| `@testing-library/react` | `16.3.2` | reserved for WP10 tests | exact registry version and SHA-512 match |
| `@testing-library/user-event` | `14.6.1` | reserved for WP10 tests | exact registry version and SHA-512 match |
| `@types/node` | `24.13.3` | Node globals used by typed configs | exact registry version and SHA-512 match |
| `@types/react` | `19.2.7` | future WP10 type surface | exact registry version and SHA-512 match |
| `@types/react-dom` | `19.2.3` | future WP10 type surface | exact registry version and SHA-512 match |
| `axe-core` | `4.12.1` | reserved for WP10 accessibility evidence | exact registry version and SHA-512 match |
| `eslint` | `9.39.5` | Flat Config API and `eslint` CLI | exact registry version and SHA-512 match |
| `eslint-config-next` | `16.2.10` | core-web-vitals and TypeScript presets | exact registry version and SHA-512 match |
| `jsdom` | `29.1.1` | Vitest DOM environment | exact registry version and SHA-512 match |
| `next` | `16.2.10` | `NextConfig`, App Router configuration, and `next` CLI | exact registry version and SHA-512 match |
| `prettier` | `3.9.5` | existing WP01 formatting CLI; no unrelated config added | exact registry version and SHA-512 match |
| `react` | `19.2.7` | future WP10 runtime | exact registry version and SHA-512 match |
| `react-dom` | `19.2.7` | future WP10 runtime | exact registry version and SHA-512 match |
| `typescript` | `6.0.3` | compiler options and `tsc` CLI | exact registry version and SHA-512 match |
| `vitest` | `4.1.10` | component-test config API and `vitest` CLI | exact registry version and SHA-512 match |

The lock's `apps/web` dependency maps are byte-for-byte equivalent to the app manifest,
`node_modules/@invoice-manager/web` links to `apps/web`, and
`node_modules/@invoice-manager/contracts` links to `tools/contracts`. The contract workspace
name/version and `./v1 -> ./.generated/typescript/v1/index.ts` export agree with the app's
`0.0.0` declaration. Across all 611 locked package records, every non-link external entry has
an exact semantic version, public registry resolution, and SHA-512 integrity evidence.

## Exact locked-version API and option inspection

No installed dependency tree or global package version was used. The reviewer read the
content-addressed cached tarballs whose SHA-512 bytes matched the root lock:

- Next.js `16.2.10` exports `NextConfig`; its exact declarations accept `output:
  "standalone"`, `poweredByHeader`, `reactStrictMode`, `typescript.ignoreBuildErrors`,
  `typescript.tsconfigPath`, asynchronous rewrites, and string source/destination pairs.
  Its exact `prepareDestination` implementation expands the wildcard and merges the original
  request query before destination query values, supporting the intended path/query semantics.
- TypeScript `6.0.3` declares every selected strict compiler option and the exact `ES2022`,
  `ESNext`, `Bundler`, `Force`, and `preserve` enum values. The JSON parses cleanly, enables
  `strict`, `noEmit`, `noUncheckedIndexedAccess`, and `exactOptionalPropertyTypes`, and defines
  no generated-path alias.
- ESLint `9.39.5` exports `defineConfig` and `globalIgnores` from `eslint/config` through locked
  `@eslint/config-helpers@0.4.2`; locked `@eslint/core@0.17.0` declares all three configured
  linter options. `eslint-config-next@16.2.10` exports both imported subpaths as Flat Config
  arrays, and its preset/plugin closure is present with public integrity-backed resolutions.
- Vitest `4.1.10` exports `defineConfig` from `vitest/config`, recognizes `jsdom` as a built-in
  environment, and declares the configured deterministic worker, timeout, retry, isolation,
  reset, reporting, and sequence options. `jsdom@29.1.1` supports the pinned Node 24 line.
- `@playwright/test@1.61.1` resolves exactly to `playwright@1.61.1` and re-exports the exact
  config types. Those types declare every selected test, worker, retry, timeout, Git-capture,
  reporter, browser-context, artifact, and web-server readiness option.

The three TypeScript configuration files and the ESLint module pass syntax-only parsing, and
the TypeScript JSON passes read-only JSON parsing. No Next.js, TypeScript, ESLint, Vitest,
Playwright, npm script, build, development server, proxy, or test tool was executed.

## Configuration behavior

- `next.config.ts` reads the backend origin only from the unprefixed server configuration
  variable `INVOICE_MANAGER_API_ORIGIN`, validates it eagerly as a credential-free bare
  HTTP(S) origin, and throws clear configuration errors for missing or invalid input.
- The only rewrite is fixed at `/api/v1/:path*`; its destination host comes from that validated
  server configuration, not request data. There is no `NEXT_PUBLIC_*` origin, client export,
  CORS workaround, remote asset, browser-direct Zig URL, experimental flag, or feature route.
- TypeScript is fail-closed and strict. Future source/test/framework paths are included by
  convention without creating them, while WP03 is consumed through ordinary workspace package
  resolution rather than a generated-filesystem alias.
- ESLint uses the exact locked Next core-web-vitals and TypeScript presets, disables inline
  rule overrides, reports unused directives/configs, and ignores only dependency/generated/
  build/coverage/test-artifact paths.
- Vitest is restricted to `tests/foundation/**/*.test.{ts,tsx}` with a non-routable `.invalid`
  DOM origin, one worker, no file/test shuffle, no watch mode, no retries, bounded timeouts, and
  deterministic reset/order settings. It neither adds a setup source nor configures a live
  endpoint.
- Playwright is restricted to foundation `*.e2e.ts` tests, uses the fixed local origin
  `http://localhost:3000`, starts the production `npm run start` seam, waits on that same URL,
  and fixes workers/retries/timeouts. Downloads, permissions, service workers, screenshots,
  traces, and video are disabled. Zig startup, fixtures, assertions, and runtime evidence remain
  WP10 responsibilities.

## Immutable input and side-effect evidence

The WP01/WP03 metadata hashes remain:

- `package.json`: `5cf4279e6625af726f6261dc7068f4ac786f69e2a47c8a6d95fac50411489fa7`
- `apps/web/package.json`: `f31c4513240ee6dbd76796d6e846901446df69bed46a0ac2871bfb006b492db2`
- `package-lock.json`: `2a39499255b98d7c49eb1af1d8a4c35e3be8cc2729c39cda075115c318082a0a`
- `.npmrc`: `ca9bf7608c9a78289f54f0a45f6db53aeaa7da0752078cd4d610bdd43b9f9a7d`
- `.node-version`: `55075b5ec4e8b31936cbbc282b8829116d1fd48f2f1856dee592a6650700ce`
- `.zig-version`: `aa037454b5e8320521a32b278a3f4aff05fc79009ab5503f5d4a1b9a33b38c47`
- `tools/contracts/package.json`: `ee7fcc2fa81cf2b8884cbc54ab3a01a5c8f30a400dabb5afdced384dc9f508f0`

Those inputs have no commit in the implementation range and are unchanged after review. Both
root and app `node_modules` remain absent. No install, `npm ci`, `npx`, npm script, package
binary, generation, build, or test command ran during review. Runtime, E2E, accessibility, and
performance acceptance remain explicitly deferred to WP10.

The requested charter `section:code-review-checklist` selector was unavailable; the full
generated review capsule and its embedded checklist governed the review.

## Anti-pattern checklist

1. Dead code: **PASS** - all five files are conventional live configuration entrypoints for
   the exact WP01 scripts/CLIs consumed by WP10; no standalone public implementation module was
   added.
2. Synthetic-fixture test: **N/A** - WP09 is explicitly configuration-only and owns no tests;
   runtime and behavioral tests belong to WP10.
3. Silent empty return: **PASS** - there is no silent empty fallback; invalid backend-origin
   paths throw clear configuration errors.
4. FR coverage: **PASS** - the authorized static evidence covers FR-001, NFR-012, C-002, and
   C-009 at WP09's configuration boundary; runtime acceptance is neither claimed nor required
   from this WP.
5. Frozen surface: **PASS** - the implementation touches only the five owned config paths; all
   metadata, lock, generated, contract, source, and test surfaces are unchanged.
6. Locked decision: **PASS** - no private/moving dependency, direct generated path, browser
   backend origin, authoritative business behavior, public origin, or package/lock mutation is
   introduced.
7. Shared-file ownership: **PASS** - the five paths belong solely to WP09 and no out-of-map or
   shared-file crossing occurs.
8. Production fragility: **PASS** - the only new throws are deliberate fail-loud startup/config
   validation required for a missing or malformed trusted server origin; no request-time or
   transient-race raise was added.

## Subtask disposition

- T042: **PASS** - the five deterministic configurations map completely to exact declarations,
  lock entries, integrity evidence, workspace links, and exact-version APIs without mutating or
  executing the package graph. The same-origin seam is server-only, and all runtime proof is
  correctly handed to WP10.

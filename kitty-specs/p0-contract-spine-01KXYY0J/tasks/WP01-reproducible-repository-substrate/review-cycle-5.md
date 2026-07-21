# WP01 Review Cycle 5 — Changes Requested

## Blocking finding: the GPL amendment regresses the accepted wrapper baseline

The GPL-3.0-only evidence added by `c7fc303` is correct in isolation, but the
lane's `package.json` predates the accepted WP01 wrapper corrections in
`539963f` and `6d703b4`. As a result, this candidate does not preserve behavior
that was already accepted before the licensing amendment:

- `verify:foundation:clean` and `bootstrap:foundation` contain no generated-output
  cleanup and no `lstatSync`-based pre-existing-entry classification.
- A fresh-clone replay under Node 24.18.0, npm 11.16.0, and Zig 0.16.0 made each
  wrapper fail at the expected missing WP03 producer, but both left the newly
  created root `node_modules` behind.
- `bootstrap:foundation` invokes `verify:foundation` as a full aggregate. The
  accepted first-run contract uses the focused sequence `ci`, substrate,
  contracts, API, migration-negative, persistence, web, and one real
  `http:smoke`; it does not invoke the aggregate license gate.
- `verify:substrate` no longer checks the accepted wrapper cleanup/order
  invariants and has lost the extended system-browser fallback guard for
  `google-chrome`, `chromium-browser`, `CHROME_PATH`, and
  `PLAYWRIGHT_BROWSERS_PATH=0`.

Please reapply the GPL-3.0-only amendment on the accepted WP01 package-script
baseline from `6d703b4` (including the prerequisite correction in `539963f`),
or transplant those exact accepted semantics without weakening them. Keep the
new canonical-license hash and manifest/lock license assertions. The resulting
`verify:substrate` must validate both the GPL-3.0-only evidence and the accepted
cleanup, focused-bootstrap, timing, first-failure, and browser-fallback
contracts.

The next handoff should include fresh-clone evidence that:

1. both wrappers remove only outputs they created on child failure;
2. pre-existing regular entries, dangling symlinks, and inaccessible entries
   survive cleanup classification;
3. cleanup continues after an individual removal error, promotes an otherwise
   successful run to nonzero, and never masks an earlier child failure;
4. bootstrap runs the exact focused sequence and reaches exactly one real
   `http:smoke`, with no aggregate/license stage or hidden browser preinstall;
5. the GPL missing/truncated/byte-mismatch, three manifest-mismatch, and three
   lock-record-mismatch mutations still fail closed.

## Passing evidence to preserve

- `LICENSE` byte-matches `/usr/share/common-licenses/GPL-3` and has SHA-256
  `3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`.
- Root, contracts, web, and the corresponding lock records all use
  `GPL-3.0-only` and fail closed under all nine evidence mutations above.
- Two fresh offline `npm ci` plus `verify:substrate` runs were byte-identical;
  `npm ls --all` had no problems and `npm audit` reported zero vulnerabilities.
- Empty-cache and prepared-cache `browser:install` runs installed Playwright's
  managed Chromium and headless-shell revision 1228 without metadata mutation
  or a system-browser fallback.
- `c7fc303` changes only WP01-owned files. The bulk-edit occurrence map is
  present, the changed license occurrences are in manual-review categories,
  and historical evidence / separately licensed exceptions were not rewritten.

## Anti-pattern checklist

1. Dead code: **PASS** — the executable checks are reached through root npm scripts.
2. Synthetic-fixture test: **PASS** — review mutations invoked `verify:substrate` itself.
3. Silent empty return: **PASS** — no silent-empty failure path was introduced.
4. FR coverage: **PASS** — supported and negative substrate paths exercise FR-001/FR-015 behavior.
5. Frozen surface: **PASS** — the corrective commit touches only WP01-owned files.
6. Locked decision: **FAIL** — current clean/bootstrap behavior contradicts the accepted wrapper contract described above.
7. Shared-file ownership: **PASS** — all changed metadata remains in WP01 ownership.
8. Production fragility: **PASS** — new throws are intentional fail-loud substrate diagnostics.

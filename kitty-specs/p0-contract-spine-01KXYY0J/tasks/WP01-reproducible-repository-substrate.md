---
work_package_id: WP01
subtasks:
  - T001
  - T002
  - T003
  - T004
  - T058
title: "Reproducible Repository Substrate"
task_type: implement
phase: "Phase 1 - Repository Substrate"
dependencies: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: "Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch."
execution_mode: code_change
owned_files:
  - "LICENSE"
  - ".node-version"
  - ".zig-version"
  - ".npmrc"
  - "package.json"
  - "package-lock.json"
  - "tools/contracts/package.json"
  - "apps/web/package.json"
authoritative_surface: "package"
create_intent:
  - "LICENSE"
  - ".node-version"
  - ".zig-version"
  - ".npmrc"
  - "package.json"
  - "package-lock.json"
  - "tools/contracts/package.json"
  - "apps/web/package.json"
requirement_refs:
  - FR-001
  - FR-015
  - NFR-001
  - NFR-008
  - NFR-012
  - C-009
agent_profile: node-norris
role: implementer
agent: "codex:gpt-5:node-norris:implementer"
model: ""
assignee: ""
shell_pid: "1807838"
history:
  - at: "2026-07-20T07:00:27Z"
    actor: system
    action: "Prompt generated via /spec-kitty.tasks-packages"
---

# Work Package Prompt: WP01 – Reproducible Repository Substrate

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter,
and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `node-norris`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for
this work package's `task_type` and `authoritative_surface`.

Run `spec-kitty agent action implement WP01 --agent codex` before implementation.

---

## Review Feedback

- No review feedback has been recorded yet.
- On a rejection cycle, read all structured review feedback before editing and append a concise response to the Activity Log.
- Preserve accepted behavior while correcting only the rejected scope.

## Objective

Create the immutable, root-level repository substrate that every later work package can trust.
Pin the supported Node.js, npm, and Zig versions exactly.
Predeclare the immutable contract and web workspace package metadata with every selected exact
dependency version, then generate the sole committed root npm lockfile.
Publish stable root commands for focused verification and final foundation verification.
Make missing prerequisites fail with precise, actionable diagnostics.
Prove that a clean checkout can bootstrap reproducibly without mutating committed root metadata.
Install the exact browser artifact selected by the locked Playwright package before every real
E2E run, with no system-browser fallback or hidden machine prerequisite.

This package implements the repository-foundation slice of FR-001 and FR-015.
It also establishes the practical basis for NFR-001, NFR-008, NFR-012, and C-009.
It is the implementation point for plan concern IC-01.

## Scope Boundary

This work package is the sole immutable npm metadata and root-lock owner.
Create or modify only paths matched by the declared ownership patterns:

- `.node-version`
- `LICENSE`
- `.zig-version`
- `.npmrc`
- `package.json`
- `package-lock.json`
- `tools/contracts/package.json`
- `apps/web/package.json`

Do not create or edit any application source.
Do not create any `apps/web` file except the exact package manifest owned here.
Do not create any `tools/contracts` file except the exact package manifest owned here.
Do not create `services/api` files, Zig source, or a Zig build file.
Do not create database adapters, ShovelerDB integration, schemas, migrations, or fixtures.
Do not create contract sources, generated bindings, license scanners, or helper scripts.
Do not create CI workflows, container files, deployment files, or release automation.
Do not implement invoice, client, project, billing, analytics, identity, or PDF behavior.
Do not edit mission planning artifacts, task prompts, status logs, or other work packages.

The root package declares delegation commands whose producers land in later work packages.
Those declarations are interfaces, not authorization to create their downstream targets here.
WP01 predeclares both workspace manifests and resolves their complete dependency graph now.
WP03, WP09, WP10, and every later package consume all three package manifests and the root lock
unchanged; no later work package may add npm metadata or regenerate the lock. This corrective
cycle changes only WP01-owned root script values, adds no package, changes no version, and must
leave both workspace manifests plus `package-lock.json` byte-identical.

## Branch Strategy

The planning base is `feat/p0-contract-spine`.
The merge target is also `feat/p0-contract-spine`.
This package has no work-package dependencies and may start immediately.
The runtime may create a dedicated WP branch from the planning base.
All completed changes must return to `feat/p0-contract-spine` unless the human explicitly redirects them.
Do not merge or rebase unrelated work as part of this package.

## Requirement Traceability

- `FR-001`: establish the pinned, clean-bootstrap repository foundation used by the Linux x86_64 support path.
- `FR-015`: provide stable root verification entry points that later contract, API, persistence, and web checks can join.
- `NFR-001`: make supported toolchain assumptions deterministic and locally verifiable.
- `NFR-008`: keep focused checks available independently instead of requiring an undifferentiated full build.
- `NFR-012`: make bootstrap and verification behavior reproducible from committed inputs.
- `C-009`: encode the supported Linux x86_64 and exact-toolchain prerequisite policy.
- `IC-01`: resolve repository substrate and command orchestration before downstream implementation begins.

## Repository Context

Treat the mission spec, plan, research, and quickstart as authoritative intent.
The repository is a polyglot monorepo with a Next.js frontend and a Zig backend.
npm owns JavaScript workspace resolution and the root JavaScript lockfile.
The root workspace patterns are `apps/*` and `tools/*`.
WP01 materializes the two exact package-manifest boundaries required for those workspaces while
later packages supply contract implementation, web configuration, and application source.
Zig remains an external pinned toolchain in this package; no Zig package graph is introduced here.
Later work packages will populate the workspace and service paths.
The root command surface must therefore be declared without fabricating downstream implementation.

## T001 — Immutable Tool and Version Policy

Create `.node-version` with exactly the Node.js version selected by the plan: `24.18.0`.
Create `.zig-version` with exactly the Zig version selected by the plan: `0.16.0`.
Declare npm `11.16.0` exactly through the root package-manager metadata.
Use exact version strings; do not use ranges, aliases, `latest`, or moving channels.

Configure `.npmrc` to support deterministic repository installs.
At minimum, require lockfile usage, exact dependency saves, and engine enforcement.
Do not disable security checks globally.
Do not add registry credentials, tokens, user-specific paths, or machine-local settings.
Do not enable a setting that would silently change downstream package lifecycle semantics.

Express the supported runtime assumptions in `package.json` using exact `engines` values.
Record the package manager with the exact `npm@11.16.0` declaration.
Keep the repository package private so it cannot be accidentally published.
Create the canonical root `LICENSE` with the complete GPL-3.0-only text selected
by the owner-approved charter amendment. Use that exact project license identity
in every owned package manifest and lockfile record rather than inventing a
second policy. The substrate verification must fail if the root license is
missing, truncated, or disagrees with package metadata.

Add an executable root prerequisite check using only root package metadata.
Because no helper-script path is owned here, keep its implementation within `package.json` scripts.
The check must validate Node.js, npm, Zig, operating system, and CPU architecture.
It must expect Node.js `24.18.0`, npm `11.16.0`, Zig `0.16.0`, Linux, and x86_64/x64.
Normalize the Node leading `v` and the architecture naming difference before comparison.

Every mismatch must identify:

- the prerequisite that failed;
- the expected value;
- the observed value, or that the executable was missing;
- a concise corrective action pointing to the committed version file or package-manager field.

The check must return nonzero on any mismatch.
It must not install or mutate tools automatically.
It must not depend on network access.

## T002 — Root npm Workspace and Lockfile Substrate

Create a minimal root `package.json` suitable for the planned monorepo.
Give it a stable repository package name and a non-release placeholder version.
Set `private: true`.
Declare `apps/*` and `tools/*` as the root workspace boundaries.
Create `tools/contracts/package.json` and `apps/web/package.json` before generating the lock.
Do not include the Zig service as a synthetic npm package.

Keep runtime `dependencies` empty.
Put dependencies in the workspace that consumes them rather than hoisting declarations into the root.
In `tools/contracts/package.json`, predeclare the complete minimal parse, JSON Schema 2020-12,
OpenAPI 3.1, RFC 8785 canonicalization, deterministic generation, TypeScript execution, and
test tool set WP03 requires; TypeScript is exactly `6.0.3`, and every other selected package is
an exact full version with an identified WP03 call site.
Give the contract workspace one stable version-one export targeting
`tools/contracts/.generated/typescript/v1/` and stable tool-local generate/check commands.

In `apps/web/package.json`, predeclare the complete dependency and validation tool set already
selected for WP09/WP10: Next.js exactly `16.2.10`; React and React DOM exactly `19.2.7` each;
TypeScript exactly `6.0.3`; ESLint exactly `9.39.5`; `eslint-config-next` exactly `16.2.10`;
and every formatting, DOM, component, accessibility, and Playwright package at one
explicit full version. Include the stable package-local commands WP09/WP10 will implement or use.
Do not add feature libraries, charts, state managers, data clients, UI kits, remote fonts,
authentication, databases, or other speculative packages.
Do not defer a required npm dependency decision to a later work package.
Do not use global installations as hidden repository dependencies.

Generate `package-lock.json` with npm `11.16.0` only after all three package manifests and
`.npmrc` have their final WP01 bytes.
Use the current lockfile format produced by the pinned npm version.
Do not hand-author or manually normalize the lockfile.
Ensure the lock records the root, contract, and web workspace packages plus only their approved
exact contract/web dependency graph.
Commit it as the immutable npm reproducibility baseline for the mission.

Use `npm ci` as the clean-install contract whenever a lockfile already exists.
Use lockfile-only generation only while completing WP01's owned metadata.
An ordinary clean install must not change `package.json` or `package-lock.json`.

Record immutable ownership explicitly:

- WP01 alone creates all npm manifests and the root lock, then verifies their final bytes.
- WP03 consumes `tools/contracts/package.json` and writes only its owned source, tests, ignores,
  and generated outputs.
- WP09 and WP10 consume `apps/web/package.json` unchanged while adding their separately owned files.
- No later WP regenerates `package-lock.json`, even after adding source or configuration.
- A discovered npm metadata gap is an ownership failure routed back to WP01; it is never fixed
  by an opportunistic manifest or lock edit in another package.

## T003 — Focused Command Surface and Prerequisite Diagnostics

Declare stable root npm scripts for the focused checks described by the plan.
The names must be discoverable and remain consistent for later work packages.
Include, at minimum, the following root-facing commands:

- `prerequisites:check`
- `contracts:generate`
- `contracts:check`
- `api:check`
- `web:check`
- `migration:negative`
- `persistence:integration`
- `browser:install`
- `http:smoke`
- `licenses:check`
- `verify:substrate`
- `verify:foundation`
- `verify:foundation:clean`
- `bootstrap:foundation`
- `dev:api`
- `dev:web`

`verify:substrate` must exercise only the root substrate delivered by this package.
It must be runnable before downstream source trees exist.
It must include prerequisite validation and structural assertions for root metadata.

The remaining focused commands must delegate to the canonical downstream surface identified in the plan.
Do not reimplement downstream checks as inline root business logic.
For a downstream path not yet present, fail before delegation with a precise prerequisite diagnostic.
The diagnostic must name the missing path and the work package or capability expected to provide it.
Do not silently skip a missing command.
Do not report success for an absent downstream check.

`browser:install` must resolve the local Playwright executable through the immutable web
workspace and run exactly `playwright install chromium`. The selected Chromium/headless-shell
revision therefore comes from locked `@playwright/test` `1.61.1`. Do not use a system Chrome
executable, channel name, floating package invocation, or second browser manager. `http:smoke`
must build production Next.js, invoke this idempotent installation, and then delegate the full
child-process lifecycle to WP10's `apps/web/tests/foundation/http-smoke.mjs`, propagating the
first failure unchanged.

`contracts:generate` delegates literally to WP03's tool-local generator and is the sole public
materialization path for ignored generated TypeScript and the runtime route inventory.
`contracts:check` delegates to WP03's check flow, which must invoke generation twice and compare
exact bytes before reporting success.

Implement those preflight guards within package scripts because this WP may not create helper files.
Keep inline checks readable, deterministic, and portable across supported Linux x86_64 environments.
Avoid shell features that obscure exit codes.
Forward delegated command exit codes unchanged.

`migration:negative` is mandatory and delegates exactly to the stable service-build surface:

```bash
zig build migration-negative --build-file services/api/build.zig
```

WP04 owns and publishes that convention-scanned build hook.
WP07 supplies the complete migration-negative suite: discovery, collision, dependency,
digest, DDL, checkpoint, parent-directory-sync, quarantine, and durability-uncertain cases.
It consumes WP06's public durable fault/recovery seams; WP06 remains migration-agnostic
and owns store, checkpoint, and directory-sync behavior rather than migration tests.
Before WP07 lands, the root preflight must fail nonzero with a diagnostic naming the missing WP04 build hook or missing WP07 test producer.
After they land, zero discovered negative cases, swallowed nonzero child status, or a missing required category is a hard failure.
Never skip the command or convert absence into success.

`verify:foundation` must compose the final mission checks in a stable, fail-fast order.
It must include `migration:negative` as its own visible stage rather than hiding it inside another Zig command.
It may remain expected to fail on missing downstream producers until those packages land.
Its present failure must be actionable rather than a stack trace or generic file-not-found error.
Do not weaken the final command merely to make it pass during WP01.

`verify:foundation:clean` is the canonical clean timed wrapper. It must use a monotonic clock,
start immediately before `npm ci`, include `npm ci` and `npm run verify:foundation`, preserve the
first failing child status, and stop only after the aggregate reports its result. It must support
the reference empty dependency/build-cache protocol without hiding cache preparation inside the
measured interval.

`bootstrap:foundation` is the distinct NFR-001 first-run wrapper. Its monotonic timing also begins
before its internal `npm ci`, then includes full foundation validation, production Zig and Next.js
startup, readiness, and one valid same-origin health smoke. It stops only after the response body
is consumed or a required stage fails, and preserves the first failing status.

Both timed wrappers include browser acquisition after `npm ci` through `http:smoke`; the browser
is a pinned repository artifact rather than an excluded Node/npm/Zig toolchain prerequisite. A
prepared valid Playwright cache may make installation a no-op, but an empty reference cache must
acquire the same locked revision inside the measured boundary.

Development commands must perform the same prerequisite and path checks before delegating.
They must not download toolchains, start substitute servers, or invent application behavior.

## T004 — Clean-Bootstrap and Reproducibility Tests

Verify the substrate on the exact pinned toolchain in a clean environment.
Perform verification from a clean checkout or isolated temporary copy, not from cached workspace state alone.
Do not add test fixtures or test programs outside the seven owned metadata files.

The verification sequence must prove all of the following:

- the version files contain one exact version each;
- `package.json` parses and contains exact engine and package-manager declarations;
- workspace declarations match the planned monorepo boundaries;
- workspace declarations include exactly the required `apps/*` and `tools/*` roots;
- `.npmrc` enforces the intended deterministic settings;
- `package-lock.json` is accepted by `npm ci` under npm `11.16.0`;
- `npm ci` does not mutate `package.json` or `package-lock.json`;
- repeated clean installs leave the lockfile byte-identical;
- both workspace manifests contain the approved exact contract/web graph and stable commands;
- the root lock contains the complete approved graph for root, contract, and web workspaces;
- `verify:substrate` succeeds on the supported platform and versions;
- a missing Zig executable produces the designed diagnostic and a nonzero exit;
- a wrong tool version produces expected-versus-observed diagnostics and a nonzero exit;
- a downstream focused command names its missing producer instead of silently succeeding;
- `migration:negative` names an absent WP04 hook or WP07 producer and exits nonzero;
- root scripts propagate failures from delegated commands.
- bare `http:smoke` builds production web output, installs the pinned Chromium/headless-shell
  revision, invokes the WP10 lifecycle harness, and never selects a system browser;
- `verify:foundation:clean` starts timing before `npm ci` and preserves child failures.
- `bootstrap:foundation` times install, validation, production startup, and same-origin smoke.

Capture a checksum of `package-lock.json` before and after repeated installs.
Use repository diff checks to prove that the seven owned files remain unchanged.
Remove only disposable install state created by the test.
Do not delete or rewrite user-owned files.
Do not require network access after a valid npm cache is prepared for the pinned complete graph.

Test immutable metadata in isolated temporary copies without creating downstream source:

1. Hash the initial `package-lock.json`, run `npm ci`, and prove the hash and tracked root metadata remain unchanged.
2. Run a second clean install from a fresh `node_modules` state and compare exact lock bytes.
3. Inspect every locked package against the approved contract/web allowlist and reject ranges or unexpected packages.
4. Confirm both workspace package entries and their complete transitive graph are present.
5. Run every package-local metadata command far enough to prove stable target names or an
   actionable missing-producer diagnostic without fabricating source.
6. Treat every later manifest or lock edit as an ownership failure even if the resulting bytes install.

## T058 — Corrective Playwright Browser and Smoke Lifecycle Contract

Close the persisted analysis finding that the locked Playwright package did not provision its
matching browser executable and that the bare smoke command did not own a complete runtime.

1. Add root `browser:install` delegation through the installed web workspace to exact
   `playwright install chromium`; do not add a dependency or edit a workspace manifest.
2. Make root `http:smoke` generate contracts, build production Next.js, install the browser, and
   invoke WP10's owned `http-smoke.mjs` lifecycle harness after producer preflights.
3. Update `verify:substrate` script-key/delegation assertions for the new command and harness;
   preserve all unrelated accepted substrate behavior.
4. In an isolated clean checkout and empty browser cache, run pinned `npm ci`, inspect the locked
   Playwright install plan for Chromium/headless-shell revision 1228, install it, and prove the
   executable exists without `channel`, `executablePath`, or system-Chrome fallback.
5. Repeat with a prepared valid cache and require idempotent success. Hash the root manifest,
   both workspace manifests, and lock before/after every check; only `package.json` may differ
   from the prior accepted WP01 commit and the other three files must be byte-identical.

Record the prior missing-revision failure as `RED:` evidence, then the exact corrective command
and `GREEN:` result. This package proves provisioning/delegation only; WP10 proves application E2E.

Where a negative case needs an alternate executable, use an isolated temporary `PATH` or a controlled process shim.
Never replace the user's real Node.js, npm, or Zig installation.
Keep all negative-test artifacts outside the repository and remove them afterward.

## Implementation Guidance

Prefer small, transparent root configuration over a framework for repository orchestration.
Keep JSON valid and avoid comments in `package.json` and `package-lock.json`.
Keep version files newline-terminated.
Keep `.npmrc` repository-scoped and free of secrets.
Quote inline Node snippets carefully so npm, the shell, and JavaScript agree on escaping.
Use structured, stable diagnostic prefixes so CI and humans can distinguish prerequisite failures.
Avoid ANSI-only meaning; messages must remain understandable in plain logs.

Do not loosen exact version checks because the local machine differs.
If the pinned toolchain is unavailable, report that verification is blocked after completing safe static checks.
Do not regenerate the lockfile with an unpinned npm version and claim equivalence.

## Test Strategy

Run static checks first:

1. Parse `package.json` and `package-lock.json` as JSON.
2. Compare all declared tool versions with the mission plan.
3. Inspect the script keys and their canonical delegation targets.
4. Confirm `contracts:generate`, `contracts:check`, `verify:foundation:clean`, and
   `bootstrap:foundation` have the exact semantics above.
5. Confirm `migration:negative` delegates to the exact WP04 hook command.
6. Confirm no unowned files were added or modified.

Run supported-path checks next:

1. Confirm `node --version` is `v24.18.0`.
2. Confirm `npm --version` is `11.16.0`.
3. Confirm `zig version` is `0.16.0`.
4. Confirm `uname` and Node platform data resolve to Linux x86_64/x64.
5. Run `npm run prerequisites:check`.
6. Run `npm ci` using the committed lockfile.
7. Run `npm run verify:substrate`.
8. Exercise `npm run verify:foundation:clean` through its first expected missing-producer result
   and verify that `npm ci` is inside the timed boundary.
9. Exercise `npm run bootstrap:foundation` through its first expected missing-producer result and
   verify install, validation, production startup, and smoke are one ordered timing boundary.
10. Run `npm run migration:negative` once and verify its current producer diagnostic or real delegated result.

Run reproducibility and negative-path checks last.
Record exact commands and outcomes in the Activity Log.
Do not run `verify:foundation` as a WP01 success gate when its producers are intentionally absent.
Do run it once to verify that its first missing prerequisite is diagnosed accurately.

## Risks and Mitigations

- Risk: an unpinned npm regenerates a different lockfile. Mitigation: verify npm first and generate only with `11.16.0`.
- Risk: an incomplete upfront dependency set pressures later lock edits. Mitigation: predeclare both complete workspace manifests, test their command surfaces, and route gaps back to WP01.
- Risk: inline preflight scripts become unreadable. Mitigation: keep each guard narrow and delegate real work downstream.
- Risk: workspace globs accidentally claim backend ownership. Mitigation: declare only `apps/*` and `tools/*`; never model the Zig service as npm.
- Risk: missing downstream paths look like successful checks. Mitigation: explicit nonzero preflight guards with named producers.
- Risk: migration-negative passes vacuously. Mitigation: require WP04 hook presence, producer/category floors, and unchanged exit-code propagation.
- Risk: root scripts encode speculative business behavior. Mitigation: restrict them to orchestration and prerequisites.
- Risk: install tests mutate tracked metadata. Mitigation: hash files, inspect diffs, and fail on mutation.
- Risk: Playwright silently uses a machine browser. Mitigation: install the locked Chromium target,
  forbid system-browser selectors, inspect revision 1228, and exercise an isolated browser cache.
- Risk: local toolchain mismatch hides static correctness. Mitigation: separate static verification from supported-toolchain execution and report both.

## Definition of Done

- All seven create-intent files exist and are the only repository files changed by WP01.
- Node.js `24.18.0`, npm `11.16.0`, and Zig `0.16.0` are pinned exactly and consistently.
- Linux x86_64 is validated as the supported execution platform.
- The root npm package is private and declares exactly the planned `apps/*` and `tools/*` workspace boundaries.
- Both workspace manifests pin the complete approved exact contract/web tooling set.
- `package-lock.json` was generated by pinned npm from all final WP01-owned manifests.
- WP01's sole immutable npm metadata/lock ownership is explicit and testable.
- The focused command surface includes mandatory `migration:negative` with explicit downstream prerequisite diagnostics.
- The focused command surface includes `browser:install`, and bare `http:smoke` owns build,
  locked browser provisioning, and delegation to WP10's complete lifecycle harness.
- `verify:substrate` succeeds on the supported toolchain.
- `verify:foundation:clean` times `npm ci` plus the complete aggregate boundary.
- `bootstrap:foundation` times `npm ci`, full validation, production startup, and same-origin smoke.
- Clean `npm ci` runs are reproducible and leave root metadata byte-identical.
- Negative prerequisite cases fail nonzero with expected and observed values.
- No application source, service build file, CI configuration, or business behavior was introduced.
- The Activity Log contains commands, results, limitations, and any blocked exact-toolchain checks.

## Review Guidance

Review ownership before behavior: every diff path must be one of the seven exact frontmatter paths.
Reject application code, helper scripts, CI files, or service build files in this package.
Compare every pinned version against the plan rather than the reviewer's local defaults.
Confirm the lockfile is tool-generated and reproducible under npm `11.16.0`.
Confirm every contract/web dependency is exact, justified by a planned command/call site, and
locked before WP01 completes.
Confirm no later WP is authorized to edit npm manifests or regenerate the root lock.
Inspect prerequisite failures for actionable expected-versus-observed diagnostics.
Confirm `migration:negative` uses the exact WP04 hook, fails on missing/empty producer categories, and propagates child failures.
Confirm missing downstream producers fail explicitly and are not silently skipped.
Confirm `verify:substrate` is independently useful before other work packages land.
Confirm `contracts:generate` and both clean timed wrappers have the exact declared semantics.
Confirm the corrective diff changes only root script values, leaves both workspace manifests and
the lock byte-identical, and cannot fall back to an unpinned system browser.
Treat downstream-focused checks as declared interfaces; do not require their implementations in WP01.
Verify the full command surface is compatible with later work without preempting their owned files.

## Activity Log

- 2026-07-20T07:00:27Z – system – Prompt created for WP01 reproducible repository substrate implementation.
- Append implementation start, material decisions, verification commands, and results chronologically below this line.
- 2026-07-20T17:51:14Z – codex:gpt-5:node-norris:implementer – shell_pid=1807838 – Assigned agent via action command
- 2026-07-20T18:44:53Z – codex:gpt-5:node-norris:implementer – shell_pid=1807838 – Ready for review: exact Node/npm/Zig pins, immutable peer-clean workspace graph and lock, clean/offline reproducibility, zero-vulnerability audit, and actionable missing-producer diagnostics verified under official Node 24.18.0; host Node 26 mismatch remains intentionally rejected.
- 2026-07-20T18:45:39Z – codex:gpt-5:reviewer-renata:reviewer – shell_pid=1807838 – Started review via action command
- 2026-07-20T18:54:02Z – user – shell_pid=1807838 – Moved to planned
- 2026-07-20T18:59:37Z – codex:gpt-5:node-norris:implementer – shell_pid=1807838 – Started implementation via action command
- 2026-07-20T19:06:04Z – codex:gpt-5:node-norris:implementer – shell_pid=1807838 – Ready for review cycle 2: scoped next@16.2.10/PostCSS 8.5.10 override resolves with Vite PostCSS 8.5.20; strict-peer npm ci, npm ls --all problems=[], full/prod audits, verify:substrate, and repeated offline hashes pass under Node 24.18.0/npm 11.16.0. persistence:integration targets durability_integration_test.zig/test-persistence-integration. Bootstrap delegates one aggregate http:smoke and propagates WP03 failure status 1. Commit 5d5a341.
- 2026-07-20T19:07:10Z – codex:gpt-5:reviewer-renata:reviewer – shell_pid=1807838 – Started review via action command
- 2026-07-20T19:14:46Z – user – shell_pid=1807838 – Review passed: commit 5d5a341 resolves all cycle-1 blockers; scoped next@16.2.10 PostCSS 8.5.10 plus Vite PostCSS 8.5.20 yields npm ls --all exit 0/problems empty; pinned Node 24.18.0/npm 11.16.0 repeated offline npm ci is metadata-immutable and full/prod audits are zero; persistence delegates durability_integration_test.zig to test-persistence-integration; bootstrap times npm ci plus verify:foundation, reaches exactly one aggregate http:smoke, and preserves first failure status; seven-file ownership and actionable negative diagnostics pass.
- 2026-07-20T23:01:36Z – codex – shell_pid=1807838 – Correction cycle: newly published js-yaml advisory requires exact patched transitive override
- 2026-07-20T23:02:30Z – codex – shell_pid=1807838 – Started implementation via action command
- 2026-07-20T23:03:00Z – codex:gpt-5:node-norris:implementer – RED: fresh immutable Node 24.18.0/npm 11.16.0 install and `npm audit --audit-level=high --json` reported 4 high findings through `@hey-api/openapi-ts@0.99.0` → `@hey-api/json-schema-ref-parser@1.4.4` → affected `js-yaml@4.2.0` under GHSA-52cp-r559-cp3m; npm's proposed fix was a generator rollback to 0.97.0.
- 2026-07-20T23:10:48Z – codex:gpt-5:node-norris:implementer – GREEN: commit a2002e9 keeps every direct version exact, adds a chain-scoped override to patched `js-yaml@4.3.0`, and changes only package.json plus the lock's version/resolution/SHA-512 tuple. Normal and offline/ignore-script `npm ci` runs were metadata-immutable; full and production audits report 0 vulnerabilities; `npm ls --all` is valid; `verify:substrate` passes under Node 24.18.0/npm 11.16.0/Zig 0.16.0 and asserts the override plus patched lock entry.
- 2026-07-20T23:14:22Z – codex – shell_pid=1807838 – Correction implementation committed as a2002e9; exact direct generator version retained, transitive js-yaml patched to 4.3.0, immutable installs and full/prod audits green; ready for independent review.
- 2026-07-20T23:15:12Z – codex-wp01-advisory-review – shell_pid=1807838 – Started review via action command
- 2026-07-21T14:46:43Z – codex – Corrective planning after blocked analysis: provision the exact
  Playwright-managed Chromium revision and delegate a self-contained bare smoke lifecycle; no
  dependency, workspace-manifest, or lock change.
- 2026-07-20T23:20:41Z – user – shell_pid=1807838 – Moved to planned
- 2026-07-20T23:23:05Z – codex – shell_pid=785373 – Started implementation via action command
- 2026-07-20T23:24:22Z – codex – shell_pid=785373 – GREEN correction cycle 4: pinned npm 11.16.0 dedupe removed the sole redundant nested @eslint/eslintrc js-yaml lock row; commit 2fc13e7 now has 610 package entries and exactly one hoisted js-yaml@4.3.0. A fresh manifests-only offline lock generation byte-matched the committed lock; normal offline npm ci was metadata-immutable, npm ls problems=[], verify:substrate passed under exact Node/npm/Zig, and full plus production audits reported 0 vulnerabilities. Generated install trees were removed.
- 2026-07-20T23:24:47Z – codex – shell_pid=785373 – Cycle 4 blocker resolved in 2fc13e7: lock deduped by pinned npm to canonical 610-entry graph, byte-equal to clean manifests-only regeneration; all prior security and substrate gates remain green.
- 2026-07-20T23:25:16Z – codex-wp01-lock-rereview – shell_pid=1807838 – Started review via action command
- 2026-07-20T23:29:17Z – user – shell_pid=1807838 – Review passed cycle 5: commit 2fc13e7 removes only the redundant nested js-yaml row; two independent manifests-only npm 11.16.0 offline regenerations byte-match the canonical 610-entry committed lock (sha256 6ea2ffb8...), direct @hey-api/openapi-ts remains 0.99.0, one hoisted js-yaml 4.3.0 retains exact public-registry integrity, repeated offline npm ci is metadata-immutable, verify:substrate and npm ls --all problems=[] pass, and full/prod audits are zero.
- 2026-07-21T15:01:12Z – codex-wp01-lock-rereview – shell_pid=1807838 – Moved to planned
- 2026-07-21T15:05:34Z – codex-wp01-browser-fix – shell_pid=1807838 – Started implementation via action command
- 2026-07-21T15:15:44Z – codex-wp01-browser-fix – shell_pid=1807838 – RED: isolated clean clone at prior accepted tip; pinned Node 24.18.0/npm 11.16.0 npm ci succeeded, locked Playwright plan reported chromium revision 1228 and chromium-headless-shell revision 1228, but an empty PLAYWRIGHT_BROWSERS_PATH lacked the expected managed executable and the probe exited 1. Baseline hashes: package 262d99dd, web f31c4513, contracts ee7fcc2f, lock 6ea2ffb8.
- 2026-07-21T15:15:53Z – codex-wp01-browser-fix – shell_pid=1807838 – GREEN: commit e89d3bb changes only package.json. In a fresh isolated clone, pinned npm ci succeeded; PLAYWRIGHT_BROWSERS_PATH began empty; npm run browser:install resolved local Playwright 1.61.1 with npm exec --offline and installed managed chromium plus chromium-headless-shell revision 1228; both executables passed X_OK; a prepared-cache repeat exited 0 without download. verify:substrate passed, npm audit found 0 vulnerabilities, npm ls problems=[], and http:smoke failed actionably at its first absent producer. Final hashes: package 816264f8, web f31c4513, contracts ee7fcc2f, lock 6ea2ffb8.
- 2026-07-21T15:16:13Z – codex-wp01-browser-fix – shell_pid=1807838 – Ready for review: e89d3bb adds offline local Playwright Chromium provisioning and the ordered production smoke harness contract; isolated empty/prepared-cache revision-1228 evidence and immutable metadata hashes recorded.
- 2026-07-21T15:17:32Z – codex-wp01-browser-review – shell_pid=1807838 – Started review via action command
- 2026-07-21T15:25:30Z – user – shell_pid=1807838 – Arbiter override: superseded rejected review-cycle-3 is closed by committed parseable approval review-cycle-7 at 4e8f592 after independent empty-cache rev1228 provisioning, idempotency, exact substrate, ownership, and immutable-hash verification; implementation e89d3bb passes all corrective requirements.
- 2026-07-21T20:28:03Z – codex-wp01-browser-review – shell_pid=1807838 – Moved to planned
- 2026-07-21T20:41:21Z – codex:gpt-5:node-norris:implementer – shell_pid=1807838 – Started implementation via action command
- 2026-07-21T20:50:27Z – codex:gpt-5:node-norris:implementer – shell_pid=1807838 – Ready for review: c7fc303 adopts canonical GPL-3.0-only metadata/text with exact hash and manifest/lock fail-closed checks; Node24/npm11/Zig0.16 immutable installs, mutation negatives, wrappers, audit, diff scope, and fresh-clone gates verified

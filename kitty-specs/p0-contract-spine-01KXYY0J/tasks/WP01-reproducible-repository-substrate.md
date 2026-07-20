---
work_package_id: WP01
subtasks:
  - T001
  - T002
  - T003
  - T004
title: "Reproducible Repository Substrate"
task_type: implement
phase: "Phase 1 - Repository Substrate"
dependencies: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: "Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch."
execution_mode: code_change
owned_files:
  - "package*.json"
  - ".*-version"
  - ".npm*"
authoritative_surface: "package"
create_intent:
  - ".node-version"
  - ".zig-version"
  - ".npmrc"
  - "package.json"
  - "package-lock.json"
requirement_refs:
  - FR-001
  - FR-015
  - NFR-001
  - NFR-008
  - NFR-012
  - C-009
agent_profile: node-norris
role: implementer
agent: codex
model: ""
assignee: ""
shell_pid: ""
history:
  - at: "2026-07-20T07:00:27Z"
    actor: system
    action: "Prompt generated via /spec-kitty.tasks-packages"
---

# Work Package Prompt: WP01 – Reproducible Repository Substrate

## ⚡ Do This First: Load Agent Profile

- Load the `node-norris` agent profile before inspecting or changing repository files.
- Use `/ad-hoc-profile-load` if the host exposes profile loading as a skill or command.
- Adopt the `implementer` role and preserve the profile's engineering and verification rules throughout this work package.
- Run `spec-kitty agent action implement WP01 --agent codex` before implementation so the work package enters the correct runtime state.
- If profile loading or the state transition is unavailable, stop and report the exact command and error; do not perform untracked implementation.

## Review Feedback

- No review feedback has been recorded yet.
- On a rejection cycle, read all structured review feedback before editing and append a concise response to the Activity Log.
- Preserve accepted behavior while correcting only the rejected scope.

## Objective

Create the immutable, root-level repository substrate that every later work package can trust.
Pin the supported Node.js, npm, and Zig versions exactly.
Establish npm workspaces and a committed npm lockfile without taking ownership of application dependencies.
Publish stable root commands for focused verification and final foundation verification.
Make missing prerequisites fail with precise, actionable diagnostics.
Prove that a clean checkout can bootstrap reproducibly without mutating committed root metadata.

This package implements the repository-foundation slice of FR-001 and FR-015.
It also establishes the practical basis for NFR-001, NFR-008, NFR-012, and C-009.
It is the implementation point for plan concern IC-01.

## Scope Boundary

This work package owns root configuration only.
Create or modify only paths matched by the declared ownership patterns:

- `.node-version`
- `.zig-version`
- `.npmrc`
- `package.json`
- `package-lock.json`

Do not create or edit any application source.
Do not create `apps/web` files or select Next.js dependencies.
Do not create `services/api` files, Zig source, or a Zig build file.
Do not create database adapters, ShovelerDB integration, schemas, migrations, or fixtures.
Do not create contract sources, generated bindings, license scanners, or helper scripts.
Do not create CI workflows, container files, deployment files, or release automation.
Do not implement invoice, client, project, billing, analytics, identity, or PDF behavior.
Do not edit mission planning artifacts, task prompts, status logs, or other work packages.

The root package may declare delegation commands whose producers land in later work packages.
Those declarations are interfaces, not authorization to create their downstream targets here.

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
Use the project license identity selected by the mission rather than inventing a second license policy.

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
Declare the planned workspace boundary for the frontend without creating frontend files.
Do not include the Zig service as a synthetic npm package.

Keep root dependencies empty unless a dependency is strictly required by the root substrate.
Do not add Next.js, React, TypeScript, test frameworks, formatters, linters, or Zig tooling here.
Those choices belong to their producing work packages.
Do not use global installations as hidden repository dependencies.

Generate `package-lock.json` with npm `11.16.0` from the committed `package.json` and `.npmrc`.
Use the current lockfile format produced by the pinned npm version.
Do not hand-author or manually normalize the lockfile.
Ensure the lockfile records the root package consistently and contains no accidental dependencies.
Commit the lockfile as a first-class reproducibility input.

Use `npm ci` as the clean-install contract whenever a lockfile already exists.
Use lockfile-only generation only for the initial substrate or a deliberate package metadata change.
An ordinary clean install must not change `package.json` or `package-lock.json`.

## T003 — Focused Command Surface and Prerequisite Diagnostics

Declare stable root npm scripts for the focused checks described by the plan.
The names must be discoverable and remain consistent for later work packages.
Include, at minimum, the following root-facing commands:

- `prerequisites:check`
- `contracts:check`
- `api:check`
- `web:check`
- `persistence:integration`
- `http:smoke`
- `licenses:check`
- `verify:substrate`
- `verify:foundation`
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

Implement those preflight guards within package scripts because this WP may not create helper files.
Keep inline checks readable, deterministic, and portable across supported Linux x86_64 environments.
Avoid shell features that obscure exit codes.
Forward delegated command exit codes unchanged.

`verify:foundation` must compose the final mission checks in a stable, fail-fast order.
It may remain expected to fail on missing downstream producers until those packages land.
Its present failure must be actionable rather than a stack trace or generic file-not-found error.
Do not weaken the final command merely to make it pass during WP01.

Development commands must perform the same prerequisite and path checks before delegating.
They must not download toolchains, start substitute servers, or invent application behavior.

## T004 — Clean-Bootstrap and Reproducibility Tests

Verify the substrate on the exact pinned toolchain in a clean environment.
Perform verification from a clean checkout or isolated temporary copy, not from cached workspace state alone.
Do not add test fixtures or test programs outside the five owned root files.

The verification sequence must prove all of the following:

- the version files contain one exact version each;
- `package.json` parses and contains exact engine and package-manager declarations;
- workspace declarations match the planned frontend boundary;
- `.npmrc` enforces the intended deterministic settings;
- `package-lock.json` is accepted by `npm ci` under npm `11.16.0`;
- `npm ci` does not mutate `package.json` or `package-lock.json`;
- repeated clean installs leave the lockfile byte-identical;
- `verify:substrate` succeeds on the supported platform and versions;
- a missing Zig executable produces the designed diagnostic and a nonzero exit;
- a wrong tool version produces expected-versus-observed diagnostics and a nonzero exit;
- a downstream focused command names its missing producer instead of silently succeeding;
- root scripts propagate failures from delegated commands.

Capture a checksum of `package-lock.json` before and after repeated installs.
Use repository diff checks to prove that the five owned files remain unchanged.
Remove only disposable install state created by the test.
Do not delete or rewrite user-owned files.
Do not require network access after a valid npm cache is prepared for this dependency-free substrate.

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
4. Confirm no unowned files were added or modified.

Run supported-path checks next:

1. Confirm `node --version` is `v24.18.0`.
2. Confirm `npm --version` is `11.16.0`.
3. Confirm `zig version` is `0.16.0`.
4. Confirm `uname` and Node platform data resolve to Linux x86_64/x64.
5. Run `npm run prerequisites:check`.
6. Run `npm ci` using the committed lockfile.
7. Run `npm run verify:substrate`.

Run reproducibility and negative-path checks last.
Record exact commands and outcomes in the Activity Log.
Do not run `verify:foundation` as a WP01 success gate when its producers are intentionally absent.
Do run it once to verify that its first missing prerequisite is diagnosed accurately.

## Risks and Mitigations

- Risk: an unpinned npm regenerates a different lockfile. Mitigation: verify npm first and generate only with `11.16.0`.
- Risk: inline preflight scripts become unreadable. Mitigation: keep each guard narrow and delegate real work downstream.
- Risk: workspace globs accidentally claim backend ownership. Mitigation: declare only the planned frontend workspace boundary.
- Risk: missing downstream paths look like successful checks. Mitigation: explicit nonzero preflight guards with named producers.
- Risk: root scripts encode speculative business behavior. Mitigation: restrict them to orchestration and prerequisites.
- Risk: install tests mutate tracked metadata. Mitigation: hash files, inspect diffs, and fail on mutation.
- Risk: local toolchain mismatch hides static correctness. Mitigation: separate static verification from supported-toolchain execution and report both.

## Definition of Done

- All five create-intent files exist and are the only repository files changed by WP01.
- Node.js `24.18.0`, npm `11.16.0`, and Zig `0.16.0` are pinned exactly and consistently.
- Linux x86_64 is validated as the supported execution platform.
- The root npm package is private and declares the planned frontend workspace boundary.
- `package-lock.json` was generated by the pinned npm and is committed without accidental dependencies.
- The focused command surface is present with explicit downstream prerequisite diagnostics.
- `verify:substrate` succeeds on the supported toolchain.
- Clean `npm ci` runs are reproducible and leave root metadata byte-identical.
- Negative prerequisite cases fail nonzero with expected and observed values.
- No application source, service build file, CI configuration, or business behavior was introduced.
- The Activity Log contains commands, results, limitations, and any blocked exact-toolchain checks.

## Review Guidance

Review ownership before behavior: every diff path must match `package*.json`, `.*-version`, or `.npm*`.
Reject application code, helper scripts, CI files, or service build files in this package.
Compare every pinned version against the plan rather than the reviewer's local defaults.
Confirm the lockfile is tool-generated and reproducible under npm `11.16.0`.
Inspect prerequisite failures for actionable expected-versus-observed diagnostics.
Confirm missing downstream producers fail explicitly and are not silently skipped.
Confirm `verify:substrate` is independently useful before other work packages land.
Treat downstream-focused checks as declared interfaces; do not require their implementations in WP01.
Verify the full command surface is compatible with later work without preempting their owned files.

## Activity Log

- 2026-07-20T07:00:27Z – system – Prompt created for WP01 reproducible repository substrate implementation.
- Append implementation start, material decisions, verification commands, and results chronologically below this line.

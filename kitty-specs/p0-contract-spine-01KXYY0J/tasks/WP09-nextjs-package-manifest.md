---
work_package_id: WP09
title: Next.js Package Manifest
dependencies:
- WP01
- WP02
- WP03
requirement_refs:
- FR-001
- NFR-012
- C-002
- C-009
tracker_refs: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch.
subtasks:
- T042
phase: Phase 3
assignee: ''
agent: codex
history: []
agent_profile: frontend-freddy
authoritative_surface: apps/web/
create_intent:
- apps/web/package.json
- apps/web/next.config.ts
- apps/web/tsconfig.json
- apps/web/eslint.config.mjs
- apps/web/vitest.config.ts
- apps/web/playwright.config.ts
execution_mode: code_change
model: ''
owned_files:
- apps/web/package.json
- apps/web/*config*
role: implementer
tags: []
task_type: implement
---

# Work Package Prompt: WP09 – Next.js Package Manifest

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `frontend-freddy`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Declare the exact Next.js workspace package and deterministic app-local configuration that
WP10 will integrate after the ready Zig boundary exists. This package produces metadata only:
it does not install dependencies, reconcile the root lock, create UI/runtime source, generate
contracts, or claim build and test evidence before the integration steward runs.

## Context

- WP01 owns root `package.json`, the initial root lock, npm policy, scripts, and tool pins.
- WP02 owns canonical wire values and fixtures; do not restate them in configuration.
- WP03 owns `tools/contracts`, its stable package export, and all generated TypeScript.
- WP09 owns only `apps/web/package.json` and paths matched by `apps/web/*config*`.
- WP10 is the sole later codebase-wide root-lock integration steward.
- WP10 owns all app shell, client, adapter, test, proxy-integration, and E2E source.
- Consume dependency contracts by package/workspace name; never point at generated files.
- Use Next.js App Router, server components by default, and a server-only proxy seam.
- Keep P0 foundation-only; add no product dependency or speculative UI framework.

## Hard Ownership Boundary

- Create or edit only the exact frontmatter-owned package/config paths.
- Never edit root `package.json`, root `package-lock.json`, `.npmrc`, or version files.
- Never create `apps/web/package-lock.json` or any competing lock.
- Never create files below `apps/web/src/` or `apps/web/tests/`.
- Never create, copy, edit, or commit generated TypeScript or OpenAPI output.
- Never edit `tools/contracts`, contracts, Zig code, CI, documentation, or mission state.
- Do not run a command that writes lockfiles, caches, generated output, or source.
- If WP01 or WP03 metadata is insufficient, record an integration request for its owner.

## Branch Strategy

- **Strategy**: `wp_branch`
- **Planning base branch**: `feat/p0-contract-spine`
- **Merge target branch**: `feat/p0-contract-spine`
- Start with the governed implementation action:

```bash
spec-kitty agent action implement WP09 --agent codex
```

- Verify accepted WP01, WP02, and WP03 metadata contracts are available first.
- Do not merge, rebase, tag, publish, or advance mission state from this package.

## Subtasks & Detailed Guidance

### Subtask T042 – Exact Web Package and Static Configuration

**Purpose**

Create a private independently addressable web workspace whose exact dependency declarations,
scripts, compiler/lint/test configuration, and server-only proxy contract are ready for WP10's
serialized lock reconciliation and runtime validation.

### Package Metadata

1. Create `apps/web/package.json` as valid deterministic JSON with stable key ordering.
2. Set `private: true`; give the workspace a stable non-publishable package identity/version.
3. Pin Next.js to exactly `16.2.10`.
4. Pin React and React DOM to exactly `19.2.7` each.
5. Pin TypeScript to exactly `6.0.3`.
6. Pin ESLint to exactly `10.7.0`.
7. Pin `eslint-config-next` to the exact Next.js-compatible release selected by the package.
8. Declare only tooling required by WP10's format, lint, strict type, component,
   accessibility, production-build, and Playwright foundation workflow.
9. Give every additional runtime, type, DOM, component-test, accessibility, and Playwright
   package one explicit full semantic version; preserve any exact selections from the source
   prompt and never use caret, tilde, wildcard, tag, range, branch, or `latest`.
10. Use no Git URL, private registry, unpublished package, sibling path, absolute path,
    `file:` dependency, or moving reference.
11. Declare WP03's contract-tool workspace by its stable package name only when required for
    normal package resolution; never reference `.generated` or a repository-relative file.
12. Keep runtime dependencies separate from development-only validation tooling.
13. Do not add Tailwind, CSS-in-JS, UI kits, charts, state managers, data clients, form
    libraries, icon packs, remote fonts, authentication, databases, or feature packages.
14. Provide package-local scripts for dev, format/check, lint, typecheck, component tests,
    E2E, and production build, using stable command names consumed by WP01/WP10.
15. Keep scripts declarative; do not embed lock regeneration, downloads, generated-type copies,
    shell-specific mutation, hidden network bootstrap, or direct Zig process management.
16. Require Node/npm versions consistent with WP01 without redefining the root toolchain.
17. End the JSON file with one newline and include no comments or environment-specific data.

### TypeScript and Next.js Configuration

18. Create strict `apps/web/tsconfig.json` with `strict: true`, `noEmit: true`, modern module
    resolution, and no `any` or unchecked-index escape hatch added for convenience.
19. Include only future app source/tests and framework-generated type locations by convention;
    do not create those files or generated directories in WP09.
20. Resolve WP03 contracts through the package export, never a TypeScript path alias into
    `tools/contracts/.generated/typescript/v1/`.
21. Create `apps/web/next.config.ts` for App Router/server behavior and deterministic builds.
22. Define `/api/v1/:path*` as a server-side proxy/rewrite contract for WP10.
23. Read the internal Zig base origin only from a server-only environment variable.
24. Forbid `NEXT_PUBLIC_*` backend origins and request-controlled proxy destinations.
25. Preserve path/query semantics and make invalid/missing origin configuration fail clearly.
26. Do not add CORS, a browser-direct backend URL, remote font/image hosts, analytics,
    telemetry integration, experimental flags, or feature routes.
27. Keep configuration deterministic: no timestamps, host paths, random ports, branch names,
    network discovery, or filesystem scans outside the workspace contract.

### Lint, Component-Test, and E2E Configuration

28. Create `apps/web/eslint.config.mjs` using ESLint Flat Config and Next correctness rules.
29. Do not globally disable framework, accessibility, hooks, server/client, or TypeScript rules.
30. Keep ignores limited to known dependency/build/test artifact paths.
31. Create `apps/web/vitest.config.ts` with a deterministic DOM environment and setup contract.
32. Restrict component-test discovery to WP10's `apps/web/tests/foundation/**` ownership.
33. Disable uncontrolled retries, random ordering, live network, and watch mode in CI defaults.
34. Create `apps/web/playwright.config.ts` for WP10's real production-shaped Next.js server.
35. Restrict E2E discovery to foundation tests and use a fixed local Next.js origin.
36. Define bounded startup/readiness/test timeouts and deterministic retry/worker policy.
37. Do not mock away the Zig boundary in E2E configuration or expose its origin to browser code.
38. Leave actual service startup, fixtures, browser assertions, screenshots, and performance
    measurement to WP10; this package writes configuration only.

## Static and Deterministic Validation

The root lock intentionally does not yet contain WP09 dependencies. Therefore validation here
must be read-only and must not depend on dependency installation, compilation, or execution.

1. Parse `apps/web/package.json` with a standard JSON parser.
2. Assert the six approved core version pins are exact literal values.
3. Assert every other declared package uses one full exact semantic version or the approved
   local workspace identity; reject all range/moving/private/local-path forms.
4. Assert package scripts contain no install, lock rewrite, generated-copy, or remote-download
   side effects and refer only to the declared toolchain.
5. Statically inspect all five config files for deterministic values and owned-path references.
6. Search for `NEXT_PUBLIC` backend configuration, direct Zig browser origins, remote fonts,
   generated-path aliases, sibling/local dependencies, and speculative product packages.
7. Run `git diff --check` and require every changed path to match one of the two owned globs.
8. Require `git diff --name-only` to exclude all root metadata/locks, app source/tests,
   generated output, caches, and build artifacts.
9. Record exact package versions, config paths, static checks, and results in the Activity Log.

### Commands Explicitly Forbidden in WP09

- Do not run `npm install`, `npm ci`, `npm update`, or any lock-only installation command.
- Do not run build, typecheck, lint, component, Playwright, dev-server, or proxy smoke gates.
- Do not invoke contract generation or create framework/type/test caches.
- Do not claim dependency compatibility or runtime behavior from static metadata review alone.

## Explicit WP10 Handoff

- WP10 consumes the accepted WP09 metadata after WP08 and all other dependencies are ready.
- WP10 alone regenerates root `package-lock.json` with pinned npm 11.16.0.
- WP10 verifies the semantic lock diff, exact resolutions/integrity, and WP03 workspace link.
- WP10 runs `npm ci`, format/lint/type/component/build gates, real proxy E2E, and performance.
- Any resolution/config incompatibility returns to WP09 with the exact path and diagnostic.
- WP09 must not preempt that serialized integration by writing a lock or implementation source.

## Definition of Done

- [ ] T042 creates only `apps/web/package.json` and `apps/web/*config*` files.
- [ ] Next 16.2.10 and React/React DOM 19.2.7 are exact.
- [ ] TypeScript 6.0.3 and ESLint 10.7.0 are exact.
- [ ] Every additional declared package has an explicit exact version.
- [ ] Package scripts cover WP10's gates without install/lock/generation side effects.
- [ ] Strict TypeScript, Flat ESLint, deterministic Vitest, and Playwright configs exist.
- [ ] Server-only same-origin proxy configuration exposes no browser backend origin.
- [ ] No root package/lock, app source/test, contract, or generated output changed.
- [ ] Static validation passes without installing, building, or generating anything.
- [ ] Lock, install, runtime, E2E, and performance evidence is explicitly deferred to WP10.

## Risks & Mitigations

- **Metadata races the root lock**: WP09 never writes a lock; WP10 reconciles once later.
- **Static checks overclaim compatibility**: label them metadata-only and require WP10 runtime.
- **Ranges make resolution drift**: require exact full versions and reject moving references.
- **Config smuggles implementation scope**: own config only; leave all source/tests to WP10.
- **Generated contracts gain a second path**: reference only WP03's stable workspace package.
- **Proxy leaks the Zig origin**: keep configuration server-only with no public variable.
- **Speculative dependencies enlarge P0**: declare only the minimum foundation toolchain.

## Reviewer Guidance

- Compare all allowed WPMetadata fields with WP09 in `wps.yaml` and require T042 only.
- Review changed paths before content; reject any path outside the two ownership entries.
- Parse package JSON and verify every version/source form deterministically.
- Confirm the exact core pins and inspect every additional tool for necessity and exactness.
- Inspect scripts for mutation, download, lock, generation, or implementation side effects.
- Inspect configs for server-only origin handling, strictness, bounded tests, and stable paths.
- Confirm no app source/test/generated artifact or root package/lock is present in the diff.
- Reject install/build/test evidence as out of sequence; require the explicit WP10 handoff.

## Activity Log

> Entries must remain chronological. Append new entries at the end.

- 2026-07-20T07:11:44Z – system – WP09 reduced to exact web package metadata and
  deterministic static configuration, with serialized lock and runtime proof handed to WP10.

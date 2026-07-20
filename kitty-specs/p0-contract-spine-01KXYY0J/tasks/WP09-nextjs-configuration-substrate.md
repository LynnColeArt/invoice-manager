---
work_package_id: WP09
title: Next.js Configuration Substrate
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
- apps/web/next.config.ts
- apps/web/tsconfig.json
- apps/web/eslint.config.mjs
- apps/web/vitest.config.ts
- apps/web/playwright.config.ts
execution_mode: code_change
model: ''
owned_files:
- apps/web/*config*
role: implementer
tags: []
task_type: implement
---

# Work Package Prompt: WP09 – Next.js Configuration Substrate

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `frontend-freddy`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Create only deterministic app-local Next.js, TypeScript, lint, component-test, and E2E
configuration for WP10. Prove statically that every package, executable, preset, plugin,
environment, and version-sensitive behavior assumed by those configs already exists at the
exact version in WP01's immutable app package metadata and root lock.

WP09 does not create or edit npm metadata, install dependencies, reconcile a lock, create
application or test source, generate contracts, or claim runtime acceptance.

## Context

- WP01 is the sole owner of root `package.json`, `apps/web/package.json`, every exact web
  dependency declaration, npm policy, and the sole root `package-lock.json`.
- WP09 consumes all WP01 npm metadata and lock bytes read-only and routes any gap to WP01.
- WP02 owns canonical cross-runtime values and fixtures; configuration must not redefine them.
- WP03 owns the contract workspace export and all generated TypeScript; configuration may
  resolve its declared package export but never a generated filesystem path.
- WP10 owns all app source, adapters, component/accessibility tests, proxy E2E, and runtime
  evidence. It consumes WP01 metadata/lock and WP09 configuration without editing either.
- WP09 owns only paths matched by `apps/web/*config*`.
- Use App Router, server components by default, and a server-only same-origin proxy seam.
- Keep P0 foundation-only; configuration must not smuggle in a product framework or feature.

## Hard Ownership Boundary

- Create or edit only the five configuration files listed in `create_intent`.
- Never edit `package.json`, `apps/web/package.json`, `package-lock.json`, `.npmrc`, or a
  version file; hash these inputs before and after validation and require byte identity.
- Never create `apps/web/package-lock.json` or any second package/lock boundary.
- Never run `npm install`, `npm ci`, `npm update`, lock-only installation, or another command
  that could mutate metadata, the root lock, dependency state, or an install tree.
- Never create files under `apps/web/src/` or `apps/web/tests/`.
- Never create, copy, edit, or commit generated TypeScript, OpenAPI output, caches, snapshots,
  screenshots, framework output, coverage, or build artifacts.
- Never edit contracts, `tools/contracts`, Zig code, root scripts, CI, docs, or mission state.
- If a required tool/version is absent or inconsistent, stop and report the exact expectation,
  declaration, lock entry, and required WP01 correction; do not repair it here.

## Branch Strategy

- **Strategy**: `wp_branch`
- **Planning base branch**: `feat/p0-contract-spine`
- **Merge target branch**: `feat/p0-contract-spine`
- Start with the governed implementation action:

```bash
spec-kitty agent action implement WP09 --agent codex
```

- Verify accepted WP01, WP02, and WP03 outputs are present before implementation.
- Do not merge, rebase, tag, publish, or advance mission state from this package.

## Subtasks & Detailed Guidance

### Subtask T042 – Static Next.js Configuration Against the Immutable Lock

**Purpose**

Publish configuration that is complete enough for WP10 to implement against while proving,
without installation or execution of package tools, that every configuration expectation is
already declared exactly and resolved immutably by WP01.

### Read-Only Metadata and Lock Preflight

1. Parse root `package.json`, `apps/web/package.json`, and root `package-lock.json` read-only.
2. Require the app workspace entry, exact dependency declarations, exact package-lock
   resolutions, integrity evidence, and workspace link to agree.
3. Build a deterministic expectation inventory before writing configuration. For each config,
   list every imported package, CLI, preset, plugin, parser, environment, and framework API.
4. Map every expectation to its exact app-manifest declaration and exact root-lock entry.
5. Require full exact semantic versions; reject range, tag, Git, private-registry, sibling,
   absolute, `file:`, unpublished, or other moving/local sources.
6. Require the lock to contain the expected resolved version and integrity for every external
   package plus the declared workspace relationship for WP03's package export.
7. Verify version-sensitive config syntax and options against the exact locked tool version;
   do not silently fall back to a locally or globally installed version.
8. At minimum inventory Next.js, TypeScript, ESLint and all imported presets/plugins, the
   configured DOM test environment, Vitest, Playwright, and any referenced test support tool.
9. Reject an unused locked tool as authorization to add unrelated configuration behavior.
10. Record the expectation-to-declaration-to-lock mapping in the Activity Log.

### TypeScript and Next.js Configuration

11. Create strict `apps/web/tsconfig.json` with `strict: true`, `noEmit: true`, modern module
    resolution, and no convenience escape from unchecked access or type safety.
12. Include future WP10 app/test paths and framework type locations by convention only; do not
    create those paths, `.next` output, generated declarations, or setup source.
13. Resolve WP03 contracts by its stable workspace package export, never through a path alias
    into `tools/contracts/.generated/typescript/v1/`.
14. Create `apps/web/next.config.ts` for deterministic App Router/server behavior.
15. Define `/api/v1/:path*` as the server-side proxy/rewrite contract consumed by WP10.
16. Read the internal Zig origin only from a server-only environment variable and fail clearly
    for missing or invalid configuration.
17. Forbid `NEXT_PUBLIC_*` backend origins, request-controlled destinations, browser-direct Zig
    URLs, CORS workarounds, remote fonts/images, analytics, telemetry, and experimental flags.
18. Preserve path/query semantics without adding feature routes or product behavior.
19. Keep both configs free of timestamps, host paths, branch names, random ports, network
    discovery, or filesystem scans outside the workspace contract.

### Lint, Component-Test, and E2E Configuration

20. Create `apps/web/eslint.config.mjs` with the exact locked ESLint Flat Config APIs and exact
    locked Next/TypeScript presets or plugins from the preflight inventory.
21. Do not globally disable framework, accessibility, hooks, server/client, or TypeScript rules.
22. Limit ignores to known dependency, generated, build, coverage, and test-artifact paths.
23. Create `apps/web/vitest.config.ts` with the exact locked DOM environment, deterministic
    defaults, bounded timeouts, no live network, no watch mode in CI, and no random ordering.
24. Restrict component-test discovery to WP10's `apps/web/tests/foundation/**`; reference a
    setup path only if WP10 owns and is explicitly required to create that source.
25. Create `apps/web/playwright.config.ts` for WP10's real production-shaped Next.js server.
26. Restrict E2E discovery to WP10 foundation tests and use a fixed local Next.js origin.
27. Define bounded startup/readiness/test timeouts and deterministic retries/workers.
28. Do not mock away the Zig boundary or expose its origin to browser code.
29. Leave service startup, fixtures, assertions, screenshots, and performance measurement to
    WP10; a configuration path reference never grants WP09 ownership of its target.

## Static and Deterministic Validation

Run validation without installing packages or importing config modules through dependency code.

1. Reparse the three WP01-owned JSON inputs and rederive the complete expectation mapping.
2. Fail if any config import, executable, preset, plugin, environment, option, or framework API
   lacks an exact matching declaration and root-lock resolution.
3. Statically parse or inspect all five owned configs using only the pinned system Node runtime
   and read-only scripts supplied by WP01; do not generate a helper file.
4. Search configs for undeclared packages, generated-path aliases, public backend variables,
   browser-direct Zig origins, remote assets, unbounded retries, and speculative dependencies.
5. Recompute preflight SHA-256 values for all npm metadata/lock inputs and require exact match.
6. Run `git diff --check` over the five configuration paths.
7. Require `git diff --name-only` to contain only paths matched by `apps/web/*config*`.
8. Confirm no source, tests, generated output, caches, dependency tree, or build output exists in
   the WP diff or as a validation side effect.
9. Record exact commands, inventory entries, versions, lock paths, hashes, and results.

### Commands Explicitly Forbidden in WP09

- Do not run any install, update, lock-generation, package-execution, or package-manager repair.
- Do not run Next.js, TypeScript, ESLint, Vitest, Playwright, build, dev, or proxy smoke gates.
- Do not invoke contract generation or create framework, type, test, or coverage caches.
- Do not claim compatibility or runtime behavior from static config/lock review alone.

## Explicit WP10 Handoff

- WP10 consumes accepted WP09 configs and WP01's immutable app manifest/root lock unchanged.
- WP10 materializes WP03 generated exports before typecheck/build as its prompt requires.
- WP10 runs the real format/lint/type/component/build, proxy E2E, and performance evidence.
- Any config incompatibility returns to WP09 with the exact file and diagnostic.
- Any missing dependency, version, script, or lock entry returns to WP01; neither WP09 nor WP10
  may edit npm metadata or regenerate the root lock.

## Definition of Done

- [ ] T042 creates only the five declared `apps/web/*config*` files.
- [ ] Every config expectation maps to an exact app declaration and immutable root-lock entry.
- [ ] WP01-owned npm metadata and root lock remain byte-identical before/after validation.
- [ ] Strict TypeScript, Flat ESLint, deterministic Vitest, and Playwright configs exist.
- [ ] Server-only same-origin proxy configuration exposes no browser backend origin.
- [ ] No package metadata, lock, app source/test, contract, or generated output changed.
- [ ] Static validation passes without installation, package execution, build, or generation.
- [ ] Runtime, E2E, and performance evidence is explicitly deferred to WP10.

## Risks & Mitigations

- **Config requests an undeclared tool**: inventory every expectation and route gaps to WP01.
- **Static review overclaims compatibility**: label evidence configuration-only; WP10 runs tools.
- **An install silently mutates state**: prohibit all installs and hash metadata/lock inputs.
- **Config smuggles implementation scope**: own only config; source/tests remain WP10-owned.
- **Generated contracts gain a second path**: resolve only WP03's stable package export.
- **Proxy leaks the Zig origin**: keep it server-only with no public environment variable.

## Reviewer Guidance

- Treat committed `tasks.md`, this prompt frontmatter, and `lanes.json` as authority; never
  require or compare transient `wps.yaml`.
- Review changed paths before content; reject anything outside `apps/web/*config*`.
- Reproduce the expectation inventory against WP01's read-only app manifest and root lock.
- Confirm every imported/referenced tool and version-sensitive option has an exact lock entry.
- Inspect configs for server-only origin handling, strictness, bounded tests, and stable paths.
- Confirm no npm metadata/lock, source, test, generated artifact, dependency tree, or cache changed.
- Reject install/build/test evidence as out of sequence and enforce WP01/WP10 failure routing.

## Activity Log

> Entries must remain chronological. Append new entries at the end.

- 2026-07-20T07:11:44Z – system – WP09 transformed into a configuration-only substrate
  consuming WP01's immutable npm metadata/lock and handing runtime proof to WP10.

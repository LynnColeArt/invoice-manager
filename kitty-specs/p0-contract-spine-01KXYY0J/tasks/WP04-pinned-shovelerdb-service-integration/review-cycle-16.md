---
affected_files:
  - services/api/build.zig
  - services/api/tests/persistence/shovelerdb_build_discovery.zig
blocking_findings: 1
cycle_number: 16
implementation_commit: 9b9b7d9
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T05:49:23-05:00'
reviewer_agent: 'codex:dependency-review'
verdict: rejected
wp_id: WP04
---

# WP04 Review Cycle 16 — REJECTED

The accepted WP04 HTTP hook correctly materializes contracts and exposes the
approved shared, persistence, and migration dependencies, but the first real
WP08 consumer proves that the hook is not yet usable as an HTTP test boundary.

## Blocking finding

### B1 — HTTP tests cannot reach the production boundary or spawned executable

`configureHttp` creates each `tests/http/*.zig` file as an isolated Zig module
with only `shared`, `persistence`, and `migrations` named imports. Zig 0.16
therefore rejects a real WP08 test importing `../../src/http/server.zig` with
`error: import of file outside module path`. The compiler invocation confirms
that no HTTP or composition-root module is present. The hook also builds the API
executable only for `zig build run`; HTTP tests receive neither a named
composition-root module nor the emitted executable path required for strict
child-process black-box coverage.

Reproduction from the dependency-composed WP08 lane:

```text
zig build test-http --build-file services/api/build.zig
```

The command runs the exact contract materializer, then fails while compiling
`tests/http/health_test.zig` and `tests/http/envelope_test.zig` on imports that
escape the test module root. This failure cannot serve as WP08's required
route-policy RED because that package explicitly excludes missing imports and
build failures.

Required narrow correction:

1. Add a named `http` module rooted at `src/http/root.zig` with the approved
   public dependency imports.
2. Add a named composition-root module rooted at `src/main.zig` and give it the
   exact `shared`, `persistence`, `migrations`, and `http` graph used by the real
   executable.
3. Build the real API executable before HTTP tests and expose its emitted path
   through a named generated options module such as `http_test_config`, so
   black-box tests can spawn the actual program without guessing cache paths.
4. Give every HTTP test root the `http`, composition-root, and test-config
   modules in addition to the already approved dependency modules.
5. Preserve the exact materializer as a direct prerequisite of every affected
   compile step and keep the existing fail-closed producer checks.
6. Extend the permanent WP04 build-discovery fixture to compile/refAllDecls the
   new public modules and prove the configured executable path exists and is the
   emitted real artifact. Record a qualifying public RED before product changes.

Do not change WP08 source to bypass module isolation, copy production code into
tests, weaken the generated-inventory prerequisite, or introduce a second HTTP
registry. No ShovelerDB adapter, ABI, persistence, migration, coverage, root
script, or web change is requested.

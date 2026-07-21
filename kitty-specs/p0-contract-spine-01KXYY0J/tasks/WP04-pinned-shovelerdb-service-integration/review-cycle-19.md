---
affected_files:
  - services/api/build.zig
  - services/api/tests/persistence/shovelerdb_build_discovery.zig
blocking_findings: 1
cycle_number: 19
implementation_commit: da7e7e3a
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T06:28:57-05:00'
reviewer_agent: 'codex:wp08-consumer-review'
verdict: rejected
wp_id: WP04
---

# WP04 Review Cycle 19 — REJECTED

Cycle 18 correctly enforces the least-authority HTTP graph. The first real
route-inventory consumer now exposes one remaining package-root integration
defect in WP04's named HTTP module.

## Blocking finding

### B1 — the locked canonical inventory embed cannot resolve from the HTTP module

WP08 must embed exactly
`../../../../tools/contracts/.generated/runtime/v1/route-inventory.json` once
from `src/http/route_inventory.zig`. With `http` rooted at
`services/api/src/http/root.zig`, Zig 0.16 rejects that required expression as
`embed of file outside package path`. The exact repository-root gate therefore
cannot compile the sole route-inventory boundary even though the materializer
has produced the JSON successfully:

```text
zig build test-http --build-file services/api/build.zig
```

This is an upstream build-graph failure, not WP08's qualifying policy RED. That
behavioral RED is already committed and recorded separately.

Zig 0.16 supports the required least-authority correction: a module dependency
may be keyed by the exact embed literal and rooted at the generated JSON. A
minimal compiler probe confirmed that `@embedFile("route_bytes")` resolves when
the same dependency name is supplied as a module rooted at the target file.

Required narrow correction:

1. Add one read-only module dependency to the production `http` module whose
   import key is exactly
   `../../../../tools/contracts/.generated/runtime/v1/route-inventory.json` and
   whose root source is the canonical generated JSON at repository level.
2. Keep HTTP's executable Zig capability graph otherwise `http={shared}`; do
   not restore persistence/migration access or add a second registry/wrapper.
3. Preserve the exact repository-root materializer as a prerequisite before
   any compile can resolve the generated file.
4. Add a permanent WP04 discovery fixture whose synthetic HTTP module executes
   the exact locked `@embedFile` expression. Against the current graph it must
   fail specifically on outside-package resolution; record and commit that RED
   before the build correction.
5. After correction, prove the positive consumer fixture embeds the materialized
   bytes, the existing forbidden-persistence fixture still reports
   `no module named 'persistence'`, discovery remains fully green, and the real
   emitted executable/config/run behavior is unchanged.

No WP08 product workaround, generated Zig wrapper, filesystem read, build-root
expansion, persistence/migration import, root-script change, or generated-file
write is permitted.


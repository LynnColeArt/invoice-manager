---
affected_files: []
cycle_number: 4
mission_slug: p0-contract-spine-01KXYY0J
reproduction_command:
reviewed_at: '2026-07-21T02:26:25Z'
reviewer_agent: codex
verdict: rejected
wp_id: WP04
---

# WP04 post-approval correction

## Blocking finding

`configurePersistence` unconditionally calls `createSharedModule`, whose root is
`src/shared/root.zig`, and passes that module into every focused WP06 test and
coverage artifact. WP06 formally depends only on WP04 and its owned scope
explicitly forbids creating or editing WP05 shared files. In a dependency-clean
WP06 lane, all `test-persistence*` hooks therefore fail before compiling WP06
with `failed to check cache: 'src/shared/root.zig' FileNotFound`.

## Required correction

- Focused WP06 persistence modules must not instantiate, import, or require the
  WP05 shared producer.
- `createPersistenceModule` must support the WP06 dependency-clean graph while
  retaining the later WP07 graph once shared exists.
- Persistence production coverage validation must reject a named or relative
  shared import in the WP06 scope.
- Add a discovery/build regression proving a complete persistence producer
  compiles and measures without `src/shared/**`.
- Preserve the accepted shared and migration coverage graphs and all prior
  adversarial, ABI, provenance, clean-copy, tamper, and npm evidence.

This is a build-integration defect in WP04's owned surface, not permission for
WP06 to add an out-of-scope shared stub or acquire an undeclared WP05 dependency.

---
affected_files:
  - path: services/api/src/platform/persistence/shovelerdb.zig
  - path: services/api/tests/persistence/shovelerdb_adapter_test.zig
blocking_findings: 1
cycle_number: 8
implementation_commit: 40d6661
mission_slug: p0-contract-spine-01KXYY0J
reproduction_command: inspect the accepted WP04 adapter and WP06 public Executor against WP07 T034
reviewed_at: '2026-07-21T04:45:00Z'
reviewer_agent: 'codex:architect-preflight'
verdict: rejected
wp_id: WP04
---

# WP04 Review Cycle 8

Verdict: **REJECT — downstream adapter capability is incomplete**

The accepted provenance, ABI, coverage-isolation, and sanitized-diagnostic work
remains valid. A pre-approval WP07 compatibility audit found one blocking
adapter seam omission that must be corrected before WP06 can expose the generic
application-neutral boundary required by the migration runner.

## Blocking finding: required runtime statements cannot cross the adapter safely

The accepted adapter exposes reviewed compile-time SQL through `execute` and a
single escaped runtime text literal through `executeText`. WP07 T034 must write
and later read an applied-migration record containing an ID, owner, descriptor
digest, script digest, and canonical UTC instant. Its owned files may consume
only the WP06 public facade; they may not edit or import the adapter.

With only one dynamic literal per statement, WP06 cannot offer a safe generic
multi-value statement boundary. WP07 would be forced either to construct and
execute unrestricted runtime SQL, weaken the required history schema, or edit
an upstream work package. All three outcomes contradict the frozen ownership
and SQL-safety decisions.

The same audit found that recursively discovered `up.sql` is necessarily a
runtime byte sequence. Even after WP07 validates its canonical path and exact
published digest, the adapter's compile-time-only `execute` operation cannot
run it. Calling the private runtime `executeOwned` is impossible outside WP04,
and exporting raw adapter access would violate the persistence facade. WP04
therefore also needs a narrow exact-script primitive for WP06's distinct
startup-only executor; it is not a general domain-mutation API.

### Required correction

1. Add one generic adapter operation that interleaves a compile-time-reviewed
   sequence of SQL fragments with multiple runtime text values.
2. Encode every runtime value with the existing text-literal policy; reject
   embedded NULs and never accept a runtime SQL fragment or identifier.
3. Require the fragment/value arity to match exactly and return a typed error
   before engine execution when it does not.
4. Preserve `OwnedResult` ownership and all existing `execute`/`executeText`
   behavior. Do not add migration-specific types or logic to WP04.
5. Add an internal adapter operation for an exact runtime script byte sequence.
   Reject embedded NUL, create the sentinel form without normalization, execute
   the exact bytes, and keep this primitive out of downstream public exports.
   WP06 will expose it only through a separate opaque startup capability.
6. Add red-first adapter tests that insert and query at least five independently
   bound values, including quotes and empty text, and prove malformed arity,
   embedded NUL, allocation cleanup, and SQL-injection-shaped values are safe.
7. Add an exact-script regression that executes one synthetic DDL statement,
   rejects embedded NUL and a second trailing statement, and proves leading
   and trailing whitespace remain accepted. The pinned engine parses exactly
   one statement per call; WP04 must not invent an unreviewed SQL splitter.
8. Keep ShovelerDB C handles and unrestricted runtime SQL absent from every downstream
   public signature. WP06 will translate the internal `OwnedResult` into
   application-neutral persistence rows and a startup-only validated-script
   capability in its own correction cycle.
9. Re-run adapter Debug/ReleaseSafe, discovery, provenance, ABI, and all
   accepted coverage-isolation/adversarial gates. The public ShovelerDB pin and
   vendored digest must remain unchanged.

## Scope and prior evidence

This correction belongs to WP04 because `shovelerdb.zig` is its authoritative
adapter surface. It does not reopen the accepted dependency pin, license,
coverage ownership, diagnostic privacy, or build-discovery decisions except to
require their regression suites to remain green.

WP06 must not be approved until it consumes this operation through a generic
bound-statement/query-row facade and proves WP07 T034 can round-trip multiple
application-neutral values without importing adapter types.

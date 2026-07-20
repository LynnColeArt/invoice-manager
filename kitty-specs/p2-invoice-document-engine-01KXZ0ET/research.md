# Research: P2 Invoice Document Engine

## Scope and Dependencies

P2 plans against P0 `0.1.0-draft.1` and P1 `0.1.0-draft.1`. Both are Draft and
permit planning only. P2 implementation waits until every consumed artifact is
Frozen, merged, and revalidated on the current baseline.

## Decision 1: Exact Pricing

V1 supports fixed lines and quantity/rate lines as a tagged union. Quantity is a
positive canonical decimal string with at most six fractional digits. Zig parses
to a scaled integer, multiplies by Money minor units in `i128`, and rounds once
per line to the nearest minor unit with ties away from zero. A fixed line is the
escape hatch for an owner-selected total; calculated lines cannot be overridden.

This prevents JavaScript precision loss, preserves P0's canonical integer Money,
and gives downstream snapshots enough information to explain each total.

## Decision 2: Explicit Tax Semantics

Prices are tax-exclusive. Each line selects `standard`, `zero_rated`, `exempt`,
`reverse_charge`, or `out_of_scope`. Standard/zero rates use integer parts per
million: `200000` is 20%, `88750` is 8.875%. Zig calculates tax per line with an
`i128` intermediate and the same rounding rule, then sums the line taxes.

P2 performs arithmetic and presentation, not jurisdiction selection, filing, or
certification. Reverse charge requires an explicit display note; exempt and
out-of-scope are semantically distinct from numeric zero.

## Decision 3: Three Digest Meanings

- `snapshot_digest`: SHA-256 of RFC 8785 canonical JSON for the snapshot.
- `render_recipe_digest`: SHA-256 of a canonical record binding render payload,
  template source, font/package manifest, logo, and runtime digests.
- `artifact_digest`: SHA-256 of exact PDF bytes.

Domain spelling is `sha256:<64 lowercase hex>`. HTTP uses RFC 9530
`Content-Digest`. Digests prove byte identity, not legal validity.

## Decision 4: External OS Sandbox Is Mandatory

LuaLaTeX runs directly with shell escape disabled and fixed arguments, but TeX
flags are not the security boundary. TeX Live documents that TeX reads and
writes files and recommends isolation; the 2026 guide also says `openin_any` no
longer restricts reads. P2 therefore requires an OS-enforced child sandbox with
no network, no ambient host filesystem, no inherited descriptors, an unprivileged
identity, read-only pinned TeX/font/template trees, one private workspace, and
process/CPU/memory/file/output/wall limits. If the platform cannot establish the
sandbox, rendering fails closed.

Source: https://www.tug.org/texlive/doc/texlive-en/texlive-en.html

## Decision 5: Immutable Renderer and Typography

“TeX Live 2026” is not a sufficient pin because the live package repository can
change. Each released template binds exact runtime image/source digest, installed
package manifest, font bytes/licenses, template source digest, and supported
document-schema versions.

The first family is restrained black/gray typography with a pinned OFL sans
family, tabular figures, Letter/A4 variants, repeated multipage table headings,
right-aligned amounts, explicit currency codes, and generous whitespace.
Released template versions are append-only.

## Decision 6: PNG-Only Logo Boundary

P1 selects and stores a decoded, bounded PNG asset with immutable content digest.
P2 independently verifies type, dimensions, size, and digest before staging a
fixed workspace filename. SVG and PDF logos are excluded from v1 to reduce parser
and active-content surface.

## Decision 7: Preview Is Stateless

Evaluation and preview are synchronous and side-effect free. Preview data is
private temporary state, not a persistent job or public download. P2 produces a
receipt for final staged bytes but P5 owns number allocation, issuance,
transactional retention, and orphan reconciliation.

## Decision 8: Accessibility Is HTML-First

The PDF has an accessible title, but the review surface also renders a complete
semantic HTML summary and structured errors. The browser never recalculates
money; it formats Zig-returned amounts. Keyboard-only operation and an embedded-
PDF-independent fallback are acceptance requirements.

## Source Register Summary

Primary standards and project documentation are recorded in the CSV register:
TeX Live security behavior, RFC 8785 canonical JSON, RFC 9530 digest fields, and
the P0/P1 mission Draft contracts. All external claims are used as design input;
the executable sandbox and deterministic fixture tests remain the proof.

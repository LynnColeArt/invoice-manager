# P1 Planning Quickstart

P1 is a planning-only mission until P0 is Frozen and merged.

## Validate the planning artifacts

```sh
spec-kitty agent decision verify --mission 01KXYZD3
python3 -m json.tool kitty-specs/p1-parties-projects-01KXYZD3/contracts/resolved-invoice-configuration-v1.schema.json >/dev/null
python3 -m json.tool kitty-specs/p1-parties-projects-01KXYZD3/contracts/p1-contract-manifest.json >/dev/null
```

## Review the core decisions

1. Domestic and Other/Hide results omit the `remittance` property entirely.
2. Europe and Other/Show require a complete remittance block.
3. Effective identity resolves Project override, then Client default, then error.
4. Logo Off yields no reference; Logo On resolves Project asset, then identity
   default, then error.
5. USD/EUR values remain P0 Money strings and never enter JavaScript arithmetic.
6. Cadence fields are facts only; P6 owns recurrence and advancement.

## Consumer simulation

P2, P5, and P6 may plan against synthetic data conforming to the Draft schema.
They must record `0.1.0-draft.1` and may not begin implementation until the P0
and P1 contracts they consume are Frozen and available on their baseline.


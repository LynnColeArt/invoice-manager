# P2 Planning Quickstart

P2 is planning-only until its consumed P0/P1 contracts are Frozen and merged.

```sh
spec-kitty agent decision verify --mission 01KXZ0ET
python3 -m json.tool kitty-specs/p2-invoice-document-engine-01KXZ0ET/contracts/invoice-document-v1.schema.json >/dev/null
python3 -m json.tool kitty-specs/p2-invoice-document-engine-01KXZ0ET/contracts/p2-contract-manifest.json >/dev/null
```

Review these non-negotiable boundaries:

1. Zig is the sole source of line, tax, subtotal, and total values.
2. No raw TeX, template path, command, or process option is accepted.
3. LuaLaTeX runs only after OS filesystem/network/process isolation succeeds.
4. Domestic/hidden remittance is absent from data, TeX, diagnostics, and PDF.
5. Preview is not issuance; P5 owns numbers, durable retention, and lifecycle.


# P4 Planning Quickstart

P4 is planning-only until P0 is Frozen and the normalized input Draft is reviewed.

```sh
spec-kitty agent decision verify --mission 01KXZ1AJ
python3 -m json.tool kitty-specs/p4-reporting-dashboard-01KXZ1AJ/contracts/normalized-reporting-snapshot-v1.schema.json >/dev/null
python3 -m json.tool kitty-specs/p4-reporting-dashboard-01KXZ1AJ/contracts/p4-contract-manifest.json >/dev/null
```

Review four invariants: business as-of is distinct from projection watermark;
revisions advance exactly by one; money is always per currency; every chart has
the exact semantic table. P4 never mutates source domains.


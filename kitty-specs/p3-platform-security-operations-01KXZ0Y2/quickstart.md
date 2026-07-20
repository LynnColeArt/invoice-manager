# P3 Planning Quickstart

P3 is planning-only until P0 is Frozen and merged.

```sh
spec-kitty agent decision verify --mission 01KXZ0Y2
python3 -m json.tool kitty-specs/p3-platform-security-operations-01KXZ0Y2/contracts/backup-manifest-v1.schema.json >/dev/null
python3 -m json.tool kitty-specs/p3-platform-security-operations-01KXZ0Y2/contracts/p3-contract-manifest.json >/dev/null
```

Review the invariants: one offline-or-service data owner; Zig default-deny auth;
production HTTPS/private binds only; secrets never in argv/environment; backup
manifest written last; restore into a fresh empty root only; restored sessions
revoked before readiness.


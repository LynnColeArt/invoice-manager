# Invoice Manager

Invoice Manager is a deliberately boring, open-source billing application for a
small technical consulting business. P0 establishes the contract spine: a
Next.js App Router shell, a Zig business-service boundary, durable ShovelerDB
storage, deterministic contracts, and independently diagnosable validation.

The project is licensed under **GPL-3.0-only**. P0 is distributed as the
Git-tracked source repository. Apache-2.0 runtime dependencies are accepted only
with complete pinned license/notice evidence; LGPL components require an
explicit selection plus source and relinking evidence; attribution terms are
preserved. GPL-2.0-only combined-runtime code, unknown/custom licenses, missing
evidence, and unselected multi-license expressions fail closed. Container,
installed Zig-binary, and Next standalone packaging are deferred to P3 and are
not P0 distribution artifacts.

## Supported baseline

- Linux x86_64 with at least 4 logical CPUs and 16 GiB RAM for acceptance
- Node.js 24.18.0
- npm 11.16.0
- Zig 0.16.0
- Git

ShovelerDB is the unmodified 43-file GPL-3.0-only engine export at commit
`20dced69738bfce08f94368b8d017cfc283747fe`. Its public source, exact tree
and code digests, license, notice, build file, ABI header, included paths, and
excluded MariaDB reference corpus are recorded in
`deps/shovelerdb/PROVENANCE`.

The immutable contributor details are in the
[P0 quickstart](kitty-specs/p0-contract-spine-01KXYY0J/quickstart.md), governed
by the accepted WP11 receipt commit
`97b4094de279a0b568760f2e9a202f98dc64021d`.

## Clone and verify

After the public repository exists:

```bash
export INVOICE_MANAGER_REPOSITORY_URL=<public-repository-url>
git clone --recurse-submodules "$INVOICE_MANAGER_REPOSITORY_URL" invoice-manager
cd invoice-manager
npm run verify:foundation:clean
```

The clean wrapper installs the locked dependency graph and Playwright Chromium
revision 1228 inside its measured boundary, then delegates to the exact focused
aggregate. It does not use a system browser or a sibling repository.

For a first-run bootstrap including the production-shaped same-origin health
smoke:

```bash
npm run bootstrap:foundation
```

## Focused validation

Each gate is independently runnable and is also required by foundation CI:

```bash
npm run contracts:check
npm run web:check
npm run api:check
npm run migration:negative
npm run persistence:integration
npm run http:smoke
npm run licenses:check
npm run verify:foundation
```

`licenses:check` emits a deterministic machine-readable GPL-3.0-only report.
The committed LGPL evidence records libvips 8.17.3 source commit/archive
identity and the replaceable dynamic shared object used by the locked Linux x64
runtime. The full LGPL text is preserved under `tools/licenses/evidence/`.

## Local run

Create the database parent directory, then run the service and web application
in separate terminals:

```bash
mkdir -p .local
INVOICE_API_BIND=127.0.0.1 \
INVOICE_API_PORT=8080 \
INVOICE_DATABASE_PATH=.local/invoice-manager.db \
npm run dev:api
```

```bash
INVOICE_MANAGER_API_ORIGIN=http://127.0.0.1:8080 npm run dev:web
```

The supported health path is
`http://localhost:3000/api/v1/health`. It traverses production Next.js and the
real Ready Zig service through the same-origin App Router handler. Browser
input cannot choose the upstream origin.

## Contract contributions

Domain missions add only owner-scoped fragments, fixtures, and migrations.
Generated aggregates remain ignored build outputs. Shared/root changes go to
the integration steward.

1. Add a namespaced contribution below the owning contract directory.
2. Add valid and invalid synthetic fixtures under the same owner/version.
3. Update only that owner's manifest.
4. Run `npm run contracts:generate` and `npm run contracts:check`.
5. Route shared-file changes to the integration steward.

P1-P4 are immutable Draft conformance inputs. Their implementation stays blocked
until P0 is merged and each consumer revalidates its baseline.

## Failure routing

| Failing command | Responsible surface |
| --- | --- |
| `npm run contracts:check` | WP03; WP02 for common values |
| `npm run web:check` | WP09 configuration or WP10 shell/proxy |
| `npm run api:check` | WP05/WP08; WP04 build integration |
| `npm run migration:negative` | WP07 |
| `npm run persistence:integration` | WP06; WP04/WP07 at seams |
| `npm run http:smoke` | WP08 Zig boundary or WP10 same-origin proxy |
| `npm run licenses:check` | WP12 policy/report; producing dependency owner |
| clean wrapper failure | WP01 wiring or the first focused failing owner |

Do not convert a required failure to a warning. Report the exact command,
candidate commit, exit status, diagnostic, and owning path.

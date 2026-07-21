# Third-Party Notices

## ShovelerDB

- Component: ShovelerDB embedded database engine
- Public source: https://github.com/LynnColeArt/ShovelerDB.git
- Exact source commit: `20dced69738bfce08f94368b8d017cfc283747fe`
- License: GPL-3.0-only, as evidenced by the preserved upstream license and notice
- Full license text: `deps/shovelerdb/LICENSE`
- Upstream licensing notice: `deps/shovelerdb/NOTICE`
- Source provenance: `deps/shovelerdb/PROVENANCE`

The committed `LICENSE`, `NOTICE`, `build.zig`, `include/**`, and `src/**`
snapshot is an unmodified 43-file engine export of the exact public commit
above and is distributed with this application. The separately GPL-2.0-only
`references/mariadb/**` corpus and the development-only
`tests/fixtures/mariadb-adapted/**` descriptors are outside this engine export
and are not distributed in Invoice Manager. `deps/shovelerdb/PROVENANCE` and
the Invoice Manager build-only shim at
`services/api/src/platform/persistence/shovelerdb_abi_root.zig` are Invoice
Manager packaging metadata/code; they do not modify the exported upstream
source files.

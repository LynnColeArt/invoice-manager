import { createHash } from "node:crypto";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import {
  inventoryStandaloneArtifact,
  platformAllows,
  resolveLockDependency,
  stageRuntimeNotices,
  traverseProductionLock,
  verifyShovelerEvidence,
  type ArtifactManifestPolicy,
  type LicensePolicy,
} from "../src/audit.js";

const temporary: string[] = [];
const target = { os: "linux", cpu: "x64", libc: "glibc" } as const;

afterEach(async () => {
  await Promise.all(
    temporary
      .splice(0)
      .map((entry) => rm(entry, { force: true, recursive: true })),
  );
});

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

describe("npm lock resolution", () => {
  it("implements positive and negative npm platform-list semantics", () => {
    expect(platformAllows({ os: ["!darwin"] }, target)).toBe(true);
    expect(platformAllows({ os: ["!linux"] }, target)).toBe(false);
    expect(platformAllows({ os: ["darwin", "linux"] }, target)).toBe(true);
    expect(platformAllows({ os: ["darwin", "!linux"] }, target)).toBe(false);
    expect(platformAllows({ cpu: ["!arm64"], libc: ["!musl"] }, target)).toBe(
      true,
    );
    expect(platformAllows({ cpu: ["arm64"] }, target)).toBe(false);
  });

  it("uses Node ancestor resolution and prefers a nested locked dependency", () => {
    const packages = {
      "node_modules/a": { version: "1.0.0", dependencies: { b: "2.0.0" } },
      "node_modules/a/node_modules/b": { version: "2.0.0" },
      "node_modules/b": { version: "1.0.0" },
    };
    expect(resolveLockDependency(packages, "node_modules/a", "b")).toBe(
      "node_modules/a/node_modules/b",
    );
  });

  it("hard-fails every unresolved production edge", () => {
    const packages = {
      "apps/web": { dependencies: { a: "1.0.0" } },
      "node_modules/a": {
        version: "1.0.0",
        dependencies: { missing: "1.0.0" },
      },
    };
    expect(() => traverseProductionLock(packages, "apps/web", target)).toThrow(
      "unresolved production edge a@1.0.0 > missing",
    );
  });

  it("does not skip a required package with a negative-only platform list", () => {
    const packages = {
      "apps/web": { dependencies: { helpers: "1.0.0" } },
      "node_modules/helpers": { version: "1.0.0", os: ["!darwin"] },
    };
    expect(traverseProductionLock(packages, "apps/web", target)).toEqual([
      expect.objectContaining({ key: "node_modules/helpers" }),
    ]);
    packages["node_modules/helpers"].os = ["!linux"];
    expect(() => traverseProductionLock(packages, "apps/web", target)).toThrow(
      "required production edge",
    );
  });
});

describe("standalone artifact closure", () => {
  async function fixture(): Promise<{ root: string; policy: LicensePolicy }> {
    const root = await mkdtemp(
      path.join(os.tmpdir(), "invoice-license-artifact-"),
    );
    temporary.push(root);
    const standalone = path.join(root, "apps/web/.next/standalone");
    await mkdir(path.join(standalone, "node_modules/foo"), { recursive: true });
    await mkdir(path.join(root, "node_modules/foo"), { recursive: true });
    await writeFile(path.join(root, "LICENSE"), "project-license\n");
    await writeFile(
      path.join(root, "THIRD_PARTY_NOTICES.md"),
      "project-notices\n",
    );
    await writeFile(
      path.join(root, "node_modules/foo/LICENSE"),
      "foo-license\n",
    );
    const projectManifest = JSON.stringify({
      name: "invoice-manager",
      version: "0.0.0",
      license: "GPL-2.0-only",
    });
    const fooManifest = JSON.stringify({
      name: "foo",
      version: "1.0.0",
      license: "MIT",
    });
    await writeFile(path.join(root, "package.json"), projectManifest);
    await writeFile(
      path.join(root, "node_modules/foo/package.json"),
      fooManifest,
    );
    await writeFile(path.join(standalone, "package.json"), projectManifest);
    await writeFile(path.join(standalone, "server.js"), "server\n");
    await writeFile(
      path.join(standalone, "node_modules/foo/package.json"),
      fooManifest,
    );
    await writeFile(
      path.join(standalone, "node_modules/foo/native.node"),
      "native\n",
    );

    const manifests: Record<string, ArtifactManifestPolicy> = {
      "package.json": {
        identity: "project:invoice-manager",
        version: "0.0.0",
        spdx_expression: "GPL-2.0-only",
        source_manifest_path: "package.json",
        source_manifest_sha256: sha256(projectManifest),
        source_notice_path: "LICENSE",
        source_notice_sha256: sha256("project-license\n"),
        distributed_notice_path: "licenses/project-invoice-manager.LICENSE",
      },
      "node_modules/foo/package.json": {
        identity: "npm:foo",
        version: "1.0.0",
        spdx_expression: "MIT",
        source_manifest_path: "node_modules/foo/package.json",
        source_manifest_sha256: sha256(fooManifest),
        source_notice_path: "node_modules/foo/LICENSE",
        source_notice_sha256: sha256("foo-license\n"),
        distributed_notice_path: "licenses/npm-foo.LICENSE",
      },
    };
    return {
      root,
      policy: {
        schema: "invoice-manager.runtime-license-policy/v2",
        project_license: "GPL-2.0-only",
        target,
        compatible_combined_runtime: ["GPL-2.0-only", "MIT"],
        incompatible_combined_runtime: ["Apache-2.0"],
        license_selections: {},
        artifact_manifests: manifests,
        root_distribution_files: {
          LICENSE: sha256("project-license\n"),
          "THIRD_PARTY_NOTICES.md": sha256("project-notices\n"),
        },
      },
    };
  }

  it("stages notices, maps every byte once, and records native artifacts", async () => {
    const { root, policy } = await fixture();
    await stageRuntimeNotices(root, policy);
    const inventory = await inventoryStandaloneArtifact(root, policy);

    expect(inventory.violations).toEqual([]);
    expect(inventory.manifests.map((entry) => entry.manifest_path)).toEqual([
      "node_modules/foo/package.json",
      "package.json",
    ]);
    expect(inventory.native_artifacts).toEqual([
      "node_modules/foo/native.node",
    ]);
    expect(inventory.unmapped_files).toEqual([]);
    expect(inventory.file_count).toBeGreaterThanOrEqual(8);
    expect(
      await readFile(
        path.join(root, "apps/web/.next/standalone/licenses/npm-foo.LICENSE"),
        "utf8",
      ),
    ).toBe("foo-license\n");

    await writeFile(
      path.join(root, "apps/web/.next/standalone/server.js"),
      "changed-server\n",
    );
    const changed = await inventoryStandaloneArtifact(root, policy);
    expect(changed.tree_digest).not.toBe(inventory.tree_digest);
    expect(
      changed.manifests.find(
        (entry) => entry.identity === "project:invoice-manager",
      )?.artifact_digest,
    ).not.toBe(
      inventory.manifests.find(
        (entry) => entry.identity === "project:invoice-manager",
      )?.artifact_digest,
    );
  });

  it("fails unmatched manifests, stale policy, and missing staged notices", async () => {
    const { root, policy } = await fixture();
    await mkdir(
      path.join(root, "apps/web/.next/standalone/node_modules/unexpected"),
      { recursive: true },
    );
    await writeFile(
      path.join(
        root,
        "apps/web/.next/standalone/node_modules/unexpected/package.json",
      ),
      JSON.stringify({ name: "unexpected", version: "1.0.0", license: "MIT" }),
    );
    const stale = structuredClone(policy);
    stale.artifact_manifests!["node_modules/stale/package.json"] = {
      ...stale.artifact_manifests!["node_modules/foo/package.json"],
      identity: "npm:stale",
    };
    const inventory = await inventoryStandaloneArtifact(root, stale);
    expect(inventory.violations.map((entry) => entry.reason)).toEqual(
      expect.arrayContaining([
        "artifact_manifest_policy_unmatched",
        "artifact_manifest_policy_stale",
        "artifact_notice_missing",
      ]),
    );
  });

  it("fails artifact manifest conflicts and committed source-manifest drift", async () => {
    const { root, policy } = await fixture();
    await stageRuntimeNotices(root, policy);
    const standaloneManifest = path.join(
      root,
      "apps/web/.next/standalone/node_modules/foo/package.json",
    );
    await writeFile(
      standaloneManifest,
      JSON.stringify({ name: "foo", version: "2.0.0", license: "Apache-2.0" }),
    );
    await writeFile(
      path.join(root, "node_modules/foo/package.json"),
      JSON.stringify({ name: "foo", version: "1.0.0", license: "ISC" }),
    );
    const inventory = await inventoryStandaloneArtifact(root, policy);
    expect(inventory.violations.map((entry) => entry.reason)).toEqual(
      expect.arrayContaining([
        "artifact_manifest_source_drift",
        "artifact_manifest_version_mismatch",
        "artifact_manifest_license_conflict",
      ]),
    );
  });

  it("fails a distributed notice whose bytes differ from committed evidence", async () => {
    const { root, policy } = await fixture();
    await stageRuntimeNotices(root, policy);
    await writeFile(
      path.join(root, "apps/web/.next/standalone/licenses/npm-foo.LICENSE"),
      "mutated\n",
    );
    const inventory = await inventoryStandaloneArtifact(root, policy);
    expect(inventory.violations).toContainEqual(
      expect.objectContaining({ reason: "artifact_notice_digest_mismatch" }),
    );
  });

  it("fails source notice digest drift before copying anything", async () => {
    const { root, policy } = await fixture();
    await writeFile(path.join(root, "node_modules/foo/LICENSE"), "mutated\n");
    await expect(stageRuntimeNotices(root, policy)).rejects.toThrow(
      "source notice digest mismatch",
    );
  });
});

describe("ShovelerDB evidence", () => {
  it("checks the exact provenance fields, source-tree digest, license, and notice", async () => {
    const root = await mkdtemp(
      path.join(os.tmpdir(), "invoice-license-shoveler-"),
    );
    temporary.push(root);
    await mkdir(path.join(root, "deps/shovelerdb/include"), {
      recursive: true,
    });
    await mkdir(path.join(root, "deps/shovelerdb/src"), { recursive: true });
    await writeFile(path.join(root, "deps/shovelerdb/LICENSE"), "license\n");
    await writeFile(
      path.join(root, "deps/shovelerdb/include/api.h"),
      "header\n",
    );
    await writeFile(path.join(root, "deps/shovelerdb/src/lib.zig"), "source\n");
    await writeFile(path.join(root, "THIRD_PARTY_NOTICES.md"), "notice\n");
    const lines = [
      `${sha256("license\n")}  LICENSE`,
      `${sha256("header\n")}  include/api.h`,
      `${sha256("source\n")}  src/lib.zig`,
    ];
    const tree = sha256(`${lines.join("\n")}\n`);
    const provenance = path.join(root, "deps/shovelerdb/PROVENANCE");
    const provenanceContents = `component=ShovelerDB\nsource_url=https://example.invalid/db.git\ncommit=${"a".repeat(40)}\nsource_tree_sha256=${tree}\n`;
    await writeFile(provenance, provenanceContents);
    const evidence = {
      commit: "a".repeat(40),
      source: "https://example.invalid/db.git",
      spdx_expression: "GPL-2.0-only",
      license_path: "deps/shovelerdb/LICENSE",
      license_sha256: sha256("license\n"),
      notice_path: "THIRD_PARTY_NOTICES.md",
      notice_sha256: sha256("notice\n"),
      provenance_path: "deps/shovelerdb/PROVENANCE",
      provenance_sha256: sha256(provenanceContents),
      source_tree_sha256: tree,
    };

    await expect(verifyShovelerEvidence(root, evidence)).resolves.toMatchObject(
      {
        verified: true,
        source_tree_sha256: tree,
      },
    );
    await writeFile(provenance, `${provenanceContents}unexpected=value\n`);
    await expect(verifyShovelerEvidence(root, evidence)).resolves.toMatchObject(
      { verified: false },
    );
    await writeFile(provenance, provenanceContents);
    await writeFile(path.join(root, "deps/shovelerdb/src/lib.zig"), "drift\n");
    await expect(verifyShovelerEvidence(root, evidence)).resolves.toMatchObject(
      { verified: false },
    );
  });
});

import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import {
  auditRepository,
  findRepositoryRoot,
  loadPolicy,
  verifyLgplObligation,
} from "../src/audit.js";

const root = findRepositoryRoot();
const temporary: string[] = [];

afterEach(async () => {
  await Promise.all(
    temporary.splice(0).map((directory) =>
      rm(directory, { force: true, recursive: true }),
    ),
  );
});

describe("P0 source distribution closure", () => {
  it("does not treat build outputs as shipped P0 artifacts", async () => {
    const report = await auditRepository(root, await loadPolicy(root));
    const serialized = JSON.stringify(report);
    expect(serialized).not.toContain(".next/standalone");
    expect(serialized).not.toContain("tools/licenses/.runtime/zig");
    expect(serialized).not.toContain("bin/invoice-manager-api");
    expect(serialized).not.toContain("container-image.tar");
    expect((report as unknown as { distribution: { deferred_packaging: string[] } }).distribution.deferred_packaging).toEqual([
      "container-image",
      "next-standalone",
      "zig-installed-binary",
    ]);
  });

  it("records libvips LGPL source and replaceable dynamic-link evidence", async () => {
    const policy = await loadPolicy(root);
    const key = "npm:@img/sharp-libvips-linux-x64@1.3.2";
    expect(policy.lgpl_obligations![key].versions_sha256).toBe(
      "71e22ad5154a3891e09291e2f316b3d9b0d0f405459144a94897a203580df055",
    );
    const result = await verifyLgplObligation(
      root,
      key,
      policy.lgpl_obligations![key],
    );
    expect(result).toMatchObject({
      verified: true,
      selected_license: "LGPL-3.0-or-later",
      source_commit: "3664cfc5dc2c5661288f5bf5a85ccc51c64c1626",
      source_archive_sha256:
        "8cea8ae2cdbac89e5750952e6d8b18061257de59716ff8458c0767c801bfd7a9",
      dynamic_library_sha256:
        "0c1a1560417bbcdac38ce83151e52e56711deb70c5373053822c3301a19a4496",
      linked_version: "8.18.3",
      relinking_mode: "replaceable-dynamic-shared-object",
    });
  });

  it("fails a drifted libvips versions or shared-library digest closed", async () => {
    const policy = await loadPolicy(root);
    const key = "npm:@img/sharp-libvips-linux-x64@1.3.2";
    const obligation = structuredClone(policy.lgpl_obligations![key]);
    obligation.versions_sha256 = "0".repeat(64);
    expect((await verifyLgplObligation(root, key, obligation)).verified).toBe(
      false,
    );
    obligation.versions_sha256 = policy.lgpl_obligations![key].versions_sha256;
    obligation.dynamic_library_sha256 = "0".repeat(64);
    expect((await verifyLgplObligation(root, key, obligation)).verified).toBe(
      false,
    );
  });

  it("rejects a non-regular relinking artifact", async () => {
    const directory = await mkdtemp(path.join(os.tmpdir(), "invoice-lgpl-"));
    temporary.push(directory);
    // This test exercises the public verifier with repository-relative inputs in a synthetic root.
    await mkdir(path.join(directory, "evidence"), { recursive: true });
    await writeFile(path.join(directory, "evidence/LICENSE"), "license\n");
    await writeFile(
      path.join(directory, "evidence/versions.json"),
      '{"vips":"8.17.3"}\n',
    );
    await writeFile(path.join(directory, "evidence/library.so"), "not-elf\n");
    await chmod(path.join(directory, "evidence/library.so"), 0o755);
    const sha = async (name: string) =>
      (await import("node:crypto"))
        .createHash("sha256")
        .update(await readFile(path.join(directory, name)))
        .digest("hex");
    const result = await verifyLgplObligation(directory, "npm:test@1.0.0", {
      selected_license: "LGPL-3.0-or-later",
      license_path: "evidence/LICENSE",
      license_sha256: await sha("evidence/LICENSE"),
      source_url:
        "https://github.com/libvips/libvips/archive/0c9151a4f416d2f8ae20a755db218f6637050eec.tar.gz",
      source_commit: "0c9151a4f416d2f8ae20a755db218f6637050eec",
      source_archive_sha256: "a".repeat(64),
      versions_path: "evidence/versions.json",
      versions_sha256: await sha("evidence/versions.json"),
      linked_version: "8.17.3",
      dynamic_library_path: "evidence/library.so",
      dynamic_library_sha256: await sha("evidence/library.so"),
      relinking_mode: "replaceable-dynamic-shared-object",
    });
    expect(result.verified).toBe(false);
  });
});

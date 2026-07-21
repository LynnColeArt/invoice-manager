import { chmod, mkdir, mkdtemp, rm, symlink, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { readConformanceLock } from "../src/conformance.js";
import { ContractError } from "../src/errors.js";
import { discoverAndValidateMigrations } from "../src/migrations.js";
import { composeModules, discoverModules, type ModuleContribution } from "../src/modules.js";
import { readRepositoryBytes, resolveRepositoryWritePath } from "../src/paths.js";
import { discoverStableIdRegistry, StableIdRegistry } from "../src/registry.js";

const roots: string[] = [];
afterEach(async () => Promise.all(roots.splice(0).map((root) => rm(root, { recursive: true, force: true }))));

async function temporary(prefix: string): Promise<string> {
  const root = await mkdtemp(path.join(os.tmpdir(), prefix));
  roots.push(root);
  return root;
}

async function expectCode(action: () => Promise<unknown>, code: string): Promise<void> {
  await expect(action()).rejects.toMatchObject({ code });
}

function ownerModule(): ModuleContribution {
  return {
    module_version: 1,
    module_id: "synthetic-p7",
    owner_mission: "p7",
    mount_key: "synthetic_p7",
    api_fragments: ["contracts/api/v1/fragments/p7/api.openapi.json"],
    event_catalogs: [],
    migration_root: "services/api/migrations/p7",
    route_policy: { default_access: "protected", public_operations: [] },
  };
}

describe("root-contained paths and strict UTF-8", () => {
  it("rejects a declared directory where a regular fragment file is required", async () => {
    const root = await temporary("invoice-manager-directory-fragment-");
    await mkdir(path.join(root, "contracts/api/v1/fragments/p7/api.openapi.json"), { recursive: true });
    await expect(() => composeModules(root, new StableIdRegistry(), [ownerModule()])).rejects.toMatchObject({
      code: "path_not_file",
      pointer: "/api_fragments/0",
    });
  });

  it("translates unreadable files and discovery directories into stable pointer diagnostics", async () => {
    const root = await temporary("invoice-manager-unreadable-");
    await mkdir(path.join(root, "contracts/blocked"), { recursive: true });
    const file = path.join(root, "contracts/evidence.json");
    await writeFile(file, "{}\n");
    await chmod(file, 0o000);
    try {
      await expect(() => readRepositoryBytes(root, "contracts/evidence.json", "/evidence")).rejects.toMatchObject({
        code: "path_read_failed",
        pointer: "/evidence",
      });
    } finally {
      await chmod(file, 0o600);
    }

    await chmod(path.join(root, "contracts/blocked"), 0o000);
    try {
      await expect(() => discoverStableIdRegistry(root)).rejects.toMatchObject({
        code: "path_directory_read_failed",
        pointer: "/contracts/blocked",
      });
    } finally {
      await chmod(path.join(root, "contracts/blocked"), 0o700);
    }
  });

  it("rejects escaping fragment symlinks and invalid UTF-8 before parsing", async () => {
    const root = await temporary("invoice-manager-paths-");
    const external = await temporary("invoice-manager-external-");
    const fragmentDirectory = path.join(root, "contracts/api/v1/fragments/p7");
    await mkdir(fragmentDirectory, { recursive: true });
    const externalFile = path.join(external, "escaped.json");
    await writeFile(externalFile, '{"openapi":"3.1.0","servers":[{"url":"/api/v1"}],"paths":{}}\n');
    await symlink(externalFile, path.join(fragmentDirectory, "api.openapi.json"));
    await expectCode(() => composeModules(root, new StableIdRegistry(), [ownerModule()]), "path_symlink_escape");

    await rm(path.join(fragmentDirectory, "api.openapi.json"));
    await writeFile(path.join(fragmentDirectory, "api.openapi.json"), Buffer.from([
      ...Buffer.from('{"openapi":"3.1.0","info":{"title":"bad'), 0xff,
      ...Buffer.from('","version":"1"},"servers":[{"url":"/api/v1"}],"paths":{}}\n'),
    ]));
    await expectCode(() => composeModules(root, new StableIdRegistry(), [ownerModule()]), "utf8_invalid");
  });

  it("rejects symlinks and invalid UTF-8 in schema discovery", async () => {
    const root = await temporary("invoice-manager-registry-");
    const external = await temporary("invoice-manager-registry-external-");
    await mkdir(path.join(root, "contracts/synthetic"), { recursive: true });
    const outside = path.join(external, "schema.json");
    await writeFile(outside, '{"$id":"https://invoice-manager.invalid/contracts/outside.schema.json"}\n');
    await symlink(outside, path.join(root, "contracts/synthetic/schema.json"));
    await expectCode(() => discoverStableIdRegistry(root), "path_symlink_escape");
    await rm(path.join(root, "contracts/synthetic/schema.json"));
    await writeFile(path.join(root, "contracts/synthetic/schema.json"), Buffer.concat([
      Buffer.from('{"$id":"https://invoice-manager.invalid/contracts/synthetic.schema.json","description":"'),
      Buffer.from([0xff]), Buffer.from('"}\n'),
    ]));
    await expectCode(() => discoverStableIdRegistry(root), "utf8_invalid");
  });

  it("rejects owner-directory symlinks during module and migration discovery", async () => {
    const moduleRoot = await temporary("invoice-manager-module-symlink-");
    const externalModules = await temporary("invoice-manager-module-external-");
    await mkdir(path.join(moduleRoot, "contracts/modules"), { recursive: true });
    await mkdir(path.join(externalModules, "p7"), { recursive: true });
    await symlink(path.join(externalModules, "p7"), path.join(moduleRoot, "contracts/modules/p7"));
    await expectCode(() => discoverModules(moduleRoot, new StableIdRegistry()), "path_symlink_escape");

    const migrationRoot = await temporary("invoice-manager-migration-symlink-");
    const externalMigrations = await temporary("invoice-manager-migration-external-");
    await mkdir(path.join(migrationRoot, "services/api/migrations"), { recursive: true });
    await mkdir(path.join(externalMigrations, "p7"), { recursive: true });
    await symlink(path.join(externalMigrations, "p7"), path.join(migrationRoot, "services/api/migrations/p7"));
    await expectCode(
      () => discoverAndValidateMigrations(migrationRoot, ["services/api/migrations/p7"], new StableIdRegistry()),
      "path_symlink_escape",
    );
  });

  it("rejects invalid UTF-8 at migration and conformance lock boundaries", async () => {
    const migrationRoot = await temporary("invoice-manager-migration-utf8-");
    const directory = path.join(migrationRoot, "services/api/migrations/p7/one");
    await mkdir(directory, { recursive: true });
    await writeFile(path.join(directory, "manifest.json"), Buffer.from([0x7b, 0xff, 0x7d]));
    await writeFile(path.join(directory, "up.sql"), "SELECT 1;\n");
    await expectCode(() => discoverAndValidateMigrations(migrationRoot, ["services/api/migrations/p7"], new StableIdRegistry()), "utf8_invalid");

    const conformanceRoot = await temporary("invoice-manager-conformance-utf8-");
    await mkdir(path.join(conformanceRoot, "contracts/conformance"), { recursive: true });
    await writeFile(path.join(conformanceRoot, "contracts/conformance/p0-p4-inputs.json"), Buffer.from([0x7b, 0xff, 0x7d]));
    await expectCode(() => readConformanceLock(conformanceRoot), "utf8_invalid");
  });

  it("rejects refresh reads and writes through escaping symlink parents", async () => {
    const root = await temporary("invoice-manager-refresh-");
    const external = await temporary("invoice-manager-refresh-external-");
    await mkdir(path.join(root, "contracts"), { recursive: true });
    await writeFile(path.join(external, "replacements.json"), "[]\n");
    await symlink(external, path.join(root, "contracts/conformance"));
    await expectCode(() => readRepositoryBytes(root, "contracts/conformance/replacements.json", ""), "path_symlink_escape");
    await expectCode(() => resolveRepositoryWritePath(root, "contracts/conformance/change.candidate.json", ""), "path_symlink_escape");
  });
});

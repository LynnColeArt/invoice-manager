import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { afterEach, describe, expect, it } from "vitest";
import { ContractError } from "../src/errors.js";
import { preflightContracts } from "../src/generate.js";
import { sha256Digest, stableJson } from "../src/json.js";
import {
  discoverAndValidateMigrations,
  migrationDescriptorDigest,
  type MigrationDescriptor,
  validateMigrationDescriptor,
} from "../src/migrations.js";
import { StableIdRegistry } from "../src/registry.js";

const repository = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const roots: string[] = [];
afterEach(async () => Promise.all(roots.splice(0).map((root) => rm(root, { recursive: true, force: true }))));

async function registry(): Promise<StableIdRegistry> {
  const result = new StableIdRegistry();
  for (const relative of ["contracts/common/v1/schema.json", "contracts/migrations/v1/manifest.schema.json"]) {
    result.add(JSON.parse(await readFile(path.join(repository, relative), "utf8")), relative);
  }
  return result;
}

async function root(): Promise<string> {
  const value = await mkdtemp(path.join(os.tmpdir(), "invoice-manager-migrations-"));
  roots.push(value);
  return value;
}

async function writeMigration(
  workspace: string,
  owner: string,
  id: string,
  dependencies: string[] = [],
): Promise<{ relative: string; descriptor: MigrationDescriptor; script: Buffer }> {
  const directory = path.join(workspace, `services/api/migrations/${owner}/${id}`);
  await mkdir(directory, { recursive: true });
  const script = Buffer.from(`-- synthetic ${owner} migration\nSELECT 1;\n`);
  await writeFile(path.join(directory, "up.sql"), script);
  const descriptor: MigrationDescriptor = {
    id,
    owner,
    name: `synthetic_${owner}`,
    depends_on: dependencies,
    script_path: "up.sql",
    script_digest: sha256Digest(script),
    descriptor_digest: "",
  };
  descriptor.descriptor_digest = migrationDescriptorDigest(descriptor);
  const relative = `services/api/migrations/${owner}/${id}/manifest.json`;
  await writeFile(path.join(directory, "manifest.json"), stableJson(descriptor));
  return { relative, descriptor, script };
}

async function expectCode(action: () => Promise<unknown>, code: string): Promise<void> {
  try {
    await action();
    throw new Error("Expected ContractError");
  } catch (error) {
    expect(error).toBeInstanceOf(ContractError);
    expect(error).toMatchObject({ code });
  }
}

describe("owner-scoped migration contracts", () => {
  it("verifies independently hashed descriptor JCS and exact script bytes", async () => {
    const workspace = await root();
    const created = await writeMigration(workspace, "p7", "01890f3a-1234-7abc-8def-0123456789ad");
    await expect(validateMigrationDescriptor(workspace, created.relative, created.descriptor, await registry())).resolves.toBeUndefined();
    await expect(discoverAndValidateMigrations(workspace, ["services/api/migrations/p7"], await registry())).resolves.toHaveLength(1);
  });

  it("rejects independent script and descriptor mutations", async () => {
    const workspace = await root();
    const created = await writeMigration(workspace, "p7", "01890f3a-1234-7abc-8def-0123456789ad");
    await writeFile(path.join(workspace, path.dirname(created.relative), "up.sql"), "-- mutated\n");
    await expectCode(async () => validateMigrationDescriptor(workspace, created.relative, created.descriptor, await registry()), "migration_script_digest_mismatch");
    await writeFile(path.join(workspace, path.dirname(created.relative), "up.sql"), created.script);
    const descriptorMutation = { ...created.descriptor, name: "mutated_name" };
    await expectCode(async () => validateMigrationDescriptor(workspace, created.relative, descriptorMutation, await registry()), "migration_descriptor_digest_mismatch");
  });

  it("binds frozen descriptor and script mutations to a real pinned owner's Draft migration root", async () => {
    const realP1 = (await preflightContracts(repository)).conformance.find(({ manifest }) => manifest.owner_mission === "p1")!.manifest;
    expect(realP1.migration_strategy).toEqual({ mode: "owner_scoped_forward_only", root: "services/api/migrations/p1" });
    const workspace = await root();
    const created = await writeMigration(workspace, realP1.owner_mission, "01890f3a-1234-7abc-8def-0123456789af");
    await expect(validateMigrationDescriptor(workspace, created.relative, created.descriptor, await registry())).resolves.toBeUndefined();

    await writeFile(path.join(workspace, path.dirname(created.relative), "up.sql"), "-- real-owner script mutation\n");
    await expectCode(async () => validateMigrationDescriptor(workspace, created.relative, created.descriptor, await registry()), "migration_script_digest_mismatch");
    await writeFile(path.join(workspace, path.dirname(created.relative), "up.sql"), created.script);
    await expectCode(
      async () => validateMigrationDescriptor(workspace, created.relative, { ...created.descriptor, name: "real_owner_descriptor_mutation" }, await registry()),
      "migration_descriptor_digest_mismatch",
    );
  });

  it("rejects duplicate IDs, missing dependencies, cycles, and owner/path mismatch", async () => {
    const duplicateRoot = await root();
    const duplicate = "01890f3a-1234-7abc-8def-0123456789ad";
    await writeMigration(duplicateRoot, "p7", duplicate);
    await writeMigration(duplicateRoot, "p8", duplicate);
    await expectCode(async () => discoverAndValidateMigrations(duplicateRoot, ["services/api/migrations/p7", "services/api/migrations/p8"], await registry()), "migration_id_collision");

    const missingRoot = await root();
    await writeMigration(missingRoot, "p7", duplicate, ["01890f3a-1234-7abc-8def-0123456789ae"]);
    await expectCode(async () => discoverAndValidateMigrations(missingRoot, ["services/api/migrations/p7"], await registry()), "migration_dependency_missing");

    const cycleRoot = await root();
    const first = "01890f3a-1234-7abc-8def-0123456789ad";
    const second = "01890f3a-1234-7abc-8def-0123456789ae";
    await writeMigration(cycleRoot, "p7", first, [second]);
    await writeMigration(cycleRoot, "p7", second, [first]);
    await expectCode(async () => discoverAndValidateMigrations(cycleRoot, ["services/api/migrations/p7"], await registry()), "migration_dependency_cycle");

    const mismatchRoot = await root();
    const created = await writeMigration(mismatchRoot, "p7", first);
    await expectCode(async () => validateMigrationDescriptor(mismatchRoot, created.relative, { ...created.descriptor, owner: "p8" }, await registry()), "migration_owner_path_mismatch");
  });
});

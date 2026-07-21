import { execFile, spawn } from "node:child_process";
import { promisify } from "node:util";
import { fail } from "./errors.js";
import type { VerifiedConformance } from "./conformance.js";
import { parseJsonBytes, sha256Digest, sha256Hex } from "./json.js";
import { validateLifecycleManifest, type ContractInput, type ContractManifest } from "./lifecycle.js";
import { collectReferences, type StableIdRegistry } from "./registry.js";

const execFileAsync = promisify(execFile);

export type PinnedOutputMaterial = {
  path: string;
  schema_id: string;
  byte_sha256: string;
  document: Record<string, unknown>;
  references: string[];
};

export type PinnedFixtureMaterial = {
  path: string;
  expectation: "valid" | "invalid";
  digest: string;
  available: boolean;
  byte_sha256?: string;
};

export type PinnedMigrationMaterial = {
  mode: string;
  root?: string;
  available: boolean;
};

export type PinnedOwnerMaterial = {
  owner_mission: string;
  contract_id: string;
  version: string;
  state: ContractManifest["state"];
  commit: string;
  manifest_path: string;
  manifest_byte_sha256: string;
  content_digest: string;
  manifest: ContractManifest;
  dependencies: string[];
  inputs: ContractInput[];
  outputs: PinnedOutputMaterial[];
  fixtures: PinnedFixtureMaterial[];
  migration: PinnedMigrationMaterial;
};

function gitBatchType(root: string, expression: string): Promise<{ status: number; stdout: string }> {
  return new Promise((resolve, reject) => {
    const child = spawn("git", ["cat-file", "--batch-check=%(objecttype)"], { cwd: root, stdio: ["pipe", "pipe", "ignore"] });
    let stdout = "";
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => { stdout += chunk; });
    child.once("error", reject);
    child.once("close", (code) => resolve({ status: code ?? 1, stdout }));
    child.stdin.end(`${expression}\n`);
  });
}

async function gitType(root: string, commit: string, relative: string, pointer: string): Promise<string | undefined> {
  let result: { status: number; stdout: string };
  try {
    result = await gitBatchType(root, `${commit}:${relative}`);
  } catch {
    fail("conformance_artifact_read_failed", pointer, "Pinned artifact metadata could not be read from the exact commit");
  }
  if (result.status !== 0) fail("conformance_artifact_read_failed", pointer, "Pinned artifact metadata could not be read from the exact commit");
  const response = result.stdout.trim();
  if (response.endsWith(" missing")) return undefined;
  if (!/^(blob|tree|commit|tag)$/u.test(response)) fail("conformance_artifact_read_failed", pointer, "Pinned artifact metadata response was invalid");
  return response;
}

async function gitBlob(root: string, commit: string, relative: string, code: string, pointer: string): Promise<Buffer> {
  const kind = await gitType(root, commit, relative, pointer);
  if (kind === undefined) fail(code, pointer, "Pinned artifact is unavailable at the exact commit");
  if (kind !== "blob") fail("conformance_artifact_not_file", pointer, "Pinned artifact must be a regular Git blob");
  try {
    const { stdout } = await execFileAsync("git", ["show", `${commit}:${relative}`], { cwd: root, encoding: "buffer", maxBuffer: 16 * 1024 * 1024 });
    return Buffer.from(stdout);
  } catch {
    fail("conformance_artifact_read_failed", pointer, "Pinned artifact could not be read from the exact commit");
  }
}

function object(value: unknown, pointer: string): Record<string, unknown> {
  if (value === null || Array.isArray(value) || typeof value !== "object") fail("conformance_output_schema_invalid", pointer, "Pinned output schema must be a JSON object");
  return value as Record<string, unknown>;
}

export async function validatePinnedManifestMaterial(
  root: string,
  verified: VerifiedConformance,
  registry: StableIdRegistry,
  index: number,
): Promise<PinnedOwnerMaterial> {
  const { manifest, pin } = verified;
  await validateLifecycleManifest(root, manifest);
  if (manifest.owner_mission !== pin.owner_mission) fail("conformance_owner_mismatch", `/inputs/${index}/owner_mission`, "Pinned manifest owner differs");
  if (manifest.contract_id !== pin.contract_id) fail("conformance_contract_mismatch", `/inputs/${index}/contract_id`, "Pinned manifest contract ID differs");
  if (manifest.version !== pin.version) fail("conformance_version_mismatch", `/inputs/${index}/version`, "Pinned manifest version differs");

  const strategyPointer = `/inputs/${index}/manifest/migration_strategy`;
  let migration: PinnedMigrationMaterial;
  if (manifest.migration_strategy.mode === "none") {
    if (manifest.migration_strategy.root !== undefined) fail("conformance_migration_strategy_invalid", strategyPointer, "A no-migration strategy must not declare a root");
    migration = { mode: "none", available: false };
  } else if (manifest.migration_strategy.mode === "owner_scoped_forward_only") {
    const expectedRoot = `services/api/migrations/${manifest.owner_mission}`;
    if (manifest.migration_strategy.root !== expectedRoot) fail("conformance_migration_strategy_invalid", strategyPointer, "Pinned migration root does not match its owner convention");
    const kind = await gitType(root, pin.commit, expectedRoot, `${strategyPointer}/root`);
    if (kind !== undefined && kind !== "tree") fail("conformance_migration_root_invalid", `${strategyPointer}/root`, "Pinned migration root must be a Git tree");
    migration = { mode: manifest.migration_strategy.mode, root: expectedRoot, available: kind === "tree" };
  } else {
    fail("conformance_migration_strategy_invalid", strategyPointer, "Pinned migration strategy mode is unsupported");
  }

  const outputs: PinnedOutputMaterial[] = [];
  for (const [outputIndex, output] of manifest.outputs.entries()) {
    const pointer = `/inputs/${index}/outputs/${outputIndex}/path`;
    const bytes = await gitBlob(root, pin.commit, output.path, "conformance_output_unavailable", pointer);
    const document = object(parseJsonBytes(bytes, pointer), pointer);
    const schemaId = document.$id;
    if (typeof schemaId !== "string") fail("schema_id_missing", `${pointer}/$id`, "Pinned output schema has no stable ID");
    const source = `git:${pin.commit}:${output.path}`;
    if (registry.sources.get(source) !== schemaId) fail("conformance_schema_missing", pointer, "Pinned output schema is not registered from its exact source");
    const references = [...collectReferences(document)].sort();
    references.forEach((reference, referenceIndex) => {
      registry.resolve(reference.startsWith("#") ? `${schemaId}${reference}` : reference, `${pointer}/references/${referenceIndex}`);
    });
    outputs.push({ path: output.path, schema_id: schemaId, byte_sha256: sha256Hex(bytes), document, references });
  }

  const fixtures: PinnedFixtureMaterial[] = [];
  for (const [fixtureIndex, fixture] of manifest.integration_fixtures.entries()) {
    const pointer = `/inputs/${index}/integration_fixtures/${fixtureIndex}/path`;
    const kind = await gitType(root, pin.commit, fixture.path, pointer);
    if (kind === undefined) {
      if (manifest.state !== "Draft" || fixture.digest !== "pending") fail("conformance_fixture_unavailable", pointer, "Concrete pinned fixture is unavailable at the exact commit");
      fixtures.push({ path: fixture.path, expectation: fixture.expectation, digest: fixture.digest, available: false });
      continue;
    }
    const bytes = await gitBlob(root, pin.commit, fixture.path, "conformance_fixture_unavailable", pointer);
    if (fixture.digest !== "pending" && sha256Digest(bytes) !== fixture.digest) fail("conformance_fixture_digest_mismatch", `${pointer}/digest`, "Pinned fixture digest differs from exact bytes");
    fixtures.push({ path: fixture.path, expectation: fixture.expectation, digest: fixture.digest, available: true, byte_sha256: sha256Hex(bytes) });
  }

  return {
    owner_mission: manifest.owner_mission,
    contract_id: manifest.contract_id,
    version: manifest.version,
    state: manifest.state,
    commit: pin.commit,
    manifest_path: pin.manifest_path,
    manifest_byte_sha256: sha256Hex(verified.manifestBytes),
    content_digest: pin.content_digest,
    manifest: structuredClone(manifest),
    dependencies: [...manifest.dependencies],
    inputs: structuredClone(manifest.inputs),
    outputs,
    fixtures,
    migration,
  };
}

export async function inspectPinnedConformance(
  root: string,
  conformance: VerifiedConformance[],
  registry: StableIdRegistry,
): Promise<PinnedOwnerMaterial[]> {
  const owners = conformance.map(({ pin }) => pin.owner_mission);
  if (owners.join(",") !== "p1,p2,p3,p4") fail("conformance_owner_set_invalid", "/inputs", "Pinned artifact inspection requires exact P1-P4 owner order");
  const materials: PinnedOwnerMaterial[] = [];
  for (const [index, verified] of conformance.entries()) materials.push(await validatePinnedManifestMaterial(root, verified, registry, index));
  return materials;
}

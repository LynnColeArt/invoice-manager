import { spawn } from "node:child_process";
import { lstat, mkdir, mkdtemp, readFile, readdir, rename, rm, rmdir, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { createClient } from "@hey-api/openapi-ts";
import { Validator } from "@seriousme/openapi-schema-validator";
import ts from "typescript";
import { ContractError, fail } from "./errors.js";
import { validateCanonicalEventFixtures } from "./event-conformance.js";
import {
  buildBaselineRefreshCandidate,
  readConformanceLock,
  verifyConformanceLock,
  type BaselineRefreshCandidate,
  type ConformanceLock,
  type ConformancePin,
  type VerifiedConformance,
} from "./conformance.js";
import { validateCanonicalFixtures } from "./fixtures.js";
import { compareCodeUnits, parseJsonBytes, sha256Hex, stableJson } from "./json.js";
import { readRepositoryBytes } from "./paths.js";
import { type ContractManifest, validateLifecycleManifest } from "./lifecycle.js";
import { discoverAndValidateMigrations } from "./migrations.js";
import { composeModules, type ComposedContracts } from "./modules.js";
import { inspectPinnedConformance, type PinnedOwnerMaterial } from "./pinned-conformance.js";
import { validateCanonicalP0IfPresent } from "./p0-lifecycle.js";
import { assertReferencesResolve, discoverStableIdRegistry, isJsonObject, type StableIdRegistry } from "./registry.js";

export type PreflightResult = {
  registry: StableIdRegistry;
  conformance: VerifiedConformance[];
  composition: ComposedContracts;
  pinnedConformance: PinnedOwnerMaterial[];
};

type TreeSnapshot = Map<string, { bytes: Buffer; mode: number }>;

async function validateOpenApi(openapi: Record<string, unknown>, registry: StableIdRegistry): Promise<void> {
  const validator = new Validator();
  for (const { id, document } of [...registry.documents.values()].sort((a, b) => compareCodeUnits(a.id, b.id))) {
    await validator.addSpecRef(structuredClone(document), id);
  }
  const result = await validator.validate(structuredClone(openapi));
  if (!result.valid) {
    const first = result.errors?.[0];
    if (typeof first === "string") fail("openapi_validation_failed", "", first);
    fail("openapi_validation_failed", first?.instancePath ?? "", first?.message ?? "Composed OpenAPI is invalid");
  }
}

export async function preflightContracts(
  root: string,
  options: { lock?: ConformanceLock; exactBaseline?: boolean } = {},
): Promise<PreflightResult> {
  const registry = await discoverStableIdRegistry(root);
  const lock = options.lock ?? await readConformanceLock(root);
  const conformance = await verifyConformanceLock(root, registry, lock, { exactBaseline: options.exactBaseline });
  assertReferencesResolve(registry);
  const draftValue = parseJsonBytes(await readRepositoryBytes(root, "contracts/manifests/drafts/p0.json", ""));
  registry.validate("https://invoice-manager.invalid/contracts/manifests/v1/schema.json", draftValue);
  await validateLifecycleManifest(root, draftValue as unknown as ContractManifest);
  await validateCanonicalP0IfPresent(root, registry);
  const composition = await composeModules(root, registry);
  const pinnedConformance = await inspectPinnedConformance(root, conformance, registry);
  await discoverAndValidateMigrations(root, composition.modules.map((module) => module.migration_root), registry);
  await validateOpenApi(composition.openapi, registry);
  await validateCanonicalFixtures(root);
  await validateCanonicalEventFixtures(root, registry);
  return { registry, conformance, composition, pinnedConformance };
}

export async function buildValidatedBaselineRefreshCandidate(
  root: string,
  current: ConformanceLock,
  replacements: ConformancePin[],
): Promise<BaselineRefreshCandidate> {
  const pinRegistry = await discoverStableIdRegistry(root);
  const candidate = await buildBaselineRefreshCandidate(root, pinRegistry, current, replacements);
  await preflightContracts(root, {
    lock: { format_version: 1, inputs: candidate.inputs },
    exactBaseline: false,
  });
  return {
    ...candidate,
    validation: "all-pins-composition-references-migrations-lifecycle-events-fixtures-revalidated",
  };
}

function embeddedName(id: string): string {
  const pathPart = new URL(id).pathname.split("/").filter(Boolean).slice(-3).join("_").replaceAll(/[^A-Za-z0-9_]/gu, "_");
  return `InvoiceManager_${pathPart}_${sha256Hex(id).slice(0, 12)}`;
}

function visitReferences(value: unknown, visitor: (reference: string, holder: Record<string, unknown>) => void, seen = new Set<object>()): void {
  if (value === null || typeof value !== "object" || seen.has(value)) return;
  seen.add(value);
  if (Array.isArray(value)) value.forEach((entry) => visitReferences(entry, visitor, seen));
  else {
    const record = value as Record<string, unknown>;
    if (typeof record.$ref === "string") visitor(record.$ref, record);
    Object.values(record).forEach((entry) => visitReferences(entry, visitor, seen));
  }
}

export function buildGeneratorOpenApi(openapi: Record<string, unknown>, registry: StableIdRegistry): Record<string, unknown> {
  const clone = structuredClone(openapi);
  const components = isJsonObject(clone.components as never) ? clone.components as Record<string, unknown> : (clone.components = {} as Record<string, unknown>);
  const schemas = isJsonObject(components.schemas as never) ? components.schemas as Record<string, unknown> : (components.schemas = {} as Record<string, unknown>);
  const embeddedById = new Map<string, string>();
  const definitionByReference = new Map<string, string>();
  const embedding = new Set<string>();

  const embed = (id: string): string => {
    const existing = embeddedById.get(id);
    if (existing) return existing;
    const registered = registry.documents.get(id);
    if (!registered) fail("schema_reference_unknown", "", "Generator reference is not registered locally");
    const name = embeddedName(id);
    if (name in schemas) fail("generator_component_collision", `/components/schemas/${name}`, "Embedded schema component name collides");
    embeddedById.set(id, name);
    embedding.add(id);
    const document = structuredClone(registered.document);
    schemas[name] = document;
    const definitions = document.$defs;
    if (definitions !== null && typeof definitions === "object" && !Array.isArray(definitions)) {
      for (const [definitionName, definition] of Object.entries(definitions).sort(([left], [right]) => compareCodeUnits(left, right))) {
        const componentName = `${name}_${definitionName.replaceAll(/[^A-Za-z0-9_]/gu, "_")}`;
        if (componentName in schemas) fail("generator_component_collision", `/components/schemas/${componentName}`, "Embedded definition component name collides");
        definitionByReference.set(`${id}#/$defs/${definitionName}`, componentName);
        schemas[componentName] = structuredClone(definition);
      }
    }
    rewrite(document, id, name);
    for (const [reference, componentName] of definitionByReference) {
      if (reference.startsWith(`${id}#/$defs/`)) rewrite(schemas[componentName], id, name);
    }
    embedding.delete(id);
    return name;
  };

  const rewrite = (value: unknown, currentId?: string, currentEmbedded?: string): void => {
    visitReferences(value, (reference, holder) => {
      if (reference.startsWith("#")) {
        const directDefinition = currentId ? definitionByReference.get(`${currentId}${reference}`) : undefined;
        if (directDefinition) {
          holder.$ref = `#/components/schemas/${directDefinition}`;
          return;
        }
        if (currentEmbedded) holder.$ref = `#/components/schemas/${currentEmbedded}${reference.slice(1)}`;
        return;
      }
      const hashIndex = reference.indexOf("#");
      const id = hashIndex === -1 ? reference : reference.slice(0, hashIndex);
      if (!id.startsWith("https://invoice-manager.invalid/contracts/")) fail("schema_network_reference", "", "Generator cannot resolve a non-local reference");
      const name = embedding.has(id) ? embeddedById.get(id)! : embed(id);
      const fragment = hashIndex === -1 ? "" : reference.slice(hashIndex + 1);
      const directDefinition = definitionByReference.get(`${id}${fragment ? `#${fragment}` : ""}`);
      holder.$ref = directDefinition ? `#/components/schemas/${directDefinition}` : `#/components/schemas/${name}${fragment}`;
    });
  };

  rewrite(clone);
  visitReferences(clone, (reference) => {
    if (!reference.startsWith("#")) fail("generator_external_reference_remaining", "", "Generator clone contains an external reference");
  });
  return clone;
}

async function snapshotTree(root: string, options: { optionalRoot?: boolean } = {}): Promise<TreeSnapshot> {
  const snapshot: TreeSnapshot = new Map();
  const walk = async (current: string, relative: string, optionalRoot = false): Promise<void> => {
    let entries;
    try {
      entries = await readdir(current, { withFileTypes: true });
    } catch (error) {
      if (optionalRoot && (error as NodeJS.ErrnoException).code === "ENOENT") return;
      fail("generation_snapshot_read_failed", relative ? `/${relative}` : "", "Generated output snapshot could not read a directory");
    }
    for (const entry of entries.sort((a, b) => compareCodeUnits(a.name, b.name))) {
      const childRelative = relative ? `${relative}/${entry.name}` : entry.name;
      const child = path.join(current, entry.name);
      if (entry.isSymbolicLink()) fail("generation_snapshot_entry_invalid", `/${childRelative}`, "Generated output snapshots must not contain symbolic links");
      if (entry.isDirectory()) await walk(child, childRelative);
      else if (entry.isFile()) {
        try {
          const metadata = await stat(child);
          snapshot.set(childRelative, { bytes: await readFile(child), mode: metadata.mode & 0o777 });
        } catch {
          fail("generation_snapshot_read_failed", `/${childRelative}`, "Generated output snapshot could not read a file");
        }
      } else fail("generation_snapshot_entry_invalid", `/${childRelative}`, "Generated output snapshots require regular files and directories");
    }
  };
  await walk(root, "", options.optionalRoot === true);
  return snapshot;
}

function assertSnapshotsEqual(left: TreeSnapshot, right: TreeSnapshot, code: string): void {
  const leftPaths = [...left.keys()].sort(compareCodeUnits);
  const rightPaths = [...right.keys()].sort(compareCodeUnits);
  if (stableJson(leftPaths) !== stableJson(rightPaths)) fail(code, "", "Generated file sets differ between runs");
  for (const relative of leftPaths) {
    const a = left.get(relative)!;
    const b = right.get(relative)!;
    if (a.mode !== b.mode || !a.bytes.equals(b.bytes)) fail(code, "", `Generated output differs at ${relative}`);
  }
}

async function copySnapshot(snapshot: TreeSnapshot, destination: string): Promise<void> {
  await rm(destination, { recursive: true, force: true });
  await mkdir(destination, { recursive: true });
  for (const [relative, entry] of snapshot) {
    const target = path.join(destination, ...relative.split("/"));
    await mkdir(path.dirname(target), { recursive: true });
    await writeFile(target, entry.bytes, { mode: entry.mode });
  }
}

function routeInventory(composition: ComposedContracts): string {
  return stableJson({ format_version: 1, routes: composition.routes });
}

async function runHeyGenerator(input: Record<string, unknown>, outputPath: string): Promise<void> {
  await createClient({
    input,
    output: {
      path: outputPath,
      clean: true,
      entryFile: true,
      header: ["// Generated by invoice-manager contracts:generate.", "// Do not edit."],
      tsConfigPath: null,
    },
    plugins: ["@hey-api/typescript"],
    logs: { level: "silent", file: false },
  });
}

async function typecheckGenerated(directory: string): Promise<void> {
  const files = (await readdir(directory)).filter((entry) => entry.endsWith(".ts")).sort(compareCodeUnits).map((entry) => path.join(directory, entry));
  const program = ts.createProgram(files, {
    target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.ESNext,
    moduleResolution: ts.ModuleResolutionKind.Bundler,
    strict: true,
    noEmit: true,
    skipLibCheck: true,
  });
  const diagnostics = ts.getPreEmitDiagnostics(program);
  if (diagnostics.length) fail("generated_types_invalid", "", ts.flattenDiagnosticMessageText(diagnostics[0].messageText, "\n"));
  const source = (await Promise.all(files.map((file) => readFile(file, "utf8")))).join("\n");
  if (/minor_units[^\n]*number/iu.test(source) || /revision[^\n]*number/iu.test(source)) {
    fail("generated_int64_number", "", "Canonical int64 fields must not generate as TypeScript number");
  }
}

export type PublishFault = "before_backup" | "after_types_backup" | "after_inventory_backup" | "after_types_publish" | "after_inventory_publish";

async function pathExistsStrict(value: string): Promise<boolean> {
  try {
    await lstat(value);
    return true;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return false;
    throw error;
  }
}

export async function publishPair(
  root: string,
  generatedTypes: string,
  inventoryBytes: string,
  fault?: PublishFault,
): Promise<void> {
  const generatedRoot = path.join(root, "tools/contracts/.generated");
  const finalTypes = path.join(generatedRoot, "typescript/v1");
  const finalInventory = path.join(generatedRoot, "runtime/v1/route-inventory.json");
  await mkdir(generatedRoot, { recursive: true });
  const publishRoot = await mkdtemp(path.join(generatedRoot, ".publish-"));
  const stagedTypes = path.join(publishRoot, "typescript");
  const stagedInventory = path.join(publishRoot, "route-inventory.json");
  const backupTypes = path.join(publishRoot, "backup-types");
  const backupInventory = path.join(publishRoot, "backup-inventory.json");
  await rename(generatedTypes, stagedTypes);
  await writeFile(stagedInventory, inventoryBytes, "utf8");
  await mkdir(path.dirname(finalTypes), { recursive: true });
  await mkdir(path.dirname(finalInventory), { recursive: true });
  const priorTypes = await pathExistsStrict(finalTypes);
  const priorInventory = await pathExistsStrict(finalInventory);
  if (priorTypes !== priorInventory) {
    await rm(publishRoot, { recursive: true });
    fail("generated_prior_pair_incomplete", "", "Refusing to publish over a partial generated pair");
  }
  const inject = (point: PublishFault): void => {
    if (fault === point) fail("generation_publish_injected_failure", "", `Injected publish failure at ${point}`);
  };
  let typesBackedUp = false;
  let inventoryBackedUp = false;
  let typesPublished = false;
  let inventoryPublished = false;
  try {
    inject("before_backup");
    if (priorTypes) {
      await rename(finalTypes, backupTypes);
      typesBackedUp = true;
    }
    inject("after_types_backup");
    if (priorInventory) {
      await rename(finalInventory, backupInventory);
      inventoryBackedUp = true;
    }
    inject("after_inventory_backup");
    await rename(stagedTypes, finalTypes);
    typesPublished = true;
    inject("after_types_publish");
    await rename(stagedInventory, finalInventory);
    inventoryPublished = true;
    inject("after_inventory_publish");
    await rm(publishRoot, { recursive: true });
  } catch (error) {
    try {
      if (inventoryPublished) await rm(finalInventory);
      if (typesPublished) await rm(finalTypes, { recursive: true });
      if (inventoryBackedUp) await rename(backupInventory, finalInventory);
      if (typesBackedUp) await rename(backupTypes, finalTypes);
      await rm(publishRoot, { recursive: true });
    } catch (rollbackError) {
      throw new ContractError(
        "generation_publish_rollback_failed",
        "",
        `Publish failed and rollback could not restore the prior pair: ${rollbackError instanceof Error ? rollbackError.message : "unknown rollback error"}`,
      );
    }
    throw error;
  }
}

export async function generateContracts(root: string): Promise<PreflightResult> {
  const preflight = await preflightContracts(root);
  const generatorInput = buildGeneratorOpenApi(preflight.composition.openapi, preflight.registry);
  const stagingParent = path.join(root, "tools/contracts/.generated/.staging");
  await mkdir(stagingParent, { recursive: true });
  const temporaryRoot = await mkdtemp(path.join(stagingParent, "run-"));
  const first = path.join(temporaryRoot, "first");
  const second = path.join(temporaryRoot, "second");
  try {
    await runHeyGenerator(generatorInput, first);
    await runHeyGenerator(generatorInput, second);
    const firstSnapshot = await snapshotTree(first);
    const secondSnapshot = await snapshotTree(second);
    assertSnapshotsEqual(firstSnapshot, secondSnapshot, "generation_nondeterministic");
    await typecheckGenerated(first);
    const inventory = routeInventory(preflight.composition);
    await publishPair(root, first, inventory);
    return preflight;
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
    try {
      await rmdir(stagingParent);
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code !== "ENOENT" && code !== "ENOTEMPTY") throw error;
    }
  }
}

function spawnCaptured(command: string, args: string[], cwd: string): Promise<{ status: number; stdout: string; stderr: string }> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => { stdout += chunk; });
    child.stderr.on("data", (chunk: string) => { stderr += chunk; });
    child.once("error", reject);
    child.once("close", (code) => resolve({ status: code ?? 1, stdout, stderr }));
  });
}

async function snapshotGeneratedPair(root: string): Promise<TreeSnapshot> {
  return snapshotTree(path.join(root, "tools/contracts/.generated"), { optionalRoot: true });
}

async function restoreGeneratedPair(root: string, snapshot: TreeSnapshot): Promise<void> {
  const generatedRoot = path.join(root, "tools/contracts/.generated");
  await rm(generatedRoot, { recursive: true, force: true });
  if (snapshot.size > 0) await copySnapshot(snapshot, generatedRoot);
}

export async function checkContracts(root: string): Promise<PreflightResult> {
  const before = await snapshotGeneratedPair(root);
  try {
    const firstRun = await spawnCaptured("npm", ["run", "contracts:generate"], root);
    if (firstRun.status !== 0) fail("generation_failed", "", firstRun.stderr.trim() || firstRun.stdout.trim() || "First generation failed");
    const first = await snapshotGeneratedPair(root);
    const secondRun = await spawnCaptured("npm", ["run", "contracts:generate"], root);
    if (secondRun.status !== 0) fail("generation_failed", "", secondRun.stderr.trim() || secondRun.stdout.trim() || "Second generation failed");
    const second = await snapshotGeneratedPair(root);
    if (firstRun.stdout !== secondRun.stdout || firstRun.stderr !== secondRun.stderr) fail("generation_diagnostics_nondeterministic", "", "Generation diagnostics differ between runs");
    assertSnapshotsEqual(first, second, "generation_nondeterministic");
    const result = await preflightContracts(root);
    const types = path.join(root, "tools/contracts/.generated/typescript/v1/index.ts");
    const inventory = path.join(root, "tools/contracts/.generated/runtime/v1/route-inventory.json");
    try { await readFile(types); await readFile(inventory); } catch { fail("generated_output_missing", "", "Stable generated outputs are unavailable"); }
    return result;
  } catch (error) {
    await restoreGeneratedPair(root, before);
    throw error;
  }
}

export { assertSnapshotsEqual, snapshotTree };

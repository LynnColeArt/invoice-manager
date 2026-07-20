import { spawn } from "node:child_process";
import { mkdir, mkdtemp, readFile, readdir, rename, rm, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { createClient } from "@hey-api/openapi-ts";
import { Validator } from "@seriousme/openapi-schema-validator";
import ts from "typescript";
import { ContractError, fail } from "./errors.js";
import { readConformanceLock, verifyConformanceLock, type VerifiedConformance } from "./conformance.js";
import { validateCanonicalFixtures } from "./fixtures.js";
import { readJson, compareCodeUnits, sha256Hex, stableJson } from "./json.js";
import { type ContractManifest, validateLifecycleManifest } from "./lifecycle.js";
import { discoverAndValidateMigrations } from "./migrations.js";
import { composeModules, type ComposedContracts } from "./modules.js";
import { assertReferencesResolve, discoverStableIdRegistry, isJsonObject, type StableIdRegistry } from "./registry.js";

export type PreflightResult = {
  registry: StableIdRegistry;
  conformance: VerifiedConformance[];
  composition: ComposedContracts;
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

export async function preflightContracts(root: string): Promise<PreflightResult> {
  const registry = await discoverStableIdRegistry(root);
  const lock = await readConformanceLock(root);
  const conformance = await verifyConformanceLock(root, registry, lock);
  assertReferencesResolve(registry);
  const draftValue = await readJson(path.join(root, "contracts/manifests/drafts/p0.json"));
  registry.validate("https://invoice-manager.invalid/contracts/manifests/v1/schema.json", draftValue);
  await validateLifecycleManifest(root, draftValue as unknown as ContractManifest);
  const composition = await composeModules(root, registry);
  await discoverAndValidateMigrations(root, composition.modules.map((module) => module.migration_root), registry);
  await validateOpenApi(composition.openapi, registry);
  await validateCanonicalFixtures(root);
  return { registry, conformance, composition };
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

async function snapshotTree(root: string): Promise<TreeSnapshot> {
  const snapshot: TreeSnapshot = new Map();
  const walk = async (current: string, relative: string): Promise<void> => {
    let entries;
    try {
      entries = await readdir(current, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries.sort((a, b) => compareCodeUnits(a.name, b.name))) {
      const childRelative = relative ? `${relative}/${entry.name}` : entry.name;
      const child = path.join(current, entry.name);
      if (entry.isDirectory()) await walk(child, childRelative);
      else if (entry.isFile()) {
        const metadata = await stat(child);
        snapshot.set(childRelative, { bytes: await readFile(child), mode: metadata.mode & 0o777 });
      }
    }
  };
  await walk(root, "");
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

async function publishPair(root: string, generatedTypes: string, inventoryBytes: string): Promise<void> {
  const generatedRoot = path.join(root, "tools/contracts/.generated");
  const finalTypes = path.join(generatedRoot, "typescript/v1");
  const finalInventory = path.join(generatedRoot, "runtime/v1/route-inventory.json");
  const token = `${process.pid}-${sha256Hex(inventoryBytes).slice(0, 12)}`;
  const publishRoot = path.join(generatedRoot, `.publish-${token}`);
  const stagedTypes = path.join(publishRoot, "typescript");
  const stagedInventory = path.join(publishRoot, "route-inventory.json");
  const backupTypes = path.join(publishRoot, "backup-types");
  const backupInventory = path.join(publishRoot, "backup-inventory.json");
  await mkdir(publishRoot, { recursive: true });
  await rename(generatedTypes, stagedTypes);
  await writeFile(stagedInventory, inventoryBytes, "utf8");
  await mkdir(path.dirname(finalTypes), { recursive: true });
  await mkdir(path.dirname(finalInventory), { recursive: true });
  let typesBackedUp = false;
  let inventoryBackedUp = false;
  try {
    try { await rename(finalTypes, backupTypes); typesBackedUp = true; } catch {}
    try { await rename(finalInventory, backupInventory); inventoryBackedUp = true; } catch {}
    await rename(stagedTypes, finalTypes);
    await rename(stagedInventory, finalInventory);
    await rm(publishRoot, { recursive: true, force: true });
  } catch (error) {
    await rm(finalTypes, { recursive: true, force: true });
    await rm(finalInventory, { force: true });
    if (typesBackedUp) await rename(backupTypes, finalTypes);
    if (inventoryBackedUp) await rename(backupInventory, finalInventory);
    await rm(publishRoot, { recursive: true, force: true });
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
    try { await rm(stagingParent); } catch {}
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
  return snapshotTree(path.join(root, "tools/contracts/.generated"));
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

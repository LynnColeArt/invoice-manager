import { lstat, readdir, realpath } from "node:fs/promises";
import path from "node:path";
import Ajv2020, { type AnySchema, type ErrorObject, type ValidateFunction } from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import { fail } from "./errors.js";
import { compareCodeUnits, type JsonValue, parseJsonBytes } from "./json.js";
import { normalizeRepositoryPath, readRepositoryBytes, resolveRepositoryFile } from "./paths.js";

export type RegistryDocument = {
  id: string;
  source: string;
  document: Record<string, unknown>;
};

function pointerSegment(value: string): string {
  return value.replaceAll("~1", "/").replaceAll("~0", "~");
}

export class StableIdRegistry {
  readonly documents = new Map<string, RegistryDocument>();
  readonly sources = new Map<string, string>();

  add(document: Record<string, unknown>, source: string): void {
    const id = document.$id;
    if (typeof id !== "string" || id.length === 0) fail("schema_id_missing", "/$id", `Schema at ${source} has no stable $id`);
    if (id.includes("#")) fail("schema_id_fragment_ambiguous", "/$id", "Stable schema IDs must identify a whole document");
    if (!id.startsWith("https://invoice-manager.invalid/contracts/")) fail("schema_id_untrusted", "/$id", "Schema ID is outside the local contract namespace");
    const existing = this.documents.get(id);
    if (existing) fail("schema_id_duplicate", "/$id", `Schema ID is already registered by ${existing.source}`);
    const existingId = this.sources.get(source);
    if (existingId && existingId !== id) fail("schema_path_alias", "/$id", "One source path cannot identify multiple schemas");
    this.documents.set(id, { id, source, document });
    this.sources.set(source, id);
  }

  has(id: string): boolean {
    return this.documents.has(id.split("#", 1)[0]);
  }

  resolve(reference: string): unknown {
    if (reference.startsWith("#")) fail("schema_reference_ambiguous", "", "Fragment-only references require an explicit source document");
    const hashIndex = reference.indexOf("#");
    const id = hashIndex === -1 ? reference : reference.slice(0, hashIndex);
    if (/^https?:/u.test(id) && !id.startsWith("https://invoice-manager.invalid/contracts/")) {
      fail("schema_network_reference", "", "Network schema references are forbidden");
    }
    const registered = this.documents.get(id);
    if (!registered) fail("schema_reference_unknown", "", "Stable schema ID is not registered locally");
    if (hashIndex === -1 || reference.slice(hashIndex) === "#") return registered.document;
    const fragment = reference.slice(hashIndex + 1);
    if (!fragment.startsWith("/")) fail("schema_fragment_invalid", "", "Only JSON Pointer URI fragments are supported");
    let current: unknown = registered.document;
    for (const segment of fragment.slice(1).split("/")) {
      if (current === null || typeof current !== "object" || !(pointerSegment(segment) in current)) {
        fail("schema_fragment_unresolved", "", "Stable schema JSON Pointer does not resolve");
      }
      current = (current as Record<string, unknown>)[pointerSegment(segment)];
    }
    return current;
  }

  createAjv(): Ajv2020 {
    const ajv = new Ajv2020({ allErrors: true, strict: true, validateFormats: true });
    addFormats(ajv);
    for (const { document } of [...this.documents.values()].sort((a, b) => compareCodeUnits(a.id, b.id))) {
      ajv.addSchema(document as AnySchema);
    }
    return ajv;
  }

  validate(schemaId: string, value: unknown): void {
    const ajv = this.createAjv();
    const validate = ajv.getSchema(schemaId);
    if (!validate) fail("schema_reference_unknown", "", "Validation schema is not registered");
    if (!validate(value)) throwAjvError(validate, "schema_validation_failed");
  }
}

function throwAjvError(validate: ValidateFunction, code: string): never {
  const first = (validate.errors ?? [])[0] as ErrorObject | undefined;
  fail(code, first?.instancePath ?? "", first ? `${first.keyword}: ${first.message ?? "invalid value"}` : "Schema validation failed");
}

async function walkFiles(root: string, current: string, output: string[]): Promise<void> {
  for (const entry of await readdir(current, { withFileTypes: true })) {
    const absolute = path.join(current, entry.name);
    if (entry.isSymbolicLink()) fail("path_symlink_escape", "", "Contract discovery must not traverse symbolic links");
    if (entry.isDirectory()) await walkFiles(root, absolute, output);
    else if (entry.isFile() && entry.name.endsWith(".json")) output.push(path.relative(root, absolute).split(path.sep).join("/"));
  }
}

export async function discoverStableIdRegistry(root: string): Promise<StableIdRegistry> {
  const registry = new StableIdRegistry();
  const rootReal = await realpath(root);
  const files: string[] = [];
  const contractsPath = path.join(rootReal, "contracts");
  if ((await lstat(contractsPath)).isSymbolicLink()) fail("path_symlink_escape", "", "Contract discovery root must not be a symbolic link");
  await walkFiles(rootReal, await resolveRepositoryFile(rootReal, "contracts", ""), files);
  for (const relative of files.sort(compareCodeUnits)) {
    const normalized = normalizeRepositoryPath(relative, "");
    const value = parseJsonBytes(await readRepositoryBytes(rootReal, normalized, ""));
    if (value !== null && !Array.isArray(value) && typeof value === "object" && "$id" in value) {
      registry.add(value as Record<string, unknown>, normalized);
    }
  }
  return registry;
}

export function collectReferences(value: unknown, output = new Set<string>(), seen = new Set<object>()): Set<string> {
  if (value === null || typeof value !== "object" || seen.has(value)) return output;
  seen.add(value);
  if (Array.isArray(value)) {
    value.forEach((entry) => collectReferences(entry, output, seen));
  } else {
    for (const [key, entry] of Object.entries(value)) {
      if (key === "$ref" && typeof entry === "string") output.add(entry);
      else collectReferences(entry, output, seen);
    }
  }
  return output;
}

export function assertReferencesResolve(registry: StableIdRegistry): void {
  for (const { id, document } of registry.documents.values()) {
    for (const reference of collectReferences(document)) {
      if (reference.startsWith("#")) {
        registry.resolve(`${id}${reference}`);
      } else if (reference.startsWith("https://invoice-manager.invalid/contracts/")) {
        registry.resolve(reference);
      } else if (/^https?:/u.test(reference)) {
        fail("schema_network_reference", "", "Network schema references are forbidden");
      }
    }
  }
}

export function isJsonObject(value: JsonValue): value is { [key: string]: JsonValue } {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

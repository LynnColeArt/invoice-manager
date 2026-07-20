import { lstat, readdir } from "node:fs/promises";
import path from "node:path";
import { ContractError, fail } from "./errors.js";
import { jcsBytes, parseJsonBytes, sha256Digest } from "./json.js";
import { normalizeRepositoryPath, readRepositoryBytes, resolveRepositoryDirectory } from "./paths.js";
import type { StableIdRegistry } from "./registry.js";

export type MigrationDescriptor = {
  id: string;
  owner: string;
  name: string;
  depends_on: string[];
  script_path: "up.sql";
  script_digest: string;
  descriptor_digest: string;
};

function compareCodeUnits(left: string, right: string): number {
  return left < right ? -1 : left > right ? 1 : 0;
}

export function migrationDescriptorDigest(descriptor: MigrationDescriptor): string {
  return sha256Digest(jcsBytes({
    id: descriptor.id,
    owner: descriptor.owner,
    name: descriptor.name,
    depends_on: [...descriptor.depends_on].sort(compareCodeUnits),
    script_path: descriptor.script_path,
    script_digest: descriptor.script_digest,
  }));
}

export async function validateMigrationDescriptor(
  root: string,
  relativeDescriptorPath: string,
  descriptor: MigrationDescriptor,
  registry: StableIdRegistry,
): Promise<void> {
  registry.validate("https://invoice-manager.invalid/contracts/migrations/v1/manifest.schema.json", descriptor as unknown);
  const normalized = normalizeRepositoryPath(relativeDescriptorPath, "");
  const ownerPrefix = `services/api/migrations/${descriptor.owner}/`;
  if (!normalized.startsWith(ownerPrefix)) fail("migration_owner_path_mismatch", "/owner", "Migration descriptor is outside its owner's root");
  const sortedDependencies = [...descriptor.depends_on].sort(compareCodeUnits);
  if (descriptor.depends_on.some((entry, index) => entry !== sortedDependencies[index])) fail("migration_dependencies_unsorted", "/depends_on", "Migration dependencies must be lexicographically sorted");
  const expectedDescriptor = migrationDescriptorDigest(descriptor);
  if (descriptor.descriptor_digest !== expectedDescriptor) fail("migration_descriptor_digest_mismatch", "/descriptor_digest", "Migration descriptor digest differs");
  const scriptRelative = `${path.posix.dirname(normalized)}/${descriptor.script_path}`;
  let script: Buffer;
  try {
    script = await readRepositoryBytes(root, scriptRelative, "/script_path");
  } catch (error) {
    if (error instanceof ContractError && error.code === "path_missing") {
      fail("migration_script_missing", "/script_path", "Migration script is unavailable");
    }
    throw error;
  }
  if (sha256Digest(script) !== descriptor.script_digest) fail("migration_script_digest_mismatch", "/script_digest", "Migration script digest differs");
}

async function walkDescriptors(root: string, relative: string, output: string[]): Promise<void> {
  const absolute = path.join(root, ...relative.split("/"));
  try {
    const metadata = await lstat(absolute);
    if (metadata.isSymbolicLink()) fail("path_symlink_escape", "", "Migration discovery must not traverse symbolic links");
    await resolveRepositoryDirectory(root, relative, "");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return;
    if (error instanceof ContractError && error.code === "path_missing") return;
    throw error;
  }
  let entries;
  try {
    entries = await readdir(absolute, { withFileTypes: true });
  } catch {
    fail("path_directory_read_failed", `/${relative}`, "Migration discovery directory could not be read");
  }
  for (const entry of entries.sort((a, b) => compareCodeUnits(a.name, b.name))) {
    const child = `${relative}/${entry.name}`;
    if (entry.isSymbolicLink()) fail("path_symlink_escape", "", "Migration discovery must not traverse symbolic links");
    if (entry.isDirectory()) await walkDescriptors(root, child, output);
    else if (entry.isFile() && entry.name === "manifest.json") output.push(child);
  }
}

export async function discoverAndValidateMigrations(root: string, ownerRoots: string[], registry: StableIdRegistry): Promise<MigrationDescriptor[]> {
  const paths: string[] = [];
  for (const ownerRoot of [...ownerRoots].sort(compareCodeUnits)) await walkDescriptors(root, normalizeRepositoryPath(ownerRoot, ""), paths);
  const migrations: Array<{ path: string; descriptor: MigrationDescriptor }> = [];
  for (const relative of paths.sort(compareCodeUnits)) {
    const descriptor = parseJsonBytes(await readRepositoryBytes(root, relative, "")) as unknown as MigrationDescriptor;
    await validateMigrationDescriptor(root, relative, descriptor, registry);
    migrations.push({ path: relative, descriptor });
  }
  const byId = new Map<string, string>();
  for (const { path: relative, descriptor } of migrations) {
    const prior = byId.get(descriptor.id);
    if (prior) fail("migration_id_collision", "/id", `Migration ID collides with ${prior}`);
    byId.set(descriptor.id, relative);
  }
  for (const { descriptor } of migrations) {
    descriptor.depends_on.forEach((dependency, index) => {
      if (!byId.has(dependency)) fail("migration_dependency_missing", `/depends_on/${index}`, "Migration dependency is unavailable");
    });
  }
  const visiting = new Set<string>();
  const visited = new Set<string>();
  const byDescriptorId = new Map(migrations.map(({ descriptor }) => [descriptor.id, descriptor]));
  const visit = (id: string): void => {
    if (visiting.has(id)) fail("migration_dependency_cycle", "/depends_on", "Migration dependency graph contains a cycle");
    if (visited.has(id)) return;
    visiting.add(id);
    byDescriptorId.get(id)?.depends_on.forEach(visit);
    visiting.delete(id);
    visited.add(id);
  };
  [...byDescriptorId.keys()].sort(compareCodeUnits).forEach(visit);
  return migrations.map(({ descriptor }) => descriptor);
}

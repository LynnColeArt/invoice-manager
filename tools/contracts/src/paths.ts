import { lstat, readFile, realpath } from "node:fs/promises";
import path from "node:path";
import { fail } from "./errors.js";
import { decodeUtf8 } from "./json.js";

export function normalizeRepositoryPath(value: string, pointer: string, allowGlob = false): string {
  if (typeof value !== "string" || value.length === 0) fail("path_invalid", pointer, "Path must be a non-empty string");
  if (value.includes("\\")) fail("path_not_slash_separated", pointer, "Path must use forward slashes");
  if (path.posix.isAbsolute(value) || path.win32.isAbsolute(value)) fail("path_absolute", pointer, "Path must be repository-relative");
  if (value.includes("\0")) fail("path_invalid", pointer, "Path must not contain NUL");
  const segments = value.split("/");
  if (segments.some((segment) => segment === "" || segment === ".")) {
    fail("path_not_normalized", pointer, "Path must not contain empty or dot segments");
  }
  if (segments.some((segment) => segment === "..")) fail("path_traversal", pointer, "Path must not traverse outside the repository");
  if (!allowGlob && /[*?{}]/u.test(value)) fail("path_glob_forbidden", pointer, "Concrete paths must not contain glob syntax");
  const normalized = path.posix.normalize(value);
  if (normalized !== value) fail("path_not_normalized", pointer, "Path is not normalized");
  return normalized;
}

export async function resolveRepositoryFile(root: string, value: string, pointer: string): Promise<string> {
  const normalized = normalizeRepositoryPath(value, pointer);
  const rootReal = await realpath(root);
  const candidate = path.resolve(rootReal, ...normalized.split("/"));
  let candidateReal: string;
  try {
    await lstat(candidate);
    candidateReal = await realpath(candidate);
  } catch {
    fail("path_missing", pointer, "Declared repository path does not exist");
  }
  const relative = path.relative(rootReal, candidateReal!);
  if (relative.startsWith("..") || path.isAbsolute(relative)) fail("path_symlink_escape", pointer, "Declared path escapes through a symlink");
  return candidateReal!;
}

export async function readRepositoryBytes(root: string, value: string, pointer: string): Promise<Buffer> {
  return readFile(await resolveRepositoryFile(root, value, pointer));
}

export async function readRepositoryText(root: string, value: string, pointer: string): Promise<string> {
  return decodeUtf8(await readRepositoryBytes(root, value, pointer), pointer);
}

export async function resolveRepositoryWritePath(root: string, value: string, pointer: string): Promise<string> {
  const normalized = normalizeRepositoryPath(value, pointer);
  const rootReal = await realpath(root);
  const segments = normalized.split("/");
  let current = rootReal;
  for (const [index, segment] of segments.slice(0, -1).entries()) {
    current = path.join(current, segment);
    let metadata;
    try {
      metadata = await lstat(current);
    } catch {
      fail("path_parent_missing", pointer, `Write parent segment ${index} does not exist`);
    }
    if (metadata.isSymbolicLink()) fail("path_symlink_escape", pointer, "Write path traverses a symbolic link");
    if (!metadata.isDirectory()) fail("path_parent_invalid", pointer, "Write path parent is not a directory");
    const resolved = await realpath(current);
    const relative = path.relative(rootReal, resolved);
    if (relative.startsWith("..") || path.isAbsolute(relative)) fail("path_symlink_escape", pointer, "Write path escapes the repository");
  }
  const destination = path.join(current, segments.at(-1)!);
  try {
    const metadata = await lstat(destination);
    if (metadata.isSymbolicLink()) fail("path_symlink_escape", pointer, "Write destination is a symbolic link");
    fail("path_destination_exists", pointer, "Write destination already exists");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
  }
  return destination;
}

export function assertUniqueNormalizedPaths(
  values: Array<{ path: string }>,
  pointer: string,
): void {
  const seen = new Map<string, number>();
  values.forEach((entry, index) => {
    const normalized = normalizeRepositoryPath(entry.path, `${pointer}/${index}/path`);
    const previous = seen.get(normalized);
    if (previous !== undefined) {
      fail("path_duplicate", `${pointer}/${index}/path`, `Path duplicates ${pointer}/${previous}/path`);
    }
    seen.set(normalized, index);
  });
}

export function repositoryRoot(from = process.cwd()): string {
  return path.basename(from) === "contracts" && path.basename(path.dirname(from)) === "tools"
    ? path.resolve(from, "../..")
    : from;
}

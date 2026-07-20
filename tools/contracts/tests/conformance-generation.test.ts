import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { afterEach, describe, expect, it } from "vitest";
import { ContractError } from "../src/errors.js";
import {
  assertImmutableCommit,
  readConformanceLock,
  verifyConformanceLock,
} from "../src/conformance.js";
import {
  assertSnapshotsEqual,
  buildGeneratorOpenApi,
  generateContracts,
  preflightContracts,
  snapshotTree,
} from "../src/generate.js";
import { run } from "../src/main.js";
import { discoverStableIdRegistry } from "../src/registry.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const temporaryRoots: string[] = [];
afterEach(async () => Promise.all(temporaryRoots.splice(0).map((directory) => rm(directory, { recursive: true, force: true }))));

function collectRefs(value: unknown, refs: string[] = []): string[] {
  if (value === null || typeof value !== "object") return refs;
  if (Array.isArray(value)) value.forEach((entry) => collectRefs(entry, refs));
  else for (const [key, entry] of Object.entries(value)) key === "$ref" && typeof entry === "string" ? refs.push(entry) : collectRefs(entry, refs);
  return refs;
}

async function isolatedContractRoot(): Promise<string> {
  const isolated = await mkdtemp(path.join(root, ".wp03-contract-test-"));
  temporaryRoots.push(isolated);
  await cp(path.join(root, "contracts"), path.join(isolated, "contracts"), { recursive: true });
  await mkdir(path.join(isolated, "tools/contracts"), { recursive: true });
  await cp(path.join(root, "tools/contracts/.gitignore"), path.join(isolated, "tools/contracts/.gitignore"), { recursive: true });
  return isolated;
}

describe("immutable P1-P4 conformance", () => {
  it("recomputes every exact manifest byte hash and RFC 8785 content digest", async () => {
    const registry = await discoverStableIdRegistry(root);
    const lock = await readConformanceLock(root);
    const verified = await verifyConformanceLock(root, registry, lock);
    expect(verified.map(({ pin }) => [pin.owner_mission, pin.content_digest])).toEqual([
      ["p1", "73457636636187ff5537564a0f13ed29030d931746dbcc2740da3636cb2747f5"],
      ["p2", "c12f5c79c21689f146c705cef5b454bca684e5e86e0ac7a326df8dc7db1f9a70"],
      ["p3", "48d85d152ab9e46efd052c4e3b02dba47a8e6bbfeac8315864cc6d470d274bf3"],
      ["p4", "453c138255cd525587a07049a04576c9d22919979c0c2ac45ce37f46e2e54636"],
    ]);
    expect(verified.every(({ pin }) => execFileSync("git", ["cat-file", "-t", pin.commit], { cwd: root, encoding: "utf8" }).trim() === "commit")).toBe(true);
  });

  it("rejects moving, abbreviated, unavailable, and silently changed pins", async () => {
    for (const reference of ["HEAD", "main", "v1.0.0", "47638a9"]) {
      expect(() => assertImmutableCommit(reference, "/commit")).toThrowError(expect.objectContaining({ code: "conformance_moving_reference" }));
    }
    const registry = await discoverStableIdRegistry(root);
    const lock = await readConformanceLock(root);
    const changed = structuredClone(lock);
    changed.inputs[0].commit = "0".repeat(40);
    await expect(verifyConformanceLock(root, registry, changed)).rejects.toMatchObject({ code: "conformance_baseline_refresh_required", pointer: "/inputs/0" });
    const drifted = structuredClone(lock);
    drifted.inputs[0].manifest_sha256 = "0".repeat(64);
    await expect(verifyConformanceLock(root, registry, drifted)).rejects.toMatchObject({ code: "conformance_baseline_refresh_required" });
  });
});

describe.sequential("deterministic generated contract pair", () => {
  it("creates a network-free generator clone with canonical int64 strings", async () => {
    const preflight = await preflightContracts(root);
    const clone = buildGeneratorOpenApi(preflight.composition.openapi, preflight.registry);
    expect(collectRefs(clone).every((reference) => reference.startsWith("#"))).toBe(true);
    expect(JSON.stringify(clone)).toContain("minor_units");
    expect(preflight.composition.routes).toEqual([{
      path: "/api/v1/health",
      method: "get",
      operation_id: "P0Health",
      owner: "p0",
      mount_key: "foundation",
      access: "public",
    }]);
    expect(Object.keys(preflight.composition.openapi.paths as object)).toEqual(["/health"]);
  });

  it("generates twice byte-identically and preserves the prior pair on a moving pin", async () => {
    const isolated = await isolatedContractRoot();
    await generateContracts(isolated);
    const generatedRoot = path.join(isolated, "tools/contracts/.generated");
    const first = await snapshotTree(generatedRoot);
    await generateContracts(isolated);
    const second = await snapshotTree(generatedRoot);
    expect(() => assertSnapshotsEqual(first, second, "generation_nondeterministic")).not.toThrow();
    const types = await readFile(path.join(generatedRoot, "typescript/v1/types.gen.ts"), "utf8");
    expect(types).toMatch(/Money/u);
    expect(types).toMatch(/minor_units:[^\n]*CanonicalInt64/u);
    expect(types).not.toMatch(/minor_units:[^\n]*number/u);
    const inventory = JSON.parse(await readFile(path.join(generatedRoot, "runtime/v1/route-inventory.json"), "utf8"));
    expect(inventory).toEqual({ format_version: 1, routes: [{ access: "public", method: "get", mount_key: "foundation", operation_id: "P0Health", owner: "p0", path: "/api/v1/health" }] });

    const lockPath = path.join(isolated, "contracts/conformance/p0-p4-inputs.json");
    const lock = JSON.parse(await readFile(lockPath, "utf8"));
    lock.inputs[0].commit = "HEAD";
    await writeFile(lockPath, `${JSON.stringify(lock)}\n`);
    await expect(generateContracts(isolated)).rejects.toBeInstanceOf(ContractError);
    const afterFailure = await snapshotTree(generatedRoot);
    expect(() => assertSnapshotsEqual(second, afterFailure, "generation_mutated_after_failure")).not.toThrow();
  });

  it("keeps generated outputs ignored/untracked and rejects destination overrides", async () => {
    expect(await readFile(path.join(root, "tools/contracts/.gitignore"), "utf8")).toBe(".generated/\n");
    expect(execFileSync("git", ["ls-files", "tools/contracts/.generated"], { cwd: root, encoding: "utf8" })).toBe("");
    expect(await run(["generate", "--output", "elsewhere"])).toBe(3);
  });
});

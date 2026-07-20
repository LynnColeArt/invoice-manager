import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { afterEach, describe, expect, it } from "vitest";
import { ContractError } from "../src/errors.js";
import {
  assertLifecycleTransition,
  computeContentDigest,
  type ContractManifest,
  validateLifecycleManifest,
} from "../src/lifecycle.js";
import { sha256Digest } from "../src/json.js";
import {
  assertImmutableCommit,
  type ConformancePin,
  readConformanceLock,
  verifyConformanceLock,
} from "../src/conformance.js";
import {
  assertSnapshotsEqual,
  buildValidatedBaselineRefreshCandidate,
  buildGeneratorOpenApi,
  generateContracts,
  preflightContracts,
  publishPair,
  snapshotTree,
  type PublishFault,
} from "../src/generate.js";
import { run } from "../src/main.js";
import { composeModules, type EventCatalog } from "../src/modules.js";
import { buildRealOwnerSurface, type RealOwnerSurface } from "../src/real-conformance.js";
import { discoverStableIdRegistry, StableIdRegistry } from "../src/registry.js";

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

  it("builds a truthful refresh candidate only after every live program gate reruns", async () => {
    const lockBytes = await readFile(path.join(root, "contracts/conformance/p0-p4-inputs.json"));
    const lock = await readConformanceLock(root);
    const original = lock.inputs[0];
    const tree = execFileSync("git", ["show", "-s", "--format=%T", original.commit], { cwd: root, encoding: "utf8" }).trim();
    const refreshedCommit = execFileSync("git", ["commit-tree", tree, "-p", original.commit], {
      cwd: root,
      encoding: "utf8",
      input: "WP03 deterministic baseline refresh proof\n",
      env: {
        ...process.env,
        GIT_AUTHOR_NAME: "WP03 Test",
        GIT_AUTHOR_EMAIL: "wp03@example.invalid",
        GIT_COMMITTER_NAME: "WP03 Test",
        GIT_COMMITTER_EMAIL: "wp03@example.invalid",
        GIT_AUTHOR_DATE: "2000-01-01T00:00:00Z",
        GIT_COMMITTER_DATE: "2000-01-01T00:00:00Z",
      },
    }).trim();
    const replacement: ConformancePin = { ...original, commit: refreshedCommit };
    const candidate = await buildValidatedBaselineRefreshCandidate(root, lock, [replacement]);
    expect(candidate.validation).toBe("all-pins-composition-references-migrations-lifecycle-events-fixtures-revalidated");
    expect(candidate.changes).toEqual([{ owner_mission: "p1", old: original, next: replacement }]);
    expect(await readFile(path.join(root, "contracts/conformance/p0-p4-inputs.json"))).toEqual(lockBytes);
  });
});

function apiDocument(surface: RealOwnerSurface, owner: string): Record<string, unknown> {
  return surface.documents.get(`contracts/api/v1/fragments/${owner}/conformance.openapi.json`)!;
}

function operation(surface: RealOwnerSurface, owner: string): Record<string, unknown> {
  const paths = apiDocument(surface, owner).paths as Record<string, unknown>;
  return (Object.values(paths)[0] as Record<string, unknown>).get as Record<string, unknown>;
}

function catalog(surface: RealOwnerSurface, owner: string): EventCatalog {
  return surface.documents.get(`contracts/events/v1/catalogs/${owner}/conformance.json`)! as unknown as EventCatalog;
}

describe("real P1-P4 concurrent mutation matrix", () => {
  it("composes all exact pinned owners together", async () => {
    const preflight = await preflightContracts(root);
    expect(preflight.realOwnerComposition.modules.map((module) => module.owner_mission)).toEqual(["p1", "p2", "p3", "p4"]);
    expect(preflight.realOwnerComposition.routes).toHaveLength(4);
    expect(preflight.realOwnerComposition.catalogs).toHaveLength(4);
  });

  it("rejects each closed collision/ref/access class and cleanly succeeds after every failure", async () => {
    const preflight = await preflightContracts(root);
    const cases: Array<{ code: string; mutate: (surface: RealOwnerSurface) => void }> = [
      {
        code: "route_method_collision",
        mutate: (surface) => {
          const p1Paths = apiDocument(surface, "p1").paths as Record<string, unknown>;
          apiDocument(surface, "p2").paths = structuredClone(p1Paths);
          operation(surface, "p2").operationId = "P2Conformance";
        },
      },
      { code: "route_operation_id_collision", mutate: (surface) => { operation(surface, "p2").operationId = "P1Conformance"; } },
      {
        code: "openapi_component_collision",
        mutate: (surface) => {
          const schemas = (apiDocument(surface, "p2").components as Record<string, unknown>).schemas as Record<string, unknown>;
          schemas.P1PinnedContract = schemas.P2PinnedContract;
          delete schemas.P2PinnedContract;
        },
      },
      { code: "module_mount_duplicate", mutate: (surface) => { surface.modules[1].mount_key = surface.modules[0].mount_key; } },
      {
        code: "event_identity_collision",
        mutate: (surface) => {
          catalog(surface, "p2").source = catalog(surface, "p1").source;
          catalog(surface, "p2").events[0].event_type = catalog(surface, "p1").events[0].event_type;
        },
      },
      { code: "route_public_policy_missing", mutate: (surface) => { operation(surface, "p1")["x-invoice-manager-access"] = "public"; } },
      { code: "event_payload_schema_unresolved", mutate: (surface) => { catalog(surface, "p1").events[0].payload_schema_id = "https://invoice-manager.invalid/contracts/missing.schema.json"; } },
      {
        code: "event_payload_schema_conflict",
        mutate: (surface) => { catalog(surface, "p2").events[0].event_type = catalog(surface, "p1").events[0].event_type; },
      },
    ];
    for (const testCase of cases) {
      const surface = buildRealOwnerSurface(preflight.conformance, preflight.registry);
      testCase.mutate(surface);
      try {
        await composeModules(root, preflight.registry, surface.modules, surface.loader);
        throw new Error("Expected real-owner mutation rejection");
      } catch (error) {
        expect(error).toMatchObject({ code: testCase.code });
        expect((error as ContractError).pointer).not.toBe("");
      }
      const clean = buildRealOwnerSurface(preflight.conformance, preflight.registry);
      await expect(composeModules(root, preflight.registry, clean.modules, clean.loader)).resolves.toMatchObject({ routes: { length: 4 } });
    }

    const realSchema = preflight.registry.documents.get(preflight.registry.sources.get(`git:${preflight.conformance[0].pin.commit}:${preflight.conformance[0].manifest.outputs[0].path}`)!)!.document;
    const schemaRegistry = new StableIdRegistry();
    schemaRegistry.add(structuredClone(realSchema), "real-p1");
    expect(() => schemaRegistry.add(structuredClone(realSchema), "real-p1-duplicate")).toThrowError(expect.objectContaining({ code: "schema_id_duplicate", pointer: "/$id" }));
  });

  it("rejects lifecycle, evidence, path, fixture, dependency, and transition mutations on a real pinned Draft", async () => {
    const preflight = await preflightContracts(root);
    const verified = preflight.conformance.find(({ manifest }) => manifest.owner_mission === "p1")!;
    const clean = structuredClone(verified.manifest);
    const workspace = await mkdtemp(path.join(os.tmpdir(), "invoice-manager-real-lifecycle-"));
    temporaryRoots.push(workspace);

    const concrete = structuredClone(clean);
    for (const output of concrete.outputs) {
      const bytes = execFileSync("git", ["show", `${verified.pin.commit}:${output.path}`], { cwd: root });
      await mkdir(path.join(workspace, path.dirname(output.path)), { recursive: true });
      await writeFile(path.join(workspace, output.path), bytes);
      output.digest = sha256Digest(bytes);
    }
    for (const fixture of concrete.integration_fixtures) {
      const bytes = Buffer.from(`{"fixture":"${fixture.expectation}"}\n`);
      await mkdir(path.join(workspace, path.dirname(fixture.path)), { recursive: true });
      await writeFile(path.join(workspace, fixture.path), bytes);
      fixture.digest = sha256Digest(bytes);
    }
    concrete.content_digest = computeContentDigest(concrete);
    await expect(validateLifecycleManifest(workspace, concrete)).resolves.toBeUndefined();

    const cases: Array<{ code: string; pointer: string; mutate: (manifest: ContractManifest) => void }> = [
      { code: "lifecycle_pending_evidence", pointer: "/content_digest", mutate: (manifest) => { manifest.state = "Frozen"; } },
      { code: "content_digest_mismatch", pointer: "/content_digest", mutate: (manifest) => { manifest.content_digest = `sha256:${"0".repeat(64)}`; } },
      {
        code: "path_missing",
        pointer: "/outputs/0/path",
        mutate: (manifest) => {
          manifest.outputs[0].path = `${manifest.outputs[0].path}.missing`;
          manifest.content_digest = computeContentDigest(manifest);
        },
      },
      {
        code: "path_missing",
        pointer: "/integration_fixtures/0/path",
        mutate: (manifest) => {
          manifest.integration_fixtures[0].path = `${manifest.integration_fixtures[0].path}.missing`;
          manifest.content_digest = computeContentDigest(manifest);
        },
      },
      { code: "path_traversal", pointer: "/outputs/0/path", mutate: (manifest) => { manifest.outputs[0].path = "../escape.json"; } },
      { code: "dependency_input_missing", pointer: "/dependencies/0", mutate: (manifest) => { manifest.inputs = []; } },
    ];
    for (const testCase of cases) {
      const source = testCase.code === "lifecycle_pending_evidence" ? structuredClone(clean) : structuredClone(concrete);
      testCase.mutate(source);
      await expect(validateLifecycleManifest(workspace, source)).rejects.toMatchObject({ code: testCase.code, pointer: testCase.pointer });
      await expect(validateLifecycleManifest(root, clean)).resolves.toBeUndefined();
    }

    expect(() => assertLifecycleTransition(clean.state, "Implemented")).toThrowError(expect.objectContaining({
      code: "lifecycle_transition_forbidden",
      pointer: "/state",
    }));
    await expect(validateLifecycleManifest(root, clean)).resolves.toBeUndefined();

    await writeFile(path.join(workspace, concrete.outputs[0].path), "mutated real pinned output bytes\n");
    await expect(validateLifecycleManifest(workspace, concrete)).rejects.toMatchObject({ code: "file_digest_mismatch", pointer: "/outputs/0/digest" });
    await expect(validateLifecycleManifest(root, clean)).resolves.toBeUndefined();
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

  it("runs full envelope, discriminator, payload, and JSONL validation in live preflight", async () => {
    const isolated = await isolatedContractRoot();
    const batchPath = path.join(isolated, "contracts/events/v1/fixtures/runtime-events.jsonl");
    const event = JSON.parse((await readFile(batchPath, "utf8")).trim());
    event.data.status = "not-ready";
    await writeFile(batchPath, `${JSON.stringify(event)}\n`);
    await expect(preflightContracts(isolated)).rejects.toMatchObject({ code: "event_payload_invalid", pointer: "/data/status", line: 1 });
    await writeFile(batchPath, Buffer.from([0xff, 0x0a]));
    await expect(preflightContracts(isolated)).rejects.toMatchObject({ code: "event_jsonl_utf8_invalid", pointer: "" });
  });

  it("restores both prior outputs byte-for-byte for failures throughout paired publication", async () => {
    const isolated = await isolatedContractRoot();
    await generateContracts(isolated);
    const generatedRoot = path.join(isolated, "tools/contracts/.generated");
    const finalTypes = path.join(generatedRoot, "typescript/v1");
    const finalInventory = path.join(generatedRoot, "runtime/v1/route-inventory.json");
    const priorTypes = await snapshotTree(finalTypes);
    const priorInventory = await readFile(finalInventory);
    const faults: PublishFault[] = [
      "before_backup",
      "after_types_backup",
      "after_inventory_backup",
      "after_types_publish",
      "after_inventory_publish",
    ];
    for (const [index, fault] of faults.entries()) {
      const nextTypes = path.join(generatedRoot, `fault-source-${index}`);
      await mkdir(nextTypes, { recursive: true });
      await writeFile(path.join(nextTypes, "index.ts"), `// replacement ${index}\n`);
      await expect(publishPair(isolated, nextTypes, `{"replacement":${index}}\n`, fault)).rejects.toMatchObject({
        code: "generation_publish_injected_failure",
      });
      const afterTypes = await snapshotTree(finalTypes);
      expect(() => assertSnapshotsEqual(priorTypes, afterTypes, "publish_rollback_types_drift")).not.toThrow();
      expect(await readFile(finalInventory)).toEqual(priorInventory);
    }
  });

  it("keeps generated outputs ignored/untracked and rejects destination overrides", async () => {
    expect(await readFile(path.join(root, "tools/contracts/.gitignore"), "utf8")).toBe(".generated/\n");
    expect(execFileSync("git", ["ls-files", "tools/contracts/.generated"], { cwd: root, encoding: "utf8" })).toBe("");
    expect(await run(["generate", "--output", "elsewhere"])).toBe(3);
  });
});

import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { afterEach, describe, expect, it } from "vitest";
import { ContractError } from "../src/errors.js";
import { stableJson } from "../src/json.js";
import {
  composeModules,
  discoverModules,
  effectiveOperationAccess,
  type ModuleContribution,
  validateModuleSet,
} from "../src/modules.js";
import { StableIdRegistry } from "../src/registry.js";

const roots: string[] = [];
const repository = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
afterEach(async () => Promise.all(roots.splice(0).map((root) => rm(root, { recursive: true, force: true }))));

function moduleFor(owner: string, options: Partial<ModuleContribution> = {}): ModuleContribution {
  return {
    module_version: 1,
    module_id: `module-${owner}`,
    owner_mission: owner,
    mount_key: `mount_${owner}`,
    api_fragments: [`contracts/api/v1/fragments/${owner}/api.openapi.json`],
    event_catalogs: [],
    migration_root: `services/api/migrations/${owner}`,
    route_policy: { default_access: "protected", public_operations: [] },
    ...options,
  };
}

function api(operationId: string, route: string, access: unknown = "protected", component = ""): Record<string, unknown> {
  return {
    openapi: "3.1.0",
    info: { title: "Synthetic owner", version: "1.0.0" },
    servers: [{ url: "/api/v1" }],
    paths: {
      [route]: {
        get: {
          operationId,
          ...(access === undefined ? {} : { "x-invoice-manager-access": access }),
          responses: { "200": { description: "Synthetic response" } },
        },
      },
    },
    components: component ? { schemas: { [component]: { type: "string" } } } : {},
  };
}

async function rootWithFragments(entries: Array<[string, Record<string, unknown>]>): Promise<string> {
  const root = await mkdtemp(path.join(os.tmpdir(), "invoice-manager-modules-"));
  roots.push(root);
  for (const [owner, document] of entries) {
    const directory = path.join(root, `contracts/api/v1/fragments/${owner}`);
    await mkdir(directory, { recursive: true });
    await writeFile(path.join(directory, "api.openapi.json"), stableJson(document));
  }
  return root;
}

async function expectCode(action: () => Promise<unknown> | unknown, code: string): Promise<void> {
  try {
    await action();
    throw new Error("Expected ContractError");
  } catch (error) {
    expect(error).toBeInstanceOf(ContractError);
    expect(error).toMatchObject({ code });
  }
}

describe("convention module composition", () => {
  it("discovers additive owners in deterministic semantic order", async () => {
    const root = await rootWithFragments([
      ["p7", api("SyntheticAlpha", "/alpha")],
      ["p8", api("SyntheticBeta", "/beta")],
    ]);
    const p7 = moduleFor("p7");
    const p8 = moduleFor("p8");
    const first = await composeModules(root, new StableIdRegistry(), [p8, p7]);
    const second = await composeModules(root, new StableIdRegistry(), [p7, p8]);
    expect(stableJson(first)).toBe(stableJson(second));
    expect(first.routes.map((route) => route.path)).toEqual(["/api/v1/alpha", "/api/v1/beta"]);
    expect(Object.keys(first.openapi.paths as object)).toEqual(["/alpha", "/beta"]);
    expect(first.routes.every((route) => route.access === "protected")).toBe(true);
  });

  it("treats absent/invalid metadata as protected while reporting quality errors", async () => {
    expect(effectiveOperationAccess(undefined)).toEqual({ access: "protected", valid: false });
    expect(effectiveOperationAccess("publik")).toEqual({ access: "protected", valid: false });
    const document = api("SyntheticAlpha", "/alpha");
    delete (((document.paths as Record<string, unknown>)["/alpha"] as Record<string, unknown>).get as Record<string, unknown>)["x-invoice-manager-access"];
    const root = await rootWithFragments([["p7", document]]);
    await expectCode(() => composeModules(root, new StableIdRegistry(), [moduleFor("p7")]), "route_access_metadata_missing");
  });

  it("discovers module manifests solely by the owner directory convention", async () => {
    const root = await rootWithFragments([
      ["p7", api("SyntheticAlpha", "/alpha")],
      ["p8", api("SyntheticBeta", "/beta")],
    ]);
    for (const owner of ["p8", "p7"]) {
      const directory = path.join(root, `contracts/modules/${owner}`);
      await mkdir(directory, { recursive: true });
      await writeFile(path.join(directory, "module.json"), stableJson(moduleFor(owner)));
    }
    const schema = JSON.parse(await readFile(path.join(repository, "contracts/modules/v1/schema.json"), "utf8"));
    const registry = new StableIdRegistry();
    registry.add(schema, "contracts/modules/v1/schema.json");
    const discovered = await discoverModules(root, registry);
    expect(discovered.map((module) => module.owner_mission)).toEqual(["p7", "p8"]);
  });

  it("requires matching public declarations on both surfaces", async () => {
    const root = await rootWithFragments([["p7", api("SyntheticAlpha", "/alpha", "public")]]);
    await expectCode(() => composeModules(root, new StableIdRegistry(), [moduleFor("p7")]), "route_public_policy_missing");
    const protectedRoot = await rootWithFragments([["p8", api("SyntheticBeta", "/beta", "protected")]]);
    const p8 = moduleFor("p8", { route_policy: { default_access: "protected", public_operations: ["SyntheticBeta"] } });
    await expectCode(() => composeModules(protectedRoot, new StableIdRegistry(), [p8]), "route_public_metadata_missing");
  });

  it("rejects every API collision before returning an aggregate", async () => {
    const pathRoot = await rootWithFragments([
      ["p7", api("SyntheticAlpha", "/shared")],
      ["p8", api("SyntheticBeta", "/shared")],
    ]);
    await expectCode(() => composeModules(pathRoot, new StableIdRegistry(), [moduleFor("p7"), moduleFor("p8")]), "route_method_collision");

    const operationRoot = await rootWithFragments([
      ["p7", api("SameOperation", "/alpha")],
      ["p8", api("SameOperation", "/beta")],
    ]);
    await expectCode(() => composeModules(operationRoot, new StableIdRegistry(), [moduleFor("p7"), moduleFor("p8")]), "route_operation_id_collision");

    const componentRoot = await rootWithFragments([
      ["p7", api("SyntheticAlpha", "/alpha", "protected", "Collision")],
      ["p8", api("SyntheticBeta", "/beta", "protected", "Collision")],
    ]);
    await expectCode(() => composeModules(componentRoot, new StableIdRegistry(), [moduleFor("p7"), moduleFor("p8")]), "openapi_component_collision");
  });

  it("rejects mount and owner-convention collisions", () => {
    const duplicate = [moduleFor("p7", { mount_key: "same" }), moduleFor("p8", { mount_key: "same" })];
    expect(() => validateModuleSet(duplicate)).toThrowError(expect.objectContaining({ code: "module_mount_duplicate" }));
    const escaped = moduleFor("p7", { api_fragments: ["contracts/api/v1/fragments/p8/wrong.openapi.json"] });
    expect(() => validateModuleSet([escaped])).toThrowError(expect.objectContaining({ code: "module_owner_path_mismatch" }));
  });
});

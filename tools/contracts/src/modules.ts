import { readdir } from "node:fs/promises";
import path from "node:path";
import { parseDocument } from "yaml";
import { fail } from "./errors.js";
import { compareCodeUnits, type JsonValue, parseJson } from "./json.js";
import { normalizeRepositoryPath, readRepositoryText, resolveRepositoryFile } from "./paths.js";
import { type StableIdRegistry, isJsonObject } from "./registry.js";

export type Access = "public" | "protected";
export type ModuleContribution = {
  module_version: number;
  module_id: string;
  owner_mission: string;
  mount_key: string;
  api_fragments: string[];
  event_catalogs: string[];
  migration_root: string;
  route_policy: { default_access: "protected"; public_operations: string[] };
};
export type EventCatalogEntry = {
  event_type: string;
  event_version: number;
  aggregate_type: string;
  payload_schema_id: string;
};
export type EventCatalog = {
  catalog_version: number;
  owner_mission: string;
  source: string;
  events: EventCatalogEntry[];
};
export type RouteInventoryEntry = {
  path: string;
  method: string;
  operation_id: string;
  owner: string;
  mount_key: string;
  access: Access;
};
export type ComposedContracts = {
  openapi: Record<string, unknown>;
  modules: ModuleContribution[];
  catalogs: EventCatalog[];
  routes: RouteInventoryEntry[];
};

export const canonicalMethods = ["get", "put", "post", "delete", "options", "head", "patch", "trace"] as const;
const methodIndex = new Map<string, number>(canonicalMethods.map((method, index) => [method, index]));

function objectValue(value: unknown, code: string, pointer: string): Record<string, unknown> {
  if (value === null || Array.isArray(value) || typeof value !== "object") fail(code, pointer, "Expected an object");
  return value as Record<string, unknown>;
}

function parseYamlDocument(text: string, pointer: string): Record<string, unknown> {
  const document = parseDocument(text, { prettyErrors: false, uniqueKeys: true });
  if (document.errors.length || document.warnings.length) fail("openapi_yaml_invalid", pointer, "OpenAPI YAML must be one warning-free document");
  return objectValue(document.toJS(), "openapi_document_invalid", pointer);
}

async function readStructuredFile(root: string, relative: string): Promise<Record<string, unknown>> {
  const text = await readRepositoryText(root, relative, "");
  if (relative.endsWith(".json")) return objectValue(parseJson(text), "json_object_required", "");
  return parseYamlDocument(text, "");
}

function validateOwnerPath(owner: string, kind: "api" | "catalog" | "migration", value: string, pointer: string): string {
  const normalized = normalizeRepositoryPath(value, pointer);
  const expected = kind === "api"
    ? `contracts/api/v1/fragments/${owner}/`
    : kind === "catalog"
      ? `contracts/events/v1/catalogs/${owner}/`
      : `services/api/migrations/${owner}`;
  if (owner === "p0" && kind === "api" && normalized === "contracts/api/v1/base.openapi.yaml") return normalized;
  if (kind === "migration" ? normalized !== expected && !normalized.startsWith(`${expected}/`) : !normalized.startsWith(expected)) {
    fail("module_owner_path_mismatch", pointer, `Declared ${kind} path is outside ${owner}'s contribution convention`);
  }
  return normalized;
}

export function effectiveOperationAccess(metadata: unknown): { access: Access; valid: boolean } {
  if (metadata === "public") return { access: "public", valid: true };
  if (metadata === "protected") return { access: "protected", valid: true };
  return { access: "protected", valid: false };
}

export function validateModuleSet(modules: ModuleContribution[]): void {
  const mounts = new Map<string, number>();
  const moduleIds = new Map<string, number>();
  modules.forEach((module, index) => {
    if (module.module_version !== 1) fail("module_version_invalid", `/modules/${index}/module_version`, "Module version must be 1");
    if (!/^p[0-8]$/u.test(module.owner_mission)) fail("module_owner_invalid", `/modules/${index}/owner_mission`, "Module owner is invalid");
    if (mounts.has(module.mount_key)) fail("module_mount_duplicate", `/modules/${index}/mount_key`, "Module mount key collides with another owner");
    mounts.set(module.mount_key, index);
    if (moduleIds.has(module.module_id)) fail("module_id_duplicate", `/modules/${index}/module_id`, "Module ID collides with another owner");
    moduleIds.set(module.module_id, index);
    module.api_fragments.forEach((entry, entryIndex) => validateOwnerPath(module.owner_mission, "api", entry, `/modules/${index}/api_fragments/${entryIndex}`));
    module.event_catalogs.forEach((entry, entryIndex) => validateOwnerPath(module.owner_mission, "catalog", entry, `/modules/${index}/event_catalogs/${entryIndex}`));
    validateOwnerPath(module.owner_mission, "migration", module.migration_root, `/modules/${index}/migration_root`);
    if (module.route_policy.default_access !== "protected") fail("route_default_access_invalid", `/modules/${index}/route_policy/default_access`, "Default route access must be protected");
    const publicIds = new Set<string>();
    module.route_policy.public_operations.forEach((entry, entryIndex) => {
      if (publicIds.has(entry)) fail("route_public_operation_duplicate", `/modules/${index}/route_policy/public_operations/${entryIndex}`, "Public operation ID is duplicated");
      publicIds.add(entry);
    });
  });
}

export async function discoverModules(root: string, registry: StableIdRegistry): Promise<ModuleContribution[]> {
  const directory = path.join(root, "contracts/modules");
  const modules: ModuleContribution[] = [];
  for (const entry of (await readdir(directory, { withFileTypes: true })).sort((a, b) => compareCodeUnits(a.name, b.name))) {
    if (entry.isSymbolicLink() && /^p[0-8]$/u.test(entry.name)) {
      fail("path_symlink_escape", "", "Module discovery must not traverse symbolic links");
    }
    if (!entry.isDirectory() || !/^p[0-8]$/u.test(entry.name)) continue;
    const relative = `contracts/modules/${entry.name}/module.json`;
    await resolveRepositoryFile(root, relative, "");
    const value = parseJson(await readRepositoryText(root, relative, ""));
    registry.validate("https://invoice-manager.invalid/contracts/modules/v1/schema.json", value);
    const module = value as unknown as ModuleContribution;
    if (module.owner_mission !== entry.name) fail("module_owner_convention_mismatch", "/owner_mission", "Module directory and declared owner differ");
    modules.push(module);
  }
  modules.sort((left, right) => compareCodeUnits(`${left.owner_mission}\0${left.module_id}`, `${right.owner_mission}\0${right.module_id}`));
  validateModuleSet(modules);
  return modules;
}

function normalizedRoutePath(serverBase: string, routePath: string, pointer: string): string {
  if (!routePath.startsWith("/")) fail("route_path_invalid", pointer, "OpenAPI route path must begin with /");
  if (routePath.includes("//") || routePath.split("/").some((segment) => segment === "." || segment === "..")) {
    fail("route_path_not_normalized", pointer, "OpenAPI route path is not normalized");
  }
  const base = serverBase === "/" ? "" : serverBase.replace(/\/$/u, "");
  return `${base}${routePath}` || "/";
}

function sortedRecord(record: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(record).sort(([left], [right]) => compareCodeUnits(left, right)));
}

export type StructuredContractLoader = (relative: string) => Promise<Record<string, unknown>>;

export async function composeModules(
  root: string,
  registry: StableIdRegistry,
  suppliedModules?: ModuleContribution[],
  suppliedLoader?: StructuredContractLoader,
): Promise<ComposedContracts> {
  const modules = suppliedModules ? [...suppliedModules] : await discoverModules(root, registry);
  validateModuleSet(modules);
  modules.sort((left, right) => compareCodeUnits(`${left.owner_mission}\0${left.module_id}`, `${right.owner_mission}\0${right.module_id}`));
  const paths: Record<string, Record<string, unknown>> = {};
  const componentGroups: Record<string, Record<string, unknown>> = {};
  const routes: RouteInventoryEntry[] = [];
  const catalogs: EventCatalog[] = [];
  const routeOwners = new Map<string, string>();
  const operationOwners = new Map<string, string>();
  const componentOwners = new Map<string, string>();
  const eventIdentities = new Map<string, string>();
  const eventTypeVersions = new Map<string, string>();
  const load = suppliedLoader ?? ((relative: string) => readStructuredFile(root, relative));

  for (const module of modules) {
    const declaredPublic = new Set(module.route_policy.public_operations);
    const resolvedPublic = new Set<string>();
    for (const [fragmentIndex, fragmentPath] of module.api_fragments.entries()) {
      const normalized = validateOwnerPath(module.owner_mission, "api", fragmentPath, `/api_fragments/${fragmentIndex}`);
      const fragment = await load(normalized);
      if (fragment.openapi !== "3.1.0") fail("openapi_version_invalid", "/openapi", "OpenAPI fragments must use 3.1.0");
      const servers = Array.isArray(fragment.servers) ? fragment.servers : [];
      const firstServer = servers[0];
      const serverBase = isJsonObject(firstServer as JsonValue) && typeof firstServer.url === "string" ? firstServer.url : "/api/v1";
      const fragmentPaths = objectValue(fragment.paths ?? {}, "openapi_paths_invalid", "/paths");
      for (const [routePath, pathItemValue] of Object.entries(fragmentPaths).sort(([a], [b]) => compareCodeUnits(a, b))) {
        const pathItem = objectValue(pathItemValue, "openapi_path_item_invalid", `/paths/${routePath}`);
        const composedPath = normalizedRoutePath(serverBase, routePath, `/paths/${routePath}`);
        if (serverBase !== "/api/v1") fail("openapi_server_base_invalid", "/servers/0/url", "Every owner fragment must use the /api/v1 server base");
        paths[routePath] ??= {};
        for (const method of canonicalMethods) {
          const operationValue = pathItem[method];
          if (operationValue === undefined) continue;
          const operation = objectValue(operationValue, "openapi_operation_invalid", `/paths/${routePath}/${method}`);
          const routeIdentity = `${composedPath}\0${method}`;
          const priorRoute = routeOwners.get(routeIdentity);
          if (priorRoute) fail("route_method_collision", `/paths/${routePath}/${method}`, `Route collides with owner ${priorRoute}`);
          const operationId = operation.operationId;
          if (typeof operationId !== "string" || operationId.length === 0) fail("route_operation_id_missing", `/paths/${routePath}/${method}/operationId`, "Every operation needs an operationId");
          const priorOperation = operationOwners.get(operationId);
          if (priorOperation) fail("route_operation_id_collision", `/paths/${routePath}/${method}/operationId`, `Operation ID collides with owner ${priorOperation}`);
          const access = effectiveOperationAccess(operation["x-invoice-manager-access"]);
          if (!access.valid) {
            const code = operation["x-invoice-manager-access"] === undefined ? "route_access_metadata_missing" : "route_access_metadata_invalid";
            fail(code, `/paths/${routePath}/${method}/x-invoice-manager-access`, "Every operation must explicitly declare public or protected access");
          }
          const listedPublic = declaredPublic.has(operationId);
          if (access.access === "public" && !listedPublic) fail("route_public_policy_missing", `/paths/${routePath}/${method}/x-invoice-manager-access`, "Public OpenAPI operation is absent from module policy");
          if (listedPublic && access.access !== "public") fail("route_public_metadata_missing", `/route_policy/public_operations`, "Module public operation is not public in OpenAPI");
          if (listedPublic) resolvedPublic.add(operationId);
          routeOwners.set(routeIdentity, module.owner_mission);
          operationOwners.set(operationId, module.owner_mission);
          paths[routePath][method] = structuredClone(operation);
          routes.push({ path: composedPath, method, operation_id: operationId, owner: module.owner_mission, mount_key: module.mount_key, access: access.access });
        }
      }
      const components = objectValue(fragment.components ?? {}, "openapi_components_invalid", "/components");
      for (const [groupName, groupValue] of Object.entries(components).sort(([a], [b]) => compareCodeUnits(a, b))) {
        const group = objectValue(groupValue, "openapi_component_group_invalid", `/components/${groupName}`);
        componentGroups[groupName] ??= {};
        for (const [name, value] of Object.entries(group).sort(([a], [b]) => compareCodeUnits(a, b))) {
          const identity = `${groupName}\0${name}`;
          const prior = componentOwners.get(identity);
          if (prior) fail("openapi_component_collision", `/components/${groupName}/${name}`, `Component collides with owner ${prior}`);
          componentOwners.set(identity, module.owner_mission);
          componentGroups[groupName][name] = structuredClone(value);
        }
      }
    }
    for (const publicId of declaredPublic) {
      if (!resolvedPublic.has(publicId)) fail("route_public_operation_unresolved", "/route_policy/public_operations", `Public operation ${publicId} does not resolve to one owned operation`);
    }
    for (const [catalogIndex, catalogPath] of module.event_catalogs.entries()) {
      const normalized = validateOwnerPath(module.owner_mission, "catalog", catalogPath, `/event_catalogs/${catalogIndex}`);
      const value = await load(normalized);
      registry.validate("https://invoice-manager.invalid/contracts/events/catalog/v1/schema.json", value);
      const catalog = value as unknown as EventCatalog;
      if (catalog.owner_mission !== module.owner_mission) fail("event_catalog_owner_mismatch", "/owner_mission", "Event catalog owner differs from module owner");
      catalog.events.forEach((entry, entryIndex) => {
        const identity = `${catalog.source}\0${entry.event_type}\0${entry.event_version}`;
        if (eventIdentities.has(identity)) fail("event_identity_collision", `/events/${entryIndex}`, "Event discriminator identity is duplicated");
        eventIdentities.set(identity, module.owner_mission);
        const typeVersion = `${entry.event_type}\0${entry.event_version}`;
        const payload = eventTypeVersions.get(typeVersion);
        if (payload && payload !== entry.payload_schema_id) fail("event_payload_schema_conflict", `/events/${entryIndex}/payload_schema_id`, "Event type/version is bound to conflicting payload schemas");
        eventTypeVersions.set(typeVersion, entry.payload_schema_id);
        if (!registry.has(entry.payload_schema_id)) fail("event_payload_schema_unresolved", `/events/${entryIndex}/payload_schema_id`, "Event payload schema ID is not registered locally");
        registry.resolve(entry.payload_schema_id);
      });
      catalogs.push(catalog);
    }
  }
  routes.sort((left, right) => compareCodeUnits(left.path, right.path) || (methodIndex.get(left.method) ?? 99) - (methodIndex.get(right.method) ?? 99) || compareCodeUnits(left.operation_id, right.operation_id));
  catalogs.sort((left, right) => compareCodeUnits(`${left.owner_mission}\0${left.source}`, `${right.owner_mission}\0${right.source}`));
  const sortedPaths = Object.fromEntries(Object.entries(paths).sort(([a], [b]) => compareCodeUnits(a, b)).map(([routePath, methods]) => [routePath, Object.fromEntries(Object.entries(methods).sort(([a], [b]) => (methodIndex.get(a) ?? 99) - (methodIndex.get(b) ?? 99)))]));
  const components = Object.fromEntries(Object.entries(componentGroups).sort(([a], [b]) => compareCodeUnits(a, b)).map(([groupName, group]) => [groupName, sortedRecord(group)]));
  return {
    openapi: {
      openapi: "3.1.0",
      info: { title: "Invoice Manager Composed API", version: "0.1.0-draft.1" },
      servers: [{ url: "/api/v1" }],
      paths: sortedPaths,
      components,
    },
    modules,
    catalogs,
    routes,
  };
}

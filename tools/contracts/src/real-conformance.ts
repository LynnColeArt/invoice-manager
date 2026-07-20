import { fail } from "./errors.js";
import type { VerifiedConformance } from "./conformance.js";
import {
  composeModules,
  type ComposedContracts,
  type EventCatalog,
  type ModuleContribution,
  type StructuredContractLoader,
} from "./modules.js";
import type { StableIdRegistry } from "./registry.js";

export type RealOwnerSurface = {
  modules: ModuleContribution[];
  documents: Map<string, Record<string, unknown>>;
  loader: StructuredContractLoader;
};

function ownerNumber(owner: string): string {
  return owner.slice(1);
}

export function buildRealOwnerSurface(
  conformance: VerifiedConformance[],
  registry: StableIdRegistry,
): RealOwnerSurface {
  const expectedOwners = ["p1", "p2", "p3", "p4"];
  if (conformance.map(({ pin }) => pin.owner_mission).join(",") !== expectedOwners.join(",")) {
    fail("conformance_owner_set_invalid", "/inputs", "Real owner composition requires exact P1-P4 pins");
  }
  const documents = new Map<string, Record<string, unknown>>();
  const modules = conformance.map(({ pin, manifest }) => {
    const output = manifest.outputs[0];
    const source = `git:${pin.commit}:${output.path}`;
    const schemaId = registry.sources.get(source);
    if (!schemaId) fail("conformance_schema_missing", "/outputs/0", "Pinned owner output schema was not registered");
    const apiPath = `contracts/api/v1/fragments/${pin.owner_mission}/conformance.openapi.json`;
    const catalogPath = `contracts/events/v1/catalogs/${pin.owner_mission}/conformance.json`;
    const operationId = `P${ownerNumber(pin.owner_mission)}Conformance`;
    documents.set(apiPath, {
      openapi: "3.1.0",
      info: { title: `${manifest.contract_id} pinned conformance`, version: manifest.version },
      servers: [{ url: "/api/v1" }],
      paths: {
        [`/conformance/${pin.owner_mission}`]: {
          get: {
            operationId,
            "x-invoice-manager-access": "protected",
            responses: { "200": { description: "Pinned owner contract is available" } },
          },
        },
      },
      components: {
        schemas: {
          [`P${ownerNumber(pin.owner_mission)}PinnedContract`]: { $ref: schemaId },
        },
      },
    });
    const catalog: EventCatalog = {
      catalog_version: 1,
      owner_mission: pin.owner_mission,
      source: `${pin.owner_mission}-conformance`,
      events: [{
        event_type: `conformance.${pin.owner_mission}_snapshot`,
        event_version: 1,
        aggregate_type: `${pin.owner_mission}_contract`,
        payload_schema_id: schemaId,
      }],
    };
    documents.set(catalogPath, catalog as unknown as Record<string, unknown>);
    return {
      module_version: 1,
      module_id: `${pin.owner_mission}-pinned-conformance`,
      owner_mission: pin.owner_mission,
      mount_key: `${pin.owner_mission}_pinned_conformance`,
      api_fragments: [apiPath],
      event_catalogs: [catalogPath],
      migration_root: manifest.migration_strategy.mode === "owner_scoped_forward_only" && manifest.migration_strategy.root
        ? manifest.migration_strategy.root
        : `services/api/migrations/${pin.owner_mission}`,
      route_policy: { default_access: "protected" as const, public_operations: [] },
    };
  });
  const loader: StructuredContractLoader = async (relative) => {
    const document = documents.get(relative);
    if (!document) fail("conformance_document_missing", "", "Real owner contribution document is unavailable");
    return structuredClone(document);
  };
  return { modules, documents, loader };
}

export async function composeRealOwners(
  root: string,
  registry: StableIdRegistry,
  conformance: VerifiedConformance[],
): Promise<ComposedContracts> {
  const surface = buildRealOwnerSurface(conformance, registry);
  return composeModules(root, registry, surface.modules, surface.loader);
}

import { validateCatalogSet, validateEventJsonl } from "./events.js";
import type { EventCatalog } from "./modules.js";
import { parseJsonBytes } from "./json.js";
import { readRepositoryBytes } from "./paths.js";
import type { StableIdRegistry } from "./registry.js";

export async function validateCanonicalEventFixtures(root: string, registry: StableIdRegistry): Promise<void> {
  const catalog = parseJsonBytes(
    await readRepositoryBytes(root, "contracts/events/v1/fixtures/runtime-catalog.json", "/event_catalog"),
    "/event_catalog",
  ) as unknown as EventCatalog;
  validateCatalogSet([catalog], registry);
  const batch = await readRepositoryBytes(root, "contracts/events/v1/fixtures/runtime-events.jsonl", "/event_batch");
  validateEventJsonl(batch, [catalog], registry);
}

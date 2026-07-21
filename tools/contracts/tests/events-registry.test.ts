import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { ContractError } from "../src/errors.js";
import { validateCatalogSet, validateDomainEvent, validateEventJsonl } from "../src/events.js";
import type { EventCatalog } from "../src/modules.js";
import { assertReferencesResolve, StableIdRegistry } from "../src/registry.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");

async function registry(): Promise<StableIdRegistry> {
  const result = new StableIdRegistry();
  for (const relative of [
    "contracts/common/v1/schema.json",
    "contracts/events/v1/envelope.schema.json",
    "contracts/events/v1/catalog.schema.json",
  ]) {
    result.add(JSON.parse(await readFile(path.join(root, relative), "utf8")) as Record<string, unknown>, relative);
  }
  result.add({
    $schema: "https://json-schema.org/draft/2020-12/schema",
    $id: "https://invoice-manager.invalid/contracts/events/v1/payloads/p8/synthetic.schema.json",
    type: "object",
    additionalProperties: false,
    required: ["label"],
    properties: { label: { type: "string", const: "synthetic" } },
  }, "synthetic-payload");
  return result;
}

const catalog: EventCatalog = {
  catalog_version: 1,
  owner_mission: "p8",
  source: "synthetic-source",
  events: [{
    event_type: "synthetic.changed",
    event_version: 1,
    aggregate_type: "synthetic",
    payload_schema_id: "https://invoice-manager.invalid/contracts/events/v1/payloads/p8/synthetic.schema.json",
  }],
};

function event(): Record<string, unknown> {
  return {
    envelope_version: 1,
    event_id: "01890f3a-1234-7abc-8def-0123456789ab",
    event_type: "synthetic.changed",
    event_version: 1,
    source: "synthetic-source",
    aggregate: { type: "synthetic", id: "01890f3a-1234-7abc-8def-0123456789ac", revision: "9223372036854775807" },
    occurred_at: "2026-07-20T12:34:56.789Z",
    recorded_at: "2026-07-20T12:34:56.790Z",
    correlation_id: null,
    causation_id: null,
    data: { label: "synthetic" },
  };
}

function expectCode(action: () => unknown, code: string, pointer?: string): void {
  try {
    action();
    throw new Error("Expected ContractError");
  } catch (error) {
    expect(error).toBeInstanceOf(ContractError);
    expect(error).toMatchObject({ code, ...(pointer === undefined ? {} : { pointer }) });
  }
}

describe("stable-ID registry", () => {
  it("resolves local documents/fragments and safe recursive references", async () => {
    const result = await registry();
    const recursive = {
      $schema: "https://json-schema.org/draft/2020-12/schema",
      $id: "https://invoice-manager.invalid/contracts/synthetic/v1/recursive.schema.json",
      type: "object",
      properties: { child: { $ref: "https://invoice-manager.invalid/contracts/synthetic/v1/recursive.schema.json" } },
    };
    result.add(recursive, "recursive");
    expect(result.resolve("https://invoice-manager.invalid/contracts/common/v1/schema.json#/$defs/Money")).toMatchObject({ type: "object" });
    expect(() => assertReferencesResolve(result)).not.toThrow();
  });

  it("rejects duplicate IDs, unresolved fragments, guessed and network references", async () => {
    const result = await registry();
    expectCode(() => result.add({ $id: "https://invoice-manager.invalid/contracts/common/v1/schema.json" }, "duplicate"), "schema_id_duplicate");
    expectCode(() => result.resolve("https://invoice-manager.invalid/contracts/common/v1/schema.json#/$defs/Missing"), "schema_fragment_unresolved");
    expectCode(() => result.resolve("#/$defs/Money"), "schema_reference_ambiguous");
    expectCode(() => result.resolve("https://example.com/schema.json"), "schema_network_reference");
  });
});

describe("event envelope and payload binding", () => {
  it("preserves signed-64-bit revision strings and validates the second-stage payload", async () => {
    const result = await registry();
    expect(() => validateDomainEvent(event(), [catalog], result)).not.toThrow();
  });

  it("rejects numeric, noncanonical, negative, out-of-range revisions and malformed instants", async () => {
    const result = await registry();
    for (const [revision, code] of [[1, "event_envelope_invalid"], ["01", "event_envelope_invalid"], ["-1", "event_envelope_invalid"], ["9223372036854775808", "event_revision_out_of_range"]] as const) {
      const value = event();
      (value.aggregate as Record<string, unknown>).revision = revision;
      expectCode(() => validateDomainEvent(value, [catalog], result), code);
    }
    const malformed = event();
    malformed.occurred_at = "2026-07-20T12:34:56Z";
    expectCode(() => validateDomainEvent(malformed, [catalog], result), "event_envelope_invalid", "/occurred_at");
  });

  it("reports discriminator, aggregate, source, and payload failures independently", async () => {
    const result = await registry();
    const wrongSource = event(); wrongSource.source = "different-source";
    expectCode(() => validateDomainEvent(wrongSource, [catalog], result), "event_source_mismatch", "/source");
    const wrongAggregate = event(); (wrongAggregate.aggregate as Record<string, unknown>).type = "different";
    expectCode(() => validateDomainEvent(wrongAggregate, [catalog], result), "event_aggregate_mismatch", "/aggregate/type");
    const wrongPayload = event(); wrongPayload.data = { label: "different" };
    expectCode(() => validateDomainEvent(wrongPayload, [catalog], result), "event_payload_invalid", "/data/label");
    const unknown = event(); unknown.event_type = "synthetic.unknown";
    expectCode(() => validateDomainEvent(unknown, [catalog], result), "event_discriminator_missing", "/event_type");
  });

  it("rejects duplicate identities and conflicting type/version payload reuse", async () => {
    const result = await registry();
    expectCode(() => validateCatalogSet([catalog, structuredClone(catalog)], result), "event_identity_collision");
    const conflicting = structuredClone(catalog);
    conflicting.source = "another-source";
    conflicting.events[0].payload_schema_id = "https://invoice-manager.invalid/contracts/common/v1/schema.json";
    expectCode(() => validateCatalogSet([catalog, conflicting], result), "event_payload_schema_conflict");
  });

  it("validates LF-terminated JSONL batches and reports safe line metadata", async () => {
    const result = await registry();
    const line = JSON.stringify(event());
    expect(() => validateEventJsonl(Buffer.from(`${line}\n${line}\n`), [catalog], result)).not.toThrow();
    expectCode(() => validateEventJsonl(Buffer.from(line), [catalog], result), "event_jsonl_termination_invalid");
    try {
      validateEventJsonl(Buffer.from(`${line}\nnot-json\n`), [catalog], result);
      throw new Error("Expected ContractError");
    } catch (error) {
      expect(error).toMatchObject({ code: "event_jsonl_json_invalid", line: 2, pointer: "" });
      expect((error as Error).message).not.toContain("not-json");
    }
  });
});

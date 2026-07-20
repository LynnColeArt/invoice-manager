import type { ErrorObject } from "ajv";
import { ContractError, fail } from "./errors.js";
import type { EventCatalog } from "./modules.js";
import type { StableIdRegistry } from "./registry.js";

type EventEnvelope = {
  envelope_version: number;
  event_id: string;
  event_type: string;
  event_version: number;
  source: string;
  aggregate: { type: string; id: string; revision: string };
  occurred_at: string;
  recorded_at: string;
  correlation_id: string | null;
  causation_id: string | null;
  data: unknown;
};

function firstAjvError(errors: ErrorObject[] | null | undefined): { pointer: string; message: string } {
  const first = errors?.[0];
  return { pointer: first?.instancePath ?? "", message: first ? `${first.keyword}: ${first.message ?? "invalid value"}` : "Schema validation failed" };
}

export function validateCatalogSet(catalogs: EventCatalog[], registry: StableIdRegistry): void {
  const identities = new Map<string, string>();
  const typeVersions = new Map<string, string>();
  catalogs.forEach((catalog, catalogIndex) => {
    registry.validate("https://invoice-manager.invalid/contracts/events/catalog/v1/schema.json", catalog as unknown);
    catalog.events.forEach((entry, entryIndex) => {
      const identity = `${catalog.source}\0${entry.event_type}\0${entry.event_version}`;
      if (identities.has(identity)) fail("event_identity_collision", `/catalogs/${catalogIndex}/events/${entryIndex}`, "Event discriminator identity is duplicated");
      identities.set(identity, catalog.owner_mission);
      const typeVersion = `${entry.event_type}\0${entry.event_version}`;
      const existingPayload = typeVersions.get(typeVersion);
      if (existingPayload && existingPayload !== entry.payload_schema_id) {
        fail("event_payload_schema_conflict", `/catalogs/${catalogIndex}/events/${entryIndex}/payload_schema_id`, "Event type/version has conflicting payload schemas");
      }
      typeVersions.set(typeVersion, entry.payload_schema_id);
      registry.resolve(entry.payload_schema_id);
    });
  });
}

export function validateDomainEvent(event: unknown, catalogs: EventCatalog[], registry: StableIdRegistry): void {
  const ajv = registry.createAjv();
  const envelopeValidator = ajv.getSchema("https://invoice-manager.invalid/contracts/events/v1/envelope.schema.json");
  if (!envelopeValidator) fail("event_envelope_schema_missing", "", "Event envelope schema is unavailable");
  if (!envelopeValidator(event)) {
    const detail = firstAjvError(envelopeValidator.errors as ErrorObject[] | null | undefined);
    fail("event_envelope_invalid", detail.pointer, detail.message);
  }
  const envelope = event as EventEnvelope;
  let revision: bigint;
  try {
    revision = BigInt(envelope.aggregate.revision);
  } catch {
    fail("event_revision_invalid", "/aggregate/revision", "Aggregate revision must be a canonical integer string");
  }
  if (revision < 0n || revision > 9223372036854775807n) fail("event_revision_out_of_range", "/aggregate/revision", "Aggregate revision exceeds signed 64-bit range");
  validateCatalogSet(catalogs, registry);
  const typeMatches = catalogs.flatMap((catalog) => catalog.events.filter((entry) => entry.event_type === envelope.event_type && entry.event_version === envelope.event_version).map((entry) => ({ catalog, entry })));
  if (typeMatches.length === 0) fail("event_discriminator_missing", "/event_type", "No catalog entry matches the event type and version");
  const sourceMatches = typeMatches.filter(({ catalog }) => catalog.source === envelope.source);
  if (sourceMatches.length === 0) fail("event_source_mismatch", "/source", "Event source does not match the catalog discriminator");
  if (sourceMatches.length > 1) fail("event_discriminator_multiple", "/event_type", "Multiple catalog entries match the event discriminator");
  const match = sourceMatches[0];
  if (match.entry.aggregate_type !== envelope.aggregate.type) fail("event_aggregate_mismatch", "/aggregate/type", "Event aggregate type does not match the catalog binding");
  const payloadValidator = ajv.getSchema(match.entry.payload_schema_id);
  if (!payloadValidator) fail("event_payload_schema_unresolved", "/data", "Payload schema ID is not registered locally");
  if (!payloadValidator(envelope.data)) {
    const detail = firstAjvError(payloadValidator.errors as ErrorObject[] | null | undefined);
    fail("event_payload_invalid", `/data${detail.pointer}`, detail.message);
  }
}

export function validateEventJsonl(bytes: Buffer, catalogs: EventCatalog[], registry: StableIdRegistry): void {
  const text = bytes.toString("utf8");
  if (Buffer.from(text, "utf8").compare(bytes) !== 0) fail("event_jsonl_utf8_invalid", "", "Event batch must be valid UTF-8");
  if (!text.endsWith("\n") || text.includes("\r")) fail("event_jsonl_termination_invalid", "", "Event batch must use LF-terminated records");
  const lines = text.slice(0, -1).split("\n");
  if (lines.some((line) => line.length === 0)) fail("event_jsonl_empty_line", "", "Event batch must not contain empty records");
  lines.forEach((line, index) => {
    let event: unknown;
    try {
      event = JSON.parse(line);
    } catch {
      fail("event_jsonl_json_invalid", "", "Event batch record is invalid JSON", index + 1);
    }
    try {
      validateDomainEvent(event, catalogs, registry);
    } catch (error) {
      if (error instanceof ContractError) throw new ContractError(error.code, error.pointer, error.message, index + 1);
      throw error;
    }
  });
}

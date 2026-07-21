import { createHash } from "node:crypto";
import { canonicalize } from "json-canonicalize";
import { fail } from "./errors.js";

export type JsonPrimitive = null | boolean | number | string;
export type JsonValue = JsonPrimitive | JsonValue[] | { [key: string]: JsonValue };

export function compareCodeUnits(left: string, right: string): number {
  return left < right ? -1 : left > right ? 1 : 0;
}

function assertJcsValue(value: unknown, pointer: string, seen: Set<object>): asserts value is JsonValue {
  if (value === undefined) fail("jcs_undefined", pointer, "RFC 8785 input must not contain undefined");
  if (typeof value === "number" && !Number.isFinite(value)) {
    fail("jcs_nonfinite_number", pointer, "RFC 8785 input must contain only finite numbers");
  }
  if (typeof value === "function" || typeof value === "symbol" || typeof value === "bigint") {
    fail("jcs_unsupported_value", pointer, "RFC 8785 input contains an unsupported value");
  }
  if (value === null || typeof value !== "object") return;
  if (seen.has(value)) fail("jcs_cycle", pointer, "RFC 8785 input must not be cyclic");
  seen.add(value);
  if (Array.isArray(value)) {
    value.forEach((entry, index) => assertJcsValue(entry, `${pointer}/${index}`, seen));
  } else {
    for (const [key, entry] of Object.entries(value)) {
      const escaped = key.replaceAll("~", "~0").replaceAll("/", "~1");
      assertJcsValue(entry, `${pointer}/${escaped}`, seen);
    }
  }
  seen.delete(value);
}

export function jcsBytes(value: unknown): Buffer {
  assertJcsValue(value, "", new Set());
  return Buffer.from(canonicalize(value), "utf8");
}

export function sha256Hex(bytes: Buffer | string): string {
  return createHash("sha256").update(bytes).digest("hex");
}

export function sha256Digest(bytes: Buffer | string): string {
  return `sha256:${sha256Hex(bytes)}`;
}

export function decodeUtf8(bytes: Buffer, pointer = ""): string {
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    fail("utf8_invalid", pointer, "Structured contract input must be valid UTF-8");
  }
}

export function parseJsonBytes(bytes: Buffer, pointer = ""): JsonValue {
  return parseJson(decodeUtf8(bytes, pointer), pointer);
}

export function parseJson(text: string, pointer = ""): JsonValue {
  try {
    return JSON.parse(text) as JsonValue;
  } catch {
    fail("json_invalid", pointer, "JSON input is invalid");
  }
}

export function stableJson(value: unknown): string {
  return `${jcsBytes(value).toString("utf8")}\n`;
}

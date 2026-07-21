import type {
  P0ErrorResponse,
  P0HealthResponse,
} from "@invoice-manager/contracts/v1";

import { hasExactKeys, isErrorResponse, isRecord, isUuidV7 } from "./errors";

export const MAXIMUM_HEALTH_BODY_BYTES = 16 * 1024;

export type HealthResult =
  | { ok: true; status: 200; value: P0HealthResponse }
  | { ok: false; status: 503; error: P0ErrorResponse };

export function isJsonContentType(value: string | null): boolean {
  if (value === null) return false;
  const mediaType = value.split(";", 1)[0]?.trim().toLowerCase();
  return mediaType === "application/json";
}

function isHealthSuccess(value: unknown): value is P0HealthResponse {
  return (
    isRecord(value) &&
    hasExactKeys(value, ["data", "meta"]) &&
    isRecord(value["data"]) &&
    hasExactKeys(value["data"], ["status"]) &&
    value["data"]["status"] === "ready" &&
    isRecord(value["meta"]) &&
    hasExactKeys(value["meta"], ["request_id"]) &&
    isUuidV7(value["meta"]["request_id"])
  );
}

function isCanonicalHealthFailure(value: unknown): value is P0ErrorResponse {
  return (
    isErrorResponse(value) &&
    value.error.code === "service_not_ready" &&
    value.error.message === "The service is not ready." &&
    value.error.fields === undefined
  );
}

export function decodeExpectedHealthResponse(
  status: number,
  text: string,
): HealthResult | null {
  let value: unknown;
  try {
    value = JSON.parse(text) as unknown;
  } catch {
    return null;
  }
  if (status === 200 && isHealthSuccess(value))
    return { ok: true, status: 200, value };
  if (status === 503 && isCanonicalHealthFailure(value)) {
    return { ok: false, status: 503, error: value };
  }
  return null;
}

export async function readBoundedResponseBody(
  response: Response,
  maximumBytes = MAXIMUM_HEALTH_BODY_BYTES,
): Promise<string | null> {
  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    let declared = 0;
    if (declaredLength.length === 0) return null;
    for (const character of declaredLength) {
      if (character < "0" || character > "9") return null;
      declared = declared * 10 + (character.charCodeAt(0) - 48);
      if (declared > maximumBytes) return null;
    }
  }
  if (response.body === null) return "";

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      total += chunk.value.byteLength;
      if (total > maximumBytes) {
        await reader.cancel();
        return null;
      }
      chunks.push(chunk.value);
    }
  } catch {
    return null;
  }
  const joined = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    joined.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(joined);
  } catch {
    return null;
  }
}

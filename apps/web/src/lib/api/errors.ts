import type {
  P0ErrorField,
  P0ErrorResponse,
} from "@invoice-manager/contracts/v1";

type UnknownRecord = Record<string, unknown>;

const UUID_HYPHENS = new Set([8, 13, 18, 23]);

export function isRecord(value: unknown): value is UnknownRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function hasExactKeys(
  value: UnknownRecord,
  required: readonly string[],
): boolean {
  const actual = Object.keys(value).sort();
  const expected = [...required].sort();
  return (
    actual.length === expected.length &&
    actual.every((key, index) => key === expected[index])
  );
}

function isLowerHex(character: string): boolean {
  return (
    (character >= "0" && character <= "9") ||
    (character >= "a" && character <= "f")
  );
}

export function isUuidV7(value: unknown): value is string {
  if (typeof value !== "string" || value.length !== 36) return false;
  for (let index = 0; index < value.length; index += 1) {
    if (UUID_HYPHENS.has(index)) {
      if (value[index] !== "-") return false;
    } else if (!isLowerHex(value[index] ?? "")) {
      return false;
    }
  }
  return value[14] === "7" && "89ab".includes(value[19] ?? "");
}

function isSafeCode(value: unknown): value is string {
  if (typeof value !== "string" || value.length === 0 || value.length > 64)
    return false;
  for (let index = 0; index < value.length; index += 1) {
    const character = value[index] ?? "";
    const lower = character >= "a" && character <= "z";
    const laterDigit = index > 0 && character >= "0" && character <= "9";
    const laterUnderscore = index > 0 && character === "_";
    if (!lower && !laterDigit && !laterUnderscore) return false;
  }
  return true;
}

function isJsonPointer(value: unknown): value is string {
  if (typeof value !== "string" || value.length > 256) return false;
  if (value.length === 0) return true;
  if (value[0] !== "/") return false;
  for (let index = 0; index < value.length; index += 1) {
    if (value[index] !== "~") continue;
    const escaped = value[index + 1];
    if (escaped !== "0" && escaped !== "1") return false;
    index += 1;
  }
  return true;
}

function isErrorField(value: unknown): value is P0ErrorField {
  return (
    isRecord(value) &&
    hasExactKeys(value, ["path", "code", "message"]) &&
    isJsonPointer(value["path"]) &&
    isSafeCode(value["code"]) &&
    typeof value["message"] === "string" &&
    value["message"].length <= 160
  );
}

export function isErrorResponse(value: unknown): value is P0ErrorResponse {
  if (!isRecord(value) || !hasExactKeys(value, ["error", "meta"])) return false;
  if (
    !isRecord(value["meta"]) ||
    !hasExactKeys(value["meta"], ["request_id"]) ||
    !isUuidV7(value["meta"]["request_id"])
  ) {
    return false;
  }
  if (!isRecord(value["error"])) return false;
  const error = value["error"];
  const keys = Object.keys(error).sort();
  const hasFields = Object.hasOwn(error, "fields");
  const expectedKeys = hasFields
    ? ["code", "fields", "message"]
    : ["code", "message"];
  if (
    keys.length !== expectedKeys.length ||
    keys.some((key, index) => key !== expectedKeys[index])
  ) {
    return false;
  }
  if (
    !isSafeCode(error["code"]) ||
    typeof error["message"] !== "string" ||
    error["message"].length > 160
  ) {
    return false;
  }
  return (
    !hasFields ||
    (Array.isArray(error["fields"]) &&
      error["fields"].length <= 16 &&
      error["fields"].every(isErrorField))
  );
}

export function createUuidV7(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  let timestamp = Date.now();
  for (let index = 5; index >= 0; index -= 1) {
    bytes[index] = timestamp % 256;
    timestamp = Math.floor(timestamp / 256);
  }
  bytes[6] = ((bytes[6] ?? 0) & 0x0f) | 0x70;
  bytes[8] = ((bytes[8] ?? 0) & 0x3f) | 0x80;
  const hex = [...bytes]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export function serviceNotReady(requestId = createUuidV7()): P0ErrorResponse {
  return {
    error: {
      code: "service_not_ready",
      message: "The service is not ready.",
    },
    meta: { request_id: requestId },
  };
}

export function routeNotFound(): P0ErrorResponse {
  return {
    error: {
      code: "route_not_found",
      message: "The requested route does not exist.",
    },
    meta: { request_id: createUuidV7() },
  };
}

export function methodNotAllowed(): P0ErrorResponse {
  return {
    error: {
      code: "method_not_allowed",
      message: "The request method is not supported.",
    },
    meta: { request_id: createUuidV7() },
  };
}

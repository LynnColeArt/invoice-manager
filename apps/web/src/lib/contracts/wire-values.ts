import type { InvoiceManagerCommonV1SchemaJson914Ceb9464EdCanonicalInt64 } from "@invoice-manager/contracts/v1";

const INT64_MAX = "9223372036854775807";
const INT64_MIN_MAGNITUDE = "9223372036854775808";

function isAsciiDigit(character: string): boolean {
  return character >= "0" && character <= "9";
}

export function assertCanonicalInt64(
  value: unknown,
): InvoiceManagerCommonV1SchemaJson914Ceb9464EdCanonicalInt64 {
  if (typeof value !== "string" || value.length === 0) {
    throw new TypeError("Expected a canonical signed 64-bit decimal string.");
  }

  const negative = value[0] === "-";
  const digits = negative ? value.slice(1) : value;
  if (
    digits.length === 0 ||
    (digits.length > 1 && digits[0] === "0") ||
    (negative && digits === "0")
  ) {
    throw new TypeError("Expected a canonical signed 64-bit decimal string.");
  }
  for (const character of digits) {
    if (!isAsciiDigit(character)) {
      throw new TypeError("Expected a canonical signed 64-bit decimal string.");
    }
  }

  const limit = negative ? INT64_MIN_MAGNITUDE : INT64_MAX;
  if (
    digits.length > limit.length ||
    (digits.length === limit.length && digits > limit)
  ) {
    throw new RangeError("Expected a canonical signed 64-bit decimal string.");
  }
  return value;
}

export function formatCanonicalInt64ForDisplay(
  value: unknown,
  locale?: string,
): string {
  const canonical = assertCanonicalInt64(value);
  return new Intl.NumberFormat(locale).format(BigInt(canonical));
}

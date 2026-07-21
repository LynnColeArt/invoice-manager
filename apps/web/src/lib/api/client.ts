import type { P0ErrorResponse } from "@invoice-manager/contracts/v1";

import { serviceNotReady } from "./errors";
import {
  decodeExpectedHealthResponse,
  type HealthResult,
  isJsonContentType,
  readBoundedResponseBody,
} from "./health";

export interface HealthClientOptions {
  fetch?: typeof fetch;
  timeoutMs?: number;
}

function unavailable(): HealthResult {
  const error: P0ErrorResponse = serviceNotReady();
  return { ok: false, status: 503, error };
}

export async function requestHealth(
  options: HealthClientOptions = {},
): Promise<HealthResult> {
  const fetcher = options.fetch ?? fetch;
  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort(),
    options.timeoutMs ?? 750,
  );
  try {
    const response = await fetcher("/api/v1/health", {
      method: "GET",
      headers: { accept: "application/json" },
      redirect: "manual",
      cache: "no-store",
      signal: controller.signal,
    });
    if (!isJsonContentType(response.headers.get("content-type"))) {
      controller.abort();
      return unavailable();
    }
    const body = await readBoundedResponseBody(response);
    if (body === null) {
      controller.abort();
      return unavailable();
    }
    const decoded = decodeExpectedHealthResponse(response.status, body);
    if (decoded === null) controller.abort();
    return decoded ?? unavailable();
  } catch {
    return unavailable();
  } finally {
    clearTimeout(timeout);
  }
}

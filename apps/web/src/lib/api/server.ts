import type { P0ErrorResponse } from "@invoice-manager/contracts/v1";

import { methodNotAllowed, routeNotFound, serviceNotReady } from "./errors";
import {
  decodeExpectedHealthResponse,
  type HealthResult,
  isJsonContentType,
  readBoundedResponseBody,
} from "./health";

const HEALTH_PATH = "/api/v1/health";
const UPSTREAM_DEADLINE_MS = 750;

const SAFE_RESPONSE_HEADERS = {
  "cache-control": "no-store, max-age=0",
  "content-type": "application/json; charset=utf-8",
  expires: "0",
  pragma: "no-cache",
} as const;

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: SAFE_RESPONSE_HEADERS,
  });
}

function safeUnavailable(): HealthResult {
  return { ok: false, status: 503, error: serviceNotReady() };
}

function fixedApiOrigin(): URL | null {
  const raw = process.env["INVOICE_MANAGER_API_ORIGIN"];
  if (raw === undefined || raw.length === 0) return null;
  try {
    const parsed = new URL(raw);
    if (
      (parsed.protocol !== "http:" && parsed.protocol !== "https:") ||
      parsed.username !== "" ||
      parsed.password !== "" ||
      parsed.pathname !== "/" ||
      parsed.search !== "" ||
      parsed.hash !== "" ||
      raw !== parsed.origin
    ) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

export async function readServerHealth(): Promise<HealthResult> {
  const origin = fixedApiOrigin();
  if (origin === null) return safeUnavailable();
  const target = new URL(HEALTH_PATH, `${origin.origin}/`);
  if (
    target.origin !== origin.origin ||
    target.pathname !== HEALTH_PATH ||
    target.search !== ""
  ) {
    return safeUnavailable();
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), UPSTREAM_DEADLINE_MS);
  try {
    const response = await fetch(target, {
      method: "GET",
      headers: { accept: "application/json" },
      redirect: "manual",
      cache: "no-store",
      signal: controller.signal,
    });
    if (response.status !== 200 && response.status !== 503) {
      controller.abort();
      return safeUnavailable();
    }
    if (!isJsonContentType(response.headers.get("content-type"))) {
      controller.abort();
      return safeUnavailable();
    }
    if (response.url !== "") {
      const responseUrl = new URL(response.url);
      if (
        responseUrl.origin !== origin.origin ||
        responseUrl.pathname !== HEALTH_PATH
      ) {
        controller.abort();
        return safeUnavailable();
      }
    }
    const body = await readBoundedResponseBody(response);
    if (body === null) {
      controller.abort();
      return safeUnavailable();
    }
    const decoded = decodeExpectedHealthResponse(response.status, body);
    if (decoded === null) controller.abort();
    return decoded ?? safeUnavailable();
  } catch {
    return safeUnavailable();
  } finally {
    clearTimeout(timeout);
  }
}

export async function handleApiV1Get(request: Request): Promise<Response> {
  const url = new URL(request.url);
  if (url.pathname !== HEALTH_PATH || url.search !== "") {
    return jsonResponse(routeNotFound(), 404);
  }
  const result = await readServerHealth();
  return result.ok
    ? jsonResponse(result.value, result.status)
    : jsonResponse(result.error, result.status);
}

export function handleApiV1BaseGet(): Response {
  return jsonResponse(routeNotFound(), 404);
}

export function handleUnsupportedMethod(): Response {
  const error: P0ErrorResponse = methodNotAllowed();
  return jsonResponse(error, 405);
}

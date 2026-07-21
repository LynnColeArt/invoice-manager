import { describe, expect, it, vi } from "vitest";

import { requestHealth } from "../../src/lib/api/client";
import { decodeExpectedHealthResponse } from "../../src/lib/api/health";
import {
  assertCanonicalInt64,
  formatCanonicalInt64ForDisplay,
} from "../../src/lib/contracts/wire-values";

const requestId = "018f08c4-2f44-7abc-8abc-1234567890ab";

describe("canonical wire adapters", () => {
  it.each([
    "-9223372036854775808",
    "-9007199254740993",
    "0",
    "9007199254740993",
    "9223372036854775807",
  ])("round-trips canonical int64 %s without number coercion", (value) => {
    expect(assertCanonicalInt64(value)).toBe(value);
  });

  it.each([
    "9223372036854775808",
    "-9223372036854775809",
    "01",
    "-0",
    "+1",
    " 1",
    1,
  ])("rejects non-canonical or out-of-range int64 %j", (value) => {
    expect(() => assertCanonicalInt64(value)).toThrow(
      "canonical signed 64-bit decimal string",
    );
  });

  it("uses bigint only behind an explicit checked display adapter", () => {
    expect(formatCanonicalInt64ForDisplay("-9007199254740993", "en-US")).toBe(
      "-9,007,199,254,740,993",
    );
  });
});

describe("generated health envelope refinement", () => {
  it("accepts only the exact generated success shape", () => {
    expect(
      decodeExpectedHealthResponse(
        200,
        JSON.stringify({
          data: { status: "ready" },
          meta: { request_id: requestId },
        }),
      ),
    ).toEqual({
      ok: true,
      status: 200,
      value: { data: { status: "ready" }, meta: { request_id: requestId } },
    });

    expect(
      decodeExpectedHealthResponse(
        200,
        JSON.stringify({
          data: { status: "ready", internal: "nope" },
          meta: { request_id: requestId },
        }),
      ),
    ).toBeNull();
  });

  it("accepts only canonical 503 health failures", () => {
    const envelope = {
      error: {
        code: "service_not_ready",
        message: "The service is not ready.",
      },
      meta: { request_id: requestId },
    };
    expect(decodeExpectedHealthResponse(503, JSON.stringify(envelope))).toEqual(
      {
        ok: false,
        status: 503,
        error: envelope,
      },
    );
    expect(
      decodeExpectedHealthResponse(
        503,
        JSON.stringify({
          ...envelope,
          error: { ...envelope.error, message: "socket secret" },
        }),
      ),
    ).toBeNull();
  });
});

describe("injectable same-origin health client", () => {
  it("returns typed success and structured failure without exposing raw bodies", async () => {
    const successFetch = vi.fn(async () =>
      Response.json({
        data: { status: "ready" },
        meta: { request_id: requestId },
      }),
    );
    await expect(requestHealth({ fetch: successFetch })).resolves.toMatchObject(
      {
        ok: true,
        value: { data: { status: "ready" } },
      },
    );
    expect(successFetch).toHaveBeenCalledWith(
      "/api/v1/health",
      expect.objectContaining({
        method: "GET",
        redirect: "manual",
        cache: "no-store",
      }),
    );

    const malformedFetch = vi.fn(
      async () =>
        new Response("internal-host.example:9999", {
          status: 200,
          headers: { "content-type": "text/plain" },
        }),
    );
    const result = await requestHealth({ fetch: malformedFetch });
    expect(result).toMatchObject({
      ok: false,
      status: 503,
      error: {
        error: {
          code: "service_not_ready",
          message: "The service is not ready.",
        },
      },
    });
    expect(JSON.stringify(result)).not.toContain("internal-host");
  });

  it("maps redirect, timeout, and oversized bodies to safe unavailability", async () => {
    const redirectFetch = vi.fn(
      async () =>
        new Response(null, {
          status: 302,
          headers: { location: "http://secret.invalid/" },
        }),
    );
    await expect(
      requestHealth({ fetch: redirectFetch }),
    ).resolves.toMatchObject({
      ok: false,
      status: 503,
    });

    const timeoutFetch = vi.fn(
      (_input: string | URL | Request, init?: RequestInit) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );
    await expect(
      requestHealth({ fetch: timeoutFetch, timeoutMs: 5 }),
    ).resolves.toMatchObject({
      ok: false,
      status: 503,
    });

    const oversizedFetch = vi.fn(
      async () =>
        new Response("x".repeat(16 * 1024 + 1), {
          status: 200,
          headers: { "content-type": "application/json" },
        }),
    );
    await expect(
      requestHealth({ fetch: oversizedFetch }),
    ).resolves.toMatchObject({
      ok: false,
      status: 503,
    });
  });

  it.each(["application/jsonp", "application/json-evil", "text/plain"])(
    "rejects non-JSON media type token %s exactly",
    async (contentType) => {
      const deceptiveFetch = vi.fn(
        async () =>
          new Response(
            JSON.stringify({
              data: { status: "ready" },
              meta: { request_id: requestId },
            }),
            { status: 200, headers: { "content-type": contentType } },
          ),
      );
      await expect(
        requestHealth({ fetch: deceptiveFetch }),
      ).resolves.toMatchObject({
        ok: false,
        status: 503,
      });
    },
  );
});

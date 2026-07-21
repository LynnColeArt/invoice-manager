import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import http from "node:http";

const profile = process.env["WP10_PROXY_PROFILE"] ?? "stopped";
const fixtureOrigin = process.env["WP10_FIXTURE_CONTROL_ORIGIN"];
const fixedFixtureRequestId = "018f08c4-2f44-7abc-8abc-1234567890ab";
const requestIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

type ErrorEnvelope = {
  error: { code: string; message: string };
  meta: { request_id: string };
};

type FixtureObservation = {
  method: string;
  url: string;
  headers: Record<string, string>;
  aborted_before_end: boolean;
  closed_ms: number | null;
};

async function expectCanonicalError(
  response: {
    status(): number;
    json(): Promise<unknown>;
    headers(): Record<string, string>;
  },
  status: number,
  code: string,
  message: string,
) {
  expect(response.status()).toBe(status);
  const body = (await response.json()) as ErrorEnvelope;
  expect(body).toEqual({
    error: { code, message },
    meta: { request_id: expect.stringMatching(requestIdPattern) },
  });
  const headers = response.headers();
  expect(headers["cache-control"]).toContain("no-store");
  expect(headers["set-cookie"]).toBeUndefined();
  expect(headers["location"]).toBeUndefined();
  expect(JSON.stringify(body)).not.toContain("127.0.0.1");
  return body;
}

async function fixtureControl(
  action: "reset" | "snapshot",
): Promise<FixtureObservation[]> {
  if (fixtureOrigin === undefined) return [];
  const response = await fetch(`${fixtureOrigin}/__control__/${action}`);
  if (!response.ok && response.status !== 204)
    throw new Error(`fixture control failed: ${response.status}`);
  if (action === "reset") return [];
  const payload = (await response.json()) as {
    observations: FixtureObservation[];
  };
  return payload.observations;
}

function rawRequest(path: string): Promise<{
  status: number;
  headers: http.IncomingHttpHeaders;
  body: string;
}> {
  return new Promise((resolve, reject) => {
    const request = http.request(
      { host: "localhost", port: 3000, method: "GET", path },
      (response) => {
        const chunks: Buffer[] = [];
        response.on("data", (chunk: Buffer) => chunks.push(chunk));
        response.on("end", () =>
          resolve({
            status: response.statusCode ?? 0,
            headers: response.headers,
            body: Buffer.concat(chunks).toString("utf8"),
          }),
        );
      },
    );
    request.on("error", reject);
    request.end();
  });
}

test("T046-PUBLIC-01: handler-owned invalid paths and methods are local canonical failures", async ({
  request,
}) => {
  await fixtureControl("reset");
  const localRequestIds: string[] = [];
  for (const path of [
    "/api/v1",
    "/api/v1/",
    "/api/v1/health/",
    "/api/v1/health?destination=http%3A%2F%2Fsecret.invalid",
    "/api/v1/health%2Fsecret",
    "/api/v1/%5Csecret",
    "/api/v1/%255csecret",
    "/api/v1/%252e%252e/health",
  ]) {
    const body = await expectCanonicalError(
      await request.get(path, {
        headers: {
          authorization: "Bearer browser-secret",
          cookie: "session=browser-secret",
          forwarded: "host=secret.invalid",
          "x-forwarded-host": "secret.invalid",
          "x-rewrite-url": "http://secret.invalid/",
        },
        maxRedirects: 0,
      }),
      404,
      "route_not_found",
      "The requested route does not exist.",
    );
    localRequestIds.push(body.meta.request_id);
  }
  expect(new Set(localRequestIds).size).toBe(localRequestIds.length);

  for (const path of ["/api/v1", "/api/v1/health"]) {
    const head = await request.fetch(path, { method: "HEAD", maxRedirects: 0 });
    expect(head.status()).toBe(405);
    expect(await head.body()).toHaveLength(0);
    expect(head.headers()["cache-control"]).toContain("no-store");

    for (const method of [
      "OPTIONS",
      "POST",
      "PUT",
      "PATCH",
      "DELETE",
    ] as const) {
      await expectCanonicalError(
        await request.fetch(path, { method, maxRedirects: 0 }),
        405,
        "method_not_allowed",
        "The request method is not supported.",
      );
    }
  }
  expect(await fixtureControl("snapshot")).toEqual([]);
});

test("T046-UPSTREAM-01: canonical health uses a fixed target and safe bounded response", async ({
  request,
}) => {
  await fixtureControl("reset");
  const started = performance.now();
  const response = await request.get("/api/v1/health", {
    headers: {
      authorization: "Bearer browser-secret",
      cookie: "session=browser-secret",
      forwarded: "host=secret.invalid",
      "x-forwarded-host": "secret.invalid",
      "x-rewrite-url": "http://secret.invalid/",
    },
    maxRedirects: 0,
  });
  const elapsedMs = performance.now() - started;

  if (profile === "real-ready" || profile === "header-leak") {
    expect(response.status()).toBe(200);
    expect(await response.json()).toEqual({
      data: { status: "ready" },
      meta: { request_id: expect.stringMatching(requestIdPattern) },
    });
  } else {
    await expectCanonicalError(
      response,
      503,
      "service_not_ready",
      "The service is not ready.",
    );
  }
  const serialized = JSON.stringify({
    body: (await response.body()).toString("utf8"),
    headers: response.headers(),
  });
  expect(serialized).not.toContain("browser-secret");
  expect(serialized).not.toContain("secret.invalid");
  expect(serialized).not.toContain("fixture_secret");
  expect(response.headers()["set-cookie"]).toBeUndefined();
  expect(response.headers()["location"]).toBeUndefined();
  expect(response.headers()["x-internal-origin"]).toBeUndefined();

  if (profile === "slow") {
    expect(elapsedMs).toBeGreaterThanOrEqual(650);
    expect(elapsedMs).toBeLessThan(950);
  }
  const observations = await fixtureControl("snapshot");
  if (fixtureOrigin !== undefined) {
    expect(observations).toHaveLength(1);
    expect(observations[0]).toMatchObject({
      method: "GET",
      url: "/api/v1/health",
    });
    expect(observations[0]?.headers["accept"]).toBe("application/json");
    const upstreamHeaders = JSON.stringify(observations[0]?.headers);
    expect(upstreamHeaders).not.toContain("browser-secret");
    expect(upstreamHeaders).not.toContain("secret.invalid");
    if (profile === "slow" || profile === "slow-non-json") {
      expect(observations[0]?.aborted_before_end).toBe(true);
      expect(observations[0]?.closed_ms).toBeLessThan(950);
    }
  }

  if (profile === "canonical-503") {
    expect(((await response.json()) as ErrorEnvelope).meta.request_id).toBe(
      fixedFixtureRequestId,
    );
  }
  if (
    fixtureOrigin !== undefined &&
    !["canonical-503", "header-leak"].includes(profile)
  ) {
    expect(((await response.json()) as ErrorEnvelope).meta.request_id).not.toBe(
      fixedFixtureRequestId,
    );
  }
});

test("T046-PREROUTE-01: locked framework normalization does not follow or reach upstream", async () => {
  await fixtureControl("reset");
  const repeatedSlash = await rawRequest("/api//v1/health");
  expect(repeatedSlash.status).toBe(308);
  expect(repeatedSlash.headers.location).toBe("/api/v1/health");
  expect(repeatedSlash.body).not.toContain("INVOICE_MANAGER_API_ORIGIN");

  const rawBackslash = await rawRequest("/api\\v1\\health");
  expect(rawBackslash.status).toBe(308);
  expect(rawBackslash.headers.location).toBe("/api/v1/health");

  const encodedTraversal = await rawRequest("/api/v1/%2e%2e/health");
  expect(encodedTraversal.status).toBe(404);
  expect(encodedTraversal.headers.location).toBeUndefined();
  expect(encodedTraversal.body).not.toContain("INVOICE_MANAGER_API_ORIGIN");
  const preRouteSurface = JSON.stringify([
    repeatedSlash,
    rawBackslash,
    encodedTraversal,
  ]);
  for (const secret of [
    fixtureOrigin,
    "127.0.0.1",
    "fixture_secret",
    "secret.invalid",
  ]) {
    if (secret !== undefined) expect(preRouteSurface).not.toContain(secret);
  }
  expect(await fixtureControl("snapshot")).toEqual([]);
});

test("T047-SHELL-01: live shell is same-origin, accessible, responsive, and contrast-safe", async ({
  page,
}) => {
  const browserRequests: string[] = [];
  page.on("request", (request) => browserRequests.push(request.url()));
  await page.goto("/");
  await expect(
    page.getByRole("heading", { level: 1, name: "Invoice Manager foundation" }),
  ).toBeVisible();
  if (profile === "real-ready" || profile === "header-leak") {
    await expect(
      page.getByText("Service ready", { exact: true }),
    ).toBeVisible();
  } else {
    await expect(
      page.getByRole("heading", { level: 3, name: "Service unavailable" }),
    ).toBeVisible();
  }
  expect(
    browserRequests.every((url) => url.startsWith("http://localhost:3000/")),
  ).toBe(true);

  await page.keyboard.press("Tab");
  await expect(
    page.getByRole("link", { name: "Skip to main content" }),
  ).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("main")).toBeFocused();
  await expect(page.locator("nav, form")).toHaveCount(0);
  for (const feature of [
    "Invoices",
    "Clients",
    "Projects",
    "Dashboard",
    "Reporting",
  ]) {
    await expect(page.getByText(feature, { exact: true })).toHaveCount(0);
  }

  for (const viewport of [
    { width: 320, height: 640 },
    { width: 768, height: 900 },
    { width: 1280, height: 900 },
    { width: 1920, height: 1080 },
  ]) {
    await page.setViewportSize(viewport);
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth - window.innerWidth,
      ),
    ).toBeLessThanOrEqual(0);
  }
  await page.setViewportSize({ width: 320, height: 640 });
  await page.evaluate(() => {
    document.documentElement.style.zoom = "2";
  });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth - window.innerWidth,
    ),
  ).toBeLessThanOrEqual(0);
  await page.evaluate(() => {
    document.documentElement.style.zoom = "1";
  });

  for (const colorScheme of ["light", "dark"] as const) {
    await page.emulateMedia({ colorScheme, forcedColors: "none" });
    const ratios = await page.evaluate(() => {
      const style = getComputedStyle(document.documentElement);
      const rgb = (name: string) => {
        const match = style.getPropertyValue(name).match(/[0-9a-f]{2}/gi);
        if (match === null || match.length !== 3)
          throw new Error(`expected hex color ${name}`);
        return match.map((part) => Number.parseInt(part, 16));
      };
      const luminance = (color: number[]) => {
        const linear = color.map((part) => {
          const channel = part / 255;
          return channel <= 0.04045
            ? channel / 12.92
            : ((channel + 0.055) / 1.055) ** 2.4;
        });
        return (
          0.2126 * (linear[0] ?? 0) +
          0.7152 * (linear[1] ?? 0) +
          0.0722 * (linear[2] ?? 0)
        );
      };
      const ratio = (left: number[], right: number[]) => {
        const ordered = [luminance(left), luminance(right)].sort(
          (a, b) => b - a,
        );
        const light = ordered[0] ?? 0;
        const dark = ordered[1] ?? 0;
        return (light + 0.05) / (dark + 0.05);
      };
      const background = rgb("--background");
      return {
        accent: ratio(rgb("--accent"), background),
        focus: ratio(rgb("--focus"), background),
        muted: ratio(rgb("--muted"), background),
        text: ratio(rgb("--text"), background),
      };
    });
    expect(ratios.text).toBeGreaterThanOrEqual(4.5);
    expect(ratios.muted).toBeGreaterThanOrEqual(4.5);
    expect(ratios.accent).toBeGreaterThanOrEqual(4.5);
    expect(ratios.focus).toBeGreaterThanOrEqual(3);
  }
  await page.emulateMedia({ forcedColors: "active" });
  expect(
    await page.evaluate(() => matchMedia("(forced-colors: active)").matches),
  ).toBe(true);
  await page.emulateMedia({ colorScheme: "light", forcedColors: "none" });

  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
    .analyze();
  expect(
    results.violations.filter(
      ({ impact }) => impact === "serious" || impact === "critical",
    ),
  ).toEqual([]);
});

test("T047-NFR007-01: real Ready diagnostic measures sequential complete same-origin reads", async ({
  request,
}) => {
  test.setTimeout(110_000);
  test.skip(
    profile !== "real-ready",
    "diagnostic belongs only to the real WP08 Ready phase",
  );

  const validate = async () => {
    const started = performance.now();
    try {
      const response = await request.get("/api/v1/health", { maxRedirects: 0 });
      const bytes = await response.body();
      const completed = performance.now();
      const body = JSON.parse(bytes.toString("utf8")) as {
        data?: { status?: string };
        meta?: { request_id?: string };
      };
      const valid =
        response.status() === 200 &&
        body.data?.status === "ready" &&
        requestIdPattern.test(body.meta?.request_id ?? "");
      return { durationMs: completed - started, valid };
    } catch {
      return { durationMs: performance.now() - started, valid: false };
    }
  };

  const warmupStarted = performance.now();
  for (let warmup = 0; warmup < 10; warmup += 1) {
    const sample = await validate();
    expect(sample.valid).toBe(true);
  }
  const warmupCompleted = performance.now();

  const samples: Array<{ durationMs: number; valid: boolean }> = [];
  let invalid = 0;
  const measuredStarted = performance.now();
  for (let sampleIndex = 0; sampleIndex < 100; sampleIndex += 1) {
    const sample = await validate();
    samples.push(sample);
    if (!sample.valid) invalid += 1;
  }
  const measuredCompleted = performance.now();
  const sorted = samples
    .map(({ durationMs }) => durationMs)
    .sort((left, right) => left - right);
  const minimum = sorted[0] ?? Number.NaN;
  const median = ((sorted[49] ?? Number.NaN) + (sorted[50] ?? Number.NaN)) / 2;
  const p99 = sorted[98] ?? Number.NaN;
  const maximum = sorted[99] ?? Number.NaN;
  const slow = samples.filter(({ durationMs }) => durationMs > 1_000).length;
  console.log(
    `[nfr-007:samples] ${JSON.stringify(samples.map((sample, index) => ({ index: index + 1, ...sample })))}`,
  );
  console.log(
    `[nfr-007] evidence=diagnostic clock=performance.now_monotonic warmups=10 warmup_start_ms=${warmupStarted.toFixed(3)} warmup_stop_ms=${warmupCompleted.toFixed(3)} warmup_total_ms=${(warmupCompleted - warmupStarted).toFixed(3)} samples=100 measured_start_ms=${measuredStarted.toFixed(3)} measured_stop_ms=${measuredCompleted.toFixed(3)} measured_total_ms=${(measuredCompleted - measuredStarted).toFixed(3)} sequential=true complete_body=true min_ms=${minimum.toFixed(3)} median_ms=${median.toFixed(3)} p99_sample_99_ms=${p99.toFixed(3)} max_ms=${maximum.toFixed(3)} slow=${slow} invalid=${invalid}`,
  );
  expect(samples).toHaveLength(100);
  expect(invalid).toBe(0);
  expect(p99).toBeLessThanOrEqual(1_000);
});

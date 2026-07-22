import { readFileSync } from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

const harness = readFileSync(
  path.join(process.cwd(), "tests/foundation/http-smoke.mjs"),
  "utf8",
);

describe("HTTP smoke process lifecycle", () => {
  it("gives cold ReleaseSafe startup its own bounded allowance", () => {
    expect(harness).toContain("const releaseSafeColdStartTimeoutMs = 180_000;");
    expect(harness).toMatch(
      /"WP08 ReleaseSafe Zig",\s+releaseSafeColdStartTimeoutMs,\s+\);/,
    );
    expect(harness).toContain(
      "function waitForReadyLine(child, pattern, label, timeoutMs = 30_000)",
    );
    expect(harness).toContain(
      "${label} startup timed out after ${timeoutMs} ms; stderr=",
    );
    expect(harness).toContain(
      'await waitForExit(child, "private network namespace smoke", 600_000);',
    );
  });
});

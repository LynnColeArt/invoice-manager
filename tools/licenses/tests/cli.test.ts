import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { describe, expect, it } from "vitest";
import { findRepositoryRoot } from "../src/audit.js";

const root = findRepositoryRoot();
const execFileAsync = promisify(execFile);

async function run(command: string): Promise<{ stdout: string; stderr: string }> {
  return execFileAsync(
    process.execPath,
    ["--import", "tsx", "tools/licenses/src/main.ts", command],
    { cwd: root, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 },
  );
}

describe("license audit CLI", () => {
  it("emits byte-identical GPL-3.0-only source-closure reports", async () => {
    const first = await run("report");
    const second = await run("report");
    expect(first.stdout).toBe(second.stdout);
    const report = JSON.parse(first.stdout) as {
      project_license: string;
      status: string;
      distribution: { kind: string; deferred_packaging: string[] };
    };
    expect(report.project_license).toBe("GPL-3.0-only");
    expect(report.status).toBe("compatible");
    expect(report.distribution.kind).toBe("source-repository");
    expect(report.distribution.deferred_packaging).toEqual([
      "container-image",
      "next-standalone",
      "zig-installed-binary",
    ]);
    expect(first.stdout).not.toContain(".next/standalone");
    expect(first.stdout).not.toContain("bin/invoice-manager-api");
  });

  it("checks exact ShovelerDB source evidence without network access", async () => {
    const result = await run("source-check");
    expect(result.stderr).toContain(
      "exact ShovelerDB GPL-3.0-only provenance/tree/license/notice evidence verified",
    );
    expect(JSON.parse(result.stdout)).toMatchObject({
      verified: true,
      file_count: 43,
      source_tree_sha256:
        "681d76ebe2ab6b05b3a94c7ab86749e5c3013520adb7c84f83dabfd15b2a544c",
    });
  });

  it("returns a successful check only for a compatible deterministic report", async () => {
    const result = await run("check");
    expect(result.stderr).toContain(
      "deterministic GPL-3.0-only source-defined runtime closure is compatible",
    );
  });

  it("rejects unknown commands", async () => {
    await expect(run("not-a-command")).rejects.toMatchObject({ code: 2 });
  });
});

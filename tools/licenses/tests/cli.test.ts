import { spawnSync } from "node:child_process";
import path from "node:path";
import { beforeAll, describe, expect, it } from "vitest";
import {
  findRepositoryRoot,
  hydrateArtifactPolicy,
  loadPolicy,
  stageRuntimeNotices,
} from "../src/audit.js";

const root = findRepositoryRoot();
const executable = path.join(root, "node_modules/.bin/tsx");
const main = path.join(root, "tools/licenses/src/main.ts");

function invoke(command: string): {
  status: number | null;
  stdout: string;
  stderr: string;
} {
  const result = spawnSync(executable, [main, command], {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  if (result.error) throw result.error;
  return {
    status: result.status,
    stdout: result.stdout,
    stderr: result.stderr,
  };
}

beforeAll(async () => {
  const policy = await hydrateArtifactPolicy(root, await loadPolicy(root));
  await stageRuntimeNotices(root, policy);
});

describe("license CLI black box", () => {
  it("rejects unknown commands with stable usage diagnostics", () => {
    const result = invoke("unknown-command");
    expect(result.status).toBe(2);
    expect(result.stderr).toBe(
      "[license:error] usage requires exactly one supported command\n",
    );
  });

  it("verifies the exact ShovelerDB source receipt independently", () => {
    const result = invoke("source-check");
    expect(result.status).toBe(0);
    expect(JSON.parse(result.stdout)).toMatchObject({ verified: true });
    expect(result.stderr).toContain(
      "exact ShovelerDB provenance/tree/license/notice evidence verified",
    );
  });

  it("emits byte-identical artifact reports and fails the mandatory SWC license", () => {
    const first = invoke("check-existing");
    const second = invoke("check-existing");
    expect(first.status).toBe(3);
    expect(second.status).toBe(3);
    expect(first.stdout).toBe(second.stdout);
    const report = JSON.parse(first.stdout) as {
      status: string;
      components: Array<{
        identity: string;
        runtime_role: string;
        artifact_paths?: string[];
      }>;
      artifacts: {
        standalone: {
          manifests: unknown[];
          native_artifacts: string[];
          violations: Array<{ reason: string }>;
        };
        zig: { violations: Array<{ reason: string }> };
      };
      violations: Array<{ component: string; reason: string }>;
    };
    expect(report.status).toBe("blocked");
    expect(
      report.components.filter((entry) => entry.runtime_role === "build-only"),
    ).toEqual([]);
    const tslib = report.components.find(
      (entry) => entry.identity === "npm:tslib",
    );
    expect(tslib).toMatchObject({
      identity: "npm:tslib",
      runtime_role: "combined-runtime",
    });
    expect(tslib?.artifact_paths).toBeUndefined();
    expect(report.artifacts.standalone.manifests).toHaveLength(66);
    expect(report.artifacts.standalone.native_artifacts).toEqual(
      expect.arrayContaining([
        expect.stringMatching(/sharp-linux-x64\.node$/u),
        expect.stringMatching(/libvips-cpp\.so\.8\.17\.3$/u),
      ]),
    );
    expect(report.violations).toContainEqual(
      expect.objectContaining({
        component: "npm:@swc/helpers@0.5.15",
        reason: "license_incompatible",
      }),
    );
    expect(report.artifacts.standalone.violations).toContainEqual(
      expect.objectContaining({ reason: "artifact_layout_private_prefix" }),
    );
    expect(report.artifacts.zig.violations).toContainEqual(
      expect.objectContaining({ reason: "zig_artifact_required_path_missing" }),
    );
    expect(first.stderr).not.toContain(root);
    expect(first.stderr).toContain("component=npm:@swc/helpers@0.5.15");
  });
});

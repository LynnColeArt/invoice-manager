import { readFile } from "node:fs/promises";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  auditComponents,
  discoverRuntimeComponents,
  findRepositoryRoot,
  renderReport,
  type LicenseComponent,
  type LicensePolicy,
} from "../src/audit.js";

const root = findRepositoryRoot();

const policy: LicensePolicy = {
  schema: "invoice-manager.runtime-license-policy/v1",
  project_license: "GPL-2.0-only",
  compatible_combined_runtime: [
    "0BSD",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "GPL-2.0-only",
    "ISC",
    "MIT",
    "MIT-0",
  ],
  incompatible_combined_runtime: [
    "Apache-2.0",
    "GPL-3.0-only",
    "LGPL-3.0-or-later",
  ],
  license_selections: {},
};

function component(
  overrides: Partial<LicenseComponent> = {},
): LicenseComponent {
  return {
    identity: "npm:example",
    version: "1.0.0",
    source: "https://registry.npmjs.org/example/-/example-1.0.0.tgz",
    runtime_role: "combined-runtime",
    spdx_expression: "MIT",
    selected_license: "MIT",
    notice_path: "node_modules/example/LICENSE",
    dependency_path: "@invoice-manager/web > example",
    evidence_path: "package-lock.json#packages/node_modules/example",
    evidence_digest: "sha256:" + "a".repeat(64),
    disposition: "compatible",
    ...overrides,
  };
}

describe("deterministic runtime license policy", () => {
  it("fails closed for unknown, incompatible, and unselected multi-license evidence", () => {
    const report = auditComponents(
      [
        component({
          identity: "npm:unknown",
          spdx_expression: "UNKNOWN",
          selected_license: null,
        }),
        component({
          identity: "npm:apache",
          spdx_expression: "Apache-2.0",
          selected_license: "Apache-2.0",
        }),
        component({
          identity: "npm:choice",
          spdx_expression: "MIT OR Apache-2.0",
          selected_license: null,
        }),
      ],
      policy,
    );

    expect(report.status).toBe("blocked");
    expect(report.violations).toEqual([
      expect.objectContaining({
        component: "npm:apache@1.0.0",
        reason: "license_incompatible",
      }),
      expect.objectContaining({
        component: "npm:choice@1.0.0",
        reason: "license_selection_required",
      }),
      expect.objectContaining({
        component: "npm:unknown@1.0.0",
        reason: "license_unknown",
      }),
    ]);
    for (const violation of report.violations) {
      expect(violation.dependency_path).toBeTruthy();
      expect(violation.evidence).toBeTruthy();
      expect(violation.policy_reason).toBeTruthy();
    }
  });

  it("requires the selected branch to be committed and present in an OR expression", () => {
    const selectedPolicy = structuredClone(policy);
    selectedPolicy.license_selections["npm:choice@1.0.0"] = "BSD-3-Clause";
    const report = auditComponents(
      [
        component({
          identity: "npm:choice",
          spdx_expression: "MIT OR Apache-2.0",
          selected_license: null,
        }),
      ],
      selectedPolicy,
    );

    expect(report.violations).toEqual([
      expect.objectContaining({ reason: "license_selection_invalid" }),
    ]);
  });

  it("sorts records and emits byte-identical canonical reports", () => {
    const first = auditComponents(
      [
        component({ identity: "npm:zeta" }),
        component({ identity: "npm:alpha" }),
      ],
      policy,
    );
    const second = auditComponents(
      [
        component({ identity: "npm:alpha" }),
        component({ identity: "npm:zeta" }),
      ],
      policy,
    );

    expect(renderReport(first)).toEqual(renderReport(second));
    expect(first.components.map((entry) => entry.identity)).toEqual([
      "npm:alpha",
      "npm:zeta",
    ]);
    expect(renderReport(first).endsWith("\n")).toBe(true);
  });

  it("requires canonical SHA-256 notice evidence in committed policy", async () => {
    const committed = JSON.parse(
      await readFile(
        path.join(root, "tools/licenses/policy/runtime-policy.json"),
        "utf8",
      ),
    ) as LicensePolicy;
    for (const entry of Object.values(committed.notice_evidence ?? {})) {
      expect(entry.path).not.toMatch(
        /^(?:\/|[A-Za-z]:|.*(?:^|\/)\.\.(?:\/|$))/u,
      );
      expect(entry.sha256).toMatch(/^[0-9a-f]{64}$/u);
    }
  });

  it("discovers the exact Linux x64 production-lock closure and mandatory Apache blocker", async () => {
    const components = await discoverRuntimeComponents(root);
    const report = auditComponents(components, policy);

    expect(components.length).toBeGreaterThanOrEqual(29);
    expect(
      components.map((entry) => `${entry.identity}@${entry.version}`),
    ).toContain("npm:@swc/helpers@0.5.15");
    expect(report.violations).toContainEqual(
      expect.objectContaining({
        component: "npm:@swc/helpers@0.5.15",
        reason: "license_incompatible",
      }),
    );
    expect(components.map((entry) => entry.identity)).toContain(
      "source:shovelerdb",
    );
    expect(components.map((entry) => entry.identity)).toContain(
      "toolchain:zig-stdlib",
    );
    expect(components.map((entry) => entry.identity)).toContain(
      "vendored:next/native-url",
    );
  });
});

describe("foundation workflow contract", () => {
  it("pins actions, separates focused/final jobs, and aggregates every result", async () => {
    const workflow = await readFile(
      path.join(root, ".github/workflows/foundation.yml"),
      "utf8",
    );
    const requiredJobs = [
      "contracts",
      "web",
      "api",
      "migration_negative",
      "persistence",
      "http_proxy",
      "runtime_license",
      "bootstrap_foundation",
      "verify_foundation_clean",
      "foundation",
    ];
    for (const job of requiredJobs)
      expect(workflow).toMatch(new RegExp(`^  ${job}:`, "m"));
    expect(workflow).toContain("run: npm run migration:negative");
    expect(workflow).toContain("run: npm run bootstrap:foundation");
    expect(workflow).toContain("run: npm run verify:foundation:clean");
    expect(workflow).toContain("node-version: 24.18.0");
    expect(workflow).toContain("NPM_VERSION: 11.16.0");
    expect(workflow).toContain("ZIG_VERSION: 0.16.0");
    expect(workflow).toContain("submodules: recursive");
    const uses = workflow
      .split("\n")
      .filter((line) => line.trimStart().startsWith("uses:"));
    expect(uses.length).toBeGreaterThan(0);
    for (const line of uses)
      expect(line.trim()).toMatch(/^uses: [^\s@]+@[0-9a-f]{40} # v\S+$/u);
    expect(workflow).not.toMatch(/uses: [^\s@]+@v\d/u);
    expect(workflow).toContain("if: ${{ always() }}");
    expect(workflow).toContain(
      "for result in ${{ join(needs.*.result, ' ') }}",
    );

    const bootstrap = workflow.slice(
      workflow.indexOf("  bootstrap_foundation:"),
      workflow.indexOf("  verify_foundation_clean:"),
    );
    const clean = workflow.slice(
      workflow.indexOf("  verify_foundation_clean:"),
      workflow.indexOf("  foundation:"),
    );
    expect(bootstrap).not.toContain("run: npm ci");
    expect(clean).not.toContain("run: npm ci");
  });
});

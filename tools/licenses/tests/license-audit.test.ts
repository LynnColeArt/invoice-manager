import { readFile } from "node:fs/promises";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { parse } from "yaml";
import {
  auditComponents,
  auditRepository,
  discoverRuntimeComponents,
  findRepositoryRoot,
  loadPolicy,
  renderReport,
  verifyShovelerEvidence,
  type LicenseComponent,
  type LicensePolicy,
} from "../src/audit.js";

const root = findRepositoryRoot();

const policy = {
  schema: "invoice-manager.runtime-license-policy/v3",
  project_license: "GPL-3.0-only",
  distribution: {
    kind: "source-repository",
    shipped_surface: "git-tracked-source",
    deferred_packaging: [
      "container-image",
      "next-standalone",
      "zig-installed-binary",
    ],
  },
  target: { os: "linux", cpu: "x64", libc: "glibc" },
  compatible_combined_runtime: [
    "0BSD",
    "Apache-2.0",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "CC-BY-4.0",
    "GPL-3.0-only",
    "ISC",
    "LGPL-3.0-or-later",
    "MIT",
    "MIT-0",
  ],
  incompatible_combined_runtime: ["GPL-2.0-only"],
  license_selections: {},
  notice_evidence: {},
  lgpl_obligations: {},
} as unknown as LicensePolicy;

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
    evidence_digest: `sha256:${"a".repeat(64)}`,
    evidence_status: "verified",
    disposition: "pending",
    ...overrides,
  };
}

describe("GPL-3.0-only runtime license policy", () => {
  it("fails closed for GPL-2.0-only, unknown, unselected, missing Apache notice, and missing LGPL obligations", () => {
    const report = auditComponents(
      [
        component({
          identity: "npm:gpl2",
          spdx_expression: "GPL-2.0-only",
          selected_license: "GPL-2.0-only",
        }),
        component({
          identity: "npm:unknown",
          spdx_expression: "UNKNOWN",
          selected_license: null,
        }),
        component({
          identity: "npm:choice",
          spdx_expression: "MIT OR Apache-2.0",
          selected_license: null,
        }),
        component({
          identity: "npm:apache",
          spdx_expression: "Apache-2.0",
          selected_license: "Apache-2.0",
          notice_path: null,
          evidence_status: "missing",
        }),
        component({
          identity: "npm:lgpl",
          spdx_expression: "LGPL-3.0-or-later",
          selected_license: "LGPL-3.0-or-later",
        }),
      ],
      policy,
    );

    expect(report.status).toBe("blocked");
    expect(report.violations).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          component: "npm:gpl2@1.0.0",
          reason: "license_incompatible",
        }),
        expect.objectContaining({
          component: "npm:unknown@1.0.0",
          reason: "license_unknown",
        }),
        expect.objectContaining({
          component: "npm:choice@1.0.0",
          reason: "license_selection_required",
        }),
        expect.objectContaining({
          component: "npm:apache@1.0.0",
          reason: "evidence_missing",
        }),
        expect.objectContaining({
          component: "npm:lgpl@1.0.0",
          reason: "lgpl_obligations_missing",
        }),
      ]),
    );
    for (const violation of report.violations) {
      expect(violation.dependency_path).toBeTruthy();
      expect(violation.evidence).toBeTruthy();
      expect(violation.policy_reason).toBeTruthy();
    }
  });

  it("accepts Apache evidence and an explicit verified LGPL source/relink record", () => {
    const selected = structuredClone(policy) as LicensePolicy & {
      lgpl_obligations: Record<string, unknown>;
    };
    (selected.lgpl_obligations as unknown as Record<string, unknown>)[
      "npm:lgpl@1.0.0"
    ] = {
      selected_license: "LGPL-3.0-or-later",
      evidence_status: "verified",
    };
    const report = auditComponents(
      [
        component({
          identity: "npm:apache",
          spdx_expression: "Apache-2.0",
          selected_license: "Apache-2.0",
        }),
        component({
          identity: "npm:lgpl",
          spdx_expression: "LGPL-3.0-or-later",
          selected_license: "LGPL-3.0-or-later",
        }),
      ],
      selected,
    );
    expect(report.status).toBe("compatible");
  });

  it("requires explicit valid selections for OR expressions", () => {
    const selected = structuredClone(policy);
    selected.license_selections["npm:choice@1.0.0"] = "BSD-3-Clause";
    const report = auditComponents(
      [
        component({
          identity: "npm:choice",
          spdx_expression: "MIT OR Apache-2.0",
          selected_license: null,
        }),
      ],
      selected,
    );
    expect(report.violations).toContainEqual(
      expect.objectContaining({ reason: "license_selection_invalid" }),
    );
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

  it("audits the actual Linux x64 source-defined runtime closure", async () => {
    const committed = await loadPolicy(root);
    const components = await discoverRuntimeComponents(root, committed);
    const report = await auditRepository(root, committed);
    const identities = components.map(
      (entry) => `${entry.identity}@${entry.version}`,
    );

    expect(report.status).toBe("compatible");
    expect(report.project_license).toBe("GPL-3.0-only");
    expect((report as unknown as { distribution: { kind: string } }).distribution.kind).toBe(
      "source-repository",
    );
    expect(report).not.toHaveProperty("artifacts.standalone");
    expect(JSON.stringify(report)).not.toContain("bin/invoice-manager-api");
    expect(identities).toContain("project:invoice-manager@0.0.0");
    expect(identities).toContain("npm:@swc/helpers@0.5.15");
    expect(identities).toContain(
      "npm:@img/sharp-libvips-linux-x64@1.2.4",
    );
    expect(identities).toContain(
      "source:shovelerdb@20dced69738bfce08f94368b8d017cfc283747fe",
    );
    expect(identities).toContain("toolchain:zig@0.16.0");
  });

  it("verifies exact ShovelerDB commit, 43-file/source/code trees, license, notice, build, and ABI header", async () => {
    const committed = await loadPolicy(root);
    const evidence = await verifyShovelerEvidence(
      root,
      committed.source_components!.shovelerdb,
    );
    expect(evidence).toMatchObject({
      verified: true,
      source_tree_sha256:
        "681d76ebe2ab6b05b3a94c7ab86749e5c3013520adb7c84f83dabfd15b2a544c",
      code_tree_sha256:
        "1fbc377ac6b54f105af3d09a627c2a7896c68626c8b03dfbdffbbe5c3204f782",
      file_count: 43,
      license_sha256:
        "3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986",
      notice_sha256:
        "59936d400c1c13e6a7e35aa1711277e695a94c50c2472fcbc01368a11b171283",
      build_zig_sha256:
        "a69e8d470cf1db44d0469e00e7db089b6ad7ca2e62b7607c03ac964843b483cc",
      abi_header_sha256:
        "177535ee08de90ee3f68f708046f19815e283f1072102afb594f6697708f676a",
    });
  });

  it("keeps committed notice evidence repository-relative and digest-pinned", async () => {
    const committed = await loadPolicy(root);
    for (const entry of Object.values(committed.notice_evidence ?? {})) {
      expect(entry.path).not.toMatch(
        /^(?:\/|[A-Za-z]:|.*(?:^|\/)\.\.(?:\/|$))/u,
      );
      expect(entry.sha256).toMatch(/^[0-9a-f]{64}$/u);
    }
  });

  it("fails duplicate identity/version evidence conflicts closed", () => {
    const report = auditComponents(
      [
        component(),
        component({ evidence_digest: `sha256:${"b".repeat(64)}` }),
      ],
      policy,
    );
    expect(report.status).toBe("blocked");
    expect(report.violations).toContainEqual(
      expect.objectContaining({ reason: "component_evidence_conflict" }),
    );
  });
});

describe("foundation workflow contract", () => {
  it("pins actions, separates every focused/final job, and aggregates every result", async () => {
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
      "verify_foundation",
      "bootstrap_foundation",
      "verify_foundation_clean",
      "foundation",
    ];
    for (const job of requiredJobs)
      expect(workflow).toMatch(new RegExp(`^  ${job}:`, "m"));
    expect(workflow).toContain("run: npm run migration:negative");
    expect(workflow).toContain("npm run bootstrap:foundation");
    expect(workflow).toContain("npm run verify:foundation:clean");
    expect(workflow).toContain("node-version: 24.18.0");
    expect(workflow).toContain("NPM_VERSION: 11.16.0");
    expect(workflow).toContain("ZIG_VERSION: 0.16.0");
    expect(workflow).toContain("submodules: recursive");
    expect(workflow).not.toContain(".next/standalone");
    expect(workflow).not.toContain("bin/invoice-manager-api");
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

    const parsed = parse(workflow) as {
      permissions: Record<string, string>;
      jobs: Record<
        string,
        {
          env?: Record<string, string>;
          "timeout-minutes": number;
          needs?: string[];
          steps: Array<{
            "continue-on-error"?: boolean;
            env?: Record<string, string>;
            name?: string;
            run?: string;
            uses?: string;
            with?: Record<string, unknown>;
          }>;
        }
      >;
    };
    expect(parsed.permissions).toEqual({ contents: "read" });
    expect(parsed.jobs.bootstrap_foundation["timeout-minutes"]).toBe(15);
    expect(parsed.jobs.verify_foundation_clean["timeout-minutes"]).toBe(15);
    expect(parsed.jobs.foundation.needs?.sort()).toEqual(
      requiredJobs.filter((entry) => entry !== "foundation").sort(),
    );
    for (const [jobName, job] of Object.entries(parsed.jobs)) {
      for (const value of Object.values(job.env ?? {}))
        expect(
          value,
          `${jobName} job-level env cannot use the step-only runner context`,
        ).not.toMatch(/\$\{\{\s*runner\./u);
      if (jobName === "foundation") continue;
      expect(
        job.steps.find((step) => step.uses?.startsWith("actions/checkout@"))
          ?.with,
      ).toMatchObject({ submodules: "recursive", "fetch-depth": 0 });
      expect(
        job.steps.find((step) => step.uses?.startsWith("actions/setup-node@"))
          ?.with,
      ).toMatchObject({ "node-version": "24.18.0", "check-latest": false });
    }
    for (const jobName of [
      "contracts",
      "web",
      "api",
      "migration_negative",
      "persistence",
      "http_proxy",
      "runtime_license",
      "verify_foundation",
    ]) {
      expect(
        parsed.jobs[jobName].steps.filter((step) => step.run === "npm ci"),
      ).toHaveLength(1);
    }
    const licenseRuns = parsed.jobs.runtime_license.steps.flatMap(
      (step) => step.run ?? [],
    );
    expect(licenseRuns.some((run) => run.includes("tsc --noEmit"))).toBe(true);
    expect(licenseRuns.some((run) => run.includes("source-check"))).toBe(true);
    expect(licenseRuns).toContain("npm run licenses:check");
    expect(licenseRuns.join("\n")).not.toContain("--prefix");
    for (const jobName of ["bootstrap_foundation", "verify_foundation_clean"]) {
      const run = parsed.jobs[jobName].steps.at(-1)?.run ?? "";
      expect(run).toContain("process.hrtime.bigint()");
      expect(run).toContain('npm install --global "npm@${NPM_VERSION}"');
      expect(run).toContain("900");
      expect(run).toContain(
        jobName === "bootstrap_foundation"
          ? "npm run bootstrap:foundation"
          : "npm run verify:foundation:clean",
      );
    }
    const stepEnvValues = (jobName: string): string[] =>
      parsed.jobs[jobName].steps.flatMap((step) =>
        Object.values(step.env ?? {}),
      );
    expect(stepEnvValues("http_proxy")).toContain(
      "${{ runner.temp }}/playwright-http",
    );
    expect(stepEnvValues("verify_foundation")).toContain(
      "${{ runner.temp }}/playwright-aggregate",
    );
    expect(stepEnvValues("bootstrap_foundation")).toEqual(
      expect.arrayContaining([
        "${{ runner.temp }}/foundation-bootstrap-home",
        "${{ runner.temp }}/foundation-bootstrap-npm",
        "${{ runner.temp }}/foundation-bootstrap-playwright",
      ]),
    );
    expect(stepEnvValues("verify_foundation_clean")).toEqual(
      expect.arrayContaining([
        "${{ runner.temp }}/foundation-verify-home",
        "${{ runner.temp }}/foundation-verify-npm",
        "${{ runner.temp }}/foundation-verify-playwright",
      ]),
    );

    const namespaceProbe = [
      "sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0",
      'test "$(sysctl -n kernel.apparmor_restrict_unprivileged_userns)" = 0',
      "unshare --user --map-current-user --keep-caps --net sh -ceu 'ip link set lo up'",
    ].join("\n");
    const namespaceJobs: Record<string, string> = {
      http_proxy: "npm run http:smoke",
      verify_foundation: "npm run verify:foundation",
      bootstrap_foundation: "npm run bootstrap:foundation",
      verify_foundation_clean: "npm run verify:foundation:clean",
    };
    let namespaceProbeCount = 0;
    for (const [jobName, command] of Object.entries(namespaceJobs)) {
      const steps = parsed.jobs[jobName].steps;
      const probeIndex = steps.findIndex(
        (step) => step.name === "Require private network namespace support",
      );
      const commandIndex = steps.findIndex((step) =>
        (step.run ?? "").includes(command),
      );
      expect(probeIndex, `${jobName} namespace probe`).toBeGreaterThanOrEqual(0);
      expect(commandIndex, `${jobName} HTTP command`).toBeGreaterThan(probeIndex);
      const probe = steps[probeIndex];
      expect(probe.run?.trim()).toBe(namespaceProbe);
      expect(probe["continue-on-error"]).not.toBe(true);
      expect(probe.run).not.toContain("|| true");
      namespaceProbeCount += 1;
    }
    expect(namespaceProbeCount).toBe(4);
    expect(workflow.match(/name: Require private network namespace support/gu)).toHaveLength(
      4,
    );
  });
});

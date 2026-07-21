import {
  auditRepository,
  findRepositoryRoot,
  loadPolicy,
  renderReport,
  verifyShovelerEvidence,
} from "./audit.js";

const root = findRepositoryRoot();

export async function run(argv: string[]): Promise<number> {
  const command = argv[0] ?? "help";
  if (command === "help" || command === "--help" || command === "-h") {
    process.stdout.write(
      "Usage: tsx tools/licenses/src/main.ts <check|report|source-check>\n",
    );
    return 0;
  }
  if (!["check", "report", "source-check"].includes(command) || argv.length !== 1) {
    process.stderr.write(
      "[license:error] usage requires exactly one supported command\n",
    );
    return 2;
  }

  try {
    const policy = await loadPolicy(root);
    if (command === "source-check") {
      const evidence = await verifyShovelerEvidence(
        root,
        policy.source_components.shovelerdb,
      );
      process.stdout.write(JSON.stringify(evidence) + "\n");
      if (!evidence.verified) {
        process.stderr.write(
          "[license:error] exact ShovelerDB GPL-3.0-only provenance/tree/license/notice evidence mismatch\n",
        );
        return 3;
      }
      process.stderr.write(
        "[license:ok] exact ShovelerDB GPL-3.0-only provenance/tree/license/notice evidence verified\n",
      );
      return 0;
    }

    const first = renderReport(await auditRepository(root, policy));
    const second = renderReport(await auditRepository(root, policy));
    if (first !== second) {
      process.stderr.write(
        "[license:error] deterministic report mismatch for unchanged committed inputs\n",
      );
      return 3;
    }
    process.stdout.write(first);
    if (command === "report") return 0;
    const report = JSON.parse(first) as {
      status: string;
      violations: Array<{
        component: string;
        reason: string;
        dependency_path: string;
        evidence: string;
        policy_reason: string;
      }>;
    };
    if (report.status !== "compatible") {
      for (const entry of report.violations) {
        process.stderr.write(
          "[license:error] component=" +
            entry.component +
            " reason=" +
            entry.reason +
            " dependency_path=" +
            JSON.stringify(entry.dependency_path) +
            " evidence=" +
            JSON.stringify(entry.evidence) +
            " policy=" +
            JSON.stringify(entry.policy_reason) +
            "\n",
        );
      }
      return 3;
    }
    process.stderr.write(
      "[license:ok] deterministic GPL-3.0-only source-defined runtime closure is compatible\n",
    );
    return 0;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(
      "[license:error] " + message.replaceAll(root, "<repository>") + "\n",
    );
    return 3;
  }
}

void run(process.argv.slice(2)).then((status) => {
  process.exitCode = status;
});

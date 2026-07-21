import {
  auditComponents,
  discoverRuntimeComponents,
  findRepositoryRoot,
  loadPolicy,
  renderReport,
} from "./audit.js";

const root = findRepositoryRoot();

export async function run(argv: string[]): Promise<number> {
  const command = argv[0] ?? "help";
  if (command === "help" || command === "--help" || command === "-h") {
    process.stdout.write(
      "Usage: tsx tools/licenses/src/main.ts <check|report>\n",
    );
    return 0;
  }
  if ((command !== "check" && command !== "report") || argv.length !== 1) {
    process.stderr.write(
      "[license:error] usage requires exactly one check or report command\n",
    );
    return 2;
  }
  try {
    const policy = await loadPolicy(root);
    const first = renderReport(
      auditComponents(await discoverRuntimeComponents(root, policy), policy),
    );
    const second = renderReport(
      auditComponents(await discoverRuntimeComponents(root, policy), policy),
    );
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
          `[license:error] component=${entry.component} reason=${entry.reason} dependency_path=${JSON.stringify(entry.dependency_path)} evidence=${JSON.stringify(entry.evidence)} policy=${JSON.stringify(entry.policy_reason)}\n`,
        );
      }
      return 3;
    }
    process.stderr.write(
      "[license:ok] deterministic GPL-2.0-only runtime closure is compatible\n",
    );
    return 0;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(
      `[license:error] ${message.replaceAll(root, "<repository>")}\n`,
    );
    return 3;
  }
}

void run(process.argv.slice(2)).then((status) => {
  process.exitCode = status;
});

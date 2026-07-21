import { execFile } from "node:child_process";
import { mkdir, rm } from "node:fs/promises";
import { promisify } from "node:util";
import {
  auditRepository,
  findRepositoryRoot,
  hydrateArtifactPolicy,
  loadPolicy,
  renderReport,
  stageRuntimeNotices,
  verifyShovelerEvidence,
} from "./audit.js";

const root = findRepositoryRoot();
const execFileAsync = promisify(execFile);

function sanitized(value: string): string {
  let result = value.replaceAll(root, "<repository>");
  if (process.env.HOME) result = result.replaceAll(process.env.HOME, "<home>");
  return result;
}

async function producer(
  executable: string,
  args: string[],
  label: string,
): Promise<void> {
  try {
    const { stdout, stderr } = await execFileAsync(executable, args, {
      cwd: root,
      encoding: "utf8",
      maxBuffer: 64 * 1024 * 1024,
    });
    for (const output of [stdout, stderr]) {
      if (output) process.stderr.write(sanitized(output));
    }
  } catch (error) {
    const cause = error as NodeJS.ErrnoException & {
      stdout?: string;
      stderr?: string;
    };
    for (const output of [cause.stdout, cause.stderr]) {
      if (output) process.stderr.write(sanitized(output));
    }
    throw new Error(`[license:producer] ${label} failed`);
  }
}

async function prepareArtifacts(): Promise<void> {
  await producer(
    "npm",
    ["run", "contracts:generate"],
    "contract materialization",
  );
  await producer(
    "npm",
    ["run", "build", "--workspace", "@invoice-manager/web"],
    "Next standalone build",
  );
  const zigRoot = "tools/licenses/.runtime/zig";
  await rm(`${root}/${zigRoot}`, { force: true, recursive: true });
  await mkdir(`${root}/${zigRoot}`, { recursive: true });
  await producer(
    "zig",
    [
      "build",
      "--build-file",
      "services/api/build.zig",
      "-Doptimize=ReleaseSafe",
      "--prefix",
      zigRoot,
    ],
    "Zig release install",
  );
  await stageRuntimeNotices(
    root,
    await hydrateArtifactPolicy(root, await loadPolicy(root)),
  );
}

export async function run(argv: string[]): Promise<number> {
  const command = argv[0] ?? "help";
  if (command === "help" || command === "--help" || command === "-h") {
    process.stdout.write(
      "Usage: tsx tools/licenses/src/main.ts <check|report|check-existing|report-existing|source-check>\n",
    );
    return 0;
  }
  if (
    ![
      "check",
      "report",
      "check-existing",
      "report-existing",
      "source-check",
    ].includes(command) ||
    argv.length !== 1
  ) {
    process.stderr.write(
      "[license:error] usage requires exactly one supported command\n",
    );
    return 2;
  }
  try {
    if (command === "source-check") {
      const policy = await loadPolicy(root);
      if (!policy.source_components)
        throw new Error("[license:policy] source component policy is missing");
      const evidence = await verifyShovelerEvidence(
        root,
        policy.source_components.shovelerdb,
      );
      process.stdout.write(`${JSON.stringify(evidence)}\n`);
      if (!evidence.verified) {
        process.stderr.write(
          "[license:error] exact ShovelerDB provenance/tree/license/notice evidence mismatch\n",
        );
        return 3;
      }
      process.stderr.write(
        "[license:ok] exact ShovelerDB provenance/tree/license/notice evidence verified\n",
      );
      return 0;
    }
    if (command === "check" || command === "report") await prepareArtifacts();
    const policy = await hydrateArtifactPolicy(root, await loadPolicy(root));
    const first = renderReport(await auditRepository(root, policy));
    const second = renderReport(await auditRepository(root, policy));
    if (first !== second) {
      process.stderr.write(
        "[license:error] deterministic report mismatch for unchanged committed inputs\n",
      );
      return 3;
    }
    process.stdout.write(first);
    if (command === "report" || command === "report-existing") return 0;
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

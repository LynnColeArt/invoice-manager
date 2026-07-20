import { link, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { asContractError, fail } from "./errors.js";
import { readConformanceLock, type ConformancePin } from "./conformance.js";
import { buildValidatedBaselineRefreshCandidate, checkContracts, generateContracts } from "./generate.js";
import { parseJsonBytes, stableJson } from "./json.js";
import { normalizeRepositoryPath, readRepositoryBytes, resolveRepositoryWritePath } from "./paths.js";

export const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");

export const helpText = `Invoice Manager contract tool

Usage:
  tsx tools/contracts/src/main.ts generate
  tsx tools/contracts/src/main.ts check
  tsx tools/contracts/src/main.ts baseline-refresh --replacements <json> --candidate <json>

Inputs:
  contracts/api, events, modules, manifests, migrations, conformance, and fixtures
  exact full-commit P1-P4 pins in contracts/conformance/p0-p4-inputs.json

Outputs (generate only; fixed destinations):
  tools/contracts/.generated/typescript/v1/
  tools/contracts/.generated/runtime/v1/route-inventory.json

Check mode invokes the literal root contracts:generate command twice, compares exact
diagnostics and bytes, then validates schemas, lifecycle evidence, references, access
policy, collision preflight, migrations, generated types, and fixtures.

Exit meanings:
  0 success or help
  2 usage error
  3 validation, collision, immutable-pin, mutation, or determinism failure
`;

function option(args: string[], name: string): string {
  const index = args.indexOf(name);
  if (index === -1 || index + 1 >= args.length || args[index + 1].startsWith("--")) fail("cli_option_missing", "", `Missing ${name}`);
  return args[index + 1];
}

async function baselineRefresh(args: string[]): Promise<void> {
  const replacementsPath = normalizeRepositoryPath(option(args, "--replacements"), "");
  const candidatePath = normalizeRepositoryPath(option(args, "--candidate"), "");
  if (!candidatePath.startsWith("contracts/conformance/") || !candidatePath.endsWith(".candidate.json")) {
    fail("conformance_candidate_destination_invalid", "", "Baseline refresh writes only an explicit contracts/conformance/*.candidate.json file");
  }
  const replacements = parseJsonBytes(await readRepositoryBytes(repositoryRoot, replacementsPath, ""));
  if (!Array.isArray(replacements)) fail("conformance_replacements_invalid", "", "Replacement input must be a JSON array");
  const current = await readConformanceLock(repositoryRoot);
  const candidate = await buildValidatedBaselineRefreshCandidate(repositoryRoot, current, replacements as unknown as ConformancePin[]);
  const destination = await resolveRepositoryWritePath(repositoryRoot, candidatePath, "");
  const temporary = `${destination}.tmp`;
  await writeFile(temporary, stableJson(candidate), { encoding: "utf8", flag: "wx" });
  try {
    await link(temporary, destination);
    await rm(temporary);
  } catch (error) {
    await rm(temporary, { force: true });
    throw error;
  }
  process.stdout.write(`[contracts:baseline-refresh] candidate=${candidatePath} changes=${candidate.changes.length}\n`);
}

export async function run(argv: string[]): Promise<number> {
  const command = argv[0] ?? "help";
  if (command === "help" || command === "--help" || command === "-h") {
    process.stdout.write(helpText);
    return 0;
  }
  try {
    if (command === "generate") {
      if (argv.length !== 1) fail("generated_destination_override_forbidden", "", "Generation destinations are fixed and accept no overrides");
      const result = await generateContracts(repositoryRoot);
      process.stdout.write(`[contracts:generate] modules=${result.composition.modules.length} routes=${result.composition.routes.length} conformance=${result.conformance.length}\n`);
      return 0;
    }
    if (command === "check") {
      if (argv.length !== 1) fail("cli_usage_invalid", "", "Check accepts no additional arguments");
      const result = await checkContracts(repositoryRoot);
      process.stdout.write(`[contracts:check] modules=${result.composition.modules.length} routes=${result.composition.routes.length} conformance=${result.conformance.length}\n`);
      return 0;
    }
    if (command === "baseline-refresh") {
      await baselineRefresh(argv.slice(1));
      return 0;
    }
    process.stderr.write(`${JSON.stringify({ code: "cli_usage_invalid", pointer: "", message: "Unknown command" })}\n`);
    process.stderr.write(helpText);
    return 2;
  } catch (error) {
    const diagnostic = asContractError(error).diagnostic();
    process.stderr.write(`${JSON.stringify(diagnostic)}\n`);
    return 3;
  }
}

const entry = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : "";
if (entry === import.meta.url) process.exitCode = await run(process.argv.slice(2));

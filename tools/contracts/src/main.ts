import { link, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { asContractError, fail } from "./errors.js";
import { readConformanceLock, type ConformancePin } from "./conformance.js";
import { buildValidatedBaselineRefreshCandidate, checkContracts, generateContracts } from "./generate.js";
import { parseJsonBytes, stableJson } from "./json.js";
import { normalizeRepositoryPath, readRepositoryBytes, resolveRepositoryWritePath } from "./paths.js";
import { checkCanonicalP0, freezeP0, implementP0, verifyP0 } from "./p0-lifecycle.js";

export const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");

export const helpText = `Invoice Manager contract tool

Usage:
  tsx tools/contracts/src/main.ts generate
  tsx tools/contracts/src/main.ts check
  tsx tools/contracts/src/main.ts baseline-refresh --replacements <json> --candidate <json>
  tsx tools/contracts/src/main.ts p0-freeze --expected-draft-sha256 <64hex>
  tsx tools/contracts/src/main.ts p0-implement --expected-manifest-sha256 <64hex>
  tsx tools/contracts/src/main.ts p0-verify --expected-manifest-sha256 <64hex> --accepted-wp11-receipt-commit <40hex> --closure-evidence -
  tsx tools/contracts/src/main.ts p0-check

Inputs:
  contracts/api, events, modules, manifests, migrations, conformance, and fixtures
  exact full-commit P1-P4 pins in contracts/conformance/p0-p4-inputs.json

Outputs (generate only; fixed destinations):
  tools/contracts/.generated/typescript/v1/
  tools/contracts/.generated/runtime/v1/route-inventory.json

Lifecycle output (fixed destination):
  contracts/manifests/p0.json

Check mode invokes the literal root contracts:generate command twice, compares exact
diagnostics and bytes, then validates schemas, lifecycle evidence, references, access
policy, collision preflight, migrations, generated types, and fixtures.

Exit meanings:
  0 success or help
  2 usage error
  3 validation, collision, immutable-pin, mutation, or determinism failure
`;

function exactArguments(args: string[], expected: string[]): void {
  if (args.length !== expected.length || args.some((value, index) => index % 2 === 0 && value !== expected[index])) {
    fail("cli_usage_invalid", "", "P0 lifecycle command arguments do not match the fixed interface");
  }
}

async function stdinBytes(): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  return Buffer.concat(chunks);
}

function option(args: string[], name: string): string {
  const index = args.indexOf(name);
  if (index === -1 || index + 1 >= args.length || args[index + 1].startsWith("--")) fail("cli_option_missing", "", `Missing ${name}`);
  return args[index + 1];
}

async function baselineRefresh(root: string, args: string[]): Promise<void> {
  const replacementsPath = normalizeRepositoryPath(option(args, "--replacements"), "");
  const candidatePath = normalizeRepositoryPath(option(args, "--candidate"), "");
  if (!candidatePath.startsWith("contracts/conformance/") || !candidatePath.endsWith(".candidate.json")) {
    fail("conformance_candidate_destination_invalid", "", "Baseline refresh writes only an explicit contracts/conformance/*.candidate.json file");
  }
  const replacements = parseJsonBytes(await readRepositoryBytes(root, replacementsPath, ""));
  if (!Array.isArray(replacements)) fail("conformance_replacements_invalid", "", "Replacement input must be a JSON array");
  const current = await readConformanceLock(root);
  const candidate = await buildValidatedBaselineRefreshCandidate(root, current, replacements as unknown as ConformancePin[]);
  const destination = await resolveRepositoryWritePath(root, candidatePath, "");
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

export async function run(argv: string[], root = repositoryRoot): Promise<number> {
  const command = argv[0] ?? "help";
  if (command === "help" || command === "--help" || command === "-h") {
    process.stdout.write(helpText);
    return 0;
  }
  try {
    if (command === "generate") {
      if (argv.length !== 1) fail("generated_destination_override_forbidden", "", "Generation destinations are fixed and accept no overrides");
      const result = await generateContracts(root);
      process.stdout.write(`[contracts:generate] modules=${result.composition.modules.length} routes=${result.composition.routes.length} conformance=${result.conformance.length}\n`);
      return 0;
    }
    if (command === "check") {
      if (argv.length !== 1) fail("cli_usage_invalid", "", "Check accepts no additional arguments");
      const result = await checkContracts(root);
      process.stdout.write(`[contracts:check] modules=${result.composition.modules.length} routes=${result.composition.routes.length} conformance=${result.conformance.length}\n`);
      return 0;
    }
    if (command === "baseline-refresh") {
      await baselineRefresh(root, argv.slice(1));
      return 0;
    }
    if (command === "p0-freeze") {
      const args = argv.slice(1);
      exactArguments(args, ["--expected-draft-sha256", ""]);
      process.stdout.write(stableJson(await freezeP0(root, args[1])));
      return 0;
    }
    if (command === "p0-implement") {
      const args = argv.slice(1);
      exactArguments(args, ["--expected-manifest-sha256", ""]);
      process.stdout.write(stableJson(await implementP0(root, args[1])));
      return 0;
    }
    if (command === "p0-verify") {
      const args = argv.slice(1);
      exactArguments(args, ["--expected-manifest-sha256", "", "--accepted-wp11-receipt-commit", "", "--closure-evidence", ""]);
      if (args[5] !== "-") fail("cli_usage_invalid", "", "Closure evidence must be read from standard input");
      const evidence = parseJsonBytes(await stdinBytes());
      process.stdout.write(stableJson(await verifyP0(root, args[1], evidence, args[3])));
      return 0;
    }
    if (command === "p0-check") {
      if (argv.length !== 1) fail("cli_usage_invalid", "", "p0-check accepts no arguments");
      const manifest = await checkCanonicalP0(root);
      process.stdout.write(stableJson({ command: "p0-check", state: manifest.state, content_digest: manifest.content_digest }));
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

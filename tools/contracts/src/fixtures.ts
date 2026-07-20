import { ContractError, fail } from "./errors.js";
import { parseJsonBytes } from "./json.js";
import { type ContractManifest, validateLifecycleManifest } from "./lifecycle.js";
import { type ModuleContribution, validateModuleSet } from "./modules.js";
import { readRepositoryBytes } from "./paths.js";

type ExpectedFailure = { code: string; pointer: string };

function object(value: unknown): Record<string, unknown> {
  if (value === null || Array.isArray(value) || typeof value !== "object") fail("fixture_shape_invalid", "", "Fixture must be an object");
  return value as Record<string, unknown>;
}

function assertExpectedFailure(error: unknown, expected: ExpectedFailure): void {
  if (!(error instanceof ContractError)) throw error;
  if (error.code !== expected.code || error.pointer !== expected.pointer) {
    fail("fixture_expected_failure_mismatch", "/expected", `Expected ${expected.code} at ${expected.pointer}; observed ${error.code} at ${error.pointer}`);
  }
}

export async function validateCanonicalFixtures(root: string): Promise<void> {
  const load = async (relative: string): Promise<unknown> => parseJsonBytes(await readRepositoryBytes(root, relative, ""));
  const validModule = object(await load("contracts/fixtures/p0/v1/valid/module-pair.json"));
  validateModuleSet(validModule.modules as ModuleContribution[]);

  const invalidModule = object(await load("contracts/fixtures/p0/v1/invalid/module-duplicate-mount.json"));
  try {
    validateModuleSet(invalidModule.modules as ModuleContribution[]);
    fail("fixture_expected_failure_missing", "/expected", "Invalid module fixture was accepted");
  } catch (error) {
    assertExpectedFailure(error, invalidModule.expected as ExpectedFailure);
  }

  const validLifecycle = await load("contracts/fixtures/p0/v1/valid/lifecycle-draft.json");
  await validateLifecycleManifest(root, validLifecycle as unknown as ContractManifest);

  const invalidLifecycle = object(await load("contracts/fixtures/p0/v1/invalid/lifecycle-frozen-pending-digest.json"));
  try {
    await validateLifecycleManifest(root, invalidLifecycle.manifest as ContractManifest);
    fail("fixture_expected_failure_missing", "/expected", "Invalid lifecycle fixture was accepted");
  } catch (error) {
    assertExpectedFailure(error, invalidLifecycle.expected as ExpectedFailure);
  }
}

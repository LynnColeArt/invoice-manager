import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { ContractError } from "../src/errors.js";
import {
  assertLifecycleTransition,
  computeContentDigest,
  type ContractManifest,
  validateLifecycleManifest,
} from "../src/lifecycle.js";
import { sha256Digest } from "../src/json.js";

const roots: string[] = [];
afterEach(async () => Promise.all(roots.splice(0).map((root) => rm(root, { recursive: true, force: true }))));

function draft(overrides: Partial<ContractManifest> = {}): ContractManifest {
  return {
    manifest_version: 1,
    contract_id: "invoice-manager.synthetic",
    owner_mission: "p8",
    mission: "p8-synthetic-contract-01KXYZAB",
    version: "0.1.0-draft.1",
    state: "Draft",
    baseline_commit: "a71448bbec991a6bf0be805129d704beab06d486",
    content_digest: "pending",
    dependencies: [],
    inputs: [],
    outputs: [{ path: "outputs/value.json", kind: "other", digest: "pending" }],
    owned_paths: ["outputs/**"],
    shared_touchpoints: [],
    migration_strategy: { mode: "none" },
    integration_fixtures: [
      { path: "fixtures/invalid.json", expectation: "invalid", digest: "pending" },
      { path: "fixtures/valid.json", expectation: "valid", digest: "pending" },
    ],
    ...overrides,
  };
}

function expectContractError(action: () => unknown | Promise<unknown>, code: string, pointer: string): Promise<void> {
  return Promise.resolve()
    .then(action)
    .then(() => { throw new Error("Expected ContractError"); })
    .catch((error: unknown) => {
      expect(error).toBeInstanceOf(ContractError);
      expect(error).toMatchObject({ code, pointer });
    });
}

async function frozenFixture(): Promise<{ root: string; manifest: ContractManifest }> {
  const root = await mkdtemp(path.join(os.tmpdir(), "invoice-manager-lifecycle-"));
  roots.push(root);
  await Promise.all(["outputs", "fixtures"].map((directory) => mkdir(path.join(root, directory), { recursive: true })));
  const files = {
    "outputs/value.json": Buffer.from('{"value":"synthetic"}\n'),
    "fixtures/valid.json": Buffer.from('{"case":"valid"}\n'),
    "fixtures/invalid.json": Buffer.from('{"case":"invalid"}\n'),
  };
  await Promise.all(Object.entries(files).map(([relative, bytes]) => writeFile(path.join(root, relative), bytes)));
  const manifest = draft({
    state: "Frozen",
    outputs: [{ path: "outputs/value.json", kind: "other", digest: sha256Digest(files["outputs/value.json"]) }],
    integration_fixtures: [
      { path: "fixtures/invalid.json", expectation: "invalid", digest: sha256Digest(files["fixtures/invalid.json"]) },
      { path: "fixtures/valid.json", expectation: "valid", digest: sha256Digest(files["fixtures/valid.json"]) },
    ],
  });
  manifest.content_digest = computeContentDigest(manifest);
  return { root, manifest };
}

describe("contract lifecycle gate", () => {
  it("permits only the specified forward and terminal transitions", () => {
    for (const [from, to] of [
      ["Draft", "Frozen"], ["Draft", "Superseded"], ["Frozen", "Implemented"],
      ["Frozen", "Superseded"], ["Implemented", "Verified"], ["Implemented", "Superseded"],
      ["Verified", "Superseded"],
    ] as const) expect(() => assertLifecycleTransition(from, to)).not.toThrow();
    for (const [from, to] of [
      ["Draft", "Implemented"], ["Frozen", "Verified"], ["Implemented", "Frozen"],
      ["Verified", "Implemented"], ["Superseded", "Draft"],
    ] as const) expect(() => assertLifecycleTransition(from, to)).toThrowError(ContractError);
  });

  it("accepts pending evidence in Draft and rejects it in Frozen", async () => {
    await expect(validateLifecycleManifest(process.cwd(), draft())).resolves.toBeUndefined();
    await expectContractError(
      () => validateLifecycleManifest(process.cwd(), draft({ state: "Frozen" })),
      "lifecycle_pending_evidence",
      "/content_digest",
    );
  });

  it("verifies every concrete Draft digest and declared file while pending remains optional", async () => {
    const { root, manifest: frozen } = await frozenFixture();
    const concreteDraft = { ...structuredClone(frozen), state: "Draft" as const };
    concreteDraft.content_digest = computeContentDigest(concreteDraft);
    await expect(validateLifecycleManifest(root, concreteDraft)).resolves.toBeUndefined();

    const wrongContent = { ...structuredClone(concreteDraft), content_digest: `sha256:${"0".repeat(64)}` };
    await expectContractError(() => validateLifecycleManifest(root, wrongContent), "content_digest_mismatch", "/content_digest");

    const wrongFile = structuredClone(concreteDraft);
    wrongFile.outputs[0].digest = `sha256:${"0".repeat(64)}`;
    wrongFile.content_digest = computeContentDigest(wrongFile);
    await expectContractError(() => validateLifecycleManifest(root, wrongFile), "file_digest_mismatch", "/outputs/0/digest");

    const missingFile = structuredClone(concreteDraft);
    missingFile.outputs[0].path = "outputs/missing.json";
    missingFile.content_digest = computeContentDigest(missingFile);
    await expectContractError(() => validateLifecycleManifest(root, missingFile), "path_missing", "/outputs/0/path");

    const invalidSentinel = { ...structuredClone(concreteDraft), content_digest: "PENDING" };
    await expectContractError(() => validateLifecycleManifest(root, invalidSentinel), "digest_invalid", "/content_digest");
  });

  it("derives a key-order-independent RFC 8785 identity and excludes lifecycle fields", () => {
    const first = draft();
    const reordered: ContractManifest = {
      integration_fixtures: first.integration_fixtures.map((entry) => ({ digest: entry.digest, expectation: entry.expectation, path: entry.path })),
      migration_strategy: first.migration_strategy,
      shared_touchpoints: first.shared_touchpoints,
      owned_paths: first.owned_paths,
      outputs: first.outputs.map((entry) => ({ digest: entry.digest, kind: entry.kind, path: entry.path })),
      inputs: first.inputs.map((entry) => ({ content_digest: entry.content_digest, required_state: entry.required_state, version: entry.version, owner_mission: entry.owner_mission, contract_id: entry.contract_id })),
      dependencies: first.dependencies,
      content_digest: first.content_digest,
      baseline_commit: first.baseline_commit,
      state: first.state,
      version: first.version,
      mission: first.mission,
      owner_mission: first.owner_mission,
      contract_id: first.contract_id,
      manifest_version: first.manifest_version,
    };
    const implemented = { ...first, state: "Implemented" as const, baseline_commit: "f".repeat(40), content_digest: "sha256:" + "0".repeat(64) };
    expect(computeContentDigest(first)).toBe(computeContentDigest(reordered));
    expect(computeContentDigest(first)).toBe(computeContentDigest(implemented));
  });

  it("verifies concrete files and preserves content identity through Implemented", async () => {
    const { root, manifest } = await frozenFixture();
    await expect(validateLifecycleManifest(root, manifest)).resolves.toBeUndefined();
    const implemented = { ...structuredClone(manifest), state: "Implemented" as const };
    await expect(validateLifecycleManifest(root, implemented, { previous: manifest })).resolves.toBeUndefined();
    await writeFile(path.join(root, "outputs/value.json"), '{"value":"mutated"}\n');
    await expectContractError(() => validateLifecycleManifest(root, implemented, { previous: manifest }), "file_digest_mismatch", "/outputs/0/digest");
  });

  it("rejects dependency/input mismatch and each unsafe path class without writes", async () => {
    const cases: Array<[ContractManifest, string, string]> = [
      [draft({ dependencies: ["p1"] }), "dependency_input_missing", "/dependencies/0"],
      [draft({ inputs: [{ contract_id: "invoice-manager.one", owner_mission: "p1", version: "1.0.0", required_state: "Frozen", content_digest: "pending" }] }), "input_owner_undeclared", "/inputs/0/owner_mission"],
      [draft({ outputs: [{ path: "/absolute.json", digest: "pending" }] }), "path_absolute", "/outputs/0/path"],
      [draft({ outputs: [{ path: "../escape.json", digest: "pending" }] }), "path_traversal", "/outputs/0/path"],
      [draft({ outputs: [{ path: "double//slash.json", digest: "pending" }] }), "path_not_normalized", "/outputs/0/path"],
      [draft({ outputs: [{ path: "windows\\path.json", digest: "pending" }] }), "path_not_slash_separated", "/outputs/0/path"],
      [draft({ outputs: [{ path: "same.json", digest: "pending" }, { path: "same.json", digest: "pending" }] }), "path_duplicate", "/outputs/1/path"],
    ];
    for (const [manifest, code, pointer] of cases) await expectContractError(() => validateLifecycleManifest(process.cwd(), manifest), code, pointer);
  });
});

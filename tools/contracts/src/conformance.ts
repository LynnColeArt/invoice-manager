import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fail } from "./errors.js";
import { computeContentDigest, type ContractManifest, validateLifecycleManifest } from "./lifecycle.js";
import { parseJson, sha256Hex, stableJson } from "./json.js";
import { normalizeRepositoryPath } from "./paths.js";
import { type StableIdRegistry, isJsonObject } from "./registry.js";

const execFileAsync = promisify(execFile);

export type ConformancePin = {
  owner_mission: string;
  contract_id: string;
  version: string;
  manifest_path: string;
  commit: string;
  manifest_sha256: string;
  content_digest: string;
};
export type ConformanceLock = { format_version: number; inputs: ConformancePin[] };
export type VerifiedConformance = { pin: ConformancePin; manifest: ContractManifest; manifestBytes: Buffer };

const exactP0Pins: Readonly<Record<string, Pick<ConformancePin, "commit" | "manifest_sha256" | "content_digest">>> = {
  p1: { commit: "47638a9d95427697c1fcc74c7279f40f314450f5", manifest_sha256: "3f28ddb033e5259163671b34c8c64f6214c5524f0f941e4dc5d03c38485a7987", content_digest: "73457636636187ff5537564a0f13ed29030d931746dbcc2740da3636cb2747f5" },
  p2: { commit: "8830e8bbdfb1a7ecb92015359aa28c58d9f2b078", manifest_sha256: "24bf9f15fad1d598fae394e5ec40e7a50e6f166e7bd1202e3c51c4576c89bbc7", content_digest: "c12f5c79c21689f146c705cef5b454bca684e5e86e0ac7a326df8dc7db1f9a70" },
  p3: { commit: "1a83ce0523ccc793c62d7bcd3b6992eb761ec506", manifest_sha256: "1b2013f7876a0015af7a18ed9bdc89675520c7dcf0c68f98253357af5c96c11f", content_digest: "48d85d152ab9e46efd052c4e3b02dba47a8e6bbfeac8315864cc6d470d274bf3" },
  p4: { commit: "860ee50cd959e75391753cafe841b4da82882a0b", manifest_sha256: "2da1496e68aa9577a91af647af34268181c9a58ff5aec529cc71121db4159a24", content_digest: "453c138255cd525587a07049a04576c9d22919979c0c2ac45ce37f46e2e54636" },
};

function compareCodeUnits(left: string, right: string): number {
  return left < right ? -1 : left > right ? 1 : 0;
}

export function assertImmutableCommit(value: string, pointer: string): void {
  if (!/^[0-9a-f]{40}$/u.test(value)) fail("conformance_moving_reference", pointer, "Conformance input must use a full lowercase 40-hex commit");
}

async function gitBytes(root: string, commit: string, relative: string, pointer: string): Promise<Buffer> {
  assertImmutableCommit(commit, pointer);
  try {
    await execFileAsync("git", ["cat-file", "-e", `${commit}^{commit}`], { cwd: root, encoding: "buffer", maxBuffer: 1024 * 1024 });
  } catch {
    fail("conformance_commit_unavailable", pointer, "Pinned commit is unavailable in this clone");
  }
  try {
    const { stdout } = await execFileAsync("git", ["show", `${commit}:${relative}`], { cwd: root, encoding: "buffer", maxBuffer: 16 * 1024 * 1024 });
    return Buffer.from(stdout);
  } catch {
    fail("conformance_manifest_unavailable", pointer, "Pinned repository path is unavailable at the exact commit");
  }
}

export async function readConformanceLock(root: string): Promise<ConformanceLock> {
  const value = parseJson(await readFile(path.join(root, "contracts/conformance/p0-p4-inputs.json"), "utf8"));
  if (!isJsonObject(value) || value.format_version !== 1 || !Array.isArray(value.inputs)) fail("conformance_lock_invalid", "", "Conformance lock has an invalid shape");
  return value as unknown as ConformanceLock;
}

function validateLockShape(lock: ConformanceLock, exactBaseline: boolean): void {
  if (lock.format_version !== 1) fail("conformance_lock_version_invalid", "/format_version", "Conformance lock version must be 1");
  if (lock.inputs.length !== 4) fail("conformance_owner_set_invalid", "/inputs", "Conformance lock must contain exactly P1 through P4");
  const expectedOwners = ["p1", "p2", "p3", "p4"];
  lock.inputs.forEach((pin, index) => {
    if (pin.owner_mission !== expectedOwners[index]) fail("conformance_owner_order_invalid", `/inputs/${index}/owner_mission`, "Conformance inputs must be canonically sorted P1 through P4");
    assertImmutableCommit(pin.commit, `/inputs/${index}/commit`);
    normalizeRepositoryPath(pin.manifest_path, `/inputs/${index}/manifest_path`);
    if (!/^[0-9a-f]{64}$/u.test(pin.manifest_sha256)) fail("conformance_manifest_digest_invalid", `/inputs/${index}/manifest_sha256`, "Manifest byte digest must be 64 lowercase hex characters");
    if (!/^[0-9a-f]{64}$/u.test(pin.content_digest)) fail("conformance_content_digest_invalid", `/inputs/${index}/content_digest`, "Content digest must be 64 lowercase hex characters");
    if (exactBaseline) {
      const exact = exactP0Pins[pin.owner_mission];
      if (!exact || exact.commit !== pin.commit || exact.manifest_sha256 !== pin.manifest_sha256 || exact.content_digest !== pin.content_digest) {
        fail("conformance_baseline_refresh_required", `/inputs/${index}`, "Pin differs from the accepted P0 baseline; use an explicit baseline refresh candidate");
      }
    }
  });
}

export async function verifyConformanceLock(
  root: string,
  registry: StableIdRegistry,
  lock: ConformanceLock,
  options: { exactBaseline?: boolean } = {},
): Promise<VerifiedConformance[]> {
  validateLockShape(lock, options.exactBaseline !== false);
  const results: VerifiedConformance[] = [];
  for (const [index, pin] of lock.inputs.entries()) {
    const bytes = await gitBytes(root, pin.commit, pin.manifest_path, `/inputs/${index}/commit`);
    if (sha256Hex(bytes) !== pin.manifest_sha256) fail("conformance_manifest_digest_mismatch", `/inputs/${index}/manifest_sha256`, "Pinned manifest byte digest differs");
    const value = parseJson(bytes.toString("utf8"), `/inputs/${index}`);
    if (!isJsonObject(value)) fail("conformance_manifest_invalid", `/inputs/${index}`, "Pinned manifest must be a JSON object");
    registry.validate("https://invoice-manager.invalid/contracts/manifests/v1/schema.json", value);
    const manifest = value as unknown as ContractManifest;
    if (manifest.owner_mission !== pin.owner_mission) fail("conformance_owner_mismatch", `/inputs/${index}/owner_mission`, "Pinned manifest owner differs");
    if (manifest.contract_id !== pin.contract_id) fail("conformance_contract_mismatch", `/inputs/${index}/contract_id`, "Pinned manifest contract ID differs");
    if (manifest.version !== pin.version) fail("conformance_version_mismatch", `/inputs/${index}/version`, "Pinned manifest version differs");
    const digest = computeContentDigest(manifest).slice("sha256:".length);
    if (digest !== pin.content_digest) fail("conformance_content_digest_mismatch", `/inputs/${index}/content_digest`, "Pinned RFC 8785 content digest differs");
    await validateLifecycleManifest(root, manifest);
    results.push({ pin, manifest, manifestBytes: bytes });
  }
  const p0Value = parseJson(await readFile(path.join(root, "contracts/manifests/drafts/p0.json"), "utf8"));
  if (!isJsonObject(p0Value)) fail("conformance_manifest_invalid", "/inputs", "P0 Draft manifest is invalid");
  const p0Manifest = p0Value as unknown as ContractManifest;
  const manifestsByOwner = new Map<string, ContractManifest>([["p0", p0Manifest], ...results.map(({ manifest }) => [manifest.owner_mission, manifest] as const)]);
  for (const [resultIndex, { manifest }] of results.entries()) {
    for (const [inputIndex, input] of manifest.inputs.entries()) {
      const dependency = manifestsByOwner.get(input.owner_mission);
      if (!dependency) fail("conformance_dependency_unpinned", `/inputs/${resultIndex}/manifest/inputs/${inputIndex}/owner_mission`, "Draft input owner is not present in the real P0-P4 set");
      if (dependency.contract_id !== input.contract_id) fail("conformance_dependency_contract_mismatch", `/inputs/${resultIndex}/manifest/inputs/${inputIndex}/contract_id`, "Draft input contract ID differs from its real owner manifest");
      if (dependency.version !== input.version) fail("conformance_dependency_version_mismatch", `/inputs/${resultIndex}/manifest/inputs/${inputIndex}/version`, "Draft input version differs from its real owner manifest");
      if (input.content_digest !== "pending" && dependency.content_digest !== input.content_digest) {
        fail("conformance_dependency_digest_mismatch", `/inputs/${resultIndex}/manifest/inputs/${inputIndex}/content_digest`, "Draft input content digest differs from its real owner manifest");
      }
    }
  }
  for (const [index, result] of results.entries()) {
    for (const [outputIndex, output] of result.manifest.outputs.entries()) {
      const bytes = await gitBytes(root, result.pin.commit, output.path, `/inputs/${index}/outputs/${outputIndex}/path`);
      let value: unknown;
      try {
        value = JSON.parse(bytes.toString("utf8"));
      } catch {
        continue;
      }
      if (value !== null && !Array.isArray(value) && typeof value === "object" && "$id" in value) {
        registry.add(value as Record<string, unknown>, `git:${result.pin.commit}:${output.path}`);
      }
    }
  }
  return results;
}

export type BaselineRefreshCandidate = {
  format_version: 1;
  previous_lock_sha256: string;
  changes: Array<{ owner_mission: string; old: ConformancePin; next: ConformancePin }>;
  inputs: ConformancePin[];
  validation: "all-pins-and-fixtures-revalidated";
};

export async function buildBaselineRefreshCandidate(
  root: string,
  registry: StableIdRegistry,
  current: ConformanceLock,
  replacements: ConformancePin[],
): Promise<BaselineRefreshCandidate> {
  const byOwner = new Map(replacements.map((pin) => [pin.owner_mission, pin]));
  const next: ConformanceLock = {
    format_version: 1,
    inputs: current.inputs.map((pin) => byOwner.get(pin.owner_mission) ?? pin).sort((a, b) => compareCodeUnits(a.owner_mission, b.owner_mission)),
  };
  await verifyConformanceLock(root, registry, next, { exactBaseline: false });
  const changes = current.inputs.flatMap((old) => {
    const replacement = byOwner.get(old.owner_mission);
    return replacement && stableJson(replacement) !== stableJson(old) ? [{ owner_mission: old.owner_mission, old, next: replacement }] : [];
  });
  if (changes.length === 0) fail("conformance_refresh_empty", "/changes", "Baseline refresh must record at least one changed pin");
  return {
    format_version: 1,
    previous_lock_sha256: sha256Hex(stableJson(current)),
    changes,
    inputs: next.inputs,
    validation: "all-pins-and-fixtures-revalidated",
  };
}

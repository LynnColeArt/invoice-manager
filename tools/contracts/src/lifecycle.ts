import { compareCodeUnits, jcsBytes, sha256Digest } from "./json.js";
import { fail } from "./errors.js";
import { assertUniqueNormalizedPaths, normalizeRepositoryPath, readRepositoryBytes } from "./paths.js";

export const lifecycleStates = ["Draft", "Frozen", "Implemented", "Verified", "Superseded"] as const;
export type LifecycleState = (typeof lifecycleStates)[number];

export type ContractInput = {
  contract_id: string;
  owner_mission: string;
  version: string;
  required_state: Exclude<LifecycleState, "Draft" | "Superseded">;
  content_digest: string;
};
export type DigestedPath = { path: string; digest: string; [key: string]: unknown };
export type ContractManifest = {
  manifest_version: number;
  contract_id: string;
  owner_mission: string;
  mission: string;
  version: string;
  state: LifecycleState;
  baseline_commit: string;
  content_digest: string;
  dependencies: string[];
  inputs: ContractInput[];
  outputs: DigestedPath[];
  owned_paths: string[];
  shared_touchpoints: Array<{ path: string; steward: string; reason: string }>;
  migration_strategy: { mode: string; root?: string };
  integration_fixtures: Array<DigestedPath & { expectation: "valid" | "invalid" }>;
};

const legalTransitions: Record<LifecycleState, readonly LifecycleState[]> = {
  Draft: ["Frozen", "Superseded"],
  Frozen: ["Implemented", "Superseded"],
  Implemented: ["Verified", "Superseded"],
  Verified: ["Superseded"],
  Superseded: [],
};

export function assertLifecycleTransition(from: LifecycleState, to: LifecycleState): void {
  if (from === to) return;
  if (!legalTransitions[from].includes(to)) {
    fail("lifecycle_transition_forbidden", "/state", `Transition ${from} -> ${to} is not permitted`);
  }
}

function sortedBy<T>(items: T[], identity: (item: T) => string): T[] {
  return [...items].sort((left, right) => compareCodeUnits(identity(left), identity(right)));
}

export function contentProjection(manifest: ContractManifest): unknown {
  return {
    contract_id: manifest.contract_id,
    version: manifest.version,
    inputs: sortedBy(manifest.inputs, (entry) => `${entry.contract_id}\0${entry.owner_mission}\0${entry.version}`),
    outputs: sortedBy(manifest.outputs, (entry) => entry.path),
    fixtures: sortedBy(manifest.integration_fixtures, (entry) => entry.path),
  };
}

export function computeContentDigest(manifest: ContractManifest): string {
  return sha256Digest(jcsBytes(contentProjection(manifest)));
}

function assertEvidence(manifest: ContractManifest): void {
  if (manifest.content_digest === "pending") {
    if (manifest.state !== "Draft") fail("lifecycle_pending_evidence", "/content_digest", "Pending content evidence is allowed only in Draft");
  } else if (!/^sha256:[0-9a-f]{64}$/u.test(manifest.content_digest)) {
    fail("digest_invalid", "/content_digest", "Expected pending or a canonical SHA-256 digest");
  }
  const evidenceGroups: Array<[DigestedPath[], string]> = [
    [manifest.outputs, "/outputs"],
    [manifest.integration_fixtures, "/integration_fixtures"],
  ];
  for (const [entries, pointer] of evidenceGroups) {
    entries.forEach((entry, index) => {
      if (entry.digest === "pending") {
        if (manifest.state !== "Draft") fail("lifecycle_pending_evidence", `${pointer}/${index}/digest`, "Pending file evidence is allowed only in Draft");
      } else if (!/^sha256:[0-9a-f]{64}$/u.test(entry.digest)) {
        fail("digest_invalid", `${pointer}/${index}/digest`, "Expected pending or a canonical SHA-256 digest");
      }
    });
  }
  manifest.inputs.forEach((entry, index) => {
    if (entry.content_digest === "pending") {
      if (manifest.state !== "Draft") fail("lifecycle_pending_evidence", `/inputs/${index}/content_digest`, "Pending input evidence is allowed only in Draft");
    } else if (!/^sha256:[0-9a-f]{64}$/u.test(entry.content_digest)) {
      fail("digest_invalid", `/inputs/${index}/content_digest`, "Expected pending or a canonical SHA-256 digest");
    }
  });
}

function assertDependencyBijection(manifest: ContractManifest): void {
  const owners = new Map<string, number>();
  manifest.inputs.forEach((entry, index) => {
    if (owners.has(entry.owner_mission)) fail("input_owner_duplicate", `/inputs/${index}/owner_mission`, "Each dependency owner must have exactly one input");
    owners.set(entry.owner_mission, index);
  });
  const dependencies = new Set<string>();
  manifest.dependencies.forEach((owner, index) => {
    if (dependencies.has(owner)) fail("dependency_duplicate", `/dependencies/${index}`, "Dependency owner is duplicated");
    dependencies.add(owner);
    if (!owners.has(owner)) fail("dependency_input_missing", `/dependencies/${index}`, "Dependency owner has no corresponding input");
  });
  for (const [owner, index] of owners) {
    if (!dependencies.has(owner)) fail("input_owner_undeclared", `/inputs/${index}/owner_mission`, "Input owner is not declared as a dependency");
  }
  const identities = new Map<string, number>();
  manifest.inputs.forEach((entry, index) => {
    const identity = `${entry.contract_id}\0${entry.version}`;
    if (identities.has(identity)) fail("input_contract_duplicate", `/inputs/${index}/contract_id`, "Input contract identity is duplicated");
    identities.set(identity, index);
  });
}

function assertManifestPaths(manifest: ContractManifest): void {
  assertUniqueNormalizedPaths(manifest.outputs, "/outputs");
  assertUniqueNormalizedPaths(manifest.integration_fixtures, "/integration_fixtures");
  const owned = new Map<string, number>();
  manifest.owned_paths.forEach((entry, index) => {
    const normalized = normalizeRepositoryPath(entry, `/owned_paths/${index}`, true);
    if (owned.has(normalized)) fail("path_duplicate", `/owned_paths/${index}`, "Owned path is duplicated");
    owned.set(normalized, index);
  });
  const touchpoints = new Map<string, number>();
  manifest.shared_touchpoints.forEach((entry, index) => {
    const normalized = normalizeRepositoryPath(entry.path, `/shared_touchpoints/${index}/path`, true);
    if (touchpoints.has(normalized)) fail("path_duplicate", `/shared_touchpoints/${index}/path`, "Shared touchpoint is duplicated");
    touchpoints.set(normalized, index);
  });
}

function stateRank(state: LifecycleState): number {
  return lifecycleStates.indexOf(state);
}

export type ManifestResolver = (input: ContractInput) => Promise<ContractManifest>;

export async function validateLifecycleManifest(
  root: string,
  manifest: ContractManifest,
  options: { previous?: ContractManifest; resolveInput?: ManifestResolver } = {},
): Promise<void> {
  if (!lifecycleStates.includes(manifest.state)) fail("lifecycle_state_invalid", "/state", "Unknown lifecycle state");
  assertManifestPaths(manifest);
  assertDependencyBijection(manifest);
  assertEvidence(manifest);
  if (options.previous) {
    if (options.previous.contract_id !== manifest.contract_id || options.previous.version !== manifest.version) {
      fail("lifecycle_identity_changed", "/contract_id", "Lifecycle comparison requires one contract identity and version");
    }
    assertLifecycleTransition(options.previous.state, manifest.state);
    if (options.previous.state !== "Draft" && computeContentDigest(options.previous) !== computeContentDigest(manifest)) {
      fail("lifecycle_content_mutated", "/content_digest", "Frozen contract content cannot change within one version");
    }
  }
  if (manifest.state !== "Draft" && !manifest.integration_fixtures.some((entry) => entry.expectation === "valid")) {
    fail("fixture_valid_missing", "/integration_fixtures", "Frozen contracts require a valid integration fixture");
  }
  if (manifest.state !== "Draft" && !manifest.integration_fixtures.some((entry) => entry.expectation === "invalid")) {
    fail("fixture_invalid_missing", "/integration_fixtures", "Frozen contracts require an invalid integration fixture");
  }
  if (manifest.content_digest !== "pending") {
    const computedContent = computeContentDigest(manifest);
    if (manifest.content_digest !== computedContent) fail("content_digest_mismatch", "/content_digest", "Contract content digest does not match its RFC 8785 projection");
  }

  for (const [group, pointer] of [[manifest.outputs, "/outputs"], [manifest.integration_fixtures, "/integration_fixtures"]] as const) {
    for (const [index, entry] of group.entries()) {
      if (entry.digest === "pending") continue;
      const actual = sha256Digest(await readRepositoryBytes(root, entry.path, `${pointer}/${index}/path`));
      if (actual !== entry.digest) fail("file_digest_mismatch", `${pointer}/${index}/digest`, "Declared file digest does not match exact bytes");
    }
  }
  const concreteInputs = manifest.inputs.filter((entry) => entry.content_digest !== "pending");
  if (concreteInputs.length > 0 && !options.resolveInput) fail("input_resolver_missing", "/inputs", "Concrete dependency evidence requires an immutable manifest resolver");
  for (const [index, input] of manifest.inputs.entries()) {
    if (input.content_digest === "pending") continue;
    const dependency = await options.resolveInput!(input);
    if (dependency.contract_id !== input.contract_id) fail("input_contract_mismatch", `/inputs/${index}/contract_id`, "Resolved input contract ID differs");
    if (dependency.owner_mission !== input.owner_mission) fail("input_owner_mismatch", `/inputs/${index}/owner_mission`, "Resolved input owner differs");
    if (dependency.version !== input.version) fail("input_version_mismatch", `/inputs/${index}/version`, "Resolved input version differs");
    if (dependency.state === "Superseded" || stateRank(dependency.state) < stateRank(input.required_state)) {
      fail("input_state_insufficient", `/inputs/${index}/required_state`, "Resolved input has not reached the required lifecycle state");
    }
    if (dependency.content_digest !== input.content_digest) fail("input_digest_mismatch", `/inputs/${index}/content_digest`, "Resolved input content digest differs");
  }
}

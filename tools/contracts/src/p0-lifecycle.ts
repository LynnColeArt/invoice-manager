import { execFile } from "node:child_process";
import { link, lstat, open, rename, rm } from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";
import { fail } from "./errors.js";
import {
  computeContentDigest,
  type ContractManifest,
  validateLifecycleManifest,
} from "./lifecycle.js";
import {
  compareCodeUnits,
  jcsBytes,
  parseJsonBytes,
  sha256Digest,
  sha256Hex,
  stableJson,
} from "./json.js";
import { readRepositoryBytes, resolveRepositoryWritePath } from "./paths.js";
import { discoverStableIdRegistry, type StableIdRegistry } from "./registry.js";

const execFileAsync = promisify(execFile);
const manifestSchemaId =
  "https://invoice-manager.invalid/contracts/manifests/v1/schema.json";
const draftPath = "contracts/manifests/drafts/p0.json";
const canonicalPath = "contracts/manifests/p0.json";
const lockPath = "contracts/manifests/.p0.json.lock";
const nextPath = "contracts/manifests/.p0.json.next";

export const closureGateNames = [
  "foundation-ci",
  "bootstrap-foundation",
  "verify-foundation-clean",
  "proxy-performance",
  "runtime-license",
  "public-clean-clone",
  "p1-p4-conformance",
  "governed-doc-drift",
] as const;

export type ClosureGateName = (typeof closureGateNames)[number];
export type ClosureEvidenceGate = {
  gate: ClosureGateName;
  evidence_id: string;
  digest: string;
};
export type ClosureEvidence = {
  format_version: 1;
  candidate_commit: string;
  accepted_wp11_receipt_commit: string;
  gates: ClosureEvidenceGate[];
};
export type P0WriteFault = "before_replace";
export type P0PromotionResult = {
  command: "p0-freeze" | "p0-implement" | "p0-verify";
  from: "Draft" | "Frozen" | "Implemented";
  to: "Frozen" | "Implemented" | "Verified";
  source_sha256: string;
  manifest_sha256: string;
  content_digest: string;
  evidence?: ClosureEvidence & { digest: string };
};

type JsonObject = Record<string, unknown>;

function object(value: unknown, pointer: string): JsonObject {
  if (value === null || Array.isArray(value) || typeof value !== "object") {
    fail(
      "p0_closure_evidence_invalid",
      pointer,
      "Closure evidence must be a JSON object",
    );
  }
  return value as JsonObject;
}

function exactKeys(
  value: JsonObject,
  expected: string[],
  pointer: string,
): void {
  const observed = Object.keys(value).sort(compareCodeUnits);
  const sortedExpected = [...expected].sort(compareCodeUnits);
  if (stableJson(observed) !== stableJson(sortedExpected)) {
    fail(
      "p0_closure_evidence_invalid",
      pointer,
      "Closure evidence contains missing or unknown fields",
    );
  }
}

function fullCommit(value: unknown, pointer: string): string {
  if (typeof value !== "string" || !/^[0-9a-f]{40}$/u.test(value)) {
    fail(
      "p0_closure_evidence_invalid",
      pointer,
      "Expected a full lowercase 40-hex commit",
    );
  }
  return value;
}

export function validateClosureEvidence(
  value: unknown,
  trustedReceiptCommit: string,
): ClosureEvidence {
  if (!/^[0-9a-f]{40}$/u.test(trustedReceiptCommit)) {
    fail(
      "p0_receipt_commit_invalid",
      "/accepted_wp11_receipt_commit",
      "Trusted receipt commit must be full lowercase 40-hex",
    );
  }
  const evidence = object(value, "");
  exactKeys(
    evidence,
    [
      "format_version",
      "candidate_commit",
      "accepted_wp11_receipt_commit",
      "gates",
    ],
    "",
  );
  if (evidence.format_version !== 1)
    fail(
      "p0_closure_evidence_invalid",
      "/format_version",
      "Closure evidence format must be 1",
    );
  const candidateCommit = fullCommit(
    evidence.candidate_commit,
    "/candidate_commit",
  );
  const receiptCommit = fullCommit(
    evidence.accepted_wp11_receipt_commit,
    "/accepted_wp11_receipt_commit",
  );
  if (receiptCommit !== trustedReceiptCommit) {
    fail(
      "p0_receipt_commit_mismatch",
      "/accepted_wp11_receipt_commit",
      "Closure evidence does not name the trusted WP11 receipt commit",
    );
  }
  if (
    !Array.isArray(evidence.gates) ||
    evidence.gates.length !== closureGateNames.length
  ) {
    fail(
      "p0_closure_evidence_invalid",
      "/gates",
      "Closure evidence must contain exactly eight gates",
    );
  }
  const gates = evidence.gates.map((entry, index): ClosureEvidenceGate => {
    const gate = object(entry, `/gates/${index}`);
    const gateName = closureGateNames[index];
    exactKeys(gate, ["gate", "evidence_id", "digest"], `/gates/${index}`);
    if (gate.gate !== gateName) {
      fail(
        "p0_closure_evidence_invalid",
        `/gates/${index}/gate`,
        "Closure gates must use the exact canonical order",
      );
    }
    if (
      typeof gate.evidence_id !== "string" ||
      gate.evidence_id.length === 0 ||
      gate.evidence_id.trim() !== gate.evidence_id
    ) {
      fail(
        "p0_closure_evidence_invalid",
        `/gates/${index}/evidence_id`,
        "Evidence ID must be nonempty with no surrounding whitespace",
      );
    }
    if (
      typeof gate.digest !== "string" ||
      !/^sha256:[0-9a-f]{64}$/u.test(gate.digest)
    ) {
      fail(
        "p0_closure_evidence_invalid",
        `/gates/${index}/digest`,
        "Evidence digest must be canonical SHA-256",
      );
    }
    return {
      gate: gateName,
      evidence_id: gate.evidence_id,
      digest: gate.digest,
    };
  });
  return {
    format_version: 1,
    candidate_commit: candidateCommit,
    accepted_wp11_receipt_commit: receiptCommit,
    gates,
  };
}

function assertExpectedSha256(value: string): void {
  if (!/^[0-9a-f]{64}$/u.test(value))
    fail(
      "p0_expected_sha256_invalid",
      "",
      "Expected source hash must be 64 lowercase hex characters",
    );
}

function assertP0Identity(manifest: ContractManifest): void {
  if (
    manifest.manifest_version !== 1 ||
    manifest.contract_id !== "invoice-manager.foundation" ||
    manifest.owner_mission !== "p0" ||
    manifest.mission !== "p0-contract-spine-01KXYY0J" ||
    manifest.version !== "0.1.0-draft.1"
  ) {
    fail(
      "p0_manifest_identity_invalid",
      "",
      "Canonical P0 must retain the accepted Draft identity",
    );
  }
}

function lineageProjection(manifest: ContractManifest): unknown {
  return {
    manifest_version: manifest.manifest_version,
    contract_id: manifest.contract_id,
    owner_mission: manifest.owner_mission,
    mission: manifest.mission,
    version: manifest.version,
    baseline_commit: manifest.baseline_commit,
    dependencies: [...manifest.dependencies].sort(compareCodeUnits),
    inputs: manifest.inputs
      .map(({ content_digest: _digest, ...input }) => input)
      .sort((left, right) =>
        compareCodeUnits(
          `${left.contract_id}\0${left.owner_mission}\0${left.version}`,
          `${right.contract_id}\0${right.owner_mission}\0${right.version}`,
        ),
      ),
    outputs: manifest.outputs
      .map(({ digest: _digest, ...output }) => output)
      .sort((left, right) => compareCodeUnits(left.path, right.path)),
    owned_paths: manifest.owned_paths,
    shared_touchpoints: manifest.shared_touchpoints,
    migration_strategy: manifest.migration_strategy,
    integration_fixtures: manifest.integration_fixtures
      .map(({ digest: _digest, ...fixture }) => fixture)
      .sort((left, right) => compareCodeUnits(left.path, right.path)),
  };
}

function assertDraftLineage(
  draft: ContractManifest,
  canonical: ContractManifest,
): void {
  if (
    stableJson(lineageProjection(draft)) !==
    stableJson(lineageProjection(canonical))
  ) {
    fail(
      "p0_manifest_lineage_changed",
      "",
      "Canonical P0 may differ from Draft only by evidence and lifecycle state",
    );
  }
}

async function loadManifest(
  root: string,
  relative: string,
  registry: StableIdRegistry,
): Promise<{ bytes: Buffer; manifest: ContractManifest }> {
  const bytes = await readRepositoryBytes(root, relative, "");
  const value = parseJsonBytes(bytes);
  registry.validate(manifestSchemaId, value);
  const manifest = value as unknown as ContractManifest;
  assertP0Identity(manifest);
  await validateLifecycleManifest(root, manifest);
  return { bytes, manifest };
}

async function loadDraft(
  root: string,
  registry: StableIdRegistry,
): Promise<{ bytes: Buffer; manifest: ContractManifest }> {
  const result = await loadManifest(root, draftPath, registry);
  if (result.manifest.state !== "Draft")
    fail(
      "p0_draft_state_invalid",
      "/state",
      "Immutable P0 source must remain Draft",
    );
  return result;
}

async function canonicalKind(root: string): Promise<"missing" | "file"> {
  const absolute = path.join(root, ...canonicalPath.split("/"));
  try {
    const metadata = await lstat(absolute);
    if (metadata.isSymbolicLink())
      fail(
        "p0_canonical_symlink",
        "",
        "Canonical P0 destination must not be a symbolic link",
      );
    if (!metadata.isFile())
      fail(
        "p0_canonical_not_file",
        "",
        "Canonical P0 destination must be a regular file",
      );
    return "file";
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return "missing";
    throw error;
  }
}

async function loadCanonical(
  root: string,
  registry: StableIdRegistry,
  draft: ContractManifest,
): Promise<{ bytes: Buffer; manifest: ContractManifest }> {
  if ((await canonicalKind(root)) === "missing")
    fail("p0_canonical_missing", "", "Canonical P0 manifest does not exist");
  const result = await loadManifest(root, canonicalPath, registry);
  assertDraftLineage(draft, result.manifest);
  return result;
}

async function materializeFrozen(
  root: string,
  draft: ContractManifest,
): Promise<ContractManifest> {
  const manifest = structuredClone(draft);
  manifest.dependencies.sort(compareCodeUnits);
  manifest.inputs.sort((left, right) =>
    compareCodeUnits(
      `${left.contract_id}\0${left.owner_mission}\0${left.version}`,
      `${right.contract_id}\0${right.owner_mission}\0${right.version}`,
    ),
  );
  manifest.outputs.sort((left, right) =>
    compareCodeUnits(left.path, right.path),
  );
  manifest.integration_fixtures.sort((left, right) =>
    compareCodeUnits(left.path, right.path),
  );
  for (const [index, output] of manifest.outputs.entries()) {
    output.digest = sha256Digest(
      await readRepositoryBytes(root, output.path, `/outputs/${index}/path`),
    );
  }
  for (const [index, fixture] of manifest.integration_fixtures.entries()) {
    fixture.digest = sha256Digest(
      await readRepositoryBytes(
        root,
        fixture.path,
        `/integration_fixtures/${index}/path`,
      ),
    );
  }
  manifest.state = "Frozen";
  manifest.content_digest = computeContentDigest(manifest);
  return manifest;
}

async function publishCanonical(
  root: string,
  bytes: Buffer,
  replace: boolean,
  fault?: P0WriteFault,
): Promise<void> {
  const lockDestination = await resolveRepositoryWritePath(root, lockPath, "");
  const nextDestination = await resolveRepositoryWritePath(root, nextPath, "");
  const canonicalDestination = path.join(root, ...canonicalPath.split("/"));
  const lockHandle = await open(lockDestination, "wx");
  await lockHandle.close();
  let nextCreated = false;
  try {
    const nextHandle = await open(nextDestination, "wx");
    nextCreated = true;
    try {
      await nextHandle.writeFile(bytes);
      await nextHandle.sync();
    } finally {
      await nextHandle.close();
    }
    if (fault === "before_replace")
      fail(
        "p0_write_injected_failure",
        "",
        "Injected failure before canonical replacement",
      );
    if (replace) {
      if ((await canonicalKind(root)) !== "file")
        fail(
          "p0_canonical_missing",
          "",
          "Canonical P0 disappeared before replacement",
        );
      await rename(nextDestination, canonicalDestination);
    } else {
      if ((await canonicalKind(root)) !== "missing")
        fail("p0_canonical_exists", "", "Canonical P0 already exists");
      await link(nextDestination, canonicalDestination);
      await rm(nextDestination);
    }
  } finally {
    if (nextCreated) await rm(nextDestination, { force: true });
    await rm(lockDestination, { force: true });
  }
}

function promotionResult(
  command: P0PromotionResult["command"],
  from: P0PromotionResult["from"],
  to: P0PromotionResult["to"],
  sourceBytes: Buffer,
  manifestBytes: Buffer,
  manifest: ContractManifest,
  evidence?: ClosureEvidence,
): P0PromotionResult {
  return {
    command,
    from,
    to,
    source_sha256: sha256Hex(sourceBytes),
    manifest_sha256: sha256Hex(manifestBytes),
    content_digest: manifest.content_digest,
    ...(evidence
      ? {
          evidence: {
            ...structuredClone(evidence),
            digest: sha256Digest(jcsBytes(evidence)),
          },
        }
      : {}),
  };
}

export async function freezeP0(
  root: string,
  expectedDraftSha256: string,
): Promise<P0PromotionResult> {
  assertExpectedSha256(expectedDraftSha256);
  if ((await canonicalKind(root)) !== "missing")
    fail("p0_canonical_exists", "", "Canonical P0 already exists");
  const registry = await discoverStableIdRegistry(root);
  const draft = await loadDraft(root, registry);
  if (sha256Hex(draft.bytes) !== expectedDraftSha256)
    fail(
      "p0_source_sha256_mismatch",
      "",
      "Immutable Draft bytes differ from the expected hash",
    );
  const manifest = await materializeFrozen(root, draft.manifest);
  assertDraftLineage(draft.manifest, manifest);
  registry.validate(manifestSchemaId, manifest as unknown);
  await validateLifecycleManifest(root, manifest, { previous: draft.manifest });
  const manifestBytes = Buffer.from(stableJson(manifest));
  await publishCanonical(root, manifestBytes, false);
  return promotionResult(
    "p0-freeze",
    "Draft",
    "Frozen",
    draft.bytes,
    manifestBytes,
    manifest,
  );
}

export async function implementP0(
  root: string,
  expectedManifestSha256: string,
  options: { writeFault?: P0WriteFault } = {},
): Promise<P0PromotionResult> {
  assertExpectedSha256(expectedManifestSha256);
  const registry = await discoverStableIdRegistry(root);
  const draft = await loadDraft(root, registry);
  const current = await loadCanonical(root, registry, draft.manifest);
  if (sha256Hex(current.bytes) !== expectedManifestSha256)
    fail(
      "p0_source_sha256_mismatch",
      "",
      "Canonical P0 bytes differ from the expected hash",
    );
  if (current.manifest.state !== "Frozen")
    fail(
      "p0_transition_source_invalid",
      "/state",
      "p0-implement requires Frozen P0",
    );
  const manifest = {
    ...structuredClone(current.manifest),
    state: "Implemented" as const,
  };
  registry.validate(manifestSchemaId, manifest as unknown);
  await validateLifecycleManifest(root, manifest, {
    previous: current.manifest,
  });
  assertDraftLineage(draft.manifest, manifest);
  const manifestBytes = Buffer.from(stableJson(manifest));
  await publishCanonical(root, manifestBytes, true, options.writeFault);
  return promotionResult(
    "p0-implement",
    "Frozen",
    "Implemented",
    current.bytes,
    manifestBytes,
    manifest,
  );
}

async function gitOutput(
  root: string,
  args: string[],
  code: string,
  message: string,
): Promise<string> {
  try {
    const { stdout } = await execFileAsync("git", args, {
      cwd: root,
      encoding: "utf8",
      maxBuffer: 4 * 1024 * 1024,
    });
    return stdout.trim();
  } catch {
    fail(code, "", message);
  }
}

async function assertClosureCandidate(
  root: string,
  evidence: ClosureEvidence,
): Promise<void> {
  const head = await gitOutput(
    root,
    ["rev-parse", "HEAD"],
    "p0_candidate_git_invalid",
    "Candidate Git HEAD is unavailable",
  );
  if (head !== evidence.candidate_commit)
    fail(
      "p0_candidate_head_mismatch",
      "/candidate_commit",
      "Closure candidate commit must equal exact HEAD",
    );
  const status = await gitOutput(
    root,
    ["status", "--porcelain=v1", "--untracked-files=no"],
    "p0_candidate_git_invalid",
    "Candidate tracked status is unavailable",
  );
  if (status !== "")
    fail(
      "p0_candidate_tree_dirty",
      "",
      "Closure candidate must have a clean tracked tree",
    );
  await gitOutput(
    root,
    ["cat-file", "-e", `${evidence.accepted_wp11_receipt_commit}^{commit}`],
    "p0_receipt_commit_unavailable",
    "Trusted WP11 receipt commit is unavailable",
  );
  try {
    await execFileAsync(
      "git",
      [
        "merge-base",
        "--is-ancestor",
        evidence.accepted_wp11_receipt_commit,
        "HEAD",
      ],
      { cwd: root, encoding: "utf8" },
    );
  } catch {
    fail(
      "p0_receipt_not_ancestor",
      "/accepted_wp11_receipt_commit",
      "Trusted WP11 receipt must be an ancestor of the closure candidate",
    );
  }
}

export async function verifyP0(
  root: string,
  expectedManifestSha256: string,
  closureEvidence: unknown,
  trustedReceiptCommit: string,
  options: { writeFault?: P0WriteFault } = {},
): Promise<P0PromotionResult> {
  assertExpectedSha256(expectedManifestSha256);
  const evidence = validateClosureEvidence(
    closureEvidence,
    trustedReceiptCommit,
  );
  const registry = await discoverStableIdRegistry(root);
  const draft = await loadDraft(root, registry);
  const current = await loadCanonical(root, registry, draft.manifest);
  if (sha256Hex(current.bytes) !== expectedManifestSha256)
    fail(
      "p0_source_sha256_mismatch",
      "",
      "Canonical P0 bytes differ from the expected hash",
    );
  if (current.manifest.state !== "Implemented")
    fail(
      "p0_transition_source_invalid",
      "/state",
      "p0-verify requires Implemented P0",
    );
  await assertClosureCandidate(root, evidence);
  const manifest = {
    ...structuredClone(current.manifest),
    state: "Verified" as const,
  };
  registry.validate(manifestSchemaId, manifest as unknown);
  await validateLifecycleManifest(root, manifest, {
    previous: current.manifest,
  });
  assertDraftLineage(draft.manifest, manifest);
  const manifestBytes = Buffer.from(stableJson(manifest));
  await publishCanonical(root, manifestBytes, true, options.writeFault);
  return promotionResult(
    "p0-verify",
    "Implemented",
    "Verified",
    current.bytes,
    manifestBytes,
    manifest,
    evidence,
  );
}

export async function validateCanonicalP0IfPresent(
  root: string,
  registry?: StableIdRegistry,
): Promise<ContractManifest | undefined> {
  if ((await canonicalKind(root)) === "missing") return undefined;
  const resolvedRegistry = registry ?? (await discoverStableIdRegistry(root));
  const draft = await loadDraft(root, resolvedRegistry);
  const canonical = await loadCanonical(root, resolvedRegistry, draft.manifest);
  return canonical.manifest;
}

export async function checkCanonicalP0(
  root: string,
): Promise<ContractManifest> {
  const manifest = await validateCanonicalP0IfPresent(root);
  if (!manifest)
    fail("p0_canonical_missing", "", "Canonical P0 manifest does not exist");
  return manifest;
}

import { execFileSync } from "node:child_process";
import {
  cp,
  lstat,
  mkdir,
  mkdtemp,
  readFile,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { afterEach, describe, expect, it } from "vitest";
import { ContractError } from "../src/errors.js";
import {
  computeContentDigest,
  contentProjection,
  type ContractManifest,
} from "../src/lifecycle.js";
import {
  checkCanonicalP0,
  closureGateNames,
  freezeP0,
  implementP0,
  type ClosureEvidence,
  validateClosureEvidence,
  verifyP0,
} from "../src/p0-lifecycle.js";
import { jcsBytes, sha256Digest, sha256Hex, stableJson } from "../src/json.js";
import { run } from "../src/main.js";

const projectRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../..",
);
const roots: string[] = [];

afterEach(async () =>
  Promise.all(
    roots.splice(0).map((root) => rm(root, { recursive: true, force: true })),
  ),
);

function git(root: string, args: string[]): string {
  return execFileSync("git", args, {
    cwd: root,
    encoding: "utf8",
    env: {
      ...process.env,
      GIT_AUTHOR_NAME: "P0 Lifecycle Test",
      GIT_AUTHOR_EMAIL: "p0-lifecycle@example.invalid",
      GIT_COMMITTER_NAME: "P0 Lifecycle Test",
      GIT_COMMITTER_EMAIL: "p0-lifecycle@example.invalid",
      GIT_AUTHOR_DATE: "2000-01-01T00:00:00Z",
      GIT_COMMITTER_DATE: "2000-01-01T00:00:00Z",
    },
  }).trim();
}

async function fixtureRoot(): Promise<{
  root: string;
  draftBytes: Buffer;
  receiptCommit: string;
}> {
  const root = await mkdtemp(
    path.join(os.tmpdir(), "invoice-manager-p0-lifecycle-"),
  );
  roots.push(root);
  await Promise.all([
    mkdir(path.join(root, "contracts/manifests/v1"), { recursive: true }),
    mkdir(path.join(root, "contracts/manifests/drafts"), { recursive: true }),
    mkdir(path.join(root, "contracts/fixtures/p0/v1/valid"), {
      recursive: true,
    }),
    mkdir(path.join(root, "contracts/fixtures/p0/v1/invalid"), {
      recursive: true,
    }),
    mkdir(path.join(root, "contracts/outputs"), { recursive: true }),
  ]);
  await cp(
    path.join(projectRoot, "contracts/manifests/v1/schema.json"),
    path.join(root, "contracts/manifests/v1/schema.json"),
  );
  await writeFile(
    path.join(root, "contracts/outputs/value.json"),
    '{"value":"synthetic"}\n',
  );
  await writeFile(
    path.join(root, "contracts/fixtures/p0/v1/valid/value.json"),
    '{"case":"valid"}\n',
  );
  await writeFile(
    path.join(root, "contracts/fixtures/p0/v1/invalid/value.json"),
    '{"case":"invalid"}\n',
  );
  const draft: ContractManifest = {
    manifest_version: 1,
    contract_id: "invoice-manager.foundation",
    owner_mission: "p0",
    mission: "p0-contract-spine-01KXYY0J",
    version: "0.1.0-draft.1",
    state: "Draft",
    baseline_commit: "a71448bbec991a6bf0be805129d704beab06d486",
    content_digest: "pending",
    dependencies: [],
    inputs: [],
    outputs: [
      {
        path: "contracts/outputs/value.json",
        kind: "other",
        digest: "pending",
      },
    ],
    owned_paths: ["contracts/**"],
    shared_touchpoints: [],
    migration_strategy: { mode: "none" },
    integration_fixtures: [
      {
        path: "contracts/fixtures/p0/v1/valid/value.json",
        expectation: "valid",
        digest: "pending",
      },
      {
        path: "contracts/fixtures/p0/v1/invalid/value.json",
        expectation: "invalid",
        digest: "pending",
      },
    ],
  };
  const draftBytes = Buffer.from(stableJson(draft));
  await writeFile(
    path.join(root, "contracts/manifests/drafts/p0.json"),
    draftBytes,
  );
  await writeFile(path.join(root, "marker.txt"), "clean\n");
  git(root, ["init", "-q"]);
  git(root, ["add", "."]);
  git(root, ["commit", "-qm", "receipt baseline"]);
  return { root, draftBytes, receiptCommit: git(root, ["rev-parse", "HEAD"]) };
}

function evidence(
  candidateCommit: string,
  receiptCommit: string,
): ClosureEvidence {
  return {
    format_version: 1,
    candidate_commit: candidateCommit,
    accepted_wp11_receipt_commit: receiptCommit,
    gates: closureGateNames.map((gate, index) => ({
      gate,
      evidence_id: `synthetic-${index + 1}`,
      digest: `sha256:${String(index + 1).padStart(64, "0")}`,
    })),
  };
}

async function freezeAndImplement(
  root: string,
): Promise<{ implementedBytes: Buffer; implementedCommit: string }> {
  const draftBytes = await readFile(
    path.join(root, "contracts/manifests/drafts/p0.json"),
  );
  await freezeP0(root, sha256Hex(draftBytes));
  const frozenBytes = await readFile(
    path.join(root, "contracts/manifests/p0.json"),
  );
  await implementP0(root, sha256Hex(frozenBytes));
  git(root, ["add", "contracts/manifests/p0.json"]);
  git(root, ["commit", "-qm", "implement contract"]);
  return {
    implementedBytes: await readFile(
      path.join(root, "contracts/manifests/p0.json"),
    ),
    implementedCommit: git(root, ["rev-parse", "HEAD"]),
  };
}

async function expectCode(
  action: () => unknown | Promise<unknown>,
  code: string,
): Promise<void> {
  await expect(Promise.resolve().then(action)).rejects.toMatchObject({ code });
}

describe("P0 canonical lifecycle materialization", () => {
  it("fills exact byte digests, sorts semantic collections, and computes the RFC 8785 identity without touching Draft", async () => {
    const { root, draftBytes } = await fixtureRoot();
    const result = await freezeP0(root, sha256Hex(draftBytes));
    const canonicalBytes = await readFile(
      path.join(root, "contracts/manifests/p0.json"),
    );
    const manifest = JSON.parse(
      canonicalBytes.toString("utf8"),
    ) as ContractManifest;

    expect(
      await readFile(path.join(root, "contracts/manifests/drafts/p0.json")),
    ).toEqual(draftBytes);
    expect(manifest.state).toBe("Frozen");
    expect(manifest.outputs[0].digest).toBe(
      sha256Digest(await readFile(path.join(root, manifest.outputs[0].path))),
    );
    expect(
      manifest.integration_fixtures.map(({ path: value }) => value),
    ).toEqual([
      "contracts/fixtures/p0/v1/invalid/value.json",
      "contracts/fixtures/p0/v1/valid/value.json",
    ]);
    expect(manifest.content_digest).toBe(
      sha256Digest(jcsBytes(contentProjection(manifest))),
    );
    expect(result.manifest_sha256).toBe(sha256Hex(canonicalBytes));
    expect(result.content_digest).toBe(computeContentDigest(manifest));
    expect(await checkCanonicalP0(root)).toEqual(manifest);
  });

  it("rejects stale hashes, an existing destination, transition skips, reruns, and destination overrides", async () => {
    const { root, draftBytes } = await fixtureRoot();
    await expectCode(
      () => freezeP0(root, "0".repeat(64)),
      "p0_source_sha256_mismatch",
    );
    expect(
      await lstat(path.join(root, "contracts/manifests/p0.json")).catch(
        () => undefined,
      ),
    ).toBeUndefined();
    await freezeP0(root, sha256Hex(draftBytes));
    await expectCode(
      () => freezeP0(root, sha256Hex(draftBytes)),
      "p0_canonical_exists",
    );
    const frozenBytes = await readFile(
      path.join(root, "contracts/manifests/p0.json"),
    );
    await expectCode(
      () =>
        verifyP0(
          root,
          sha256Hex(frozenBytes),
          evidence(
            git(root, ["rev-parse", "HEAD"]),
            git(root, ["rev-parse", "HEAD"]),
          ),
          git(root, ["rev-parse", "HEAD"]),
        ),
      "p0_transition_source_invalid",
    );
    expect(
      await run(["p0-freeze", "--destination", "../escape.json"], root),
    ).toBe(3);
    expect(
      await lstat(path.join(root, "escape.json")).catch(() => undefined),
    ).toBeUndefined();
  });

  it("preserves the prior canonical bytes on an injected atomic replacement failure", async () => {
    const { root, draftBytes } = await fixtureRoot();
    await freezeP0(root, sha256Hex(draftBytes));
    const before = await readFile(
      path.join(root, "contracts/manifests/p0.json"),
    );
    await expectCode(
      () =>
        implementP0(root, sha256Hex(before), { writeFault: "before_replace" }),
      "p0_write_injected_failure",
    );
    expect(
      await readFile(path.join(root, "contracts/manifests/p0.json")),
    ).toEqual(before);
    expect(
      await lstat(path.join(root, "contracts/manifests/.p0.json.lock")).catch(
        () => undefined,
      ),
    ).toBeUndefined();
    expect(
      await lstat(path.join(root, "contracts/manifests/.p0.json.next")).catch(
        () => undefined,
      ),
    ).toBeUndefined();
  });

  it("fails closed on missing files, escaping symlinks, and canonical path replacement", async () => {
    const missing = await fixtureRoot();
    await rm(path.join(missing.root, "contracts/outputs/value.json"));
    await expectCode(
      () => freezeP0(missing.root, sha256Hex(missing.draftBytes)),
      "path_missing",
    );

    const escaping = await fixtureRoot();
    const outside = path.join(
      os.tmpdir(),
      `p0-outside-${path.basename(escaping.root)}.json`,
    );
    roots.push(outside);
    await writeFile(outside, "{}\n");
    await rm(path.join(escaping.root, "contracts/outputs/value.json"));
    await symlink(
      outside,
      path.join(escaping.root, "contracts/outputs/value.json"),
    );
    await expectCode(
      () => freezeP0(escaping.root, sha256Hex(escaping.draftBytes)),
      "path_symlink_escape",
    );

    const canonicalLink = await fixtureRoot();
    await symlink(
      "drafts/p0.json",
      path.join(canonicalLink.root, "contracts/manifests/p0.json"),
    );
    await expectCode(
      () => freezeP0(canonicalLink.root, sha256Hex(canonicalLink.draftBytes)),
      "p0_canonical_symlink",
    );
  });

  it("emits byte-deterministic Frozen manifests and summaries for identical inputs", async () => {
    const first = await fixtureRoot();
    const second = await fixtureRoot();
    const firstResult = await freezeP0(first.root, sha256Hex(first.draftBytes));
    const secondResult = await freezeP0(
      second.root,
      sha256Hex(second.draftBytes),
    );
    expect(stableJson(firstResult)).toBe(stableJson(secondResult));
    expect(
      await readFile(path.join(first.root, "contracts/manifests/p0.json")),
    ).toEqual(
      await readFile(path.join(second.root, "contracts/manifests/p0.json")),
    );
  });
});

describe("P0 Verified closure evidence", () => {
  it("accepts only the exact closed, ordered eight-gate evidence shape", async () => {
    const { root, receiptCommit } = await fixtureRoot();
    const valid = evidence(git(root, ["rev-parse", "HEAD"]), receiptCommit);
    expect(validateClosureEvidence(valid, receiptCommit)).toEqual(valid);
    for (const mutate of [
      (value: Record<string, unknown>) => {
        value.extra = true;
      },
      (value: Record<string, unknown>) => {
        (value.gates as unknown[]).pop();
      },
      (value: Record<string, unknown>) => {
        [(value.gates as unknown[])[0], (value.gates as unknown[])[1]] = [
          (value.gates as unknown[])[1],
          (value.gates as unknown[])[0],
        ];
      },
      (value: Record<string, unknown>) => {
        (value.gates as Array<Record<string, unknown>>)[0].evidence_id = "";
      },
      (value: Record<string, unknown>) => {
        (value.gates as Array<Record<string, unknown>>)[0].digest = "pending";
      },
      (value: Record<string, unknown>) => {
        value.accepted_wp11_receipt_commit = "0".repeat(40);
      },
    ]) {
      const changed = structuredClone(valid) as unknown as Record<
        string,
        unknown
      >;
      mutate(changed);
      expect(() =>
        validateClosureEvidence(changed, receiptCommit),
      ).toThrowError(ContractError);
    }
  });

  it("requires clean tracked HEAD, exact candidate HEAD, and the trusted receipt commit", async () => {
    const { root, receiptCommit } = await fixtureRoot();
    const { implementedBytes, implementedCommit } =
      await freezeAndImplement(root);
    await expectCode(
      () =>
        verifyP0(
          root,
          sha256Hex(implementedBytes),
          evidence(receiptCommit, receiptCommit),
          receiptCommit,
        ),
      "p0_candidate_head_mismatch",
    );
    await writeFile(path.join(root, "marker.txt"), "dirty\n");
    await expectCode(
      () =>
        verifyP0(
          root,
          sha256Hex(implementedBytes),
          evidence(implementedCommit, receiptCommit),
          receiptCommit,
        ),
      "p0_candidate_tree_dirty",
    );
    git(root, ["checkout", "--", "marker.txt"]);
    await expectCode(
      () =>
        verifyP0(
          root,
          sha256Hex(implementedBytes),
          evidence(implementedCommit, receiptCommit),
          "0".repeat(40),
        ),
      "p0_receipt_commit_mismatch",
    );
  });

  it("changes only lifecycle state, preserves content identity, and returns a deterministic ledger summary", async () => {
    const { root, receiptCommit } = await fixtureRoot();
    const { implementedBytes, implementedCommit } =
      await freezeAndImplement(root);
    const before = JSON.parse(
      implementedBytes.toString("utf8"),
    ) as ContractManifest;
    const closure = evidence(implementedCommit, receiptCommit);
    const result = await verifyP0(
      root,
      sha256Hex(implementedBytes),
      closure,
      receiptCommit,
    );
    const afterBytes = await readFile(
      path.join(root, "contracts/manifests/p0.json"),
    );
    const after = JSON.parse(afterBytes.toString("utf8")) as ContractManifest;

    expect(after).toEqual({ ...before, state: "Verified" });
    expect(after.content_digest).toBe(before.content_digest);
    expect(result.evidence).toEqual({
      ...closure,
      digest: sha256Digest(jcsBytes(closure)),
    });
    expect(result.manifest_sha256).toBe(sha256Hex(afterBytes));
    await expectCode(
      () => verifyP0(root, sha256Hex(afterBytes), closure, receiptCommit),
      "p0_transition_source_invalid",
    );
  });
});

import { createHash } from "node:crypto";
import { existsSync, readdirSync, statSync } from "node:fs";
import { copyFile, mkdir, readdir, readFile, rm } from "node:fs/promises";
import path from "node:path";

type NoticeEvidence = { path: string; sha256: string };
export type ShovelerPolicy = {
  commit: string;
  source: string;
  spdx_expression: string;
  license_path: string;
  license_sha256: string;
  notice_path: string;
  notice_sha256: string;
  provenance_path: string;
  provenance_sha256: string;
  source_tree_sha256: string;
};
type ZigPolicy = {
  version: string;
  source: string;
  spdx_expression: string;
  version_path: string;
  required_license_sha256: string;
  committed_license_path: string | null;
};
export type ArtifactManifestPolicy = {
  identity: string;
  version: string;
  spdx_expression: string;
  source_manifest_path: string;
  source_manifest_sha256: string;
  source_notice_path: string | null;
  source_notice_sha256: string | null;
  distributed_notice_path: string | null;
};

type RootDistributionFile =
  string | { sha256: string; distributed_path: string };

export type PlatformTarget = { os: string; cpu: string; libc: string };

export type LicensePolicy = {
  schema:
    | "invoice-manager.runtime-license-policy/v1"
    | "invoice-manager.runtime-license-policy/v2";
  project_license: "GPL-2.0-only";
  target?: PlatformTarget;
  compatible_combined_runtime: string[];
  incompatible_combined_runtime: string[];
  license_selections: Record<string, string>;
  notice_evidence?: Record<string, NoticeEvidence>;
  source_components?: { shovelerdb: ShovelerPolicy; zig_stdlib: ZigPolicy };
  artifact_manifests?: Record<string, ArtifactManifestPolicy>;
  artifact_inventory?: {
    manifest_count: number;
    identity_count: number;
    projection_sha256: string;
  };
  root_distribution_files?: Record<string, RootDistributionFile>;
  zig_artifact?: {
    root: string;
    required_paths: string[];
  };
};

export type LicenseComponent = {
  identity: string;
  version: string;
  source: string;
  runtime_role:
    | "combined-runtime"
    | "compiled-runtime"
    | "runtime-capable-vendored"
    | "build-only";
  spdx_expression: string;
  selected_license: string | null;
  notice_path: string | null;
  dependency_path: string;
  evidence_path: string;
  evidence_digest: string;
  evidence_status?: "verified" | "missing" | "mismatch" | "conflicting";
  disposition: "pending" | "compatible" | "blocked" | "build-only-proven";
  artifact_paths?: string[];
  artifact_digest?: string;
};

export type LicenseViolation = {
  component: string;
  reason: string;
  dependency_path: string;
  evidence: string;
  policy_reason: string;
};

export type LicenseReport = {
  schema: "invoice-manager.runtime-license-report/v1";
  project_license: "GPL-2.0-only";
  target: PlatformTarget;
  status: "compatible" | "blocked";
  components: LicenseComponent[];
  violations: LicenseViolation[];
  artifacts?: {
    standalone: ArtifactInventory;
    zig: ZigArtifactInventory;
  };
};

export type ArtifactViolation = {
  path: string;
  reason: string;
  detail: string;
};

export type ArtifactManifestInventory = {
  identity: string;
  version: string;
  spdx_expression: string;
  manifest_path: string;
  raw_manifest_path: string;
  artifact_paths: string[];
  artifact_digest: string;
  distributed_notice_path: string | null;
};

export type ArtifactInventory = {
  root: string;
  payload_prefix: string;
  file_count: number;
  tree_digest: string;
  manifests: ArtifactManifestInventory[];
  native_artifacts: string[];
  unmapped_files: string[];
  violations: ArtifactViolation[];
};

export type ZigArtifactInventory = {
  root: string;
  files: string[];
  tree_digest: string;
  violations: ArtifactViolation[];
};

type JsonObject = { [key: string]: JsonValue };
type JsonValue = null | boolean | number | string | JsonValue[] | JsonObject;

function canonical(value: JsonValue): JsonValue {
  if (Array.isArray(value)) return value.map(canonical);
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value)
        .sort(compare)
        .map((key) => [key, canonical(value[key])]),
    ) as JsonObject;
  }
  return value;
}

function stableJson(value: unknown): string {
  return `${JSON.stringify(canonical(value as JsonValue))}\n`;
}

function compare(left: string, right: string): number {
  return left < right ? -1 : left > right ? 1 : 0;
}

export function findRepositoryRoot(start = process.cwd()): string {
  let current = path.resolve(start);
  for (;;) {
    if (
      existsSync(path.join(current, "package-lock.json")) &&
      existsSync(path.join(current, "apps/web/package.json")) &&
      existsSync(path.join(current, "tools/contracts/package.json"))
    ) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current)
      throw new Error("[license:path] repository root is unavailable");
    current = parent;
  }
}

function sha256(bytes: Buffer | string): string {
  return createHash("sha256").update(bytes).digest("hex");
}

function digest(value: unknown): string {
  return `sha256:${sha256(stableJson(value))}`;
}

function assertRepositoryPath(value: string): void {
  if (
    path.isAbsolute(value) ||
    value.includes("\\") ||
    value
      .split("/")
      .some((part) => part === "" || part === "." || part === "..")
  ) {
    throw new Error(`[license:policy] unsafe repository path: ${value}`);
  }
}

async function bytes(root: string, relative: string): Promise<Buffer | null> {
  assertRepositoryPath(relative);
  try {
    return await readFile(path.join(root, ...relative.split("/")));
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return null;
    throw error;
  }
}

function componentKey(
  component: Pick<LicenseComponent, "identity" | "version">,
): string {
  return `${component.identity}@${component.version}`;
}

function violation(
  component: LicenseComponent,
  reason: string,
  policyReason: string,
): LicenseViolation {
  return {
    component: componentKey(component),
    reason,
    dependency_path: component.dependency_path,
    evidence: `${component.evidence_path} ${component.evidence_digest}`,
    policy_reason: policyReason,
  };
}

function expressionBranches(expression: string): string[] | null {
  if (!expression.includes(" OR ")) return null;
  if (
    expression.includes("(") ||
    expression.includes(")") ||
    expression.includes(" AND ") ||
    expression.includes(" WITH ")
  )
    return [];
  return expression
    .split(" OR ")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

export function auditComponents(
  input: LicenseComponent[],
  policy: LicensePolicy,
): LicenseReport {
  const components = input
    .map((entry) => structuredClone(entry))
    .sort((left, right) => compare(componentKey(left), componentKey(right)));
  const violations: LicenseViolation[] = [];
  const seen = new Map<string, string>();
  const compatible = new Set(policy.compatible_combined_runtime);
  const incompatible = new Set(policy.incompatible_combined_runtime);

  for (const component of components) {
    const key = componentKey(component);
    const fingerprint = stableJson(component);
    const previous = seen.get(key);
    if (previous !== undefined) {
      component.disposition = "blocked";
      violations.push(
        violation(
          component,
          previous === fingerprint
            ? "component_duplicate"
            : "component_evidence_conflict",
          "One stable identity/version must have exactly one evidence record.",
        ),
      );
      continue;
    }
    seen.set(key, fingerprint);

    if (component.runtime_role === "build-only") {
      if (component.evidence_status !== "verified") {
        component.disposition = "blocked";
        violations.push(
          violation(
            component,
            "build_only_proof_missing",
            "Build-only exclusions require deterministic proof that the component is absent from the distributed runtime.",
          ),
        );
      } else {
        component.disposition = "build-only-proven";
      }
      continue;
    }

    if (component.evidence_status && component.evidence_status !== "verified") {
      component.disposition = "blocked";
      violations.push(
        violation(
          component,
          `evidence_${component.evidence_status}`,
          "Committed license and notice evidence must exist and match its pinned SHA-256 digest.",
        ),
      );
    }

    const expression = component.spdx_expression.trim();
    if (
      expression === "" ||
      expression === "UNKNOWN" ||
      expression === "UNLICENSED" ||
      expression === "SEE LICENSE IN"
    ) {
      component.disposition = "blocked";
      component.selected_license = null;
      violations.push(
        violation(
          component,
          "license_unknown",
          "Unknown, absent, custom, or unparseable license evidence fails closed.",
        ),
      );
      continue;
    }

    const branches = expressionBranches(expression);
    let selected = component.selected_license;
    if (branches !== null) {
      selected = policy.license_selections[key] ?? null;
      component.selected_license = selected;
      if (selected === null) {
        component.disposition = "blocked";
        violations.push(
          violation(
            component,
            "license_selection_required",
            "OR expressions require a committed explicit compatible branch selection.",
          ),
        );
        continue;
      }
      if (branches.length === 0 || !branches.includes(selected)) {
        component.disposition = "blocked";
        violations.push(
          violation(
            component,
            "license_selection_invalid",
            "The committed selection must name an exact branch of the SPDX OR expression.",
          ),
        );
        continue;
      }
    } else if (
      expression.includes(" AND ") ||
      expression.includes(" WITH ") ||
      expression.includes("(") ||
      expression.includes(")")
    ) {
      component.disposition = "blocked";
      violations.push(
        violation(
          component,
          "license_legal_review_required",
          "Compound, exception, and nuanced expressions remain blocked pending explicit human legal review.",
        ),
      );
      continue;
    } else {
      selected = expression;
      component.selected_license = expression;
    }

    if (selected && incompatible.has(selected)) {
      component.disposition = "blocked";
      violations.push(
        violation(
          component,
          "license_incompatible",
          `${selected} is not approved for GPL-2.0-only combined runtime distribution.`,
        ),
      );
    } else if (selected && compatible.has(selected)) {
      if (component.disposition !== "blocked")
        component.disposition = "compatible";
    } else {
      component.disposition = "blocked";
      violations.push(
        violation(
          component,
          "license_unreviewed",
          `${selected ?? expression} has no committed compatibility decision for GPL-2.0-only combined runtime distribution.`,
        ),
      );
    }
  }

  violations.sort((left, right) =>
    compare(
      `${left.component}\0${left.reason}`,
      `${right.component}\0${right.reason}`,
    ),
  );
  return {
    schema: "invoice-manager.runtime-license-report/v1",
    project_license: "GPL-2.0-only",
    target: policy.target ?? { os: "linux", cpu: "x64", libc: "glibc" },
    status: violations.length === 0 ? "compatible" : "blocked",
    components,
    violations,
  };
}

export function platformAllows(
  record: Record<string, unknown>,
  target: PlatformTarget,
): boolean {
  const permits = (field: "os" | "cpu" | "libc"): boolean => {
    const values = record[field];
    if (!Array.isArray(values)) return true;
    const strings = values.filter(
      (entry): entry is string => typeof entry === "string",
    );
    const expected = target[field];
    if (strings.includes(`!${expected}`)) return false;
    const positive = strings.filter((entry) => !entry.startsWith("!"));
    return positive.length === 0 || positive.includes(expected);
  };
  return permits("os") && permits("cpu") && permits("libc");
}

function dependencies(record: Record<string, unknown>): string[] {
  const names = new Set<string>();
  for (const field of ["dependencies", "optionalDependencies"] as const) {
    const value = record[field];
    if (value !== null && typeof value === "object" && !Array.isArray(value)) {
      for (const name of Object.keys(value)) names.add(name);
    }
  }
  return [...names].sort(compare);
}

export function resolveLockDependency(
  packages: Record<string, Record<string, unknown>>,
  parentKey: string,
  dependencyName: string,
): string | null {
  let directory = parentKey;
  for (;;) {
    const candidate = path.posix.join(
      directory,
      "node_modules",
      dependencyName,
    );
    if (packages[candidate]) return candidate;
    if (directory === "" || directory === ".") break;
    directory = path.posix.dirname(directory);
    if (path.posix.basename(directory) === "node_modules") {
      directory = path.posix.dirname(directory);
    }
    if (directory === ".") directory = "";
  }
  const rootCandidate = `node_modules/${dependencyName}`;
  return packages[rootCandidate] ? rootCandidate : null;
}

export type LockedProductionNode = {
  key: string;
  chain: string;
  record: Record<string, unknown>;
};

export function traverseProductionLock(
  packages: Record<string, Record<string, unknown>>,
  rootKey: string,
  target: PlatformTarget,
): LockedProductionNode[] {
  const root = packages[rootKey];
  if (!root)
    throw new Error(`[license:lock] missing production root ${rootKey}`);
  const queue = dependencies(root).map((dependencyName) => ({
    parentKey: rootKey,
    dependencyName,
    chain: dependencyName,
    optional:
      typeof root.optionalDependencies === "object" &&
      root.optionalDependencies !== null &&
      dependencyName in root.optionalDependencies,
  }));
  const seen = new Set<string>();
  const result: LockedProductionNode[] = [];
  while (queue.length > 0) {
    queue.sort((left, right) =>
      compare(
        `${left.parentKey}\0${left.dependencyName}\0${left.chain}`,
        `${right.parentKey}\0${right.dependencyName}\0${right.chain}`,
      ),
    );
    const edge = queue.shift()!;
    const key = resolveLockDependency(
      packages,
      edge.parentKey,
      edge.dependencyName,
    );
    const parent = packages[edge.parentKey];
    const parentVersion =
      typeof parent?.version === "string" ? `@${parent.version}` : "";
    const diagnosticChain = `${edge.chain}`;
    if (!key) {
      throw new Error(
        `[license:lock] unresolved production edge ${diagnosticChain}`,
      );
    }
    const record = packages[key];
    if (!platformAllows(record, target)) {
      if (edge.optional) continue;
      throw new Error(
        `[license:lock] required production edge ${edge.parentKey}${parentVersion} > ${edge.dependencyName} excludes ${target.os}/${target.cpu}/${target.libc}`,
      );
    }
    if (seen.has(key)) continue;
    seen.add(key);
    result.push({ key, chain: edge.chain, record });
    const optionalDependencies =
      typeof record.optionalDependencies === "object" &&
      record.optionalDependencies !== null
        ? record.optionalDependencies
        : {};
    const version =
      typeof record.version === "string" ? `@${record.version}` : "";
    for (const dependencyName of dependencies(record)) {
      queue.push({
        parentKey: key,
        dependencyName,
        chain: `${edge.chain}${version} > ${dependencyName}`,
        optional: dependencyName in optionalDependencies,
      });
    }
  }
  return result.sort((left, right) => compare(left.key, right.key));
}

async function npmComponents(
  root: string,
  policy: LicensePolicy,
): Promise<LicenseComponent[]> {
  const lockBytes = await readFile(path.join(root, "package-lock.json"));
  const lock = JSON.parse(lockBytes.toString("utf8")) as {
    packages?: Record<string, Record<string, unknown>>;
  };
  const packages = lock.packages;
  if (!packages)
    throw new Error("[license:lock] package-lock.json lacks packages");
  const graph = traverseProductionLock(
    packages,
    "apps/web",
    policy.target ?? { os: "linux", cpu: "x64", libc: "glibc" },
  ).filter((entry) => entry.key !== "node_modules/@invoice-manager/contracts");

  const result: LicenseComponent[] = [];
  for (const { key, chain, record } of graph) {
    const name = key.slice("node_modules/".length);
    const version =
      typeof record.version === "string" ? record.version : "UNKNOWN";
    const identity = `npm:${name}`;
    const policyKey = `${identity}@${version}`;
    const notice = policy.notice_evidence?.[policyKey];
    const noticeBytes = notice ? await bytes(root, notice.path) : null;
    const actualNoticeDigest = noticeBytes ? sha256(noticeBytes) : null;
    const manifestBytes = await bytes(root, `${key}/package.json`);
    const manifest = manifestBytes
      ? (JSON.parse(manifestBytes.toString("utf8")) as { license?: unknown })
      : {};
    const lockLicense =
      typeof record.license === "string" ? record.license : "UNKNOWN";
    const manifestLicense =
      typeof manifest.license === "string" ? manifest.license : "UNKNOWN";
    let evidenceStatus: LicenseComponent["evidence_status"] = "verified";
    if (!notice || !noticeBytes) evidenceStatus = "missing";
    else if (actualNoticeDigest !== notice.sha256) evidenceStatus = "mismatch";
    else if (manifestLicense !== lockLicense) evidenceStatus = "conflicting";
    result.push({
      identity,
      version,
      source:
        typeof record.resolved === "string" ? record.resolved : "UNPINNED",
      runtime_role: "combined-runtime",
      spdx_expression: lockLicense,
      selected_license: null,
      notice_path: notice?.path ?? null,
      dependency_path: chain,
      evidence_path: `package-lock.json#packages/${key.replaceAll("/", "~1")}`,
      evidence_digest: digest({
        lock_record: record,
        package_manifest_sha256: manifestBytes ? sha256(manifestBytes) : null,
        notice_sha256: actualNoticeDigest,
      }),
      evidence_status: evidenceStatus,
      disposition: "pending",
    });
  }
  return result;
}

async function sourceTreeDigest(root: string): Promise<string> {
  const files: string[] = ["deps/shovelerdb/LICENSE"];
  const visit = async (relative: string): Promise<void> => {
    const entries = await readdir(path.join(root, relative), {
      withFileTypes: true,
    });
    for (const entry of entries.sort((left, right) =>
      compare(left.name, right.name),
    )) {
      const child = `${relative}/${entry.name}`;
      if (entry.isDirectory()) await visit(child);
      else if (entry.isFile()) files.push(child);
    }
  };
  await visit("deps/shovelerdb/include");
  await visit("deps/shovelerdb/src");
  files.sort(compare);
  const lines: string[] = [];
  for (const file of files)
    lines.push(
      `${sha256(await readFile(path.join(root, file)))}  ${file.slice("deps/shovelerdb/".length)}`,
    );
  return sha256(`${lines.join("\n")}\n`);
}

export async function verifyShovelerEvidence(
  root: string,
  policy: ShovelerPolicy,
): Promise<{
  verified: boolean;
  source_tree_sha256: string;
  provenance_sha256: string | null;
  license_sha256: string | null;
  notice_sha256: string | null;
}> {
  const [provenance, license, notice] = await Promise.all([
    bytes(root, policy.provenance_path),
    bytes(root, policy.license_path),
    bytes(root, policy.notice_path),
  ]);
  const tree = await sourceTreeDigest(root);
  const fields = new Map<string, string>();
  let unique = true;
  for (const line of provenance?.toString("utf8").split("\n") ?? []) {
    if (line === "") continue;
    const separator = line.indexOf("=");
    if (separator <= 0) {
      unique = false;
      continue;
    }
    const key = line.slice(0, separator);
    if (fields.has(key)) unique = false;
    fields.set(key, line.slice(separator + 1));
  }
  const provenanceSha = provenance ? sha256(provenance) : null;
  const licenseSha = license ? sha256(license) : null;
  const noticeSha = notice ? sha256(notice) : null;
  return {
    verified:
      unique &&
      provenanceSha === policy.provenance_sha256 &&
      fields.get("component") === "ShovelerDB" &&
      fields.get("source_url") === policy.source &&
      fields.get("commit") === policy.commit &&
      fields.get("source_tree_sha256") === policy.source_tree_sha256 &&
      tree === policy.source_tree_sha256 &&
      licenseSha === policy.license_sha256 &&
      noticeSha === policy.notice_sha256,
    source_tree_sha256: tree,
    provenance_sha256: provenanceSha,
    license_sha256: licenseSha,
    notice_sha256: noticeSha,
  };
}

async function sourceComponents(
  root: string,
  policy: LicensePolicy,
): Promise<LicenseComponent[]> {
  if (!policy.source_components) return [];
  const shoveler = policy.source_components.shovelerdb;
  const shovelerEvidence = await verifyShovelerEvidence(root, shoveler);

  const zig = policy.source_components.zig_stdlib;
  const zigVersion = await bytes(root, zig.version_path);
  const zigLicense = zig.committed_license_path
    ? await bytes(root, zig.committed_license_path)
    : null;
  const zigVerified =
    zigVersion?.toString("utf8") === `${zig.version}\n` &&
    zigLicense !== null &&
    sha256(zigLicense) === zig.required_license_sha256;

  return [
    {
      identity: "source:shovelerdb",
      version: shoveler.commit,
      source: `${shoveler.source}#${shoveler.commit}`,
      runtime_role: "compiled-runtime",
      spdx_expression: shoveler.spdx_expression,
      selected_license: null,
      notice_path: shoveler.notice_path,
      dependency_path: "services/api > deps/shovelerdb",
      evidence_path: shoveler.provenance_path,
      evidence_digest: digest(shovelerEvidence),
      evidence_status: shovelerEvidence.verified ? "verified" : "mismatch",
      disposition: "pending",
    },
    {
      identity: "toolchain:zig-stdlib",
      version: zig.version,
      source: zig.source,
      runtime_role: "compiled-runtime",
      spdx_expression: zig.spdx_expression,
      selected_license: null,
      notice_path: zig.committed_license_path,
      dependency_path: "services/api > Zig standard library",
      evidence_path: zig.version_path,
      evidence_digest: digest({
        version_sha256: zigVersion ? sha256(zigVersion) : null,
        required_license_sha256: zig.required_license_sha256,
        committed_license_sha256: zigLicense ? sha256(zigLicense) : null,
      }),
      evidence_status: zigVerified ? "verified" : "missing",
      disposition: "pending",
    },
  ];
}

type TreeFile = { path: string; bytes: Buffer };

async function treeFiles(root: string): Promise<TreeFile[]> {
  const result: TreeFile[] = [];
  const visit = async (directory: string): Promise<void> => {
    const entries = await readdir(path.join(root, directory), {
      withFileTypes: true,
    });
    for (const entry of entries.sort((left, right) =>
      compare(left.name, right.name),
    )) {
      const relative = directory ? `${directory}/${entry.name}` : entry.name;
      if (entry.isDirectory()) await visit(relative);
      else if (entry.isFile())
        result.push({
          path: relative,
          bytes: await readFile(path.join(root, relative)),
        });
      else
        throw new Error(
          `[license:artifact] unsupported non-regular artifact entry ${relative}`,
        );
    }
  };
  await visit("");
  return result.sort((left, right) => compare(left.path, right.path));
}

function artifactPrefix(
  rawManifestPaths: string[],
  expectedManifestPaths: string[],
): string {
  const counts = new Map<string, number>();
  for (const raw of rawManifestPaths) {
    for (const expected of expectedManifestPaths) {
      if (raw === expected) counts.set("", (counts.get("") ?? 0) + 1);
      else if (raw.endsWith(`/${expected}`)) {
        const prefix = raw.slice(0, -expected.length);
        counts.set(prefix, (counts.get(prefix) ?? 0) + 1);
      }
    }
  }
  const selected = [...counts.entries()].sort(
    ([leftPrefix, leftCount], [rightPrefix, rightCount]) =>
      rightCount - leftCount ||
      leftPrefix.length - rightPrefix.length ||
      compare(leftPrefix, rightPrefix),
  )[0];
  if (!selected)
    throw new Error(
      "[license:artifact] standalone contains no policy-recognized package manifest",
    );
  return selected[0];
}

function distributionFile(
  source: string,
  value: RootDistributionFile,
): { sha256: string; distributed_path: string } {
  return typeof value === "string"
    ? { sha256: value, distributed_path: source }
    : value;
}

async function artifactLayout(
  root: string,
  policy: LicensePolicy,
): Promise<{
  standaloneRoot: string;
  payloadRoot: string;
  payloadPrefix: string;
  rawManifestPaths: string[];
}> {
  const standaloneRoot = path.join(root, "apps/web/.next/standalone");
  const files = await treeFiles(standaloneRoot);
  const rawManifestPaths = files
    .map((entry) => entry.path)
    .filter((entry) => path.posix.basename(entry) === "package.json")
    .sort(compare);
  const expected = Object.keys(policy.artifact_manifests ?? {}).sort(compare);
  const payloadPrefix = artifactPrefix(rawManifestPaths, expected);
  return {
    standaloneRoot,
    payloadRoot: path.join(standaloneRoot, payloadPrefix),
    payloadPrefix,
    rawManifestPaths,
  };
}

function directNoticePath(root: string, directory: string): string | null {
  const absolute = path.join(root, directory);
  if (!existsSync(absolute)) return null;
  const names = readdirSync(absolute);
  for (const name of names.sort(compare)) {
    if (!/^(?:license|licence|notice|copyright)(?:\.|$)/iu.test(name)) continue;
    const relative = directory === "." ? name : `${directory}/${name}`;
    if (statSync(path.join(root, relative)).isFile()) return relative;
  }
  return null;
}

export async function hydrateArtifactPolicy(
  root: string,
  policy: LicensePolicy,
): Promise<LicensePolicy> {
  if (policy.artifact_manifests) return policy;
  const expected = policy.artifact_inventory;
  if (!expected)
    throw new Error(
      "[license:policy] artifact inventory commitment is missing",
    );
  const standaloneRoot = path.join(root, "apps/web/.next/standalone");
  const files = await treeFiles(standaloneRoot);
  const rawManifests = files
    .map((entry) => entry.path)
    .filter((entry) => path.posix.basename(entry) === "package.json")
    .sort(compare);
  const rawApp = rawManifests.find(
    (entry) =>
      entry === "apps/web/package.json" ||
      entry.endsWith("/apps/web/package.json"),
  );
  if (!rawApp)
    throw new Error(
      "[license:artifact] standalone app package manifest is missing",
    );
  const prefix = rawApp.slice(0, -"apps/web/package.json".length);
  const appManifestBytes = await readFile(
    path.join(root, "apps/web/package.json"),
  );
  const appManifest = JSON.parse(appManifestBytes.toString("utf8")) as {
    name: string;
    version: string;
    license: string;
  };
  const nextManifest = JSON.parse(
    await readFile(path.join(root, "node_modules/next/package.json"), "utf8"),
  ) as { version: string };
  const manifests: Record<string, ArtifactManifestPolicy> = {};
  for (const [index, rawPath] of rawManifests.entries()) {
    const manifestPath = rawPath.startsWith(prefix)
      ? rawPath.slice(prefix.length)
      : rawPath;
    const artifact = JSON.parse(
      (await readFile(path.join(standaloneRoot, rawPath))).toString("utf8"),
    ) as { name?: string; version?: string; license?: string };
    const project =
      manifestPath === "apps/web/package.json" ||
      manifestPath === "apps/web/.next/package.json";
    const sourceManifestPath = project ? "apps/web/package.json" : manifestPath;
    const sourceManifest = await bytes(root, sourceManifestPath);
    if (!sourceManifest)
      throw new Error(
        `[license:artifact] source manifest missing for ${manifestPath}`,
      );
    const sourceValue = JSON.parse(sourceManifest.toString("utf8")) as {
      name?: string;
      version?: string;
      license?: string;
    };
    const compiledPrefix = "node_modules/next/dist/compiled/";
    const packageRoot = manifestPath.slice(0, -"/package.json".length);
    const identity =
      manifestPath === "apps/web/package.json"
        ? "project:@invoice-manager/web"
        : manifestPath === "apps/web/.next/package.json"
          ? "project:@invoice-manager/web-build-metadata"
          : manifestPath.startsWith(compiledPrefix)
            ? `vendored:next/${packageRoot.slice(compiledPrefix.length)}`
            : `npm:${artifact.name ?? sourceValue.name ?? packageRoot}`;
    const version = String(
      artifact.version ??
        sourceValue.version ??
        (manifestPath.startsWith(compiledPrefix)
          ? `${nextManifest.version}-vendored`
          : "UNKNOWN"),
    );
    const spdxExpression = String(
      artifact.license ??
        sourceValue.license ??
        (project ? appManifest.license : "UNKNOWN"),
    );
    const sourceDirectory = path.posix.dirname(sourceManifestPath);
    const sourceNoticePath = project
      ? "LICENSE"
      : directNoticePath(root, sourceDirectory);
    const sourceNotice = sourceNoticePath
      ? await bytes(root, sourceNoticePath)
      : null;
    const safeIdentity = identity.replace(/[^A-Za-z0-9._-]+/gu, "-");
    manifests[manifestPath] = {
      identity,
      version,
      spdx_expression: spdxExpression,
      source_manifest_path: sourceManifestPath,
      source_manifest_sha256: sha256(sourceManifest),
      source_notice_path: sourceNoticePath,
      source_notice_sha256: sourceNotice ? sha256(sourceNotice) : null,
      distributed_notice_path: sourceNotice
        ? `licenses/${String(index + 1).padStart(3, "0")}-${safeIdentity}.LICENSE`
        : null,
    };
  }
  const projectionSha = sha256(stableJson(manifests));
  const identities = new Set(
    Object.values(manifests).map(
      (entry) => `${entry.identity}@${entry.version}`,
    ),
  );
  if (
    Object.keys(manifests).length !== expected.manifest_count ||
    identities.size !== expected.identity_count ||
    projectionSha !== expected.projection_sha256
  ) {
    throw new Error(
      `[license:artifact] artifact manifest policy mismatch count=${Object.keys(manifests).length}/${expected.manifest_count} identities=${identities.size}/${expected.identity_count} projection=${projectionSha}/${expected.projection_sha256}`,
    );
  }
  policy.artifact_manifests = manifests;
  return policy;
}

export async function stageRuntimeNotices(
  root: string,
  policy: LicensePolicy,
): Promise<void> {
  const manifests = policy.artifact_manifests;
  if (!manifests)
    throw new Error("[license:policy] artifact manifest inventory is missing");
  const layout = await artifactLayout(root, policy);
  const noticeRoot = path.join(layout.payloadRoot, "licenses");
  await rm(noticeRoot, { force: true, recursive: true });
  await mkdir(noticeRoot, { recursive: true });

  for (const [manifestPath, entry] of Object.entries(manifests).sort(
    ([left], [right]) => compare(left, right),
  )) {
    if (
      entry.source_notice_path === null ||
      entry.source_notice_sha256 === null ||
      entry.distributed_notice_path === null
    ) {
      continue;
    }
    const source = await bytes(root, entry.source_notice_path);
    if (!source)
      throw new Error(
        `[license:artifact] source notice missing for ${manifestPath}`,
      );
    if (sha256(source) !== entry.source_notice_sha256)
      throw new Error(
        `[license:artifact] source notice digest mismatch for ${manifestPath}`,
      );
    assertRepositoryPath(entry.distributed_notice_path);
    const destination = path.join(
      layout.payloadRoot,
      ...entry.distributed_notice_path.split("/"),
    );
    await mkdir(path.dirname(destination), { recursive: true });
    await copyFile(
      path.join(root, ...entry.source_notice_path.split("/")),
      destination,
    );
  }

  for (const [sourcePath, configured] of Object.entries(
    policy.root_distribution_files ?? {},
  ).sort(([left], [right]) => compare(left, right))) {
    const entry = distributionFile(sourcePath, configured);
    const source = await bytes(root, sourcePath);
    if (!source || sha256(source) !== entry.sha256)
      throw new Error(
        `[license:artifact] root distribution evidence mismatch for ${sourcePath}`,
      );
    assertRepositoryPath(entry.distributed_path);
    for (const distributionRoot of [
      layout.payloadRoot,
      policy.zig_artifact
        ? path.join(root, ...policy.zig_artifact.root.split("/"))
        : null,
    ]) {
      if (!distributionRoot) continue;
      await mkdir(distributionRoot, { recursive: true });
      const destination = path.join(
        distributionRoot,
        ...entry.distributed_path.split("/"),
      );
      await mkdir(path.dirname(destination), { recursive: true });
      await copyFile(path.join(root, ...sourcePath.split("/")), destination);
    }
  }
}

function closestManifest(file: string, manifests: Set<string>): string | null {
  if (path.posix.basename(file) === "package.json" && manifests.has(file))
    return file;
  let directory = path.posix.dirname(file);
  for (;;) {
    const candidate =
      directory === "." ? "package.json" : `${directory}/package.json`;
    if (manifests.has(candidate)) return candidate;
    if (directory === "." || directory === "") return null;
    directory = path.posix.dirname(directory);
  }
}

export async function inventoryStandaloneArtifact(
  root: string,
  policy: LicensePolicy,
): Promise<ArtifactInventory> {
  const configured = policy.artifact_manifests ?? {};
  const expected = Object.keys(configured).sort(compare);
  const layout = await artifactLayout(root, policy);
  const rawFiles = await treeFiles(layout.standaloneRoot);
  const violations: ArtifactViolation[] = [];
  if (layout.payloadPrefix.includes(".worktrees/")) {
    violations.push({
      path: layout.payloadPrefix,
      reason: "artifact_layout_private_prefix",
      detail:
        "Standalone embeds a local worktree path; WP09 must set a repository-stable tracing root.",
    });
  }
  const normalizedFiles = new Map<string, TreeFile>();
  for (const file of rawFiles) {
    if (!file.path.startsWith(layout.payloadPrefix)) {
      violations.push({
        path: file.path,
        reason: "artifact_file_outside_payload",
        detail:
          "Every standalone file must live under one deterministic payload root.",
      });
      continue;
    }
    normalizedFiles.set(file.path.slice(layout.payloadPrefix.length), file);
  }
  const actualManifests = [...normalizedFiles.keys()]
    .filter((entry) => path.posix.basename(entry) === "package.json")
    .sort(compare);
  const actualSet = new Set(actualManifests);
  const expectedSet = new Set(expected);
  for (const manifest of actualManifests) {
    if (!expectedSet.has(manifest))
      violations.push({
        path: manifest,
        reason: "artifact_manifest_policy_unmatched",
        detail: "Artifact package manifest has no committed policy record.",
      });
  }
  for (const manifest of expected) {
    if (!actualSet.has(manifest))
      violations.push({
        path: manifest,
        reason: "artifact_manifest_policy_stale",
        detail:
          "Committed artifact policy record has no exact package manifest.",
      });
  }

  const assigned = new Map<string, string[]>();
  const noticeOwners = new Map<string, string>();
  for (const [manifest, entry] of Object.entries(configured)) {
    if (entry.distributed_notice_path)
      noticeOwners.set(entry.distributed_notice_path, manifest);
  }
  const projectManifest =
    expected.find(
      (entry) => configured[entry].identity === "project:@invoice-manager/web",
    ) ?? null;
  const rootDistributionOwners = new Map<string, string>();
  if (projectManifest) {
    for (const [source, value] of Object.entries(
      policy.root_distribution_files ?? {},
    )) {
      rootDistributionOwners.set(
        distributionFile(source, value).distributed_path,
        projectManifest,
      );
    }
  }
  for (const [source, value] of Object.entries(
    policy.root_distribution_files ?? {},
  ).sort(([left], [right]) => compare(left, right))) {
    const entry = distributionFile(source, value);
    const distributed = normalizedFiles.get(entry.distributed_path);
    if (!distributed)
      violations.push({
        path: entry.distributed_path,
        reason: "artifact_root_notice_missing",
        detail:
          "Required project/source notice is absent from the distribution.",
      });
    else if (sha256(distributed.bytes) !== entry.sha256)
      violations.push({
        path: entry.distributed_path,
        reason: "artifact_root_notice_digest_mismatch",
        detail:
          "Distributed project/source notice differs from committed evidence.",
      });
  }
  const unmapped: string[] = [];
  for (const file of [...normalizedFiles.keys()].sort(compare)) {
    const owner =
      noticeOwners.get(file) ??
      rootDistributionOwners.get(file) ??
      closestManifest(file, actualSet);
    if (!owner) {
      unmapped.push(file);
      continue;
    }
    const list = assigned.get(owner) ?? [];
    list.push(file);
    assigned.set(owner, list);
  }
  for (const file of unmapped)
    violations.push({
      path: file,
      reason: "artifact_file_unmapped",
      detail:
        "Every distributed byte must map to exactly one manifest policy record.",
    });

  const manifests: ArtifactManifestInventory[] = [];
  for (const manifestPath of actualManifests) {
    const entry = configured[manifestPath];
    if (!entry) continue;
    const artifactManifest = normalizedFiles.get(manifestPath)!;
    const parsed = JSON.parse(artifactManifest.bytes.toString("utf8")) as {
      name?: unknown;
      version?: unknown;
      license?: unknown;
    };
    const sourceManifest = await bytes(root, entry.source_manifest_path);
    if (
      !sourceManifest ||
      sha256(sourceManifest) !== entry.source_manifest_sha256
    )
      violations.push({
        path: manifestPath,
        reason: "artifact_manifest_source_drift",
        detail: "Committed source-manifest evidence is missing or has drifted.",
      });
    if (typeof parsed.version === "string" && parsed.version !== entry.version)
      violations.push({
        path: manifestPath,
        reason: "artifact_manifest_version_mismatch",
        detail: `Artifact version ${parsed.version} differs from policy ${entry.version}.`,
      });
    if (
      typeof parsed.license === "string" &&
      parsed.license !== entry.spdx_expression
    )
      violations.push({
        path: manifestPath,
        reason: "artifact_manifest_license_conflict",
        detail: `Artifact license ${parsed.license} differs from policy ${entry.spdx_expression}.`,
      });
    if (
      entry.source_notice_path === null ||
      entry.source_notice_sha256 === null ||
      entry.distributed_notice_path === null
    ) {
      violations.push({
        path: manifestPath,
        reason: "artifact_notice_policy_missing",
        detail: "Every runtime manifest requires committed notice evidence.",
      });
    } else {
      const sourceNotice = await bytes(root, entry.source_notice_path);
      if (!sourceNotice || sha256(sourceNotice) !== entry.source_notice_sha256)
        violations.push({
          path: entry.source_notice_path,
          reason: "artifact_notice_source_drift",
          detail: "Source notice is missing or differs from committed policy.",
        });
      const distributed = normalizedFiles.get(entry.distributed_notice_path);
      if (!distributed)
        violations.push({
          path: entry.distributed_notice_path,
          reason: "artifact_notice_missing",
          detail: "Required notice is absent from the standalone distribution.",
        });
      else if (sha256(distributed.bytes) !== entry.source_notice_sha256)
        violations.push({
          path: entry.distributed_notice_path,
          reason: "artifact_notice_digest_mismatch",
          detail: "Distributed notice differs from committed source evidence.",
        });
    }
    const artifactPaths = [...(assigned.get(manifestPath) ?? [])].sort(compare);
    manifests.push({
      identity: entry.identity,
      version: entry.version,
      spdx_expression: entry.spdx_expression,
      manifest_path: manifestPath,
      raw_manifest_path: artifactManifest.path,
      artifact_paths: artifactPaths,
      artifact_digest: digest(
        artifactPaths.map((file) => ({
          path: file,
          sha256: sha256(normalizedFiles.get(file)!.bytes),
        })),
      ),
      distributed_notice_path: entry.distributed_notice_path,
    });
  }
  manifests.sort((left, right) =>
    compare(left.manifest_path, right.manifest_path),
  );
  const nativeArtifacts = [...normalizedFiles.keys()]
    .filter((entry) => /\.(?:node|a|dylib|dll|so(?:\.\d+)*)$/u.test(entry))
    .sort(compare);
  const treeProjection = [...normalizedFiles.entries()]
    .sort(([left], [right]) => compare(left, right))
    .map(([file, entry]) => ({ path: file, sha256: sha256(entry.bytes) }));
  violations.sort((left, right) =>
    compare(`${left.path}\0${left.reason}`, `${right.path}\0${right.reason}`),
  );
  return {
    root: "apps/web/.next/standalone",
    payload_prefix: layout.payloadPrefix,
    file_count: normalizedFiles.size,
    tree_digest: digest(treeProjection),
    manifests,
    native_artifacts: nativeArtifacts,
    unmapped_files: unmapped,
    violations,
  };
}

export async function inventoryZigArtifact(
  root: string,
  policy: LicensePolicy,
): Promise<ZigArtifactInventory> {
  const configured = policy.zig_artifact;
  if (!configured)
    return {
      root: "",
      files: [],
      tree_digest: digest([]),
      violations: [
        {
          path: "tools/licenses/policy/runtime-policy.json",
          reason: "zig_artifact_policy_missing",
          detail: "Zig distributable policy is required.",
        },
      ],
    };
  assertRepositoryPath(configured.root);
  const artifactRoot = path.join(root, ...configured.root.split("/"));
  let files: TreeFile[] = [];
  try {
    files = await treeFiles(artifactRoot);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
  }
  const names = files.map((entry) => entry.path).sort(compare);
  const violations = configured.required_paths
    .filter((required) => !names.includes(required))
    .map((required) => ({
      path: `${configured.root}/${required}`,
      reason: "zig_artifact_required_path_missing",
      detail: "Producer build did not install the required release artifact.",
    }));
  return {
    root: configured.root,
    files: names,
    tree_digest: digest(
      files.map((entry) => ({ path: entry.path, sha256: sha256(entry.bytes) })),
    ),
    violations,
  };
}

export async function loadPolicy(root: string): Promise<LicensePolicy> {
  const value = JSON.parse(
    await readFile(
      path.join(root, "tools/licenses/policy/runtime-policy.json"),
      "utf8",
    ),
  ) as LicensePolicy;
  if (
    value.schema !== "invoice-manager.runtime-license-policy/v2" ||
    value.project_license !== "GPL-2.0-only"
  ) {
    throw new Error(
      "[license:policy] unsupported policy schema or project license",
    );
  }
  return value;
}

function artifactComponent(
  manifest: ArtifactManifestInventory,
  policy: ArtifactManifestPolicy,
  violations: ArtifactViolation[],
): LicenseComponent {
  const evidenceFailure = violations.some(
    (entry) =>
      entry.path === manifest.manifest_path ||
      entry.path === policy.source_manifest_path ||
      entry.path === policy.source_notice_path ||
      entry.path === policy.distributed_notice_path,
  );
  return {
    identity: policy.identity,
    version: policy.version,
    source: policy.source_manifest_path,
    runtime_role: policy.identity.startsWith("vendored:")
      ? "runtime-capable-vendored"
      : policy.identity.startsWith("project:")
        ? "combined-runtime"
        : "combined-runtime",
    spdx_expression: policy.spdx_expression,
    selected_license: null,
    notice_path: policy.distributed_notice_path,
    dependency_path: `standalone > ${manifest.manifest_path}`,
    evidence_path: manifest.manifest_path,
    evidence_digest: manifest.artifact_digest,
    evidence_status: evidenceFailure ? "missing" : "verified",
    disposition: "pending",
    artifact_paths: manifest.artifact_paths,
    artifact_digest: manifest.artifact_digest,
  };
}

export async function discoverRuntimeComponents(
  root: string,
  suppliedPolicy?: LicensePolicy,
  suppliedInventory?: ArtifactInventory,
): Promise<LicenseComponent[]> {
  const policy = await hydrateArtifactPolicy(
    root,
    suppliedPolicy ?? (await loadPolicy(root)),
  );
  const inventory =
    suppliedInventory ?? (await inventoryStandaloneArtifact(root, policy));
  const base = [
    ...(await npmComponents(root, policy)),
    ...(await sourceComponents(root, policy)),
  ];
  const byKey = new Map(base.map((entry) => [componentKey(entry), entry]));
  for (const manifest of inventory.manifests) {
    const configured = policy.artifact_manifests?.[manifest.manifest_path];
    if (!configured) continue;
    const component = artifactComponent(
      manifest,
      configured,
      inventory.violations,
    );
    const existing = byKey.get(componentKey(component));
    if (existing) {
      existing.artifact_paths = component.artifact_paths;
      existing.artifact_digest = component.artifact_digest;
      existing.runtime_role = component.runtime_role;
      if (component.evidence_status !== "verified")
        existing.evidence_status = component.evidence_status;
    } else {
      byKey.set(componentKey(component), component);
    }
  }
  return [...byKey.values()].sort((left, right) =>
    compare(componentKey(left), componentKey(right)),
  );
}

export async function auditRepository(
  root: string,
  suppliedPolicy?: LicensePolicy,
): Promise<LicenseReport> {
  const policy = await hydrateArtifactPolicy(
    root,
    suppliedPolicy ?? (await loadPolicy(root)),
  );
  const standalone = await inventoryStandaloneArtifact(root, policy);
  const zig = await inventoryZigArtifact(root, policy);
  const report = auditComponents(
    await discoverRuntimeComponents(root, policy, standalone),
    policy,
  );
  for (const [scope, violations] of [
    ["standalone", standalone.violations],
    ["zig", zig.violations],
  ] as const) {
    for (const entry of violations) {
      report.violations.push({
        component: `artifact:${scope}`,
        reason: entry.reason,
        dependency_path: entry.path,
        evidence: entry.path,
        policy_reason: entry.detail,
      });
    }
  }
  report.violations.sort((left, right) =>
    compare(
      `${left.component}\0${left.reason}`,
      `${right.component}\0${right.reason}`,
    ),
  );
  report.status = report.violations.length === 0 ? "compatible" : "blocked";
  report.artifacts = { standalone, zig };
  return report;
}

export function renderReport(report: LicenseReport): string {
  return stableJson(report);
}

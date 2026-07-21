import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { lstat, readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export type NoticeEvidence = { path: string; sha256: string };
export type PlatformTarget = { os: string; cpu: string; libc: string };
export type DistributionPolicy = {
  kind: "source-repository";
  shipped_surface: "git-tracked-source";
  deferred_packaging: [
    "container-image",
    "next-standalone",
    "zig-installed-binary",
  ];
};
export type ShovelerPolicy = {
  commit: string;
  source: string;
  spdx_expression: string;
  license_path: string;
  license_sha256: string;
  upstream_notice_path: string;
  upstream_notice_sha256: string;
  distribution_notice_path: string;
  distribution_notice_sha256: string;
  provenance_path: string;
  provenance_sha256: string;
  source_file_count: number;
  source_tree_sha256: string;
  code_tree_sha256: string;
  build_zig_sha256: string;
  abi_header_sha256: string;
};
export type ZigToolchainPolicy = {
  version: string;
  source: string;
  version_path: string;
};
export type LgplObligation = {
  selected_license: "LGPL-3.0-or-later";
  license_path: string;
  license_sha256: string;
  source_url: string;
  source_commit: string;
  source_archive_sha256: string;
  versions_path: string;
  versions_sha256: string;
  linked_version: string;
  dynamic_library_path: string;
  dynamic_library_sha256: string;
  relinking_mode: "replaceable-dynamic-shared-object";
  evidence_status?: "verified";
};
export type LicensePolicy = {
  schema: "invoice-manager.runtime-license-policy/v3";
  project_license: "GPL-3.0-only";
  distribution: DistributionPolicy;
  target: PlatformTarget;
  compatible_combined_runtime: string[];
  incompatible_combined_runtime: string[];
  license_selections: Record<string, string>;
  notice_evidence: Record<string, NoticeEvidence>;
  lgpl_obligations: Record<string, LgplObligation>;
  source_components: {
    shovelerdb: ShovelerPolicy;
    zig_toolchain: ZigToolchainPolicy;
  };
};

export type LgplVerification = {
  verified: boolean;
  selected_license: string;
  source_commit: string;
  source_archive_sha256: string;
  dynamic_library_sha256: string | null;
  linked_version: string;
  relinking_mode: string;
  evidence_digest: string;
};

export type LicenseComponent = {
  identity: string;
  version: string;
  source: string;
  runtime_role: "combined-runtime" | "compiled-runtime" | "build-only";
  spdx_expression: string;
  selected_license: string | null;
  notice_path: string | null;
  dependency_path: string;
  evidence_path: string;
  evidence_digest: string;
  evidence_status?: "verified" | "missing" | "mismatch" | "conflicting";
  disposition: "pending" | "compatible" | "blocked" | "build-only-proven";
  lgpl_obligation?: LgplVerification;
};

export type LicenseViolation = {
  component: string;
  reason: string;
  dependency_path: string;
  evidence: string;
  policy_reason: string;
};

export type DistributionEvidence = DistributionPolicy & {
  tracked_file_count: number;
  tracked_path_digest: string;
  prohibited_tracked_paths: string[];
};

export type LicenseReport = {
  schema: "invoice-manager.runtime-license-report/v2";
  project_license: "GPL-3.0-only";
  target: PlatformTarget;
  distribution: DistributionEvidence;
  status: "compatible" | "blocked";
  components: LicenseComponent[];
  violations: LicenseViolation[];
};

type JsonObject = { [key: string]: JsonValue };
type JsonValue = null | boolean | number | string | JsonValue[] | JsonObject;

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
    if (parent === current) {
      throw new Error("[license:path] repository root is unavailable");
    }
    current = parent;
  }
}

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
  return JSON.stringify(canonical(value as JsonValue)) + "\n";
}

function sha256(bytes: Buffer | string): string {
  return createHash("sha256").update(bytes).digest("hex");
}

function digest(value: unknown): string {
  return "sha256:" + sha256(stableJson(value));
}

function assertRepositoryPath(value: string): void {
  if (
    path.isAbsolute(value) ||
    value.includes("\\") ||
    value.split("/").some((part) => part === "" || part === "." || part === "..")
  ) {
    throw new Error("[license:policy] unsafe repository path: " + value);
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
  return component.identity + "@" + component.version;
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
    evidence: component.evidence_path + " " + component.evidence_digest,
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
  ) {
    return [];
  }
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
            "Build-only exclusions require deterministic source-distribution evidence.",
          ),
        );
      } else {
        component.disposition = "build-only-proven";
      }
      continue;
    }

    if (component.evidence_status !== "verified") {
      component.disposition = "blocked";
      violations.push(
        violation(
          component,
          "evidence_" + (component.evidence_status ?? "missing"),
          "Complete committed license and notice evidence must exist and match its SHA-256 digest.",
        ),
      );
    }

    const expression = component.spdx_expression.trim();
    if (
      expression === "" ||
      expression === "UNKNOWN" ||
      expression === "UNLICENSED" ||
      expression.startsWith("SEE LICENSE IN")
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
          "Compound, exception, and nuanced expressions remain blocked until explicitly selected and reviewed.",
        ),
      );
      continue;
    } else {
      selected = expression;
      component.selected_license = expression;
    }

    if (selected !== null && incompatible.has(selected)) {
      component.disposition = "blocked";
      violations.push(
        violation(
          component,
          "license_incompatible",
          selected + " is incompatible with the GPL-3.0-only combined runtime policy.",
        ),
      );
    } else if (selected !== null && compatible.has(selected)) {
      if (component.disposition !== "blocked") component.disposition = "compatible";
    } else {
      component.disposition = "blocked";
      violations.push(
        violation(
          component,
          "license_unreviewed",
          (selected ?? expression) +
            " has no committed GPL-3.0-only compatibility decision.",
        ),
      );
    }

    if (selected?.startsWith("LGPL-")) {
      const staticEvidence = policy.lgpl_obligations[key]?.evidence_status;
      if (
        component.lgpl_obligation?.verified !== true &&
        staticEvidence !== "verified"
      ) {
        component.disposition = "blocked";
        violations.push(
          violation(
            component,
            "lgpl_obligations_missing",
            "LGPL components require an explicit selected license plus verified source and relinking evidence.",
          ),
        );
      }
    }
  }

  violations.sort((left, right) =>
    compare(
      left.component + "\0" + left.reason,
      right.component + "\0" + right.reason,
    ),
  );
  return {
    schema: "invoice-manager.runtime-license-report/v2",
    project_license: "GPL-3.0-only",
    target: policy.target,
    distribution: {
      ...policy.distribution,
      tracked_file_count: 0,
      tracked_path_digest: digest([]),
      prohibited_tracked_paths: [],
    },
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
    if (strings.includes("!" + expected)) return false;
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
    const candidate = path.posix.join(directory, "node_modules", dependencyName);
    if (packages[candidate]) return candidate;
    if (directory === "" || directory === ".") break;
    directory = path.posix.dirname(directory);
    if (path.posix.basename(directory) === "node_modules") {
      directory = path.posix.dirname(directory);
    }
    if (directory === ".") directory = "";
  }
  const rootCandidate = "node_modules/" + dependencyName;
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
  if (!root) throw new Error("[license:lock] missing production root " + rootKey);
  const optionalRoot =
    typeof root.optionalDependencies === "object" &&
    root.optionalDependencies !== null
      ? root.optionalDependencies
      : {};
  const queue = dependencies(root).map((dependencyName) => ({
    parentKey: rootKey,
    dependencyName,
    chain: dependencyName,
    optional: dependencyName in optionalRoot,
  }));
  const seen = new Set<string>();
  const result: LockedProductionNode[] = [];
  while (queue.length > 0) {
    queue.sort((left, right) =>
      compare(
        left.parentKey + "\0" + left.dependencyName + "\0" + left.chain,
        right.parentKey + "\0" + right.dependencyName + "\0" + right.chain,
      ),
    );
    const edge = queue.shift()!;
    const key = resolveLockDependency(packages, edge.parentKey, edge.dependencyName);
    if (!key) {
      throw new Error("[license:lock] unresolved production edge " + edge.chain);
    }
    const record = packages[key];
    if (!platformAllows(record, target)) {
      if (edge.optional) continue;
      throw new Error(
        "[license:lock] required production edge excludes " +
          target.os +
          "/" +
          target.cpu +
          "/" +
          target.libc +
          ": " +
          edge.chain,
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
    const version = typeof record.version === "string" ? "@" + record.version : "";
    for (const dependencyName of dependencies(record)) {
      queue.push({
        parentKey: key,
        dependencyName,
        chain: edge.chain + version + " > " + dependencyName,
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
  if (!lock.packages) throw new Error("[license:lock] package-lock.json lacks packages");
  const graph = traverseProductionLock(lock.packages, "apps/web", policy.target).filter(
    (entry) => entry.key !== "node_modules/@invoice-manager/contracts",
  );
  const result: LicenseComponent[] = [];
  for (const { key, chain, record } of graph) {
    const name = key.slice("node_modules/".length);
    const version = typeof record.version === "string" ? record.version : "UNKNOWN";
    const identity = "npm:" + name;
    const policyKey = identity + "@" + version;
    const notice = policy.notice_evidence[policyKey];
    const noticeBytes = notice ? await bytes(root, notice.path) : null;
    const manifestBytes = await bytes(root, key + "/package.json");
    const manifest = manifestBytes
      ? (JSON.parse(manifestBytes.toString("utf8")) as { license?: unknown })
      : {};
    const lockLicense =
      typeof record.license === "string" ? record.license : "UNKNOWN";
    const manifestLicense =
      typeof manifest.license === "string" ? manifest.license : "UNKNOWN";
    let evidenceStatus: LicenseComponent["evidence_status"] = "verified";
    if (
      typeof record.resolved !== "string" ||
      !record.resolved.startsWith("https://registry.npmjs.org/") ||
      typeof record.integrity !== "string"
    ) {
      evidenceStatus = "missing";
    } else if (!notice || !noticeBytes) {
      evidenceStatus = "missing";
    } else if (sha256(noticeBytes) !== notice.sha256) {
      evidenceStatus = "mismatch";
    } else if (!manifestBytes || manifestLicense !== lockLicense) {
      evidenceStatus = "conflicting";
    }

    const component: LicenseComponent = {
      identity,
      version,
      source: typeof record.resolved === "string" ? record.resolved : "UNPINNED",
      runtime_role: "combined-runtime",
      spdx_expression: lockLicense,
      selected_license: null,
      notice_path: notice?.path ?? null,
      dependency_path: chain,
      evidence_path: "package-lock.json#packages/" + key.replaceAll("/", "~1"),
      evidence_digest: digest({
        lock_record: record,
        package_manifest_sha256: manifestBytes ? sha256(manifestBytes) : null,
        notice_sha256: noticeBytes ? sha256(noticeBytes) : null,
      }),
      evidence_status: evidenceStatus,
      disposition: "pending",
    };
    const obligation = policy.lgpl_obligations[policyKey];
    if (obligation) {
      component.lgpl_obligation = await verifyLgplObligation(
        root,
        policyKey,
        obligation,
      );
    }
    result.push(component);
  }
  return result;
}

type TreeDigest = { paths: string[]; digest: string };

async function collectRegularFiles(
  root: string,
  relative: string,
): Promise<string[]> {
  const absolute = path.join(root, ...relative.split("/"));
  const metadata = await lstat(absolute);
  if (!metadata.isDirectory()) {
    if (!metadata.isFile()) {
      throw new Error("[license:source] non-regular source entry " + relative);
    }
    return [relative];
  }
  const output: string[] = [];
  const entries = await readdir(absolute, { withFileTypes: true });
  for (const entry of entries.sort((left, right) => compare(left.name, right.name))) {
    const child = relative + "/" + entry.name;
    if (entry.isDirectory()) output.push(...(await collectRegularFiles(root, child)));
    else if (entry.isFile()) output.push(child);
    else throw new Error("[license:source] non-regular source entry " + child);
  }
  return output;
}

async function treeDigest(
  root: string,
  paths: string[],
  stripPrefix: string,
): Promise<TreeDigest> {
  const sorted = [...paths].sort(compare);
  const lines: string[] = [];
  for (const relative of sorted) {
    const content = await readFile(path.join(root, ...relative.split("/")));
    lines.push(sha256(content) + "  " + relative.slice(stripPrefix.length));
  }
  return { paths: sorted, digest: sha256(lines.join("\n") + "\n") };
}

export async function verifyShovelerEvidence(
  root: string,
  policy: ShovelerPolicy,
): Promise<{
  verified: boolean;
  file_count: number;
  source_tree_sha256: string;
  code_tree_sha256: string;
  provenance_sha256: string | null;
  license_sha256: string | null;
  notice_sha256: string | null;
  distribution_notice_sha256: string | null;
  build_zig_sha256: string | null;
  abi_header_sha256: string | null;
}> {
  const prefix = "deps/shovelerdb/";
  const codePaths = [
    ...(await collectRegularFiles(root, "deps/shovelerdb/include")),
    ...(await collectRegularFiles(root, "deps/shovelerdb/src")),
  ];
  const sourcePaths = [
    "deps/shovelerdb/LICENSE",
    "deps/shovelerdb/NOTICE",
    "deps/shovelerdb/build.zig",
    ...codePaths,
  ];
  const sourceTree = await treeDigest(root, sourcePaths, prefix);
  const codeTree = await treeDigest(root, codePaths, prefix);
  const [provenance, license, notice, distributionNotice, buildZig, header] =
    await Promise.all([
      bytes(root, policy.provenance_path),
      bytes(root, policy.license_path),
      bytes(root, policy.upstream_notice_path),
      bytes(root, policy.distribution_notice_path),
      bytes(root, "deps/shovelerdb/build.zig"),
      bytes(root, "deps/shovelerdb/include/shovelerdb.h"),
    ]);
  const fields = new Map<string, string>();
  let unique = provenance !== null;
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
  const observed = {
    file_count: sourcePaths.length,
    source_tree_sha256: sourceTree.digest,
    code_tree_sha256: codeTree.digest,
    provenance_sha256: provenance ? sha256(provenance) : null,
    license_sha256: license ? sha256(license) : null,
    notice_sha256: notice ? sha256(notice) : null,
    distribution_notice_sha256: distributionNotice
      ? sha256(distributionNotice)
      : null,
    build_zig_sha256: buildZig ? sha256(buildZig) : null,
    abi_header_sha256: header ? sha256(header) : null,
  };
  return {
    verified:
      unique &&
      fields.get("component") === "ShovelerDB" &&
      fields.get("source_url") === policy.source &&
      fields.get("commit") === policy.commit &&
      fields.get("engine_license") === "GPL-3.0-only" &&
      fields.get("source_file_count") === String(policy.source_file_count) &&
      fields.get("source_tree_sha256") === policy.source_tree_sha256 &&
      fields.get("code_tree_sha256") === policy.code_tree_sha256 &&
      fields.get("license_sha256") === policy.license_sha256 &&
      fields.get("notice_sha256") === policy.upstream_notice_sha256 &&
      fields.get("build_zig_sha256") === policy.build_zig_sha256 &&
      fields.get("abi_header_sha256") === policy.abi_header_sha256 &&
      observed.file_count === policy.source_file_count &&
      observed.source_tree_sha256 === policy.source_tree_sha256 &&
      observed.code_tree_sha256 === policy.code_tree_sha256 &&
      observed.provenance_sha256 === policy.provenance_sha256 &&
      observed.license_sha256 === policy.license_sha256 &&
      observed.notice_sha256 === policy.upstream_notice_sha256 &&
      observed.distribution_notice_sha256 ===
        policy.distribution_notice_sha256 &&
      observed.build_zig_sha256 === policy.build_zig_sha256 &&
      observed.abi_header_sha256 === policy.abi_header_sha256,
    ...observed,
  };
}

export async function verifyLgplObligation(
  root: string,
  _componentKey: string,
  obligation: LgplObligation,
): Promise<LgplVerification> {
  for (const relative of [
    obligation.license_path,
    obligation.versions_path,
    obligation.dynamic_library_path,
  ]) {
    assertRepositoryPath(relative);
  }
  const [license, versions, library] = await Promise.all([
    bytes(root, obligation.license_path),
    bytes(root, obligation.versions_path),
    bytes(root, obligation.dynamic_library_path),
  ]);
  let regular = false;
  try {
    regular = (
      await lstat(
        path.join(root, ...obligation.dynamic_library_path.split("/")),
      )
    ).isFile();
  } catch {
    regular = false;
  }
  let linkedVersion: unknown = null;
  try {
    linkedVersion = versions
      ? (JSON.parse(versions.toString("utf8")) as { vips?: unknown }).vips
      : null;
  } catch {
    linkedVersion = null;
  }
  const librarySha = library ? sha256(library) : null;
  const verified =
    obligation.selected_license === "LGPL-3.0-or-later" &&
    /^[0-9a-f]{40}$/u.test(obligation.source_commit) &&
    obligation.source_url.includes(obligation.source_commit) &&
    /^[0-9a-f]{64}$/u.test(obligation.source_archive_sha256) &&
    obligation.relinking_mode === "replaceable-dynamic-shared-object" &&
    license !== null &&
    sha256(license) === obligation.license_sha256 &&
    versions !== null &&
    sha256(versions) === obligation.versions_sha256 &&
    linkedVersion === obligation.linked_version &&
    regular &&
    library !== null &&
    library.length >= 4 &&
    library[0] === 0x7f &&
    library[1] === 0x45 &&
    library[2] === 0x4c &&
    library[3] === 0x46 &&
    librarySha === obligation.dynamic_library_sha256;
  const projection = {
    selected_license: obligation.selected_license,
    license_sha256: license ? sha256(license) : null,
    source_url: obligation.source_url,
    source_commit: obligation.source_commit,
    source_archive_sha256: obligation.source_archive_sha256,
    versions_sha256: versions ? sha256(versions) : null,
    linked_version: linkedVersion,
    dynamic_library_sha256: librarySha,
    relinking_mode: obligation.relinking_mode,
  };
  return {
    verified,
    selected_license: obligation.selected_license,
    source_commit: obligation.source_commit,
    source_archive_sha256: obligation.source_archive_sha256,
    dynamic_library_sha256: librarySha,
    linked_version: obligation.linked_version,
    relinking_mode: obligation.relinking_mode,
    evidence_digest: digest(projection),
  };
}

async function sourceComponents(
  root: string,
  policy: LicensePolicy,
): Promise<LicenseComponent[]> {
  const shoveler = policy.source_components.shovelerdb;
  const shovelerEvidence = await verifyShovelerEvidence(root, shoveler);
  const zig = policy.source_components.zig_toolchain;
  const zigVersion = await bytes(root, zig.version_path);
  return [
    {
      identity: "source:shovelerdb",
      version: shoveler.commit,
      source: shoveler.source + "#" + shoveler.commit,
      runtime_role: "compiled-runtime",
      spdx_expression: shoveler.spdx_expression,
      selected_license: null,
      notice_path: shoveler.distribution_notice_path,
      dependency_path: "services/api > deps/shovelerdb",
      evidence_path: shoveler.provenance_path,
      evidence_digest: digest(shovelerEvidence),
      evidence_status: shovelerEvidence.verified ? "verified" : "mismatch",
      disposition: "pending",
    },
    {
      identity: "toolchain:zig",
      version: zig.version,
      source: zig.source,
      runtime_role: "build-only",
      spdx_expression: "MIT",
      selected_license: "MIT",
      notice_path: null,
      dependency_path: "P0 source build prerequisite",
      evidence_path: zig.version_path,
      evidence_digest: digest({
        version_sha256: zigVersion ? sha256(zigVersion) : null,
        distribution: policy.distribution,
      }),
      evidence_status:
        zigVersion?.toString("utf8") === zig.version + "\n"
          ? "verified"
          : "mismatch",
      disposition: "pending",
    },
  ];
}

async function projectComponent(root: string): Promise<LicenseComponent> {
  const [manifestBytes, license] = await Promise.all([
    bytes(root, "package.json"),
    bytes(root, "LICENSE"),
  ]);
  const manifest = manifestBytes
    ? (JSON.parse(manifestBytes.toString("utf8")) as {
        name?: unknown;
        version?: unknown;
        license?: unknown;
      })
    : {};
  const verified =
    manifest.name === "invoice-manager" &&
    manifest.version === "0.0.0" &&
    manifest.license === "GPL-3.0-only" &&
    license !== null &&
    sha256(license) ===
      "3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986";
  return {
    identity: "project:invoice-manager",
    version: typeof manifest.version === "string" ? manifest.version : "UNKNOWN",
    source: "git-tracked-source",
    runtime_role: "combined-runtime",
    spdx_expression:
      typeof manifest.license === "string" ? manifest.license : "UNKNOWN",
    selected_license: null,
    notice_path: "LICENSE",
    dependency_path: "source-repository",
    evidence_path: "package.json + LICENSE",
    evidence_digest: digest({
      package_manifest_sha256: manifestBytes ? sha256(manifestBytes) : null,
      license_sha256: license ? sha256(license) : null,
    }),
    evidence_status: verified ? "verified" : "mismatch",
    disposition: "pending",
  };
}

export async function discoverRuntimeComponents(
  root: string,
  suppliedPolicy?: LicensePolicy,
): Promise<LicenseComponent[]> {
  const policy = suppliedPolicy ?? (await loadPolicy(root));
  return [
    await projectComponent(root),
    ...(await npmComponents(root, policy)),
    ...(await sourceComponents(root, policy)),
  ].sort((left, right) => compare(componentKey(left), componentKey(right)));
}

async function distributionEvidence(
  root: string,
  policy: LicensePolicy,
): Promise<DistributionEvidence> {
  const { stdout } = await execFileAsync("git", ["ls-files", "-z"], {
    cwd: root,
    encoding: "buffer",
    maxBuffer: 64 * 1024 * 1024,
  });
  const paths = stdout
    .toString("utf8")
    .split("\0")
    .filter(Boolean)
    .sort(compare);
  const prohibited = paths.filter(
    (entry) =>
      entry.includes("/.next/") ||
      entry === ".next" ||
      entry.startsWith("node_modules/") ||
      entry.startsWith("zig-out/") ||
      entry.startsWith("tools/licenses/.runtime/") ||
      /(?:^|\/)(?:container-image|image)\.(?:tar|oci)$/u.test(entry),
  );
  return {
    ...policy.distribution,
    tracked_file_count: paths.length,
    tracked_path_digest: digest(paths),
    prohibited_tracked_paths: prohibited,
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
    value.schema !== "invoice-manager.runtime-license-policy/v3" ||
    value.project_license !== "GPL-3.0-only" ||
    value.distribution?.kind !== "source-repository" ||
    value.distribution.shipped_surface !== "git-tracked-source" ||
    stableJson(value.distribution.deferred_packaging) !==
      stableJson([
        "container-image",
        "next-standalone",
        "zig-installed-binary",
      ])
  ) {
    throw new Error(
      "[license:policy] unsupported policy schema, project license, or P0 distribution boundary",
    );
  }
  return value;
}

export async function auditRepository(
  root: string,
  suppliedPolicy?: LicensePolicy,
): Promise<LicenseReport> {
  const policy = suppliedPolicy ?? (await loadPolicy(root));
  const report = auditComponents(
    await discoverRuntimeComponents(root, policy),
    policy,
  );
  report.distribution = await distributionEvidence(root, policy);
  for (const tracked of report.distribution.prohibited_tracked_paths) {
    report.violations.push({
      component: "distribution:source-repository",
      reason: "built_artifact_tracked",
      dependency_path: tracked,
      evidence: tracked,
      policy_reason:
        "P0 ships GPL-3.0-only source; container, standalone, and installed Zig binary packaging is deferred to P3.",
    });
  }
  report.violations.sort((left, right) =>
    compare(
      left.component + "\0" + left.reason,
      right.component + "\0" + right.reason,
    ),
  );
  report.status = report.violations.length === 0 ? "compatible" : "blocked";
  return report;
}

export function renderReport(report: LicenseReport): string {
  return stableJson(report);
}

export { sha256 };

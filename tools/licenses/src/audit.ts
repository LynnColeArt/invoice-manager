import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

type NoticeEvidence = { path: string; sha256: string };
type ShovelerPolicy = {
  commit: string;
  source: string;
  spdx_expression: string;
  license_path: string;
  license_sha256: string;
  notice_path: string;
  notice_sha256: string;
  provenance_path: string;
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
type VendoredPolicy = {
  identity: string;
  manifest_path: string;
  notice_path: string;
  notice_sha256: string;
};

export type LicensePolicy = {
  schema: "invoice-manager.runtime-license-policy/v1";
  project_license: "GPL-2.0-only";
  target?: { os: "linux"; cpu: "x64"; libc: "glibc" };
  compatible_combined_runtime: string[];
  incompatible_combined_runtime: string[];
  license_selections: Record<string, string>;
  notice_evidence?: Record<string, NoticeEvidence>;
  source_components?: { shovelerdb: ShovelerPolicy; zig_stdlib: ZigPolicy };
  next_vendored_runtime?: VendoredPolicy[];
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
  target: { os: "linux"; cpu: "x64"; libc: "glibc" };
  status: "compatible" | "blocked";
  components: LicenseComponent[];
  violations: LicenseViolation[];
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

function applicable(record: Record<string, unknown>): boolean {
  const permits = (field: "os" | "cpu" | "libc", expected: string): boolean => {
    const values = record[field];
    if (!Array.isArray(values)) return true;
    const strings = values.filter(
      (entry): entry is string => typeof entry === "string",
    );
    return strings.includes(expected) && !strings.includes(`!${expected}`);
  };
  return (
    permits("os", "linux") && permits("cpu", "x64") && permits("libc", "glibc")
  );
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
  const web = JSON.parse(
    await readFile(path.join(root, "apps/web/package.json"), "utf8"),
  ) as { dependencies?: Record<string, string> };
  const queue = Object.keys(web.dependencies ?? {})
    .filter((name) => name !== "@invoice-manager/contracts")
    .sort(compare)
    .map((name) => ({
      key: `node_modules/${name}`,
      chain: `@invoice-manager/web > ${name}`,
    }));
  const chains = new Map<string, string>();
  while (queue.length > 0) {
    const current = queue.shift()!;
    if (chains.has(current.key)) continue;
    const record: Record<string, unknown> | undefined = packages[current.key];
    if (!record)
      throw new Error(
        `[license:lock] unresolved production dependency ${current.key}`,
      );
    if (!applicable(record)) continue;
    chains.set(current.key, current.chain);
    for (const dependencyName of dependencies(record)) {
      const key = `node_modules/${dependencyName}`;
      if (packages[key] && applicable(packages[key]))
        queue.push({
          key,
          chain: `${current.chain} > ${dependencyName}`,
        });
    }
    queue.sort((left, right) =>
      compare(`${left.key}\0${left.chain}`, `${right.key}\0${right.chain}`),
    );
  }

  const result: LicenseComponent[] = [];
  for (const [key, chain] of [...chains.entries()].sort(([left], [right]) =>
    compare(left, right),
  )) {
    const record: Record<string, unknown> = packages[key];
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

async function sourceComponents(
  root: string,
  policy: LicensePolicy,
): Promise<LicenseComponent[]> {
  if (!policy.source_components) return [];
  const shoveler = policy.source_components.shovelerdb;
  const [provenance, license, notice] = await Promise.all([
    bytes(root, shoveler.provenance_path),
    bytes(root, shoveler.license_path),
    bytes(root, shoveler.notice_path),
  ]);
  const treeDigest = await sourceTreeDigest(root);
  const exactProvenance =
    provenance?.toString("utf8").includes(`commit=${shoveler.commit}`) ===
      true &&
    provenance
      .toString("utf8")
      .includes(`source_tree_sha256=${shoveler.source_tree_sha256}`);
  const shovelerVerified =
    exactProvenance &&
    license !== null &&
    sha256(license) === shoveler.license_sha256 &&
    notice !== null &&
    sha256(notice) === shoveler.notice_sha256 &&
    treeDigest === shoveler.source_tree_sha256;

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
      evidence_digest: digest({
        provenance_sha256: provenance ? sha256(provenance) : null,
        license_sha256: license ? sha256(license) : null,
        notice_sha256: notice ? sha256(notice) : null,
        source_tree_sha256: treeDigest,
      }),
      evidence_status: shovelerVerified ? "verified" : "mismatch",
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

async function vendoredComponents(
  root: string,
  policy: LicensePolicy,
): Promise<LicenseComponent[]> {
  const nextLock = JSON.parse(
    await readFile(path.join(root, "package-lock.json"), "utf8"),
  ) as { packages: Record<string, { version?: string; resolved?: string }> };
  const next = nextLock.packages["node_modules/next"];
  const version = next.version ?? "UNKNOWN";
  const result: LicenseComponent[] = [];
  for (const entry of [...(policy.next_vendored_runtime ?? [])].sort(
    (left, right) => compare(left.identity, right.identity),
  )) {
    const [manifest, notice] = await Promise.all([
      bytes(root, entry.manifest_path),
      bytes(root, entry.notice_path),
    ]);
    const parsed = manifest
      ? (JSON.parse(manifest.toString("utf8")) as { license?: unknown })
      : {};
    const noticeDigest = notice ? sha256(notice) : null;
    result.push({
      identity: `vendored:next/${entry.identity}`,
      version,
      source: `${next.resolved ?? "UNPINNED"}#${entry.manifest_path.slice("node_modules/next/".length)}`,
      runtime_role: "runtime-capable-vendored",
      spdx_expression:
        typeof parsed.license === "string" ? parsed.license : "UNKNOWN",
      selected_license: null,
      notice_path: entry.notice_path,
      dependency_path: `@invoice-manager/web > next > vendored ${entry.identity}`,
      evidence_path: entry.manifest_path,
      evidence_digest: digest({
        manifest_sha256: manifest ? sha256(manifest) : null,
        notice_sha256: noticeDigest,
      }),
      evidence_status:
        manifest && notice && noticeDigest === entry.notice_sha256
          ? "verified"
          : manifest && notice
            ? "mismatch"
            : "missing",
      disposition: "pending",
    });
  }
  return result;
}

export async function loadPolicy(root: string): Promise<LicensePolicy> {
  const value = JSON.parse(
    await readFile(
      path.join(root, "tools/licenses/policy/runtime-policy.json"),
      "utf8",
    ),
  ) as LicensePolicy;
  if (
    value.schema !== "invoice-manager.runtime-license-policy/v1" ||
    value.project_license !== "GPL-2.0-only"
  ) {
    throw new Error(
      "[license:policy] unsupported policy schema or project license",
    );
  }
  return value;
}

export async function discoverRuntimeComponents(
  root: string,
  suppliedPolicy?: LicensePolicy,
): Promise<LicenseComponent[]> {
  const policy = suppliedPolicy ?? (await loadPolicy(root));
  return [
    ...(await npmComponents(root, policy)),
    ...(await sourceComponents(root, policy)),
    ...(await vendoredComponents(root, policy)),
  ].sort((left, right) => compare(componentKey(left), componentKey(right)));
}

export function renderReport(report: LicenseReport): string {
  return stableJson(report);
}

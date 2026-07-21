import { spawn } from "node:child_process";
import {
  access,
  mkdtemp,
  readFile,
  readdir,
  readlink,
  rm,
} from "node:fs/promises";
import dns from "node:dns/promises";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const node = process.execPath;
const isPrivateNetnsWorker = process.argv[2] === "--private-netns-worker";
const fixtureScript = path.join(
  root,
  "apps/web/tests/foundation/proxy-fixture.mjs",
);
const children = new Set();
const knownPorts = new Map();
let shuttingDown = false;
let cleanupPromise;
let temporaryDirectory;
let signalCount = 0;

const inheritedEnvironmentDenylist = [
  "INVOICE_MANAGER_API_ORIGIN",
  "WP10_FIXTURE_CONTROL_ORIGIN",
  "WP10_PRIVATE_NETNS",
  "WP10_PROXY_PROFILE",
];

function log(message) {
  console.log(`[http-smoke] ${message}`);
}

function spawnOwned(command, args, options = {}) {
  const environment = { ...process.env };
  for (const name of inheritedEnvironmentDenylist) delete environment[name];
  Object.assign(environment, options.env);
  for (const name of options.unsetEnv ?? []) delete environment[name];
  const child = spawn(command, args, {
    cwd: root,
    detached: true,
    env: environment,
    stdio: options.stdio ?? ["ignore", "pipe", "pipe"],
  });
  children.add(child);
  child.once("exit", () => {
    children.delete(child);
    try {
      process.kill(-child.pid, "SIGTERM");
    } catch (error) {
      if (error.code !== "ESRCH") {
        console.error(
          `[http-smoke:error] failed to clear process group ${child.pid}: ${error}`,
        );
        process.exitCode = 1;
      }
    }
  });
  return child;
}

async function stopChild(child) {
  if (child.exitCode !== null || child.signalCode !== null) return;
  const exited = new Promise((resolve) => child.once("exit", resolve));
  try {
    process.kill(-child.pid, "SIGTERM");
  } catch (error) {
    if (error.code !== "ESRCH") throw error;
  }
  const graceful = await Promise.race([
    exited.then(() => true),
    new Promise((resolve) => setTimeout(() => resolve(false), 10_000)),
  ]);
  if (!graceful) {
    try {
      process.kill(-child.pid, "SIGKILL");
    } catch (error) {
      if (error.code !== "ESRCH") throw error;
    }
    await exited;
  }
}

async function stopAll() {
  if (shuttingDown) return;
  shuttingDown = true;
  await Promise.allSettled([...children].map(stopChild));
  shuttingDown = false;
}

for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(signal, () => {
    signalCount += 1;
    if (signalCount > 1) process.exit(128 + os.constants.signals[signal]);
    void cleanupResources()
      .then(() => process.exit(128 + os.constants.signals[signal]))
      .catch((error) => {
        console.error(`[http-smoke:error] signal cleanup failed: ${error}`);
        process.exit(1);
      });
  });
}

function waitForExit(child, label, timeoutMs = 120_000) {
  return new Promise((resolve, reject) => {
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      void stopChild(child).then(
        () => reject(new Error(`${label} timed out after ${timeoutMs} ms`)),
        reject,
      );
    }, timeoutMs);
    child.once("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });
    child.once("exit", (code, signal) => {
      clearTimeout(timer);
      if (timedOut) return;
      if (code === 0) resolve();
      else
        reject(
          new Error(
            `${label} exited code=${String(code)} signal=${String(signal)}`,
          ),
        );
    });
  });
}

function waitForReadyLine(child, pattern, label, timeoutMs = 30_000) {
  return new Promise((resolve, reject) => {
    let stderr = "";
    const timer = setTimeout(() => {
      cleanup();
      reject(
        new Error(`${label} startup timed out; stderr=${stderr.slice(-1_000)}`),
      );
    }, timeoutMs);
    const onData = (chunk) => {
      const text = chunk.toString("utf8");
      stderr += text;
      process.stderr.write(text);
      const match = stderr.match(pattern);
      if (match) {
        cleanup();
        resolve(Number(match[1]));
      }
    };
    const onExit = (code, signal) => {
      cleanup();
      reject(
        new Error(
          `${label} exited before readiness code=${String(code)} signal=${String(signal)}; stderr=${stderr.slice(-1_000)}`,
        ),
      );
    };
    function cleanup() {
      clearTimeout(timer);
      child.stderr.off("data", onData);
      child.off("exit", onExit);
    }
    child.stderr.on("data", onData);
    child.once("exit", onExit);
  });
}

function portKey(host, port) {
  return `${host}:${port}`;
}

function rememberPort(host, port, label) {
  knownPorts.set(portKey(host, port), { host, port, label });
}

function forgetPort(host, port) {
  knownPorts.delete(portKey(host, port));
}

function canBind(host, port) {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.unref();
    server.once("error", () => resolve(false));
    server.listen({ host, port, exclusive: true }, () => {
      server.close(() => resolve(true));
    });
  });
}

async function requirePortFree(port, label, host = "127.0.0.1") {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    if (await canBind(host, port)) return;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(`${label} did not release ${host}:${port}`);
}

async function localhostAddresses() {
  const resolved = await dns.lookup("localhost", { all: true });
  return [
    ...new Set(["127.0.0.1", "::1", ...resolved.map(({ address }) => address)]),
  ];
}

async function requireLocalhostPortFree(port, label) {
  for (const host of await localhostAddresses()) {
    await requirePortFree(port, label, host);
  }
}

function cleanupResources() {
  cleanupPromise ??= (async () => {
    await stopAll();
    if (isPrivateNetnsWorker)
      await requireLocalhostPortFree(3000, "Next.js cleanup");
    for (const { host, port, label } of knownPorts.values()) {
      await requirePortFree(port, label, host);
    }
    knownPorts.clear();
    if (temporaryDirectory !== undefined) {
      await rm(temporaryDirectory, { recursive: true, force: true });
      temporaryDirectory = undefined;
    }
  })();
  return cleanupPromise;
}

async function runCaptured(command, args) {
  const child = spawnOwned(command, args);
  let stdout = "";
  let stderr = "";
  child.stdout.on("data", (chunk) => {
    stdout += chunk.toString("utf8");
  });
  child.stderr.on("data", (chunk) => {
    stderr += chunk.toString("utf8");
  });
  await waitForExit(child, `${command} ${args.join(" ")}`, 30_000);
  if (stderr !== "") process.stderr.write(stderr);
  return stdout.trim();
}

async function runPlaywright(label, apiOrigin, extraEnv = {}) {
  await requireLocalhostPortFree(3000, `${label} preflight`);
  log(
    `phase=${label} origin=${apiOrigin === undefined ? "unset" : "server-only"}`,
  );
  const child = spawnOwned(
    "npm",
    ["run", "test:e2e", "--workspace", "@invoice-manager/web"],
    {
      env: {
        ...extraEnv,
        ...(apiOrigin === undefined
          ? {}
          : { INVOICE_MANAGER_API_ORIGIN: apiOrigin }),
      },
      unsetEnv:
        apiOrigin === undefined ? ["INVOICE_MANAGER_API_ORIGIN"] : undefined,
      stdio: "inherit",
    },
  );
  await waitForExit(child, `Playwright ${label}`, 180_000);
  await requireLocalhostPortFree(3000, `${label} Next.js`);
}

async function startFixture(profileName) {
  const child = spawnOwned(node, [fixtureScript, profileName]);
  child.stdout.on("data", (chunk) => process.stdout.write(chunk));
  const port = await waitForReadyLine(
    child,
    new RegExp(
      `\\[fixture:ready\\] listening port=([0-9]+) profile=${profileName}`,
    ),
    `fixture ${profileName}`,
  );
  rememberPort("127.0.0.1", port, `fixture ${profileName}`);
  return { child, port, origin: `http://127.0.0.1:${port}` };
}

async function runFixtureProfile(profileName) {
  const fixture = await startFixture(profileName);
  try {
    await runPlaywright(profileName, fixture.origin, {
      WP10_FIXTURE_CONTROL_ORIGIN: fixture.origin,
      WP10_PROXY_PROFILE: profileName,
    });
  } finally {
    await stopChild(fixture.child);
    await requirePortFree(fixture.port, `fixture ${profileName}`);
    forgetPort("127.0.0.1", fixture.port);
  }
}

function waitForAnyExit(child, timeoutMs = 30_000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error("cleanup probe exit timed out")),
      timeoutMs,
    );
    child.once("exit", (code, signal) => {
      clearTimeout(timer);
      resolve({ code, signal });
    });
  });
}

async function signalCleanupProbeMain() {
  const probeDirectory = process.argv[3];
  if (probeDirectory === undefined)
    throw new Error("signal cleanup probe directory is missing");
  temporaryDirectory = probeDirectory;
  const fixture = await startFixture("non-json");
  console.error(`[cleanup-probe:ready] port=${fixture.port}`);
  await new Promise(() => {});
}

async function runLifecycleCleanupProbes() {
  const failureFixture = await startFixture("non-json");
  try {
    throw new Error("deliberate lifecycle failure probe");
  } catch (error) {
    if (
      !(error instanceof Error) ||
      error.message !== "deliberate lifecycle failure probe"
    )
      throw error;
  } finally {
    await stopChild(failureFixture.child);
    await requirePortFree(failureFixture.port, "failure cleanup probe");
    forgetPort("127.0.0.1", failureFixture.port);
  }

  const timeoutFixture = await startFixture("non-json");
  const timeoutStarted = performance.now();
  try {
    await waitForExit(
      timeoutFixture.child,
      "deliberate lifecycle timeout probe",
      25,
    );
    throw new Error("timeout cleanup probe unexpectedly completed");
  } catch (error) {
    if (
      !(error instanceof Error) ||
      (!error.message.includes("timed out after 25 ms") &&
        !error.message.includes("signal=SIGTERM")) ||
      performance.now() - timeoutStarted < 20
    ) {
      throw error;
    }
  } finally {
    await requirePortFree(timeoutFixture.port, "timeout cleanup probe");
    forgetPort("127.0.0.1", timeoutFixture.port);
  }

  const probeDirectory = await mkdtemp(
    path.join(os.tmpdir(), "invoice-manager-wp10-signal-"),
  );
  try {
    const signalProbe = spawnOwned(node, [
      path.resolve(process.argv[1]),
      "--signal-cleanup-probe",
      probeDirectory,
    ]);
    signalProbe.stdout.on("data", (chunk) => process.stdout.write(chunk));
    const signalPort = await waitForReadyLine(
      signalProbe,
      /\[cleanup-probe:ready\] port=([0-9]+)/,
      "signal cleanup probe",
    );
    const terminationPromise = waitForAnyExit(signalProbe);
    signalProbe.kill("SIGTERM");
    const termination = await terminationPromise;
    if (termination.code !== 143) {
      throw new Error(
        `signal cleanup probe exited code=${String(termination.code)} signal=${String(termination.signal)}`,
      );
    }
    await requirePortFree(signalPort, "signal cleanup probe");
    try {
      await access(probeDirectory);
      throw new Error("signal cleanup probe retained its temporary directory");
    } catch (error) {
      if (
        error instanceof Error &&
        "code" in error &&
        error.code === "ENOENT"
      ) {
        // Expected: the signal handler used the same resource cleanup path.
      } else {
        throw error;
      }
    }
  } finally {
    await rm(probeDirectory, { recursive: true, force: true });
  }
  log("failure, timeout, and signal cleanup probes passed");
}

async function scanFiles(directory, needle) {
  const entries = await readdir(directory, { withFileTypes: true });
  for (const entry of entries) {
    const candidate = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      if (await scanFiles(candidate, needle)) return true;
    } else if ((await readFile(candidate)).includes(needle)) {
      return true;
    }
  }
  return false;
}

async function innerMain() {
  if (process.version !== "v24.18.0")
    throw new Error(`Node drift: ${process.version}`);
  const expectedParentNamespace = process.argv[3];
  const workerNamespace = await readlink("/proc/self/ns/net");
  if (
    process.argv[2] !== "--private-netns-worker" ||
    expectedParentNamespace === undefined ||
    workerNamespace === expectedParentNamespace
  ) {
    throw new Error("private network namespace worker attestation failed");
  }
  await requireLocalhostPortFree(3000, "initial smoke preflight");
  const [npmVersion, zigVersion, candidate, indexTree, trackedStatus] =
    await Promise.all([
      runCaptured("npm", ["--version"]),
      runCaptured("zig", ["version"]),
      runCaptured("git", ["rev-parse", "HEAD"]),
      runCaptured("git", ["write-tree"]),
      runCaptured("git", ["status", "--porcelain", "--untracked-files=no"]),
    ]);
  log(
    `evidence=diagnostic runner=${os.platform()}-${os.arch()} cpu=${JSON.stringify(os.cpus()[0]?.model ?? "unknown")} logical_cpus=${os.cpus().length} ram_bytes=${os.totalmem()} node=${process.version.slice(1)} npm=${npmVersion} zig=${zigVersion} candidate_commit=${candidate} candidate_index_tree=${indexTree} tracked_clean=${trackedStatus === ""} netns=${workerNamespace}`,
  );

  await runLifecycleCleanupProbes();

  temporaryDirectory = await mkdtemp(
    path.join(os.tmpdir(), "invoice-manager-wp10-"),
  );
  const databasePath = path.join(temporaryDirectory, "foundation.shovel");
  let zig;
  let zigPort;
  try {
    zig = spawnOwned(
      "zig",
      [
        "build",
        "run",
        "--build-file",
        "services/api/build.zig",
        "-Doptimize=ReleaseSafe",
      ],
      {
        env: {
          INVOICE_API_BIND: "127.0.0.1",
          INVOICE_API_PORT: "0",
          INVOICE_DATABASE_PATH: databasePath,
        },
      },
    );
    zig.stdout.on("data", (chunk) => process.stdout.write(chunk));
    zigPort = await waitForReadyLine(
      zig,
      /\[api:ready\] listening port=([0-9]+)/,
      "WP08 ReleaseSafe Zig",
      60_000,
    );
    rememberPort("127.0.0.1", zigPort, "Zig cleanup");
    const zigOrigin = `http://127.0.0.1:${zigPort}`;
    await runPlaywright("real-ready", zigOrigin, {
      WP10_PROXY_PROFILE: "real-ready",
    });
    if (
      await scanFiles(path.join(root, "apps/web/.next"), Buffer.from(zigOrigin))
    ) {
      throw new Error("production assets contain the internal Zig origin");
    }
    await stopChild(zig);
    await requirePortFree(zigPort, "stopped Zig");
    forgetPort("127.0.0.1", zigPort);
    await runPlaywright("stopped-zig", zigOrigin, {
      WP10_PROXY_PROFILE: "stopped",
    });
    zig = undefined;

    await runPlaywright("missing-origin", undefined, {
      WP10_PROXY_PROFILE: "stopped",
    });
    await runPlaywright(
      "invalid-origin",
      "http://user:secret@127.0.0.1:9/path",
      {
        WP10_PROXY_PROFILE: "stopped",
      },
    );

    for (const fixtureProfile of [
      "canonical-503",
      "redirect",
      "slow",
      "slow-non-json",
      "declared-oversize",
      "streamed-oversize",
      "non-json",
      "media-type-spoof",
      "malformed-json",
      "malformed-envelope",
      "unexpected-status",
      "header-leak",
    ]) {
      await runFixtureProfile(fixtureProfile);
    }
  } finally {
    if (zig !== undefined) await stopChild(zig);
    await cleanupResources();
  }
  await requireLocalhostPortFree(3000, "final Next.js cleanup");
  log(
    "all real Ready, stopped, invalid-config, adversarial, performance, and cleanup phases passed",
  );
}

async function outerMain() {
  const parentNamespace = await readlink("/proc/self/ns/net");
  const child = spawnOwned(
    "unshare",
    [
      "--user",
      "--map-current-user",
      "--keep-caps",
      "--net",
      "sh",
      "-ceu",
      'ip link set lo up; exec "$@"',
      "invoice-wp10-netns",
      node,
      path.resolve(process.argv[1]),
      "--private-netns-worker",
      parentNamespace,
    ],
    { stdio: "inherit" },
  );
  await waitForExit(child, "private network namespace smoke", 600_000);
}

try {
  if (process.argv[2] === "--signal-cleanup-probe")
    await signalCleanupProbeMain();
  else if (isPrivateNetnsWorker) await innerMain();
  else await outerMain();
} catch (error) {
  console.error(
    `[http-smoke:error] ${error instanceof Error ? error.stack : String(error)}`,
  );
  await cleanupResources();
  process.exitCode = 1;
}

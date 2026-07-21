import { defineConfig } from "@playwright/test";

const WEB_ORIGIN = "http://localhost:3000";

export default defineConfig({
  testDir: "./tests/foundation",
  testMatch: "**/*.e2e.ts",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  repeatEach: 1,
  timeout: 15_000,
  globalTimeout: 120_000,
  maxFailures: 1,
  forbidOnly: true,
  failOnFlakyTests: true,
  captureGitInfo: {
    commit: false,
    diff: false,
  },
  reporter: [["line"]],
  outputDir: "test-results",
  expect: {
    timeout: 5_000,
  },
  use: {
    baseURL: WEB_ORIGIN,
    browserName: "chromium",
    headless: true,
    locale: "en-US",
    timezoneId: "UTC",
    colorScheme: "light",
    serviceWorkers: "block",
    acceptDownloads: false,
    permissions: [],
    screenshot: "off",
    trace: "off",
    video: "off",
  },
  webServer: {
    command: "npm run start -- --hostname localhost --port 3000",
    url: WEB_ORIGIN,
    reuseExistingServer: false,
    timeout: 30_000,
    stdout: "pipe",
    stderr: "pipe",
  },
});

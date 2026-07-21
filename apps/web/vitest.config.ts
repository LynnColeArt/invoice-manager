import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["tests/foundation/**/*.test.{ts,tsx}"],
    environment: "jsdom",
    environmentOptions: {
      jsdom: {
        url: "http://component-test.invalid/",
      },
    },
    watch: false,
    isolate: true,
    fileParallelism: false,
    maxWorkers: 1,
    maxConcurrency: 1,
    testTimeout: 5_000,
    hookTimeout: 5_000,
    teardownTimeout: 5_000,
    retry: 0,
    bail: 1,
    allowOnly: false,
    passWithNoTests: false,
    clearMocks: true,
    mockReset: true,
    restoreMocks: true,
    unstubEnvs: true,
    unstubGlobals: true,
    sequence: {
      concurrent: false,
      shuffle: false,
      hooks: "list",
      setupFiles: "list",
    },
    reporters: ["default"],
  },
});

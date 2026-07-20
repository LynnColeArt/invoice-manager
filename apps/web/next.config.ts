import type { NextConfig } from "next";

const API_ORIGIN_ENVIRONMENT_VARIABLE = "INVOICE_MANAGER_API_ORIGIN";

function readApiOrigin(): string {
  const configuredOrigin = process.env[API_ORIGIN_ENVIRONMENT_VARIABLE];

  if (configuredOrigin === undefined || configuredOrigin.length === 0) {
    throw new Error(
      `[web:config] ${API_ORIGIN_ENVIRONMENT_VARIABLE} must define the internal Zig API origin`,
    );
  }

  if (configuredOrigin !== configuredOrigin.trim()) {
    throw new Error(
      `[web:config] ${API_ORIGIN_ENVIRONMENT_VARIABLE} must not contain surrounding whitespace`,
    );
  }

  let parsedOrigin: URL;
  try {
    parsedOrigin = new URL(configuredOrigin);
  } catch {
    throw new Error(
      `[web:config] ${API_ORIGIN_ENVIRONMENT_VARIABLE} must be an absolute HTTP(S) origin`,
    );
  }

  const isHttp = parsedOrigin.protocol === "http:" || parsedOrigin.protocol === "https:";
  const isBareOrigin =
    parsedOrigin.pathname === "/" && parsedOrigin.search === "" && parsedOrigin.hash === "";

  if (
    !isHttp ||
    !isBareOrigin ||
    parsedOrigin.username !== "" ||
    parsedOrigin.password !== ""
  ) {
    throw new Error(
      `[web:config] ${API_ORIGIN_ENVIRONMENT_VARIABLE} must be an absolute HTTP(S) origin without credentials, path, query, or fragment`,
    );
  }

  return parsedOrigin.origin;
}

const apiOrigin = readApiOrigin();

const nextConfig: NextConfig = {
  output: "standalone",
  poweredByHeader: false,
  reactStrictMode: true,
  typescript: {
    ignoreBuildErrors: false,
    tsconfigPath: "tsconfig.json",
  },
  async rewrites() {
    return [
      {
        source: "/api/v1/:path*",
        destination: `${apiOrigin}/api/v1/:path*`,
      },
    ];
  },
};

export default nextConfig;

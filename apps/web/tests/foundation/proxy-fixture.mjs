import http from "node:http";

const profile = process.argv[2];
const supported = new Set([
  "canonical-503",
  "declared-oversize",
  "header-leak",
  "malformed-envelope",
  "malformed-json",
  "media-type-spoof",
  "non-json",
  "redirect",
  "slow",
  "slow-non-json",
  "streamed-oversize",
  "unexpected-status",
]);

if (!supported.has(profile)) {
  console.error("[fixture:error] unsupported profile");
  process.exit(2);
}

const fixedRequestId = "018f08c4-2f44-7abc-8abc-1234567890ab";
const observations = [];

function snapshot(request) {
  const observation = {
    method: request.method,
    url: request.url,
    headers: request.headers,
    aborted_before_end: false,
    closed_ms: null,
  };
  const started = performance.now();
  observations.push(observation);
  return { observation, started };
}

function sendJson(response, status, body, headers = {}) {
  const text = JSON.stringify(body);
  response.writeHead(status, {
    "content-length": Buffer.byteLength(text),
    "content-type": "application/json; charset=utf-8",
    ...headers,
  });
  response.end(text);
}

const server = http.createServer((request, response) => {
  if (request.url === "/__control__/reset") {
    observations.length = 0;
    response.writeHead(204);
    response.end();
    return;
  }
  if (request.url === "/__control__/snapshot") {
    sendJson(response, 200, { observations });
    return;
  }

  const tracked = snapshot(request);
  response.on("close", () => {
    tracked.observation.aborted_before_end = !response.writableEnded;
    tracked.observation.closed_ms = performance.now() - tracked.started;
  });
  if (request.url !== "/api/v1/health") {
    if (profile === "redirect" && request.url === "/redirect-middle") {
      response.writeHead(302, {
        location: `http://127.0.0.1:${server.address().port}/redirect-sink`,
      });
      response.end();
      return;
    }
    sendJson(response, 200, {
      sink: "destination-followed",
      internal_origin: `http://127.0.0.1:${server.address().port}`,
    });
    return;
  }

  switch (profile) {
    case "canonical-503":
      sendJson(response, 503, {
        error: {
          code: "service_not_ready",
          message: "The service is not ready.",
        },
        meta: { request_id: fixedRequestId },
      });
      return;
    case "redirect":
      response.writeHead(302, {
        location: `http://127.0.0.1:${server.address().port}/redirect-middle`,
        "set-cookie": "fixture_secret=do-not-forward",
        "x-internal-origin": `http://127.0.0.1:${server.address().port}`,
      });
      response.end("internal redirect body");
      return;
    case "slow": {
      const timer = setTimeout(() => {
        if (response.destroyed) return;
        sendJson(response, 200, {
          data: { status: "ready" },
          meta: { request_id: fixedRequestId },
        });
      }, 1_250);
      response.on("close", () => clearTimeout(timer));
      return;
    }
    case "declared-oversize": {
      const body = "x".repeat(16 * 1024 + 1);
      response.writeHead(200, {
        "content-length": Buffer.byteLength(body),
        "content-type": "application/json",
      });
      response.end(body);
      return;
    }
    case "streamed-oversize":
      response.writeHead(200, { "content-type": "application/json" });
      response.write("x".repeat(9 * 1024));
      setImmediate(() => response.end("x".repeat(9 * 1024)));
      return;
    case "non-json":
      response.writeHead(200, {
        "content-type": "text/plain",
        "set-cookie": "fixture_secret=do-not-forward",
      });
      response.end(
        `secret internal origin http://127.0.0.1:${server.address().port}`,
      );
      return;
    case "slow-non-json": {
      response.writeHead(200, { "content-type": "text/plain" });
      response.flushHeaders();
      const timer = setTimeout(
        () => response.end("late internal diagnostic"),
        5_000,
      );
      response.on("close", () => clearTimeout(timer));
      return;
    }
    case "media-type-spoof":
      response.writeHead(200, { "content-type": "application/jsonp" });
      response.end(
        JSON.stringify({
          data: { status: "ready" },
          meta: { request_id: fixedRequestId },
        }),
      );
      return;
    case "malformed-json":
      response.writeHead(200, { "content-type": "application/json" });
      response.end(
        `{"internal_origin":"http://127.0.0.1:${server.address().port}"`,
      );
      return;
    case "malformed-envelope":
      sendJson(response, 200, {
        data: {
          status: "ready",
          internal_origin: `http://127.0.0.1:${server.address().port}`,
        },
        meta: { request_id: fixedRequestId },
      });
      return;
    case "unexpected-status":
      sendJson(response, 418, {
        error: {
          code: "internal_fixture",
          message: "internal socket diagnostic",
        },
        meta: { request_id: fixedRequestId },
      });
      return;
    case "header-leak":
      sendJson(
        response,
        200,
        { data: { status: "ready" }, meta: { request_id: fixedRequestId } },
        {
          location: `http://127.0.0.1:${server.address().port}/destination-sink`,
          "set-cookie": "fixture_secret=do-not-forward",
          "x-internal-origin": `http://127.0.0.1:${server.address().port}`,
        },
      );
      return;
  }
});

server.on("clientError", (_error, socket) => socket.destroy());
server.listen({ host: "127.0.0.1", port: 0, exclusive: true }, () => {
  const address = server.address();
  if (typeof address === "string" || address === null) {
    console.error("[fixture:error] missing TCP address");
    process.exitCode = 1;
    server.close();
    return;
  }
  console.error(
    `[fixture:ready] listening port=${address.port} profile=${profile}`,
  );
});

function shutdown() {
  server.closeAllConnections();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 1_000).unref();
}

process.once("SIGINT", shutdown);
process.once("SIGTERM", shutdown);

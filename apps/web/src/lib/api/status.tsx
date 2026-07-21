"use client";

import { useEffect, useState } from "react";

import { requestHealth } from "./client";

export type FoundationState =
  | { kind: "checking" }
  | { kind: "ready"; requestId: string }
  | {
      kind: "unavailable";
      code: string;
      message: string;
      requestId: string;
    };

export function FoundationStatusView({
  state,
}: Readonly<{ state: FoundationState }>) {
  return (
    <main id="main-content" className="foundation-shell" tabIndex={-1}>
      <header className="foundation-header">
        <p className="eyebrow">Technical foundation</p>
        <h1>Invoice Manager foundation</h1>
        <p className="lede">
          The application boundary is intentionally small while its contracts,
          storage, and service lifecycle are being proven.
        </p>
      </header>

      <section
        className="status-panel"
        aria-labelledby="service-status-heading"
      >
        <h2 id="service-status-heading">Service status</h2>
        {state.kind === "checking" ? (
          <p className="status-line" aria-live="polite">
            Checking service readiness
          </p>
        ) : null}
        {state.kind === "ready" ? (
          <div className="status-copy">
            <p className="status-line" aria-live="polite">
              Service ready
            </p>
            <p className="technical-detail">
              Request <code>{state.requestId}</code>
            </p>
          </div>
        ) : null}
        {state.kind === "unavailable" ? (
          <div className="error-summary" tabIndex={-1}>
            <div role="alert">
              <h3>Service unavailable</h3>
              <p>{state.message}</p>
            </div>
            <p className="technical-detail">
              <code>{state.code}</code> · Request <code>{state.requestId}</code>
            </p>
          </div>
        ) : null}
      </section>
    </main>
  );
}

export function FoundationHealthStatus() {
  const [state, setState] = useState<FoundationState>({ kind: "checking" });

  useEffect(() => {
    let active = true;
    void requestHealth().then((result) => {
      if (!active) return;
      setState(
        result.ok
          ? { kind: "ready", requestId: result.value.meta.request_id }
          : {
              kind: "unavailable",
              code: result.error.error.code,
              message: result.error.error.message,
              requestId: result.error.meta.request_id,
            },
      );
    });
    return () => {
      active = false;
    };
  }, []);

  return <FoundationStatusView state={state} />;
}

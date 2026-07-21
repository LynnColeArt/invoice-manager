import "@testing-library/jest-dom/vitest";

import { render } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { FoundationStatusView } from "../../src/lib/api/status";

describe("foundation accessibility contract", () => {
  it("keeps the status announcement textual and the error summary keyboard focusable", () => {
    const { container, rerender } = render(
      <FoundationStatusView state={{ kind: "checking" }} />,
    );

    expect(container.querySelector("[aria-live='polite']")).toHaveTextContent(
      "Checking service readiness",
    );

    rerender(
      <FoundationStatusView
        state={{
          kind: "unavailable",
          code: "service_not_ready",
          message: "The service is not ready.",
          requestId: "018f08c4-2f44-7abc-8abc-1234567890ab",
        }}
      />,
    );
    expect(container.querySelector(".error-summary")).toHaveAttribute(
      "tabindex",
      "-1",
    );
    expect(container.querySelector("[role='alert']")).not.toHaveTextContent(
      requestIdForTest,
    );
  });
});

const requestIdForTest = "018f08c4-2f44-7abc-8abc-1234567890ab";

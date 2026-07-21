import "@testing-library/jest-dom/vitest";

import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { FoundationStatusView } from "../../src/lib/api/status";

describe("foundation shell", () => {
  it("presents one main landmark, a logical heading, and an explicit service state", () => {
    const { container } = render(
      <FoundationStatusView
        state={{
          kind: "ready",
          requestId: "018f08c4-2f44-7abc-8abc-1234567890ab",
        }}
      />,
    );

    expect(container.querySelectorAll("main")).toHaveLength(1);
    expect(
      screen.getByRole("heading", {
        level: 1,
        name: "Invoice Manager foundation",
      }),
    ).toBeVisible();
    expect(screen.getByText("Service ready")).toBeVisible();
    expect(screen.getByText(/018f08c4/)).toBeVisible();
  });

  it("renders a focusable, restrained live error summary", () => {
    render(
      <FoundationStatusView
        state={{
          kind: "unavailable",
          code: "service_not_ready",
          message: "The service is not ready.",
          requestId: "018f08c4-2f44-7abc-8abc-1234567890ab",
        }}
      />,
    );

    const summary = screen.getByRole("alert").parentElement;
    expect(summary).not.toBeNull();
    expect(summary).toHaveAttribute("tabindex", "-1");
    expect(summary).toHaveTextContent("Service unavailable");
    expect(summary).toHaveTextContent("The service is not ready.");
  });

  it("does not imply that later business features already exist", () => {
    render(<FoundationStatusView state={{ kind: "checking" }} />);

    expect(screen.getByText("Checking service readiness")).toBeVisible();
    expect(screen.queryByRole("navigation")).not.toBeInTheDocument();
    expect(screen.queryByRole("form")).not.toBeInTheDocument();
    for (const feature of [
      "Invoices",
      "Clients",
      "Projects",
      "Dashboard",
      "Reporting",
    ]) {
      expect(
        screen.queryByText(feature, { exact: true }),
      ).not.toBeInTheDocument();
    }
  });
});

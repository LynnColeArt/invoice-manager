import {
  handleApiV1BaseGet,
  handleUnsupportedMethod,
} from "../../../lib/api/server";

export const dynamic = "force-dynamic";

export function GET(): Response {
  return handleApiV1BaseGet();
}

export const HEAD = handleUnsupportedMethod;
export const OPTIONS = handleUnsupportedMethod;
export const POST = handleUnsupportedMethod;
export const PUT = handleUnsupportedMethod;
export const PATCH = handleUnsupportedMethod;
export const DELETE = handleUnsupportedMethod;

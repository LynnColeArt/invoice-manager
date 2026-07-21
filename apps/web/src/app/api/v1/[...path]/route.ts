import {
  handleApiV1Get,
  handleUnsupportedMethod,
} from "../../../../lib/api/server";

export const dynamic = "force-dynamic";

export async function GET(
  request: Request,
  context: { params: Promise<{ path: string[] }> },
): Promise<Response> {
  await context.params;
  return handleApiV1Get(request);
}

export const HEAD = handleUnsupportedMethod;
export const OPTIONS = handleUnsupportedMethod;
export const POST = handleUnsupportedMethod;
export const PUT = handleUnsupportedMethod;
export const PATCH = handleUnsupportedMethod;
export const DELETE = handleUnsupportedMethod;

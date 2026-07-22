export type ContractDiagnostic = {
  code: string;
  pointer: string;
  message: string;
  line?: number;
};

export class ContractError extends Error {
  readonly code: string;
  readonly pointer: string;
  readonly line?: number;

  constructor(code: string, pointer: string, message: string, line?: number) {
    super(message);
    this.name = "ContractError";
    this.code = code;
    this.pointer = pointer;
    this.line = line;
  }

  diagnostic(): ContractDiagnostic {
    return {
      code: this.code,
      pointer: this.pointer,
      message: this.message,
      ...(this.line === undefined ? {} : { line: this.line }),
    };
  }
}

export function fail(code: string, pointer: string, message: string, line?: number): never {
  throw new ContractError(code, pointer, message, line);
}

export function asContractError(error: unknown): ContractError {
  if (error instanceof ContractError) return error;
  const message = error instanceof Error ? error.message : "Unknown contract failure";
  return new ContractError("contract_internal_error", "", message);
}

import type { ApiService } from '../core/api';
import { FINDING_CHECKS, Findings } from '../core/findings';
import { FixFinding } from '../core/fix-finding';
import { stubExplainEntry, type ExplainEntryState } from './explain-entry';

/** One request a stubbed transport was asked for -- `testing/system-info.ts`'s shape. */
export interface StubbedFindingsCall {
  readonly path: string;
  readonly method: string;
}

export type StubbedFindings = Findings & {
  readonly calls: readonly StubbedFindingsCall[];
  /** Change what the next `load()` answers. */
  setBody(body: unknown): void;
  /** Flip the transport after construction. */
  setUnreachable(unreachable: boolean): void;
};

/** An answer with every check `checked` and no finding. */
export function cleanFindingsBody(): { checks: object[]; findings: object[] } {
  return {
    checks: FINDING_CHECKS.map((check) => ({ check, status: 'checked' })),
    findings: [],
  };
}

/**
 * A `Findings` over a stubbed `GET /ui/findings`, for the specs that mount Home. The real class
 * over a stubbed transport, so its narrowing and parking run unchanged.
 */
export function stubFindings(seed: { readonly body?: unknown; readonly unreachable?: boolean } = {}): StubbedFindings {
  const calls: StubbedFindingsCall[] = [];
  let body: unknown = seed.body ?? cleanFindingsBody();
  let unreachable = seed.unreachable === true;
  const api = {
    requestJson: async (path: string, init: { method?: string } = {}) => {
      calls.push({ path, method: init.method ?? 'GET' });
      if (unreachable) return { kind: 'error', status: 0, code: null, reason: null, detail: null };
      return { kind: 'ok', status: 200, body: JSON.parse(JSON.stringify(body)) };
    },
  };
  return Object.assign(new Findings({ api: api as unknown as ApiService }), {
    calls: calls as readonly StubbedFindingsCall[],
    setBody(next: unknown) {
      body = next;
    },
    setUnreachable(next: boolean) {
      unreachable = next;
    },
  });
}

/**
 * A real `FixFinding` over `stubExplainEntry`'s gate, whose facts a spec sets through `state` and
 * announces with `fire()`.
 */
export function stubFixFinding(overrides: Partial<ExplainEntryState> = {}): {
  readonly fix: FixFinding;
  readonly state: ExplainEntryState;
  readonly fire: () => void;
} {
  const { entry, state, fire } = stubExplainEntry(overrides);
  return { fix: new FixFinding({ explainEntry: entry }), state, fire };
}

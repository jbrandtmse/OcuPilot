import type { ApiService } from '../core/api';
import type { ConnectivityService } from '../core/connectivity';
import { Guardrails } from '../core/guardrails';

/** One request a stubbed transport was asked for -- `testing/findings.ts`'s shape. */
export interface StubbedGuardrailsCall {
  readonly path: string;
  readonly method: string;
}

export type StubbedGuardrails = Guardrails & {
  readonly calls: readonly StubbedGuardrailsCall[];
  /** Change what the next `load()` answers. */
  setBody(body: unknown): void;
  /** Flip the transport after construction. */
  setUnreachable(unreachable: boolean): void;
  /** Make every read answer with this failing HTTP status (0 is unreachable), or `null` to answer. */
  setStatus(status: number | null): void;
};

/** A small well-formed answer: two refused codes, two tools on one screen, one secret. */
export function guardrailsBody(): Record<string, unknown> {
  return {
    prohibited: [
      { code: 'PROBE.FIRST', reason: 'The first probe refusal.' },
      { code: 'PROBE.SECOND', reason: 'The second probe refusal.' },
    ],
    switches: { killSwitch: false, killSwitchAudience: '', enforcedReadOnly: false },
    confirmTools: [
      { name: 'permissions.users.delete', descriptor: 'OcuPilot.Screen.Descriptor.UserList' },
      { name: 'permissions.users.password', descriptor: 'OcuPilot.Screen.Descriptor.UserList' },
    ],
    secrets: [{ tool: 'permissions.users.password', fields: ['Password'] }],
    limits: { contextRowCap: 200, totalMaxLength: 65536, fieldMaxLength: 1000, turnsPerHour: 0 },
  };
}

/**
 * A `Guardrails` over a stubbed `GET /ui/guardrails`, for the specs that mount the page or the
 * shell. The real class over a stubbed transport, so its narrowing runs unchanged.
 */
export function stubGuardrails(
  seed: { readonly body?: unknown; readonly unreachable?: boolean; readonly connectivity?: ConnectivityService } = {}
): StubbedGuardrails {
  const calls: StubbedGuardrailsCall[] = [];
  let body: unknown = seed.body ?? guardrailsBody();
  let unreachable = seed.unreachable === true;
  let failing: number | null = null;
  const api = {
    requestJson: async (path: string, init: { method?: string } = {}) => {
      calls.push({ path, method: init.method ?? 'GET' });
      if (failing !== null) return { kind: 'error', status: failing, code: null, reason: null, detail: null };
      if (unreachable) return { kind: 'error', status: 0, code: null, reason: null, detail: null };
      return { kind: 'ok', status: 200, body: JSON.parse(JSON.stringify(body)) };
    },
  };
  return Object.assign(new Guardrails({ api: api as unknown as ApiService, connectivity: seed.connectivity ?? null }), {
    calls: calls as readonly StubbedGuardrailsCall[],
    setBody(next: unknown) {
      body = next;
    },
    setUnreachable(next: boolean) {
      unreachable = next;
    },
    setStatus(next: number | null) {
      failing = next;
    },
  });
}

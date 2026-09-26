import type { ApiService } from '../core/api';
import {
  SYSTEM_INFO_FIELDS,
  SystemInfo,
  type SystemInfoField,
} from '../core/system-info';

/** One request a stubbed transport was asked for -- `testing/about.ts`'s shape. */
export interface StubbedSystemInfoCall {
  readonly path: string;
  readonly method: string;
}

export type StubbedSystemInfo = SystemInfo & {
  readonly calls: readonly StubbedSystemInfoCall[];
  /** Change what the next `load()` answers, so a spec can drive a degraded answer in place. */
  setFields(fields: Partial<Record<SystemInfoField, string>>): void;
  /** Flip the transport after construction, so one store can answer and then stop answering. */
  setUnreachable(unreachable: boolean): void;
};

/** What one stub answers, defaulted per member so a spec names only what it is about. */
export interface StubbedSystemInfoSeed {
  readonly fields?: Partial<Record<SystemInfoField, string>>;
  /** When true the transport never answers, which is the store's unreachable branch. */
  readonly unreachable?: boolean;
}

/**
 * A `SystemInfo` over a stubbed `GET /ui/system`, for the specs that mount something which
 * injects it without being about it, and for the ones that are -- mirrors `testing/about.ts`.
 *
 * The real class over a stubbed transport, so a spec that arranges "the instance says this"
 * arranges it the way the instance does, and the store's own parking and narrowing run unchanged.
 */
export function stubSystemInfo(seed: StubbedSystemInfoSeed = {}): StubbedSystemInfo {
  const calls: StubbedSystemInfoCall[] = [];
  const fields: Record<string, string> = {};
  for (const field of SYSTEM_INFO_FIELDS) fields[field] = seed.fields?.[field] ?? `${field}-value`;

  let unreachable = seed.unreachable === true;
  const api = {
    requestJson: async (path: string, init: { method?: string } = {}) => {
      calls.push({ path, method: init.method ?? 'GET' });
      if (unreachable) {
        return { kind: 'error', status: 0, code: null, reason: null, detail: null };
      }
      return { kind: 'ok', status: 200, body: { ...fields } };
    },
  };

  return Object.assign(new SystemInfo({ api: api as unknown as ApiService }), {
    calls: calls as readonly StubbedSystemInfoCall[],
    setFields(next: Partial<Record<SystemInfoField, string>>) {
      for (const [key, value] of Object.entries(next)) fields[key] = value;
    },
    setUnreachable(next: boolean) {
      unreachable = next;
    },
  });
}

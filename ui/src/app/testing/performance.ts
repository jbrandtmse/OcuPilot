import type { AccountPreferences } from '../core/account-preferences';
import type { ApiService } from '../core/api';
import { ChangeBus } from '../core/change-bus';
import type { ConnectivityService } from '../core/connectivity';
import { PERFORMANCE_FIELDS, PerformanceRow, type PerformanceField } from '../core/performance';
import { RefreshService } from '../core/refresh';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';

/** One request a stubbed transport was asked for -- `testing/system-info.ts`'s shape. */
export interface StubbedPerformanceCall {
  readonly path: string;
}

export type StubbedPerformanceRow = PerformanceRow & {
  readonly calls: readonly StubbedPerformanceCall[];
  /** Change what the next read answers, so a spec can move the values in place. */
  setValues(values: Partial<Record<PerformanceField, number>>): void;
  /** Answer the next reads with this HTTP status and no values; `200` answers the values again. */
  setStatus(status: number): void;
  /** Move the clock the next answer is plotted at, in milliseconds. */
  setNow(ms: number): void;
};

/** What one stub answers, defaulted so a spec names only what it is about. */
export interface StubbedPerformanceSeed {
  readonly values?: Partial<Record<PerformanceField, number>>;
  /** The HTTP status every read answers until `setStatus` moves it; `200` by default. */
  readonly status?: number;
}

/**
 * A `PerformanceRow` over a stubbed `GET /ui/performance`, for the specs that mount something
 * which injects it without being about it, and for the ones that are.
 *
 * The real class over a stubbed transport, so a spec that arranges "the instance says this"
 * arranges it the way the instance does, and the store's own 403 and fault handling run unchanged.
 */
export function stubPerformanceRow(seed: StubbedPerformanceSeed = {}): StubbedPerformanceRow {
  const calls: StubbedPerformanceCall[] = [];
  const values: Record<string, number> = {};
  PERFORMANCE_FIELDS.forEach((field, index) => {
    values[field] = seed.values?.[field] ?? (index + 1) * 1000;
  });
  let status = seed.status ?? 200;
  let now = 1_700_000_000_000;

  const api = {
    requestJson: async (path: string) => {
      calls.push({ path });
      if (status === 200) return { kind: 'ok', status: 200, body: { ...values } };
      return { kind: 'error', status, code: status === 403 ? 'AUTH.NOPRIVILEGE' : null, reason: null, detail: null };
    },
  };

  return Object.assign(new PerformanceRow({ api: api as unknown as ApiService, now: () => now }), {
    calls: calls as readonly StubbedPerformanceCall[],
    setValues(next: Partial<Record<PerformanceField, number>>) {
      for (const [key, value] of Object.entries(next)) values[key] = value as number;
    },
    setStatus(next: number) {
      status = next;
    },
    setNow(ms: number) {
      now = ms;
    },
  });
}

/** An arm the injected `schedule` seam was handed, for a spec to fire by hand. */
export interface ScheduledArm {
  readonly run: () => void;
  readonly delayMs: number;
}

/**
 * The refresh framework Home binds, wired the way `src/main.ts` wires it but with the timer in the
 * spec's hands: nothing fires until the spec runs an arm from `scheduled`, and a fault parks
 * nothing.
 */
export function homeRefresh(account: AccountPreferences): {
  readonly refresh: RefreshService;
  readonly stores: ScreenStores;
  readonly actions: ScreenActions;
  readonly scheduled: ScheduledArm[];
} {
  const scheduled: ScheduledArm[] = [];
  const stores = new ScreenStores({ account });
  const connectivity = { retryWhenReachable: () => undefined } as unknown as ConnectivityService;
  const refresh = new RefreshService({
    stores,
    connectivity,
    bus: new ChangeBus(),
    namespace: () => 'HSCUSTOM',
    schedule: (run, delayMs) => scheduled.push({ run, delayMs }),
  });
  return { refresh, stores, actions: new ScreenActions(), scheduled };
}

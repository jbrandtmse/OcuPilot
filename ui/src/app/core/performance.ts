/**
 * Home's performance row (Story 16.18): five instance metrics over `/api/ocupilot/ui/performance`,
 * and the ten-minute Global references line drawn from the answers this Home view received.
 *
 * **Its read is Home's refresh read.** Home joins AD-43's roster, and the shared framework calls
 * `read` on every tick; the store answers it in `RefreshReadResult`'s own terms. A success is one
 * row carrying the five numbers, which the framework writes into Home's `ScreenStore` -- the row a
 * turn's screen context sends (AD-24). A 403 is an answer, not a fault: the caller may not read the
 * metrics, so the row, its line and the context row all go and no fault stamp is raised. Any other
 * failure is the framework's fault to surface, and the last values stand.
 *
 * **Nothing here computes a rate.** Every value is the instance's own; the line plots the answers
 * received, each at the client time it arrived, and invents no history.
 *
 * Framework-free, like the rest of `core/` (AD-19), so `ui/tools/performance.test.mjs` executes it
 * under `node --test`.
 */

import type { ApiService, JsonResult } from './api';
import { classifyFault, type Fault } from './fault.ts';
import type { RefreshReadResult } from './refresh.ts';
import { groupDigits } from './table-model.ts';

/** Absolute from the origin root, through the one API service (AD-20). */
export const PERFORMANCE_PATH = '/api/ocupilot/ui/performance';

/** The five members the read answers, in the order the row shows them. */
export const PERFORMANCE_FIELDS = [
  'cacheEfficiency',
  'globalReferencesPerSecond',
  'globalUpdatesPerSecond',
  'diskReadsPerSecond',
  'diskWritesPerSecond',
] as const;

export type PerformanceField = (typeof PERFORMANCE_FIELDS)[number];

export type PerformanceValues = Readonly<Record<PerformanceField, number>>;

/** One answer on the line: when it arrived, in client milliseconds, and its Global references. */
export interface PerformancePoint {
  readonly at: number;
  readonly value: number;
}

/** How far back the line reaches: ten minutes. */
export const SPARKLINE_WINDOW_MS = 600_000;

export interface PerformanceRowOptions {
  readonly api: Pick<ApiService, 'requestJson'>;
  /** Defaults to `Date.now`. The time each answer is plotted at. */
  readonly now?: () => number;
}

/** The five numbers off an answered body, or `null` when any is missing or not a finite number. */
function valuesOf(body: unknown): PerformanceValues | null {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) return null;
  const source = body as Record<string, unknown>;
  const out: Record<string, number> = {};
  for (const field of PERFORMANCE_FIELDS) {
    const value = source[field];
    if (typeof value !== 'number' || !Number.isFinite(value)) return null;
    out[field] = value;
  }
  return out as PerformanceValues;
}

export class PerformanceRow {
  private readonly api: Pick<ApiService, 'requestJson'>;
  private readonly now: () => number;

  private valuesHeld: PerformanceValues | null = null;
  private deniedValue = false;
  private pointsHeld: readonly PerformancePoint[] = [];

  /**
   * Bumped by `reset()` and `clearHistory()`, read across the await: an answer about a Home view
   * that has closed, or about a principal who signed out, must not land on the next one (AD-8).
   */
  private generation = 0;

  /** Bumped by every read, so only the newest answer settles. */
  private request = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: PerformanceRowOptions) {
    this.api = options.api;
    this.now = options.now ?? (() => Date.now());
  }

  /** The last successful answer, or `null` before one and after a 403. */
  values(): PerformanceValues | null {
    return this.valuesHeld;
  }

  /** Whether the instance refused the last read with a 403. */
  denied(): boolean {
    return this.deniedValue;
  }

  /** The line's points, oldest first: only answers received since the view opened. */
  points(): readonly PerformancePoint[] {
    return this.pointsHeld;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * Home's refresh read (AD-43). An arrow property so the one function is what Home binds and
   * re-binds, and the framework's re-bind comparison sees the same read.
   */
  readonly read = async (): Promise<RefreshReadResult> => {
    const generation = this.generation;
    const request = (this.request += 1);
    const result: JsonResult<unknown> = await this.api.requestJson<unknown>(PERFORMANCE_PATH, { scope: null });
    const current = generation === this.generation && request === this.request;

    if (result.kind === 'error' && result.status === 403) {
      if (current) {
        this.valuesHeld = null;
        this.deniedValue = true;
        this.pointsHeld = [];
        this.notify();
      }
      return { kind: 'ok', rows: [], truncated: false };
    }

    const values = result.kind === 'ok' ? valuesOf(result.body) : null;
    if (values === null) {
      // An answer that is not the read's shape is a server fault, carrying the status it came with.
      const failed: JsonResult<unknown> =
        result.kind === 'ok' ? { kind: 'error', status: result.status, code: null, reason: null, detail: null } : result;
      return { kind: 'fault', fault: classifyFault(failed, PERFORMANCE_PATH) as Fault };
    }

    if (current) {
      const at = this.now();
      this.valuesHeld = values;
      this.deniedValue = false;
      this.pointsHeld = [...this.pointsHeld, { at, value: values.globalReferencesPerSecond }].filter(
        (point) => point.at >= at - SPARKLINE_WINDOW_MS
      );
      this.notify();
    }
    return { kind: 'ok', rows: [{ ...values }], truncated: false };
  };

  /**
   * Drop the line, keeping the values. Called when Home is left: the line plots only what this
   * Home view received, so the next one starts empty.
   */
  clearHistory(): void {
    this.generation += 1;
    if (this.pointsHeld.length === 0) return;
    this.pointsHeld = [];
    this.notify();
  }

  /** Forget everything. Sign-out: every value is what the instance answered this caller (AD-8). */
  reset(): void {
    this.generation += 1;
    this.valuesHeld = null;
    this.deniedValue = false;
    this.pointsHeld = [];
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/**
 * The line through `points` as an SVG path in a `width` x `height` box, or `''` when fewer than
 * two points fall in the window.
 *
 * The baseline is zero, and the top is the largest value plotted. The x axis spans ten minutes
 * from the first point, then scrolls: it starts at the later of the first point and ten minutes
 * before `now`, and a point before that start is not drawn.
 */
export function sparklinePath(
  points: readonly PerformancePoint[],
  now: number,
  width: number,
  height: number
): string {
  if (points.length < 2) return '';
  const start = Math.max(points[0].at, now - SPARKLINE_WINDOW_MS);
  const shown = points.filter((point) => point.at >= start);
  if (shown.length < 2) return '';
  const top = Math.max(...shown.map((point) => point.value));
  const round = (value: number): string => String(Math.round(value * 100) / 100);
  return shown
    .map((point, index) => {
      const x = ((point.at - start) / SPARKLINE_WINDOW_MS) * width;
      const y = top > 0 ? height - (point.value / top) * height : height;
      return `${index === 0 ? 'M' : 'L'}${round(x)} ${round(y)}`;
    })
    .join(' ');
}

/**
 * The five values as the row shows them: each rate a whole number with its digits grouped, and
 * cache efficiency with one decimal.
 */
export function formatPerformance(values: PerformanceValues): Readonly<Record<PerformanceField, string>> {
  const rate = (value: number): string => groupDigits(Math.round(value));
  const [whole, fraction] = (Math.round(values.cacheEfficiency * 10) / 10).toFixed(1).split('.');
  return {
    cacheEfficiency: `${groupDigits(Number(whole))}.${fraction}`,
    globalReferencesPerSecond: rate(values.globalReferencesPerSecond),
    globalUpdatesPerSecond: rate(values.globalUpdatesPerSecond),
    diskReadsPerSecond: rate(values.diskReadsPerSecond),
    diskWritesPerSecond: rate(values.diskWritesPerSecond),
  };
}

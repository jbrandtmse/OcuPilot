/**
 * The instance's allowed directories, for a server-path picker to offer (Story 18.1, AD-21).
 *
 * **One list, read one way.** `load` issues the Allowed directories screen's own declared read,
 * through `createScreenRead`, so the picker, the screen and its read tool answer the same rows
 * under the same gate and cap (AD-5, AD-36). Nothing here computes a root or checks a name: the
 * roots are the instance's answer, and whether a root and a name resolve is
 * `OcuPilot.Port.PathPort`'s question, asked again at the write.
 *
 * **A refusal keeps the instance's own sentence.** A read that does not answer leaves no roots and
 * carries the envelope's `reason`, so a picker says why it offers nothing in the words the server
 * wrote (AD-39); a transport failure carries none.
 *
 * **Only the newest load settles.** Each `load` bumps a request counter read across the await, so
 * an older answer arriving last never overwrites a newer one.
 *
 * Framework-free, like the rest of `core/` (AD-19): a subscribable a component mirrors into a
 * signal, which `ui/tools/allowed-directories.test.mjs` executes under `node --test`.
 */

import type { ApiRequestInit, ApiService, JsonResult } from './api';
import { screenForRoute } from './navigation.ts';
import { createScreenRead } from './screen-read.ts';

/** The Allowed directories screen's route, whose declared read the store issues. */
export const ALLOWED_DIRECTORIES_ROUTE = 'security/allowed-directories';

/** The cap the store reads under: the read ceiling the resolver on the instance uses too. */
export const ALLOWED_DIRECTORIES_MAX_ROWS = 1000;

/** Where a load stands. */
export type AllowedDirectoriesStatus = 'loading' | 'ready' | 'refused';

/**
 * What the last load answered: `roots` in read order, `truncated` when the read was cut at the
 * cap, and `reason` the envelope's sentence for a refused read, `''` otherwise.
 */
export interface AllowedDirectoriesState {
  readonly status: AllowedDirectoriesStatus;
  readonly roots: readonly string[];
  readonly truncated: boolean;
  readonly reason: string;
}

/** The state before any load has settled. */
export const ALLOWED_DIRECTORIES_LOADING: AllowedDirectoriesState = { status: 'loading', roots: [], truncated: false, reason: '' };

/** The `Directory` of each row that carries a non-empty one, in read order. */
function rootsOf(rows: readonly unknown[]): string[] {
  const roots: string[] = [];
  for (const row of rows) {
    if (row === null || typeof row !== 'object' || Array.isArray(row)) continue;
    const directory = (row as Record<string, unknown>)['Directory'];
    if (typeof directory === 'string' && directory !== '') roots.push(directory);
  }
  return roots;
}

export class AllowedDirectoriesStore {
  private stateValue: AllowedDirectoriesState = ALLOWED_DIRECTORIES_LOADING;

  private request = 0;

  private readonly listeners = new Set<() => void>();

  /** The last settled answer, or the loading state while one is in flight. */
  state(): AllowedDirectoriesState {
    return this.stateValue;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * Read the roots through the Allowed directories screen's declared read, at
   * `ALLOWED_DIRECTORIES_MAX_ROWS`. The state reads `loading` until the newest load settles.
   */
  async load(api: Pick<ApiService, 'requestJson'>): Promise<void> {
    const request = (this.request += 1);
    this.set(ALLOWED_DIRECTORIES_LOADING);
    const screen = screenForRoute(ALLOWED_DIRECTORIES_ROUTE);
    if (screen === null || screen.read === null) {
      this.set({ status: 'refused', roots: [], truncated: false, reason: '' });
      return;
    }
    // The read answers a classified fault, which carries no sentence; the envelope's own reason is
    // kept from the answer the read was built on.
    let answered: JsonResult<unknown> | null = null;
    const capturing: Pick<ApiService, 'requestJson'> = {
      requestJson: async <T>(path: string, init?: ApiRequestInit): Promise<JsonResult<T>> => {
        const result = await api.requestJson<T>(path, init);
        answered = result as JsonResult<unknown>;
        return result;
      },
    };
    const result = await createScreenRead(capturing, screen)({ maxRows: ALLOWED_DIRECTORIES_MAX_ROWS });
    if (request !== this.request) return;
    if (result.kind === 'ok') {
      this.set({ status: 'ready', roots: rootsOf(result.rows), truncated: result.truncated, reason: '' });
      return;
    }
    const last = answered as JsonResult<unknown> | null;
    const reason = last !== null && last.kind === 'error' ? (last.reason ?? '') : '';
    this.set({ status: 'refused', roots: [], truncated: false, reason });
  }

  private set(state: AllowedDirectoriesState): void {
    this.stateValue = state;
    for (const listener of [...this.listeners]) listener();
  }
}

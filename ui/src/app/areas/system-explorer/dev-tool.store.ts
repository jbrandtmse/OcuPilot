/**
 * System Explorer's Code metrics and Document hashes state (AD-19, Story 24.1): what the form holds,
 * the search last sent, and the one `RefreshRead` the page binds.
 *
 * **Framework-free.** It imports nothing from Angular; `dev-tool.page.ts` holds one per screen store,
 * so a return to the screen finds the last search.
 *
 * **No read until there is a search.** The bound read answers no rows, and sends nothing, until Search
 * has been pressed with a pattern or an agent's arrival has named one; from then on every read -- the
 * framework's re-read on a change to a class or routine, a namespace switch, Refresh -- runs that same
 * search again (AD-14).
 */

import type { ApiRequestInit, ApiService, JsonResult } from '../../core/api';
import type { RefreshRead, RefreshReadResult } from '../../core/refresh';
import type { ScreenArrival } from '../../core/screen-arrival';
import { createScreenRead, type ScreenReadCriteria } from '../../core/screen-read';
import type { ScreenDeclaration } from '../../core/screens.generated';

/** The two criteria both screens declare. */
export const SPEC_PARAM = 'spec';
export const GENERATED_PARAM = 'generated';

/** The generated choice's two values. */
export const GENERATED_NO = 'no';
export const GENERATED_YES = 'yes';

export class DevToolState {
  private specValue = '';

  private generatedValue = GENERATED_NO;

  private sentValue: ScreenReadCriteria | null = null;

  private cachedRead: RefreshRead | null = null;

  private refusalValue = '';

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** The instance's reason for refusing the last read, or `''` when it was not refused. */
  refusal(): string {
    return this.refusalValue;
  }

  setRefusal(reason: string): void {
    if (reason === this.refusalValue) return;
    this.refusalValue = reason;
    this.notify();
  }

  spec(): string {
    return this.specValue;
  }

  includeGenerated(): boolean {
    return this.generatedValue === GENERATED_YES;
  }

  setSpec(value: string): void {
    this.specValue = value;
    this.notify();
  }

  setIncludeGenerated(on: boolean): void {
    this.generatedValue = on ? GENERATED_YES : GENERATED_NO;
    this.notify();
  }

  /** Whether a search has been sent. */
  searched(): boolean {
    return this.sentValue !== null;
  }

  /** Send the form as shown from the next read on: answers false, sending nothing, with no pattern. */
  search(): boolean {
    if (this.specValue.trim() === '') return false;
    this.sentValue = { [SPEC_PARAM]: this.specValue, [GENERATED_PARAM]: this.generatedValue };
    this.notify();
    return true;
  }

  /**
   * Run an agent arrival's search: the declared criteria it carries, shown in the form. An arrival with no
   * pattern sends nothing and drops the search it replaces.
   */
  useArrival(arrival: ScreenArrival): boolean {
    const criteria = arrival.criteria;
    this.specValue = typeof criteria[SPEC_PARAM] === 'string' ? criteria[SPEC_PARAM] : '';
    this.generatedValue = criteria[GENERATED_PARAM] === GENERATED_YES ? GENERATED_YES : GENERATED_NO;
    if (this.search()) return true;
    this.sentValue = null;
    this.notify();
    return false;
  }

  /** What the next read sends, or `null` while no search has been sent. */
  criteria(): ScreenReadCriteria | null {
    return this.sentValue === null ? null : { ...this.sentValue };
  }

  /** The one `RefreshRead` this state holds, built by `create` on first ask. */
  readFor(create: () => RefreshRead): RefreshRead {
    if (this.cachedRead === null) this.cachedRead = create();
    return this.cachedRead;
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/**
 * The screens' `RefreshRead`: no request and no rows while `state` holds no search, and the declared read with the
 * search's criteria otherwise. Each answer's refusal reason, or `''`, is kept on `state` for the page to show.
 */
export function createDevToolRead(api: Pick<ApiService, 'requestJson'>, declaration: ScreenDeclaration, state: DevToolState): RefreshRead {
  const recording: Pick<ApiService, 'requestJson'> = {
    requestJson: async <T,>(path: string, init?: ApiRequestInit): Promise<JsonResult<T>> => {
      const result = await api.requestJson<T>(path, init);
      state.setRefusal(result.kind === 'error' ? (result.reason ?? '') : '');
      return result;
    },
  };
  const read = createScreenRead(recording, declaration, () => state.criteria() ?? {});
  return async (options): Promise<RefreshReadResult> => {
    if (state.criteria() === null) return { kind: 'ok', rows: [], truncated: false };
    return read(options);
  };
}

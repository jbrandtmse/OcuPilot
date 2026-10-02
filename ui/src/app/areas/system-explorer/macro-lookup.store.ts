/**
 * System Explorer's Macros state (AD-19, Story 19.4): the document and macro the form holds, the
 * lookup last sent, and the one `RefreshRead` the page binds.
 *
 * **Framework-free.** It imports nothing from Angular; `macro-lookup.page.ts` holds one per screen
 * store.
 *
 * **No read until there is a lookup.** The bound read answers no rows, and sends nothing, until Look
 * up has been pressed with a document and a macro, or an agent's arrival has named both.
 */

import type { ApiRequestInit, ApiService, JsonResult } from '../../core/api';
import type { RefreshRead, RefreshReadResult } from '../../core/refresh';
import type { ScreenArrival } from '../../core/screen-arrival';
import { createScreenRead, type ScreenReadCriteria } from '../../core/screen-read';
import type { ScreenDeclaration } from '../../core/screens.generated';

/** The two criteria the Macros screen declares. */
export const DOCUMENT_PARAM = 'document';
export const MACRO_PARAM = 'macro';

/** The Macros screen's route, and the query parameter a link to it prefills the document from. */
export const MACROS_ROUTE = 'system-explorer/macros';

export const DOCUMENT_QUERY = 'document';

/** The one definition a lookup answers, read off its row. */
export interface MacroDefinition {
  readonly macro: string;
  readonly document: string;
  readonly line: number | null;
  readonly definition: string;
}

function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/** The first row as a definition, or `null` when the lookup answered none. */
export function definitionOf(rows: readonly unknown[]): MacroDefinition | null {
  const row = rows[0];
  if (row === null || typeof row !== 'object') return null;
  const record = row as Record<string, unknown>;
  return {
    macro: text(record['Macro']),
    document: text(record['Document']),
    line: typeof record['Line'] === 'number' ? record['Line'] : null,
    definition: text(record['Definition']),
  };
}

export class MacroLookupState {
  private documentValue = '';

  private macroValue = '';

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

  document(): string {
    return this.documentValue;
  }

  macro(): string {
    return this.macroValue;
  }

  setDocument(value: string): void {
    this.documentValue = value;
    this.notify();
  }

  setMacro(value: string): void {
    this.macroValue = value;
    this.notify();
  }

  /** Whether a lookup has been sent. */
  searched(): boolean {
    return this.sentValue !== null;
  }

  /** The lookup last sent, for the empty state's sentence: its document and macro. */
  sent(): { readonly document: string; readonly macro: string } {
    return { document: this.sentValue?.[DOCUMENT_PARAM] ?? '', macro: this.sentValue?.[MACRO_PARAM] ?? '' };
  }

  /** Send the form as shown from the next read on: answers false, sending nothing, unless both fields hold text. */
  lookUp(): boolean {
    const document = this.documentValue.trim();
    const macro = this.macroValue.trim();
    if (document === '' || macro === '') return false;
    this.sentValue = { [DOCUMENT_PARAM]: document, [MACRO_PARAM]: macro };
    this.notify();
    return true;
  }

  /** Run an agent arrival's lookup: the criteria it carries, shown in the form. */
  useArrival(arrival: ScreenArrival): boolean {
    const criteria = arrival.criteria;
    if (typeof criteria[DOCUMENT_PARAM] === 'string') this.documentValue = criteria[DOCUMENT_PARAM];
    if (typeof criteria[MACRO_PARAM] === 'string') this.macroValue = criteria[MACRO_PARAM];
    this.notify();
    return this.lookUp();
  }

  /** What the next read sends, or `null` while no lookup has been sent. */
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
 * The Macros screen's `RefreshRead`: no request and no rows while `state` holds no lookup, and the
 * declared read with the lookup's criteria otherwise. Each answer's refusal reason, or `''`, is
 * kept on `state` for the page to show.
 */
export function createMacroRead(api: Pick<ApiService, 'requestJson'>, declaration: ScreenDeclaration, state: MacroLookupState): RefreshRead {
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

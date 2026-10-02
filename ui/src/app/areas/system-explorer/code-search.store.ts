/**
 * System Explorer's Search state (AD-19, Story 19.4): what the form holds, the search last sent, and
 * the one `RefreshRead` the page binds.
 *
 * **Framework-free.** It imports nothing from Angular; `code-search.page.ts` holds one per screen
 * store, so a return to the screen finds the last search.
 *
 * **No read until there is a search.** The bound read answers no rows, and sends nothing, until
 * Search has been pressed with text or an agent's arrival has named one; from then on every read --
 * the framework's re-read on a change to a class or routine, a namespace switch, Refresh -- runs
 * that same search again (AD-14).
 */

import type { ApiService } from '../../core/api';
import type { RefreshRead, RefreshReadResult } from '../../core/refresh';
import type { ScreenArrival } from '../../core/screen-arrival';
import { createScreenRead, type ScreenReadCriteria } from '../../core/screen-read';
import type { ScreenDeclaration } from '../../core/screens.generated';

/** The three criteria the Search screen declares. */
export const TEXT_PARAM = 'text';
export const SCOPE_PARAM = 'scope';
export const CASE_PARAM = 'case';

/** The scope a search opens on, and the case choice. */
export const SCOPE_ALL = 'all';
export const CASE_NO = 'no';
export const CASE_YES = 'yes';

/** The viewer routes a hit opens: the class viewer for a class, the routine viewer otherwise. */
export const CLASS_VIEWER_ROUTE = 'system-explorer/classes/document';
export const ROUTINE_VIEWER_ROUTE = 'system-explorer/routines/document';

/** The viewer route that shows document `name`. */
export function viewerRouteFor(name: string): string {
  return name.toLowerCase().endsWith('.cls') ? CLASS_VIEWER_ROUTE : ROUTINE_VIEWER_ROUTE;
}

/** One match, read off a row by its declared fields. */
export interface SearchHit {
  readonly key: string;
  readonly document: string;
  readonly member: string;
  readonly line: number | null;
  readonly attribute: string;
  readonly text: string;
}

function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/** The rows as hits, in the order the instance answered them. */
export function hitsOf(rows: readonly unknown[]): SearchHit[] {
  const hits: SearchHit[] = [];
  rows.forEach((row, index) => {
    if (row === null || typeof row !== 'object') return;
    const record = row as Record<string, unknown>;
    hits.push({
      key: `${index}`,
      document: text(record['Document']),
      member: text(record['Member']),
      line: typeof record['Line'] === 'number' ? record['Line'] : null,
      attribute: text(record['Attribute']),
      text: text(record['Text']),
    });
  });
  return hits;
}

/**
 * Where in its document a hit is: `Member+Line` for a member's line, the member alone where the
 * instance names no line, `[Attribute]` for a match in an attribute of the document itself, and the
 * line alone for a routine's line.
 */
export function hitLocation(hit: SearchHit): string {
  if (hit.member !== '') return hit.line === null ? hit.member : `${hit.member}+${hit.line}`;
  if (hit.attribute !== '') return `[${hit.attribute}]`;
  return hit.line === null ? '' : `${hit.line}`;
}

export class CodeSearchState {
  private textValue = '';

  private scopeValue = SCOPE_ALL;

  private caseValue = CASE_NO;

  private sentValue: ScreenReadCriteria | null = null;

  private cachedRead: RefreshRead | null = null;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  text(): string {
    return this.textValue;
  }

  scope(): string {
    return this.scopeValue;
  }

  matchCase(): boolean {
    return this.caseValue === CASE_YES;
  }

  setText(value: string): void {
    this.textValue = value;
    this.notify();
  }

  setScope(value: string): void {
    this.scopeValue = value;
    this.notify();
  }

  setMatchCase(on: boolean): void {
    this.caseValue = on ? CASE_YES : CASE_NO;
    this.notify();
  }

  /** Whether a search has been sent. */
  searched(): boolean {
    return this.sentValue !== null;
  }

  /** Send the form as shown from the next read on: answers false, sending nothing, with no text. */
  search(): boolean {
    if (this.textValue.trim() === '') return false;
    this.sentValue = { [TEXT_PARAM]: this.textValue, [SCOPE_PARAM]: this.scopeValue, [CASE_PARAM]: this.caseValue };
    this.notify();
    return true;
  }

  /**
   * Run an agent arrival's search: the declared criteria it carries, shown in the form, the others
   * left at their defaults. An arrival with no text sends nothing.
   */
  useArrival(arrival: ScreenArrival): boolean {
    const criteria = arrival.criteria;
    this.textValue = typeof criteria[TEXT_PARAM] === 'string' ? criteria[TEXT_PARAM] : '';
    this.scopeValue = typeof criteria[SCOPE_PARAM] === 'string' && criteria[SCOPE_PARAM] !== '' ? criteria[SCOPE_PARAM] : SCOPE_ALL;
    this.caseValue = criteria[CASE_PARAM] === CASE_YES ? CASE_YES : CASE_NO;
    this.notify();
    return this.search();
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
 * The Search screen's `RefreshRead`: no request and no rows while `state` holds no search, and the
 * declared read with the search's criteria otherwise.
 */
export function createSearchRead(api: Pick<ApiService, 'requestJson'>, declaration: ScreenDeclaration, state: CodeSearchState): RefreshRead {
  const read = createScreenRead(api, declaration, () => state.criteria() ?? {});
  return async (options): Promise<RefreshReadResult> => {
    if (state.criteria() === null) return { kind: 'ok', rows: [], truncated: false };
    return read(options);
  };
}

/**
 * The class and routine viewers' own state (AD-19): which document the route names, which view is
 * on screen, the form the next read asks for, and the document text the last read answered.
 *
 * **Framework-free.** It imports nothing from Angular; the page holds one per page instance.
 *
 * **One read, the descriptor's own.** `createSourceRead` issues the declared read with the `name`
 * and `form` criteria. Its rows go to the screen store like any list's -- so the table, the panel's
 * screen context and the read tool all see the same structure rows -- and the answer's `document`,
 * which never enters screen context (AD-36), is kept here alone. A document the namespace does not
 * hold answers 404 `PORT.NOTFOUND`, which reads as no rows, so the table's empty state says the
 * document no longer exists.
 */

import type { ApiService, JsonResult } from '../../core/api';
import { classifyFault, type Fault } from '../../core/fault';
import type { RefreshRead, RefreshReadResult } from '../../core/refresh';
import { screenReadPath, type ScreenReadCriteria } from '../../core/screen-read';
import type { ScreenDeclaration } from '../../core/screens.generated';

/** The five views a viewer offers, in their order on screen. */
export type SourceViewKey = 'source' | 'xml' | 'int' | 'structure' | 'documentation';

export const SOURCE_VIEWS: readonly SourceViewKey[] = ['source', 'xml', 'int', 'structure', 'documentation'];

/** The `form` criterion each text view reads. */
export const VIEW_FORMS: Readonly<Record<'source' | 'xml' | 'int', string>> = { source: 'udl', xml: 'xml', int: 'int' };

/** The code the port refuses a document the namespace does not hold with. */
export const NOT_FOUND_CODE = 'PORT.NOTFOUND';

/** Whether `view` shows the document's text. */
export function isTextView(view: SourceViewKey): view is 'source' | 'xml' | 'int' {
  return view === 'source' || view === 'xml' || view === 'int';
}

/** One document as the read's `document` member carries it. */
export interface SourceDocument {
  readonly name: string;
  readonly form: string;
  readonly available: boolean;
  /** The text, its lines joined by newlines; `''` where the instance keeps no such form. */
  readonly content: string;
  readonly modified: string;
  readonly database: string;
  readonly generates: readonly string[];
  /** Why no text is available: `objectonly` where the instance keeps only a routine's object code (Story 19.2), else `''`. */
  readonly reason: string;
}

/** The reason a routine kept only as object code carries (Story 19.2). */
export const OBJECT_ONLY_REASON = 'objectonly';

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/** The document an answer carries, each member read by its declared name and type, or `null`. */
export function documentOf(value: unknown): SourceDocument | null {
  if (!isRecord(value)) return null;
  const lines = Array.isArray(value['content']) ? value['content'].map(text) : [];
  const generates = Array.isArray(value['generates']) ? value['generates'].map(text).filter((name) => name !== '') : [];
  return {
    name: text(value['name']),
    form: text(value['form']),
    available: value['available'] === true,
    content: lines.join('\n'),
    modified: text(value['modified']),
    database: text(value['database']),
    generates,
    reason: text(value['reason']),
  };
}

/** One documented row: the class or a member, by name, with its description as text. */
export interface DocumentedRow {
  readonly key: string;
  readonly kind: string;
  readonly name: string;
  readonly description: string;
}

/** The rows that carry a description, class row first, in row order. */
export function documentedRows(rows: readonly unknown[]): DocumentedRow[] {
  return rows
    .filter(isRecord)
    .map((row, index) => ({
      key: `${index}`,
      kind: text(row['Kind']),
      name: text(row['Name']),
      description: text(row['Description']),
    }))
    .filter((row) => row.description !== '');
}

export class SourceViewerState {
  private nameValue = '';

  private viewValue: SourceViewKey = 'source';

  private formValue = VIEW_FORMS.source;

  private documentValue: SourceDocument | null = null;

  private goneValue = false;

  private opened = false;

  private cachedRead: RefreshRead | null = null;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  name(): string {
    return this.nameValue;
  }

  view(): SourceViewKey {
    return this.viewValue;
  }

  /** The form the next read asks for. */
  form(): string {
    return this.formValue;
  }

  /** The document the last answer for this name and form carried, or `null`. */
  document(): SourceDocument | null {
    return this.documentValue;
  }

  /** Whether the last answer said the namespace holds no document by this name. */
  gone(): boolean {
    return this.goneValue;
  }

  /**
   * Show `name`, from Source: answers true when that is a different document, which the page then
   * reads; the name already open changes nothing.
   */
  open(name: string): boolean {
    if (this.opened && name === this.nameValue) return false;
    this.opened = true;
    this.nameValue = name;
    this.viewValue = 'source';
    this.formValue = VIEW_FORMS.source;
    this.documentValue = null;
    this.goneValue = false;
    this.notify();
    return true;
  }

  /**
   * Show `view`. A text view asks for its own form and answers true, since each is a re-read;
   * Structure and Documentation show the rows already read and answer false.
   */
  setView(view: SourceViewKey): boolean {
    this.viewValue = view;
    if (!isTextView(view)) {
      this.notify();
      return false;
    }
    this.formValue = VIEW_FORMS[view];
    this.notify();
    return true;
  }

  /** What the next read sends: the name and the form. */
  criteria(): ScreenReadCriteria {
    return { name: this.nameValue, form: this.formValue };
  }

  /** Keep what an answer to `sent` carried, unless the name or form has moved on since. */
  applyAnswer(sent: ScreenReadCriteria, document: SourceDocument | null, gone: boolean): void {
    if (sent['name'] !== this.nameValue || sent['form'] !== this.formValue) return;
    this.documentValue = document;
    this.goneValue = gone;
    this.notify();
  }

  /**
   * Drop the document another namespace answered (AD-44), so the page shows the table -- its
   * skeleton, refusal or empty state -- until this namespace's read answers.
   */
  forget(): void {
    if (this.documentValue === null && !this.goneValue) return;
    this.documentValue = null;
    this.goneValue = false;
    this.notify();
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

/** The answer's shape: the rows, `truncated`, and the document beside them. */
interface SourceReadBody {
  readonly rows?: unknown;
  readonly truncated?: unknown;
  readonly document?: unknown;
}

/**
 * The viewer's `RefreshRead`: the declared read with `state`'s criteria, its rows to the screen
 * store and its document to `state`. A 404 `PORT.NOTFOUND` is no rows and a gone document; any
 * other failure is the classified fault the table and the shell's banner show.
 */
export function createSourceRead(
  api: Pick<ApiService, 'requestJson'>,
  declaration: Pick<ScreenDeclaration, 'toolIdentifier' | 'read'>,
  state: SourceViewerState
): RefreshRead {
  return async ({ maxRows }): Promise<RefreshReadResult> => {
    const sent = state.criteria();
    const path = screenReadPath(declaration, maxRows, sent);
    const result: JsonResult<SourceReadBody> = await api.requestJson<SourceReadBody>(path);
    const body = result.kind === 'ok' ? result.body : null;
    if (result.kind === 'ok' && isRecord(body) && Array.isArray(body['rows'])) {
      state.applyAnswer(sent, documentOf(body['document']), false);
      return { kind: 'ok', rows: body['rows'] as readonly unknown[], truncated: body['truncated'] === true };
    }
    if (result.kind === 'error' && result.status === 404 && result.code === NOT_FOUND_CODE) {
      state.applyAnswer(sent, null, true);
      return { kind: 'ok', rows: [], truncated: false };
    }
    const failed: JsonResult<unknown> =
      result.kind === 'ok' ? { kind: 'error', status: result.status, code: null, reason: null, detail: null } : result;
    return { kind: 'fault', fault: classifyFault(failed, path) as Fault };
  };
}

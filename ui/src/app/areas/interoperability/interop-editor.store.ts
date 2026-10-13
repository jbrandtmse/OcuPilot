/**
 * The embedded rule, BPL and DTL editor screens' own state (AD-19, Story 20.7): which document the
 * route names, what the owning list's declared read answered about it, and the revision a new frame
 * is keyed by.
 *
 * **Framework-free.** It imports nothing from Angular; the page holds one per page instance and hands
 * it what it needs as plain functions, so `ui/tools/interop-editor-store.test.mjs` drives it under
 * `node --test`.
 *
 * **One request, the list's own read** (AD-5, AD-20, AD-36): `screenReadPath` for the owning list at
 * `EDITOR_READ_ROWS`, with `scope` pinned to the namespace the document opened in. The list's verdict
 * is checked first, so a denied person sends nothing. The screen declares no read of its own, and the
 * editor itself is never asked anything: it is drawn by `app-interop-editor-frame` (AD-63).
 *
 * **What the answer decides.** `open` only for a row the read returned, and for a process or a
 * transformation only when the row is not marked `Coded` (AD-62 item 13); `coded` for a marked row,
 * `gone` for an id the read does not return (deleted, never created, another namespace, or past the
 * read's cap), `refused` for a denied verdict or a 403 that names its pair, and `fault` for any other
 * answer. A late answer for an older request is dropped.
 */

import type { ApiService } from '../../core/api';
import type { Verdict } from '../../core/navigation';
import { screenReadPath } from '../../core/screen-read.ts';
import type { ScreenDeclaration } from '../../core/screens.generated';

/** What the screen draws: a skeleton, the editor, or one of the four sentences. */
export type InteropEditorPhase = 'loading' | 'open' | 'gone' | 'coded' | 'refused' | 'fault';

/** The rows the list read asks for: the route's ceiling, which is the most the list itself shows. */
export const EDITOR_READ_ROWS = 1000;

/** The extension a document name carries, which the editor's own document parameter does not. */
export const DOCUMENT_EXTENSION = '.cls';

/** What the store reads and is told its verdict through. */
export interface InteropEditorDeps {
  /** Issues the list's read; the store passes `scope` on every call. */
  readonly api: Pick<ApiService, 'requestJson'>;
  /** The list whose declared read and verdict the screen follows. */
  readonly list: Pick<ScreenDeclaration, 'route' | 'toolIdentifier' | 'read'>;
  /** The signed-in person's verdict for a screen's route (AD-8). */
  readonly verdict: (route: string) => Verdict;
}

/** The shape of the list read's body the store relies on. */
interface ListBody {
  readonly rows?: unknown;
}

/** Whether `row` is an object carrying a string `Name` equal to `id`. */
function rowNamed(row: unknown, id: string): row is Record<string, unknown> {
  return typeof row === 'object' && row !== null && (row as Record<string, unknown>)['Name'] === id;
}

export class InteropEditorState {
  private readonly deps: InteropEditorDeps;

  private phaseValue: InteropEditorPhase = 'loading';

  private idValue = '';

  private namespaceValue = '';

  private documentValue = '';

  private revisionValue = 0;

  private failedPairValue = '';

  private busyValue = false;

  /** Which read is current; an answer to an older one is dropped. */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  constructor(deps: InteropEditorDeps) {
    this.deps = deps;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  phase(): InteropEditorPhase {
    return this.phaseValue;
  }

  /** The route's document name, `<class>.cls`, as last opened. */
  id(): string {
    return this.idValue;
  }

  /** The namespace the last read was issued in, and the one a drawn frame is built for. */
  namespace(): string {
    return this.namespaceValue;
  }

  /** The editor's document: the answered row's `Name` less its extension, or `''` until a row is answered. */
  document(): string {
    return this.documentValue;
  }

  /** Counts the frames drawn for this screen; a new value is a new frame at the same address. */
  revision(): number {
    return this.revisionValue;
  }

  /** The `resource:permission` pair a `refused` screen names. */
  failedPair(): string {
    return this.failedPairValue;
  }

  /** Whether a read is in flight, for the first open and for a Refresh alike. */
  busy(): boolean {
    return this.busyValue;
  }

  /** Open `id` in `namespace`: the frame goes at once, and the read decides what replaces it. */
  open(id: string, namespace: string): Promise<void> {
    this.idValue = id;
    this.namespaceValue = namespace;
    this.documentValue = '';
    this.failedPairValue = '';
    this.phaseValue = 'loading';
    return this.read();
  }

  /** Read the same document in the same namespace again; an answer that still opens it draws a new frame. */
  refresh(): Promise<void> {
    if (this.namespaceValue === '') return Promise.resolve();
    return this.read();
  }

  /** Drop any answer still in flight and every listener; the page calls it as it is destroyed. */
  reset(): void {
    this.generation += 1;
    this.busyValue = false;
    this.listeners.clear();
  }

  private async read(): Promise<void> {
    const generation = ++this.generation;
    const verdict = this.deps.verdict(this.deps.list.route);
    if (!verdict.allowed) {
      this.settle('refused', verdict.failedPair);
      return;
    }
    const id = this.idValue;
    if (id.length <= DOCUMENT_EXTENSION.length || !id.endsWith(DOCUMENT_EXTENSION)) {
      this.settle('gone');
      return;
    }
    this.busyValue = true;
    this.notify();
    const namespace = this.namespaceValue;
    const result = await this.deps.api.requestJson<ListBody>(screenReadPath(this.deps.list, EDITOR_READ_ROWS), { scope: namespace });
    if (generation !== this.generation) return;
    if (result.kind === 'ok') {
      const rows = result.body !== null && typeof result.body === 'object' ? result.body.rows : undefined;
      if (Array.isArray(rows)) {
        const row = rows.find((candidate) => rowNamed(candidate, id)) as Record<string, unknown> | undefined;
        if (row === undefined) this.settle('gone');
        else if (row['Coded'] === true) this.settle('coded');
        else this.settle('open', '', id.slice(0, id.length - DOCUMENT_EXTENSION.length));
        return;
      }
    } else if (result.kind === 'error' && result.status === 403) {
      const pair = result.detail === null ? '' : result.detail['failedPair'];
      if (typeof pair === 'string' && pair !== '') {
        this.settle('refused', pair);
        return;
      }
    }
    this.settle('fault');
  }

  private settle(phase: InteropEditorPhase, failedPair = '', document = ''): void {
    this.busyValue = false;
    this.phaseValue = phase;
    this.failedPairValue = failedPair;
    this.documentValue = document;
    if (phase === 'open') this.revisionValue += 1;
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

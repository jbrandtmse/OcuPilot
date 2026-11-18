/**
 * System Explorer's Global nodes state (AD-19, Story 21.5): one global's nodes, a bounded page at a time, the start node the person asked for and
 * the refusal on screen.
 *
 * **Framework-free.** It imports nothing from Angular; `global-view.page.ts` holds one and hands it what it needs as plain functions, so the component
 * specs drive it directly.
 *
 * **A page is posted to the screen's own route**, `POST /explorer/globals/nodes`, scoped to the namespace, with the global's name, the start node
 * and, for "More", the cursor the last page answered. A request generation drops an older answer. **A namespace switch forgets everything read in
 * the old one** (AD-44, `forget`).
 *
 * **The answer is screen-only** (AD-36): a node's reference and value live in this state and are rendered as text; none of it enters the screen's
 * store, so none of it reaches screen context.
 *
 * **A write is a screen action** (AD-53) of `explorer.globalnodes.save` or `explorer.globalnodes.delete`, sent through the action handler; its answer
 * is the change event, and the page is read again over as many pages as were loaded.
 */

import type { ApiService, JsonResult } from '../../core/api';
import { STRINGS } from '../../core/strings';
import type { ActionRefusal, ActionSink, ActionValues } from '../../shell/screen-action-handler';

/** The screen's own route. */
export const NODES_PATH = '/api/ocupilot/explorer/globals/nodes';

/** The node page's descriptor, which the screen actions are sent for. */
export const GLOBAL_VIEW_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.ExplorerGlobalView';

/** The node page's two actions. */
export const NODE_SAVE_ACTION = 'save';
export const NODE_DELETE_ACTION = 'delete';

/** The rows a page asks for. */
export const PAGE_SIZE = 100;

/** The longest value the instance edits, and a display cut. */
export const MAX_VALUE = 1000;

/** One node of the page. */
export interface NodeRow {
  readonly reference: string;
  readonly value: string;
  readonly cut: boolean;
  readonly editable: boolean;
  readonly below: boolean;
}

/** What the store needs from the page: the API, the namespace and the action handler. */
export interface GlobalViewDeps {
  readonly api: Pick<ApiService, 'requestJson'>;
  readonly scope: () => string;
  readonly sender: {
    sendFor(descriptor: string, actionId: string, target: string, values?: ActionValues, sink?: ActionSink, scope?: string): Promise<boolean>;
    lastRefusal(): ActionRefusal | null;
  };
}

/** The answer's rows, `next` cursor and `cut` flag, or `null` for a body that is not a page. */
function pageOf(body: unknown): { rows: readonly NodeRow[]; next: string; cut: boolean } | null {
  if (typeof body !== 'object' || body === null) return null;
  const record = body as Record<string, unknown>;
  if (!Array.isArray(record['rows']) || typeof record['next'] !== 'string') return null;
  const rows: NodeRow[] = [];
  for (const raw of record['rows'] as unknown[]) {
    if (typeof raw !== 'object' || raw === null) return null;
    const row = raw as Record<string, unknown>;
    if (typeof row['reference'] !== 'string' || typeof row['value'] !== 'string') return null;
    rows.push({
      reference: row['reference'],
      value: row['value'],
      cut: row['cut'] === true,
      editable: row['editable'] === true,
      below: row['below'] === true,
    });
  }
  return { rows, next: record['next'], cut: record['cut'] === true };
}

/** The sentence a refused read or write reads as: the instance's own, or the generic refusal. */
function sentenceOf(result: JsonResult<unknown>): string {
  return (result.kind === 'error' ? (result.reason ?? '') : '') || STRINGS.connectivityRequestRefused;
}

export class GlobalViewStore {
  private nameValue = '';

  private rowsValue: readonly NodeRow[] = [];

  private nextValue = '';

  private cutValue = false;

  private loadingValue = false;

  private loadedValue = false;

  private refusalValue = '';

  /** The start node last applied, and the draft the field holds. */
  private startValue = '';

  private draftValue = '';

  /** Bumped by each read, so an answer that arrives after a newer request is dropped. */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }

  /** The global's name, without `^`. */
  name(): string {
    return this.nameValue;
  }

  rows(): readonly NodeRow[] {
    return this.rowsValue;
  }

  /** Whether the instance holds more nodes after the last row. */
  hasMore(): boolean {
    return this.nextValue !== '';
  }

  /** Whether any shown value or reference was cut. */
  cut(): boolean {
    return this.cutValue;
  }

  loading(): boolean {
    return this.loadingValue;
  }

  /** Whether a read has answered since the global was opened. */
  loaded(): boolean {
    return this.loadedValue;
  }

  refusal(): string {
    return this.refusalValue;
  }

  draft(): string {
    return this.draftValue;
  }

  setDraft(text: string): void {
    this.draftValue = text;
    this.notify();
  }

  /** Open global `name` (a name without `^`, or with it), forgetting what was read. Answers whether the name changed. */
  open(name: string): boolean {
    const bare = name.startsWith('^') ? name.slice(1) : name;
    if (bare === this.nameValue) return false;
    this.nameValue = bare;
    this.forget();
    return true;
  }

  /** Forget every row, the start node and the refusal. */
  forget(): void {
    this.generation += 1;
    this.rowsValue = [];
    this.nextValue = '';
    this.cutValue = false;
    this.loadingValue = false;
    this.loadedValue = false;
    this.refusalValue = '';
    this.startValue = '';
    this.draftValue = '';
    this.notify();
  }

  /** Read the first page from the draft start node. */
  async go(deps: GlobalViewDeps): Promise<void> {
    this.startValue = this.draftValue.trim();
    await this.readFrom(deps, this.startValue, 1);
  }

  /** Read the page after the last row, and show it below. */
  async more(deps: GlobalViewDeps): Promise<void> {
    if (this.nextValue === '' || this.loadingValue) return;
    const generation = ++this.generation;
    this.loadingValue = true;
    this.refusalValue = '';
    this.notify();
    const result = await this.post(deps, { after: this.nextValue });
    if (generation !== this.generation) return;
    this.loadingValue = false;
    const page = result.kind === 'ok' ? pageOf(result.body) : null;
    if (page === null) {
      this.refusalValue = sentenceOf(result);
      this.notify();
      return;
    }
    this.rowsValue = [...this.rowsValue, ...page.rows];
    this.nextValue = page.next;
    this.cutValue = this.cutValue || page.cut;
    this.notify();
  }

  /** Read again as many pages as are shown, from the start node: the answer to a change. */
  async reload(deps: GlobalViewDeps): Promise<void> {
    await this.readFrom(deps, this.startValue, Math.max(1, Math.ceil(this.rowsValue.length / PAGE_SIZE)));
  }

  private async readFrom(deps: GlobalViewDeps, start: string, pages: number): Promise<void> {
    if (this.nameValue === '') return;
    const generation = ++this.generation;
    this.loadingValue = true;
    this.refusalValue = '';
    this.notify();
    let rows: readonly NodeRow[] = [];
    let next = '';
    let cut = false;
    for (let index = 0; index < pages; index += 1) {
      const body: Record<string, string> = next !== '' ? { after: next } : start !== '' ? { start } : {};
      const result = await this.post(deps, body);
      if (generation !== this.generation) return;
      const page = result.kind === 'ok' ? pageOf(result.body) : null;
      if (page === null) {
        this.loadingValue = false;
        this.refusalValue = sentenceOf(result);
        this.notify();
        return;
      }
      rows = [...rows, ...page.rows];
      next = page.next;
      cut = cut || page.cut;
      if (next === '') break;
    }
    this.loadingValue = false;
    this.loadedValue = true;
    this.rowsValue = rows;
    this.nextValue = next;
    this.cutValue = cut;
    this.notify();
  }

  private post(deps: GlobalViewDeps, extra: Record<string, string>): Promise<JsonResult<unknown>> {
    return deps.api.requestJson<unknown>(NODES_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ global: this.nameValue, pageSize: PAGE_SIZE, ...extra }),
      scope: deps.scope(),
    });
  }

  /**
   * Set the node `reference` to `value`, the value the dialog opened on being `was`: the screen action `save`. Answers the instance's refusal sentence
   * on a refusal, `''` once applied.
   */
  async save(deps: GlobalViewDeps, reference: string, value: string, was: string): Promise<string> {
    return this.act(deps, NODE_SAVE_ACTION, reference, { Value: value, Was: was });
  }

  /** Delete the node `reference` and every node below it: the screen action `delete`. Answers the refusal sentence, or `''` once applied. */
  async remove(deps: GlobalViewDeps, reference: string): Promise<string> {
    return this.act(deps, NODE_DELETE_ACTION, reference, undefined);
  }

  private async act(deps: GlobalViewDeps, action: string, reference: string, values: ActionValues | undefined): Promise<string> {
    let refused = '';
    const sink: ActionSink = { setRefusal: (reason) => (refused = reason) };
    const applied = await deps.sender.sendFor(GLOBAL_VIEW_DESCRIPTOR, action, reference, values, sink, deps.scope());
    if (applied) return '';
    return refused || deps.sender.lastRefusal()?.reason || STRINGS.connectivityRequestRefused;
  }
}

/**
 * The Classes and Routines lists' own state (AD-19): what each declared criterion holds, whether
 * Search has been pressed, what the next read sends, and the one `RefreshRead` the page binds.
 *
 * **Framework-free, held beside the screen's store.** It imports nothing from Angular, and
 * `code-list.page.ts` holds one instance per `ScreenStore` in a `WeakMap`, so a return from a
 * viewer finds the search the user last ran -- the shape `TaskHistorySearch` takes.
 *
 * **The form is the declaration's.** Every value is keyed by a declared criterion's `param` and
 * opens on that criterion's declared `default` (AD-36), so a list adds or drops a criterion in its
 * descriptor alone.
 */

import type { RefreshRead } from '../../core/refresh';
import type { ScreenArrival } from '../../core/screen-arrival';
import type { ScreenReadCriteria } from '../../core/screen-read';
import type { ReadCriterion } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';

/** A yes/no choice criterion's two values: the checkbox is checked on the first. */
export const CHOICE_YES = 'yes';
export const CHOICE_NO = 'no';

/** Whether `field` is a yes/no choice, drawn as a checkbox rather than a select. */
export function isYesNo(field: Pick<ReadCriterion, 'kind' | 'options'>): boolean {
  const options = field.options ?? [];
  return field.kind === 'choice' && options.length === 2 && options[0] === CHOICE_YES && options[1] === CHOICE_NO;
}

/** Each criterion's declared default, `''` where it declares none. */
export function declaredDefaults(fields: readonly ReadCriterion[]): Record<string, string> {
  const values: Record<string, string> = {};
  for (const field of fields) values[field.param] = field.default ?? '';
  return values;
}

/**
 * What the next read sends: nothing, so the instance applies every declared default; the form as
 * shown; or an agent arrival's criteria exactly.
 */
type RequestMode = 'default' | 'form' | 'arrival';

export class CodeListSearch {
  private readonly fields: readonly ReadCriterion[];

  private values: Record<string, string>;

  private mode: RequestMode = 'default';

  private arrivalSent: Record<string, string> = {};

  /** The criteria the person changed since the screen last chose what to send; an echo leaves them. */
  private readonly edited = new Set<string>();

  private searchedOnce = false;

  private cachedRead: RefreshRead | null = null;

  /** Bumped per page instance, so a destroyed one can tell a newer instance from leaving the screen. */
  private pageGeneration = 0;

  private readonly listeners = new Set<() => void>();

  constructor(fields: readonly ReadCriterion[]) {
    this.fields = fields;
    this.values = declaredDefaults(fields);
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** The declared criteria, in declaration order. */
  criteriaFields(): readonly ReadCriterion[] {
    return this.fields;
  }

  /** What criterion `param` holds now. */
  value(param: string): string {
    return this.values[param] ?? '';
  }

  setValue(param: string, value: string): void {
    if (!(param in this.values)) return;
    this.values[param] = value;
    this.edited.add(param);
    this.notify();
  }

  /** Whether yes/no criterion `param` holds yes. */
  checked(param: string): boolean {
    return this.value(param) === CHOICE_YES;
  }

  setChecked(param: string, checked: boolean): void {
    this.setValue(param, checked ? CHOICE_YES : CHOICE_NO);
  }

  /** Whether Search has been pressed since this screen store was created. */
  searched(): boolean {
    return this.searchedOnce;
  }

  noteSearched(): void {
    this.searchedOnce = true;
    this.notify();
  }

  takeGeneration(): number {
    this.pageGeneration += 1;
    return this.pageGeneration;
  }

  isCurrentGeneration(generation: number): boolean {
    return this.pageGeneration === generation;
  }

  /** Open on the default read: nothing is sent, and the form shows the declared defaults. */
  useDefault(): void {
    this.mode = 'default';
    this.values = declaredDefaults(this.fields);
    this.edited.clear();
    this.notify();
  }

  /** Send the form as shown from the next read on. */
  useForm(): void {
    this.mode = 'form';
    this.edited.clear();
    this.notify();
  }

  /**
   * Run an agent arrival's search exactly: the declared criteria it carries and nothing else, shown
   * in the form, with the ones it left absent filled from the answer.
   */
  useArrival(arrival: ScreenArrival): void {
    const sent: Record<string, string> = {};
    for (const field of this.fields) {
      const value = arrival.criteria[field.param];
      if (typeof value === 'string') sent[field.param] = value;
    }
    this.values = { ...declaredDefaults(this.fields), ...sent };
    this.arrivalSent = sent;
    this.edited.clear();
    this.mode = 'arrival';
    this.notify();
  }

  /** What the next read sends, read at call time. */
  criteria(): ScreenReadCriteria {
    if (this.mode === 'default') return {};
    if (this.mode === 'arrival') return { ...this.arrivalSent };
    return { ...this.values };
  }

  /**
   * Fill each criterion the request `sent` left absent from the answer's applied criteria (AD-36),
   * so the form shows the values the instance used. An answer to a request since replaced changes
   * nothing, and a criterion the person has changed since keeps what they entered.
   */
  applyEcho(applied: Readonly<Record<string, string>>, sent: ScreenReadCriteria): void {
    if (JSON.stringify(sent) !== JSON.stringify(this.criteria())) return;
    let changed = false;
    for (const field of this.fields) {
      if (sent[field.param] !== undefined || this.edited.has(field.param)) continue;
      const value = applied[field.param];
      if (typeof value !== 'string') continue;
      this.values[field.param] = value;
      changed = true;
    }
    if (changed) this.notify();
  }

  /** The one `RefreshRead` this store holds, built by `create` on first ask. */
  readFor(create: () => RefreshRead): RefreshRead {
    if (this.cachedRead === null) this.cachedRead = create();
    return this.cachedRead;
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/** What one compile request answered, as the page hands it to `CodeListWrite.runCompile`. */
export interface CompileAnswer {
  /** The instance applied the request; a refused one carries `reason` instead. */
  readonly applied: boolean;
  /** The compiler's console lines, in order. */
  readonly lines: readonly string[];
  /** The compiler reported an error. */
  readonly errors: boolean;
  /** The refusal's own sentence (AD-39), or `''`. */
  readonly reason: string;
}

/** One document a delete answered for: deleted, or refused with the instance's own reason. */
export interface DeletedDocument {
  readonly name: string;
  readonly deleted: boolean;
  readonly reason: string;
}

/** What one delete request answered, as the page hands it to `CodeListWrite.runDelete`. */
export interface DeleteAnswer {
  readonly applied: boolean;
  readonly documents: readonly DeletedDocument[];
}

/** `template` with each `<placeholder>` of `values` replaced. */
export function fillPlaceholders(template: string, values: Readonly<Record<string, string | number>>): string {
  let text = template;
  for (const [key, value] of Object.entries(values)) text = text.split(`<${key}>`).join(String(value));
  return text;
}

/** The console lines a compile's `output` carries, or `[]` (AD-39's fifth exception). */
export function compileLinesOf(output: unknown): { readonly lines: readonly string[]; readonly errors: boolean } {
  if (output === null || typeof output !== 'object') return { lines: [], errors: false };
  const lines = (output as Record<string, unknown>)['lines'];
  const errors = (output as Record<string, unknown>)['errors'] === true;
  return { lines: Array.isArray(lines) ? lines.filter((line): line is string => typeof line === 'string') : [], errors };
}

/** The per-document results a delete's `output` carries, or `[]`. */
export function deletedDocumentsOf(output: unknown): readonly DeletedDocument[] {
  if (output === null || typeof output !== 'object') return [];
  const documents = (output as Record<string, unknown>)['documents'];
  if (!Array.isArray(documents)) return [];
  const results: DeletedDocument[] = [];
  for (const entry of documents) {
    if (entry === null || typeof entry !== 'object') continue;
    const record = entry as Record<string, unknown>;
    const name = record['name'];
    if (typeof name !== 'string') continue;
    results.push({ name, deleted: record['deleted'] === true, reason: typeof record['reason'] === 'string' ? record['reason'] : '' });
  }
  return results;
}

/**
 * The Classes and Routines lists' write state (AD-19, Story 19.2): the compile sequence's queue, its
 * position and stop flag, the lines the output pane shows and the polite status line.
 *
 * **Framework-free.** The page hands it the one request each step makes (`send`) and mirrors it into
 * signals; it imports nothing from Angular, so `code-list.page.spec.ts` and `node --test` drive it.
 *
 * **One request per document, in the order given** (AD-7, AD-12): each answer's lines are appended
 * as it lands, before the next request is sent, and Stop sends nothing further. A refused request is
 * a line in the pane, and the sequence goes on. A delete is one request over the whole set.
 */
export class CodeListWrite {
  private kind: '' | 'compile' | 'delete' = '';

  private names: readonly string[] = [];

  private position = 0;

  private current = '';

  private stopRequested = false;

  private runningNow = false;

  private done = 0;

  private withErrors = 0;

  private linesValue: string[] = [];

  private summary = '';

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Whether a compile sequence or a delete is in flight. */
  running(): boolean {
    return this.runningNow;
  }

  /** Whether the running operation is a compile sequence, which Stop applies to. */
  stoppable(): boolean {
    return this.runningNow && this.kind === 'compile';
  }

  /** The output pane's lines, oldest first. */
  lines(): readonly string[] {
    return this.linesValue;
  }

  /** The polite status line: the step in flight, else the summary the last operation left. */
  status(): string {
    if (!this.runningNow) return this.summary;
    if (this.kind === 'delete') return fillPlaceholders(STRINGS.explorerDeleteRunning, { n: this.names.length });
    return fillPlaceholders(STRINGS.explorerCompileRunning, { i: this.position, n: this.names.length, name: this.current });
  }

  /** Stop: the request in flight lands, and none after it is sent. */
  stop(): void {
    if (!this.stoppable()) return;
    this.stopRequested = true;
    this.notify();
  }

  /** Compile `names` one request at a time through `send`, in that order. Ignored while running. */
  async runCompile(names: readonly string[], send: (name: string) => Promise<CompileAnswer>): Promise<void> {
    if (this.runningNow || names.length === 0) return;
    this.begin('compile', names);
    for (const name of names) {
      if (this.stopRequested) break;
      this.position += 1;
      this.current = name;
      this.notify();
      const answer = await send(name);
      if (answer.applied) {
        this.done += 1;
        if (answer.errors) this.withErrors += 1;
        this.linesValue = [...this.linesValue, ...answer.lines];
      } else {
        this.linesValue = [...this.linesValue, fillPlaceholders(STRINGS.explorerDocumentResult, { name, reason: answer.reason })];
      }
      this.notify();
    }
    const stopped = this.stopRequested && this.position < names.length;
    this.summary = stopped
      ? fillPlaceholders(STRINGS.explorerCompileStopped, { done: this.position, n: names.length })
      : fillPlaceholders(STRINGS.explorerCompileSummary, { done: this.done, n: names.length, errors: this.withErrors });
    this.end();
  }

  /** Delete `names` as one request through `send`, and list each document's result. */
  async runDelete(names: readonly string[], send: () => Promise<DeleteAnswer>): Promise<boolean> {
    if (this.runningNow || names.length === 0) return false;
    this.begin('delete', names);
    this.notify();
    const answer = await send();
    let deleted = 0;
    if (answer.applied) {
      for (const document of answer.documents) {
        if (document.deleted) deleted += 1;
        this.linesValue = [
          ...this.linesValue,
          document.deleted
            ? fillPlaceholders(STRINGS.explorerDeleteDeleted, { name: document.name })
            : fillPlaceholders(STRINGS.explorerDocumentResult, { name: document.name, reason: document.reason }),
        ];
      }
      this.summary = fillPlaceholders(STRINGS.explorerDeleteSummary, { done: deleted, n: names.length });
    }
    this.end();
    return answer.applied;
  }

  private begin(kind: 'compile' | 'delete', names: readonly string[]): void {
    this.kind = kind;
    this.names = [...names];
    this.position = 0;
    this.current = '';
    this.stopRequested = false;
    this.runningNow = true;
    this.done = 0;
    this.withErrors = 0;
    this.linesValue = [];
    this.summary = '';
  }

  private end(): void {
    this.runningNow = false;
    this.stopRequested = false;
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

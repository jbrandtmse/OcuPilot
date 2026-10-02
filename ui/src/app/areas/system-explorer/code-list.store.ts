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

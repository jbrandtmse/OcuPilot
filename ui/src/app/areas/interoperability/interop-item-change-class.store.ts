import { Injectable, Injector, inject } from '@angular/core';

import { ApiService } from '../../core/api';
import { STRINGS } from '../../core/strings';

/** The tool whose read lists the classes an item can change to: the item's Classes tab (Story 20.41). */
export const INTEROP_ITEM_CLASSES_TOOL = 'interop.itemclasses';

/** The screen read the picker reads, as the Classes tab reads it. */
export const INTEROP_ITEM_CLASSES_PATH = `/api/ocupilot/screens/${INTEROP_ITEM_CLASSES_TOOL}/read`;

/** The most rows the picker asks for: the three kinds' compiled classes fit under it together. */
export const INTEROP_ITEM_CLASSES_MAX_ROWS = 1000;

/** One class an item can change to: its name and the kind it is a class of. */
export interface ClassOption {
  readonly name: string;
  readonly type: string;
}

/**
 * Production items' Change class picker (Story 20.41, AD-5, AD-19): the classes the item's Classes tab lists, read
 * through the same screen read as that tab, less the item's own class, and the one the person chose.
 *
 * **It composes no rule of its own.** The rows are the instance's (`Current` marks the class the item has, which is
 * left out), and every refusal sentence is the server's (AD-39); a read that fails without one reads as the shell's server-fault
 * sentence, so the dialog never stands empty with no word. The review that follows (the settings the new class
 * does not take) is the handler's dry run, not this store's.
 *
 * **The namespace is the shell's**, which the API service attaches to every request, so the list is read where the
 * Production items list reads.
 */
@Injectable({ providedIn: 'root' })
export class InteropItemChangeClassStore {
  private readonly injector = inject(Injector);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private optionList: readonly ClassOption[] = [];

  private loadingValue = false;

  private loadedValue = false;

  private reasonValue = '';

  private choiceValue = '';

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** The classes offered, in the order the instance lists them: every row but the item's own. */
  options(): readonly ClassOption[] {
    return this.optionList;
  }

  loading(): boolean {
    return this.loadingValue;
  }

  /** Whether a read has answered, so an empty list can be told from one not yet read. */
  loaded(): boolean {
    return this.loadedValue;
  }

  /** The instance's refusal of the read, or `''`. */
  reason(): string {
    return this.reasonValue;
  }

  /** The class chosen, or `''` until the person chooses one. */
  choice(): string {
    return this.choiceValue;
  }

  /** Forget everything: when the dialog opens and when it closes, so nothing outlives the dialog. */
  reset(): void {
    this.generation += 1;
    this.optionList = [];
    this.loadingValue = false;
    this.loadedValue = false;
    this.reasonValue = '';
    this.choiceValue = '';
    this.notify();
  }

  /** Choose `name`, which must be one of the classes offered; anything else leaves no choice. */
  choose(name: string): void {
    const next = this.optionList.some((option) => option.name === name) ? name : '';
    if (next === this.choiceValue) return;
    this.choiceValue = next;
    this.notify();
  }

  /** Read the classes the item `item` of `production` can change to. A read that is superseded by a reset is dropped. */
  async load(production: string, item: string): Promise<void> {
    const generation = this.generation;
    this.loadingValue = true;
    this.reasonValue = '';
    this.notify();
    const query = new URLSearchParams({ maxRows: String(INTEROP_ITEM_CLASSES_MAX_ROWS), item: `${production}||${item}` });
    const result = await this.injector.get(ApiService).requestJson<unknown>(`${INTEROP_ITEM_CLASSES_PATH}?${query.toString()}`);
    if (generation !== this.generation) return;
    this.loadingValue = false;
    if (result.kind === 'ok') {
      this.optionList = optionsOf(result.body);
      this.loadedValue = true;
    } else {
      this.reasonValue = result.kind === 'error' && typeof result.reason === 'string' && result.reason !== '' ? result.reason : STRINGS.connectivityServerFault;
    }
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/** The classes a screen read's body lists, less the one flagged `Current`. */
function optionsOf(body: unknown): readonly ClassOption[] {
  const rows = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['rows'] : undefined;
  if (!Array.isArray(rows)) return [];
  const options: ClassOption[] = [];
  for (const row of rows as readonly unknown[]) {
    if (row === null || typeof row !== 'object') continue;
    const entry = row as Record<string, unknown>;
    const name = entry['ClassName'];
    if (typeof name !== 'string' || name === '' || entry['Current'] === true) continue;
    options.push({ name, type: typeof entry['Type'] === 'string' ? entry['Type'] : '' });
  }
  return options;
}

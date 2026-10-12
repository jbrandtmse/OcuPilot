import { Injectable, Injector, inject } from '@angular/core';

import type { JsonResult } from '../../core/api';
import type { ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import { postInteropCreate } from './interop-create';

/** The route both the New table and the Add entry dialogs post to (AD-55): the same tool the agent's add resolves. */
export const INTEROP_LOOKUP_ENTRY_PATH = '/api/ocupilot/interop/lookup-entries';

/** The entity type the add's change event carries (AD-13, AD-14). */
export const INTEROP_LOOKUP_ENTRY_ENTITY = 'lookup-entry';

/** The tool the add's change event names (AD-14), which keeps its toast on the entries it added. */
export const INTEROP_LOOKUP_ENTRY_ADD_TOOL = 'interop.lookupentries.add';

/** The members the add sends, named as the server names them. */
export const INTEROP_LOOKUP_FIELDS = {
  table: 'Table',
  key: 'Key',
  value: 'Value',
} as const;

/** The members the dialog draws a field for, so a refusal on one of them is shown under it. */
const DRAWN_FIELDS: readonly string[] = [INTEROP_LOOKUP_FIELDS.table, INTEROP_LOOKUP_FIELDS.key, INTEROP_LOOKUP_FIELDS.value];

/**
 * Lookup tables' Add (Story 20.5, AD-19, AD-55): one entry, sent to one lookup table of one namespace. A table is
 * created by its first entry, so this one store serves both the New table dialog, which asks for the table's name,
 * and the entries list's Add entry dialog, whose table is the one the route names.
 *
 * **It composes no rule of its own.** `POST /interop/lookup-entries` resolves the same tool the agent's
 * `interop.lookupentries.add` does, and every sentence the dialog shows is the server's (AD-39): a violation on a
 * field, or the reason of an envelope refusal such as a key the table already holds. The value is sent as typed,
 * empty included.
 *
 * **The namespace is the caller's**, passed to `add` and sent as the request's scope, so the entry lands where the
 * list that opened the dialog reads. An accepted add publishes one `created` change event for the entry the server
 * names, which re-reads the lists (AD-14), even when the dialog was dismissed while the add was in flight. A refusal
 * on a field the dialog does not draw is shown as the dialog's reason.
 */
@Injectable({ providedIn: 'root' })
export class InteropLookupEntryStore {
  private readonly injector = inject(Injector);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private tableValue = '';

  private keyValue = '';

  private entryValue = '';

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private readBackValue: ReadBack | null = null;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** The table name typed in the New table dialog. */
  table(): string {
    return this.tableValue;
  }

  key(): string {
    return this.keyValue;
  }

  value(): string {
    return this.entryValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  /** The refusal on `field`, or `''`. */
  violation(field: string): string {
    return reasonForField(this.violationList, field);
  }

  /** The reason of a refusal that names no field of this form, or `''`. */
  reason(): string {
    return this.envelopeReason;
  }

  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  /** Forget everything: when the dialog opens and when it closes, so nothing outlives the dialog. */
  reset(): void {
    this.generation += 1;
    this.tableValue = '';
    this.keyValue = '';
    this.entryValue = '';
    this.savingValue = false;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
  }

  /** Set one field's text, clearing a refusal the old value earned. */
  set(field: 'table' | 'key' | 'value', text: string): void {
    const current = { table: this.tableValue, key: this.keyValue, value: this.entryValue }[field];
    if (text === current) return;
    if (field === 'table') this.tableValue = text;
    if (field === 'key') this.keyValue = text;
    if (field === 'value') this.entryValue = text;
    this.clearRefusal();
  }

  /**
   * Post the entry, as typed, to `table` of `namespace`, or to the table typed in the dialog when `table` is
   * `null`. Answers whether the instance added it; a refusal keeps the fields so they can be corrected.
   */
  async add(namespace: string, table: string | null): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    const body = {
      [INTEROP_LOOKUP_FIELDS.table]: table ?? this.tableValue,
      [INTEROP_LOOKUP_FIELDS.key]: this.keyValue,
      [INTEROP_LOOKUP_FIELDS.value]: this.entryValue,
    };
    this.savingValue = true;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
    // A dialog dismissed while the add was in flight keeps none of its answer, but an entry the instance added
    // is still announced, so the lists re-read.
    let current = false as boolean;
    const outcome = await postInteropCreate(
      this.injector,
      { path: INTEROP_LOOKUP_ENTRY_PATH, namespace, body, type: INTEROP_LOOKUP_ENTRY_ENTITY, tool: INTEROP_LOOKUP_ENTRY_ADD_TOOL },
      (landed) => {
        current = generation === this.generation;
        if (!current) return;
        this.savingValue = false;
        if (landed.accepted) this.readBackValue = landed.readBack;
        else this.refuse(landed.result);
      }
    );
    if (!outcome.accepted || !current) return false;
    this.notify();
    return true;
  }

  private clearRefusal(): void {
    this.violationList = [];
    this.envelopeReason = '';
    this.notify();
  }

  private refuse(result: JsonResult<unknown>): void {
    this.violationList = violationsOf(result);
    const named = this.violationList.some((entry) => DRAWN_FIELDS.includes(entry.field));
    this.envelopeReason = !named && result.kind === 'error' ? (result.reason ?? '') : '';
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

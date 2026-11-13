import { Injectable, Injector, inject } from '@angular/core';

import type { JsonResult } from '../../core/api';
import type { ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import { postInteropCreate } from './interop-create';
import { INTEROP_ITEM_ENTITY } from './interop-item-add.store';

/** The route the Copy dialog posts to (AD-55): the same tool the agent's copy resolves. */
export const INTEROP_ITEM_COPY_PATH = '/api/ocupilot/interop/items/copy';

/** The tool the copy's change event names (AD-14), which keeps its toast on Production items. */
export const INTEROP_ITEM_COPY_TOOL = 'interop.items.copy';

/** The members the copy sends, named as the server names them. */
export const INTEROP_ITEM_COPY_FIELDS = {
  production: 'Production',
  name: 'Name',
  copyFrom: 'CopyFrom',
} as const;

/**
 * Production items' Copy (Story 20.40, AD-19, AD-55): the new item's name, sent with the item it copies to one
 * production of one namespace.
 *
 * **It composes no rule of its own.** `POST /interop/items/copy` resolves the same tool the agent's
 * `interop.items.copy` does, and every sentence the dialog shows is the server's (AD-39): a violation on the name,
 * or the reason of an envelope refusal such as a name the production already holds or a source it no longer holds.
 *
 * **The namespace is the caller's**, passed to `copy` and sent as `?ns=`, so the copy lands where the list that
 * opened the dialog reads. An accepted copy publishes one `created` change event for the item the server names,
 * which re-reads the list (AD-14), even when the dialog was dismissed while the copy was in flight.
 */
@Injectable({ providedIn: 'root' })
export class InteropItemCopyStore {
  private readonly injector = inject(Injector);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private nameValue = '';

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

  name(): string {
    return this.nameValue;
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
    this.nameValue = '';
    this.savingValue = false;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
  }

  /** Set the new item's name, clearing a refusal the old value earned. */
  setName(value: string): void {
    if (value === this.nameValue) return;
    this.nameValue = value;
    this.violationList = [];
    this.envelopeReason = '';
    this.notify();
  }

  /**
   * Post the copy of `source`, as typed, to `production` of `namespace`. Answers whether the instance added it; a
   * refusal keeps the name so it can be corrected.
   */
  async copy(namespace: string, production: string, source: string): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    const body: Record<string, unknown> = {
      [INTEROP_ITEM_COPY_FIELDS.production]: production,
      [INTEROP_ITEM_COPY_FIELDS.name]: this.nameValue,
      [INTEROP_ITEM_COPY_FIELDS.copyFrom]: source,
    };
    this.savingValue = true;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
    // A dialog dismissed while the copy was in flight keeps none of its answer, but an item the instance added is
    // still announced, so the list re-reads.
    let current = false as boolean;
    const outcome = await postInteropCreate(
      this.injector,
      { path: INTEROP_ITEM_COPY_PATH, namespace, body, type: INTEROP_ITEM_ENTITY, tool: INTEROP_ITEM_COPY_TOOL },
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

  private refuse(result: JsonResult<unknown>): void {
    this.violationList = violationsOf(result);
    const named = this.violationList.some((entry) => entry.field === INTEROP_ITEM_COPY_FIELDS.name);
    this.envelopeReason = !named && result.kind === 'error' ? (result.reason ?? '') : '';
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

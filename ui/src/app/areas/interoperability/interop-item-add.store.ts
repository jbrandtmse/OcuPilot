import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { NAMESPACE_SCOPE, scopeFor } from '../../core/entity-ref';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The route the Add dialog posts to (AD-55): the same tool the agent's add resolves. */
export const INTEROP_ITEM_ADD_PATH = '/api/ocupilot/interop/items';

/** The entity type the add's change event carries (AD-13, AD-14). */
export const INTEROP_ITEM_ENTITY = 'production-item';

/** The members the add sends, named as the server names them. */
export const INTEROP_ITEM_FIELDS = {
  production: 'Production',
  name: 'Name',
  className: 'ClassName',
  poolSize: 'PoolSize',
  enabled: 'Enabled',
  category: 'Category',
  comment: 'Comment',
} as const;

/** The members the dialog draws a field for, so a refusal on one of them is shown under it. */
const DRAWN_FIELDS: readonly string[] = [
  INTEROP_ITEM_FIELDS.name,
  INTEROP_ITEM_FIELDS.className,
  INTEROP_ITEM_FIELDS.poolSize,
  INTEROP_ITEM_FIELDS.category,
  INTEROP_ITEM_FIELDS.comment,
];

/** Whether `text` is a whole number the add can send as the pool size. */
function isWholeNumber(text: string): boolean {
  return /^\d{1,9}$/.test(text);
}

/**
 * Production items' Add (Story 20.3, AD-19, AD-55): one item's six fields, sent to one production of one
 * namespace.
 *
 * **It composes no rule of its own.** `POST /interop/items` resolves the same tool the agent's
 * `interop.items.add` does, and every sentence the dialog shows is the server's (AD-39): a violation on a
 * field, or the reason of an envelope refusal such as a name the production already holds. The pool size is
 * sent as a number when it is a whole number and as typed otherwise, so the server answers the refusal.
 *
 * **The namespace is the caller's**, passed to `add` and sent as `?ns=`, so the item lands where the list
 * that opened the dialog reads. An accepted add publishes one `created` change event for the item the server
 * names, which re-reads the list (AD-14), even when the dialog was dismissed while the add was in flight. A
 * refusal on a field the dialog does not draw is shown as the dialog's reason.
 */
@Injectable({ providedIn: 'root' })
export class InteropItemAddStore {
  private readonly injector = inject(Injector);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private nameValue = '';

  private classValue = '';

  private poolValue = '';

  private enabledValue = false;

  private categoryValue = '';

  private commentValue = '';

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

  className(): string {
    return this.classValue;
  }

  poolSize(): string {
    return this.poolValue;
  }

  enabled(): boolean {
    return this.enabledValue;
  }

  category(): string {
    return this.categoryValue;
  }

  comment(): string {
    return this.commentValue;
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
    this.classValue = '';
    this.poolValue = '';
    this.enabledValue = false;
    this.categoryValue = '';
    this.commentValue = '';
    this.savingValue = false;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
  }

  /** Set one field's text, clearing a refusal the old value earned. */
  set(field: 'name' | 'className' | 'poolSize' | 'category' | 'comment', value: string): void {
    const current = { name: this.nameValue, className: this.classValue, poolSize: this.poolValue, category: this.categoryValue, comment: this.commentValue }[field];
    if (value === current) return;
    if (field === 'name') this.nameValue = value;
    if (field === 'className') this.classValue = value;
    if (field === 'poolSize') this.poolValue = value;
    if (field === 'category') this.categoryValue = value;
    if (field === 'comment') this.commentValue = value;
    this.clearRefusal();
  }

  setEnabled(value: boolean): void {
    if (value === this.enabledValue) return;
    this.enabledValue = value;
    this.clearRefusal();
  }

  /**
   * Post the item, as typed, to `production` of `namespace`. Answers whether the instance added it; a
   * refusal keeps the fields so they can be corrected.
   */
  async add(namespace: string, production: string): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    const body: Record<string, unknown> = {
      [INTEROP_ITEM_FIELDS.production]: production,
      [INTEROP_ITEM_FIELDS.name]: this.nameValue,
      [INTEROP_ITEM_FIELDS.className]: this.classValue,
      [INTEROP_ITEM_FIELDS.enabled]: this.enabledValue,
    };
    const pool = this.poolValue.trim();
    if (pool !== '') body[INTEROP_ITEM_FIELDS.poolSize] = isWholeNumber(pool) ? Number(pool) : pool;
    if (this.categoryValue !== '') body[INTEROP_ITEM_FIELDS.category] = this.categoryValue;
    if (this.commentValue !== '') body[INTEROP_ITEM_FIELDS.comment] = this.commentValue;
    this.savingValue = true;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
    const result = await this.injector.get(ApiService).requestJson<unknown>(INTEROP_ITEM_ADD_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      scope: namespace,
    });
    // A dialog dismissed while the add was in flight keeps none of its answer, but an item the instance added
    // is still announced, so the list re-reads.
    const current = generation === this.generation;
    if (result.kind !== 'ok') {
      if (current) {
        this.savingValue = false;
        this.refuse(result);
      }
      return false;
    }
    const answer = result.body !== null && typeof result.body === 'object' ? (result.body as Record<string, unknown>) : {};
    const readBack = readBackOf(answer['readBack']);
    const target = answer['target'] !== null && typeof answer['target'] === 'object' ? (answer['target'] as Record<string, unknown>) : {};
    const id = typeof target['id'] === 'string' && target['id'] !== '' ? target['id'] : typeof answer['id'] === 'string' ? answer['id'] : '';
    if (current) {
      this.savingValue = false;
      this.readBackValue = readBack;
    }
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: INTEROP_ITEM_ENTITY,
      scope: scopeFor(NAMESPACE_SCOPE, namespace),
      id,
      action: 'created',
      readBack,
    });
    if (!current) return false;
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

import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { NAMESPACE_SCOPE, scopeFor } from '../../core/entity-ref';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The route the create dialog posts to (AD-55): the same tool the agent's create resolves. */
export const DOCDB_CREATE_PATH = '/api/ocupilot/explorer/docdb';

/** The entity type the create's change event carries (AD-13, AD-14). */
export const DOCDB_ENTITY = 'docdb-database';

/** The one field the create sends, named as the server names it. */
export const DOCDB_NAME_FIELD = 'Name';

/**
 * Document databases' create (Story 19.17, AD-19, AD-55): one name, sent to one namespace.
 *
 * **It composes no rule of its own.** `POST /explorer/docdb` resolves the same tool the agent's
 * `explorer.docdb.create` does, and every sentence the dialog shows is the server's (AD-39): a
 * violation on `Name`, or the reason of an envelope refusal such as a name already taken.
 *
 * **The namespace is the caller's**, passed to `create` and sent as `?ns=`, so the database lands
 * where the list that opened the dialog reads. An accepted create publishes one `created` change
 * event in that namespace's scope, which re-reads the list (AD-14).
 */
@Injectable({ providedIn: 'root' })
export class DocDbCreateStore {
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

  /** The refusal on `Name`, or `''`. */
  nameViolation(): string {
    return reasonForField(this.violationList, DOCDB_NAME_FIELD);
  }

  /** The reason of a refusal that names no field, or `''`. */
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

  /** Set the name, clearing a refusal the old one earned. */
  setName(value: string): void {
    if (value === this.nameValue) return;
    this.nameValue = value;
    this.violationList = [];
    this.envelopeReason = '';
    this.notify();
  }

  /**
   * Post the name, as typed, to `namespace`. Answers whether the instance created the database; a
   * refusal keeps the name so it can be corrected.
   */
  async create(namespace: string): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    const name = this.nameValue;
    this.savingValue = true;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
    const result = await this.injector.get(ApiService).requestJson<unknown>(DOCDB_CREATE_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ [DOCDB_NAME_FIELD]: name }),
      scope: namespace,
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.refuse(result);
      return false;
    }
    const answer = result.body !== null && typeof result.body === 'object' ? (result.body as Record<string, unknown>) : {};
    this.readBackValue = readBackOf(answer['readBack']);
    const created = typeof answer['name'] === 'string' && answer['name'] !== '' ? answer['name'] : name;
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: DOCDB_ENTITY,
      scope: scopeFor(NAMESPACE_SCOPE, namespace),
      id: created,
      action: 'created',
      readBack: this.readBackValue,
    });
    this.notify();
    return true;
  }

  private refuse(result: JsonResult<unknown>): void {
    this.violationList = violationsOf(result);
    const named = this.violationList.some((entry) => entry.field === DOCDB_NAME_FIELD);
    this.envelopeReason = !named && result.kind === 'error' ? (result.reason ?? '') : '';
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

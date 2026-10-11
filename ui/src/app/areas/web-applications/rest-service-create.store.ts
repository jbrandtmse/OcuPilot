import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { NAMESPACE_SCOPE, scopeFor } from '../../core/entity-ref';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The route the create dialog posts to (AD-55): the same tool the agent's create resolves. */
export const REST_SERVICE_CREATE_PATH = '/api/ocupilot/rest-service';

/** The entity type the create's change event carries (AD-13, AD-14). */
export const REST_SERVICE_ENTITY = 'rest-service';

/** The package field the create sends, named as the server names it. */
export const REST_SERVICE_NAME_FIELD = 'Name';

/** The document field the create sends: the OpenAPI 2.0 text, as typed or loaded. */
export const REST_SERVICE_DOCUMENT_FIELD = 'Document';

/**
 * The REST API explorer's create (Story 18.34, AD-19, AD-55): a package and an OpenAPI 2.0 document
 * text, sent to one namespace.
 *
 * **It composes no rule of its own.** `POST /rest-service` resolves the same tool the agent's
 * `webapp.restapis.create` does and parses the text on the instance, so the document travels as the
 * text the person gave and every sentence the dialog shows is the server's (AD-39): a violation on
 * `Name` or `Document`, or the reason of an envelope refusal such as a busy target.
 *
 * **The namespace is the caller's**, passed to `create` and sent as `?ns=`, so the service is built
 * where the list that opened the dialog reads. An accepted create publishes one `created` change
 * event in that namespace's scope, which re-reads the list (AD-14), also when the dialog was
 * dismissed before the instance answered.
 */
@Injectable({ providedIn: 'root' })
export class RestServiceCreateStore {
  private readonly injector = inject(Injector);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private nameValue = '';

  private documentValue = '';

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

  documentText(): string {
    return this.documentValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  /** The refusal on `Name`, or `''`. */
  nameViolation(): string {
    return reasonForField(this.violationList, REST_SERVICE_NAME_FIELD);
  }

  /** The refusal on `Document`, or `''`. */
  documentViolation(): string {
    return reasonForField(this.violationList, REST_SERVICE_DOCUMENT_FIELD);
  }

  /** The reason of a refusal that names neither field, or `''`. */
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
    this.documentValue = '';
    this.savingValue = false;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
  }

  /** Set the package, clearing a refusal the old one earned. */
  setName(value: string): void {
    if (value === this.nameValue) return;
    this.nameValue = value;
    this.clearRefusal();
    this.notify();
  }

  /** Set the document text, clearing a refusal the old one earned. */
  setDocumentText(value: string): void {
    if (value === this.documentValue) return;
    this.documentValue = value;
    this.clearRefusal();
    this.notify();
  }

  /**
   * Post the package and the document text, as typed, to `namespace`. Answers whether the instance
   * built the service; a refusal keeps both fields so they can be corrected.
   */
  async create(namespace: string): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    const name = this.nameValue;
    const text = this.documentValue;
    this.savingValue = true;
    this.clearRefusal();
    this.readBackValue = null;
    this.notify();
    const result = await this.injector.get(ApiService).requestJson<unknown>(REST_SERVICE_CREATE_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ [REST_SERVICE_NAME_FIELD]: name, [REST_SERVICE_DOCUMENT_FIELD]: text }),
      scope: namespace,
    });
    if (generation !== this.generation) {
      // The dialog is gone and keeps nothing, but a service the instance built still re-reads the list.
      if (result.kind === 'ok') this.publishCreated(result.body, name, namespace);
      return false;
    }
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.refuse(result);
      return false;
    }
    this.readBackValue = this.publishCreated(result.body, name, namespace);
    this.notify();
    return true;
  }

  /** Publish the one `created` event for an accepted create in `namespace`'s scope, and answer its read-back. */
  private publishCreated(body: unknown, name: string, namespace: string): ReadBack | null {
    const answer = body !== null && typeof body === 'object' ? (body as Record<string, unknown>) : {};
    const readBack = readBackOf(answer['readBack']);
    const created = typeof answer['name'] === 'string' && answer['name'] !== '' ? answer['name'] : name;
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: REST_SERVICE_ENTITY,
      scope: scopeFor(NAMESPACE_SCOPE, namespace),
      id: created,
      action: 'created',
      readBack,
    });
    return readBack;
  }

  private clearRefusal(): void {
    this.violationList = [];
    this.envelopeReason = '';
  }

  private refuse(result: JsonResult<unknown>): void {
    this.violationList = violationsOf(result);
    const named = this.violationList.some((entry) => entry.field === REST_SERVICE_NAME_FIELD || entry.field === REST_SERVICE_DOCUMENT_FIELD);
    this.envelopeReason = !named && result.kind === 'error' ? (result.reason ?? '') : '';
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

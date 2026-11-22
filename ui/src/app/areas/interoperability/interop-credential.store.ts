import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import type { ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import { postInteropCreate } from './interop-create';

/** The route the New credential dialog posts to (AD-55): the same tool the agent's add resolves. */
export const INTEROP_CREDENTIAL_PATH = '/api/ocupilot/interop/credentials';

/** The entity type the add's change event carries (AD-13, AD-14). */
export const INTEROP_CREDENTIAL_ENTITY = 'interop-credential';

/** The tool the add's change event names (AD-14), which keeps its toast on the credentials it added. */
export const INTEROP_CREDENTIAL_ADD_TOOL = 'interop.credentials.add';

/** The credential's name, which is the target: sent by an add, shown and never sent by an edit. */
export const INTEROP_CREDENTIAL_NAME = 'Name';

/** The two fields beside the name, named as the server names them, in the order the dialog draws them. */
export const INTEROP_CREDENTIAL_VALUE_FIELDS = ['Username', 'BusinessPartner'] as const;

/** The password's member, sent by an add and by Set password and never held by this store. */
export const INTEROP_CREDENTIAL_PASSWORD = 'Password';

/** The screen read the partner picker reads, as the Business partners list reads it. */
export const INTEROP_CREDENTIAL_PARTNERS_PATH = '/api/ocupilot/screens/interop.businesspartners/read';

/** The most partners the picker asks for. */
export const INTEROP_CREDENTIAL_PARTNERS_MAX_ROWS = 1000;

/** The members the dialog draws a field for, so a refusal on one of them is shown under it. */
const DRAWN_FIELDS: readonly string[] = [INTEROP_CREDENTIAL_NAME, ...INTEROP_CREDENTIAL_VALUE_FIELDS, INTEROP_CREDENTIAL_PASSWORD];

/** One form's values, keyed by the server's member names. The password is not among them. */
export type CredentialValues = Readonly<Record<string, string>>;

/** The form with every field empty. */
function emptyValues(): Record<string, string> {
  return Object.fromEntries([INTEROP_CREDENTIAL_NAME, ...INTEROP_CREDENTIAL_VALUE_FIELDS].map((field) => [field, '']));
}

/**
 * Credentials' New credential, Edit and Set password form (Story 24.15, AD-19, AD-35, AD-55): the values of one credential's name, user name and
 * business partner, the refusals drawn under them, the business partners the picker offers, and the add that posts them.
 *
 * **It composes no rule of its own.** `POST /interop/credentials` resolves the same tool the agent's `interop.credentials.add` does, and every
 * sentence the dialog shows is the server's (AD-39): a violation on a field, or the reason of an envelope refusal such as a name the namespace holds.
 *
 * **It never holds a password.** The dialog reads the password from its field at the moment of the submit and hands it to `add`, which sends it
 * once and keeps no copy; Set password is sent by the page through the screen action route, with the password in the one call.
 *
 * **The namespace is the caller's**, passed to `add` and sent as the request's scope, so the credential lands where the list that opened the dialog
 * reads. An accepted add publishes one `created` change event for the credential the server names, which re-reads the list (AD-14), even when the
 * dialog was dismissed while the add was in flight.
 */
@Injectable({ providedIn: 'root' })
export class InteropCredentialStore {
  private readonly injector = inject(Injector);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private text: Record<string, string> = emptyValues();

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private readBackValue: ReadBack | null = null;

  private partnerList: readonly string[] = [];

  private partnersLoadedValue = false;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** One field's value, `''` for one never set. */
  value(field: string): string {
    return this.text[field] ?? '';
  }

  /** Every value the form holds. */
  values(): CredentialValues {
    return { ...this.text };
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

  /** The business partners the picker offers, in the order the instance lists them. */
  partners(): readonly string[] {
    return this.partnerList;
  }

  /** Whether the partners were read, so an empty list can be told from one not yet read. */
  partnersLoaded(): boolean {
    return this.partnersLoadedValue;
  }

  /** Forget everything, and hold `initial` where the dialog edits a credential: when it opens and when it closes. */
  reset(initial: CredentialValues | null = null): void {
    this.generation += 1;
    this.text = initial === null ? emptyValues() : { ...emptyValues(), ...initial };
    this.savingValue = false;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.partnerList = [];
    this.partnersLoadedValue = false;
    this.notify();
  }

  /** Set one field, clearing a refusal the old value earned. */
  set(field: string, text: string): void {
    if (this.value(field) === text) return;
    this.text[field] = text;
    this.clearRefusal();
  }

  /** Mark a send as begun, and answer the generation it belongs to, so a dialog closed meanwhile no longer takes its answer. */
  begin(): number {
    this.savingValue = true;
    this.violationList = [];
    this.envelopeReason = '';
    this.notify();
    return this.generation;
  }

  /** Whether `generation` is still the form's own: false once the dialog was reset. */
  current(generation: number): boolean {
    return generation === this.generation;
  }

  /** Keep a send's refusal: the violations of its fields and, for one naming none, the reason. */
  refuse(violations: readonly Violation[], reason: string): void {
    this.savingValue = false;
    this.violationList = violations;
    const named = violations.some((entry) => DRAWN_FIELDS.includes(entry.field));
    this.envelopeReason = named ? '' : reason;
    this.notify();
  }

  /** End a send that was applied. */
  finish(): void {
    this.savingValue = false;
    this.notify();
  }

  /** Read the namespace's business partners through the Business partners screen's read; a read that fails leaves none to offer. */
  async loadPartners(): Promise<void> {
    const generation = this.generation;
    const query = new URLSearchParams({ maxRows: String(INTEROP_CREDENTIAL_PARTNERS_MAX_ROWS) });
    const result = await this.injector.get(ApiService).requestJson<unknown>(`${INTEROP_CREDENTIAL_PARTNERS_PATH}?${query.toString()}`);
    if (generation !== this.generation) return;
    this.partnerList = result.kind === 'ok' ? namesOf(result.body) : [];
    this.partnersLoadedValue = true;
    this.notify();
  }

  /**
   * Post the credential, as typed, to `namespace`, with `password` when one was typed (an empty one sends none). Answers whether the instance
   * added it; a refusal keeps the fields so they can be corrected. The password is held by this call alone.
   */
  async add(namespace: string, password: string): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    const body: Record<string, unknown> = { ...this.text };
    if (password !== '') body[INTEROP_CREDENTIAL_PASSWORD] = password;
    this.savingValue = true;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
    // A dialog dismissed while the add was in flight keeps none of its answer, but a credential the instance added is still
    // announced, so the list re-reads.
    let current = false as boolean;
    const outcome = await postInteropCreate(
      this.injector,
      { path: INTEROP_CREDENTIAL_PATH, namespace, body, type: INTEROP_CREDENTIAL_ENTITY, tool: INTEROP_CREDENTIAL_ADD_TOOL },
      (landed) => {
        current = generation === this.generation;
        if (!current) return;
        this.savingValue = false;
        if (landed.accepted) this.readBackValue = landed.readBack;
        else this.refuseResult(landed.result);
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

  private refuseResult(result: JsonResult<unknown>): void {
    this.refuse(violationsOf(result), result.kind === 'error' ? (result.reason ?? '') : '');
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/** The names a Business partners screen read's body lists, empty ones left out. */
function namesOf(body: unknown): readonly string[] {
  const rows = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['rows'] : undefined;
  if (!Array.isArray(rows)) return [];
  const names: string[] = [];
  for (const row of rows as readonly unknown[]) {
    if (row === null || typeof row !== 'object') continue;
    const name = (row as Record<string, unknown>)['Name'];
    if (typeof name === 'string' && name !== '') names.push(name);
  }
  return names;
}

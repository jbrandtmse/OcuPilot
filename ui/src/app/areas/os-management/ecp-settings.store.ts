import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { screenForRoute } from '../../core/navigation';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { createScreenRead } from '../../core/screen-read';
import { ENTITY_SINGLETON_ID } from '../../core/screens.generated';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The screen this store serves (Story 18.21). */
export const ECP_SETTINGS_ROUTE = 'os-management/ecp-settings';

/** The Save's route and the form read's (AD-20, AD-55). */
export const ECP_SETTINGS_PATH = '/api/ocupilot/ecp-settings';
export const ECP_SETTINGS_FORM_PATH = '/api/ocupilot/ecp-settings/form';

/** The change event's triple (AD-13, AD-14): the instance's one set of ECP settings. */
export const ECP_SETTINGS_ENTITY = 'ecp-settings';
export const ECP_SETTINGS_SCOPE = 'instance';

/** The declared read answers one object, so one row is the whole answer. */
export const ECP_SETTINGS_MAX_ROWS = 1;

/** The two objects the settings travel in. */
export const APP_GROUP = 'AppServerSettings';
export const DATA_GROUP = 'DataServerSettings';

/** The numeric members, each as `<Object>.<member>`, the read's field and the violation's. */
export const NUMBER_FIELDS: readonly string[] = [
  `${APP_GROUP}.MaxServers`,
  `${APP_GROUP}.ClientReconnectDuration`,
  `${APP_GROUP}.ClientReconnectInterval`,
  `${DATA_GROUP}.MaxServerConn`,
  `${DATA_GROUP}.ServerTroubleDuration`,
];

/** The member whose change takes effect only after a restart. */
export const RESTART_FIELD = `${DATA_GROUP}.MaxServerConn`;

/** ECP SSL/TLS support: 0 Disabled, 1 Enabled, 2 Required. */
export const SSL_FIELD = `${DATA_GROUP}.SSLECPServer`;
export const SSL_CHOICES: readonly number[] = [0, 1, 2];

/** The consequence a Save's answer carries when it changed `RESTART_FIELD`. */
export const RESTART_CONSEQUENCE = 'ECP.SETTINGS.RESTART';

/** The `%ECPServer` configuration's state, as the form read answers it. */
export type ServerSsl = 'absent' | 'disabled' | 'enabled';

function textOf(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

/** A whole number as a JSON number, anything else as the text typed, so the server's rule answers it. */
function numberValue(text: string): number | string {
  return /^[0-9]{1,9}$/.test(text) ? Number(text) : text;
}

/** The object and member a `<Object>.<member>` field names. */
function split(field: string): readonly [string, string] {
  const dot = field.indexOf('.');
  return [field.slice(0, dot), field.slice(dot + 1)];
}

/**
 * ECP settings' store (Story 18.21, AD-19, AD-55): the instance's ECP settings, read through the
 * screen's own declared read, so the form and `osmgmt.ecpsettings.read` answer one read (AD-36), and
 * the form read's license and `%ECPServer` answers.
 *
 * **It composes no payload of its own.** `PUT /ecp-settings` carries a nested object of the changed
 * members only; the server merges them over its own fresh read and sends both objects complete
 * (AD-4), through the tool the agent's `osmgmt.ecpsettings.update` resolves. Every sentence is the
 * server's (AD-39).
 *
 * **SSL/TLS support's Enabled and Required take no choice unless `%ECPServer` is enabled**, as the
 * server refuses them; a Save that changed the maximum number of application servers keeps the
 * restart sentence the server answers until the form is next changed.
 */
@Injectable({ providedIn: 'root' })
export class EcpSettingsForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private textValues: Readonly<Record<string, string>> = {};

  private openedText: Readonly<Record<string, string>> = {};

  private sslValue = 0;

  private openedSsl = 0;

  private licensedValue = true;

  private serverSslValue: ServerSsl = 'absent';

  private loadedValue = false;

  private heldValue = false;

  private faultValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private savedValue = false;

  private restartValue = false;

  private readBackValue: ReadBack | null = null;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  loaded(): boolean {
    return this.loadedValue;
  }

  /** Whether the fields take input: only once the read is held. */
  editable(): boolean {
    return this.heldValue;
  }

  /** Whether the read was refused or failed, which offers Retry. */
  fault(): boolean {
    return this.faultValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  canSave(): boolean {
    return this.heldValue && !this.savingValue;
  }

  text(field: string): string {
    return this.textValues[field] ?? '';
  }

  /** ECP SSL/TLS support's value: 0, 1 or 2. */
  ssl(): number {
    return this.sslValue;
  }

  /** Whether the instance's license includes ECP, as the form read answers it. */
  licensed(): boolean {
    return this.licensedValue;
  }

  serverSsl(): ServerSsl {
    return this.serverSslValue;
  }

  /** Why SSL/TLS support's `choice` cannot be chosen, or `''`: Enabled and Required need `%ECPServer` enabled. */
  sslRefusal(choice: number): string {
    return choice !== 0 && this.serverSslValue !== 'enabled' ? 'server-ssl' : '';
  }

  violations(): readonly Violation[] {
    return this.violationList;
  }

  violationFor(field: string): string {
    return reasonForField(this.violationList, field);
  }

  reason(): string {
    return this.envelopeReason;
  }

  refusalCode(): string {
    return this.refusalCodeValue;
  }

  refusalPair(): string {
    return this.refusalPairValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  /** Whether the last accepted Save changed a member that takes effect only after a restart. */
  restartPending(): boolean {
    return this.restartValue;
  }

  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the page is left. */
  reset(): void {
    this.generation += 1;
    this.textValues = {};
    this.openedText = {};
    this.sslValue = 0;
    this.openedSsl = 0;
    this.licensedValue = true;
    this.serverSslValue = 'absent';
    this.loadedValue = false;
    this.heldValue = false;
    this.faultValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.restartValue = false;
    this.readBackValue = null;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form over the screen's declared read and the form read. `keepSaved` carries the last
   * accepted Save's confirmation, and its restart sentence, across the re-read that follows it.
   */
  async open(keepSaved = false): Promise<void> {
    const saved = keepSaved && this.savedValue;
    const restart = keepSaved && this.restartValue;
    const readBack = this.readBackValue;
    this.reset();
    if (saved) {
      this.savedValue = true;
      this.restartValue = restart;
      this.readBackValue = readBack;
    }
    const screen = screenForRoute(ECP_SETTINGS_ROUTE);
    if (screen === null || screen.read === null) return;
    const generation = this.generation;
    const [result, form] = await Promise.all([
      createScreenRead(this.api(), screen)({ maxRows: ECP_SETTINGS_MAX_ROWS }),
      this.api().requestJson<unknown>(ECP_SETTINGS_FORM_PATH),
    ]);
    if (generation !== this.generation) return;
    this.loadedValue = true;
    const row = result.kind === 'ok' ? result.rows[0] : undefined;
    if (row === null || row === undefined || typeof row !== 'object' || Array.isArray(row) || form.kind !== 'ok') {
      this.faultValue = true;
      this.rememberRefusal(form);
      this.notify();
      return;
    }
    this.absorbForm(form.body);
    this.absorb(row as Record<string, unknown>);
    this.notify();
  }

  setText(field: string, value: string): void {
    if (!this.heldValue || !NUMBER_FIELDS.includes(field) || this.text(field) === value) return;
    this.textValues = { ...this.textValues, [field]: value };
    this.change(field);
  }

  /** Choose ECP SSL/TLS support's `value`; a choice `sslRefusal` refuses is never made. */
  setSsl(value: number): void {
    if (!this.heldValue || !SSL_CHOICES.includes(value) || this.sslValue === value || this.sslRefusal(value) !== '') return;
    this.sslValue = value;
    this.change(SSL_FIELD);
  }

  /**
   * Save: put the changed members, nested in their objects. An accepted Save publishes one
   * `ecp-settings` `updated` change event (AD-14) and re-reads the form; a refused one keeps what was
   * entered.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const body = this.saveBody();
    if (Object.keys(body).length === 0) {
      this.clearRefusal();
      this.readBackValue = null;
      this.restartValue = false;
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.restartValue = false;
    this.readBackValue = null;
    this.notify();
    const result = await this.api().requestJson<unknown>(ECP_SETTINGS_PATH, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.notify();
      return false;
    }
    const answer = result.body !== null && typeof result.body === 'object' ? (result.body as Record<string, unknown>) : {};
    this.readBackValue = readBackOf(answer['readBack']);
    this.restartValue = answer['consequence'] === RESTART_CONSEQUENCE;
    this.savedValue = true;
    this.formDirty.setDirty(false);
    this.publish();
    this.notify();
    await this.open(true);
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  /** The body of a Save: the changed members only, each in its object. */
  saveBody(): Record<string, Record<string, unknown>> {
    const body: Record<string, Record<string, unknown>> = {};
    const put = (field: string, value: unknown): void => {
      const [group, member] = split(field);
      body[group] = { ...(body[group] ?? {}), [member]: value };
    };
    for (const field of NUMBER_FIELDS) {
      if (this.text(field) !== (this.openedText[field] ?? '')) put(field, numberValue(this.text(field)));
    }
    if (this.sslValue !== this.openedSsl) put(SSL_FIELD, this.sslValue);
    return body;
  }

  private absorbForm(body: unknown): void {
    const form = body !== null && typeof body === 'object' ? (body as Record<string, unknown>) : {};
    this.licensedValue = form['licensed'] !== false;
    const state = form['serverSsl'];
    this.serverSslValue = state === 'enabled' || state === 'disabled' ? state : 'absent';
  }

  private absorb(row: Record<string, unknown>): void {
    const text: Record<string, string> = {};
    for (const field of NUMBER_FIELDS) text[field] = textOf(row[field]);
    this.textValues = text;
    this.openedText = text;
    const ssl = Number(row[SSL_FIELD]);
    this.sslValue = SSL_CHOICES.includes(ssl) ? ssl : 0;
    this.openedSsl = this.sslValue;
    this.heldValue = true;
  }

  private change(field: string): void {
    this.clearFieldViolation(field);
    this.savedValue = false;
    this.restartValue = false;
    this.formDirty.setDirty(Object.keys(this.saveBody()).length > 0);
    this.notify();
  }

  private clearFieldViolation(field: string): void {
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
  }

  private rememberRefusal(result: JsonResult<unknown>): void {
    if (result.kind !== 'error') {
      this.clearRefusal();
      return;
    }
    this.refusalCodeValue = result.code ?? '';
    const pair = result.detail === null ? undefined : result.detail['failedPair'];
    this.refusalPairValue = typeof pair === 'string' ? pair : '';
  }

  private clearRefusal(): void {
    this.envelopeReason = '';
    this.refusalCodeValue = '';
    this.refusalPairValue = '';
  }

  private publish(): void {
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: ECP_SETTINGS_ENTITY,
      scope: ECP_SETTINGS_SCOPE,
      id: ENTITY_SINGLETON_ID,
      action: 'updated',
      readBack: this.readBackValue,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

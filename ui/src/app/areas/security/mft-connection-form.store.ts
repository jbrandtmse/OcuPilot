import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { screenForDescriptor } from '../../core/navigation';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { screenReadPath } from '../../core/screen-read';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` creates, `PUT <path>/<id>` edits. */
export const MFT_CONNECTION_PATH = '/api/ocupilot/mft-connection';

/** The form read: the connection's six fields, or the empty row of a new one. */
export const MFT_CONNECTION_FORM_PATH = `${MFT_CONNECTION_PATH}/form`;

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const MFT_CONNECTION_ENTITY = 'mft-connection';
export const MFT_CONNECTION_SCOPE = 'instance';

/** The two tools a Save is one caller of (AD-55), named on the change event. */
export const MFT_CONNECTION_CREATE_TOOL = 'security.mftconnections.create';
export const MFT_CONNECTION_UPDATE_TOOL = 'security.mftconnections.update';

/** The SSL/TLS configurations list, whose declared read offers the picker's rows (AD-5). */
export const SSL_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.SslConfigList';

/** The most rows the picker's read asks for. */
export const SSL_MAX_ROWS = 500;

/** The `Type` the SSL/TLS list reads for a client configuration. */
export const SSL_CLIENT_TYPE = 'Client';

/** The fields, named as the server names them. */
export const NAME_FIELD = 'Name';
export const SERVICE_FIELD = 'Service';
export const URL_FIELD = 'URL';
export const SSL_FIELD = 'SSLConfiguration';
export const USERNAME_FIELD = 'Username';
export const APPLICATION_FIELD = 'ApplicationName';

/** The file services a connection can name; the vendor's own class names, sent as they are. */
export const SERVICES: readonly string[] = ['Box', 'Dropbox', 'Kiteworks'];

/** The fields an edit may send; `Name` and `Service` are fixed once the connection exists. */
export const EDITABLE_FIELDS: readonly string[] = [URL_FIELD, SSL_FIELD, USERNAME_FIELD, APPLICATION_FIELD];

/** Every field a create sends, in the order the body lists them. */
export const CREATE_FIELDS: readonly string[] = [NAME_FIELD, SERVICE_FIELD, URL_FIELD, SSL_FIELD, USERNAME_FIELD, APPLICATION_FIELD];

/** What the form is doing: creating a connection, or editing the one its route names. */
export type FormMode = 'create' | 'edit';

type Buffer = Readonly<Record<string, string>>;

/** A new connection starts empty except for the first service. */
const EMPTY_BUFFER: Buffer = {
  [NAME_FIELD]: '',
  [SERVICE_FIELD]: SERVICES[0],
  [URL_FIELD]: '',
  [SSL_FIELD]: '',
  [USERNAME_FIELD]: '',
  [APPLICATION_FIELD]: '',
};

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

/**
 * The managed file transfer connection editor's store (Story 18.26, AD-19, AD-55): a create on
 * `security/mft-connections/edit`, an edit of the connection its route names on
 * `security/mft-connections/edit/<name>`, the id the connection's name kept exactly (AD-13).
 *
 * **It composes no payload of its own.** `POST /mft-connection` and `PUT /mft-connection/<id>` resolve the
 * same tool classes the agent's `security.mftconnections.create` and `.update` do, and every field sentence
 * is the server's (AD-39). An edit sends only the fields changed since its fresh read (AD-4); `Name` and
 * `Service` are shown and never sent on an edit.
 */
@Injectable({ providedIn: 'root' })
export class MftConnectionForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private idValue = '';

  private clientConfigs: readonly string[] = [];

  private loadedValue = false;

  private heldValue = false;

  private absentValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private refusedValues: Record<string, string> = {};

  private savedValue = false;

  private readBackValue: ReadBack | null = null;

  private createdIdValue = '';

  private retainingValue = false;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  mode(): FormMode {
    return this.modeValue;
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  /** Whether an edit names a connection the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** The text a field holds now. */
  value(field: string): string {
    return this.buffer[field] ?? '';
  }

  /** The connection an edit names, as its id. */
  id(): string {
    return this.idValue;
  }

  /** The client SSL/TLS configurations the picker offers, by name. */
  configs(): readonly string[] {
    return this.clientConfigs;
  }

  /** Whether the fields take input: in edit mode only once the fresh read is held. */
  editable(): boolean {
    return this.modeValue === 'create' || this.heldValue;
  }

  canSave(): boolean {
    if (this.savingValue || this.absentValue) return false;
    return this.modeValue === 'create' || this.heldValue;
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

  /** The read-back the last accepted Save answered (AD-58), which its "Saved" line renders. */
  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  /** The created connection's id as the instance stores it, or `''`. */
  createdId(): string {
    return this.createdIdValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  retaining(): boolean {
    return this.retainingValue;
  }

  /** Keep this form's state across the one navigation that is not a departure. */
  retainAcrossRouteReplacement(): void {
    this.retainingValue = true;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the form is left. */
  reset(): void {
    this.generation += 1;
    this.modeValue = 'create';
    this.buffer = EMPTY_BUFFER;
    this.opened = EMPTY_BUFFER;
    this.idValue = '';
    this.clientConfigs = [];
    this.loadedValue = false;
    this.heldValue = false;
    this.absentValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.readBackValue = null;
    this.createdIdValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form: a create when `id` is empty, an edit of that connection otherwise. The form read and the
   * SSL/TLS list's declared read are made on every open. An arrival that is the create's own route
   * replacement opens the new connection's edit and keeps the saved confirmation on screen.
   */
  async open(id: string): Promise<void> {
    const arriving = this.retainingValue && id !== '' && id === this.createdIdValue;
    const readBack = arriving ? this.readBackValue : null;
    this.reset();
    if (arriving) {
      this.savedValue = true;
      this.readBackValue = readBack;
    }
    this.modeValue = id === '' ? 'create' : 'edit';
    const generation = this.generation;
    const path = id === '' ? MFT_CONNECTION_FORM_PATH : `${MFT_CONNECTION_FORM_PATH}?id=${encodeURIComponent(id)}`;
    const [result, configs] = await Promise.all([this.api().requestJson<unknown>(path), this.readConfigs()]);
    if (generation !== this.generation) return;
    this.clientConfigs = configs;
    this.absorb(result, id);
    this.loadedValue = true;
    this.notify();
  }

  /** A field's input. The name and service change on a create only. */
  setValue(field: string, value: string): void {
    if (!this.editable()) return;
    if (this.modeValue === 'edit' && (field === NAME_FIELD || field === SERVICE_FIELD)) return;
    if (!CREATE_FIELDS.includes(field)) return;
    if (this.value(field) === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.change(field);
  }

  /** On blur: drop a refusal that no longer describes what the field holds. */
  onBlur(field: string): void {
    const refused = this.refusedValues[field];
    if (refused === undefined || this.value(field) === refused) return;
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.clearFieldViolation(field);
    this.notify();
  }

  /**
   * Save: a create posts the six fields; an edit puts the fields changed since its fresh read. An accepted
   * Save publishes one change event (AD-14) and marks the form clean; a refused one keeps what was entered
   * so a field can be corrected.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const creating = this.modeValue === 'create';
    if (!creating && Object.keys(this.changedFields()).length === 0) {
      this.clearRefusal();
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.readBackValue = null;
    this.notify();

    const sent = { ...this.buffer };
    const result = creating
      ? await this.api().requestJson<unknown>(MFT_CONNECTION_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.createBody()),
        })
      : await this.api().requestJson<unknown>(`${MFT_CONNECTION_PATH}/${encodeEntityId(this.idValue)}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.changedFields()),
        });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, sent);
      this.notify();
      return false;
    }
    const body = result.body as Record<string, unknown> | null;
    const id = creating ? textAt(body, 'id') || this.value(NAME_FIELD) : this.idValue;
    if (creating) this.createdIdValue = id;
    this.opened = this.buffer;
    this.savedValue = true;
    this.readBackValue = readBackOf(body?.['readBack']);
    this.formDirty.setDirty(false);
    this.publish(id, creating ? 'created' : 'updated');
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private change(field: string): void {
    this.clearFieldViolation(field);
    this.savedValue = false;
    this.formDirty.setDirty(true);
    this.notify();
  }

  private clearFieldViolation(field: string): void {
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
  }

  /** A create's body: the six fields as typed (AD-54). */
  private createBody(): Record<string, unknown> {
    const body: Record<string, unknown> = {};
    for (const field of CREATE_FIELDS) body[field] = this.value(field);
    return body;
  }

  /** The body of an edit: only the fields changed since the fresh read (AD-4, the server merges). */
  private changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of EDITABLE_FIELDS) {
      if (this.value(field) !== (this.opened[field] ?? '')) out[field] = this.value(field);
    }
    return out;
  }

  /** The client SSL/TLS configurations' names, from the list's own declared read (AD-5); none when it fails. */
  private async readConfigs(): Promise<readonly string[]> {
    const screen = screenForDescriptor(SSL_LIST_DESCRIPTOR);
    if (screen === null || screen.read === null) return [];
    const result = await this.api().requestJson<unknown>(screenReadPath(screen, SSL_MAX_ROWS));
    if (result.kind !== 'ok' || result.body === null || typeof result.body !== 'object') return [];
    const rows = (result.body as Record<string, unknown>)['rows'];
    if (!Array.isArray(rows)) return [];
    return rows
      .filter((row) => textAt(row, 'Type') === SSL_CLIENT_TYPE)
      .map((row) => textAt(row, 'Name'))
      .filter((name) => name !== '');
  }

  private absorb(result: JsonResult<unknown>, id: string): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, {});
      if (id !== '' && result.kind === 'error' && result.status === 404) this.absentValue = true;
      return;
    }
    const body = result.body;
    const record = body !== null && typeof body === 'object' ? (body as Record<string, unknown>) : {};
    const row = record['row'];
    if (row === null || typeof row !== 'object') {
      if (id !== '') this.absentValue = true;
      return;
    }
    const held: Record<string, string> = {};
    for (const field of CREATE_FIELDS) held[field] = textAt(row, field);
    if (id === '') held[SERVICE_FIELD] = held[SERVICE_FIELD] === '' ? SERVICES[0] : held[SERVICE_FIELD];
    this.buffer = held;
    this.opened = held;
    if (id !== '') {
      this.idValue = id;
      this.heldValue = true;
    }
  }

  private rememberRefusal(result: JsonResult<unknown>, sent: Record<string, string>): void {
    if (result.kind !== 'error') {
      this.clearRefusal();
      return;
    }
    this.refusalCodeValue = result.code ?? '';
    const pair = result.detail === null ? undefined : result.detail['failedPair'];
    this.refusalPairValue = typeof pair === 'string' ? pair : '';
    this.refusedValues = sent;
  }

  private clearRefusal(): void {
    this.envelopeReason = '';
    this.refusalCodeValue = '';
    this.refusalPairValue = '';
    this.refusedValues = {};
  }

  private publish(id: string, action: ChangeAction): void {
    if (id === '') return;
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: MFT_CONNECTION_ENTITY,
      scope: MFT_CONNECTION_SCOPE,
      id,
      action,
      readBack: this.readBackValue,
      tool: action === 'created' ? MFT_CONNECTION_CREATE_TOOL : MFT_CONNECTION_UPDATE_TOOL,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

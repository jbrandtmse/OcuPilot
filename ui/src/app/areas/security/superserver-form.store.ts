import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId, joinCompositeId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { screenForDescriptor } from '../../core/navigation';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { screenReadPath } from '../../core/screen-read';
import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` creates, `PUT <path>/<id>` edits. */
export const SUPERSERVER_PATH = '/api/ocupilot/superserver';

/** The form read: the superserver's settings, whether the web gateway connects through it, its locked fields and the platform. */
export const SUPERSERVER_FORM_PATH = `${SUPERSERVER_PATH}/form`;

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const SUPERSERVER_ENTITY = 'superserver';
export const SUPERSERVER_SCOPE = 'instance';

/** The two tools a Save is one caller of (AD-55), named on the change event. */
export const SUPERSERVER_CREATE_TOOL = 'security.superservers.create';
export const SUPERSERVER_UPDATE_TOOL = 'security.superservers.update';

/** The SSL/TLS configurations list, whose declared read offers the picker's rows (AD-5). */
export const SSL_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.SslConfigList';

/** The most rows the picker's read asks for. */
export const SSL_MAX_ROWS = 500;

/** The `Type` the SSL/TLS list reads for a server configuration. */
export const SSL_SERVER_TYPE = 'Server';

/** The id parts and the settings, named as the server names them. */
export const PORT_FIELD = 'Port';
export const BIND_FIELD = 'BindAddress';
export const DESCRIPTION_FIELD = 'Description';
export const ENABLED_FIELD = 'Enabled';
export const CSP_FIELD = 'EnableCSP';
export const LEVEL_FIELD = 'SSLSupportLevel';
export const CONFIG_FIELD = 'SSLConfig';
export const SYSTEM_DEFAULT_FIELD = 'SystemDefault';

/** The three flags only the system default superserver may turn on, and the one only Windows has. */
export const SYSTEM_ONLY_FIELDS: readonly string[] = ['EnableECP', 'EnableMirror', 'EnableSharding'];
export const SNMP_FIELD = 'EnableSNMP';

/** Every flag, in the classic editor's order: general, client connections, system connections, other. */
export const FLAG_FIELDS: readonly string[] = [
  ENABLED_FIELD,
  'EnableClients',
  CSP_FIELD,
  'EnableDataCheck',
  'EnableCacheDirect',
  'EnableShadows',
  ...SYSTEM_ONLY_FIELDS,
  SNMP_FIELD,
  'EnableWebLink',
  'EnableNodeJS',
];

/** The settable text fields, in the order the body lists them. */
export const TEXT_FIELDS: readonly string[] = [DESCRIPTION_FIELD, CONFIG_FIELD, LEVEL_FIELD];

/** Every settable field: the fifteen the tools admit. */
export const SETTING_FIELDS: readonly string[] = [DESCRIPTION_FIELD, ...FLAG_FIELDS, LEVEL_FIELD, CONFIG_FIELD];

/** The SSL/TLS support levels, as the buffer holds them. */
export const LEVELS: readonly string[] = ['0', '1', '2'];

/** What the form is doing: creating a superserver, or editing the one its route names. */
export type FormMode = 'create' | 'edit';

type Buffer = Readonly<Record<string, string>>;

/** A new superserver's defaults, the vendor's own: Enabled and Clients on, level 0. */
const EMPTY_BUFFER: Buffer = {
  [PORT_FIELD]: '',
  [BIND_FIELD]: '',
  [DESCRIPTION_FIELD]: '',
  [LEVEL_FIELD]: '0',
  [CONFIG_FIELD]: '',
  ...Object.fromEntries(FLAG_FIELDS.map((field) => [field, field === ENABLED_FIELD || field === 'EnableClients' ? 'true' : 'false'])),
};

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

/** A flag as the form read answers it, as the buffer's text. */
function flagText(value: unknown): string {
  return value === true || value === 'true' || value === 1 ? 'true' : 'false';
}

/**
 * A field as the wire carries it: a flag as a boolean, the support level as a number when it is one of
 * the three, and every other field as typed.
 */
export function wireValue(field: string, text: string): string | number | boolean {
  if (FLAG_FIELDS.includes(field)) return text === 'true';
  if (field === LEVEL_FIELD) return LEVELS.includes(text) ? Number(text) : text;
  return text;
}

/**
 * The superserver editor's store (Story 18.25, AD-19, AD-55): a create on `security/superservers/edit`, an
 * edit of the superserver its route names on `security/superservers/edit/<id>`, the id the composite
 * `[Port, BindAddress]`.
 *
 * **It composes no payload of its own.** `POST /superserver` and `PUT /superserver/<id>` resolve the same
 * tool classes the agent's `security.superservers.create` and `.update` do, and every field sentence is the
 * server's (AD-39). An edit sends only the settings changed since its fresh read (AD-4); `SystemDefault` is
 * shown and never sent.
 *
 * **What the form read decides.** `locked` names the fields a change to which would cut off the web gateway:
 * they stay focusable, `aria-disabled`, with the server's sentence. ECP, mirroring and sharding take input
 * only on the system default superserver, and SNMP only where the instance runs on Windows. A changed SSL/TLS
 * field of a serving superserver states its consequence before Save.
 */
@Injectable({ providedIn: 'root' })
export class SuperserverForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private idValue = '';

  private servingValue = false;

  private systemDefaultValue = false;

  private windowsValue = false;

  private lockedReasons: Record<string, string> = {};

  private serverConfigs: readonly string[] = [];

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

  private consequenceValue = '';

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

  /** Whether an edit names a superserver the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** The text a field holds now; a flag's is `'true'` or `'false'`. */
  value(field: string): string {
    return this.buffer[field] ?? '';
  }

  checked(field: string): boolean {
    return this.value(field) === 'true';
  }

  /** The superserver an edit names, as its composite id. */
  id(): string {
    return this.idValue;
  }

  /** Whether the web gateway connects through this superserver (AD-10). */
  serving(): boolean {
    return this.servingValue;
  }

  /** Whether this superserver is the instance's system default, shown and never set. */
  systemDefault(): boolean {
    return this.systemDefaultValue;
  }

  /** Whether the instance runs on Windows, which SNMP needs. */
  windows(): boolean {
    return this.windowsValue;
  }

  /** The server's sentence for a field it locks, or `''`. */
  lockReason(field: string): string {
    return this.lockedReasons[field] ?? '';
  }

  /** Whether a flag takes no input because of what the superserver is (not because it is locked). */
  unavailable(field: string): boolean {
    if (SYSTEM_ONLY_FIELDS.includes(field)) return !this.systemDefaultValue;
    return field === SNMP_FIELD && !this.windowsValue;
  }

  /** The server SSL/TLS configurations the picker offers, by name. */
  configs(): readonly string[] {
    return this.serverConfigs;
  }

  /** Whether the fields take input: in edit mode only once the fresh read is held. */
  editable(): boolean {
    return this.modeValue === 'create' || this.heldValue;
  }

  canSave(): boolean {
    if (this.savingValue || this.absentValue) return false;
    return this.modeValue === 'create' || this.heldValue;
  }

  /**
   * The consequence a changed SSL/TLS field of a serving superserver states before Save: the
   * published sentence, or `''`.
   */
  sslCaption(): string {
    if (!this.servingValue) return '';
    const changed = this.value(LEVEL_FIELD) !== (this.opened[LEVEL_FIELD] ?? '') || this.value(CONFIG_FIELD) !== (this.opened[CONFIG_FIELD] ?? '');
    return changed ? STRINGS.superserverServesConsequence : '';
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

  /** The consequence the last accepted Save answered, or `''`. */
  consequence(): string {
    return this.consequenceValue;
  }

  /** The created superserver's composite id as the instance stores it, or `''`. */
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
    this.servingValue = false;
    this.systemDefaultValue = false;
    this.windowsValue = false;
    this.lockedReasons = {};
    this.serverConfigs = [];
    this.loadedValue = false;
    this.heldValue = false;
    this.absentValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.consequenceValue = '';
    this.readBackValue = null;
    this.createdIdValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form: a create when `id` is empty, an edit of that superserver otherwise. The form read and
   * the SSL/TLS list's declared read are made on every open. An arrival that is the create's own route
   * replacement opens the new superserver's edit and keeps the saved confirmation on screen.
   */
  async open(id: string): Promise<void> {
    const arriving = this.retainingValue && id !== '' && id === this.createdIdValue;
    const readBack = arriving ? this.readBackValue : null;
    const consequence = arriving ? this.consequenceValue : '';
    this.reset();
    if (arriving) {
      this.savedValue = true;
      this.readBackValue = readBack;
      this.consequenceValue = consequence;
    }
    this.modeValue = id === '' ? 'create' : 'edit';
    const generation = this.generation;
    const path = id === '' ? SUPERSERVER_FORM_PATH : `${SUPERSERVER_FORM_PATH}?id=${encodeURIComponent(id)}`;
    const [result, configs] = await Promise.all([this.api().requestJson<unknown>(path), this.readConfigs()]);
    if (generation !== this.generation) return;
    this.serverConfigs = configs;
    this.absorb(result, id);
    this.loadedValue = true;
    this.notify();
  }

  /** A text field's input. The port and bind address change on a create only. */
  setValue(field: string, value: string): void {
    if (!this.editable()) return;
    if (this.modeValue === 'edit' && (field === PORT_FIELD || field === BIND_FIELD)) return;
    if (!(field in EMPTY_BUFFER) || FLAG_FIELDS.includes(field)) return;
    if (this.value(field) === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.change(field);
  }

  /** A flag's input. A locked or unavailable flag takes none. */
  setFlag(field: string, checked: boolean): void {
    if (!this.editable() || !FLAG_FIELDS.includes(field)) return;
    if (this.lockReason(field) !== '' || this.unavailable(field)) return;
    const text = checked ? 'true' : 'false';
    if (this.value(field) === text) return;
    this.buffer = { ...this.buffer, [field]: text };
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
   * Save: a create posts the port, the bind address and the fifteen settings; an edit puts the settings
   * changed since its fresh read. An accepted Save publishes one change event (AD-14) and marks the form
   * clean; a refused one keeps what was entered so a field can be corrected.
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
    this.consequenceValue = '';
    this.readBackValue = null;
    this.notify();

    const sent = { ...this.buffer };
    const result = creating
      ? await this.api().requestJson<unknown>(SUPERSERVER_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.createBody()),
        })
      : await this.api().requestJson<unknown>(`${SUPERSERVER_PATH}/${encodeEntityId(this.idValue)}`, {
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
    const id = creating ? textAt(body, 'id') || joinCompositeId([this.value(PORT_FIELD).trim(), this.value(BIND_FIELD)]) : this.idValue;
    if (creating) this.createdIdValue = id;
    this.opened = this.buffer;
    this.savedValue = true;
    this.consequenceValue = textAt(body, 'consequence');
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
    this.consequenceValue = '';
    this.formDirty.setDirty(true);
    this.notify();
  }

  private clearFieldViolation(field: string): void {
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
  }

  /** A create's body: the id parts and the fifteen settings, typed as the wire expects (AD-54). */
  private createBody(): Record<string, unknown> {
    const body: Record<string, unknown> = { [PORT_FIELD]: this.value(PORT_FIELD).trim(), [BIND_FIELD]: this.value(BIND_FIELD).trim() };
    for (const field of SETTING_FIELDS) body[field] = wireValue(field, this.value(field));
    return body;
  }

  /** The body of an edit: only the settings changed since the fresh read (AD-4, the server merges). */
  private changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of SETTING_FIELDS) {
      if (this.value(field) !== (this.opened[field] ?? '')) out[field] = wireValue(field, this.value(field));
    }
    return out;
  }

  /** The server SSL/TLS configurations' names, from the list's own declared read (AD-5); none when it fails. */
  private async readConfigs(): Promise<readonly string[]> {
    const screen = screenForDescriptor(SSL_LIST_DESCRIPTOR);
    if (screen === null || screen.read === null) return [];
    const result = await this.api().requestJson<unknown>(screenReadPath(screen, SSL_MAX_ROWS));
    if (result.kind !== 'ok' || result.body === null || typeof result.body !== 'object') return [];
    const rows = (result.body as Record<string, unknown>)['rows'];
    if (!Array.isArray(rows)) return [];
    return rows
      .filter((row) => textAt(row, 'Type') === SSL_SERVER_TYPE)
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
    this.windowsValue = record['windows'] === true;
    this.servingValue = record['serving'] === true;
    const locked: Record<string, string> = {};
    for (const entry of Array.isArray(record['locked']) ? (record['locked'] as unknown[]) : []) {
      const field = textAt(entry, 'field');
      const reason = textAt(entry, 'reason');
      if (field !== '' && reason !== '') locked[field] = reason;
    }
    this.lockedReasons = locked;
    const row = record['row'];
    if (row === null || typeof row !== 'object') {
      if (id !== '') this.absentValue = true;
      return;
    }
    const held: Record<string, string> = {
      [PORT_FIELD]: textAt(row, PORT_FIELD),
      [BIND_FIELD]: textAt(row, BIND_FIELD),
      [DESCRIPTION_FIELD]: textAt(row, DESCRIPTION_FIELD),
      [CONFIG_FIELD]: textAt(row, CONFIG_FIELD),
      [LEVEL_FIELD]: LEVELS.includes(textAt(row, LEVEL_FIELD)) ? textAt(row, LEVEL_FIELD) : '0',
    };
    for (const field of FLAG_FIELDS) held[field] = flagText((row as Record<string, unknown>)[field]);
    this.systemDefaultValue = (row as Record<string, unknown>)[SYSTEM_DEFAULT_FIELD] === true;
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
      type: SUPERSERVER_ENTITY,
      scope: SUPERSERVER_SCOPE,
      id,
      action,
      readBack: this.readBackValue,
      tool: action === 'created' ? SUPERSERVER_CREATE_TOOL : SUPERSERVER_UPDATE_TOOL,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

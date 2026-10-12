import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { normalizeEntityId } from '../../core/entity-ref';
import { FormDirty } from '../../core/form-dirty';
import { screenForDescriptor } from '../../core/navigation';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { screenReadPath } from '../../core/screen-read';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import type { ApplicationRoleOption } from './create-form.store';

/** The routes the form saves through: `POST` creates, `PUT <path>/<id>` edits. */
export const ROUTINE_APP_PATH = '/api/ocupilot/routine-application';

/** The form read: the application's four fields, or the defaults of a new one. */
export const ROUTINE_APP_FORM_PATH = `${ROUTINE_APP_PATH}/form`;

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const ROUTINE_APP_ENTITY = 'routine-application';
export const ROUTINE_APP_SCOPE = 'instance';

/** The two tools a Save is one caller of (AD-55), named on the change event. */
export const ROUTINE_APP_CREATE_TOOL = 'webapp.routineapps.create';
export const ROUTINE_APP_UPDATE_TOOL = 'webapp.routineapps.update';

/** The Resources list, whose declared read offers the picker's rows (AD-5). */
export const RESOURCE_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.ResourceList';

/** The most rows the picker's read asks for. */
export const RESOURCE_MAX_ROWS = 500;

/** The `ResourceType` values the Resources list reads for the resources an application may name: the classic page's. */
export const RESOURCE_TYPES: readonly string[] = ['Service', 'System', 'Application'];

/** The fields, named as the server names them. */
export const NAME_FIELD = 'Name';
export const DESCRIPTION_FIELD = 'Description';
export const ENABLED_FIELD = 'Enabled';
export const RESOURCE_FIELD = 'Resource';

/** The fields an edit may send; `Name` is the id and fixed once the application exists. */
export const EDITABLE_FIELDS: readonly string[] = [DESCRIPTION_FIELD, ENABLED_FIELD, RESOURCE_FIELD];

/** Every field a create sends, in the order the body lists them. */
export const CREATE_FIELDS: readonly string[] = [NAME_FIELD, DESCRIPTION_FIELD, ENABLED_FIELD, RESOURCE_FIELD];

/** What the form is doing: creating an application, or editing the one its route names. */
export type FormMode = 'create' | 'edit';

/** The four tabs of an edit, named after the classic editor's (`%CSP.UI.Portal.Applications.PrivRoutine`). */
export const GENERAL_TAB = 'general';
export const APPLICATION_ROLES_TAB = 'application-roles';
export const MATCHING_ROLES_TAB = 'matching-roles';
export const ROUTINES_TAB = 'routines';

/** Which tab each field a Save can refuse is drawn on; the lists change through the tabs' row actions, never a Save. */
export const ROUTINE_APP_FIELD_TABS: Readonly<Record<string, string>> = {
  [NAME_FIELD]: GENERAL_TAB,
  [DESCRIPTION_FIELD]: GENERAL_TAB,
  [ENABLED_FIELD]: GENERAL_TAB,
  [RESOURCE_FIELD]: GENERAL_TAB,
};

/** One matching role the application grants: the role a caller must hold and the role it then receives. */
export interface MatchingRole {
  readonly match: string;
  readonly role: string;
}

/** One routine or class that may add roles for the application. */
export interface RoutineEntry {
  readonly name: string;
  readonly db: string;
  readonly type: string;
}

/** The text a flag's buffer holds. */
const ON = 'true';
const OFF = 'false';

type Buffer = Readonly<Record<string, string>>;

/** A new application starts empty and enabled, as the instance defaults it. */
const EMPTY_BUFFER: Buffer = {
  [NAME_FIELD]: '',
  [DESCRIPTION_FIELD]: '',
  [ENABLED_FIELD]: ON,
  [RESOURCE_FIELD]: '',
};

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function arrayAt(source: unknown, key: string): readonly unknown[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value : [];
}

/** The roles a form read lists as `[{name, privileged}]`; a role whose mark the server did not send as false reads as privileged. */
function roleOptionsOf(entries: readonly unknown[]): readonly ApplicationRoleOption[] {
  const out: ApplicationRoleOption[] = [];
  for (const entry of entries) {
    const name = textAt(entry, 'name');
    if (name === '' || out.some((role) => role.name === name)) continue;
    const mark = (entry as Record<string, unknown>)['privileged'];
    out.push({ name, privileged: !(mark === false || mark === 0) });
  }
  return out;
}

function flagAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return ON;
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'boolean') return value ? ON : OFF;
  return ON;
}

/**
 * The privileged routine application editor's store (Story 18.31, AD-19, AD-55): a create on
 * `web-applications/routine-applications/edit`, an edit of the application its route names on
 * `web-applications/routine-applications/edit/<id>`, the id the application's name, kept in any case by the instance and
 * folded by the key builder (AD-13). It is the Doc DB application editor's store without the namespace: no form base
 * exists to share (DW-2278).
 *
 * **It composes no payload of its own.** `POST /routine-application` and `PUT /routine-application/<id>` resolve the
 * same tool classes the agent's `webapp.routineapps.create` and `.update` do, and every field sentence is the
 * server's (AD-39). An edit sends only the fields changed since its fresh read (AD-4); `Name` is shown and never sent
 * on an edit.
 *
 * **The two lists are not this form's fields** (Story 18.33, AD-56 (ii)): the application roles, matching roles and
 * routines the form read answers are kept beside the General buffer, and change only through the list's six row actions,
 * each a delta the instance applies over its own fresh read; {@link refresh} reads them again. The instance's roles and
 * databases, which the tabs' pickers offer, ride the same read.
 */
@Injectable({ providedIn: 'root' })
export class RoutineAppForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private idValue = '';

  private resourceNames: readonly string[] = [];

  private matchRolesValue: readonly unknown[] = [];

  private routinesValue: readonly RoutineEntry[] = [];

  private roleOptions: readonly ApplicationRoleOption[] = [];

  private databaseNames: readonly string[] = [];

  private actionRefusalValue = '';

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

  /** Whether an edit names an application the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** The text a field holds now; a flag reads `true` or `false`. */
  value(field: string): string {
    return this.buffer[field] ?? '';
  }

  /** Whether the enabled flag is set. */
  enabled(): boolean {
    return this.value(ENABLED_FIELD) === ON;
  }

  /** The application an edit names, by its name. */
  id(): string {
    return this.idValue;
  }

  /** The service, system and application resources the picker offers, by name. */
  resources(): readonly string[] {
    return this.resourceNames;
  }

  /** The application roles it grants every request, as the instance spells them. */
  applicationRoles(): readonly string[] {
    const out: string[] = [];
    for (const entry of this.matchRolesValue) {
      if (textAt(entry, 'MatchRole') !== '') continue;
      for (const role of arrayAt(entry, 'TargetRoles')) if (typeof role === 'string' && role !== '') out.push(role);
    }
    return out;
  }

  /** The matching roles it grants, one per matching role and target role. */
  matchingRoles(): readonly MatchingRole[] {
    const out: MatchingRole[] = [];
    for (const entry of this.matchRolesValue) {
      const match = textAt(entry, 'MatchRole');
      if (match === '') continue;
      for (const role of arrayAt(entry, 'TargetRoles')) if (typeof role === 'string' && role !== '') out.push({ match, role });
    }
    return out;
  }

  /** The routines and classes it lists, as the instance spells them. */
  routines(): readonly RoutineEntry[] {
    return this.routinesValue;
  }

  /** The roles the instance holds, each with the server's privilege mark (AD-10). */
  roleChoices(): readonly ApplicationRoleOption[] {
    return this.roleOptions;
  }

  /**
   * Whether granting `role` grants `%All` or an administrative privilege, as the server marked it, the name matched without
   * regard to case as the instance resolves a role; unknown names read as privileged.
   */
  privileged(role: string): boolean {
    const choice = this.roleOptions.find((option) => option.name.toLowerCase() === role.toLowerCase());
    return choice === undefined ? true : choice.privileged;
  }

  /** The databases the instance defines, which a routine entry may name. */
  databases(): readonly string[] {
    return this.databaseNames;
  }

  /** The refusal sentence a tab's row action was answered with, or `''`. */
  actionRefusal(): string {
    return this.actionRefusalValue;
  }

  /** Whether the form shows the application `name`, in the one spelling a reference carries (AD-13). */
  is(name: string): boolean {
    return this.idValue !== '' && normalizeEntityId(ROUTINE_APP_ENTITY, name) === normalizeEntityId(ROUTINE_APP_ENTITY, this.idValue);
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

  /** The created application's id as the instance answered it, or `''`. */
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
    this.resourceNames = [];
    this.matchRolesValue = [];
    this.routinesValue = [];
    this.roleOptions = [];
    this.databaseNames = [];
    this.actionRefusalValue = '';
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
   * Open the form: a create when `id` is empty, an edit of that application otherwise. The form read and the
   * Resources list's declared read are made on every open. An arrival that is the create's own route replacement
   * opens the new application's edit and keeps the saved confirmation on screen.
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
    const path = id === '' ? ROUTINE_APP_FORM_PATH : `${ROUTINE_APP_FORM_PATH}?id=${encodeURIComponent(id)}`;
    const [result, resources] = await Promise.all([this.api().requestJson<unknown>(path), this.readResources()]);
    if (generation !== this.generation) return;
    this.resourceNames = resources;
    this.absorb(result, id);
    this.loadedValue = true;
    this.notify();
  }

  /**
   * Read the application again after a change event (AD-14) or an applied row action: its lists, roles and databases
   * always, and its General fields only while the form is clean, so nothing typed is overwritten.
   */
  async refresh(): Promise<void> {
    if (!this.heldValue) return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${ROUTINE_APP_FORM_PATH}?id=${encodeURIComponent(this.idValue)}`);
    if (generation !== this.generation || result.kind !== 'ok') return;
    this.absorb(result, this.idValue, !this.formDirty.dirty());
    this.notify();
  }

  /** Put a row action's refusal on screen, or clear it with `''`. */
  setActionRefusal(reason: string): void {
    if (this.actionRefusalValue === reason) return;
    this.actionRefusalValue = reason;
    this.notify();
  }

  /** A field's input. The name changes on a create only. */
  setValue(field: string, value: string): void {
    if (!this.editable()) return;
    if (this.modeValue === 'edit' && field === NAME_FIELD) return;
    if (!CREATE_FIELDS.includes(field)) return;
    if (this.value(field) === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.change(field);
  }

  /** The enabled flag's input. */
  setEnabled(enabled: boolean): void {
    this.setValue(ENABLED_FIELD, enabled ? ON : OFF);
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
   * Save: a create posts the four fields; an edit puts the fields changed since its fresh read. An accepted
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
      ? await this.api().requestJson<unknown>(ROUTINE_APP_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.createBody()),
        })
      : await this.api().requestJson<unknown>(`${ROUTINE_APP_PATH}/${encodeEntityId(this.idValue)}`, {
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

  /** A create's body: the name as typed (AD-54), the flag as a boolean, the rest as text. */
  private createBody(): Record<string, unknown> {
    const body: Record<string, unknown> = {};
    for (const field of CREATE_FIELDS) body[field] = field === ENABLED_FIELD ? this.enabled() : this.value(field);
    return body;
  }

  /** The body of an edit: only the fields changed since the fresh read (AD-4, the server merges). */
  private changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of EDITABLE_FIELDS) {
      if (this.value(field) === (this.opened[field] ?? '')) continue;
      out[field] = field === ENABLED_FIELD ? this.enabled() : this.value(field);
    }
    return out;
  }

  /** The service, system and application resources' names, from the list's own declared read (AD-5); none when it fails. */
  private async readResources(): Promise<readonly string[]> {
    const screen = screenForDescriptor(RESOURCE_LIST_DESCRIPTOR);
    if (screen === null || screen.read === null) return [];
    const result = await this.api().requestJson<unknown>(screenReadPath(screen, RESOURCE_MAX_ROWS));
    if (result.kind !== 'ok' || result.body === null || typeof result.body !== 'object') return [];
    const rows = (result.body as Record<string, unknown>)['rows'];
    if (!Array.isArray(rows)) return [];
    return rows
      .filter((row) => RESOURCE_TYPES.includes(textAt(row, 'ResourceType')))
      .map((row) => textAt(row, 'Name'))
      .filter((name) => name !== '');
  }

  private absorb(result: JsonResult<unknown>, id: string, fields = true): void {
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
    this.matchRolesValue = arrayAt(row, 'MatchRoles');
    this.routinesValue = arrayAt(row, 'Routines').map((entry) => ({
      name: textAt(entry, 'RoutineOrClass'),
      db: textAt(entry, 'Db'),
      type: textAt(entry, 'Type'),
    }));
    this.roleOptions = roleOptionsOf(arrayAt(record, 'roles'));
    this.databaseNames = arrayAt(record, 'databases').filter((entry): entry is string => typeof entry === 'string' && entry !== '');
    if (!fields) return;
    const held: Record<string, string> = {};
    for (const field of CREATE_FIELDS) held[field] = field === ENABLED_FIELD ? flagAt(row, field) : textAt(row, field);
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
      type: ROUTINE_APP_ENTITY,
      scope: ROUTINE_APP_SCOPE,
      id,
      action,
      readBack: this.readBackValue,
      tool: action === 'created' ? ROUTINE_APP_CREATE_TOOL : ROUTINE_APP_UPDATE_TOOL,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { normalizeEntityId } from '../../core/entity-ref';
import { FormDirty } from '../../core/form-dirty';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import {
  GRANTED_ROLES_FIELD,
  RESOURCES_FIELD,
  ROLES_FORM_PATH,
  ROLES_PATH,
  ROLE_ENTITY,
  ROLE_SCOPE,
  type Grant,
  type ResourceOption,
  type RoleOption,
} from './role-create-form.store';

/** The three tabs, named after the classic editor's (`%CSP.UI.Portal.Role`). */
export const GENERAL_TAB = 'general';

export const MEMBERS_TAB = 'members';

export const ASSIGNED_TO_TAB = 'assigned-to';

/** The two settings a Save carries, as the server names them (AD-55). */
export const DESCRIPTION_FIELD = 'Description';

export const ESCALATION_FIELD = 'EscalationOnly';

/** Every field the General tab draws, in order; the order a refused Save's first field is chosen in. */
export const GENERAL_FIELDS: readonly string[] = [DESCRIPTION_FIELD, ESCALATION_FIELD, RESOURCES_FIELD];

/** Which tab each field is drawn on. */
export const ROLE_FIELD_TABS: Readonly<Record<string, string>> = {
  [DESCRIPTION_FIELD]: GENERAL_TAB,
  [ESCALATION_FIELD]: GENERAL_TAB,
  [RESOURCES_FIELD]: GENERAL_TAB,
  [GRANTED_ROLES_FIELD]: ASSIGNED_TO_TAB,
};

/** The holder-list types the instance answers (`Security.Role` `OWNERLIST`). */
export const MEMBER_TYPE_USER = 'User';

export const MEMBER_TYPE_ROLE = 'Role';

export const MEMBER_TYPE_ESCALATION = 'User (escalation)';

/** One holder of the role, as the form read's `members` reports it. */
export interface Member {
  readonly name: string;
  readonly type: string;
}

interface Buffer {
  readonly description: string;
  readonly escalationOnly: boolean;
}

const EMPTY_BUFFER: Buffer = { description: '', escalationOnly: false };

function record(source: unknown): Readonly<Record<string, unknown>> | null {
  return source !== null && typeof source === 'object' && !Array.isArray(source) ? (source as Record<string, unknown>) : null;
}

function textAt(source: unknown, key: string): string {
  const value = record(source)?.[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function arrayAt(source: unknown, key: string): readonly unknown[] {
  const value = record(source)?.[key];
  return Array.isArray(value) ? value : [];
}

function flagAt(source: unknown, key: string): boolean {
  const value = record(source)?.[key];
  return value === true || value === 1 || value === '1' || value === 'true';
}

/** Whether the server's `privileged` flag marks an entry: anything not sent as false is marked. */
function marked(entry: unknown): boolean {
  const flag = record(entry)?.['privileged'];
  return !(flag === false || flag === 0);
}

/**
 * The role editor's store (AD-19, AD-55): an edit of the role `permissions/roles/edit/<id>` names.
 *
 * **It composes no payload of its own.** `PUT /roles/<id>` resolves the tool the agent's
 * `permissions.roles.update` does, merges the fields this store sends over its own fresh read, and
 * sends the complete set (AD-4); every field sentence is the server's (AD-39). **A Save sends only
 * the description and the escalation-only flag, and only where they changed since the read.**
 *
 * **Grants, granted roles and members are not fields of the form** (AD-56 (ii)). They are read from
 * the instance and changed through the Roles and Users lists' own actions, which apply a delta on
 * the instance; no Save carries them.
 */
@Injectable({ providedIn: 'root' })
export class RoleEditor {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private roleName = '';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private grantList: readonly Grant[] = [];

  private grantedList: readonly string[] = [];

  private memberList: readonly Member[] = [];

  private roleOptions: readonly RoleOption[] = [];

  private resourceOptions: readonly ResourceOption[] = [];

  private maxLengths: Record<string, number> = {};

  private loadedValue = false;

  private heldValue = false;

  private absentValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private actionRefusalValue = '';

  private refusedValues: Record<string, string> = {};

  private savedValue = false;

  /** The role a create has just made, whose editor opens already saved. */
  private arrivingSaved = '';

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  /** The role the editor shows, or the route's id before its read lands. */
  name(): string {
    return this.roleName;
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  /** Whether the fields take input: only once the role's read has landed. */
  editable(): boolean {
    return this.heldValue;
  }

  /** Whether the route names a role the instance does not hold. */
  absent(): boolean {
    return this.absentValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  canSave(): boolean {
    return this.heldValue && !this.savingValue && !this.absentValue;
  }

  description(): string {
    return this.buffer.description;
  }

  escalationOnly(): boolean {
    return this.buffer.escalationOnly;
  }

  /** The role's resource grants, in the order the instance answered them. */
  grants(): readonly Grant[] {
    return this.grantList;
  }

  /** The roles this role grants, as the instance spells them. */
  grantedRoles(): readonly string[] {
    return this.grantedList;
  }

  /** The accounts and roles that hold this role, in the instance's order. */
  members(): readonly Member[] {
    return this.memberList;
  }

  /** The roles the instance holds, each with its privilege mark. */
  roleChoices(): readonly RoleOption[] {
    return this.roleOptions;
  }

  /** The resources the instance holds, as the grant dialog offers them. */
  resourceChoices(): readonly ResourceOption[] {
    return this.resourceOptions;
  }

  /** Whether granting this role grants %All or an administrative privilege, by the server's mark (AD-10). */
  privileged(): boolean {
    const own = normalizeEntityId(ROLE_ENTITY, this.roleName);
    return this.roleOptions.some((option) => option.privileged && normalizeEntityId(ROLE_ENTITY, option.name) === own);
  }

  maxLength(field: string): number {
    const held = this.maxLengths[field];
    return typeof held === 'number' ? held : 0;
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

  /** The sentence an action on this role was refused with (AD-39), or `''`. */
  actionRefusal(): string {
    return this.actionRefusalValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  /** Whether the role is `name` in the one spelling a reference carries (AD-13). */
  is(name: string): boolean {
    return this.roleName !== '' && normalizeEntityId(ROLE_ENTITY, name) === normalizeEntityId(ROLE_ENTITY, this.roleName);
  }

  /** The fields a Save would send: each of the two changed since the read (AD-4, the server merges). */
  changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    if (this.buffer.description !== this.opened.description) out[DESCRIPTION_FIELD] = this.buffer.description;
    if (this.buffer.escalationOnly !== this.opened.escalationOnly) out[ESCALATION_FIELD] = this.buffer.escalationOnly;
    return out;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the editor is left. */
  reset(): void {
    this.generation += 1;
    this.roleName = '';
    this.buffer = EMPTY_BUFFER;
    this.opened = EMPTY_BUFFER;
    this.grantList = [];
    this.grantedList = [];
    this.memberList = [];
    this.roleOptions = [];
    this.resourceOptions = [];
    this.maxLengths = {};
    this.loadedValue = false;
    this.heldValue = false;
    this.absentValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.actionRefusalValue = '';
    this.savedValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /** Mark the role a create has just made, so its editor opens showing "Saved". */
  arriveSaved(name: string): void {
    this.arrivingSaved = name;
  }

  /** Open the editor on `name`: the form read is made on every open rather than cached. */
  async open(name: string): Promise<void> {
    const arriving = this.arrivingSaved !== '' && this.arrivingSaved === name;
    this.arrivingSaved = '';
    this.reset();
    this.roleName = name;
    if (arriving) this.savedValue = true;
    const generation = this.generation;
    const result = await this.read(name);
    if (generation !== this.generation) return;
    this.absorb(result, true);
    this.loadedValue = true;
    this.notify();
  }

  /**
   * Read the role again after a change event or an applied action (AD-14): in place while the form
   * is clean, and only its grants, granted roles and members while it holds unsaved work, so nothing
   * typed is overwritten.
   */
  async refresh(): Promise<void> {
    if (!this.heldValue) return;
    const generation = this.generation;
    const result = await this.read(this.roleName);
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') return;
    this.absorb(result, !this.formDirty.dirty());
    this.notify();
  }

  setDescription(value: string): void {
    if (!this.editable() || this.buffer.description === value) return;
    this.buffer = { ...this.buffer, description: value };
    this.change(DESCRIPTION_FIELD);
  }

  setEscalationOnly(on: boolean): void {
    if (!this.editable() || this.buffer.escalationOnly === on) return;
    this.buffer = { ...this.buffer, escalationOnly: on };
    this.change(ESCALATION_FIELD);
  }

  /** Drop a refusal that no longer describes what the field holds. */
  onBlur(field: string): void {
    const refused = this.refusedValues[field];
    if (refused === undefined || this.currentText(field) === refused) return;
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
    this.notify();
  }

  /** Put an action's refusal on screen, or clear it with `''`. */
  setActionRefusal(reason: string): void {
    if (this.actionRefusalValue === reason) return;
    this.actionRefusalValue = reason;
    this.notify();
  }

  /**
   * Save: put the fields changed since the read. An accepted Save publishes one change event
   * (AD-14), marks the form clean and keeps the route open showing "Saved"; a refused one keeps what
   * was entered so a field can be corrected.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const edits = this.changedFields();
    if (Object.keys(edits).length === 0) {
      this.clearRefusal();
      this.violationList = [];
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    const generation = this.generation;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.notify();
    const sent = this.snapshot();
    const sentBuffer = this.buffer;
    const result = await this.api().requestJson<unknown>(`${ROLES_PATH}/${encodeEntityId(this.roleName)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(edits),
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
    // What was sent is now stored; anything typed while the Save was in flight stays unsaved work.
    this.opened = sentBuffer;
    const unsaved = Object.keys(this.changedFields()).length > 0;
    this.savedValue = !unsaved;
    this.formDirty.setDirty(unsaved);
    this.injector.get(ChangeBus).publish({ kind: 'changed', type: ROLE_ENTITY, scope: ROLE_SCOPE, id: this.roleName, action: 'updated' });
    this.notify();
    return true;
  }

  /** Clean the form without saving: the role is gone, so its unsaved work has nowhere to go. */
  abandon(): void {
    this.formDirty.setDirty(false);
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private read(name: string): Promise<JsonResult<unknown>> {
    return this.api().requestJson<unknown>(`${ROLES_FORM_PATH}?name=${encodeURIComponent(name)}`);
  }

  private change(field: string): void {
    if (this.violationList.some((entry) => entry.field === field)) {
      this.violationList = this.violationList.filter((entry) => entry.field !== field);
    }
    this.savedValue = false;
    this.formDirty.setDirty(true);
    this.notify();
  }

  private currentText(field: string): string {
    if (field === ESCALATION_FIELD) return String(this.buffer.escalationOnly);
    if (field === DESCRIPTION_FIELD) return this.buffer.description;
    return '';
  }

  private snapshot(): Record<string, string> {
    return { [DESCRIPTION_FIELD]: this.currentText(DESCRIPTION_FIELD), [ESCALATION_FIELD]: this.currentText(ESCALATION_FIELD) };
  }

  /**
   * Take the form read's answer. `fields` false keeps what the form holds and takes only the
   * grants, granted roles and members, which is a refresh over unsaved work.
   */
  private absorb(result: JsonResult<unknown>, fields: boolean): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, {});
      if (result.kind === 'error' && result.status === 404) this.absentValue = true;
      return;
    }
    const body = result.body;
    const lengths: Record<string, number> = {};
    const rawLengths = record(record(body)?.['maxLengths']);
    for (const [field, value] of Object.entries(rawLengths ?? {})) {
      if (typeof value === 'number') lengths[field] = value;
    }
    this.maxLengths = lengths;
    const roles: RoleOption[] = [];
    for (const entry of arrayAt(body, 'roles')) {
      const name = textAt(entry, 'name');
      if (name === '' || roles.some((role) => role.name === name)) continue;
      roles.push({ name, privileged: marked(entry) });
    }
    this.roleOptions = roles;
    const resources: ResourceOption[] = [];
    for (const entry of arrayAt(body, 'resources')) {
      const name = textAt(entry, 'name');
      if (name === '' || resources.some((resource) => resource.name === name)) continue;
      resources.push({ name, permissions: textAt(entry, 'permissions'), privileged: marked(entry) });
    }
    this.resourceOptions = resources;
    const role = record(record(body)?.['role']);
    if (role === null) {
      this.absentValue = true;
      return;
    }
    this.grantList = arrayAt(role, RESOURCES_FIELD)
      .map((entry) => ({ name: textAt(entry, 'Name'), permissions: textAt(entry, 'Permissions') }))
      .filter((grant) => grant.name !== '');
    this.grantedList = arrayAt(role, GRANTED_ROLES_FIELD).filter((name): name is string => typeof name === 'string' && name !== '');
    this.memberList = arrayAt(body, 'members')
      .map((entry) => ({ name: textAt(entry, 'Name'), type: textAt(entry, 'Type') }))
      .filter((member) => member.name !== '');
    if (!fields) return;
    this.buffer = { description: textAt(role, DESCRIPTION_FIELD), escalationOnly: flagAt(role, ESCALATION_FIELD) };
    this.opened = this.buffer;
    this.heldValue = true;
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

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { normalizeEntityId } from '../../core/entity-ref';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The route the editor saves through: `PUT <path>/<id>`. */
export const USERS_PATH = '/api/ocupilot/users';

/** The form read: the rules, their sentences, the roles the instance holds and, with a name, the account. */
export const USERS_FORM_PATH = `${USERS_PATH}/form`;

/** The entity type and scope every change this editor publishes carries (AD-13, AD-14). */
export const USER_ENTITY = 'user';

export const USER_SCOPE = 'instance';

/** The two tabs, named after the classic editor's (`%CSP.UI.Portal.User`). */
export const GENERAL_TAB = 'general';

export const ROLES_TAB = 'roles';

/** The text settings of the General tab, as the server names them. */
export const TEXT_FIELDS = [
  'FullName',
  'Comment',
  'ExpirationDate',
  'NameSpace',
  'Routine',
  'EmailAddress',
  'PhoneProvider',
  'PhoneNumber',
] as const;

/** The boolean settings of the General tab. */
export const FLAG_FIELDS = ['ChangePassword', 'PasswordNeverExpires', 'Enabled', 'AccountNeverExpires', 'HOTPKeyDisplay'] as const;

/** The mask the two two-factor checkboxes are bits of. */
export const AUTHE_FIELD = 'AutheEnabled';

/** The two bits of `AutheEnabled` the editor moves (`%sySecurityMacros.inc`): SMS text and a time-based one-time password. */
export const TWO_FACTOR_SMS_BIT = 1048576;

export const TWO_FACTOR_TOTP_BIT = 2097152;

/** The roles field, which the Roles tab shows and no Save carries (AD-56 (ii)). */
export const ROLES_FIELD = 'Roles';

/**
 * Every field the General tab draws, in the classic editor's order; the order a refused Save's
 * first field is chosen in (`core/form-tabs.ts`).
 */
export const GENERAL_FIELDS: readonly string[] = [
  'FullName',
  'Comment',
  'ChangePassword',
  'PasswordNeverExpires',
  'Enabled',
  'AccountNeverExpires',
  'ExpirationDate',
  'NameSpace',
  'Routine',
  'EmailAddress',
  'PhoneProvider',
  'PhoneNumber',
  AUTHE_FIELD,
  'HOTPKeyDisplay',
];

/** Which tab each field is drawn on. */
export const USER_FIELD_TABS: Readonly<Record<string, string>> = {
  ...Object.fromEntries(GENERAL_FIELDS.map((field) => [field, GENERAL_TAB])),
  [ROLES_FIELD]: ROLES_TAB,
};

/** One role the instance holds, marked by the server's own classifier (AD-10). */
export interface RoleOption {
  readonly name: string;
  readonly privileged: boolean;
}

interface Buffer {
  readonly text: Readonly<Record<string, string>>;
  readonly flags: Readonly<Record<string, boolean>>;
  readonly authe: number;
}

const EMPTY_BUFFER: Buffer = { text: {}, flags: {}, authe: 0 };

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function flagAt(source: unknown, key: string): boolean {
  if (source === null || typeof source !== 'object') return false;
  const value = (source as Record<string, unknown>)[key];
  return value === true || value === 1 || value === '1' || value === 'true';
}

function numberAt(source: unknown, key: string): number {
  if (source === null || typeof source !== 'object') return 0;
  const value = Number((source as Record<string, unknown>)[key]);
  return Number.isFinite(value) ? value : 0;
}

function arrayAt(source: unknown, key: string): readonly unknown[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value : [];
}

/**
 * The user editor's store (AD-19, AD-55): an edit of the account `permissions/users/edit/<id>`
 * names.
 *
 * **It composes no payload of its own.** `PUT /users/<id>` resolves the tool the agent's
 * `permissions.users.update` does, merges the fields this store sends over its own fresh read, and
 * sends the complete set (AD-4); every field sentence is the server's (AD-39). **An edit sends only
 * the fields changed since its read**, so a field another party changed since is kept, and an edit
 * that changed nothing writes nothing.
 *
 * **Roles are not a field of the form** (AD-56 (ii)). The Roles tab lists what the account holds and
 * changes it through the role actions, which apply a delta on the instance; no Save carries them.
 *
 * **Two-factor sign-in is two bits of one mask.** The two checkboxes set or clear
 * `TWO_FACTOR_SMS_BIT` and `TWO_FACTOR_TOTP_BIT` over the mask the read answered and never another
 * bit, and turning one on turns the other off, as the classic editor does.
 */
@Injectable({ providedIn: 'root' })
export class UserEditor {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private accountName = '';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private rolesHeld: readonly string[] = [];

  private roleOptions: readonly RoleOption[] = [];

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
  /** The instance's read-back of the last accepted Save (AD-58), or `null`. */
  private readBackValue: ReadBack | null = null;

  /** The account a create has just made, whose editor opens already saved. */
  private arrivingSaved = '';

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  /** The account the editor shows, as its read answered it, or the route's id before then. */
  name(): string {
    return this.accountName;
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  /** Whether the fields take input: only once the account's read has landed. */
  editable(): boolean {
    return this.heldValue;
  }

  /** Whether the route names an account the instance does not hold. */
  absent(): boolean {
    return this.absentValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  canSave(): boolean {
    return this.heldValue && !this.savingValue && !this.absentValue;
  }

  text(field: string): string {
    return this.buffer.text[field] ?? '';
  }

  flag(field: string): boolean {
    return this.buffer.flags[field] ?? false;
  }

  /** `field` as the last read or accepted Save left it, which a protection rule is drawn against. */
  storedFlag(field: string): boolean {
    return this.opened.flags[field] ?? false;
  }

  /** Whether two-factor sign-in by SMS text is on. */
  sms(): boolean {
    return (this.buffer.authe & TWO_FACTOR_SMS_BIT) !== 0;
  }

  /** Whether two-factor sign-in by a time-based one-time password is on. */
  totp(): boolean {
    return (this.buffer.authe & TWO_FACTOR_TOTP_BIT) !== 0;
  }

  /** The roles the account holds, as the instance spells them. */
  roles(): readonly string[] {
    return this.rolesHeld;
  }

  /** The roles the instance holds, each with its privilege mark. */
  roleChoices(): readonly RoleOption[] {
    return this.roleOptions;
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

  /** The sentence an action on this account was refused with (AD-39), or `''`. */
  actionRefusal(): string {
    return this.actionRefusalValue;
  }

  /** The read-back the last accepted Save answered (AD-58), which its "Saved" line renders. */
  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  /** Whether the account is `name` in the one spelling a reference carries (AD-13). */
  is(name: string): boolean {
    return this.accountName !== '' && normalizeEntityId(USER_ENTITY, name) === normalizeEntityId(USER_ENTITY, this.accountName);
  }

  /** The fields a Save would send: every one changed since the read (AD-4, the server merges). */
  changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of TEXT_FIELDS) {
      if (this.text(field) !== (this.opened.text[field] ?? '')) out[field] = this.text(field);
    }
    for (const field of FLAG_FIELDS) {
      if (this.flag(field) !== (this.opened.flags[field] ?? false)) out[field] = this.flag(field);
    }
    if (this.buffer.authe !== this.opened.authe) out[AUTHE_FIELD] = this.buffer.authe;
    return out;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the editor is left. */
  reset(): void {
    this.generation += 1;
    this.accountName = '';
    this.buffer = EMPTY_BUFFER;
    this.opened = EMPTY_BUFFER;
    this.rolesHeld = [];
    this.roleOptions = [];
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

  /** Mark the account a create has just made, so its editor opens showing "Saved". */
  arriveSaved(name: string): void {
    this.arrivingSaved = name;
  }

  /** Open the editor on `name`: the form read is made on every open rather than cached. */
  async open(name: string): Promise<void> {
    const arriving = this.arrivingSaved !== '' && this.arrivingSaved === name;
    this.arrivingSaved = '';
    this.reset();
    this.accountName = name;
    if (arriving) this.savedValue = true;
    const generation = this.generation;
    const result = await this.read(name);
    if (generation !== this.generation) return;
    this.absorb(result, true);
    this.loadedValue = true;
    this.notify();
  }

  /**
   * Read the account again after a change event (AD-14): in place while the form is clean, and only
   * its roles while it holds unsaved work, so nothing typed is overwritten.
   */
  async refresh(): Promise<void> {
    if (!this.heldValue) return;
    const generation = this.generation;
    const result = await this.read(this.accountName);
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') return;
    this.absorb(result, !this.formDirty.dirty());
    this.notify();
  }

  setText(field: string, value: string): void {
    if (!this.editable() || !(TEXT_FIELDS as readonly string[]).includes(field)) return;
    if (this.text(field) === value) return;
    this.buffer = { ...this.buffer, text: { ...this.buffer.text, [field]: value } };
    this.change(field);
  }

  setFlag(field: string, on: boolean): void {
    if (!this.editable() || !(FLAG_FIELDS as readonly string[]).includes(field)) return;
    if (this.flag(field) === on) return;
    this.buffer = { ...this.buffer, flags: { ...this.buffer.flags, [field]: on } };
    this.change(field);
  }

  /** Turn SMS text two-factor sign-in on or off; on turns the one-time password off. */
  setSms(on: boolean): void {
    this.setTwoFactor(TWO_FACTOR_SMS_BIT, TWO_FACTOR_TOTP_BIT, on);
  }

  /** Turn one-time-password two-factor sign-in on or off; on turns SMS text off. */
  setTotp(on: boolean): void {
    this.setTwoFactor(TWO_FACTOR_TOTP_BIT, TWO_FACTOR_SMS_BIT, on);
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
    this.readBackValue = null;
    this.notify();
    const sent = this.snapshot();
    const sentBuffer = this.buffer;
    const result = await this.api().requestJson<unknown>(`${USERS_PATH}/${encodeEntityId(this.accountName)}`, {
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
    this.readBackValue = readBackOf((result.body as Record<string, unknown> | null)?.['readBack']);
    this.formDirty.setDirty(unsaved);
    this.injector.get(ChangeBus).publish({ kind: 'changed', type: USER_ENTITY, scope: USER_SCOPE, id: this.accountName, action: 'updated', readBack: this.readBackValue });
    this.notify();
    return true;
  }

  /** Clean the form without saving: the account is gone, so its unsaved work has nowhere to go. */
  abandon(): void {
    this.formDirty.setDirty(false);
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private read(name: string): Promise<JsonResult<unknown>> {
    return this.api().requestJson<unknown>(`${USERS_FORM_PATH}?name=${encodeURIComponent(name)}`);
  }

  private setTwoFactor(bit: number, other: number, on: boolean): void {
    if (!this.editable()) return;
    let authe = on ? this.buffer.authe | bit : this.buffer.authe & ~bit;
    if (on) authe &= ~other;
    if (authe === this.buffer.authe) return;
    this.buffer = { ...this.buffer, authe };
    this.change(AUTHE_FIELD);
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
    if (field === AUTHE_FIELD) return String(this.buffer.authe);
    if ((FLAG_FIELDS as readonly string[]).includes(field)) return String(this.flag(field));
    return this.text(field);
  }

  private snapshot(): Record<string, string> {
    const out: Record<string, string> = {};
    for (const field of GENERAL_FIELDS) out[field] = this.currentText(field);
    return out;
  }

  /**
   * Take the form read's answer. `fields` false keeps what the form holds and takes only the
   * roles, which is a refresh over unsaved work.
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
    const rawLengths = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['maxLengths'] : null;
    if (rawLengths !== null && typeof rawLengths === 'object' && !Array.isArray(rawLengths)) {
      for (const [field, value] of Object.entries(rawLengths as Record<string, unknown>)) {
        if (typeof value === 'number') lengths[field] = value;
      }
    }
    this.maxLengths = lengths;
    const options: RoleOption[] = [];
    for (const entry of arrayAt(body, 'roles')) {
      const name = textAt(entry, 'name');
      if (name === '' || options.some((role) => role.name === name)) continue;
      const flag = (entry as Record<string, unknown>)['privileged'];
      options.push({ name, privileged: !(flag === false || flag === 0) });
    }
    this.roleOptions = options;
    const user = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['user'] : null;
    if (user === null || typeof user !== 'object') {
      this.absentValue = true;
      return;
    }
    this.rolesHeld = arrayAt(user, ROLES_FIELD).filter((role): role is string => typeof role === 'string' && role !== '');
    if (!fields) return;
    const text: Record<string, string> = {};
    for (const field of TEXT_FIELDS) text[field] = textAt(user, field);
    const flags: Record<string, boolean> = {};
    for (const field of FLAG_FIELDS) flags[field] = flagAt(user, field);
    this.buffer = { text, flags, authe: numberAt(user, AUTHE_FIELD) };
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

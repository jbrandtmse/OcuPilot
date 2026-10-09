import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The route the form creates through. */
export const USERS_PATH = '/api/ocupilot/users';

/** The form's own bootstrap read: the rules, their sentences and the roles the instance holds. */
export const USERS_FORM_PATH = `${USERS_PATH}/form`;

/** The blur check: whether a name is already taken. A read of the instance, not a validation. */
export const USERS_NAME_PATH = `${USERS_PATH}/name`;

/** The copy's route: the create's Save when the form copies an existing account (Story 18.29). */
export const USERS_COPY_PATH = `${USERS_PATH}/copy`;

/** The password check: whether the instance's policy accepts a password for an account (Story 18.29). */
export const USERS_PASSWORD_CHECK_PATH = `${USERS_PATH}/password-check`;

/** The Users list's declared read, which the copy's source picker is drawn from (AD-5). */
export const USERS_LIST_READ_PATH = '/api/ocupilot/screens/permissions.users/read?maxRows=1000';

/** The field the copy names its source by. */
export const COPY_FROM_FIELD = 'CopyFrom';

/** The machine code a refused password carries, which the server answers on the Password field. */
export const PASSWORD_POLICY_CODE = 'USER.PASSWORD.POLICY';

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const USER_ENTITY = 'user';

export const USER_SCOPE = 'instance';

/** The one secret field. Held apart from the edit buffer, never snapshotted and never echoed. */
export const PASSWORD_FIELD = 'Password';

/** The roles field, whose value is a list of role names rather than text. */
export const ROLES_FIELD = 'Roles';

/** The text fields the form sets, in the order the classic editor draws them. */
export const TEXT_FIELDS = ['Name', 'FullName', 'ExpirationDate', 'NameSpace', 'Routine'] as const;

/** One role the instance holds, as `GET /users/form` projects it. */
export interface RoleOption {
  readonly name: string;
  /**
   * Whether granting it grants %All or an administrative privilege, which the form states at the
   * field while it is ticked (AD-10). The server's classifier decides; the client decides nothing.
   */
  readonly privileged: boolean;
}

/** The account a copy takes, as `GET /users/form?name=` answers it, with its roles read-only (Story 18.29). */
export interface SourceAccount {
  readonly name: string;
  readonly fullName: string;
  readonly roles: readonly string[];
  readonly escalationRoles: readonly string[];
  /** Whether one of its roles, or one of its escalation roles, grants %All or an administrative privilege. */
  readonly privileged: boolean;
}

/** One rule the server applies, with the sentence it refuses with (AD-39). */
export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** The bootstrap read's whole answer. */
export interface UserFormRules {
  readonly requiredFields: readonly string[];
  readonly maxLengths: Readonly<Record<string, number>>;
  readonly rules: readonly FieldRule[];
  readonly roles: readonly RoleOption[];
}

/** The machine code the blur look-up reports a taken name under -- the server's own (AD-39). */
export const NAME_TAKEN_CODE = 'USER.NAME.TAKEN';

type TextBuffer = Record<string, string>;

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

function emptyBuffer(): TextBuffer {
  const out: TextBuffer = {};
  for (const field of TEXT_FIELDS) out[field] = '';
  return out;
}

function emptyRules(): UserFormRules {
  return { requiredFields: [], maxLengths: {}, rules: [], roles: [] };
}

/**
 * The create-a-user form's store (AD-19, AD-55).
 *
 * **It composes no payload of its own.** `POST /users` resolves the same tool class the agent's
 * `permissions.users.create` does, so the screen's Save and the agent's confirm are two callers of
 * one operation, and every field sentence is the server's (AD-39). A privileged role is granted,
 * not refused; the page states its consequence while one is ticked (AD-10).
 *
 * **The password is a secret end to end** (AD-3, AD-35). It is held in one private member apart
 * from the edit buffer, sent once in the Save body, and cleared on an accepted Save, on `reset()`
 * and before the store is carried across the create's own route replacement. It is never part of a
 * refusal snapshot, so a refused Save leaves no copy of it behind.
 */
@Injectable({ providedIn: 'root' })
export class UserCreateForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private buffer: TextBuffer = emptyBuffer();

  private passwordValue = '';

  private rolesValue: readonly string[] = [];

  private rulesValue: UserFormRules = emptyRules();

  private loadedValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private refusedValues: Record<string, string> = {};

  private savedValue = false;
  /** The instance's read-back of the last accepted Save (AD-58), or `null`. */
  private readBackValue: ReadBack | null = null;

  private createdIdValue = '';

  private retainingValue = false;

  private copyFromValue = '';

  private sourceValue: SourceAccount | null = null;

  private usersValue: readonly string[] = [];

  /** The full name the last source pre-filled, so a later choice replaces it rather than keeping it. */
  private prefilledFullName = '';

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

  busy(): boolean {
    return this.savingValue;
  }

  value(field: string): string {
    return this.buffer[field] ?? '';
  }

  /** What the password field holds now: what was typed since the last clear, or `''`. */
  password(): string {
    return this.passwordValue;
  }

  rules(): UserFormRules {
    return this.rulesValue;
  }

  /** Whether role `name` is ticked. */
  roleChecked(name: string): boolean {
    return this.rolesValue.includes(name);
  }

  /** Whether a ticked role is one the server marked privileged, which is when the page states the grant's consequence. */
  privilegedChecked(): boolean {
    return this.rulesValue.roles.some((role) => role.privileged && this.roleChecked(role.name));
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

  /** Whether the last Save was accepted, which the sticky bar and the password caption read. */
  saved(): boolean {
    return this.savedValue;
  }

  /** The created account's id, or `''`. */
  createdId(): string {
    return this.createdIdValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  /** The account this form copies from, or `''` for a create from nothing. */
  copyFrom(): string {
    return this.copyFromValue;
  }
  /** The source account the copy reads, or `null` while the form is not copying. */
  source(): SourceAccount | null {
    return this.sourceValue;
  }
  /** The account names the source picker offers, from the Users list's declared read. */
  users(): readonly string[] {
    return this.usersValue;
  }
  /** Whether this store is being carried across the create's own route replacement. */
  retaining(): boolean {
    return this.retainingValue;
  }

  /** Keep this form's state across the one navigation that is not a departure, less the password. */
  retainAcrossRouteReplacement(): void {
    this.passwordValue = '';
    this.retainingValue = true;
  }

  /** Whether `field` is one a Save must carry. */
  required(field: string): boolean {
    return this.rulesValue.requiredFields.includes(field);
  }

  /** The length `field` stores on this instance, or `0` when the instance declares none. */
  maxLength(field: string): number {
    const held = this.rulesValue.maxLengths[field];
    return typeof held === 'number' ? held : 0;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything, the password first: from the sign-out teardown and when the form is left. */
  reset(): void {
    this.passwordValue = '';
    this.generation += 1;
    this.buffer = emptyBuffer();
    this.rolesValue = [];
    this.copyFromValue = '';
    this.sourceValue = null;
    this.usersValue = [];
    this.prefilledFullName = '';
    this.loadedValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.createdIdValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /** Open the form: read the rules and roles the server applies, on every open rather than cached. */
  async open(): Promise<void> {
    // A create that has replaced its own route with the new account's URL is not an arrival at
    // another form: the state on screen is that account's.
    if (this.retainingValue) {
      this.retainingValue = false;
      return;
    }
    this.reset();
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(USERS_FORM_PATH);
    if (generation !== this.generation) return;
    if (result.kind === 'ok') {
      this.rulesValue = absorbRules(result.body);
    } else {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, {});
    }
    this.loadedValue = true;
    this.notify();
    void this.loadUsers(generation);
  }

  /** Read the Users list's names for the source picker. A read that fails leaves the picker empty. */
  private async loadUsers(generation: number): Promise<void> {
    const result = await this.api().requestJson<unknown>(USERS_LIST_READ_PATH);
    if (generation !== this.generation || result.kind !== 'ok') return;
    const rows = arrayAt(result.body, 'rows');
    this.usersValue = rows.map((row) => textAt(row, 'Name')).filter((name) => name !== '');
    this.notify();
  }

  /**
   * Choose the account to copy from, or `''` to create from nothing. A choice reads the source
   * (`GET /users/form?name=`) and pre-fills the full name when the field is empty or still holds the
   * previous source's; an earlier choice's refusal and pre-filled full name do not outlive it.
   */
  async setCopyFrom(name: string): Promise<void> {
    this.copyFromValue = name;
    this.sourceValue = null;
    this.clearFieldViolation(COPY_FROM_FIELD);
    if (this.prefilledFullName !== '' && this.buffer['FullName'] === this.prefilledFullName) this.setValue('FullName', '');
    this.prefilledFullName = '';
    this.markDirty();
    this.notify();
    if (name === '') return;
    const generation = this.generation;
    // copy=1 keeps the source's escalation roles in the read: the form's own read omits them (the edit form would write them back).
    const result = await this.api().requestJson<unknown>(`${USERS_FORM_PATH}?name=${encodeURIComponent(name)}&copy=1`);
    if (generation !== this.generation || this.copyFromValue !== name) return;
    if (result.kind !== 'ok') return;
    const source = absorbSource(result.body, this.rulesValue);
    if (source === null) return;
    this.sourceValue = source;
    if (this.buffer['FullName'] === '' && source.fullName !== '') {
      this.setValue('FullName', source.fullName);
      this.prefilledFullName = source.fullName;
    }
    this.notify();
  }

  setValue(field: string, value: string): void {
    if (this.buffer[field] === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.clearFieldViolation(field);
    this.markDirty();
    this.notify();
  }

  setPassword(value: string): void {
    if (this.passwordValue === value) return;
    this.passwordValue = value;
    this.clearFieldViolation(PASSWORD_FIELD);
    this.markDirty();
    this.notify();
  }

  /** Tick or untick one role, a privileged one included (AD-10). */
  setRole(name: string, on: boolean): void {
    if (this.roleChecked(name) === on) return;
    this.rolesValue = on
      ? this.rulesValue.roles.map((role) => role.name).filter((role) => role === name || this.roleChecked(role))
      : this.rolesValue.filter((entry) => entry !== name);
    this.clearFieldViolation(ROLES_FIELD);
    this.markDirty();
    this.notify();
  }

  /**
   * On blur: drop a refusal that no longer describes what the field holds, render the server's
   * required-field sentence on an empty required field, and -- for the name alone -- ask the
   * instance whether it is still free. A look-up that could not be made leaves the field unmarked.
   */
  async onBlur(field: string): Promise<void> {
    this.dropStaleViolation(field);
    this.markEmptyRequired(field);
    if (field === PASSWORD_FIELD) {
      await this.checkPassword();
      return;
    }
    if (field !== 'Name') return;
    const name = this.value('Name');
    if (name === '') return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(
      `${USERS_NAME_PATH}?name=${encodeURIComponent(name)}`
    );
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') return;
    if (this.value('Name') !== name) return;
    const body = result.body;
    const available = body !== null && typeof body === 'object'
      ? (body as Record<string, unknown>)['available'] === true
      : true;
    if (available) return;
    const reason = textAt(body, 'reason');
    if (reason === '') return;
    this.violationList = [
      ...this.violationList.filter((entry) => entry.field !== 'Name'),
      { field: 'Name', code: NAME_TAKEN_CODE, reason },
    ];
    this.notify();
  }

  /**
   * On the password's blur: ask the instance's policy and show its reason on the field. The check
   * sends the password once and keeps no copy of it; an answer for a password that has since changed
   * is dropped.
   */
  private async checkPassword(): Promise<void> {
    const password = this.passwordValue;
    if (password === '') return;
    const generation = this.generation;
    const name = this.value('Name');
    const result = await this.api().requestJson<unknown>(USERS_PASSWORD_CHECK_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, password }),
    });
    if (generation !== this.generation || this.passwordValue !== password) return;
    if (result.kind !== 'ok') return;
    const valid = (result.body as Record<string, unknown> | null)?.['valid'] === true;
    const others = this.violationList.filter((entry) => entry.field !== PASSWORD_FIELD);
    if (valid) {
      this.violationList = others;
      this.notify();
      return;
    }
    const reason = textAt(result.body, 'reason');
    if (reason === '') return;
    this.violationList = [...others, { field: PASSWORD_FIELD, code: PASSWORD_POLICY_CODE, reason }];
    this.notify();
  }

  /** Drop a refusal that no longer describes what the field holds, compared with what was refused. */
  dropStaleViolation(field: string): void {
    const refused = this.refusedValues[field];
    if (refused === undefined) return;
    if (this.currentText(field) === refused) return;
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.clearFieldViolation(field);
    this.notify();
  }

  /**
   * Save: post the field set and report whether the instance accepted it.
   *
   * An accepted Save clears the password before anything is published, and publishes one change
   * event with `created` (AD-14). A refused one keeps what was typed, the password included, so the
   * user can correct the field the server named without typing the secret again.
   */
  async save(): Promise<boolean> {
    if (this.busy()) return false;
    const generation = this.generation;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.readBackValue = null;
    this.notify();

    const sent = this.snapshotValues();
    const result = await this.api().requestJson<unknown>(this.copyFromValue === '' ? USERS_PATH : USERS_COPY_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(this.body()),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason =
        this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, sent);
      this.notify();
      return false;
    }
    this.passwordValue = '';
    this.createdIdValue = textAt(result.body, 'name');
    this.savedValue = true;
    this.readBackValue = readBackOf((result.body as Record<string, unknown> | null)?.['readBack']);
    this.formDirty.setDirty(false);
    this.publishCreated();
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private markDirty(): void {
    this.formDirty.setDirty(true);
  }

  private clearFieldViolation(field: string): void {
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
  }

  /**
   * Render the bootstrap read's first rule for an empty required field -- the server's
   * required-ness sentence, listed first per field. A field the read published no rule for
   * renders nothing. The name is left to the look-up and to Save.
   */
  private markEmptyRequired(field: string): void {
    if (field === 'Name') return;
    if (!this.required(field)) return;
    if (this.currentText(field) !== '') return;
    const rule = this.rulesValue.rules.find((entry) => entry.field === field);
    if (rule === undefined) return;
    if (this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /** The body: every field the create sends, typed as the wire expects (AD-4, AD-54). */
  private body(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    out['Name'] = this.value('Name');
    out[PASSWORD_FIELD] = this.passwordValue;
    if (this.copyFromValue !== '') {
      // A copy names its source and takes the roles, escalation roles and settings from it.
      out[COPY_FROM_FIELD] = this.copyFromValue;
      out['FullName'] = this.value('FullName');
      return out;
    }
    for (const field of TEXT_FIELDS) {
      if (field !== 'Name') out[field] = this.value(field);
    }
    out[ROLES_FIELD] = [...this.rolesValue];
    return out;
  }

  private currentText(field: string): string {
    if (field === PASSWORD_FIELD) return this.passwordValue;
    if (field === ROLES_FIELD) return this.rolesValue.join(',');
    return this.value(field);
  }

  /** What a refusal is compared against later. Never the password (AD-35). */
  private snapshotValues(): Record<string, string> {
    const out: Record<string, string> = {};
    for (const field of TEXT_FIELDS) out[field] = this.value(field);
    out[ROLES_FIELD] = this.rolesValue.join(',');
    return out;
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

  private publishCreated(): void {
    if (this.createdIdValue === '') return;
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: USER_ENTITY,
      scope: USER_SCOPE,
      id: this.createdIdValue,
      action: 'created',
      readBack: this.readBackValue,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/** The bootstrap read's body, narrowed. A member the server did not send reads as empty. */
function absorbRules(body: unknown): UserFormRules {
  const lengths: Record<string, number> = {};
  const rawLengths = body !== null && typeof body === 'object'
    ? (body as Record<string, unknown>)['maxLengths']
    : null;
  if (rawLengths !== null && typeof rawLengths === 'object' && !Array.isArray(rawLengths)) {
    for (const [field, value] of Object.entries(rawLengths as Record<string, unknown>)) {
      if (typeof value === 'number') lengths[field] = value;
    }
  }
  const rules: FieldRule[] = [];
  for (const entry of arrayAt(body, 'rules')) {
    if (entry === null || typeof entry !== 'object') continue;
    const field = textAt(entry, 'field');
    const code = textAt(entry, 'code');
    const reason = textAt(entry, 'reason');
    if (field === '' || code === '' || reason === '') continue;
    rules.push({ field, code, reason });
  }
  const roles: RoleOption[] = [];
  for (const entry of arrayAt(body, 'roles')) {
    if (entry === null || typeof entry !== 'object') continue;
    const name = textAt(entry, 'name');
    if (name === '' || roles.some((role) => role.name === name)) continue;
    // A role whose flag the server did not send as false is treated as privileged, so the
    // consequence is stated rather than missed.
    const flag = (entry as Record<string, unknown>)['privileged'];
    roles.push({ name, privileged: !(flag === false || flag === 0) });
  }
  const required = arrayAt(body, 'requiredFields').filter(
    (entry): entry is string => typeof entry === 'string'
  );
  return {
    requiredFields: required,
    maxLengths: lengths,
    rules,
    roles,
  };
}

/** The source account a form read answers, narrowed; `null` when it carries no account. */
function absorbSource(body: unknown, rules: UserFormRules): SourceAccount | null {
  const user = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['user'] : null;
  if (user === null || typeof user !== 'object') return null;
  const roles = arrayAt(user, 'Roles').filter((entry): entry is string => typeof entry === 'string');
  const escalationRoles = arrayAt(user, 'EscalationRoles').filter((entry): entry is string => typeof entry === 'string');
  const privilegedNames = rules.roles.filter((role) => role.privileged).map((role) => role.name.toUpperCase());
  const privileged = [...roles, ...escalationRoles].some((role) => privilegedNames.includes(role.toUpperCase()));
  return { name: textAt(user, 'Name'), fullName: textAt(user, 'FullName'), roles, escalationRoles, privileged };
}

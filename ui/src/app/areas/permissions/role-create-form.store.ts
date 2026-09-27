import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The route the form creates through. */
export const ROLES_PATH = '/api/ocupilot/roles';

/** The form's own bootstrap read: the rules, their sentences, the roles and the resources. */
export const ROLES_FORM_PATH = `${ROLES_PATH}/form`;

/** The blur check: whether a name is already taken. A read of the instance, not a validation. */
export const ROLES_NAME_PATH = `${ROLES_PATH}/name`;

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const ROLE_ENTITY = 'role';

export const ROLE_SCOPE = 'instance';

/** The resource grants field, whose value is a list of `{Name, Permissions}` grants. */
export const RESOURCES_FIELD = 'Resources';

/** The granted roles field, whose value is a list of role names. */
export const GRANTED_ROLES_FIELD = 'GrantedRoles';

/** The text fields the form sets, in the order the classic editor draws them. */
export const TEXT_FIELDS = ['Name', 'Description'] as const;

/** The permission letters a grant is written in, in the order the vendor writes them. */
export const PERMISSION_LETTERS = 'RWU';

/** One role the instance holds, as `GET /roles/form` projects it. */
export interface RoleOption {
  readonly name: string;
  /**
   * Whether granting it grants %All or an administrative privilege, which the form states at the
   * field while it is ticked (AD-10). The server's classifier decides; the client decides nothing.
   */
  readonly privileged: boolean;
}

/** One resource the instance holds, as `GET /roles/form` projects it. */
export interface ResourceOption {
  readonly name: string;
  /** The letters the classic grant dialog offers for it, in `PERMISSION_LETTERS` order. */
  readonly permissions: string;
  /** Whether a grant of it, at any permission, grants %All or an administrative privilege (AD-10). */
  readonly privileged: boolean;
}

/** One resource grant, in the vendor's own `{Name, Permissions}` shape. */
export interface Grant {
  readonly name: string;
  readonly permissions: string;
}

/** One rule the server applies, with the sentence it refuses with (AD-39). */
export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** The bootstrap read's whole answer. */
export interface RoleFormRules {
  readonly requiredFields: readonly string[];
  readonly maxLengths: Readonly<Record<string, number>>;
  readonly rules: readonly FieldRule[];
  readonly roles: readonly RoleOption[];
  readonly resources: readonly ResourceOption[];
}

/** The machine code the blur look-up reports a taken name under -- the server's own (AD-39). */
export const NAME_TAKEN_CODE = 'ROLE.NAME.TAKEN';

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

function emptyRules(): RoleFormRules {
  return { requiredFields: [], maxLengths: {}, rules: [], roles: [], resources: [] };
}

/** `letters` reduced to the distinct letters of `PERMISSION_LETTERS` it carries, in that order. */
export function canonicalLetters(letters: string): string {
  const upper = letters.toUpperCase();
  return [...PERMISSION_LETTERS].filter((letter) => upper.includes(letter)).join('');
}

/**
 * The create-a-role form's store (AD-19, AD-55).
 *
 * **It composes no payload of its own.** `POST /roles` resolves the same tool class the agent's
 * `permissions.roles.create` does, so the screen's Save and the agent's confirm are two callers of
 * one operation, and every field sentence is the server's (AD-39). A privileged grant is granted,
 * not refused; the page and the grant dialog state its consequence while one is chosen (AD-10).
 *
 * **A grant is the vendor's `{Name, Permissions}`**, held in the order it was added. The grant
 * dialog decides nothing the server does not: it offers the letters the bootstrap read ships for
 * each resource, and the server refuses whatever it would refuse anyway.
 */
@Injectable({ providedIn: 'root' })
export class RoleCreateForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private buffer: TextBuffer = emptyBuffer();

  private grantsValue: readonly Grant[] = [];

  private rolesValue: readonly string[] = [];

  private rulesValue: RoleFormRules = emptyRules();

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

  rules(): RoleFormRules {
    return this.rulesValue;
  }

  /** The resource grants, in the order they were added. */
  grants(): readonly Grant[] {
    return this.grantsValue;
  }

  /** The grant of resource `name`, or `null`. Resource names compare without regard to case. */
  grantFor(name: string): Grant | null {
    const key = name.toUpperCase();
    return this.grantsValue.find((grant) => grant.name.toUpperCase() === key) ?? null;
  }

  /** The bootstrap read's entry for resource `name`, or `null`. */
  resource(name: string): ResourceOption | null {
    const key = name.toUpperCase();
    return this.rulesValue.resources.find((entry) => entry.name.toUpperCase() === key) ?? null;
  }

  /** Whether role `name` is ticked. */
  roleChecked(name: string): boolean {
    return this.rolesValue.includes(name);
  }

  /** Whether a ticked granted role is one the server marked privileged (AD-10). */
  privilegedRoleChecked(): boolean {
    return this.rulesValue.roles.some((role) => role.privileged && this.roleChecked(role.name));
  }

  /** Whether a held resource grant is of a resource the server marked privileged (AD-10). */
  privilegedGrantHeld(): boolean {
    return this.grantsValue.some((grant) => this.resource(grant.name)?.privileged ?? true);
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

  /** Whether the last Save was accepted, which the sticky bar reads. */
  saved(): boolean {
    return this.savedValue;
  }

  /** The created role's id, or `''`. */
  createdId(): string {
    return this.createdIdValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
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

  /** Forget everything: from the sign-out teardown and when the form is left. */
  reset(): void {
    this.generation += 1;
    this.buffer = emptyBuffer();
    this.grantsValue = [];
    this.rolesValue = [];
    this.loadedValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.createdIdValue = '';
    this.formDirty.reset();
    this.notify();
  }

  /** Open the form: read the rules, roles and resources the server applies, on every open. */
  async open(): Promise<void> {
    this.reset();
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(ROLES_FORM_PATH);
    if (generation !== this.generation) return;
    if (result.kind === 'ok') {
      this.rulesValue = absorbRules(result.body);
    } else {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, {});
    }
    this.loadedValue = true;
    this.notify();
  }

  setValue(field: string, value: string): void {
    if (this.buffer[field] === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.clearFieldViolation(field);
    this.markDirty();
    this.notify();
  }

  /**
   * Apply the grant dialog's result: resource `name` at `permissions`. A grant already held for
   * the resource is replaced in place; an empty result removes it, which is how an edited grant
   * whose every letter was cleared, and a Remove, end.
   */
  applyGrant(name: string, permissions: string): void {
    const letters = canonicalLetters(permissions);
    const held = this.grantFor(name);
    if (letters === '') {
      if (held === null) return;
      this.grantsValue = this.grantsValue.filter((grant) => grant !== held);
    } else if (held === null) {
      this.grantsValue = [...this.grantsValue, { name, permissions: letters }];
    } else {
      if (held.permissions === letters) return;
      this.grantsValue = this.grantsValue.map((grant) =>
        grant === held ? { name: held.name, permissions: letters } : grant
      );
    }
    this.clearFieldViolation(RESOURCES_FIELD);
    this.markDirty();
    this.notify();
  }

  /** Tick or untick one granted role, a privileged one included (AD-10). */
  setRole(name: string, on: boolean): void {
    if (this.roleChecked(name) === on) return;
    this.rolesValue = on
      ? this.rulesValue.roles.map((role) => role.name).filter((role) => role === name || this.roleChecked(role))
      : this.rolesValue.filter((entry) => entry !== name);
    this.clearFieldViolation(GRANTED_ROLES_FIELD);
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
    if (field !== 'Name') return;
    const name = this.value('Name');
    if (name === '') return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(
      `${ROLES_NAME_PATH}?name=${encodeURIComponent(name)}`
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
   * Save: post the field set and report whether the instance accepted it. An accepted Save
   * publishes one change event with `created` (AD-14); a refused one keeps what was entered, so the
   * user can correct the field the server named.
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
    const result = await this.api().requestJson<unknown>(ROLES_PATH, {
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
   * required-ness sentence, listed first per field. The name is left to the look-up and to Save.
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
    for (const field of TEXT_FIELDS) out[field] = this.value(field);
    out[RESOURCES_FIELD] = this.grantsValue.map((grant) => ({ Name: grant.name, Permissions: grant.permissions }));
    out[GRANTED_ROLES_FIELD] = [...this.rolesValue];
    return out;
  }

  private currentText(field: string): string {
    if (field === RESOURCES_FIELD) return this.grantsValue.map((grant) => `${grant.name}:${grant.permissions}`).join(',');
    if (field === GRANTED_ROLES_FIELD) return this.rolesValue.join(',');
    return this.value(field);
  }

  /** What a refusal is compared against later. */
  private snapshotValues(): Record<string, string> {
    const out: Record<string, string> = {};
    for (const field of TEXT_FIELDS) out[field] = this.value(field);
    out[RESOURCES_FIELD] = this.currentText(RESOURCES_FIELD);
    out[GRANTED_ROLES_FIELD] = this.currentText(GRANTED_ROLES_FIELD);
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
      type: ROLE_ENTITY,
      scope: ROLE_SCOPE,
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
function absorbRules(body: unknown): RoleFormRules {
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
  const resources: ResourceOption[] = [];
  for (const entry of arrayAt(body, 'resources')) {
    if (entry === null || typeof entry !== 'object') continue;
    const name = textAt(entry, 'name');
    const permissions = canonicalLetters(textAt(entry, 'permissions'));
    if (name === '' || permissions === '' || resources.some((resource) => resource.name === name)) continue;
    // Treated as privileged unless the server sent the flag as false, for the same reason.
    const flag = (entry as Record<string, unknown>)['privileged'];
    resources.push({ name, permissions, privileged: !(flag === false || flag === 0) });
  }
  const required = arrayAt(body, 'requiredFields').filter(
    (entry): entry is string => typeof entry === 'string'
  );
  return {
    requiredFields: required,
    maxLengths: lengths,
    rules,
    roles,
    resources,
  };
}

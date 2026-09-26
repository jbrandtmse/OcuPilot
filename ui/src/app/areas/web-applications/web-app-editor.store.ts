import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { normalizeEntityId } from '../../core/entity-ref';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import {
  type ApplicationRoleOption,
  type FormRules,
  MATCH_ROLES_FIELD,
  UNAUTHENTICATED_BIT,
  WEB_APPLICATION_ENTITY,
  WEB_APPLICATION_SCOPE,
  WEB_APPLICATIONS_FORM_PATH,
  WEB_APPLICATIONS_PATH,
  absorbRules,
} from './create-form.store';

/** The four tabs, named after the classic editor's (`%CSP.UI.Portal.Applications.Web`). */
export const GENERAL_TAB = 'general';

export const APPLICATION_ROLES_TAB = 'application-roles';

export const MATCHING_ROLES_TAB = 'matching-roles';

export const CORS_TAB = 'cors';

/** The text settings, as the server names them. */
export const TEXT_FIELDS = [
  'Description',
  'NameSpace',
  'DispatchClass',
  'WSGIAppName',
  'WSGICallable',
  'WSGIType',
  'Resource',
  'GroupById',
  'ServeFiles',
  'Package',
  'SuperClass',
] as const;

/** The settings a whole number of seconds is typed into. */
export const NUMBER_FIELDS = ['Timeout', 'JWTAccessTokenTimeout', 'JWTRefreshTokenTimeout', 'ServeFilesTimeout'] as const;

/** The boolean settings. */
export const FLAG_FIELDS = [
  'IsNameSpaceDefault',
  'Enabled',
  'JWTAuthEnabled',
  'Recurse',
  'AutoCompile',
  'LockCSPName',
  'CorsCredentialsAllowed',
] as const;

/** The two list settings, one entry per line. */
export const LIST_FIELDS = ['CorsAllowlist', 'CorsHeadersList'] as const;

/** The authentication mask the method checkboxes are bits of. */
export const AUTHE_FIELD = 'AutheEnabled';

/**
 * The settings that decide which code answers at the application's address (AD-10), in the order
 * the General tab draws them. A change to any of them is the repointed effect.
 */
export const CODE_FIELDS: readonly string[] = ['NameSpace', 'DispatchClass', 'WSGIAppName', 'WSGICallable', 'Package', 'SuperClass'];

/**
 * Every field the General tab draws, in the classic editor's order; the order a refused Save's first
 * field is chosen in (`core/form-tabs.ts`).
 */
export const GENERAL_FIELDS: readonly string[] = [
  'Description',
  'NameSpace',
  'IsNameSpaceDefault',
  'Enabled',
  'DispatchClass',
  'WSGIAppName',
  'WSGICallable',
  'WSGIType',
  'Resource',
  'GroupById',
  AUTHE_FIELD,
  'Timeout',
  'JWTAuthEnabled',
  'JWTAccessTokenTimeout',
  'JWTRefreshTokenTimeout',
  'ServeFiles',
  'ServeFilesTimeout',
  'Package',
  'SuperClass',
  'Recurse',
  'AutoCompile',
  'LockCSPName',
];

/** Every field the Cross-origin settings tab draws, in its order. */
export const CORS_FIELDS: readonly string[] = ['CorsAllowlist', 'CorsCredentialsAllowed', 'CorsHeadersList'];

/** Which tab each field is drawn on. */
export const WEB_APP_FIELD_TABS: Readonly<Record<string, string>> = {
  ...Object.fromEntries(GENERAL_FIELDS.map((field) => [field, GENERAL_TAB])),
  ...Object.fromEntries(CORS_FIELDS.map((field) => [field, CORS_TAB])),
  [MATCH_ROLES_FIELD]: APPLICATION_ROLES_TAB,
};

/** The three application types the derived type reads (`create-form.store.ts`'s own). */
export const DERIVED_CSP = 'csp';
export const DERIVED_REST = 'rest';
export const DERIVED_PYTHON = 'python';

/** One matching-role grant: callers holding `match` receive `role`. */
export interface MatchingRole {
  readonly match: string;
  readonly role: string;
}

interface Buffer {
  readonly text: Readonly<Record<string, string>>;
  readonly flags: Readonly<Record<string, boolean>>;
  readonly lists: Readonly<Record<string, string>>;
  readonly authe: number;
}

const EMPTY_BUFFER: Buffer = { text: {}, flags: {}, lists: {}, authe: 0 };

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

function arrayAt(source: unknown, key: string): readonly unknown[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value : [];
}

/** A list setting's text, one entry per line, as the textarea shows it. */
function listText(source: unknown, key: string): string {
  return arrayAt(source, key)
    .filter((entry): entry is string => typeof entry === 'string')
    .join('\n');
}

/** The entries a list setting's text holds: each line trimmed, empty lines dropped. */
function listEntries(text: string): string[] {
  return text
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line !== '');
}

/**
 * The web application editor's store (AD-19, AD-55): an edit of the application
 * `web-applications/list/edit/<id>` names.
 *
 * **It composes no payload of its own.** `PUT /web-applications/<id>` resolves the tool the agent's
 * `webapp.list.update` does, merges the fields this store sends over its own fresh read, and sends
 * the complete set (AD-4); every field sentence is the server's (AD-39). An edit sends only the
 * fields changed since its read.
 *
 * **Roles are not a field of the form** (AD-56 (ii)). The two roles tabs list what the application
 * grants and change it through the Web applications list's role actions, which apply a delta on the
 * instance; no Save carries them.
 *
 * **The authentication checkboxes are bits of one mask**, set or cleared over the mask the read
 * answered, so a bit the instance does not offer is kept as it was.
 */
@Injectable({ providedIn: 'root' })
export class WebAppEditor {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private applicationName = '';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private fixed: Readonly<Record<string, string>> = {};

  private matchRolesValue: readonly unknown[] = [];

  private rulesValue: FormRules = absorbRules(null);

  private serveFilesValue: readonly string[] = [];

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

  /** The application a create has just made, whose editor opens already saved. */
  private arrivingSaved = '';

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  /** The application the editor shows, or the route's id before its read lands. */
  name(): string {
    return this.applicationName;
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  /** Whether the fields take input: only once the application's read has landed. */
  editable(): boolean {
    return this.heldValue;
  }

  /** Whether the route names an application the instance does not hold. */
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

  list(field: string): string {
    return this.buffer.lists[field] ?? '';
  }

  /** A setting no edit changes -- the Python directory and the physical path -- as the read answered it. */
  fixedValue(field: string): string {
    return this.fixed[field] ?? '';
  }

  /** Whether the authentication bit `bit` is set in the form's mask. */
  autheChecked(bit: number): boolean {
    return (this.buffer.authe & bit) !== 0;
  }

  /** The rules, methods and roles the form read published. */
  rules(): FormRules {
    return this.rulesValue;
  }

  /** The file-serving choices the form read published, in the vendor's own order. */
  serveFilesChoices(): readonly string[] {
    return this.serveFilesValue;
  }

  /** The roles the instance holds, each with its privilege mark (AD-10). */
  roleChoices(): readonly ApplicationRoleOption[] {
    return this.rulesValue.roles;
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

  /** The application type the form describes: REST with a dispatch class, Python with an application file, CSP otherwise. */
  derivedType(): string {
    if (this.text('DispatchClass') !== '') return DERIVED_REST;
    if (this.text('WSGIAppName') !== '') return DERIVED_PYTHON;
    return DERIVED_CSP;
  }

  /** Whether the form adds the unauthenticated bit the read did not hold (AD-10). */
  addsUnauthenticated(): boolean {
    return (this.buffer.authe & UNAUTHENTICATED_BIT) !== 0 && (this.opened.authe & UNAUTHENTICATED_BIT) === 0;
  }

  /** Whether the application is unauthenticated as read or as the unsaved form stands. */
  unauthenticated(): boolean {
    return ((this.buffer.authe | this.opened.authe) & UNAUTHENTICATED_BIT) !== 0;
  }

  /** Whether the form clears a resource the read held (AD-10). */
  clearsResource(): boolean {
    return (this.opened.text['Resource'] ?? '') !== '' && this.text('Resource') === '';
  }

  /** The first of `CODE_FIELDS`, in their order, that the form changes, or `''` (AD-10). */
  repointedField(): string {
    return CODE_FIELDS.find((field) => this.text(field) !== (this.opened.text[field] ?? '')) ?? '';
  }

  maxLength(field: string): number {
    const held = this.rulesValue.maxLengths[field];
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

  /** The sentence a role action on this application was refused with (AD-39), or `''`. */
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

  /** Whether the application is `name` in the one spelling a reference carries (AD-13). */
  is(name: string): boolean {
    return (
      this.applicationName !== '' &&
      normalizeEntityId(WEB_APPLICATION_ENTITY, name) === normalizeEntityId(WEB_APPLICATION_ENTITY, this.applicationName)
    );
  }

  /** The fields a Save would send: every one changed since the read (AD-4, the server merges). */
  changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of TEXT_FIELDS) {
      if (this.text(field) !== (this.opened.text[field] ?? '')) out[field] = this.text(field);
    }
    for (const field of NUMBER_FIELDS) {
      const value = this.text(field);
      if (value === (this.opened.text[field] ?? '')) continue;
      // A whole number travels as one; anything else as typed, which the server refuses on the field.
      out[field] = /^\d+$/.test(value.trim()) ? Number(value.trim()) : value;
    }
    for (const field of FLAG_FIELDS) {
      if (this.flag(field) !== (this.opened.flags[field] ?? false)) out[field] = this.flag(field);
    }
    for (const field of LIST_FIELDS) {
      const now = listEntries(this.list(field));
      if (JSON.stringify(now) !== JSON.stringify(listEntries(this.opened.lists[field] ?? ''))) out[field] = now;
    }
    if (this.buffer.authe !== this.opened.authe) out[AUTHE_FIELD] = this.buffer.authe;
    return out;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the editor is left. */
  reset(): void {
    this.generation += 1;
    this.applicationName = '';
    this.buffer = EMPTY_BUFFER;
    this.opened = EMPTY_BUFFER;
    this.fixed = {};
    this.matchRolesValue = [];
    this.rulesValue = absorbRules(null);
    this.serveFilesValue = [];
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

  /** Mark the application a create has just made, so its editor opens showing "Saved". */
  arriveSaved(name: string): void {
    this.arrivingSaved = name;
  }

  /** Open the editor on `name`: the form read is made on every open rather than cached. */
  async open(name: string): Promise<void> {
    const arriving = this.arrivingSaved !== '' && this.arrivingSaved === name;
    this.arrivingSaved = '';
    this.reset();
    this.applicationName = name;
    if (arriving) this.savedValue = true;
    const generation = this.generation;
    const result = await this.read(name);
    if (generation !== this.generation) return;
    this.absorb(result, true);
    this.loadedValue = true;
    this.notify();
  }

  /**
   * Read the application again after a change event (AD-14): in place while the form is clean, and
   * only its roles while it holds unsaved work, so nothing typed is overwritten.
   */
  async refresh(): Promise<void> {
    if (!this.heldValue) return;
    const generation = this.generation;
    const result = await this.read(this.applicationName);
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') return;
    this.absorb(result, !this.formDirty.dirty());
    this.notify();
  }

  setText(field: string, value: string): void {
    const known = (TEXT_FIELDS as readonly string[]).includes(field) || (NUMBER_FIELDS as readonly string[]).includes(field);
    if (!this.editable() || !known) return;
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

  setList(field: string, value: string): void {
    if (!this.editable() || !(LIST_FIELDS as readonly string[]).includes(field)) return;
    if (this.list(field) === value) return;
    this.buffer = { ...this.buffer, lists: { ...this.buffer.lists, [field]: value } };
    this.change(field);
  }

  /** Set or clear one authentication bit over the mask the form holds. */
  setAuthe(bit: number, on: boolean): void {
    if (!this.editable()) return;
    const authe = on ? this.buffer.authe | bit : this.buffer.authe & ~bit;
    if (authe === this.buffer.authe) return;
    this.buffer = { ...this.buffer, authe };
    this.change(AUTHE_FIELD);
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
    const result = await this.api().requestJson<unknown>(`${WEB_APPLICATIONS_PATH}/${encodeEntityId(this.applicationName)}`, {
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
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: WEB_APPLICATION_ENTITY,
      scope: WEB_APPLICATION_SCOPE,
      id: this.applicationName,
      action: 'updated',
      readBack: this.readBackValue,
    });
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private read(name: string): Promise<JsonResult<unknown>> {
    return this.api().requestJson<unknown>(`${WEB_APPLICATIONS_FORM_PATH}?name=${encodeURIComponent(name)}`);
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
    if ((LIST_FIELDS as readonly string[]).includes(field)) return this.list(field);
    return this.text(field);
  }

  private snapshot(): Record<string, string> {
    const out: Record<string, string> = {};
    for (const field of [...GENERAL_FIELDS, ...CORS_FIELDS]) out[field] = this.currentText(field);
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
    this.rulesValue = absorbRules(body);
    this.serveFilesValue = arrayAt(body, 'serveFilesChoices').filter((entry): entry is string => typeof entry === 'string');
    const application = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['application'] : null;
    if (application === null || typeof application !== 'object') {
      this.absentValue = true;
      return;
    }
    this.matchRolesValue = arrayAt(application, MATCH_ROLES_FIELD);
    if (!fields) return;
    const text: Record<string, string> = {};
    for (const field of [...TEXT_FIELDS, ...NUMBER_FIELDS]) text[field] = textAt(application, field);
    const flags: Record<string, boolean> = {};
    for (const field of FLAG_FIELDS) flags[field] = flagAt(application, field);
    const lists: Record<string, string> = {};
    for (const field of LIST_FIELDS) lists[field] = listText(application, field);
    const authe = Number((application as Record<string, unknown>)[AUTHE_FIELD]);
    this.buffer = { text, flags, lists, authe: Number.isFinite(authe) ? authe : 0 };
    this.opened = this.buffer;
    this.fixed = { WSGIAppLocation: textAt(application, 'WSGIAppLocation'), Path: textAt(application, 'Path') };
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

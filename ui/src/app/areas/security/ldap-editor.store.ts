import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the editor uses: `POST` creates, `PUT <path>/<id>` edits, `POST <path>/<id>/test` tests. */
export const LDAP_PATH = '/api/ocupilot/ldap';

/** The form read: `?name=` for a configuration, `?new=1` for a new one's values. */
export const LDAP_FORM_PATH = `${LDAP_PATH}/form`;

/** The name check on blur: the name the instance stores, its base DN, and whether it is taken. */
export const LDAP_NAME_PATH = `${LDAP_PATH}/name`;

/** The group examples, read from the instance whenever a group input changes. */
export const LDAP_EXAMPLES_PATH = `${LDAP_PATH}/examples`;

/** The LDAP / Kerberos list's declared read, whose names Copy settings from offers (AD-5). */
export const LDAP_LIST_READ_PATH = '/api/ocupilot/screens/security.ldap/read?maxRows=1000';

/** The change event's entity type and scope (AD-13, AD-14). */
export const LDAP_ENTITY = 'ldap-configuration';

export const LDAP_SCOPE = 'instance';

/** The three tabs, cut at the classic page's own captions. */
export const GENERAL_TAB = 'general';
export const GROUPS_TAB = 'groups';
export const ATTRIBUTES_TAB = 'attributes';

/** The fields, named as the server names them. */
export const NAME_FIELD = 'Name';
export const DESCRIPTION_FIELD = 'Description';
export const FLAGS_FIELD = 'LDAPFlags';
export const HOSTS_FIELD = 'LDAPHostNames';
export const USER_FIELD = 'LDAPSearchUsername';
export const PASSWORD_FIELD = 'LDAPSearchPassword';
export const BASE_DN_FIELD = 'LDAPBaseDN';
export const GROUPS_BASE_DN_FIELD = 'LDAPBaseDNForGroups';
export const CA_FILE_FIELD = 'LDAPCACertFile';
export const ATTRIBUTES_FIELD = 'LDAPAttributes';

/** `LDAPFlags`' bits (`%sySecurityMacros.inc`). */
export const FLAG_ACTIVE_DIRECTORY = 1;
export const FLAG_TLS = 2;
export const FLAG_ALLOW_ENV = 4;
export const FLAG_GROUPS = 8;
export const FLAG_NESTED = 16;
export const FLAG_UNIVERSAL = 32;
export const FLAG_ENABLED = 64;
export const FLAG_KERBEROS_ONLY = 128;

/** The General tab's text settings, in the classic order. */
export const GENERAL_TEXT_FIELDS: readonly string[] = [USER_FIELD, BASE_DN_FIELD, GROUPS_BASE_DN_FIELD, 'LDAPUniqueDNIdentifier'];

/** The two timeouts, whole numbers on the wire. */
export const NUMBER_FIELDS: readonly string[] = ['LDAPServerTimeout', 'LDAPClientTimeout'];

/** The Groups tab's prefixes: the organization's, then the Advanced settings' seven. */
export const ORGANIZATION_FIELD = 'OrganizationId';
export const ADVANCED_FIELDS: readonly string[] = ['GroupId', 'InstanceId', 'RoleId', 'EscalationRoleId', 'NamespaceId', 'RoutineId', 'DelimiterId'];

/** The Groups tab's two authorization IDs. */
export const AUTHORIZATION_FIELDS: readonly string[] = ['LDAPGroupId', 'LDAPInstanceId'];

/** The four user attributes the classic page enables only while LDAP groups are not used. */
export const GROUPLESS_ATTRIBUTE_FIELDS: readonly string[] = [
  'LDAPAttributeNameSpace',
  'LDAPAttributeRoutine',
  'LDAPAttributeRoles',
  'LDAPAttributeEscalationRoles',
];

/** The nine user attributes, in the classic order. */
export const ATTRIBUTE_FIELDS: readonly string[] = [
  ...GROUPLESS_ATTRIBUTE_FIELDS,
  'LDAPAttributeComment',
  'LDAPAttributeFullName',
  'LDAPAttributeMail',
  'LDAPAttributeMobile',
  'LDAPAttributeMobileProvider',
];

/** Every text setting the form sets. */
export const TEXT_FIELDS: readonly string[] = [
  DESCRIPTION_FIELD,
  ...GENERAL_TEXT_FIELDS,
  ...NUMBER_FIELDS,
  ORGANIZATION_FIELD,
  ...ADVANCED_FIELDS,
  ...AUTHORIZATION_FIELDS,
  ...ATTRIBUTE_FIELDS,
];

/** The fields whose value a copy never takes: the name, the description and the two base DNs. */
export const UNCOPIED_FIELDS: readonly string[] = [NAME_FIELD, DESCRIPTION_FIELD, BASE_DN_FIELD, GROUPS_BASE_DN_FIELD];

/** Every field in the classic order, which is the order a refused Save's first field is chosen in. */
export const FIELD_ORDER: readonly string[] = [
  NAME_FIELD,
  DESCRIPTION_FIELD,
  FLAGS_FIELD,
  HOSTS_FIELD,
  USER_FIELD,
  PASSWORD_FIELD,
  BASE_DN_FIELD,
  GROUPS_BASE_DN_FIELD,
  'LDAPUniqueDNIdentifier',
  ...NUMBER_FIELDS,
  ORGANIZATION_FIELD,
  ...ADVANCED_FIELDS,
  ...AUTHORIZATION_FIELDS,
  ...ATTRIBUTE_FIELDS,
  ATTRIBUTES_FIELD,
];

/** Which tab each field is drawn on. */
export const LDAP_FIELD_TABS: Readonly<Record<string, string>> = Object.fromEntries(
  FIELD_ORDER.map((field) => {
    if (field === ORGANIZATION_FIELD || ADVANCED_FIELDS.includes(field) || AUTHORIZATION_FIELDS.includes(field)) return [field, GROUPS_TAB];
    if (ATTRIBUTE_FIELDS.includes(field) || field === ATTRIBUTES_FIELD) return [field, ATTRIBUTES_TAB];
    return [field, GENERAL_TAB];
  })
);

/** What the form is doing: creating a configuration, or editing the one its route names. */
export type FormMode = 'create' | 'edit';

/** The search password's three options (the classic page's). */
export type PasswordMode = 'leave' | 'enter' | 'clear';

/** The group examples, one text per `FormatExample` mode. */
export interface LdapExamples {
  readonly universal: string;
  readonly group: string;
  readonly instance: string;
}

const NO_EXAMPLES: LdapExamples = { universal: '', group: '', instance: '' };

/** The settings as the form holds them. */
interface Buffer {
  readonly name: string;
  readonly text: Readonly<Record<string, string>>;
  readonly flags: number;
  readonly hosts: readonly string[];
  readonly attributes: readonly string[];
}

const EMPTY_BUFFER: Buffer = { name: '', text: {}, flags: 0, hosts: [], attributes: [] };

function recordOf(source: unknown): Record<string, unknown> {
  return source !== null && typeof source === 'object' && !Array.isArray(source) ? (source as Record<string, unknown>) : {};
}

function textOf(source: unknown, key: string): string {
  const value = recordOf(source)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function stringsOf(source: unknown, key: string): string[] {
  const value = recordOf(source)[key];
  return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === 'string' && entry !== '') : [];
}

function sameList(left: readonly string[], right: readonly string[]): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

/**
 * The LDAP and Kerberos editor's store (AD-19, AD-55, Story 16.14): a create on
 * `security/ldap/edit`, an edit of the configuration its route names on `security/ldap/edit/<name>`,
 * that configuration's group examples, and its Test authentication.
 *
 * **It composes no rule of its own.** `POST /ldap` and `PUT /ldap/<id>` resolve the tools the
 * agent's `security.ldap.create` and `security.ldap.update` do, and every field sentence is the
 * server's (AD-39) but one, the client's refusal of two passwords that differ. A create sends every
 * setting the form holds, from a new configuration's values; an edit sends the settings changed since
 * its read, `LDAPFlags` whole and a list whole (AD-4; the server merges).
 *
 * **The flags are bits of one number**, each checkbox setting or clearing its own over the value the
 * form opened, with the classic page's couplings: unticking Use LDAP groups clears nested and
 * universal groups; unticking Active Directory clears nested groups; unticking LDAP configuration
 * makes the configuration Kerberos-only, which also clears LDAP enabled.
 *
 * **The search password is write-only** (AD-35): it is never read, held apart from the buffer, sent
 * only for Enter a new password (the value) or Clear the password (`""`), and cleared on an accepted
 * Save, on `reset()` and before the store is carried across a create's own route replacement. The
 * Test authentication password is the dialog's, not the store's: `test()` sends the one it is given
 * and keeps nothing, and the test's lines are shown and never kept.
 */
@Injectable({ providedIn: 'root' })
export class LdapEditor {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private caFileValue = '';

  private kerberosValue = false;

  private passwordModeValue: PasswordMode = 'leave';

  private passwordValue = '';

  private confirmValue = '';

  private copyNames: readonly string[] = [];

  private copiedValue = '';

  private examplesValue: LdapExamples = NO_EXAMPLES;

  private examplesGeneration = 0;

  private loadedValue = false;

  private heldValue = false;

  private absentValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private secretsRefusedValue = '';

  private savedValue = false;
  /** The instance's read-back of the last accepted Save (AD-58), or `null`. */
  private readBackValue: ReadBack | null = null;

  private createdIdValue = '';

  private retainingValue = false;

  private testingValue = false;

  private testLinesValue: readonly string[] | null = null;

  private testViolationList: readonly Violation[] = [];

  private testReasonValue = '';

  private testNoAnswerValue = false;

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

  /** Whether an edit names a configuration the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** Whether the configuration's read is held: always for a create once read, and for an edit over its fresh read. */
  held(): boolean {
    return this.heldValue;
  }

  /** The name this form edits, or the name a create has typed. */
  name(): string {
    return this.buffer.name;
  }

  /** Whether `name` is the configuration this form holds, compared as the instance stores names. */
  is(name: string): boolean {
    return this.modeValue === 'edit' && this.buffer.name !== '' && this.buffer.name.toLowerCase() === name.toLowerCase();
  }

  /** The text a text setting holds now. */
  text(field: string): string {
    return this.buffer.text[field] ?? '';
  }

  /** `LDAPFlags` as the form holds it. */
  flags(): number {
    return this.buffer.flags;
  }

  /** Whether flag bit `bit` is set now. */
  flag(bit: number): boolean {
    return (this.buffer.flags & bit) !== 0;
  }

  hosts(): readonly string[] {
    return this.buffer.hosts;
  }

  attributes(): readonly string[] {
    return this.buffer.attributes;
  }

  /** The CA certificate file the read answered, shown and never set (AD-21). */
  caFile(): string {
    return this.caFileValue;
  }

  /** Whether the instance's Kerberos authentication is on, which is when the Kerberos pair is drawn. */
  kerberos(): boolean {
    return this.kerberosValue;
  }

  /** Whether the configuration is Kerberos-only (bit 128), which draws only its name, description and the pair. */
  kerberosOnly(): boolean {
    return this.flag(FLAG_KERBEROS_ONLY);
  }

  /** Whether the Groups tab's group fields take input: while Use LDAP groups is ticked. */
  groupsEnabled(): boolean {
    return this.flag(FLAG_GROUPS);
  }

  /** Whether Search nested groups takes input: while Active Directory and Use LDAP groups are both ticked. */
  nestedEnabled(): boolean {
    return this.flag(FLAG_ACTIVE_DIRECTORY) && this.flag(FLAG_GROUPS);
  }

  /** Whether one of the four role, namespace and routine attributes takes input: while LDAP groups are not used. */
  attributeEnabled(field: string): boolean {
    return !GROUPLESS_ATTRIBUTE_FIELDS.includes(field) || !this.flag(FLAG_GROUPS);
  }

  passwordMode(): PasswordMode {
    return this.passwordModeValue;
  }

  /** What the password field holds now, or `''`. */
  password(): string {
    return this.passwordValue;
  }

  confirm(): string {
    return this.confirmValue;
  }

  /** The names Copy settings from offers: the LDAP / Kerberos list's, read when a create opens. */
  copyOptions(): readonly string[] {
    return this.copyNames;
  }

  /** The configuration the form last copied settings from, or `''`. */
  copiedFrom(): string {
    return this.copiedValue;
  }

  examples(): LdapExamples {
    return this.examplesValue;
  }

  /** Whether the settings take input: a create always, an edit once its fresh read is held. */
  editable(): boolean {
    return this.modeValue === 'create' || this.heldValue;
  }

  /** Whether Save may send: not while one is in flight, never over an absent configuration. */
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

  /** The instance's sentence when a Save landed and its password write was refused, or `''`. */
  secretsRefused(): string {
    return this.secretsRefusedValue;
  }

  /** The read-back the last accepted Save answered (AD-58), which its "Saved" line renders. */
  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  /** The created configuration's stored name, or `''`. */
  createdId(): string {
    return this.createdIdValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  /** Whether this store is being carried across a create's own route replacement. */
  retaining(): boolean {
    return this.retainingValue;
  }

  /** Whether Test authentication may run: on a saved configuration with no unsaved change. */
  canTest(): boolean {
    return this.modeValue === 'edit' && this.heldValue && !this.absentValue && !this.formDirty.dirty();
  }

  testing(): boolean {
    return this.testingValue;
  }

  /** The last test's lines, the instance's own, or `null` before one answered. */
  testLines(): readonly string[] | null {
    return this.testLinesValue;
  }

  testViolationFor(field: string): string {
    return reasonForField(this.testViolationList, field);
  }

  /** A test refused as a whole -- an absent configuration, a missing privilege -- or `''`. */
  testReason(): string {
    return this.testReasonValue;
  }

  /** Whether the last test's request was ended before the instance answered. */
  testNoAnswer(): boolean {
    return this.testNoAnswerValue;
  }

  /**
   * The fields an edit's Save would send: each changed since the read, and the password's choice --
   * the typed value for Enter a new password, `""` for Clear the password. An empty Enter sends none.
   */
  changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of TEXT_FIELDS) {
      if (this.text(field) !== (this.opened.text[field] ?? '')) out[field] = this.wireValue(field);
    }
    if (this.buffer.flags !== this.opened.flags) out[FLAGS_FIELD] = this.buffer.flags;
    if (!sameList(this.buffer.hosts, this.opened.hosts)) out[HOSTS_FIELD] = [...this.buffer.hosts];
    if (!sameList(this.buffer.attributes, this.opened.attributes)) out[ATTRIBUTES_FIELD] = [...this.buffer.attributes];
    if (this.passwordModeValue === 'enter' && this.passwordValue !== '') out[PASSWORD_FIELD] = this.passwordValue;
    if (this.passwordModeValue === 'clear') out[PASSWORD_FIELD] = '';
    return out;
  }

  /** Keep this form's state across the one navigation that is not a departure, less the passwords. */
  retainAcrossRouteReplacement(): void {
    this.clearPasswords();
    this.retainingValue = true;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything, the passwords first: from the sign-out teardown and when the editor is left. */
  reset(): void {
    this.clearPasswords();
    this.generation += 1;
    this.modeValue = 'create';
    this.buffer = EMPTY_BUFFER;
    this.opened = EMPTY_BUFFER;
    this.caFileValue = '';
    this.kerberosValue = false;
    this.copyNames = [];
    this.copiedValue = '';
    this.examplesValue = NO_EXAMPLES;
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
    this.testingValue = false;
    this.testLinesValue = null;
    this.testViolationList = [];
    this.testReasonValue = '';
    this.testNoAnswerValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the editor: a create when `name` is empty, an edit of that configuration otherwise. The form
   * read is made on every open. An arrival that is a create's own route replacement opens the new
   * configuration's edit and keeps the saved confirmation on screen.
   */
  async open(name: string): Promise<void> {
    const arriving = this.retainingValue && name !== '' && name === this.createdIdValue;
    const keptReadBack = arriving ? this.readBackValue : null;
    const keptRefusal = arriving ? this.secretsRefusedValue : '';
    this.reset();
    if (arriving) {
      this.savedValue = true;
      this.readBackValue = keptReadBack;
      this.secretsRefusedValue = keptRefusal;
    }
    this.modeValue = name === '' ? 'create' : 'edit';
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(name === '' ? `${LDAP_FORM_PATH}?new=1` : `${LDAP_FORM_PATH}?name=${encodeURIComponent(name)}`);
    if (generation !== this.generation) return;
    this.absorb(result, name);
    this.loadedValue = true;
    this.notify();
    if (this.heldValue) void this.readExamples();
    if (this.modeValue === 'create' && this.heldValue) void this.readCopyOptions();
  }

  /**
   * Read the configuration again after a change from either caller (AD-14). A form holding no
   * unsaved change takes the new values; one holding changes keeps them, and its Save is judged
   * against the instance as it is then.
   */
  async refresh(): Promise<void> {
    if (this.modeValue !== 'edit' || !this.heldValue || this.formDirty.dirty()) return;
    const generation = this.generation;
    const name = this.buffer.name;
    const result = await this.api().requestJson<unknown>(`${LDAP_FORM_PATH}?name=${encodeURIComponent(name)}`);
    if (generation !== this.generation || result.kind !== 'ok' || this.formDirty.dirty()) return;
    this.absorb(result, name);
    this.notify();
  }

  setName(value: string): void {
    if (this.modeValue !== 'create' || this.buffer.name === value) return;
    this.buffer = { ...this.buffer, name: value };
    this.change(NAME_FIELD);
  }

  setText(field: string, value: string): void {
    if (!this.editable() || !TEXT_FIELDS.includes(field) || this.text(field) === value) return;
    this.buffer = { ...this.buffer, text: { ...this.buffer.text, [field]: value } };
    this.change(field);
  }

  /**
   * Set or clear flag bit `bit` over the value the form holds, with the classic page's couplings:
   * clearing Use LDAP groups clears nested and universal groups; clearing Active Directory clears
   * nested groups; nested groups is refused while either is clear, and universal groups while LDAP
   * groups are not used.
   */
  setFlag(bit: number, on: boolean): void {
    if (!this.editable()) return;
    if (on && bit === FLAG_NESTED && !this.nestedEnabled()) return;
    if (on && bit === FLAG_UNIVERSAL && !this.groupsEnabled()) return;
    let flags = on ? this.buffer.flags | bit : this.buffer.flags & ~bit;
    if (!on && bit === FLAG_GROUPS) flags &= ~(FLAG_NESTED | FLAG_UNIVERSAL);
    if (!on && bit === FLAG_ACTIVE_DIRECTORY) flags &= ~FLAG_NESTED;
    this.setFlags(flags);
    if (bit === FLAG_UNIVERSAL || bit === FLAG_GROUPS) void this.readExamples();
  }

  /**
   * LDAP configuration, the Kerberos pair's second box: unticking it makes the configuration
   * Kerberos-only (sets 128) and clears LDAP enabled (64), which the instance would clear anyway;
   * ticking it clears 128.
   */
  setLdapConfiguration(on: boolean): void {
    if (!this.editable()) return;
    this.setFlags(on ? this.buffer.flags & ~FLAG_KERBEROS_ONLY : (this.buffer.flags | FLAG_KERBEROS_ONLY) & ~FLAG_ENABLED);
  }

  /**
   * Add one host name or attribute, trimmed; an empty or already listed one adds nothing. Answers
   * whether it was added. The server refuses a host holding a space on the field.
   */
  addEntry(field: typeof HOSTS_FIELD | typeof ATTRIBUTES_FIELD, text: string): boolean {
    if (!this.editable()) return false;
    const entry = text.trim();
    const held = field === HOSTS_FIELD ? this.buffer.hosts : this.buffer.attributes;
    if (entry === '' || held.includes(entry)) return false;
    this.buffer = field === HOSTS_FIELD ? { ...this.buffer, hosts: [...held, entry] } : { ...this.buffer, attributes: [...held, entry] };
    this.change(field);
    return true;
  }

  removeEntry(field: typeof HOSTS_FIELD | typeof ATTRIBUTES_FIELD, index: number): void {
    if (!this.editable()) return;
    const held = field === HOSTS_FIELD ? this.buffer.hosts : this.buffer.attributes;
    if (index < 0 || index >= held.length) return;
    const next = held.filter((_, at) => at !== index);
    this.buffer = field === HOSTS_FIELD ? { ...this.buffer, hosts: next } : { ...this.buffer, attributes: next };
    this.change(field);
  }

  setPasswordMode(mode: PasswordMode): void {
    if (!this.editable() || this.passwordModeValue === mode) return;
    this.passwordModeValue = mode;
    if (mode !== 'enter') {
      this.passwordValue = '';
      this.confirmValue = '';
    }
    this.change(PASSWORD_FIELD);
  }

  setPassword(value: string): void {
    if (this.passwordModeValue !== 'enter' || this.passwordValue === value) return;
    this.passwordValue = value;
    this.change(PASSWORD_FIELD);
  }

  setConfirm(value: string): void {
    if (this.passwordModeValue !== 'enter' || this.confirmValue === value) return;
    this.confirmValue = value;
    this.change(PASSWORD_FIELD);
  }

  /**
   * On a create's name blur, ask the instance what it would store: the name becomes that form, and
   * each base DN still empty takes the base DN it derives. A name it refuses is marked on the field
   * with its sentence; a look-up that could not be made leaves the field as it is.
   */
  async checkName(): Promise<void> {
    if (this.modeValue !== 'create') return;
    const name = this.buffer.name.trim();
    if (name === '') return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${LDAP_NAME_PATH}?name=${encodeURIComponent(name)}`);
    if (generation !== this.generation || this.buffer.name.trim() !== name) return;
    if (result.kind !== 'ok') {
      const refused = violationsOf(result).filter((entry) => entry.field === NAME_FIELD);
      if (refused.length === 0) return;
      this.violationList = [...this.violationList.filter((entry) => entry.field !== NAME_FIELD), ...refused];
      this.notify();
      return;
    }
    const canonical = textOf(result.body, 'canonical');
    const baseDn = textOf(result.body, 'baseDN');
    if (canonical !== '' && canonical !== this.buffer.name) this.setName(canonical);
    for (const field of [BASE_DN_FIELD, GROUPS_BASE_DN_FIELD]) {
      if (baseDn !== '' && this.text(field) === '') this.setText(field, baseDn);
    }
  }

  /**
   * Copy settings from configuration `name` (a create only): every setting but the name, the
   * description and the two base DNs is read from it, and the password option becomes Enter a new
   * password, because no password is ever read.
   */
  async copyFrom(name: string): Promise<void> {
    if (this.modeValue !== 'create' || name === '') return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${LDAP_FORM_PATH}?name=${encodeURIComponent(name)}`);
    if (generation !== this.generation || result.kind !== 'ok') return;
    const source = recordOf(recordOf(result.body)['ldap']);
    const text: Record<string, string> = { ...this.buffer.text };
    for (const field of TEXT_FIELDS) {
      if (!UNCOPIED_FIELDS.includes(field)) text[field] = textOf(source, field);
    }
    const flags = Number(source[FLAGS_FIELD]);
    this.buffer = {
      ...this.buffer,
      text,
      flags: Number.isFinite(flags) ? flags : this.buffer.flags,
      hosts: stringsOf(source, HOSTS_FIELD),
      attributes: stringsOf(source, ATTRIBUTES_FIELD),
    };
    this.copiedValue = name;
    this.passwordModeValue = 'enter';
    this.change(FLAGS_FIELD);
    void this.readExamples();
  }

  /** Read the three group examples again from the instance, over the group inputs the form holds. */
  async readExamples(): Promise<void> {
    if (!this.heldValue) return;
    const generation = this.generation;
    const ticket = ++this.examplesGeneration;
    const query = new URLSearchParams();
    for (const field of [ORGANIZATION_FIELD, ...ADVANCED_FIELDS]) query.set(field, this.text(field));
    query.set('UniversalGroup', this.flag(FLAG_UNIVERSAL) ? '1' : '0');
    for (const field of AUTHORIZATION_FIELDS) query.set(field, this.text(field));
    const result = await this.api().requestJson<unknown>(`${LDAP_EXAMPLES_PATH}?${query.toString()}`);
    if (generation !== this.generation || ticket !== this.examplesGeneration || result.kind !== 'ok') return;
    this.examplesValue = {
      universal: textOf(result.body, 'universal'),
      group: textOf(result.body, 'group'),
      instance: textOf(result.body, 'instance'),
    };
    this.notify();
  }

  /**
   * Save: a create posts the name and every setting; an edit puts the settings changed since its
   * read. The password travels for Enter a new password or Clear the password alone; two passwords
   * that differ are refused here and nothing is sent. An accepted Save clears the passwords before
   * anything is published, publishes one change event (AD-14) and marks the form clean; a refused one
   * keeps what was entered.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    if (this.passwordModeValue === 'enter' && this.passwordValue !== this.confirmValue) {
      this.violationList = [
        ...this.violationList.filter((entry) => entry.field !== PASSWORD_FIELD),
        { field: PASSWORD_FIELD, code: '', reason: STRINGS.ldapPasswordMismatch },
      ];
      this.clearRefusal();
      this.savedValue = false;
      this.notify();
      return false;
    }
    const creating = this.modeValue === 'create';
    const body = creating ? this.createBody() : this.changedFields();
    if (!creating && Object.keys(body).length === 0) {
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
    const sentBuffer = this.buffer;
    const result = await this.api().requestJson<unknown>(creating ? LDAP_PATH : `${LDAP_PATH}/${encodeEntityId(this.buffer.name)}`, {
      method: creating ? 'POST' : 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.rememberRefusal(result);
      if (!creating && result.kind === 'error' && result.status === 404) this.absentValue = true;
      this.notify();
      return false;
    }
    this.clearPasswords();
    const stored = textOf(result.body, 'name');
    const id = creating ? stored || this.buffer.name : this.buffer.name;
    if (creating) this.createdIdValue = id;
    this.opened = sentBuffer;
    this.secretsRefusedValue = textOf(result.body, 'secretsRefused');
    const pending = !creating && Object.keys(this.changedFields()).length > 0;
    this.savedValue = !pending;
    this.readBackValue = readBackOf(recordOf(result.body)['readBack']);
    this.formDirty.setDirty(pending);
    this.publish(id, creating ? 'created' : 'updated');
    this.notify();
    return true;
  }

  /**
   * Test authentication: test user name `user` and password `password` against the saved
   * configuration. The answer's lines are the instance's own, carrying no verdict; a refused field
   * lands on it, and a request the gateway ends reads as no answer. The password is not kept.
   */
  async test(user: string, password: string): Promise<void> {
    if (!this.canTest() || this.testingValue) return;
    const generation = this.generation;
    this.testingValue = true;
    this.testLinesValue = null;
    this.testViolationList = [];
    this.testReasonValue = '';
    this.testNoAnswerValue = false;
    this.notify();
    const result = await this.api().requestJson<unknown>(`${LDAP_PATH}/${encodeEntityId(this.buffer.name)}/test`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ Username: user, Password: password }),
    });
    if (generation !== this.generation) return;
    this.testingValue = false;
    if (result.kind !== 'ok') {
      this.testViolationList = violationsOf(result);
      // A request the gateway ended answers no envelope of OcuPilot's: no code, and no lines.
      this.testNoAnswerValue = result.kind === 'error' && result.code === null;
      this.testReasonValue = this.testViolationList.length === 0 && !this.testNoAnswerValue && result.kind === 'error' ? (result.reason ?? '') : '';
      this.notify();
      return;
    }
    this.testLinesValue = stringsOf(result.body, 'lines');
    this.notify();
  }

  /** Forget the last test's answer, when its dialog closes. */
  clearTest(): void {
    this.testLinesValue = null;
    this.testViolationList = [];
    this.testReasonValue = '';
    this.testNoAnswerValue = false;
    this.notify();
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private setFlags(flags: number): void {
    if (flags === this.buffer.flags) return;
    this.buffer = { ...this.buffer, flags };
    this.change(FLAGS_FIELD);
  }

  private clearPasswords(): void {
    this.passwordValue = '';
    this.confirmValue = '';
    this.passwordModeValue = 'leave';
  }

  /** Read the names the LDAP / Kerberos list answers, for Copy settings from. */
  private async readCopyOptions(): Promise<void> {
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(LDAP_LIST_READ_PATH);
    if (generation !== this.generation || result.kind !== 'ok') return;
    const rows = recordOf(result.body)['rows'];
    this.copyNames = Array.isArray(rows) ? rows.map((row) => textOf(row, NAME_FIELD)).filter((name) => name !== '') : [];
    this.notify();
  }

  private change(field: string): void {
    if (this.violationList.some((entry) => entry.field === field)) {
      this.violationList = this.violationList.filter((entry) => entry.field !== field);
    }
    this.savedValue = false;
    this.secretsRefusedValue = '';
    this.formDirty.setDirty(this.modeValue === 'create' || Object.keys(this.changedFields()).length > 0);
    this.notify();
  }

  /** One text setting as the wire carries it: a whole number for a timeout, text otherwise. */
  private wireValue(field: string): unknown {
    const value = this.text(field);
    if (NUMBER_FIELDS.includes(field)) return /^\d+$/.test(value.trim()) ? Number(value.trim()) : value;
    return value;
  }

  /** A create's body: the name and every setting the form holds (AD-54), and the password's choice. */
  private createBody(): Record<string, unknown> {
    const out: Record<string, unknown> = { [NAME_FIELD]: this.buffer.name.trim() };
    for (const field of TEXT_FIELDS) out[field] = this.wireValue(field);
    out[FLAGS_FIELD] = this.buffer.flags;
    out[HOSTS_FIELD] = [...this.buffer.hosts];
    out[ATTRIBUTES_FIELD] = [...this.buffer.attributes];
    if (this.passwordModeValue === 'enter' && this.passwordValue !== '') out[PASSWORD_FIELD] = this.passwordValue;
    return out;
  }

  private absorb(result: JsonResult<unknown>, name: string): void {
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.rememberRefusal(result);
      if (name !== '' && result.kind === 'error' && result.status === 404) this.absentValue = true;
      return;
    }
    const body = recordOf(result.body);
    const ldap = body['ldap'];
    if (ldap === null || typeof ldap !== 'object' || Array.isArray(ldap)) {
      if (name !== '') this.absentValue = true;
      return;
    }
    const source = ldap as Record<string, unknown>;
    const text: Record<string, string> = {};
    for (const field of TEXT_FIELDS) text[field] = textOf(source, field);
    const flags = Number(source[FLAGS_FIELD]);
    this.buffer = {
      name: name === '' ? '' : textOf(source, NAME_FIELD) || name,
      text,
      flags: Number.isFinite(flags) ? flags : 0,
      hosts: stringsOf(source, HOSTS_FIELD),
      attributes: stringsOf(source, ATTRIBUTES_FIELD),
    };
    this.opened = this.buffer;
    this.caFileValue = textOf(source, CA_FILE_FIELD);
    this.kerberosValue = body['kerberos'] === true;
    this.heldValue = true;
  }

  private rememberRefusal(result: JsonResult<unknown>): void {
    if (result.kind !== 'error') {
      this.clearRefusal();
      return;
    }
    this.envelopeReason = this.violationList.length === 0 ? (result.reason ?? '') : '';
    this.refusalCodeValue = result.code ?? '';
    const pair = result.detail === null ? undefined : result.detail['failedPair'];
    this.refusalPairValue = typeof pair === 'string' ? pair : '';
  }

  private clearRefusal(): void {
    this.envelopeReason = '';
    this.refusalCodeValue = '';
    this.refusalPairValue = '';
    this.secretsRefusedValue = '';
  }

  /** AD-14: the LDAP / Kerberos list, and anything else showing this configuration, reads it again. */
  private publish(id: string, action: ChangeAction): void {
    if (id === '') return;
    this.injector.get(ChangeBus).publish({ kind: 'changed', type: LDAP_ENTITY, scope: LDAP_SCOPE, id, action, readBack: this.readBackValue });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

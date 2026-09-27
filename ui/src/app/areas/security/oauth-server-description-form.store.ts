import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` creates, `PUT <path>/<id>` edits. */
export const OAUTH_SERVER_PATH = '/api/ocupilot/oauth/server-description';

/** The form read: the rules, the metadata members, the readable names and, with an issuer, the description. */
export const OAUTH_SERVER_FORM_PATH = `${OAUTH_SERVER_PATH}/form`;

/** The discovery read: an issuer's published metadata, saved nowhere (AD-27). */
export const OAUTH_SERVER_DISCOVER_PATH = `${OAUTH_SERVER_PATH}/discover`;

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const OAUTH_SERVER_ENTITY = 'oauth2-server-definition';

export const OAUTH_SERVER_SCOPE = 'instance';

/** The top-level fields, named as the server names them. */
export const ISSUER_FIELD = 'IssuerEndpoint';

export const SSL_FIELD = 'SSLConfiguration';

export const CREDENTIALS_FIELD = 'ServerCredentials';

export const METADATA_FIELD = 'Metadata';

/** The one secret: written through its own write, never read back (AD-3, AD-35, AD-56). */
export const TOKEN_FIELD = 'InitialAccessToken';

/** The metadata member the JWT settings' "JWKS from URL" choice holds. */
export const JWKS_MEMBER = 'jwks_uri';

/** The Authorization server group's members, in the classic page's order. */
export const ENDPOINT_MEMBERS: readonly string[] = [
  'authorization_endpoint',
  'token_endpoint',
  'userinfo_endpoint',
  'introspection_endpoint',
  'revocation_endpoint',
  'end_session_endpoint',
];

/** The JWT settings' three choices: no key source, the JWKS URL, or an X.509 credential. */
export type JwtChoice = 'none' | 'url' | 'x509';

/** What the form is doing: creating a description, or editing the one its route names. */
export type FormMode = 'create' | 'edit';

/** How a metadata member is shaped on the wire: a URI or text, a list of strings, or a flag. */
export type MemberKind = 'uri' | 'list' | 'flag';

export interface MetadataMember {
  readonly name: string;
  readonly kind: MemberKind;
}

export type MemberValue = string | readonly string[] | boolean;

/** One rule the server applies, with the sentence it refuses with (AD-39). */
export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** The field a violation on metadata member `name` is reported under. */
export function memberField(name: string): string {
  return `${METADATA_FIELD}.${name}`;
}

interface Held {
  readonly issuer: string;
  readonly ssl: string;
  readonly credentials: string;
  readonly metadata: Readonly<Record<string, MemberValue>>;
}

const EMPTY_HELD: Held = { issuer: '', ssl: '', credentials: '', metadata: {} };

function record(source: unknown): Record<string, unknown> | null {
  return source !== null && typeof source === 'object' && !Array.isArray(source) ? (source as Record<string, unknown>) : null;
}

function textAt(source: unknown, key: string): string {
  const value = record(source)?.[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function stringsOf(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === 'string') : [];
}

/**
 * A member's empty form: `''` for a URI, `[]` for a list, `''` for a flag. A flag's empty form is not
 * `false`, which the instance stores as a value; `''` clears it.
 */
function emptyOf(kind: MemberKind): MemberValue {
  return kind === 'list' ? [] : '';
}

/**
 * A member's value read off the wire, in its kind's shape; anything else reads as the empty form. A
 * flag the wire does not carry is absent, so only a wire boolean reads as `true` or `false`.
 */
function memberOf(kind: MemberKind, value: unknown): MemberValue {
  if (kind === 'list') return stringsOf(value);
  if (kind === 'flag') return typeof value === 'boolean' ? value : '';
  return typeof value === 'string' ? value : '';
}

/** Whether a member holds nothing: a flag holding `false` holds a value. */
function isEmpty(value: MemberValue): boolean {
  if (typeof value === 'boolean') return false;
  return value.length === 0;
}

function same(left: MemberValue, right: MemberValue): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

/**
 * The OAuth 2.0 server description editor's store (AD-19, AD-55): a create on
 * `security/oauth/edit`, an edit of the description its route names on
 * `security/oauth/edit/<issuer>`.
 *
 * **It composes no payload of its own.** `POST /oauth/server-description` and
 * `PUT /oauth/server-description/<id>` resolve the tool classes the agent's
 * `security.oauthserverdescriptions.create` and `.update` do; the server expands `Metadata` to every
 * member and sends the complete set (AD-4), and every field sentence is the server's (AD-39).
 *
 * **An edit sends only what changed since its fresh read**: the top-level fields that changed and,
 * under `Metadata`, the members that changed, a cleared one in its empty form. The server applies
 * them over its own fresh read, so a member another party changed since is kept.
 *
 * **The registration access token is held in this store alone, until Save** (AD-35). It is never
 * pre-filled -- no read returns it -- and is sent only when typed; an empty field keeps the stored one.
 */
@Injectable({ providedIn: 'root' })
export class OAuthServerDescriptionForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Held = EMPTY_HELD;

  private opened: Held = EMPTY_HELD;

  private tokenValue = '';

  private choiceValue: JwtChoice = 'none';

  private membersValue: readonly MetadataMember[] = [];

  private sslNames: readonly string[] = [];

  private credentialNames: readonly string[] = [];

  private rulesValue: readonly FieldRule[] = [];

  private requiredValue: readonly string[] = [];

  private clientCountValue = 0;

  private loadedValue = false;

  private heldValue = false;

  private absentValue = false;

  private savingValue = false;

  private discoveringValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private savedValue = false;
  /** The instance's read-back of the last accepted Save (AD-58), or `null`. */
  private readBackValue: ReadBack | null = null;

  private tokenRefusedValue = '';

  private discoveredValue = '';

  private savedIdValue = '';

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
    return this.savingValue || this.discoveringValue;
  }

  /** Whether an edit names a description the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** Whether an edit's fresh read is held, which is what the page's Delete and Update JWKS act on. */
  held(): boolean {
    return this.heldValue;
  }

  issuer(): string {
    return this.buffer.issuer;
  }

  /** The issuer the fresh read answered: the description Delete and Update JWKS name. */
  storedIssuer(): string {
    return this.opened.issuer;
  }

  ssl(): string {
    return this.buffer.ssl;
  }

  credentials(): string {
    return this.buffer.credentials;
  }

  token(): string {
    return this.tokenValue;
  }

  choice(): JwtChoice {
    return this.choiceValue;
  }

  /** A metadata member's value now, in its kind's shape. */
  member(name: string): MemberValue {
    const held = this.buffer.metadata[name];
    if (held !== undefined) return held;
    return emptyOf(this.kindOf(name));
  }

  /** A URI member's text now, or `''`. */
  memberText(name: string): string {
    const value = this.member(name);
    return typeof value === 'string' ? value : '';
  }

  /** The stored JWKS URL, as the fresh read answered it. */
  storedJwksUri(): string {
    const value = this.opened.metadata[JWKS_MEMBER];
    return typeof value === 'string' ? value : '';
  }

  /** Every derived member, in the server's order. */
  members(): readonly MetadataMember[] {
    return this.membersValue;
  }

  /** The members the metadata table shows: every one the form does not edit in a field of its own. */
  tableMembers(): readonly MetadataMember[] {
    return this.membersValue.filter((entry) => entry.name !== JWKS_MEMBER && !ENDPOINT_MEMBERS.includes(entry.name));
  }

  /** The SSL/TLS configurations the caller can read through that screen's own read (AD-5). */
  sslConfigurations(): readonly string[] {
    return this.sslNames;
  }

  /** The X.509 credentials the caller can read through that screen's own read (AD-5). */
  credentialAliases(): readonly string[] {
    return this.credentialNames;
  }

  clientCount(): number {
    return this.clientCountValue;
  }

  /** Whether the fields take input: in edit mode only once the fresh read is held. */
  editable(): boolean {
    return (this.modeValue === 'create' || this.heldValue) && !this.busy();
  }

  canSave(): boolean {
    if (this.busy() || this.absentValue) return false;
    return this.modeValue === 'create' || this.heldValue;
  }

  canDiscover(): boolean {
    return this.editable() && this.buffer.issuer.trim() !== '';
  }

  required(field: string): boolean {
    return this.requiredValue.includes(field);
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

  /** The sentence a token write was refused with after the description saved, or `''`. */
  tokenRefused(): string {
    return this.tokenRefusedValue;
  }

  /** The issuer the last discovery fetched from, or `''`. */
  discovered(): string {
    return this.discoveredValue;
  }

  /** The issuer the last accepted Save answered, or `''`. */
  savedId(): string {
    return this.savedIdValue;
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
    this.buffer = EMPTY_HELD;
    this.opened = EMPTY_HELD;
    this.tokenValue = '';
    this.choiceValue = 'none';
    this.membersValue = [];
    this.sslNames = [];
    this.credentialNames = [];
    this.rulesValue = [];
    this.requiredValue = [];
    this.clientCountValue = 0;
    this.loadedValue = false;
    this.heldValue = false;
    this.absentValue = false;
    this.savingValue = false;
    this.discoveringValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.tokenRefusedValue = '';
    this.discoveredValue = '';
    this.savedIdValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form: a create when `issuer` is empty, an edit of that description otherwise. The form
   * read is made on every open. An arrival that is a Save's own route replacement keeps the saved
   * confirmation, and any token refusal beside it, on screen.
   */
  async open(issuer: string): Promise<void> {
    const arriving = this.retainingValue && issuer !== '' && issuer === this.savedIdValue;
    const tokenRefused = arriving ? this.tokenRefusedValue : '';
    this.reset();
    if (arriving) {
      this.savedValue = true;
      this.tokenRefusedValue = tokenRefused;
    }
    this.modeValue = issuer === '' ? 'create' : 'edit';
    const generation = this.generation;
    const path = issuer === '' ? OAUTH_SERVER_FORM_PATH : `${OAUTH_SERVER_FORM_PATH}?issuer=${encodeURIComponent(issuer)}`;
    const result = await this.api().requestJson<unknown>(path);
    if (generation !== this.generation) return;
    this.absorb(result, issuer);
    this.loadedValue = true;
    this.notify();
  }

  setIssuer(value: string): void {
    this.setTop('issuer', ISSUER_FIELD, value);
  }

  setSsl(value: string): void {
    this.setTop('ssl', SSL_FIELD, value);
  }

  setCredentials(value: string): void {
    this.setTop('credentials', CREDENTIALS_FIELD, value);
  }

  setToken(value: string): void {
    if (!this.editable() || this.tokenValue === value) return;
    this.tokenValue = value;
    this.change(TOKEN_FIELD);
  }

  /** Set a URI member the form edits in a field of its own. */
  setMemberText(name: string, value: string): void {
    if (!this.editable() || this.kindOf(name) !== 'uri' || this.memberText(name) === value) return;
    this.buffer = { ...this.buffer, metadata: { ...this.buffer.metadata, [name]: value } };
    this.change(memberField(name));
  }

  /** Switch the JWT settings' choice; the value the other choice held is cleared. */
  setChoice(choice: JwtChoice): void {
    if (!this.editable() || this.choiceValue === choice) return;
    this.choiceValue = choice;
    const metadata = { ...this.buffer.metadata };
    if (choice !== 'url') metadata[JWKS_MEMBER] = '';
    this.buffer = { ...this.buffer, metadata, credentials: choice === 'x509' ? this.buffer.credentials : '' };
    this.change(memberField(JWKS_MEMBER));
  }

  /**
   * On blur: render the server's required-field sentence on an empty required field of a create, as
   * the form read's first rule for it words it.
   */
  onBlur(field: string): void {
    if (this.modeValue !== 'create' || !this.required(field)) return;
    if (this.fieldText(field).trim() !== '') return;
    const rule = this.rulesValue.find((entry) => entry.field === field);
    if (rule === undefined || this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /**
   * Discover: fetch the metadata the issuer publishes into the form for review (AD-27). Nothing is
   * saved; the form is dirty until Save. A refusal leaves the form as it was.
   */
  async discover(): Promise<boolean> {
    if (!this.canDiscover()) return false;
    const generation = this.generation;
    this.discoveringValue = true;
    this.clearRefusal();
    this.discoveredValue = '';
    this.savedValue = false;
    this.notify();
    const result = await this.api().requestJson<unknown>(OAUTH_SERVER_DISCOVER_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ [ISSUER_FIELD]: this.buffer.issuer, [SSL_FIELD]: this.buffer.ssl }),
    });
    if (generation !== this.generation) return false;
    this.discoveringValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.notify();
      return false;
    }
    const published = record(record(result.body)?.['metadata']);
    const metadata: Record<string, MemberValue> = {};
    for (const entry of this.membersValue) metadata[entry.name] = memberOf(entry.kind, published?.[entry.name]);
    this.buffer = { ...this.buffer, metadata };
    if (this.memberText(JWKS_MEMBER) !== '') {
      this.choiceValue = 'url';
      this.buffer = { ...this.buffer, credentials: '' };
    }
    this.violationList = [];
    this.discoveredValue = textAt(result.body, 'issuer') || this.buffer.issuer;
    this.formDirty.setDirty(true);
    this.notify();
    return true;
  }

  /**
   * Save: a create posts every field and the non-empty members; an edit puts what changed since its
   * fresh read. A typed token travels beside them and is stored after the description is (AD-56);
   * the store forgets it either way. An accepted Save publishes one change event (AD-14).
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const creating = this.modeValue === 'create';
    const body = creating ? this.createBody() : this.changedBody();
    if (!creating && Object.keys(body).length === 0 && this.tokenValue === '') {
      this.clearRefusal();
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    if (this.tokenValue !== '') body[TOKEN_FIELD] = this.tokenValue;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.readBackValue = null;
    this.tokenRefusedValue = '';
    this.discoveredValue = '';
    this.notify();
    const result = creating
      ? await this.api().requestJson<unknown>(OAUTH_SERVER_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        })
      : await this.api().requestJson<unknown>(`${OAUTH_SERVER_PATH}/${encodeEntityId(this.opened.issuer)}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        });
    delete body[TOKEN_FIELD];
    if (generation !== this.generation) return false;
    this.savingValue = false;
    this.tokenValue = '';
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.notify();
      return false;
    }
    const id = textAt(result.body, 'issuer') || this.buffer.issuer;
    this.savedIdValue = id;
    this.tokenRefusedValue = textAt(result.body, 'tokenRefused');
    this.opened = this.buffer;
    this.savedValue = true;
    this.readBackValue = readBackOf((result.body as Record<string, unknown> | null)?.['readBack']);
    this.formDirty.setDirty(false);
    this.publish(id, creating ? 'created' : 'updated');
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private kindOf(name: string): MemberKind {
    return this.membersValue.find((entry) => entry.name === name)?.kind ?? 'uri';
  }

  private fieldText(field: string): string {
    if (field === ISSUER_FIELD) return this.buffer.issuer;
    if (field === SSL_FIELD) return this.buffer.ssl;
    if (field === CREDENTIALS_FIELD) return this.buffer.credentials;
    if (field.startsWith(`${METADATA_FIELD}.`)) return this.memberText(field.slice(METADATA_FIELD.length + 1));
    return '';
  }

  private setTop(key: 'issuer' | 'ssl' | 'credentials', field: string, value: string): void {
    if (!this.editable() || this.buffer[key] === value) return;
    this.buffer = { ...this.buffer, [key]: value };
    this.change(field);
  }

  private change(field: string): void {
    if (this.violationList.some((entry) => entry.field === field)) {
      this.violationList = this.violationList.filter((entry) => entry.field !== field);
    }
    this.savedValue = false;
    this.tokenRefusedValue = '';
    this.formDirty.setDirty(true);
    this.notify();
  }

  /** A create's body: the three fields and every member that holds a value (AD-54). */
  private createBody(): Record<string, unknown> {
    const metadata: Record<string, MemberValue> = {};
    for (const entry of this.membersValue) {
      const value = this.member(entry.name);
      if (!isEmpty(value)) metadata[entry.name] = value;
    }
    return {
      [ISSUER_FIELD]: this.buffer.issuer,
      [SSL_FIELD]: this.buffer.ssl,
      [CREDENTIALS_FIELD]: this.buffer.credentials,
      [METADATA_FIELD]: metadata,
    };
  }

  /** An edit's body: the fields and the members changed since the fresh read, a cleared one empty. */
  private changedBody(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    if (this.buffer.issuer !== this.opened.issuer) out[ISSUER_FIELD] = this.buffer.issuer;
    if (this.buffer.ssl !== this.opened.ssl) out[SSL_FIELD] = this.buffer.ssl;
    if (this.buffer.credentials !== this.opened.credentials) out[CREDENTIALS_FIELD] = this.buffer.credentials;
    const metadata: Record<string, MemberValue> = {};
    for (const entry of this.membersValue) {
      const now = this.member(entry.name);
      const before = this.opened.metadata[entry.name] ?? emptyOf(entry.kind);
      if (!same(now, before)) metadata[entry.name] = now;
    }
    if (Object.keys(metadata).length > 0) out[METADATA_FIELD] = metadata;
    return out;
  }

  private absorb(result: JsonResult<unknown>, issuer: string): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      if (issuer !== '' && result.kind === 'error' && result.status === 404) this.absentValue = true;
      return;
    }
    const body = record(result.body);
    const rules: FieldRule[] = [];
    for (const entry of Array.isArray(body?.['rules']) ? (body['rules'] as unknown[]) : []) {
      const field = textAt(entry, 'field');
      const code = textAt(entry, 'code');
      const reason = textAt(entry, 'reason');
      if (field !== '' && code !== '' && reason !== '') rules.push({ field, code, reason });
    }
    this.rulesValue = rules;
    this.requiredValue = stringsOf(body?.['requiredFields']);
    const members: MetadataMember[] = [];
    for (const entry of Array.isArray(body?.['members']) ? (body['members'] as unknown[]) : []) {
      const name = textAt(entry, 'name');
      const kind = textAt(entry, 'kind');
      if (name !== '' && (kind === 'uri' || kind === 'list' || kind === 'flag')) members.push({ name, kind });
    }
    this.membersValue = members;
    this.sslNames = stringsOf(body?.['sslConfigurations']);
    this.credentialNames = stringsOf(body?.['credentials']);
    if (issuer === '') return;
    const definition = record(body?.['definition']);
    if (definition === null) {
      this.absentValue = true;
      return;
    }
    const stored = record(definition[METADATA_FIELD]);
    const metadata: Record<string, MemberValue> = {};
    for (const entry of members) metadata[entry.name] = memberOf(entry.kind, stored?.[entry.name]);
    this.buffer = {
      issuer: textAt(definition, ISSUER_FIELD) || issuer,
      ssl: textAt(definition, SSL_FIELD),
      credentials: textAt(definition, CREDENTIALS_FIELD),
      metadata,
    };
    this.opened = this.buffer;
    const count = definition['ClientCount'];
    this.clientCountValue = typeof count === 'number' ? count : 0;
    this.choiceValue = this.memberText(JWKS_MEMBER) !== '' ? 'url' : this.buffer.credentials !== '' ? 'x509' : 'none';
    this.heldValue = true;
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

  private publish(id: string, action: ChangeAction): void {
    if (id === '') return;
    this.injector.get(ChangeBus).publish({ kind: 'changed', type: OAUTH_SERVER_ENTITY, scope: OAUTH_SERVER_SCOPE, id, action, readBack: this.readBackValue });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

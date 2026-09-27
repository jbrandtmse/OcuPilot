import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` registers a client, `PUT <path>/<clientId>` edits one. */
export const OAUTH_REGISTERED_CLIENT_PATH = '/api/ocupilot/oauth/server-client';

/** The form read: the rules, the readable credentials, the algorithm lists and, with an id, the client. */
export const OAUTH_REGISTERED_CLIENT_FORM_PATH = `${OAUTH_REGISTERED_CLIENT_PATH}/form`;

/** The entity type and scope the changes this form publishes carry (AD-13, AD-14). */
export const OAUTH_REGISTERED_CLIENT_ENTITY = 'oauth2-server-client';

export const OAUTH_REGISTERED_CLIENT_SCOPE = 'instance';

/** The top-level fields, named as the server names them. */
export const NAME_FIELD = 'Name';
export const DESCRIPTION_FIELD = 'Description';
export const TYPE_FIELD = 'ClientType';
export const REDIRECT_FIELD = 'RedirectURL';
export const LAUNCH_FIELD = 'LaunchURL';
export const CREDENTIALS_FIELD = 'ClientCredentials';
export const SCOPE_FIELD = 'DefaultScope';
export const METADATA_FIELD = 'Metadata';
export const CLIENT_ID_FIELD = 'ClientId';

/** The one secret: written through its own write, never read back (AD-3, AD-35, AD-56). */
export const SECRET_FIELD = 'ClientSecret';

/** The metadata members the form draws a control for. */
export const GRANT_MEMBER = 'grant_types';
export const RESPONSE_MEMBER = 'response_types';
export const AUTH_MEMBER = 'token_endpoint_auth_method';
export const AUTH_SIGNING_MEMBER = 'token_endpoint_auth_signing_alg';
export const CLIENT_NAME_MEMBER = 'client_name';
export const CONTACTS_MEMBER = 'contacts';
export const MAX_AGE_MEMBER = 'default_max_age';
export const LOGOUT_MEMBER = 'frontchannel_logout_uri';
export const SESSION_MEMBER = 'frontchannel_logout_session_required';
export const JWKS_MEMBER = 'jwks_uri';

/** The display URLs on Client Information, in the classic page's order. */
export const URL_MEMBERS: readonly string[] = ['logo_uri', 'client_uri', 'policy_uri', 'tos_uri'];

/** The grant types, response types and authentication methods the classic page offers, in its order. */
export const GRANT_TYPES: readonly string[] = ['authorization_code', 'implicit', 'password', 'client_credentials', 'jwt_authorization'];
export const RESPONSE_TYPES: readonly string[] = ['code', 'id_token', 'id_token token', 'token'];
export const AUTH_METHODS: readonly string[] = ['none', 'client_secret_basic', 'client_secret_post', 'client_secret_jwt', 'private_key_jwt'];

/** The two authentication methods and the grant that sign a JWT, which the signing algorithm serves. */
export const JWT_AUTH_METHODS: readonly string[] = ['client_secret_jwt', 'private_key_jwt'];
export const JWT_GRANT = 'jwt_authorization';

/** The four algorithm groups, each its signing, content-encryption and key member, in the classic page's order. */
export const ALGORITHM_GROUPS: readonly (readonly string[])[] = [
  ['id_token_signed_response_alg', 'id_token_encrypted_response_enc', 'id_token_encrypted_response_alg'],
  ['userinfo_signed_response_alg', 'userinfo_encrypted_response_enc', 'userinfo_encrypted_response_alg'],
  ['access_token_signed_response_alg', 'access_token_encrypted_response_enc', 'access_token_encrypted_response_alg'],
  ['request_object_signing_alg', 'request_object_encryption_enc', 'request_object_encryption_alg'],
];

/** The three client types the instance stores, and the one with no redirect URL, grant or response type. */
export const CLIENT_TYPES: readonly string[] = ['confidential', 'public', 'resource'];
export const RESOURCE_TYPE = 'resource';

/** Where the client's public keys come from: nowhere, its JWKS URL, or its X.509 credentials. */
export type KeySource = 'none' | 'jwks' | 'x509';

/** The four tabs, named and ordered as the classic editor's. */
export const GENERAL_TAB = 'general';
export const CREDENTIALS_TAB = 'credentials';
export const INFORMATION_TAB = 'information';
export const JWT_TAB = 'jwt';

/** The field a refusal on metadata member `name` is reported under. */
export function memberField(name: string): string {
  return `${METADATA_FIELD}.${name}`;
}

/** Which tab each field is drawn on, in form order. `Metadata` itself is refused on Client Information. */
export const REGISTERED_CLIENT_FIELD_TABS: Readonly<Record<string, string>> = {
  [NAME_FIELD]: GENERAL_TAB,
  [DESCRIPTION_FIELD]: GENERAL_TAB,
  [TYPE_FIELD]: GENERAL_TAB,
  [REDIRECT_FIELD]: GENERAL_TAB,
  [memberField(GRANT_MEMBER)]: GENERAL_TAB,
  [memberField(RESPONSE_MEMBER)]: GENERAL_TAB,
  [memberField(AUTH_MEMBER)]: GENERAL_TAB,
  [memberField(AUTH_SIGNING_MEMBER)]: GENERAL_TAB,
  [CLIENT_ID_FIELD]: CREDENTIALS_TAB,
  [SECRET_FIELD]: CREDENTIALS_TAB,
  [LAUNCH_FIELD]: INFORMATION_TAB,
  [memberField(CLIENT_NAME_MEMBER)]: INFORMATION_TAB,
  ...Object.fromEntries(URL_MEMBERS.map((member) => [memberField(member), INFORMATION_TAB])),
  [memberField(CONTACTS_MEMBER)]: INFORMATION_TAB,
  [memberField(MAX_AGE_MEMBER)]: INFORMATION_TAB,
  [SCOPE_FIELD]: INFORMATION_TAB,
  [memberField(LOGOUT_MEMBER)]: INFORMATION_TAB,
  [memberField(SESSION_MEMBER)]: INFORMATION_TAB,
  [METADATA_FIELD]: INFORMATION_TAB,
  [memberField(JWKS_MEMBER)]: JWT_TAB,
  [CREDENTIALS_FIELD]: JWT_TAB,
  ...Object.fromEntries(ALGORITHM_GROUPS.flat().map((member) => [memberField(member), JWT_TAB])),
};

/** Every field in form order, which is also the order a refused Save's tab is chosen by. */
export const REGISTERED_CLIENT_FIELD_ORDER: readonly string[] = Object.keys(REGISTERED_CLIENT_FIELD_TABS);

/** How a member is shaped on the wire. */
type MemberKind = 'text' | 'list' | 'integer' | 'flag';

/** Every member the form edits, with its kind: the only members a Save sends. */
const MEMBER_KINDS: Readonly<Record<string, MemberKind>> = {
  [GRANT_MEMBER]: 'list',
  [RESPONSE_MEMBER]: 'list',
  [AUTH_MEMBER]: 'text',
  [AUTH_SIGNING_MEMBER]: 'text',
  [CLIENT_NAME_MEMBER]: 'text',
  ...Object.fromEntries(URL_MEMBERS.map((member) => [member, 'text'])),
  [CONTACTS_MEMBER]: 'list',
  [MAX_AGE_MEMBER]: 'integer',
  [LOGOUT_MEMBER]: 'text',
  [SESSION_MEMBER]: 'flag',
  [JWKS_MEMBER]: 'text',
  ...Object.fromEntries(ALGORITHM_GROUPS.flat().map((member) => [member, 'text'])),
};

/** A member's value in the form: text (an integer's digits), a list, or a flag. */
export type MemberValue = string | readonly string[] | boolean;

/** What the form is doing: registering a client, or editing the one its route names. */
export type FormMode = 'create' | 'edit';

export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** The fields the form edits. */
interface Held {
  readonly name: string;
  readonly description: string;
  readonly clientType: string;
  readonly launchUrl: string;
  readonly credentials: string;
  readonly scope: string;
  readonly redirects: readonly string[];
  readonly keySource: KeySource;
  readonly metadata: Readonly<Record<string, MemberValue>>;
}

/** The text fields, by their store key. */
export type TextKey = 'name' | 'description' | 'clientType' | 'launchUrl' | 'credentials' | 'scope';

const TEXT_FIELDS: Readonly<Record<TextKey, string>> = {
  name: NAME_FIELD,
  description: DESCRIPTION_FIELD,
  clientType: TYPE_FIELD,
  launchUrl: LAUNCH_FIELD,
  credentials: CREDENTIALS_FIELD,
  scope: SCOPE_FIELD,
};

const EMPTY_HELD: Held = {
  name: '',
  description: '',
  clientType: 'confidential',
  launchUrl: '',
  credentials: '',
  scope: '',
  redirects: [],
  keySource: 'none',
  metadata: {},
};

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

function emptyOf(kind: MemberKind): MemberValue {
  if (kind === 'list') return [];
  if (kind === 'flag') return false;
  return '';
}

/** A member's value read off the wire, in its kind's shape. */
function memberOf(kind: MemberKind, value: unknown): MemberValue {
  if (kind === 'list') return stringsOf(value);
  if (kind === 'flag') return value === true || value === 1;
  if (typeof value === 'number') return String(value);
  return typeof value === 'string' ? value : '';
}

/** A member's value as the wire takes it: an integer's digits as a number. */
function wireOf(kind: MemberKind, value: MemberValue): unknown {
  if (kind === 'integer' && typeof value === 'string' && /^[0-9]+$/.test(value)) return Number(value);
  return value;
}

function same(left: unknown, right: unknown): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

/** The key source a stored client is read as: its JWKS URL first, then its X.509 credentials. */
function sourceOf(jwksUri: string, credentials: string): KeySource {
  if (jwksUri !== '') return 'jwks';
  return credentials !== '' ? 'x509' : 'none';
}

/** The redirect URLs a Save sends: the rows as edited, less the empty ones. */
function sentRedirects(rows: readonly string[]): string[] {
  return rows.filter((entry) => entry.trim() !== '');
}

/**
 * A new client secret: 48 random bytes from the browser's own generator, base64url-encoded with no
 * padding. It originates in the field the user holds and is never shown anywhere else (AD-35).
 */
export function generateSecret(): string {
  const bytes = new Uint8Array(48);
  globalThis.crypto.getRandomValues(bytes);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/**
 * The OAuth 2.0 server client description editor's store (AD-19, AD-55): a create on
 * `security/oauth/server-clients/edit`, an edit of the client its route names on
 * `security/oauth/server-clients/edit/<clientId>`.
 *
 * **It composes no payload of its own.** `POST /oauth/server-client` and
 * `PUT /oauth/server-client/<clientId>` resolve the tool classes the agent's
 * `security.oauthserverclients.*` do; the server sends the complete set over a fresh read (AD-4), and
 * every field sentence is the server's (AD-39). A new client starts from the form read's defaults.
 *
 * **An edit sends only what changed since its fresh read**: the fields that changed, the redirect URLs
 * whole, and under `Metadata` the members that changed.
 *
 * **The client secret is held in this store alone, until Save** (AD-35): never pre-filled, and sent
 * only when typed.
 */
@Injectable({ providedIn: 'root' })
export class OAuthRegisteredClientForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Held = EMPTY_HELD;

  private opened: Held = EMPTY_HELD;

  private clientIdValue = '';

  private secretValue = '';

  private credentialNames: readonly string[] = [];

  private algorithmLists: Readonly<Record<string, readonly string[]>> = {};

  private rulesValue: readonly FieldRule[] = [];

  private requiredValue: readonly string[] = [];

  private loadedValue = false;

  private heldValue = false;

  private absentValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private savedValue = false;
  /** The instance's read-back of the last accepted Save (AD-58), or `null`. */
  private readBackValue: ReadBack | null = null;

  private secretRefusedValue = '';

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
    return this.savingValue;
  }

  /** Whether an edit names a client the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** Whether an edit's fresh read is held, which is what the row actions act on. */
  held(): boolean {
    return this.heldValue;
  }

  text(key: TextKey): string {
    return this.buffer[key];
  }

  redirects(): readonly string[] {
    return this.buffer.redirects;
  }

  keySource(): KeySource {
    return this.buffer.keySource;
  }

  /** A member's value now, in its kind's shape. */
  member(name: string): MemberValue {
    return this.buffer.metadata[name] ?? emptyOf(MEMBER_KINDS[name] ?? 'text');
  }

  memberText(name: string): string {
    const value = this.member(name);
    return typeof value === 'string' ? value : '';
  }

  memberList(name: string): readonly string[] {
    const value = this.member(name);
    return Array.isArray(value) ? (value as readonly string[]) : [];
  }

  memberFlag(name: string): boolean {
    return this.member(name) === true;
  }

  /** The client id the instance generated: the id every write and row action names. */
  storedClientId(): string {
    return this.clientIdValue;
  }

  /** The JWKS URL the fresh read answered, which Update JWKS fetches from. */
  storedJwksUri(): string {
    const value = this.opened.metadata[JWKS_MEMBER];
    return typeof value === 'string' ? value : '';
  }

  /** The secret as typed, `''` until it is (AD-35). */
  secret(): string {
    return this.secretValue;
  }

  /** The X.509 credential aliases the caller can read (AD-5). */
  credentialAliases(): readonly string[] {
    return this.credentialNames;
  }

  /** Algorithm member `name`'s vendor value list. */
  algorithms(name: string): readonly string[] {
    return this.algorithmLists[name] ?? [];
  }

  editable(): boolean {
    return (this.modeValue === 'create' || this.heldValue) && !this.busy();
  }

  canSave(): boolean {
    if (this.busy() || this.absentValue) return false;
    return this.modeValue === 'create' || this.heldValue;
  }

  /**
   * Whether `field` is required now: the redirect URLs, grant and response types only for a client
   * that is not a resource server, and the secret only on a create of one that is not public.
   */
  required(field: string): boolean {
    if (!this.requiredValue.includes(field)) return false;
    const resource = this.buffer.clientType === RESOURCE_TYPE;
    if (resource && (field === REDIRECT_FIELD || field === memberField(GRANT_MEMBER) || field === memberField(RESPONSE_MEMBER))) return false;
    if (field === SECRET_FIELD) return this.modeValue === 'create' && this.buffer.clientType !== 'public';
    return true;
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

  /** The sentence the secret write was refused with after the save, or `''`. */
  secretRefused(): string {
    return this.secretRefusedValue;
  }

  /** The client id the last accepted Save answered, or `''`. */
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
    this.clientIdValue = '';
    this.secretValue = '';
    this.credentialNames = [];
    this.algorithmLists = {};
    this.rulesValue = [];
    this.requiredValue = [];
    this.loadedValue = false;
    this.heldValue = false;
    this.absentValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.secretRefusedValue = '';
    this.savedIdValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form: a create when `id` is empty, an edit of that client otherwise. An arrival that is
   * a Save's own re-read keeps the saved confirmation on screen.
   */
  async open(id: string): Promise<void> {
    const arriving = this.retainingValue && id !== '' && id === this.savedIdValue;
    const refused = arriving ? this.secretRefusedValue : '';
    this.reset();
    if (arriving) {
      this.savedValue = true;
      this.secretRefusedValue = refused;
    }
    this.modeValue = id === '' ? 'create' : 'edit';
    const generation = this.generation;
    const path = id === '' ? OAUTH_REGISTERED_CLIENT_FORM_PATH : `${OAUTH_REGISTERED_CLIENT_FORM_PATH}?clientId=${encodeURIComponent(id)}`;
    const result = await this.api().requestJson<unknown>(path);
    if (generation !== this.generation) return;
    this.absorb(result, id);
    this.loadedValue = true;
    this.notify();
  }

  /** Set a text field. The name stays editable: the client is known by its id. */
  setText(key: TextKey, value: string): void {
    if (!this.editable() || this.buffer[key] === value) return;
    this.buffer = { ...this.buffer, [key]: value };
    this.change(TEXT_FIELDS[key]);
  }

  setSecret(value: string): void {
    if (!this.editable() || this.secretValue === value) return;
    this.secretValue = value;
    this.change(SECRET_FIELD);
  }

  setRedirect(index: number, value: string): void {
    const rows = this.buffer.redirects;
    if (!this.editable() || index < 0 || index >= rows.length || rows[index] === value) return;
    this.buffer = { ...this.buffer, redirects: rows.map((entry, at) => (at === index ? value : entry)) };
    this.change(REDIRECT_FIELD);
  }

  addRedirect(): void {
    if (!this.editable()) return;
    this.buffer = { ...this.buffer, redirects: [...this.buffer.redirects, ''] };
    this.change(REDIRECT_FIELD);
  }

  removeRedirect(index: number): void {
    if (!this.editable() || index < 0 || index >= this.buffer.redirects.length) return;
    this.buffer = { ...this.buffer, redirects: this.buffer.redirects.filter((_, at) => at !== index) };
    this.change(REDIRECT_FIELD);
  }

  /** Set a text or integer member. */
  setMemberText(name: string, value: string): void {
    const kind = MEMBER_KINDS[name];
    if (!this.editable() || (kind !== 'text' && kind !== 'integer') || this.memberText(name) === value) return;
    this.setMember(name, value);
  }

  /** Set a list member from comma-separated text; blanks are dropped. */
  setMemberCsv(name: string, text: string): void {
    if (!this.editable() || MEMBER_KINDS[name] !== 'list') return;
    const values = text
      .split(',')
      .map((entry) => entry.trim())
      .filter((entry) => entry !== '');
    if (same(values, this.member(name))) return;
    this.setMember(name, values);
  }

  setMemberFlag(name: string, value: boolean): void {
    if (!this.editable() || MEMBER_KINDS[name] !== 'flag' || this.memberFlag(name) === value) return;
    this.setMember(name, value);
  }

  /** Add or remove one value of a list member, keeping every other value it holds. */
  setChoice(name: string, value: string, on: boolean): void {
    if (!this.editable() || MEMBER_KINDS[name] !== 'list') return;
    const current = this.memberList(name);
    if (current.includes(value) === on) return;
    this.setMember(name, on ? [...current, value] : current.filter((entry) => entry !== value));
  }

  /**
   * Choose where the client's public keys come from. A JWKS URL clears the X.509 credentials, X.509
   * credentials clear the JWKS URL, and None clears both.
   */
  setKeySource(source: KeySource): void {
    if (!this.editable() || this.buffer.keySource === source) return;
    const metadata = source === 'jwks' ? this.buffer.metadata : { ...this.buffer.metadata, [JWKS_MEMBER]: '' };
    const credentials = source === 'x509' ? this.buffer.credentials : '';
    this.buffer = { ...this.buffer, keySource: source, credentials, metadata };
    this.change(memberField(JWKS_MEMBER));
    this.change(CREDENTIALS_FIELD);
  }

  /**
   * On blur: render the server's required-field sentence on an empty required text field of a create,
   * as the form read's first rule for it words it.
   */
  onBlur(field: string): void {
    if (this.modeValue !== 'create' || !this.required(field)) return;
    const key = (Object.keys(TEXT_FIELDS) as TextKey[]).find((entry) => TEXT_FIELDS[entry] === field);
    if (key === undefined || this.buffer[key].trim() !== '') return;
    const rule = this.rulesValue.find((entry) => entry.field === field);
    if (rule === undefined || this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /**
   * Save: a create posts every field; an edit puts what changed since its fresh read. The typed secret
   * travels beside them and is stored after the client is (AD-56); the store forgets it either way. An
   * accepted Save publishes one change event under the client id (AD-14).
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const creating = this.modeValue === 'create';
    const body = creating ? this.createBody() : this.changedBody();
    if (!creating && Object.keys(body).length === 0 && this.secretValue === '') {
      this.clearRefusal();
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    if (this.secretValue !== '') body[SECRET_FIELD] = this.secretValue;
    const generation = this.generation;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.readBackValue = null;
    this.secretRefusedValue = '';
    this.notify();
    const result = creating
      ? await this.api().requestJson<unknown>(OAUTH_REGISTERED_CLIENT_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        })
      : await this.api().requestJson<unknown>(`${OAUTH_REGISTERED_CLIENT_PATH}/${encodeEntityId(this.clientIdValue)}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        });
    delete body[SECRET_FIELD];
    if (generation !== this.generation) return false;
    this.savingValue = false;
    this.secretValue = '';
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.notify();
      return false;
    }
    const id = textAt(result.body, 'clientId') || this.clientIdValue;
    this.savedIdValue = id;
    this.secretRefusedValue = textAt(result.body, 'secretRefused');
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

  private setMember(name: string, value: MemberValue): void {
    this.buffer = { ...this.buffer, metadata: { ...this.buffer.metadata, [name]: value } };
    this.change(memberField(name));
  }

  private change(field: string): void {
    if (this.violationList.some((entry) => entry.field === field)) {
      this.violationList = this.violationList.filter((entry) => entry.field !== field);
    }
    this.savedValue = false;
    this.secretRefusedValue = '';
    this.formDirty.setDirty(true);
    this.notify();
  }

  /** The members the form edits, as the wire takes them. */
  private metadataWire(only: (name: string) => boolean): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const [name, kind] of Object.entries(MEMBER_KINDS)) {
      if (only(name)) out[name] = wireOf(kind, this.member(name));
    }
    return out;
  }

  /** A create's body: every field and every member the form edits (AD-54). */
  private createBody(): Record<string, unknown> {
    return {
      [NAME_FIELD]: this.buffer.name,
      [DESCRIPTION_FIELD]: this.buffer.description,
      [TYPE_FIELD]: this.buffer.clientType,
      [REDIRECT_FIELD]: sentRedirects(this.buffer.redirects),
      [LAUNCH_FIELD]: this.buffer.launchUrl,
      [CREDENTIALS_FIELD]: this.buffer.credentials,
      [SCOPE_FIELD]: this.buffer.scope,
      [METADATA_FIELD]: this.metadataWire(() => true),
    };
  }

  /** An edit's body: the fields and members changed since the fresh read; the redirect URLs whole. */
  private changedBody(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(TEXT_FIELDS) as TextKey[]) {
      if (this.buffer[key] !== this.opened[key]) out[TEXT_FIELDS[key]] = this.buffer[key];
    }
    const redirects = sentRedirects(this.buffer.redirects);
    if (!same(redirects, sentRedirects(this.opened.redirects))) out[REDIRECT_FIELD] = redirects;
    const metadata = this.metadataWire((name) => !same(this.member(name), this.opened.metadata[name] ?? emptyOf(MEMBER_KINDS[name] ?? 'text')));
    if (Object.keys(metadata).length > 0) out[METADATA_FIELD] = metadata;
    return out;
  }

  /** The fields a client source (the form read's defaults, or the client itself) holds. */
  private heldFrom(source: Record<string, unknown> | null): Held {
    const stored = record(source?.[METADATA_FIELD]);
    const metadata: Record<string, MemberValue> = {};
    for (const [name, kind] of Object.entries(MEMBER_KINDS)) metadata[name] = memberOf(kind, stored?.[name]);
    const credentials = textAt(source, CREDENTIALS_FIELD);
    const jwks = metadata[JWKS_MEMBER];
    return {
      name: textAt(source, NAME_FIELD),
      description: textAt(source, DESCRIPTION_FIELD),
      clientType: textAt(source, TYPE_FIELD) || EMPTY_HELD.clientType,
      launchUrl: textAt(source, LAUNCH_FIELD),
      credentials,
      scope: textAt(source, SCOPE_FIELD),
      redirects: stringsOf(source?.[REDIRECT_FIELD]),
      keySource: sourceOf(typeof jwks === 'string' ? jwks : '', credentials),
      metadata,
    };
  }

  private absorb(result: JsonResult<unknown>, id: string): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      if (id !== '' && result.kind === 'error' && result.status === 404) this.absentValue = true;
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
    this.credentialNames = stringsOf(body?.['credentials']);
    const lists: Record<string, readonly string[]> = {};
    for (const [name, values] of Object.entries(record(body?.['algorithms']) ?? {})) lists[name] = stringsOf(values);
    this.algorithmLists = lists;
    if (id === '') {
      this.buffer = this.heldFrom(record(body?.['defaults']));
      this.opened = this.buffer;
      return;
    }
    const definition = record(body?.['definition']);
    if (definition === null) {
      this.absentValue = true;
      return;
    }
    this.buffer = this.heldFrom(definition);
    this.opened = this.buffer;
    this.clientIdValue = textAt(body, 'clientId') || textAt(definition, CLIENT_ID_FIELD) || id;
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
    this.injector.get(ChangeBus).publish({ kind: 'changed', type: OAUTH_REGISTERED_CLIENT_ENTITY, scope: OAUTH_REGISTERED_CLIENT_SCOPE, id, action, readBack: this.readBackValue });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

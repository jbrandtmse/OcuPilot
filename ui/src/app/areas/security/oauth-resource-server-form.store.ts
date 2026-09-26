import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` creates, `PUT <path>/<id>` edits. */
export const OAUTH_RESOURCE_SERVER_PATH = '/api/ocupilot/oauth/resource-server';

/** The form read: the rules, the readable names, the authenticators, the held mappings and, with a name, the server. */
export const OAUTH_RESOURCE_SERVER_FORM_PATH = `${OAUTH_RESOURCE_SERVER_PATH}/form`;

/** The entity type and scope the changes this form publishes carry (AD-13, AD-14). */
export const OAUTH_RESOURCE_SERVER_ENTITY = 'oauth2-resource-server';

export const OAUTH_RESOURCE_SERVER_SCOPE = 'instance';

/** The fields, named as the server names them. */
export const NAME_FIELD = 'Name';
export const DESCRIPTION_FIELD = 'Description';
export const ENABLED_FIELD = 'Enabled';
export const ISSUER_FIELD = 'IssuerEndpoint';
export const AUDIENCES_FIELD = 'Audiences';
export const SCOPE_FIELD = 'ScopeRequiredToConnect';
export const JWT_FIELD = 'AccessTokenIsJWT';
export const INTROSPECTION_FIELD = 'AlwaysCallIntrospection';
export const OIDC_FIELD = 'UseOIDC';
export const CLIENT_ID_FIELD = 'ClientId';
export const METHOD_FIELD = 'IntrospectionAuthMethod';
export const AUTHENTICATOR_FIELD = 'Authenticator';
export const NAMESPACE_MEMBER = 'Namespace';
export const IMPLEMENTATION_MEMBER = 'Implementation';

/** The one secret: written through its own write, never read back (AD-3, AD-35, AD-56). */
export const SECRET_FIELD = 'ClientSecret';

/** The field a mapping row's refusal names, and its two members. */
export const MAPPINGS_FIELD = 'Mappings';

/** The two mapping services, the key that maps every one of a service, and the class's default authenticator. */
export const GATEWAY_SERVICE = '%Service_WebGateway';
export const BINDINGS_SERVICE = '%Service_Bindings';
export const DEFAULT_KEY = '*';
export const DEFAULT_NAMESPACE = '%SYS';
export const DEFAULT_IMPLEMENTATION = '%OAuth2.ResourceServer.SimpleAuthenticator';

/** The introspection methods the instance stores, in the classic page's order. */
export const METHODS: readonly string[] = ['client_secret_basic', 'client_secret_post', 'none'];

/** The four tabs, in the classic page's field-set order. */
export const GENERAL_TAB = 'general';
export const TOKEN_TAB = 'token';
export const AUTHENTICATOR_TAB = 'authenticator';
export const MAPPINGS_TAB = 'mappings';

/** Which tab each fixed field is drawn on; an authenticator setting's field is the authenticator tab's. */
export const RESOURCE_SERVER_FIELD_TABS: Readonly<Record<string, string>> = {
  [NAME_FIELD]: GENERAL_TAB,
  [DESCRIPTION_FIELD]: GENERAL_TAB,
  [ENABLED_FIELD]: GENERAL_TAB,
  [ISSUER_FIELD]: GENERAL_TAB,
  [AUDIENCES_FIELD]: GENERAL_TAB,
  [SCOPE_FIELD]: GENERAL_TAB,
  [JWT_FIELD]: TOKEN_TAB,
  [INTROSPECTION_FIELD]: TOKEN_TAB,
  [OIDC_FIELD]: TOKEN_TAB,
  [CLIENT_ID_FIELD]: TOKEN_TAB,
  [SECRET_FIELD]: TOKEN_TAB,
  [METHOD_FIELD]: TOKEN_TAB,
  [AUTHENTICATOR_FIELD]: AUTHENTICATOR_TAB,
  [`${AUTHENTICATOR_FIELD}.${NAMESPACE_MEMBER}`]: AUTHENTICATOR_TAB,
  [`${AUTHENTICATOR_FIELD}.${IMPLEMENTATION_MEMBER}`]: AUTHENTICATOR_TAB,
  [MAPPINGS_FIELD]: MAPPINGS_TAB,
  [`${MAPPINGS_FIELD}.Service`]: MAPPINGS_TAB,
  [`${MAPPINGS_FIELD}.Key`]: MAPPINGS_TAB,
};

/** Every fixed field in form order, which is also the order a refused Save's tab is chosen by. */
export const RESOURCE_SERVER_FIELD_ORDER: readonly string[] = Object.keys(RESOURCE_SERVER_FIELD_TABS);

/** The field a refusal on authenticator setting `name` is reported under. */
export function settingField(name: string): string {
  return `${AUTHENTICATOR_FIELD}.${name}`;
}

/** The one name a mapping is known by: its service, a slash, and its key lower-cased, as the instance stores it. */
export function mappingName(service: string, key: string): string {
  return `${service}/${key.toLowerCase()}`;
}

/** The service and key of mapping `name`. */
export function mappingParts(name: string): { readonly service: string; readonly key: string } {
  const slash = name.indexOf('/');
  return slash === -1 ? { service: name, key: '' } : { service: name.slice(0, slash), key: name.slice(slash + 1) };
}

/** What the form is doing: creating a server, or editing the one its route names. */
export type FormMode = 'create' | 'edit';

/** How an authenticator setting is shaped, as its class describes it. */
export type SettingKind = 'boolean' | 'integer' | 'double' | 'string' | 'object';

export interface AuthenticatorSetting {
  readonly name: string;
  readonly kind: SettingKind;
}

export interface AuthenticatorClass {
  readonly implementation: string;
  readonly settings: readonly AuthenticatorSetting[];
}

/** A setting's value in the form: a flag, or text (a number's digits, an object's JSON). */
export type SettingValue = string | boolean;

export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** The fields the form edits. */
interface Held {
  readonly name: string;
  readonly description: string;
  readonly enabled: boolean;
  readonly issuer: string;
  readonly audiences: readonly string[];
  readonly scope: string;
  readonly jwt: boolean;
  readonly introspection: boolean;
  readonly oidc: boolean;
  readonly clientId: string;
  readonly method: string;
  readonly namespace: string;
  readonly implementation: string;
  readonly settings: Readonly<Record<string, SettingValue>>;
}

/** The text fields, by their store key. */
export type TextKey = 'name' | 'description' | 'issuer' | 'scope' | 'clientId' | 'method';

/** The flags, by their store key. */
export type FlagKey = 'enabled' | 'jwt' | 'introspection' | 'oidc';

const TEXT_FIELDS: Readonly<Record<TextKey, string>> = {
  name: NAME_FIELD,
  description: DESCRIPTION_FIELD,
  issuer: ISSUER_FIELD,
  scope: SCOPE_FIELD,
  clientId: CLIENT_ID_FIELD,
  method: METHOD_FIELD,
};

const FLAG_FIELDS: Readonly<Record<FlagKey, string>> = {
  enabled: ENABLED_FIELD,
  jwt: JWT_FIELD,
  introspection: INTROSPECTION_FIELD,
  oidc: OIDC_FIELD,
};

const EMPTY_HELD: Held = {
  name: '',
  description: '',
  enabled: true,
  issuer: '',
  audiences: [],
  scope: '',
  jwt: true,
  introspection: false,
  oidc: false,
  clientId: '',
  method: 'none',
  namespace: DEFAULT_NAMESPACE,
  implementation: DEFAULT_IMPLEMENTATION,
  settings: {},
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

function kindOf(value: string): SettingKind {
  return value === 'boolean' || value === 'integer' || value === 'double' || value === 'object' ? value : 'string';
}

/** A setting's value read off the wire, in its kind's shape. */
function settingOf(kind: SettingKind, value: unknown): SettingValue {
  if (kind === 'boolean') return value === true;
  if (kind === 'object') return value === undefined || value === null ? '' : JSON.stringify(value);
  if (typeof value === 'number') return String(value);
  return typeof value === 'string' ? value : '';
}

function same(left: unknown, right: unknown): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

/**
 * The OAuth 2.0 resource server editor's store (AD-19, AD-55): a create on
 * `security/oauth/resource-servers/edit`, an edit of the server its route names on
 * `security/oauth/resource-servers/edit/<name>`.
 *
 * **It composes no payload of its own.** `POST /oauth/resource-server` and
 * `PUT /oauth/resource-server/<id>` resolve the tool classes the agent's
 * `security.oauthresourceservers.*` do; the server fills the authenticator settings an edit leaves
 * out and sends the complete set (AD-4), and every field sentence is the server's (AD-39).
 *
 * **An edit sends only what changed since its fresh read**; the authenticator, when any of it
 * changed, goes whole, and the audiences go whole. Service mappings travel as the rows added and
 * removed since the fresh read (AD-56 (ii)).
 *
 * **The client secret is held in this store alone, until Save** (AD-35): never pre-filled, and sent
 * only when typed.
 */
@Injectable({ providedIn: 'root' })
export class OAuthResourceServerForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Held = EMPTY_HELD;

  private opened: Held = EMPTY_HELD;

  private secretValue = '';

  private mappingsValue: readonly string[] = [];

  private openedMappings: readonly string[] = [];

  private heldBy: Readonly<Record<string, string>> = {};

  private issuersValue: readonly string[] = [];

  private webAppsValue: readonly string[] = [];

  private namespacesValue: readonly string[] = [];

  private authenticatorsValue: readonly AuthenticatorClass[] = [];

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

  private mappingsRefusedCount = 0;

  private mappingsRefusedReason = '';

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

  /** Whether an edit names a server the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** Whether an edit's fresh read is held, which is what Delete acts on. */
  held(): boolean {
    return this.heldValue;
  }

  text(key: TextKey): string {
    return this.buffer[key];
  }

  flag(key: FlagKey): boolean {
    return this.buffer[key];
  }

  audiences(): readonly string[] {
    return this.buffer.audiences;
  }

  namespace(): string {
    return this.buffer.namespace;
  }

  implementation(): string {
    return this.buffer.implementation;
  }

  /** The name the fresh read answered: the server Delete names. */
  storedName(): string {
    return this.opened.name;
  }

  /** The secret as typed, `''` until it is (AD-35). */
  secret(): string {
    return this.secretValue;
  }

  /** The settings the chosen class describes, less the credential-named ones (the server removes those). */
  settings(): readonly AuthenticatorSetting[] {
    return this.authenticatorsValue.find((entry) => entry.implementation === this.buffer.implementation)?.settings ?? [];
  }

  setting(name: string): SettingValue {
    const value = this.buffer.settings[name];
    if (value !== undefined) return value;
    return this.settings().find((entry) => entry.name === name)?.kind === 'boolean' ? false : '';
  }

  /** The classes the chosen namespace offers. */
  implementations(): readonly string[] {
    return this.authenticatorsValue.map((entry) => entry.implementation);
  }

  issuers(): readonly string[] {
    return this.issuersValue;
  }

  webApplications(): readonly string[] {
    return this.webAppsValue;
  }

  namespaces(): readonly string[] {
    return this.namespacesValue;
  }

  /** The server's mappings as the Save will leave them, as `<service>/<key>`. */
  mappings(): readonly string[] {
    return this.mappingsValue;
  }

  /** Whether mapping `name` is one this Save adds, not yet stored. */
  unsaved(name: string): boolean {
    return !this.openedMappings.includes(name);
  }

  /** The server that holds mapping `name` now, other than this one, or `''`. */
  holderOf(name: string): string {
    const holder = this.heldBy[name] ?? '';
    return holder === this.buffer.name || holder === this.opened.name ? '' : holder;
  }

  editable(): boolean {
    return (this.modeValue === 'create' || this.heldValue) && !this.busy();
  }

  canSave(): boolean {
    if (this.busy() || this.absentValue) return false;
    return this.modeValue === 'create' || this.heldValue;
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

  /** The sentence the secret write was refused with after the save, or `''`. */
  secretRefused(): string {
    return this.secretRefusedValue;
  }

  /** How many mapping writes were refused after the save, and the first refusal's sentence. */
  mappingsRefused(): { readonly count: number; readonly reason: string } {
    return { count: this.mappingsRefusedCount, reason: this.mappingsRefusedReason };
  }

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
    this.secretValue = '';
    this.mappingsValue = [];
    this.openedMappings = [];
    this.heldBy = {};
    this.issuersValue = [];
    this.webAppsValue = [];
    this.namespacesValue = [];
    this.authenticatorsValue = [];
    this.rulesValue = [];
    this.requiredValue = [];
    this.loadedValue = false;
    this.heldValue = false;
    this.absentValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.clearOutcome();
    this.savedIdValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form: a create when `name` is empty, an edit of that server otherwise. An arrival that
   * is a Save's own re-read keeps the saved confirmation on screen. A create on an instance with no
   * resource server starts with the two default mappings as unsaved rows, as the classic page makes
   * them for the first server.
   */
  async open(name: string): Promise<void> {
    const arriving = this.retainingValue && name !== '' && name === this.savedIdValue;
    const outcome = arriving ? { secret: this.secretRefusedValue, count: this.mappingsRefusedCount, reason: this.mappingsRefusedReason } : null;
    this.reset();
    if (outcome !== null) {
      this.savedValue = true;
      this.secretRefusedValue = outcome.secret;
      this.mappingsRefusedCount = outcome.count;
      this.mappingsRefusedReason = outcome.reason;
    }
    this.modeValue = name === '' ? 'create' : 'edit';
    const generation = this.generation;
    const path = name === '' ? OAUTH_RESOURCE_SERVER_FORM_PATH : `${OAUTH_RESOURCE_SERVER_FORM_PATH}?name=${encodeURIComponent(name)}`;
    const result = await this.api().requestJson<unknown>(path);
    if (generation !== this.generation) return;
    this.absorb(result, name);
    this.loadedValue = true;
    this.notify();
  }

  setText(key: TextKey, value: string): void {
    if (!this.editable() || this.buffer[key] === value) return;
    if (key === 'name' && this.modeValue === 'edit') return;
    this.buffer = { ...this.buffer, [key]: value };
    this.change(TEXT_FIELDS[key]);
  }

  /**
   * Set a flag. Turning JWT off turns Call introspection on, and turning it on turns that off, as
   * the classic page does: a token that is not a JWT can only be introspected.
   */
  setFlag(key: FlagKey, value: boolean): void {
    if (!this.editable() || this.buffer[key] === value) return;
    if (key === 'introspection' && !this.buffer.jwt) return;
    this.buffer = key === 'jwt' ? { ...this.buffer, jwt: value, introspection: !value } : { ...this.buffer, [key]: value };
    this.change(FLAG_FIELDS[key]);
  }

  setSecret(value: string): void {
    if (!this.editable() || this.secretValue === value) return;
    this.secretValue = value;
    this.change(SECRET_FIELD);
  }

  setAudience(index: number, value: string): void {
    if (!this.editable() || index < 0 || index >= this.buffer.audiences.length || this.buffer.audiences[index] === value) return;
    this.buffer = { ...this.buffer, audiences: this.buffer.audiences.map((entry, at) => (at === index ? value : entry)) };
    this.change(AUDIENCES_FIELD);
  }

  addAudience(): void {
    if (!this.editable()) return;
    this.buffer = { ...this.buffer, audiences: [...this.buffer.audiences, ''] };
    this.change(AUDIENCES_FIELD);
  }

  removeAudience(index: number): void {
    if (!this.editable() || index < 0 || index >= this.buffer.audiences.length) return;
    this.buffer = { ...this.buffer, audiences: this.buffer.audiences.filter((_, at) => at !== index) };
    this.change(AUDIENCES_FIELD);
  }

  /**
   * Choose the authenticator's namespace: its classes are read, and the class moves to the default
   * when that namespace offers it, or to its first; a new class starts from its own defaults.
   */
  async setNamespace(namespace: string): Promise<void> {
    if (!this.editable() || this.buffer.namespace === namespace) return;
    this.buffer = { ...this.buffer, namespace };
    this.change(`${AUTHENTICATOR_FIELD}.${NAMESPACE_MEMBER}`);
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${OAUTH_RESOURCE_SERVER_FORM_PATH}?namespace=${encodeURIComponent(namespace)}`);
    if (generation !== this.generation || this.buffer.namespace !== namespace) return;
    if (result.kind === 'ok') this.authenticatorsValue = this.classesOf(record(result.body)?.['authenticators']);
    const offered = this.implementations();
    const implementation = offered.includes(this.buffer.implementation) ? this.buffer.implementation : offered.includes(DEFAULT_IMPLEMENTATION) ? DEFAULT_IMPLEMENTATION : (offered[0] ?? '');
    this.buffer = { ...this.buffer, implementation, settings: implementation === this.buffer.implementation ? this.buffer.settings : {} };
    this.notify();
  }

  setImplementation(implementation: string): void {
    if (!this.editable() || this.buffer.implementation === implementation) return;
    this.buffer = { ...this.buffer, implementation, settings: {} };
    this.change(`${AUTHENTICATOR_FIELD}.${IMPLEMENTATION_MEMBER}`);
  }

  setSetting(name: string, value: SettingValue): void {
    if (!this.editable() || same(this.setting(name), value)) return;
    this.buffer = { ...this.buffer, settings: { ...this.buffer.settings, [name]: value } };
    this.change(settingField(name));
  }

  /** Add the mapping of `service` and `key`, unless the server already holds it. */
  addMapping(service: string, key: string): void {
    if (!this.editable() || key === '') return;
    const name = mappingName(service, key);
    if (this.mappingsValue.includes(name)) return;
    this.mappingsValue = [...this.mappingsValue, name];
    this.change(MAPPINGS_FIELD);
  }

  removeMapping(name: string): void {
    if (!this.editable() || !this.mappingsValue.includes(name)) return;
    this.mappingsValue = this.mappingsValue.filter((entry) => entry !== name);
    this.change(MAPPINGS_FIELD);
  }

  /**
   * On blur: render the server's required-field sentence on an empty required field of a create, as
   * the form read's first rule for it words it.
   */
  onBlur(field: string): void {
    if (this.modeValue !== 'create' || !this.required(field)) return;
    const key = (Object.keys(TEXT_FIELDS) as TextKey[]).find((entry) => TEXT_FIELDS[entry] === field);
    if (key === undefined || this.buffer[key].trim() !== '') return;
    this.addRule(field);
  }

  /**
   * Save: a create posts every field; an edit puts what changed since its fresh read. The typed
   * secret and the mapping rows travel beside them and are written after the server is (AD-56); the
   * store forgets the secret either way. An accepted Save publishes one change event (AD-14) and
   * reads the server again, so every tab shows what the instance holds.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const creating = this.modeValue === 'create';
    const settings = this.settingsWire();
    if (settings === null) {
      this.notify();
      return false;
    }
    const body = creating ? this.createBody(settings) : this.changedBody(settings);
    const added = this.mappingsValue.filter((entry) => !this.openedMappings.includes(entry)).map(mappingParts);
    const removed = this.openedMappings.filter((entry) => !this.mappingsValue.includes(entry)).map(mappingParts);
    if (added.length > 0) body['mappingsAdded'] = added.map((entry) => ({ Service: entry.service, Key: entry.key }));
    if (removed.length > 0) body['mappingsRemoved'] = removed.map((entry) => ({ Service: entry.service, Key: entry.key }));
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
    this.clearOutcome();
    this.notify();
    const result = creating
      ? await this.api().requestJson<unknown>(OAUTH_RESOURCE_SERVER_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        })
      : await this.api().requestJson<unknown>(`${OAUTH_RESOURCE_SERVER_PATH}/${encodeEntityId(this.opened.name)}`, {
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
    const id = textAt(result.body, 'name') || this.buffer.name;
    this.savedIdValue = id;
    this.secretRefusedValue = textAt(result.body, 'secretRefused');
    const refused = record(record(result.body)?.['mappingsRefused']);
    this.mappingsRefusedCount = typeof refused?.['count'] === 'number' ? refused['count'] : 0;
    this.mappingsRefusedReason = textAt(refused, 'reason');
    this.opened = this.buffer;
    this.openedMappings = this.mappingsValue;
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

  private change(field: string): void {
    if (this.violationList.some((entry) => entry.field === field)) {
      this.violationList = this.violationList.filter((entry) => entry.field !== field);
    }
    this.savedValue = false;
    this.clearOutcome();
    this.formDirty.setDirty(true);
    this.notify();
  }

  /** Put the form read's rule for `field` on the field, when it is not already refused. */
  private addRule(field: string, code = ''): void {
    const rule = this.rulesValue.find((entry) => (entry.field === field || entry.field === AUTHENTICATOR_FIELD) && (code === '' || entry.code === code));
    if (rule === undefined || this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /**
   * The authenticator's settings as the wire takes them: a flag as a boolean, a number's digits as a
   * number, an object's JSON parsed. `null` when an object's text does not parse, which is refused on
   * that setting with the server's own sentence for it.
   */
  private settingsWire(): Record<string, unknown> | null {
    const out: Record<string, unknown> = {};
    let broken = false;
    for (const entry of this.settings()) {
      const value = this.buffer.settings[entry.name];
      if (value === undefined) continue;
      if (entry.kind === 'boolean') {
        out[entry.name] = value === true;
        continue;
      }
      const text = typeof value === 'string' ? value : '';
      if (entry.kind === 'object') {
        if (text.trim() === '') continue;
        try {
          out[entry.name] = JSON.parse(text) as unknown;
        } catch {
          broken = true;
          this.addRule(settingField(entry.name), 'OAUTH.AUTHENTICATOR.SETTING');
        }
        continue;
      }
      if ((entry.kind === 'integer' || entry.kind === 'double') && text.trim() !== '' && !Number.isNaN(Number(text))) {
        out[entry.name] = Number(text);
        continue;
      }
      out[entry.name] = text;
    }
    return broken ? null : out;
  }

  private authenticatorWire(settings: Record<string, unknown>): Record<string, unknown> {
    return { [NAMESPACE_MEMBER]: this.buffer.namespace, [IMPLEMENTATION_MEMBER]: this.buffer.implementation, ...settings };
  }

  /** A create's body: every field (AD-54). */
  private createBody(settings: Record<string, unknown>): Record<string, unknown> {
    return {
      [NAME_FIELD]: this.buffer.name,
      [DESCRIPTION_FIELD]: this.buffer.description,
      [ENABLED_FIELD]: this.buffer.enabled,
      [ISSUER_FIELD]: this.buffer.issuer,
      [AUDIENCES_FIELD]: this.buffer.audiences,
      [SCOPE_FIELD]: this.buffer.scope,
      [JWT_FIELD]: this.buffer.jwt,
      [INTROSPECTION_FIELD]: this.buffer.introspection,
      [OIDC_FIELD]: this.buffer.oidc,
      [CLIENT_ID_FIELD]: this.buffer.clientId,
      [METHOD_FIELD]: this.buffer.method,
      [AUTHENTICATOR_FIELD]: this.authenticatorWire(settings),
    };
  }

  /** An edit's body: the fields changed since the fresh read; the audiences and the authenticator whole. */
  private changedBody(settings: Record<string, unknown>): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(TEXT_FIELDS) as TextKey[]) {
      if (key !== 'name' && this.buffer[key] !== this.opened[key]) out[TEXT_FIELDS[key]] = this.buffer[key];
    }
    for (const key of Object.keys(FLAG_FIELDS) as FlagKey[]) {
      if (this.buffer[key] !== this.opened[key]) out[FLAG_FIELDS[key]] = this.buffer[key];
    }
    if (!same(this.buffer.audiences, this.opened.audiences)) out[AUDIENCES_FIELD] = this.buffer.audiences;
    const authenticatorChanged =
      this.buffer.namespace !== this.opened.namespace || this.buffer.implementation !== this.opened.implementation || !same(this.buffer.settings, this.opened.settings);
    if (authenticatorChanged) out[AUTHENTICATOR_FIELD] = this.authenticatorWire(settings);
    return out;
  }

  private classesOf(source: unknown): AuthenticatorClass[] {
    const classes: AuthenticatorClass[] = [];
    for (const entry of Array.isArray(record(source)?.['Authenticators']) ? (record(source)?.['Authenticators'] as unknown[]) : []) {
      const implementation = textAt(entry, IMPLEMENTATION_MEMBER);
      if (implementation === '') continue;
      const settings: AuthenticatorSetting[] = [];
      for (const setting of Array.isArray(record(entry)?.['Settings']) ? (record(entry)?.['Settings'] as unknown[]) : []) {
        const name = textAt(setting, 'name');
        if (name !== '') settings.push({ name, kind: kindOf(textAt(setting, 'type')) });
      }
      classes.push({ implementation, settings });
    }
    return classes;
  }

  private absorb(result: JsonResult<unknown>, name: string): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      if (name !== '' && result.kind === 'error' && result.status === 404) this.absentValue = true;
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
    this.issuersValue = stringsOf(body?.['serverDescriptions']);
    this.webAppsValue = stringsOf(body?.['webApplications']);
    this.namespacesValue = stringsOf(body?.['namespaces']);
    this.authenticatorsValue = this.classesOf(body?.['authenticators']);
    const held: Record<string, string> = {};
    for (const [key, value] of Object.entries(record(body?.['held']) ?? {})) {
      if (typeof value === 'string') held[key] = value;
    }
    this.heldBy = held;
    if (name === '') {
      const count = body?.['resourceServerCount'];
      if (count === 0) this.mappingsValue = [mappingName(GATEWAY_SERVICE, DEFAULT_KEY), mappingName(BINDINGS_SERVICE, DEFAULT_KEY)];
      const offered = this.implementations();
      if (!offered.includes(DEFAULT_IMPLEMENTATION)) this.buffer = { ...this.buffer, implementation: offered[0] ?? '' };
      return;
    }
    const definition = record(body?.['definition']);
    if (definition === null) {
      this.absentValue = true;
      return;
    }
    const authenticator = record(definition[AUTHENTICATOR_FIELD]);
    const implementation = textAt(authenticator, IMPLEMENTATION_MEMBER) || DEFAULT_IMPLEMENTATION;
    const described = this.authenticatorsValue.find((entry) => entry.implementation === implementation)?.settings ?? [];
    const settings: Record<string, SettingValue> = {};
    for (const entry of described) settings[entry.name] = settingOf(entry.kind, authenticator?.[entry.name]);
    const flag = (field: string, fallback: boolean): boolean => (typeof definition[field] === 'boolean' ? (definition[field] as boolean) : fallback);
    this.buffer = {
      name: textAt(definition, NAME_FIELD) || name,
      description: textAt(definition, DESCRIPTION_FIELD),
      enabled: flag(ENABLED_FIELD, true),
      issuer: textAt(definition, ISSUER_FIELD),
      audiences: stringsOf(definition[AUDIENCES_FIELD]),
      scope: textAt(definition, SCOPE_FIELD),
      jwt: flag(JWT_FIELD, true),
      introspection: flag(INTROSPECTION_FIELD, false),
      oidc: flag(OIDC_FIELD, false),
      clientId: textAt(definition, CLIENT_ID_FIELD),
      method: textAt(definition, METHOD_FIELD),
      namespace: textAt(authenticator, NAMESPACE_MEMBER) || DEFAULT_NAMESPACE,
      implementation,
      settings,
    };
    this.opened = this.buffer;
    this.mappingsValue = stringsOf(body?.['mappings']);
    this.openedMappings = this.mappingsValue;
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

  private clearOutcome(): void {
    this.secretRefusedValue = '';
    this.mappingsRefusedCount = 0;
    this.mappingsRefusedReason = '';
  }

  private publish(id: string, action: ChangeAction): void {
    if (id === '') return;
    this.injector.get(ChangeBus).publish({ kind: 'changed', type: OAUTH_RESOURCE_SERVER_ENTITY, scope: OAUTH_RESOURCE_SERVER_SCOPE, id, action, readBack: this.readBackValue });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

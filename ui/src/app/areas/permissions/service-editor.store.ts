import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The form read, taking `?name=`, and the Save's collection path (the id is appended, AD-13). */
export const SERVICE_FORM_PATH = '/api/ocupilot/services/form';

export const SERVICES_PATH = '/api/ocupilot/services';

/** The change event's entity type and scope (AD-13, AD-14). */
export const SERVICE_ENTITY = 'service';

export const SERVICE_SCOPE = 'instance';

/** The three fields a Save may send, as the server names them. */
export const ENABLED_FIELD = 'Enabled';

export const AUTHE_FIELD = 'AutheEnabled';

export const CLIENT_SYSTEMS_FIELD = 'ClientSystems';

/** The three tabs, the classic Edit Service dialog's groups (`%CSP.UI.Portal.Dialog.Service`). */
export const GENERAL_TAB = 'general';

export const METHODS_TAB = 'methods';

export const CONNECTIONS_TAB = 'connections';

/** Which tab each field is drawn on. */
export const SERVICE_FIELD_TABS: Readonly<Record<string, string>> = {
  [ENABLED_FIELD]: GENERAL_TAB,
  [AUTHE_FIELD]: METHODS_TAB,
  [CLIENT_SYSTEMS_FIELD]: CONNECTIONS_TAB,
};

/** The fields in the tabs' order, which is the order a refused Save's first field is chosen in. */
export const SERVICE_FIELD_ORDER: readonly string[] = [ENABLED_FIELD, AUTHE_FIELD, CLIENT_SYSTEMS_FIELD];

/** The vendor's `AutheEnabled` bit for the Unauthenticated method, whose effect the form states. */
export const UNAUTHENTICATED_BIT = 64;

/** The one character that separates an allowed address from its roles in the spelling a Save composes. */
export const ADDRESS_ROLE_SEPARATOR = '|';

/** One authentication method the service offers, as the form read names it. */
export interface ServiceMethod {
  readonly bit: number;
  readonly label: string;
}

/** One role the instance holds, with the kernel's verdict on giving it to an address (AD-10). */
export interface ServiceRoleOption {
  readonly name: string;
  readonly privileged: boolean;
}

/**
 * One allowed connection as the form holds it: `entry` is what a Save sends -- the instance's own
 * spelling for an entry the form did not touch, and `address` or `address|role,role` for one it
 * added or gave new roles -- and `address` and `roles` are what the editor draws.
 */
export interface ServiceConnection {
  readonly entry: string;
  readonly address: string;
  readonly roles: readonly string[];
}

interface Buffer {
  readonly enabled: boolean;
  readonly authe: number;
  readonly connections: readonly ServiceConnection[];
}

const EMPTY_BUFFER: Buffer = { enabled: false, authe: 0, connections: [] };

function recordOf(source: unknown): Record<string, unknown> {
  return source !== null && typeof source === 'object' && !Array.isArray(source) ? (source as Record<string, unknown>) : {};
}

function textOf(source: unknown, key: string): string {
  const value = recordOf(source)[key];
  return typeof value === 'string' ? value : '';
}

function arrayOf(source: unknown, key: string): readonly unknown[] {
  const value = recordOf(source)[key];
  return Array.isArray(value) ? value : [];
}

function stringsOf(source: unknown, key: string): string[] {
  return arrayOf(source, key).filter((entry): entry is string => typeof entry === 'string' && entry !== '');
}

/** The spelling a Save sends for an entry the form composes: `address`, or `address|role,role`. */
export function composeEntry(address: string, roles: readonly string[]): string {
  return roles.length === 0 ? address : `${address}${ADDRESS_ROLE_SEPARATOR}${roles.join(',')}`;
}

/** Whether two role lists name the same roles, compared as the instance does: without case. */
function sameRoles(left: readonly string[], right: readonly string[]): boolean {
  const fold = (roles: readonly string[]) => [...new Set(roles.map((role) => role.toUpperCase()))].sort().join(',');
  return fold(left) === fold(right);
}

/**
 * The service editor's store (AD-19, AD-55, Story 16.13): an edit of the service
 * `permissions/services/edit/<name>` names, across the classic Edit Service dialog's three groups.
 *
 * **It composes no payload of its own.** `PUT /services/<name>` resolves the tool the agent's
 * `permissions.services.update` does, merges what this store sends over its own fresh read, and
 * sends the complete set (AD-4); every field sentence is the server's (AD-39) but one, the client's
 * refusal of a `|` in the one-address field. A Save sends only the fields changed since the read,
 * among `Enabled`, `AutheEnabled` (the whole mask) and `ClientSystems` (the whole list).
 *
 * **An entry is sent as read until the form changes it.** The form read splits each stored entry
 * into its address and roles on the instance (`ServiceRules.EntryParts`); an entry the form did not
 * touch keeps the instance's own spelling, and one it adds or gives new roles is composed here.
 *
 * **The authentication checkboxes are bits of one mask**, set or cleared over the mask the read
 * answered, so a bit the service holds and the instance does not offer is kept as it was.
 */
@Injectable({ providedIn: 'root' })
export class ServiceEditor {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private serviceName = '';

  private descriptionValue = '';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private servesValue = false;

  private methodList: readonly ServiceMethod[] = [];

  private clientSystemsValue = false;

  private clientRolesValue = false;

  private roleList: readonly ServiceRoleOption[] = [];

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

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  /** The service the route names, or `''` on the bare route. */
  name(): string {
    return this.serviceName;
  }

  description(): string {
    return this.descriptionValue;
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  /** Whether the route names no service at all. */
  bare(): boolean {
    return this.loadedValue && this.serviceName === '';
  }

  /** Whether the service the route names is not on the instance. */
  absent(): boolean {
    return this.absentValue;
  }

  /** Whether the service's read is held, which is when its fields are drawn. */
  held(): boolean {
    return this.heldValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  canSave(): boolean {
    return this.heldValue && !this.savingValue && !this.absentValue;
  }

  /** Whether the service is the one OcuPilot is served through, as the form read says. */
  servesOcuPilot(): boolean {
    return this.servesValue;
  }

  enabled(): boolean {
    return this.buffer.enabled;
  }

  /** The methods the service offers, in the classic order, with the instance's labels. */
  methods(): readonly ServiceMethod[] {
    return this.methodList;
  }

  /** Whether the authentication bit `bit` is set in the form's mask. */
  autheChecked(bit: number): boolean {
    return (this.buffer.authe & bit) !== 0;
  }

  /** Whether the service checks the address a connection comes from, which is when an address may be added. */
  clientSystems(): boolean {
    return this.clientSystemsValue;
  }

  /** Whether the service gives an address roles, which is when an entry's roles are drawn and edited. */
  clientRoles(): boolean {
    return this.clientRolesValue;
  }

  /** The roles the instance holds, in the read's order, each with the kernel's privilege mark. */
  roleOptions(): readonly ServiceRoleOption[] {
    return this.roleList;
  }

  /** The allowed connections as the form holds them. */
  connections(): readonly ServiceConnection[] {
    return this.buffer.connections;
  }

  /** Whether the General, Authentication methods and Allowed incoming connections tabs are drawn. */
  hasMethodsTab(): boolean {
    return this.methodList.length > 0;
  }

  hasConnectionsTab(): boolean {
    return this.clientSystemsValue || this.opened.connections.length > 0;
  }

  /** Whether Service enabled is drawn unavailable: on the service OcuPilot is served through (AD-10). */
  enabledProtected(): boolean {
    return this.servesValue;
  }

  /**
   * The consequence line under the methods, or `''`: on the serving service, any change to its
   * mask; on any other, a newly ticked Unauthenticated (AD-10).
   */
  methodsEffect(): string {
    if (this.buffer.authe === this.opened.authe) return '';
    if (this.servesValue) return STRINGS.serviceEffectServesOcuPilot;
    const adds = (this.buffer.authe & UNAUTHENTICATED_BIT) !== 0 && (this.opened.authe & UNAUTHENTICATED_BIT) === 0;
    return adds ? STRINGS.serviceEffectUnauthenticated : '';
  }

  /** The serving-service line under the connection list, or `''`: on that service, while its list has changed. */
  connectionsEffect(): string {
    return this.servesValue && this.connectionsChanged() ? STRINGS.serviceEffectServesOcuPilot : '';
  }

  /**
   * The privilege line under the connection list, or `''`: while an entry holds a role its address
   * did not hold as read, and the read marks that role privileged (AD-10).
   */
  privilegeEffect(): string {
    const privileged = new Set(this.roleList.filter((role) => role.privileged).map((role) => role.name.toUpperCase()));
    for (const connection of this.buffer.connections) {
      const held = new Set(
        this.opened.connections
          .filter((entry) => entry.address.toUpperCase() === connection.address.toUpperCase())
          .flatMap((entry) => entry.roles.map((role) => role.toUpperCase()))
      );
      if (connection.roles.some((role) => !held.has(role.toUpperCase()) && privileged.has(role.toUpperCase()))) {
        return STRINGS.privilegedGrantEffect;
      }
    }
    return '';
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

  /** The fields a Save would send: each of the three changed since the read (AD-4, the server merges). */
  changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    if (this.buffer.enabled !== this.opened.enabled) out[ENABLED_FIELD] = this.buffer.enabled;
    if (this.buffer.authe !== this.opened.authe) out[AUTHE_FIELD] = this.buffer.authe;
    if (this.connectionsChanged()) out[CLIENT_SYSTEMS_FIELD] = this.buffer.connections.map((connection) => connection.entry);
    return out;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: when the editor is left, and before every open. */
  reset(): void {
    this.generation += 1;
    this.serviceName = '';
    this.descriptionValue = '';
    this.buffer = EMPTY_BUFFER;
    this.opened = EMPTY_BUFFER;
    this.servesValue = false;
    this.methodList = [];
    this.clientSystemsValue = false;
    this.clientRolesValue = false;
    this.roleList = [];
    this.loadedValue = false;
    this.heldValue = false;
    this.absentValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.readBackValue = null;
    this.formDirty.reset();
    this.notify();
  }

  /** Open the service `name`, or the bare route when it is `''`. The form read is made on every open. */
  async open(name: string): Promise<void> {
    this.reset();
    this.serviceName = name;
    if (name === '') {
      this.loadedValue = true;
      this.notify();
      return;
    }
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${SERVICE_FORM_PATH}?name=${encodeURIComponent(name)}`);
    if (generation !== this.generation) return;
    this.absorb(result);
    this.loadedValue = true;
    this.notify();
  }

  /** Set Service enabled; refused on the service OcuPilot is served through (AD-10). */
  setEnabled(on: boolean): void {
    if (!this.heldValue || this.enabledProtected() || this.buffer.enabled === on) return;
    this.buffer = { ...this.buffer, enabled: on };
    this.change(ENABLED_FIELD);
  }

  /** Set or clear one authentication bit over the mask the form holds. */
  setAuthe(bit: number, on: boolean): void {
    if (!this.heldValue) return;
    const authe = on ? this.buffer.authe | bit : this.buffer.authe & ~bit;
    if (authe === this.buffer.authe) return;
    this.buffer = { ...this.buffer, authe };
    this.change(AUTHE_FIELD);
  }

  /**
   * Add one bare address, trimmed: an entry carrying roles is refused with the published sentence on
   * the field -- one holding a `|`, or exactly one `:`, which the instance reads as `address:roles`
   * (`ServiceRules.EntryParts`) -- and an empty or already listed address adds nothing. Answers
   * whether it was added.
   */
  addAddress(text: string): boolean {
    if (!this.heldValue || !this.clientSystemsValue) return false;
    const address = text.trim();
    if (address.includes(ADDRESS_ROLE_SEPARATOR) || address.split(':').length === 2) {
      this.violationList = [
        ...this.violationList.filter((item) => item.field !== CLIENT_SYSTEMS_FIELD),
        { field: CLIENT_SYSTEMS_FIELD, code: '', reason: STRINGS.serviceAddressNoRoles },
      ];
      this.notify();
      return false;
    }
    if (address === '' || this.buffer.connections.some((connection) => connection.address === address)) return false;
    this.buffer = { ...this.buffer, connections: [...this.buffer.connections, { entry: address, address, roles: [] }] };
    this.change(CLIENT_SYSTEMS_FIELD);
    return true;
  }

  removeConnection(index: number): void {
    if (!this.heldValue || index < 0 || index >= this.buffer.connections.length) return;
    this.buffer = { ...this.buffer, connections: this.buffer.connections.filter((_, at) => at !== index) };
    this.change(CLIENT_SYSTEMS_FIELD);
  }

  /**
   * Give the entry at `index` exactly `roles`, in the form's buffer only: the entry is composed
   * `address|role,role` (or `address` for none). Roles equal to the ones it holds change nothing, so
   * an entry is never respelled by an Apply that changed no role.
   */
  setRoles(index: number, roles: readonly string[]): void {
    if (!this.heldValue || !this.clientRolesValue) return;
    const connection = this.buffer.connections[index];
    if (connection === undefined || sameRoles(connection.roles, roles)) return;
    const next: ServiceConnection = { entry: composeEntry(connection.address, roles), address: connection.address, roles: [...roles] };
    this.buffer = { ...this.buffer, connections: this.buffer.connections.map((entry, at) => (at === index ? next : entry)) };
    this.change(CLIENT_SYSTEMS_FIELD);
  }

  /**
   * Save: put the fields changed since the read. An accepted Save publishes one change event
   * (AD-14), marks the form clean and keeps the route open showing "Saved"; a refused one keeps
   * what was entered so a field can be corrected. A Save that changes nothing sends nothing.
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
    const sentBuffer = this.buffer;
    const result = await this.api().requestJson<unknown>(`${SERVICES_PATH}/${encodeEntityId(this.serviceName)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(edits),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.rememberRefusal(result);
      if (result.kind === 'error' && result.status === 404) this.absentValue = true;
      this.notify();
      return false;
    }
    // What was sent is now stored; anything entered while the Save was in flight stays unsaved work.
    this.opened = sentBuffer;
    const pending = Object.keys(this.changedFields()).length > 0;
    this.savedValue = !pending;
    this.readBackValue = readBackOf(recordOf(result.body)['readBack']);
    this.formDirty.setDirty(pending);
    this.publishUpdated();
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  /** AD-14: the Services list, and anything else showing this service, reads it again. */
  private publishUpdated(): void {
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: SERVICE_ENTITY,
      scope: SERVICE_SCOPE,
      id: this.serviceName,
      action: 'updated',
      readBack: this.readBackValue,
    });
  }

  private connectionsChanged(): boolean {
    const now = this.buffer.connections.map((connection) => connection.entry);
    const then = this.opened.connections.map((connection) => connection.entry);
    return JSON.stringify(now) !== JSON.stringify(then);
  }

  private change(field: string): void {
    if (this.violationList.some((entry) => entry.field === field)) {
      this.violationList = this.violationList.filter((entry) => entry.field !== field);
    }
    this.savedValue = false;
    this.formDirty.setDirty(Object.keys(this.changedFields()).length > 0);
    this.notify();
  }

  private absorb(result: JsonResult<unknown>): void {
    if (result.kind !== 'ok') {
      this.rememberRefusal(result);
      if (result.kind === 'error' && result.status === 404) this.absentValue = true;
      return;
    }
    const body = recordOf(result.body);
    const service = body['service'];
    if (service === null || typeof service !== 'object' || Array.isArray(service)) {
      this.absentValue = true;
      return;
    }
    const held = service as Record<string, unknown>;
    const authe = Number(held[AUTHE_FIELD]);
    const connections: ServiceConnection[] = [];
    for (const raw of arrayOf(body, 'connections')) {
      const entry = textOf(raw, 'entry');
      if (entry === '') continue;
      connections.push({ entry, address: textOf(raw, 'address'), roles: stringsOf(raw, 'roles') });
    }
    const methods: ServiceMethod[] = [];
    for (const raw of arrayOf(body, 'authenticationMethods')) {
      const bit = recordOf(raw)['bit'];
      const label = textOf(raw, 'label');
      if (typeof bit !== 'number' || bit <= 0 || label === '') continue;
      methods.push({ bit, label });
    }
    const roles: ServiceRoleOption[] = [];
    for (const raw of arrayOf(body, 'roles')) {
      const name = textOf(raw, 'name');
      if (name === '' || roles.some((role) => role.name === name)) continue;
      // A role whose flag the server did not send as false is treated as privileged, so the
      // consequence is stated rather than missed.
      const flag = recordOf(raw)['privileged'];
      roles.push({ name, privileged: !(flag === false || flag === 0) });
    }
    this.buffer = { enabled: held[ENABLED_FIELD] === true, authe: Number.isFinite(authe) ? authe : 0, connections };
    this.opened = this.buffer;
    this.descriptionValue = textOf(held, 'Description');
    this.servesValue = body['servesOcuPilot'] === true;
    this.methodList = methods;
    this.clientSystemsValue = body['clientSystems'] === true;
    this.clientRolesValue = body['clientRoles'] === true;
    this.roleList = roles;
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
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

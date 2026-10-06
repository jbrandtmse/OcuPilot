import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { REMOTE_DATABASE_LIST_SECONDS } from '../../core/proposal-view';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` creates, `PUT <path>/<id>` re-points. */
export const REMOTE_DATABASE_PATH = '/api/ocupilot/remote-database';

/** The form read: the rules, their sentences, the data servers, the bound and, with a name, the configuration. */
export const REMOTE_DATABASE_FORM_PATH = `${REMOTE_DATABASE_PATH}/form`;

/** The bounded listing of one data server's databases (AD-21's seventh case). */
export const REMOTE_DATABASE_DIRECTORIES_PATH = `${REMOTE_DATABASE_PATH}/directories`;

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const REMOTE_DATABASE_ENTITY = 'database-configuration';

/** The tool identifier whose list this form's changes belong to; it picks Remote databases over Local databases. */
export const REMOTE_DATABASE_TOOL = 'osmgmt.remotedatabases';

export const REMOTE_DATABASE_SCOPE = 'instance';

/** The fields, named as the server names them. */
export const NAME_FIELD = 'Name';

export const SERVER_FIELD = 'Server';

export const DIRECTORY_FIELD = 'Directory';

/** Shown on an edit, never set (the story's boundary). */
export const STREAM_LOCATION_FIELD = 'StreamLocation';

/** The two settable fields; the name is the id. */
export const REMOTE_DATABASE_FIELDS: readonly string[] = [SERVER_FIELD, DIRECTORY_FIELD];

/** What the form is doing: creating a remote database, or re-pointing the one its route names. */
export type FormMode = 'create' | 'edit';

/** One rule the server applies, with the sentence it refuses with (AD-39). */
export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** One database a data server's listing answered: its name there and its directory, the value sent. */
export interface DirectoryRow {
  readonly name: string;
  readonly directory: string;
}

/**
 * Where the data server's listing is: none asked for, one in flight since the moment it was sent,
 * one answered with its rows, or one refused (its reason is on the Data server field).
 */
export type Listing =
  | { readonly kind: 'idle' }
  | { readonly kind: 'running'; readonly server: string; readonly since: Date }
  | { readonly kind: 'listed'; readonly server: string; readonly rows: readonly DirectoryRow[] }
  | { readonly kind: 'refused'; readonly server: string };

/** A listing in flight, or a Save in flight (which lists again): the server and when it was sent. */
export interface RunningListing {
  readonly server: string;
  readonly since: Date;
}

type Buffer = Readonly<Record<string, string>>;

const EMPTY_BUFFER: Buffer = {
  [NAME_FIELD]: '',
  [SERVER_FIELD]: '',
  [DIRECTORY_FIELD]: '',
  [STREAM_LOCATION_FIELD]: '',
};

const IDLE: Listing = { kind: 'idle' };

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function stringsAt(source: unknown, key: string): string[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === 'string') : [];
}

function arrayAt(source: unknown, key: string): unknown[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value : [];
}

/**
 * The remote database form's store (Story 18.16, AD-19, AD-55): a create on
 * `os-management/remote-databases/edit`, a re-point of the configuration its route names on
 * `os-management/remote-databases/edit/<name>`.
 *
 * **It composes no payload of its own and holds no copy of the directory rule.** `POST
 * /remote-database` and `PUT /remote-database/<id>` resolve the same tool classes the agent's
 * `osmgmt.remotedatabases.create` and `.update` do, which list the data server again at every Save
 * (AD-21's seventh case); every field sentence is the server's (AD-39).
 *
 * **The directory is chosen, never typed.** Choosing a data server clears the directory and sends the
 * bounded listing; its rows are the directory's only choices, and a refused listing offers none and
 * puts its reason on the Data server field. A listing answer that a later choice, an open or a reset
 * has superseded is discarded. An edit's directory offers just the stored one until a server is
 * chosen or the held one is listed again (`listAgain`), which is also how a refused listing is retried.
 *
 * **An edit sends only the fields changed since its fresh read** (AD-4); an edit that changed
 * nothing writes nothing.
 */
@Injectable({ providedIn: 'root' })
export class RemoteDatabaseForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private listingGeneration = 0;

  private modeValue: FormMode = 'create';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private databaseName = '';

  private rulesValue: readonly FieldRule[] = [];

  private requiredValue: readonly string[] = [];

  private serverNames: readonly string[] = [];

  private listSecondsValue = REMOTE_DATABASE_LIST_SECONDS;

  private listingValue: Listing = IDLE;

  private loadedValue = false;

  private heldValue = false;

  private absentValue = false;

  private savingSince: Date | null = null;

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
    return this.savingSince !== null;
  }

  /** Whether an edit names a configuration the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  value(field: string): string {
    return this.buffer[field] ?? '';
  }

  /** The configuration an edit names, as its fresh read answered it. */
  name(): string {
    return this.databaseName;
  }

  /** The listing's bound in seconds, as the form read answered it. */
  listSeconds(): number {
    return this.listSecondsValue;
  }

  /** The data servers the form read answered, a stored server it no longer lists kept first. */
  servers(): readonly string[] {
    const held = this.value(SERVER_FIELD);
    if (held === '' || this.serverNames.includes(held)) return this.serverNames;
    return [held, ...this.serverNames];
  }

  listing(): Listing {
    return this.listingValue;
  }

  /**
   * The directories the Directory select offers: the rows the listing of the chosen server answered,
   * and a held directory they do not carry kept first -- which, on an edit before any choice, is the
   * stored one alone.
   */
  directories(): readonly DirectoryRow[] {
    const listing = this.listingValue;
    const rows = listing.kind === 'listed' && listing.server === this.value(SERVER_FIELD) ? listing.rows : [];
    const held = this.value(DIRECTORY_FIELD);
    if (held === '' || rows.some((row) => row.directory === held)) return rows;
    return [{ name: '', directory: held }, ...rows];
  }

  /** The listing or the Save in flight, which the running line names, or `null`. */
  running(): RunningListing | null {
    const listing = this.listingValue;
    if (listing.kind === 'running') return { server: listing.server, since: listing.since };
    if (this.savingSince !== null) return { server: this.value(SERVER_FIELD), since: this.savingSince };
    return null;
  }

  /** The data server whose listing answered no rows, or `''`. */
  listedNone(): string {
    const listing = this.listingValue;
    return listing.kind === 'listed' && listing.rows.length === 0 ? listing.server : '';
  }

  /** Whether the fields take input: in edit mode only once the fresh read is held. */
  editable(): boolean {
    return this.modeValue === 'create' || this.heldValue;
  }

  /**
   * Whether Save may send: not while a listing or a Save is in flight, never over an absent
   * configuration, and in edit mode only over a fresh read of it.
   */
  canSave(): boolean {
    if (this.running() !== null || this.absentValue) return false;
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

  /** The created configuration's name, or `''`. */
  createdId(): string {
    return this.createdIdValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  /** Whether this store is being carried across the create's own route replacement. */
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
    this.listingGeneration += 1;
    this.modeValue = 'create';
    this.buffer = EMPTY_BUFFER;
    this.opened = EMPTY_BUFFER;
    this.databaseName = '';
    this.rulesValue = [];
    this.requiredValue = [];
    this.serverNames = [];
    this.listSecondsValue = REMOTE_DATABASE_LIST_SECONDS;
    this.listingValue = IDLE;
    this.loadedValue = false;
    this.heldValue = false;
    this.absentValue = false;
    this.savingSince = null;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.readBackValue = null;
    this.createdIdValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form: a create when `name` is empty, a re-point of that configuration otherwise. The form
   * read is made on every open rather than cached, and lists no data server. An arrival that is the
   * create's own route replacement opens the new configuration's edit and keeps the saved
   * confirmation, with its read-back, on screen.
   */
  async open(name: string): Promise<void> {
    const arriving = this.retainingValue && name !== '' && name === this.createdIdValue;
    const readBack = this.readBackValue;
    this.reset();
    if (arriving) {
      this.savedValue = true;
      this.readBackValue = readBack;
    }
    this.modeValue = name === '' ? 'create' : 'edit';
    const generation = this.generation;
    const path = name === '' ? REMOTE_DATABASE_FORM_PATH : `${REMOTE_DATABASE_FORM_PATH}?name=${encodeURIComponent(name)}`;
    const result = await this.api().requestJson<unknown>(path);
    if (generation !== this.generation) return;
    this.absorb(result, name);
    this.loadedValue = true;
    this.notify();
  }

  /** Set the name of a create, or the directory, which only the listing's rows offer. */
  setValue(field: string, value: string): void {
    if (!this.editable() || this.busy()) return;
    if (field !== NAME_FIELD && field !== DIRECTORY_FIELD) return;
    if (this.modeValue === 'edit' && field === NAME_FIELD) return;
    if (this.value(field) === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.change(field);
  }

  /**
   * Choose the data server: the directory is cleared and, for a server, its bounded listing is sent.
   * A 200 offers its rows; a refusal offers nothing and renders its reason on Data server. An answer
   * a later choice, open or reset superseded is discarded.
   */
  async chooseServer(server: string): Promise<void> {
    if (!this.editable() || this.busy()) return;
    if (this.value(SERVER_FIELD) === server) return;
    this.buffer = { ...this.buffer, [SERVER_FIELD]: server, [DIRECTORY_FIELD]: '' };
    this.clearFieldViolation(DIRECTORY_FIELD);
    this.listingGeneration += 1;
    this.listingValue = server === '' ? IDLE : { kind: 'running', server, since: new Date() };
    this.change(SERVER_FIELD);
    if (server === '') return;
    await this.list(server);
  }

  /**
   * List the held data server again: the stored server of an edit, which no choice re-selects, or a
   * server whose listing was refused. Nothing held changes; the held directory stays chosen and is
   * offered among the rows. Refused while a listing or a Save is in flight, or with no server held.
   */
  async listAgain(): Promise<void> {
    const server = this.value(SERVER_FIELD);
    if (!this.editable() || this.busy() || server === '' || this.listingValue.kind === 'running') return;
    this.clearFieldViolation(SERVER_FIELD);
    this.listingGeneration += 1;
    this.listingValue = { kind: 'running', server, since: new Date() };
    this.notify();
    await this.list(server);
  }

  /** Send the bounded listing of `server`, whose running state the caller has recorded. */
  private async list(server: string): Promise<void> {
    const listingGeneration = this.listingGeneration;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${REMOTE_DATABASE_DIRECTORIES_PATH}?server=${encodeURIComponent(server)}`);
    if (generation !== this.generation || listingGeneration !== this.listingGeneration) return;
    if (result.kind === 'ok') {
      this.listingValue = { kind: 'listed', server, rows: this.rowsOf(result.body) };
      this.notify();
      return;
    }
    this.listingValue = { kind: 'refused', server };
    const answered = violationsOf(result);
    if (answered.length > 0) {
      const fields = new Set(answered.map((entry) => entry.field));
      this.violationList = [...this.violationList.filter((entry) => !fields.has(entry.field)), ...answered];
    } else {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, {});
    }
    this.notify();
  }

  /**
   * On blur: drop a refusal that no longer describes what the field holds, and render the server's
   * required-field sentence on an empty required field of a create.
   */
  onBlur(field: string): void {
    this.dropStaleViolation(field);
    this.markEmptyRequired(field);
  }

  /**
   * Save: a create posts the name, the data server and the directory; an edit puts the fields changed
   * since its fresh read. The server lists the data server again before it writes, so the running
   * line names it while the Save is in flight. An accepted Save publishes one change event (AD-14)
   * and marks the form clean; a refused one keeps what was entered so a field can be corrected.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const creating = this.modeValue === 'create';
    if (!creating && Object.keys(this.changedFields()).length === 0) {
      this.clearRefusal();
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    this.savingSince = new Date();
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.readBackValue = null;
    this.notify();

    const sent = { ...this.buffer };
    const result = creating
      ? await this.api().requestJson<unknown>(REMOTE_DATABASE_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.createBody()),
        })
      : await this.api().requestJson<unknown>(`${REMOTE_DATABASE_PATH}/${encodeEntityId(this.databaseName)}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.changedFields()),
        });
    if (generation !== this.generation) return false;
    this.savingSince = null;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason =
        this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, sent);
      this.notify();
      return false;
    }
    const id = creating ? textAt(result.body, 'name') || this.value(NAME_FIELD) : this.databaseName;
    if (creating) this.createdIdValue = id;
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

  private change(field: string): void {
    this.clearFieldViolation(field);
    this.savedValue = false;
    this.formDirty.setDirty(true);
    this.notify();
  }

  private clearFieldViolation(field: string): void {
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
  }

  private dropStaleViolation(field: string): void {
    const refused = this.refusedValues[field];
    if (refused === undefined) return;
    if (this.value(field) === refused) return;
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.clearFieldViolation(field);
    this.notify();
  }

  /** Render the form read's first rule for an empty required field of a create. */
  private markEmptyRequired(field: string): void {
    if (this.modeValue !== 'create' || !this.required(field)) return;
    if (this.value(field).trim() !== '') return;
    const rule = this.rulesValue.find((entry) => entry.field === field);
    if (rule === undefined || this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /** A create's body: the name, the data server and the directory, as chosen (AD-54). */
  private createBody(): Record<string, unknown> {
    return {
      [NAME_FIELD]: this.value(NAME_FIELD),
      [SERVER_FIELD]: this.value(SERVER_FIELD),
      [DIRECTORY_FIELD]: this.value(DIRECTORY_FIELD),
    };
  }

  /** The body of an edit: only the fields changed since the fresh read (AD-4, the server merges). */
  private changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of REMOTE_DATABASE_FIELDS) {
      if (this.value(field) !== (this.opened[field] ?? '')) out[field] = this.value(field);
    }
    return out;
  }

  /** The listing's rows, each a name and a non-empty directory; anything else is left out. */
  private rowsOf(body: unknown): DirectoryRow[] {
    const rows: DirectoryRow[] = [];
    for (const entry of arrayAt(body, 'rows')) {
      const directory = textAt(entry, 'Directory');
      if (directory !== '') rows.push({ name: textAt(entry, 'Name'), directory });
    }
    return rows;
  }

  private absorb(result: JsonResult<unknown>, name: string): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, {});
      if (name !== '' && result.kind === 'error' && result.status === 404) this.absentValue = true;
      return;
    }
    const body = result.body;
    const rules: FieldRule[] = [];
    for (const entry of arrayAt(body, 'rules')) {
      const field = textAt(entry, 'field');
      const code = textAt(entry, 'code');
      const reason = textAt(entry, 'reason');
      if (field !== '' && code !== '' && reason !== '') rules.push({ field, code, reason });
    }
    this.rulesValue = rules;
    this.requiredValue = stringsAt(body, 'requiredFields');
    const seconds = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['listSeconds'] : null;
    if (typeof seconds === 'number' && Number.isInteger(seconds) && seconds > 0) this.listSecondsValue = seconds;
    this.serverNames = arrayAt(body, 'servers')
      .map((entry) => textAt(entry, NAME_FIELD))
      .filter((server) => server !== '');
    if (name === '') {
      this.buffer = EMPTY_BUFFER;
      this.opened = this.buffer;
      return;
    }
    const configuration = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['configuration'] : null;
    if (configuration === null || typeof configuration !== 'object') {
      this.absentValue = true;
      return;
    }
    this.databaseName = textAt(body, NAME_FIELD) || name;
    this.buffer = {
      [NAME_FIELD]: this.databaseName,
      [SERVER_FIELD]: textAt(configuration, SERVER_FIELD),
      [DIRECTORY_FIELD]: textAt(configuration, DIRECTORY_FIELD),
      [STREAM_LOCATION_FIELD]: textAt(configuration, STREAM_LOCATION_FIELD),
    };
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

  private publish(id: string, action: ChangeAction): void {
    if (id === '') return;
    this.injector
      .get(ChangeBus)
      .publish({ kind: 'changed', type: REMOTE_DATABASE_ENTITY, scope: REMOTE_DATABASE_SCOPE, id, action, readBack: this.readBackValue, tool: REMOTE_DATABASE_TOOL });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

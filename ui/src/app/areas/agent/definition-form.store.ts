import { Injectable, Injector, inject } from '@angular/core';

import {
  AGENT_DEFINITIONS_PATH,
  AGENT_DEFINITION_ENTITY,
  AGENT_DEFINITION_SCOPE,
} from '../../core/agent-status';
import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { STRINGS } from '../../core/strings';
import {
  STATE_CONFLICT_CODE,
  type Violation,
  reasonForField,
  violationsOf,
} from '../../core/violations';

// The route, the entity type and the scope live in `core/agent-status.ts`, which is the other
// reader of the same list, and are re-exported here so every existing importer is unchanged. Two
// copies of a path is how one of them ends up pointing somewhere the other does not.
export { AGENT_DEFINITIONS_PATH, AGENT_DEFINITION_ENTITY, AGENT_DEFINITION_SCOPE };

/** The provider catalog the form cascades from (AD-5). */
export const AGENT_PROVIDERS_PATH = '/api/ocupilot/agent/providers';

/** One catalog row, as `GET /agent/providers` projects it. */
export interface ProviderRow {
  readonly key: string;
  readonly label: string;
  readonly defaultModel: string;
  readonly modelSuggestions: readonly string[];
  readonly defaultEndpoint: string;
  readonly endpointRequired: boolean;
  readonly canonicalMaxTokens: number;
  readonly canonicalTemperature: number;
  readonly defaultEnvVarName: string;
  readonly defaultCredentialName: string;
  readonly keyPrefix: string;
  readonly allowsLocal: boolean;
  /**
   * The sentence an inline key-shape check renders, written on the server beside the refusal it
   * mirrors and served as data (DW-339, AD-39). The client publishes no per-code copy.
   */
  readonly keyShapeReason: string;
}

/** The sentence the sticky bar carries after a save, or `''`. */
export type SaveOutcome = '' | 'saved' | 'pending-test';

/** Every wire field a request body may set, in the order the form lays them out (AD-4). */
export const WRITABLE_FIELDS = [
  'name',
  'provider',
  'model',
  'endpointUrl',
  'markedLocal',
  'httpAcknowledged',
  'credType',
  'envVarName',
  'credentialName',
  'maxTokens',
  'temperature',
  'maxIterationsPerTurn',
  'systemPromptOverride',
  'readOnly',
  'retentionDays',
  'enabled',
] as const;

export type WritableField = (typeof WRITABLE_FIELDS)[number];

/** The fields whose value is a JSON boolean on the wire; anything else is refused by the server. */
const BOOLEAN_FIELDS: readonly string[] = [
  'markedLocal',
  'httpAcknowledged',
  'readOnly',
  'enabled',
];

/** The `credType` a definition on a family that serves no local model carries. */
export const CRED_TYPE_CREDS = 'creds';

/**
 * The `credType` that names no credential at all, accepted by the server only on a provider whose
 * catalog row sets `allowsLocal` (`OcuPilot.Kernel.AgentRules.CREDTYPENONE`).
 */
export const CRED_TYPE_NONE = 'none';

/**
 * The fields the provider cascade rewrites that the form renders **no control for**.
 *
 * They are sent in every body and the server refuses on them by name (`AGENT.CREDNAME.*`,
 * `AGENT.ENVVAR.*`), so their violations reach the error summary -- but nothing can focus or blur
 * them, so `dropStaleViolation` can never run on either. `setProvider` clears them itself.
 */
const CASCADE_ONLY_FIELDS: readonly string[] = ['credentialName', 'envVarName'];

/** The fields whose value is a JSON number on the wire. */
const NUMBER_FIELDS: readonly string[] = [
  'maxTokens',
  'temperature',
  'maxIterationsPerTurn',
  'retentionDays',
];

/** The edit buffer: every writable field, as text for an input and a flag for a checkbox. */
export type EditBuffer = Record<string, string | boolean>;

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function flagAt(source: unknown, key: string): boolean {
  if (source === null || typeof source !== 'object') return false;
  return (source as Record<string, unknown>)[key] === true;
}

function stringsAt(source: unknown, key: string): readonly string[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  if (!Array.isArray(value)) return [];
  return value.filter((entry): entry is string => typeof entry === 'string');
}

function numberAt(source: unknown, key: string): number {
  if (source === null || typeof source !== 'object') return 0;
  const value = (source as Record<string, unknown>)[key];
  return typeof value === 'number' ? value : 0;
}

/**
 * The Definition form's own state (AD-19): the loaded record, the edit buffer, the dirty flag, the
 * per-field violations, the provider catalog, and the two orchestrations -- Save and Test
 * connection -- that the routes' own ordering forces.
 *
 * **Everything on screen is rendered from a response body, never from what was sent.** A `PUT`
 * carrying `enabled: true` beside a changed security field answers 200 with `enabled: false`: the
 * rule runs against the *stored* verification flag and passes, and the update then clears both
 * flags. Rendering the request would show an enabled definition that is disabled, so `absorb()` is
 * the only thing that fills the buffer after a write.
 *
 * **The key is write-only** (AD-35). No route returns it, nothing pre-fills it, a paste is not
 * trimmed, and the field is empty after a save under the published `Stored.` caption. It is not
 * part of the definition body at all: it travels on its own route.
 *
 * **Every refusal sentence is the server's** (AD-39): the envelope's `reason` for an
 * envelope-level code, a violation's own `reason` for a field-level one. The client publishes no
 * per-code copy.
 *
 * Framework-only in its injection, like `ErrorLogDrill`: the API service is resolved on the first
 * call rather than in the constructor.
 */
@Injectable({ providedIn: 'root' })
export class DefinitionForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private idValue = '';

  private loadedValue = false;

  private loadingValue = false;

  private savingValue = false;

  private testingValue = false;

  private buffer: EditBuffer = emptyBuffer();

  private loadedRecord: Record<string, unknown> | null = null;

  private providerRows: readonly ProviderRow[] = [];

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  /**
   * The last refusal's machine `code` and, where it named one, the `(resource, permission)` pair
   * that failed (AD-39). Kept beside the envelope's human `reason` rather than instead of it: the
   * page composes the published denied-action sentence over these two and renders the reason for
   * every other code, which is the `error-log.page.ts:297-308` shape.
   */
  private refusalCodeValue = '';

  private refusalPairValue = '';

  /**
   * What each writable field held when the refused request was sent, so a blur can tell a field
   * whose value has moved since from one the refusal still describes (DW-373). Taken at send rather
   * than at arrival: an edit typed while the request was out is not what the refusal judged.
   */
  private refusedValues: Record<string, string> = {};

  private testReply = '';

  private testFailure = '';

  private failureFromProvider = false;

  /** Whether the instance held no definition at all when this form was opened (AC3). */
  private instanceWasEmpty = false;

  /**
   * Set while the route is being replaced with the editor of the definition just created (AC3).
   *
   * **The replacement destroys and re-creates the page**, because `agent/definitions/edit` and
   * `agent/definitions/edit/:id` are two routes over one component. Without this the new component
   * would reset the store and re-read the definition, and the saved sentence the operator was just
   * shown -- and the "Go to Home" offer beside it on a first save -- would be gone before they
   * read it. The create's own 201 body is already the stored truth, so there is nothing to re-read
   * either.
   */
  private retainingValue = false;

  private outcomeValue: SaveOutcome = '';

  private firstSaveValue = false;

  private keyValue = '';

  /** Bumped per issued request, so a late answer to a form the user has left is dropped. */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  id(): string {
    return this.idValue;
  }

  /** Whether this form is creating rather than editing: the route carried no id. */
  creating(): boolean {
    return this.idValue === '';
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  loading(): boolean {
    return this.loadingValue;
  }

  /** Whether a Save or a Test connection sequence is in flight. */
  busy(): boolean {
    return this.savingValue || this.testingValue;
  }

  saving(): boolean {
    return this.savingValue;
  }

  testing(): boolean {
    return this.testingValue;
  }

  value(field: string): string {
    const held = this.buffer[field];
    return typeof held === 'string' ? held : '';
  }

  flag(field: string): boolean {
    return this.buffer[field] === true;
  }

  /** The API key the operator has typed. Held in the buffer, never in the loaded record. */
  key(): string {
    return this.keyValue;
  }

  providers(): readonly ProviderRow[] {
    return this.providerRows;
  }

  /** The catalog row for the provider now selected, or `null`. */
  provider(): ProviderRow | null {
    return this.providerRows.find((row) => row.key === this.value('provider')) ?? null;
  }

  violations(): readonly Violation[] {
    return this.violationList;
  }

  /** The refusal sentence for one field, or `''`. */
  violationFor(field: string): string {
    return reasonForField(this.violationList, field);
  }

  /** The envelope's own `reason` for the last refusal that was not field-level, or `''`. */
  reason(): string {
    return this.envelopeReason;
  }

  /** The last refusal's machine code, or `''`. Never its human reason (AD-39). */
  refusalCode(): string {
    return this.refusalCodeValue;
  }

  /** The `(resource, permission)` pair the last refusal named, or `''`. */
  refusalPair(): string {
    return this.refusalPairValue;
  }

  /**
   * Whether the last refusal was a stale save -- the row moved on the instance after this screen
   * read it (AD-12, AD-39).
   *
   * Its own accessor rather than a comparison spelled in the page, for the reason `refusalPair()`
   * is one: the page composes, the store keeps what the envelope said, and the code is compared
   * against the one exported constant rather than a literal per screen.
   */
  conflicted(): boolean {
    return this.refusalCodeValue === STATE_CONFLICT_CODE;
  }

  /** The provider's first words from the last passing Test connection, or `''`. */
  reply(): string {
    return this.testReply;
  }

  /**
   * What the last Test connection was refused with, or `''`.
   *
   * It is `detail.providerText` where the provider supplied one, and the envelope's own `reason`
   * otherwise. The page decides which published sentence frames it (DW-355).
   */
  failure(): string {
    return this.testFailure;
  }

  /** Whether the last refused Test connection carried the provider's own words (DW-355). */
  failureIsProviderText(): boolean {
    return this.failureFromProvider;
  }

  /** What the sticky bar says after a save, or `''`. */
  outcome(): SaveOutcome {
    return this.outcomeValue;
  }

  /**
   * Whether this save was the first definition ever stored on the instance, which is what adds
   * "Go to Home" beside the saved sentence (AC3).
   */
  firstSave(): boolean {
    return this.firstSaveValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  /**
   * Whether this store is being carried across a route replacement, so the page leaving does not
   * tear it down (AC3).
   */
  retaining(): boolean {
    return this.retainingValue;
  }

  /**
   * Keep this form's state across the one navigation that is not a departure: a create replacing
   * its own route with the new definition's editor.
   */
  retainAcrossRouteReplacement(): void {
    this.retainingValue = true;
  }

  /** Forget everything, from the sign-out teardown and when the form is left. */
  reset(): void {
    this.generation += 1;
    this.idValue = '';
    this.loadedValue = false;
    this.loadingValue = false;
    this.savingValue = false;
    this.testingValue = false;
    this.buffer = emptyBuffer();
    this.loadedRecord = null;
    this.violationList = [];
    this.envelopeReason = '';
    this.refusalCodeValue = '';
    this.refusalPairValue = '';
    this.refusedValues = {};
    this.testReply = '';
    this.testFailure = '';
    this.failureFromProvider = false;
    this.outcomeValue = '';
    this.firstSaveValue = false;
    this.instanceWasEmpty = false;
    this.retainingValue = false;
    this.keyValue = '';
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form for `id`, or for a create when `id` is `''`.
   *
   * The catalog is read on every open rather than cached: it is a small table, the read is gated
   * like every other, and a cached copy is a second source for the values the cascade fills in.
   */
  async open(id: string): Promise<void> {
    // The route replacement a create makes is not an arrival at another form: the state on screen
    // is this definition's, already read from the create's own answer (AC3).
    if (this.retainingValue && id !== '' && id === this.idValue) {
      this.retainingValue = false;
      return;
    }
    this.retainingValue = false;
    this.reset();
    const generation = this.generation;
    this.idValue = id;
    this.loadingValue = true;
    this.notify();

    await this.loadProviders(generation);
    if (generation !== this.generation) return;

    if (id === '') {
      this.instanceWasEmpty = await this.instanceHoldsNoDefinition(generation);
      if (generation !== this.generation) return;
      this.applyProviderDefaults(this.providerRows[0]?.key ?? '');
      this.loadingValue = false;
      this.loadedValue = true;
      this.notify();
      return;
    }

    const result = await this.api().requestJson<unknown>(`${AGENT_DEFINITIONS_PATH}/${encodeURIComponent(id)}`);
    if (generation !== this.generation) return;
    this.loadingValue = false;
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.notify();
      return;
    }
    this.absorb(result.body);
    this.loadedValue = true;
    this.notify();
  }

  /** Type into one text field. */
  setValue(field: string, value: string): void {
    if (this.buffer[field] === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.clearFieldViolation(field);
    this.markDirty();
    this.notify();
  }

  /** Tick one flag. */
  setFlag(field: string, value: boolean): void {
    if (this.buffer[field] === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.clearFieldViolation(field);
    this.markDirty();
    this.notify();
  }

  /**
   * Choose a provider, cascading that catalog row's canonical values into the model, endpoint,
   * maximum tokens, temperature and the two credential-naming fields (AD-5: the catalog is the one
   * table). The cascade overwrites whatever those fields held, because the row it came from no
   * longer applies; the fields the catalog says nothing about are left alone.
   */
  setProvider(key: string): void {
    if (this.value('provider') === key) return;
    this.applyProviderDefaults(key);
    this.clearFieldViolation('provider');
    // The cascade rewrites the two credential-naming fields as well, and neither renders a control
    // -- so no blur can ever reach `dropStaleViolation` for them, and a refusal the cascade has
    // just made untrue would stand in the summary with no way to clear it but another Save. The
    // four rewritten fields that DO render a control keep their violations until the reader blurs
    // them, which is where they can see what replaced the value.
    for (const field of CASCADE_ONLY_FIELDS) this.clearFieldViolation(field);
    this.markDirty();
    this.notify();
  }

  /**
   * Hold the pasted key. `(paste)` is untouched and nothing is trimmed (DW-340): a key the
   * operator pasted with a stray space is a key the server refuses by shape, which is a sentence
   * they can act on, where a client that silently trimmed would store something they never saw.
   */
  setKey(value: string): void {
    if (this.keyValue === value) return;
    this.keyValue = value;
    this.clearFieldViolation('apiKey');
    this.markDirty();
    this.notify();
  }

  /**
   * The inline key-shape check, run on blur (DW-339).
   *
   * It compares the pasted key against the catalog row's own `keyPrefix` and renders
   * `AGENT.KEY.SHAPE` on the same field, through the same violation list the server's refusal
   * lands in -- so the inline check and the server refusal are one presentation rather than two.
   * The sentence is the server's, taken from the catalog row that supplies the prefix.
   */
  checkKeyShape(): void {
    if (this.keyValue === '') return;
    const row = this.provider();
    if (row === null || row.keyPrefix === '') return;
    if (this.keyValue.startsWith(row.keyPrefix)) return;
    this.violationList = [
      ...this.violationList.filter((entry) => entry.field !== 'apiKey'),
      { field: 'apiKey', code: KEY_SHAPE_CODE, reason: row.keyShapeReason },
    ];
    this.notify();
  }

  /**
   * On blur: drop a refusal that no longer describes what the field holds (DW-373, AC8).
   *
   * **The comparison is against the values the refusal arrived over**, not against whatever the
   * field held a moment ago, so a value edited and then typed back is still described by the
   * refusal and keeps it. Nothing is added here -- a field-level sentence is written once on the
   * server (AD-39) and the client has none to invent -- so the only outcome is a stale one going.
   *
   * It is the blur-time guarantee, not the only path: `setValue`, `setFlag`, `setProvider` and
   * `setKey` each drop their own field's violation as the value moves. The gap it closes is the
   * cascade -- `setProvider` rewrites model, endpoint, maximum tokens and temperature beside its
   * own field, so a refusal on any of those four would otherwise stand over a value the form
   * itself replaced. The two the cascade also rewrites and no control can blur, `credentialName`
   * and `envVarName`, are cleared by `setProvider` instead.
   */
  dropStaleViolation(field: string): void {
    const refused = this.refusedValues[field];
    if (refused === undefined) return;
    const now = field === 'apiKey'
      ? this.keyValue
      : BOOLEAN_FIELDS.includes(field)
        ? String(this.flag(field))
        : this.value(field);
    if (now === refused) return;
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.clearFieldViolation(field);
    this.notify();
  }

  /**
   * Save: the whole writable field set to the route the form's mode names (AD-4), and the response
   * body rendered in place of what was sent.
   *
   * A create omits `enabled` entirely: the server forces `connectionVerified` to 0 on a create, and
   * the enable rule refuses `enabled: true` against it, so sending the flag would refuse the one
   * save that has to succeed.
   */
  async save(): Promise<boolean> {
    if (this.busy()) return false;
    const generation = this.generation;
    const creating = this.creating();
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.outcomeValue = '';
    this.notify();

    const sent = this.snapshotValues();
    const result = creating
      ? await this.post(AGENT_DEFINITIONS_PATH, this.body({ omitEnabled: true }))
      : await this.put(`${AGENT_DEFINITIONS_PATH}/${encodeURIComponent(this.idValue)}`, this.body({}));
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (!this.absorbAnswer(result, sent)) {
      this.notify();
      return false;
    }
    if (creating) this.firstSaveValue = this.instanceWasEmpty;
    this.outcomeValue = flagAt(this.loadedRecord, 'enabled') ? 'saved' : 'pending-test';
    // A key the operator pasted is NOT part of this body -- it travels on its own route -- so a
    // save that succeeds leaves it unstored, and clearing the dirty flag over it would let the
    // leave guard wave them off the page and drop it without a word (DW-340, AC2).
    this.formDirty.setDirty(this.keyValue !== '');
    this.publishChange();
    this.notify();
    return true;
  }

  /**
   * Test connection, which on a create route is three requests and one outcome (DW-354).
   *
   * The routes impose the order and the form does not surface it as a chore: `POST :id/credential`
   * opens the row first and 404s before it reads a body, so a key cannot be stored before an id
   * exists; a create forces the definition unverified; only a passing test clears that. So the
   * sequence is create disabled, store the key, test -- one progress indicator across all three,
   * and the sequence stops at the first fault, which renders under the button.
   *
   * `connectionVerified` in the answer is **ignored** (DW-359): it is read from the stored row and
   * is true beside `testedAsStored: false` for a definition tested with an edited endpoint. The
   * sentence describes the call just made; the row's verification is re-read afterwards.
   */
  async testConnection(): Promise<boolean> {
    if (this.busy()) return false;
    const generation = this.generation;
    this.testingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.testReply = '';
    this.testFailure = '';
    this.failureFromProvider = false;
    this.notify();

    const finish = (ok: boolean): boolean => {
      if (generation !== this.generation) return false;
      this.testingValue = false;
      this.notify();
      return ok;
    };

    if (this.creating()) {
      const sentToCreate = this.snapshotValues();
      const created = await this.post(AGENT_DEFINITIONS_PATH, this.body({ omitEnabled: true }));
      if (generation !== this.generation) return false;
      if (!this.absorbAnswer(created, sentToCreate)) return finish(false);
      this.formDirty.setDirty(false);
      this.outcomeValue = 'pending-test';
      // The gate's own path stores the first definition here rather than through Save, so the
      // "first successful definition Save" offer is set where that save actually happens (AC3,
      // EXPERIENCE.md's sticky-bar row). Save on the editor this replaces the route with runs
      // with `creating` false and no longer clears it.
      this.firstSaveValue = this.instanceWasEmpty;
      this.publishChange();
    }

    if (this.keyValue !== '') {
      const sentToStore = this.snapshotValues();
      const stored = await this.post(
        `${AGENT_DEFINITIONS_PATH}/${encodeURIComponent(this.idValue)}/credential`,
        { apiKey: this.keyValue }
      );
      if (generation !== this.generation) return false;
      if (stored.kind !== 'ok') {
        this.absorbRefusal(stored, sentToStore);
        return finish(false);
      }
      // Write-only: the field is cleared the moment the instance has it (DW-340).
      this.keyValue = '';
    }

    const sentToTest = this.snapshotValues();
    const tested = await this.post(`${AGENT_DEFINITIONS_PATH}/${encodeURIComponent(this.idValue)}/test`, {});
    if (generation !== this.generation) return false;
    if (tested.kind !== 'ok') {
      this.absorbTestRefusal(tested, sentToTest);
      return finish(false);
    }
    this.testReply = textAt(tested.body, 'reply');
    // The row's own verification, re-read: the test body's `connectionVerified` describes the
    // stored row rather than the values just tested (DW-359). Skipped while the buffer holds
    // unsaved edits -- re-reading rewrites every field from the stored record, which would revert
    // the operator's work under them and leave the dirty flag standing over changes that are no
    // longer on screen.
    if (!this.formDirty.dirty()) await this.reload();
    return finish(true);
  }

  /** Re-read the definition, so what is on screen is the stored truth after a write. */
  async reload(): Promise<void> {
    if (this.idValue === '') return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(
      `${AGENT_DEFINITIONS_PATH}/${encodeURIComponent(this.idValue)}`
    );
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') return;
    this.absorb(result.body);
    this.notify();
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

  private publishChange(): void {
    if (this.idValue === '') return;
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: AGENT_DEFINITION_ENTITY,
      scope: AGENT_DEFINITION_SCOPE,
      id: this.idValue,
    });
  }

  private post(path: string, body: Record<string, unknown>): Promise<JsonResult<unknown>> {
    return this.api().requestJson<unknown>(path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
  }

  private put(path: string, body: Record<string, unknown>): Promise<JsonResult<unknown>> {
    return this.api().requestJson<unknown>(path, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
  }

  /**
   * Whether the instance holds no definition at all, read once when a create form opens (AC3).
   *
   * "The first successful definition Save" is a fact about the instance before the save, so it is
   * observed before the create rather than inferred from the answer -- the create's own response
   * says nothing about what was there before it. The ungated selection list is the read, which is
   * the one route a caller who is about to create a definition certainly holds.
   */
  private async instanceHoldsNoDefinition(generation: number): Promise<boolean> {
    const result = await this.api().requestJson<unknown>(AGENT_DEFINITIONS_PATH);
    if (generation !== this.generation || result.kind !== 'ok') return false;
    const raw = result.body;
    const rows = raw !== null && typeof raw === 'object' ? (raw as Record<string, unknown>)['definitions'] : null;
    return Array.isArray(rows) && rows.length === 0;
  }

  private async loadProviders(generation: number): Promise<void> {
    const result = await this.api().requestJson<unknown>(AGENT_PROVIDERS_PATH);
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') return;
    const raw = result.body;
    const rows = raw !== null && typeof raw === 'object' ? (raw as Record<string, unknown>)['providers'] : null;
    if (!Array.isArray(rows)) return;
    this.providerRows = rows.map((row) => ({
      key: textAt(row, 'key'),
      label: textAt(row, 'label'),
      defaultModel: textAt(row, 'defaultModel'),
      modelSuggestions: stringsAt(row, 'modelSuggestions'),
      defaultEndpoint: textAt(row, 'defaultEndpoint'),
      endpointRequired: flagAt(row, 'endpointRequired'),
      canonicalMaxTokens: numberAt(row, 'canonicalMaxTokens'),
      canonicalTemperature: numberAt(row, 'canonicalTemperature'),
      defaultEnvVarName: textAt(row, 'defaultEnvVarName'),
      defaultCredentialName: textAt(row, 'defaultCredentialName'),
      keyPrefix: textAt(row, 'keyPrefix'),
      allowsLocal: flagAt(row, 'allowsLocal'),
      keyShapeReason: textAt(row, 'keyShapeReason'),
    }));
  }

  /** Fill the cascade from one catalog row. */
  private applyProviderDefaults(key: string): void {
    const row = this.providerRows.find((candidate) => candidate.key === key) ?? null;
    const next: EditBuffer = { ...this.buffer, provider: key };
    if (row !== null) {
      next['model'] = row.defaultModel;
      next['endpointUrl'] = row.defaultEndpoint;
      next['maxTokens'] = String(row.canonicalMaxTokens);
      next['temperature'] = String(row.canonicalTemperature);
      next['credentialName'] = row.defaultCredentialName;
      next['envVarName'] = row.defaultEnvVarName;
      // The three local-model fields are licensed by the row's own `allowsLocal`, and the form
      // renders their controls only for a row that sets it -- so a cascade onto a row that does
      // not has to clear them here. Left standing, a `credType` of `none` carried over from the
      // compatible row would be refused by rule 5 with no control on screen to change it.
      if (!row.allowsLocal) {
        next['markedLocal'] = false;
        next['httpAcknowledged'] = false;
        if (next['credType'] === CRED_TYPE_NONE) next['credType'] = CRED_TYPE_CREDS;
      }
    }
    this.buffer = next;
  }

  /** The complete writable field set, typed as the wire expects (AD-4). */
  private body(options: { omitEnabled?: boolean }): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of WRITABLE_FIELDS) {
      if (field === 'enabled' && options.omitEnabled === true) continue;
      if (BOOLEAN_FIELDS.includes(field)) {
        out[field] = this.flag(field);
        continue;
      }
      if (NUMBER_FIELDS.includes(field)) {
        const text = this.value(field);
        // A value that is not a number at all is sent as the text the operator typed, so the
        // server's own rule names the field rather than the client inventing a refusal for it.
        out[field] = text !== '' && Number.isFinite(Number(text)) ? Number(text) : text;
        continue;
      }
      out[field] = this.value(field);
    }
    return out;
  }

  /** Absorb one write's answer, and report whether it succeeded. `sent` is the fields as the request carried them. */
  private absorbAnswer(result: JsonResult<unknown>, sent: Record<string, string>): boolean {
    if (result.kind !== 'ok') {
      this.absorbRefusal(result, sent);
      return false;
    }
    this.absorb(result.body);
    return true;
  }

  private absorbRefusal(result: JsonResult<unknown>, sent: Record<string, string>): void {
    this.violationList = violationsOf(result);
    this.envelopeReason =
      this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
    this.rememberRefusal(result, sent);
  }

  /**
   * Keep the refusal's machine `code`, the pair it named and the values the fields held when the
   * refused request was sent (AD-39, DW-372, DW-373).
   *
   * The pair travels in the envelope's structured `detail`, which is an untyped record, so it is
   * narrowed rather than cast -- a `failedPair` that is not a string leaves the slot empty and the
   * page falls back to the envelope's own reason rather than rendering a sentence with a hole in
   * it.
   */
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

  /**
   * The same memory, minus the code and the pair, for a refused **Test connection**.
   *
   * A blur still needs to know what each field held when the refused request was sent, so the values are
   * kept. The code and the pair are not: the page composes them into the published denied-action
   * sentence with **this screen's save phrase** ("change this definition"), and a test that was
   * refused for privilege did not try to change anything. Rendering it would put a second banner
   * on the screen, describing an action nobody took, over a `Test connection` failure line that
   * already says what happened.
   */
  private rememberRefusedValues(result: JsonResult<unknown>, sent: Record<string, string>): void {
    if (result.kind !== 'error') {
      this.clearRefusal();
      return;
    }
    this.refusedValues = sent;
  }

  private clearRefusal(): void {
    this.envelopeReason = '';
    this.refusalCodeValue = '';
    this.refusalPairValue = '';
    this.refusedValues = {};
  }

  /** Every writable field's current text, plus the key, as one flat record. */
  private snapshotValues(): Record<string, string> {
    const out: Record<string, string> = {};
    for (const field of WRITABLE_FIELDS) {
      out[field] = BOOLEAN_FIELDS.includes(field) ? String(this.flag(field)) : this.value(field);
    }
    out['apiKey'] = this.keyValue;
    return out;
  }

  /**
   * A refused Test connection. `PROVIDER.REFUSED` with the provider's own words is the one case
   * the published failure sentence is written around; every other code renders the envelope's own
   * `reason`, verbatim (DW-355).
   */
  private absorbTestRefusal(result: JsonResult<unknown>, sent: Record<string, string>): void {
    this.violationList = violationsOf(result);
    this.rememberRefusedValues(result, sent);
    if (this.violationList.length > 0) return;
    if (result.kind !== 'error') return;
    const text = result.detail === null ? undefined : result.detail['providerText'];
    if (result.code === 'PROVIDER.REFUSED' && typeof text === 'string' && text !== '') {
      this.testFailure = text;
      this.failureFromProvider = true;
      return;
    }
    // Before the envelope's own reason, for the reason the two pages test `conflicted()` before
    // theirs: a row that moved while the provider call was out answers STATE.CONFLICT here as
    // well as on save, and the server's sentence says "the save was refused" on a screen where
    // nobody pressed Save.
    if (result.code === STATE_CONFLICT_CODE) {
      this.testFailure = STRINGS.formStaleSave;
      this.failureFromProvider = false;
      return;
    }
    this.testFailure = result.reason ?? '';
    this.failureFromProvider = false;
  }

  /** Fill the buffer from a response body. The only path that writes the loaded record. */
  private absorb(body: unknown): void {
    const record = body !== null && typeof body === 'object' ? (body as Record<string, unknown>) : {};
    this.loadedRecord = record;
    const id = textAt(record, 'id');
    if (id !== '') this.idValue = id;
    const next: EditBuffer = {};
    for (const field of WRITABLE_FIELDS) {
      next[field] = BOOLEAN_FIELDS.includes(field) ? flagAt(record, field) : textAt(record, field);
    }
    this.buffer = next;
    this.loadedValue = true;
    // The key is deliberately NOT touched here. No body carries one -- nothing could fill it
    // (AD-35) -- and clearing it would drop a pasted key on the create that Test connection makes
    // just before it stores that very key (DW-354). It is cleared where it is actually spent: on
    // `open()`, on `reset()`, and the moment the credential route has taken it (DW-340).
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/**
 * The machine code the inline key-shape check reports under -- the same one the server's own
 * refusal carries, so the two are one presentation on one field (DW-339, AD-39). The sentence
 * beside it is the catalog row's `keyShapeReason`, written on the server.
 */
export const KEY_SHAPE_CODE = 'AGENT.KEY.SHAPE';

function emptyBuffer(): EditBuffer {
  const out: EditBuffer = {};
  for (const field of WRITABLE_FIELDS) out[field] = BOOLEAN_FIELDS.includes(field) ? false : '';
  // The class's own defaults, so a create starts on values the rules accept rather than on
  // empties the first Save would refuse.
  out['credType'] = CRED_TYPE_CREDS;
  out['readOnly'] = true;
  out['retentionDays'] = '30';
  out['maxIterationsPerTurn'] = '10';
  return out;
}

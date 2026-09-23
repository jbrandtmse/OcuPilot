import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the editor saves through: `POST` creates, `PUT <path>/<id>` edits. */
export const RESOURCES_PATH = '/api/ocupilot/resources';

/** The editor's form read: the rules, their sentences, the letter rules and, with a name, the resource. */
export const RESOURCES_FORM_PATH = `${RESOURCES_PATH}/form`;

/** The blur check: whether a name is taken, and whether a public permission on it is privileged. */
export const RESOURCES_NAME_PATH = `${RESOURCES_PATH}/name`;

/** The entity type and scope every change this editor publishes carries (AD-13, AD-14). */
export const RESOURCE_ENTITY = 'resource';

export const RESOURCE_SCOPE = 'instance';

/** The three fields, in the classic dialog's order. */
export const NAME_FIELD = 'Name';

export const DESCRIPTION_FIELD = 'Description';

export const PUBLIC_PERMISSION_FIELD = 'PublicPermission';

/** The permission letters, in the order the vendor writes them. */
export const PERMISSION_LETTERS = 'RWU';

/** The machine code the blur look-up reports a taken name under -- the server's own (AD-39). */
export const NAME_TAKEN_CODE = 'RESOURCE.NAME.TAKEN';

/** The machine code of the required-name rule the form read ships, rendered on blur of an empty name. */
export const NAME_REQUIRED_CODE = 'RESOURCE.NAME.REQUIRED';

/** What the dialog is doing: nothing, creating a resource, or editing the one it names. */
export type EditorMode = 'closed' | 'create' | 'edit';

/** One rule the server applies, with the sentence it refuses with (AD-39). */
export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** The server's letter rule: the first prefix a name begins with decides, else `letters`. */
export interface LetterRules {
  readonly letters: string;
  readonly prefixes: readonly { readonly prefix: string; readonly letters: string }[];
}

interface Values {
  readonly name: string;
  readonly description: string;
  readonly letters: string;
}

const EMPTY_VALUES: Values = { name: '', description: '', letters: '' };

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : '';
}

function arrayAt(source: unknown, key: string): readonly unknown[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value : [];
}

/** `letters` reduced to the distinct letters of `PERMISSION_LETTERS` it carries, in that order. */
export function canonicalLetters(letters: string): string {
  const upper = letters.toUpperCase();
  return [...PERMISSION_LETTERS].filter((letter) => upper.includes(letter)).join('');
}

/**
 * The letters `rules` admit for resource `name`: the first prefix it begins with, compared without
 * regard to case, decides. The rule is the server's, shipped as data; this only applies it.
 */
export function admittedLetters(rules: LetterRules, name: string): string {
  const upper = name.toUpperCase();
  const entry = rules.prefixes.find((candidate) => upper.startsWith(candidate.prefix.toUpperCase()));
  return canonicalLetters(entry === undefined ? rules.letters : entry.letters);
}

/**
 * The resource editor's store (AD-4, AD-19, AD-55): one dialog over the Resources list, in create
 * or edit mode.
 *
 * **It composes no payload the server does not resolve.** `POST /resources` and
 * `PUT /resources/<id>` resolve the same tool classes the agent's `permissions.resources.create`
 * and `.update` do, and every field sentence is the server's (AD-39). An edit sends only the fields
 * changed since the dialog opened; the server merges them over a fresh read, so a field another
 * party changed since is kept (AD-4).
 *
 * **It marks `FormDirty` on a change and clean on a save or a close**, so the Resources list's
 * leave guard and the dialog's own close ask the one question (AD-11 rule 3).
 *
 * **A public permission on an administrative resource is permitted** (AD-10): the dialog states its
 * consequence while a letter is checked on a name the server marked privileged.
 */
@Injectable({ providedIn: 'root' })
export class ResourceEditor {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: EditorMode = 'closed';

  private values: Values = EMPTY_VALUES;

  private opened: Values = EMPTY_VALUES;

  private rulesValue: readonly FieldRule[] = [];

  private letterRulesValue: LetterRules = { letters: PERMISSION_LETTERS, prefixes: [] };

  private maxLengths: Readonly<Record<string, number>> = {};

  private privilegedValue = false;

  private loadedValue = false;

  private absentValue = false;

  /** Whether an edit holds the resource's fresh read; until it does, nothing is edited or sent. */
  private heldValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private savedValue = false;

  private createdIdValue = '';

  private retainingValue = false;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  mode(): EditorMode {
    return this.modeValue;
  }

  /** The resource an edit is over, or `''`. */
  editedName(): string {
    return this.modeValue === 'edit' ? this.opened.name : '';
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  /** Whether an edit names a resource the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  name(): string {
    return this.values.name;
  }

  description(): string {
    return this.values.description;
  }

  /** The public-permission letters checked now, in `PERMISSION_LETTERS` order. */
  letters(): string {
    return this.values.letters;
  }

  /** The letters the server's rule admits for the name on screen. */
  admitted(): string {
    return admittedLetters(this.letterRulesValue, this.values.name);
  }

  /**
   * Whether Save may send: not while one is in flight, and in edit mode only over a fresh read of the
   * resource, so a read that failed or has not landed never sends a change against blank values.
   */
  canSave(): boolean {
    if (this.savingValue || this.absentValue || this.modeValue === 'closed') return false;
    return this.modeValue === 'create' || this.heldValue;
  }

  /** Whether a public permission on the name on screen grants an administrative privilege (AD-10). */
  privileged(): boolean {
    return this.privilegedValue;
  }

  /** Whether the dialog states the privileged-grant consequence: a letter is checked on a privileged name. */
  showsPrivilegedEffect(): boolean {
    return this.privilegedValue && this.values.letters !== '';
  }

  maxLength(field: string): number {
    const held = this.maxLengths[field];
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

  saved(): boolean {
    return this.savedValue;
  }

  /** The created resource's id, or `''`. */
  createdId(): string {
    return this.createdIdValue;
  }

  /** The created resource's id, once: the page follows it with one route replacement. */
  takeCreatedId(): string {
    const id = this.createdIdValue;
    this.createdIdValue = '';
    return id;
  }

  /** Whether the editor is carried across a create's own route replacement. */
  retaining(): boolean {
    return this.retainingValue;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything and close: from a close the user confirmed, and the sign-out teardown. */
  reset(): void {
    this.generation += 1;
    this.modeValue = 'closed';
    this.values = EMPTY_VALUES;
    this.opened = EMPTY_VALUES;
    this.rulesValue = [];
    this.maxLengths = {};
    this.privilegedValue = false;
    this.loadedValue = false;
    this.absentValue = false;
    this.heldValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.createdIdValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /** Open the dialog in create mode, reading the rules the server applies. */
  async openCreate(): Promise<void> {
    this.reset();
    this.modeValue = 'create';
    this.notify();
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(RESOURCES_FORM_PATH);
    if (generation !== this.generation) return;
    this.absorb(result);
    this.loadedValue = true;
    this.notify();
  }

  /**
   * Open the dialog in edit mode over resource `id`, reading it fresh. A create that has just
   * replaced its route with this resource's is not a new arrival: its state is kept.
   */
  async openEdit(id: string): Promise<void> {
    if (this.retainingValue && this.modeValue === 'edit' && this.opened.name.toUpperCase() === id.toUpperCase()) {
      this.retainingValue = false;
      return;
    }
    if (this.modeValue === 'edit' && this.opened.name === id) return;
    this.reset();
    this.modeValue = 'edit';
    this.values = { ...EMPTY_VALUES, name: id };
    this.opened = this.values;
    this.notify();
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${RESOURCES_FORM_PATH}?name=${encodeURIComponent(id)}`);
    if (generation !== this.generation) return;
    this.absorb(result);
    if (result.kind === 'ok') {
      const body = result.body;
      const resource = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['resource'] : null;
      this.values = {
        name: id,
        description: textAt(resource, DESCRIPTION_FIELD),
        letters: canonicalLetters(textAt(resource, PUBLIC_PERMISSION_FIELD)),
      };
      this.opened = this.values;
      // Treated as privileged unless the server sent the flag as false, so the consequence is
      // stated rather than missed.
      const flag = resource !== null && typeof resource === 'object' ? (resource as Record<string, unknown>)['privileged'] : undefined;
      this.privilegedValue = !(flag === false || flag === 0);
      this.heldValue = true;
    } else if (result.kind === 'error' && result.status === 404) {
      this.absentValue = true;
    }
    this.loadedValue = true;
    this.notify();
  }

  /** Set the name; create mode only, since an edit's name is the resource's own. */
  setName(value: string): void {
    if (this.modeValue !== 'create' || this.values.name === value) return;
    this.values = { ...this.values, name: value, letters: this.lettersAdmittedFor(value, this.values.letters) };
    this.clearFieldViolation(NAME_FIELD);
    this.change();
  }

  setDescription(value: string): void {
    if (this.values.description === value || !this.editable()) return;
    this.values = { ...this.values, description: value };
    this.clearFieldViolation(DESCRIPTION_FIELD);
    this.change();
  }

  /** Check or uncheck one public-permission letter. */
  setLetter(letter: string, on: boolean): void {
    if (!this.editable()) return;
    const held = this.values.letters;
    const next = canonicalLetters(on ? held + letter : held.replace(letter, ''));
    if (next === held) return;
    this.values = { ...this.values, letters: next };
    this.clearFieldViolation(PUBLIC_PERMISSION_FIELD);
    this.change();
  }

  /**
   * On blur of the name in create mode: an empty name shows the server's required sentence; any
   * other asks the instance whether it is taken and whether a public permission on it is privileged. A look-up that could not be made leaves the field unmarked and
   * the consequence stated.
   */
  async onNameBlur(): Promise<void> {
    if (this.modeValue !== 'create') return;
    const name = this.values.name;
    if (name === '') {
      this.markEmptyName();
      return;
    }
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${RESOURCES_NAME_PATH}?name=${encodeURIComponent(name)}`);
    if (generation !== this.generation || this.values.name !== name) return;
    if (result.kind !== 'ok') {
      this.privilegedValue = true;
      this.notify();
      return;
    }
    const body = result.body as Record<string, unknown> | null;
    this.privilegedValue = body === null || typeof body !== 'object' ? true : body['privileged'] !== false;
    if (body !== null && typeof body === 'object' && body['taken'] === true) {
      const reason = textAt(body, 'reason');
      if (reason !== '') {
        this.violationList = [
          ...this.violationList.filter((entry) => entry.field !== NAME_FIELD),
          { field: NAME_FIELD, code: NAME_TAKEN_CODE, reason },
        ];
      }
    }
    this.notify();
  }

  /** Keep this editor's state across the one navigation that is not a departure. */
  retainAcrossRouteReplacement(): void {
    this.retainingValue = true;
  }

  /**
   * Ask to close: the shared leave question when a change is held, at once otherwise. `true` means
   * the dialog closed and the editor reset; `false` that the user chose to stay.
   */
  async requestClose(): Promise<boolean> {
    const leave = await this.formDirty.requestLeave();
    if (leave) this.reset();
    return leave;
  }

  /**
   * Save: a create posts the three fields, an edit puts the ones changed since the dialog opened.
   * An accepted Save publishes one change event (AD-14), marks the editor clean and turns a create
   * into an edit of the new resource; a refused one keeps what was entered.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const creating = this.modeValue === 'create';
    if (!creating && Object.keys(this.changedFields()).length === 0) {
      // Nothing changed since the dialog opened or last saved: nothing is written or published.
      this.clearRefusal();
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.notify();

    const result = creating
      ? await this.api().requestJson<unknown>(RESOURCES_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            [NAME_FIELD]: this.values.name,
            [DESCRIPTION_FIELD]: this.values.description,
            [PUBLIC_PERMISSION_FIELD]: this.values.letters,
          }),
        })
      : await this.api().requestJson<unknown>(`${RESOURCES_PATH}/${encodeEntityId(this.opened.name)}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.changedFields()),
        });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.notify();
      return false;
    }
    const id = creating ? textAt(result.body, 'name') || this.values.name : this.opened.name;
    if (creating) {
      this.createdIdValue = id;
      this.modeValue = 'edit';
      this.heldValue = true;
      this.values = { ...this.values, name: id };
    }
    this.opened = this.values;
    this.savedValue = true;
    this.formDirty.setDirty(false);
    this.publish(id, creating ? 'created' : 'updated');
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private change(): void {
    this.savedValue = false;
    this.formDirty.setDirty(true);
    this.notify();
  }

  /** Whether the fields take input: in edit mode only once the fresh read is held. */
  private editable(): boolean {
    return this.modeValue !== 'edit' || this.heldValue;
  }

  /** On blur of an empty name: the server's required-name sentence from the form read, at the field. */
  private markEmptyName(): void {
    const rule = this.rulesValue.find((entry) => entry.field === NAME_FIELD && entry.code === NAME_REQUIRED_CODE);
    if (rule === undefined || this.violationList.some((entry) => entry.field === NAME_FIELD)) return;
    this.violationList = [...this.violationList, { field: NAME_FIELD, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /** The letters of `letters` the rule admits for `name`, so a renamed create sends none it refuses. */
  private lettersAdmittedFor(name: string, letters: string): string {
    const admitted = admittedLetters(this.letterRulesValue, name);
    return [...letters].filter((letter) => admitted.includes(letter)).join('');
  }

  /** The body of an edit: only the fields changed since the dialog opened (AD-4, the server merges). */
  private changedFields(): Record<string, string> {
    const out: Record<string, string> = {};
    if (this.values.description !== this.opened.description) out[DESCRIPTION_FIELD] = this.values.description;
    if (this.values.letters !== this.opened.letters) out[PUBLIC_PERMISSION_FIELD] = this.values.letters;
    return out;
  }

  private absorb(result: JsonResult<unknown>): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
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
    const lengths: Record<string, number> = {};
    const rawLengths = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['maxLengths'] : null;
    if (rawLengths !== null && typeof rawLengths === 'object' && !Array.isArray(rawLengths)) {
      for (const [field, value] of Object.entries(rawLengths as Record<string, unknown>)) {
        if (typeof value === 'number') lengths[field] = value;
      }
    }
    this.maxLengths = lengths;
    const rawRules = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['letterRules'] : null;
    const prefixes: { prefix: string; letters: string }[] = [];
    for (const entry of arrayAt(rawRules, 'prefixes')) {
      const prefix = textAt(entry, 'prefix');
      if (prefix !== '') prefixes.push({ prefix, letters: canonicalLetters(textAt(entry, 'letters')) });
    }
    const letters = canonicalLetters(textAt(rawRules, 'letters'));
    this.letterRulesValue = { letters: letters === '' ? PERMISSION_LETTERS : letters, prefixes };
  }

  private clearFieldViolation(field: string): void {
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
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
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: RESOURCE_ENTITY,
      scope: RESOURCE_SCOPE,
      id,
      action,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

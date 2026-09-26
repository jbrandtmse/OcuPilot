import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import {
  EDIT_FIXED_FIELDS,
  FIELD_ORDER,
  FLAG_FIELDS,
  SETTINGS_FIELD,
  SETTING_PREFIX,
  STEPS,
  type TaskValues,
  changedBody,
  createBody,
  stepOfField,
  valuesFromTask,
} from './task-fields';

/** The routes the wizard reads and saves through. */
export const TASKS_PATH = '/api/ocupilot/tasks';

/** The form read: rules, defaults, a namespace's task types and the tasks to run after. */
export const TASK_FORM_PATH = `${TASKS_PATH}/form`;

/** The step check: every violation of the values so far, at 200 (AD-39). */
export const TASK_CHECK_PATH = `${TASKS_PATH}/check`;

/** The entity type and scope the created task's change event carries (AD-13, AD-14). */
export const TASK_ENTITY = 'task';

export const TASK_SCOPE = 'instance';

/** One setting a task type declares, as the form read answers it. */
export interface TaskSetting {
  readonly name: string;
  readonly label: string;
  readonly kind: string;
  readonly required: boolean;
  readonly default: string;
  readonly options: readonly { readonly value: string; readonly label: string }[];
}

/** One task type a namespace compiles. */
export interface TaskType {
  readonly className: string;
  readonly name: string;
  readonly settings: readonly TaskSetting[];
  readonly classicOnly: readonly string[];
}

/** One task a new one may run after. */
export interface RunAfterTask {
  readonly guid: string;
  readonly id: number;
  readonly name: string;
}

/** One rule the server applies, with the sentence it refuses with (AD-39). */
export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

const EMPTY_VALUES: TaskValues = { text: {}, flags: {}, settings: {} };

function objectAt(source: unknown, key: string): Record<string, unknown> | null {
  if (source === null || typeof source !== 'object') return null;
  const value = (source as Record<string, unknown>)[key];
  return value !== null && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

function arrayAt(source: unknown, key: string): readonly unknown[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value : [];
}

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
  return value === true || value === 1 || value === '1';
}

/**
 * `TimePeriodDay` once the period changes to `period`: that period's own starting value -- no day
 * for Weekly, the 1st for Monthly, the first Sunday for Monthly Special, none otherwise. A held day
 * is never carried over, because each period reads it differently: Weekly's `24` is Monday and
 * Wednesday, Monthly's is the 24th.
 */
function dayFor(period: string): string {
  if (period === 'Monthly') return '1';
  if (period === 'Monthly Special') return '1^1';
  return '';
}

/** The values the form read's `defaults` start the wizard on: no settings until a type is chosen. */
function valuesFrom(defaults: Record<string, unknown> | null): TaskValues {
  return { ...valuesFromTask(defaults), settings: {} };
}

function typesFrom(body: unknown): TaskType[] {
  const types: TaskType[] = [];
  for (const entry of arrayAt(body, 'types')) {
    const className = textAt(entry, 'class');
    if (className === '') continue;
    const settings: TaskSetting[] = [];
    for (const setting of arrayAt(entry, 'settings')) {
      const name = textAt(setting, 'name');
      if (name === '') continue;
      const options = arrayAt(setting, 'options')
        .map((option) => ({ value: textAt(option, 'value'), label: textAt(option, 'label') }))
        .filter((option) => option.value !== '' || option.label !== '');
      settings.push({
        name,
        label: textAt(setting, 'label') || name,
        kind: textAt(setting, 'kind') || 'string',
        required: flagAt(setting, 'required'),
        default: textAt(setting, 'default'),
        options,
      });
    }
    const classicOnly = arrayAt(entry, 'classicOnly').filter((name): name is string => typeof name === 'string');
    types.push({ className, name: textAt(entry, 'name') || className, settings, classicOnly });
  }
  return types;
}

function runAfterFrom(body: unknown): RunAfterTask[] {
  const rows: RunAfterTask[] = [];
  for (const entry of arrayAt(body, 'runAfter')) {
    const guid = textAt(entry, 'guid');
    if (guid === '') continue;
    const id = Number(textAt(entry, 'id'));
    rows.push({ guid, id: Number.isFinite(id) ? id : 0, name: textAt(entry, 'name') });
  }
  return rows;
}

/**
 * The New Task wizard's store (Story 9.7, AD-19, AD-55): the four steps' values, the task types of
 * the chosen namespace, the step check and the create.
 *
 * **It composes no rule of its own.** Next sends the values so far to `POST /tasks/check` and
 * advances only when the current step earns no violation; Create task sends them to `POST /tasks`,
 * which resolves the tool the agent's `tasks.schedule.create` does, and every sentence is the
 * server's (AD-39). The body is the field model's (`task-fields.ts`).
 *
 * **A type's settings follow the type**: choosing a type loads its settings at its own defaults,
 * and the previous type's settings are gone; choosing a namespace reads that namespace's types.
 *
 * **Edit task is its edit mode** (Story 9.8), in `SslForm`'s pattern: `open(id)` reads one task
 * (`GET /tasks/form?id=`) and keeps the `opened` snapshot; Save puts the fields changed since then
 * (`PUT /tasks/:id`) and publishes `task` `updated` with the numeric id; `refresh` re-reads after a
 * change event while the form is clean; a task the instance no longer holds is `absent`. The type
 * and the namespace are fixed, and a type holding a classic-only setting draws no setting.
 */
@Injectable({ providedIn: 'root' })
export class TaskWizard {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private valuesValue: TaskValues = EMPTY_VALUES;

  private typesValue: readonly TaskType[] = [];

  private runAfterValue: readonly RunAfterTask[] = [];

  private rulesValue: readonly FieldRule[] = [];

  private requiredValue: readonly string[] = [];

  private maxLengths: Record<string, number> = {};

  private loadedValue = false;

  private stepValue = STEPS[0];

  private furthestValue = 0;

  private checkingValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private createdIdValue = '';

  /** Whether the store is the wizard's create or Edit task's edit. */
  private modeValue: 'create' | 'edit' = 'create';

  /** The task an edit is of, as the route names it. */
  private idValue = '';

  /** An edit's values as the fresh read answered them, which Save's body is the difference from. */
  private opened: TaskValues = EMPTY_VALUES;

  private savedValue = false;

  private absentValue = false;

  private settingsClassicOnlyValue = false;

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
    return this.checkingValue || this.savingValue;
  }

  values(): TaskValues {
    return this.valuesValue;
  }

  text(field: string): string {
    return this.valuesValue.text[field] ?? '';
  }

  flag(field: string): boolean {
    return this.valuesValue.flags[field] ?? false;
  }

  setting(name: string): string {
    return this.valuesValue.settings[name] ?? '';
  }

  types(): readonly TaskType[] {
    return this.typesValue;
  }

  /** The chosen task type, or `null`. */
  type(): TaskType | null {
    const chosen = this.text('TaskClass');
    return this.typesValue.find((type) => type.className === chosen) ?? null;
  }

  runAfter(): readonly RunAfterTask[] {
    return this.runAfterValue;
  }

  required(field: string): boolean {
    return this.requiredValue.includes(field);
  }

  maxLength(field: string): number {
    const held = this.maxLengths[field];
    return typeof held === 'number' ? held : 0;
  }

  /** The key of the step on screen. */
  step(): string {
    return this.stepValue;
  }

  /** Whether the person may open `step`: one already reached. */
  reachable(step: string): boolean {
    return STEPS.indexOf(step) <= this.furthestValue;
  }

  isLastStep(): boolean {
    return this.stepValue === STEPS[STEPS.length - 1];
  }

  isFirstStep(): boolean {
    return this.stepValue === STEPS[0];
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

  /** The created task's id, or `''`. */
  createdId(): string {
    return this.createdIdValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  /**
   * Whether the task would run as an account other than `user` (AD-10), compared without regard to
   * case. An edit that keeps the account the task already runs as does not (Story 9.8).
   */
  runsAsOther(user: string): boolean {
    const runAs = this.text('RunAsUser').trim();
    if (this.modeValue === 'edit' && runAs.toUpperCase() === (this.opened.text['RunAsUser'] ?? '').trim().toUpperCase()) return false;
    return runAs !== '' && runAs.toUpperCase() !== user.toUpperCase();
  }

  /** `create` for the wizard, `edit` for Edit task. */
  mode(): 'create' | 'edit' {
    return this.modeValue;
  }

  /** The task an edit is of, or `''`. */
  id(): string {
    return this.idValue;
  }

  /** Whether `id` names the task this edit is of. */
  is(id: string): boolean {
    return this.modeValue === 'edit' && this.idValue !== '' && id === this.idValue;
  }

  /** Whether the last Save of an edit was accepted and nothing has changed since. */
  saved(): boolean {
    return this.savedValue;
  }

  /** Whether the task an edit names is not on the instance. */
  absent(): boolean {
    return this.absentValue;
  }

  /** Whether the task's type holds a classic-only setting, so its settings are not drawn (AD-35). */
  settingsClassicOnly(): boolean {
    return this.settingsClassicOnlyValue;
  }

  /** Whether `field` is one an edit draws read-only. */
  fixed(field: string): boolean {
    return this.modeValue === 'edit' && EDIT_FIXED_FIELDS.includes(field);
  }

  /** An edit's body: the fields changed since the fresh read. */
  changedBody(): Record<string, unknown> {
    return changedBody(this.opened, this.valuesValue);
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the wizard is left. */
  reset(): void {
    this.generation += 1;
    this.valuesValue = EMPTY_VALUES;
    this.typesValue = [];
    this.runAfterValue = [];
    this.rulesValue = [];
    this.requiredValue = [];
    this.maxLengths = {};
    this.loadedValue = false;
    this.stepValue = STEPS[0];
    this.furthestValue = 0;
    this.checkingValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.createdIdValue = '';
    this.modeValue = 'create';
    this.idValue = '';
    this.opened = EMPTY_VALUES;
    this.savedValue = false;
    this.absentValue = false;
    this.settingsClassicOnlyValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the wizard on its first step, from the form read made fresh on every open -- or, given a
   * task's `id`, Edit task over that task's own fresh read.
   */
  async open(id = ''): Promise<void> {
    this.reset();
    if (id !== '') {
      this.modeValue = 'edit';
      this.idValue = id;
      this.furthestValue = STEPS.length - 1;
    }
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(id === '' ? TASK_FORM_PATH : `${TASK_FORM_PATH}?id=${encodeURIComponent(id)}`);
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      if (id !== '' && result.kind === 'error' && result.status === 404) this.absentValue = true;
      this.loadedValue = true;
      this.notify();
      return;
    }
    this.absorb(result.body, true);
    this.loadedValue = true;
    this.notify();
  }

  /**
   * Read the task again after a change event (AD-14), in place while the form is clean; while it
   * holds unsaved work nothing typed is overwritten.
   */
  async refresh(): Promise<void> {
    if (this.modeValue !== 'edit' || !this.loadedValue || this.absentValue || this.formDirty.dirty()) return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${TASK_FORM_PATH}?id=${encodeURIComponent(this.idValue)}`);
    if (generation !== this.generation || this.formDirty.dirty()) return;
    if (result.kind !== 'ok') {
      if (result.kind === 'error' && result.status === 404) {
        this.absentValue = true;
        this.notify();
      }
      return;
    }
    this.absorb(result.body, false);
    this.notify();
  }

  /**
   * Save an edit: put the fields changed since the fresh read. A Save that changes nothing sends
   * nothing. An accepted one keeps the values as the new snapshot, shows "Saved", marks the form
   * clean and publishes one `task` `updated` change event with the numeric id (AD-14); a refused one
   * keeps every value.
   */
  async save(): Promise<boolean> {
    if (this.modeValue !== 'edit' || this.busy() || !this.loadedValue || this.absentValue) return false;
    const body = this.changedBody();
    if (Object.keys(body).length === 0) {
      this.clearRefusal();
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
    this.notify();
    const result = await this.api().requestJson<unknown>(`${TASKS_PATH}/${encodeEntityId(this.idValue)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      if (result.kind === 'error' && result.status === 404) this.absentValue = true;
      this.notify();
      return false;
    }
    this.opened = this.valuesValue;
    this.savedValue = true;
    this.formDirty.setDirty(false);
    this.injector.get(ChangeBus).publish({ kind: 'changed', type: TASK_ENTITY, scope: TASK_SCOPE, id: this.idValue, action: 'updated' });
    this.notify();
    return true;
  }

  /**
   * Set one text field. The namespace reads that namespace's task types; the task type loads its
   * own settings at their defaults, dropping the previous type's.
   */
  setText(field: string, value: string): void {
    if (field === SETTINGS_FIELD || FLAG_FIELDS.includes(field) || !FIELD_ORDER.includes(field) || this.fixed(field)) return;
    if (this.text(field) === value) return;
    let settings = this.valuesValue.settings;
    if (field === 'TaskClass') {
      const type = this.typesValue.find((entry) => entry.className === value) ?? null;
      settings = {};
      for (const setting of type?.settings ?? []) settings = { ...settings, [setting.name]: setting.default };
      this.violationList = this.violationList.filter((entry) => !entry.field.startsWith(SETTING_PREFIX));
    }
    let text = { ...this.valuesValue.text, [field]: value };
    if (field === 'TimePeriod') text = { ...text, TimePeriodDay: dayFor(value) };
    this.valuesValue = { ...this.valuesValue, text, settings };
    this.change(field);
    if (field === 'NameSpace') void this.loadTypes(value);
  }

  setFlag(field: string, on: boolean): void {
    if (!FLAG_FIELDS.includes(field) || this.flag(field) === on) return;
    this.valuesValue = { ...this.valuesValue, flags: { ...this.valuesValue.flags, [field]: on } };
    this.change(field);
  }

  setSetting(name: string, value: string): void {
    if (this.settingsClassicOnlyValue || this.type()?.settings.some((setting) => setting.name === name) !== true) return;
    if (this.setting(name) === value) return;
    this.valuesValue = { ...this.valuesValue, settings: { ...this.valuesValue.settings, [name]: value } };
    this.change(`${SETTING_PREFIX}${name}`);
  }

  /** Open a step already reached, keeping every value. */
  goTo(step: string): void {
    if (!STEPS.includes(step) || !this.reachable(step) || step === this.stepValue) return;
    this.stepValue = step;
    this.notify();
  }

  /** Back: the previous step, every value kept. */
  back(): void {
    const index = STEPS.indexOf(this.stepValue);
    if (index <= 0) return;
    this.stepValue = STEPS[index - 1];
    this.notify();
  }

  /**
   * Next: check the values so far on the server and advance only when the current step earns no
   * violation, which is then shown on its fields. Answers whether it advanced.
   */
  async next(): Promise<boolean> {
    if (this.busy() || this.isLastStep()) return false;
    const generation = this.generation;
    const step = this.stepValue;
    this.checkingValue = true;
    this.clearRefusal();
    this.notify();
    const result = await this.api().requestJson<unknown>(TASK_CHECK_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(createBody(this.valuesValue)),
    });
    if (generation !== this.generation) return false;
    this.checkingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.notify();
      return false;
    }
    const mine: Violation[] = [];
    for (const entry of arrayAt(result.body, 'violations')) {
      const field = textAt(entry, 'field');
      const code = textAt(entry, 'code');
      const reason = textAt(entry, 'reason');
      if (field === '' || stepOfField(field) !== step) continue;
      mine.push({ field, code, reason });
    }
    this.violationList = mine;
    if (mine.length > 0) {
      this.notify();
      return false;
    }
    const index = STEPS.indexOf(step) + 1;
    this.stepValue = STEPS[index];
    this.furthestValue = Math.max(this.furthestValue, index);
    this.notify();
    return true;
  }

  /**
   * Create task: send every value. An accepted create publishes one `task` `created` change event
   * with the instance's own id (AD-14) and marks the form clean; a refused one keeps every value.
   */
  async create(): Promise<boolean> {
    if (this.busy()) return false;
    const generation = this.generation;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.notify();
    const result = await this.api().requestJson<unknown>(TASKS_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(createBody(this.valuesValue)),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.furthestValue = STEPS.length - 1;
      this.notify();
      return false;
    }
    const id = textAt(result.body, 'id');
    this.createdIdValue = id;
    this.formDirty.setDirty(false);
    if (id !== '') {
      this.injector.get(ChangeBus).publish({ kind: 'changed', type: TASK_ENTITY, scope: TASK_SCOPE, id, action: 'created' });
    }
    this.notify();
    return true;
  }

  /** Open the step `step`, for a refusal routed there. */
  showStep(step: string): void {
    if (!STEPS.includes(step)) return;
    this.stepValue = step;
    this.notify();
  }

  /**
   * On blur: the checks that need no server -- an empty required field and a value over its
   * length -- in the server's own sentences, from the form read's rules.
   */
  onBlur(field: string): void {
    const value = this.text(field);
    const rules = this.rulesValue.filter((entry) => entry.field === field);
    let rule: FieldRule | undefined;
    if (this.required(field) && value.trim() === '') rule = rules.find((entry) => entry.code.endsWith('.REQUIRED'));
    const bound = this.maxLength(field);
    if (rule === undefined && bound > 0 && value.length > bound) rule = rules.find((entry) => entry.code.endsWith('.LENGTH') || entry.code.endsWith('.SHAPE'));
    if (rule === undefined || this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  // --- internals ------------------------------------------------------------------------------

  /** Take in a form read's body: the rules, the types, the tasks to run after and -- for an edit -- the task. */
  private absorb(body: unknown, replaceRules: boolean): void {
    if (replaceRules) this.absorbRules(body);
    this.typesValue = typesFrom(body);
    this.runAfterValue = runAfterFrom(body);
    if (this.modeValue === 'edit') {
      const task = objectAt(body, 'task');
      if (task === null) {
        this.absentValue = true;
        return;
      }
      const values = valuesFromTask(task);
      this.valuesValue = values;
      this.opened = values;
      this.settingsClassicOnlyValue = flagAt(body, 'settingsClassicOnly');
      return;
    }
    const values = valuesFrom(objectAt(body, 'defaults'));
    const namespace = textAt(body, 'namespace');
    this.valuesValue = namespace === '' ? values : { ...values, text: { ...values.text, NameSpace: namespace } };
  }

  private absorbRules(body: unknown): void {
    const rules: FieldRule[] = [];
    for (const entry of arrayAt(body, 'rules')) {
      const field = textAt(entry, 'field');
      const code = textAt(entry, 'code');
      const reason = textAt(entry, 'reason');
      if (field !== '' && code !== '' && reason !== '') rules.push({ field, code, reason });
    }
    this.rulesValue = rules;
    this.requiredValue = arrayAt(body, 'requiredFields').filter((entry): entry is string => typeof entry === 'string');
    const lengths: Record<string, number> = {};
    for (const [field, value] of Object.entries(objectAt(body, 'maxLengths') ?? {})) {
      if (typeof value === 'number') lengths[field] = value;
    }
    this.maxLengths = lengths;
  }

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private async loadTypes(namespace: string): Promise<void> {
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${TASK_FORM_PATH}?namespace=${encodeURIComponent(namespace)}`);
    if (generation !== this.generation || this.text('NameSpace') !== namespace) return;
    if (result.kind !== 'ok') {
      this.typesValue = [];
      this.violationList = [...this.violationList.filter((entry) => entry.field !== 'NameSpace'), ...violationsOf(result)];
    } else {
      this.typesValue = typesFrom(result.body);
    }
    if (this.type() === null && this.text('TaskClass') !== '') {
      this.valuesValue = { ...this.valuesValue, text: { ...this.valuesValue.text, TaskClass: '' }, settings: {} };
    }
    this.notify();
  }

  private change(field: string): void {
    if (this.violationList.some((entry) => entry.field === field)) {
      this.violationList = this.violationList.filter((entry) => entry.field !== field);
    }
    this.savedValue = false;
    this.formDirty.setDirty(true);
    this.notify();
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

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

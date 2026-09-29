import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the wizard reads and saves through: `POST` creates, `POST <path>/check` checks a step. */
export const DATABASE_PATH = '/api/ocupilot/database';

/** The form read: the rules, their sentences and the `%DB_*` resources the caller may name. */
export const DATABASE_FORM_PATH = `${DATABASE_PATH}/form`;

/** The step check: every violation of one step's values, at 200 (AD-39). */
export const DATABASE_CHECK_PATH = `${DATABASE_PATH}/check`;

/** The entity type and scope a created database's change event carries (AD-13, AD-14). */
export const DATABASE_CONFIGURATION_ENTITY = 'database-configuration';

export const DATABASE_SCOPE = 'instance';

/** The prefix every database resource name carries (Conventions, IRIS security objects). */
export const DATABASE_RESOURCE_PREFIX = '%DB_';

/** The three steps, in order, as the check route names them. */
export const NAME_STEP = 'name';
export const SIZE_STEP = 'size';
export const RESOURCE_STEP = 'resource';
export const DATABASE_STEPS: readonly string[] = [NAME_STEP, SIZE_STEP, RESOURCE_STEP];

/** The fields each step validates, as the server's step check names them. */
export const STEP_FIELDS: Readonly<Record<string, readonly string[]>> = {
  [NAME_STEP]: ['Name', 'root', 'path'],
  [SIZE_STEP]: ['Size', 'GlobalJournalState'],
  [RESOURCE_STEP]: ['ResourceName'],
};

/** Every field, in the wizard's order. */
export const DATABASE_FIELD_ORDER: readonly string[] = DATABASE_STEPS.flatMap((step) => STEP_FIELDS[step]);

/** The step that holds `field`, or `''`. */
export function stepOfDatabaseField(field: string): string {
  return DATABASE_STEPS.find((step) => STEP_FIELDS[step].includes(field)) ?? '';
}

/** Whether the create names its own new resource or an existing one. */
export type ResourceChoice = 'new' | 'existing';

/** The wizard's values, as the fields hold them. */
export interface DatabaseWizardValues {
  readonly Name: string;
  readonly root: string;
  readonly path: string;
  readonly Size: string;
  readonly GlobalJournalState: boolean;
  readonly resourceChoice: ResourceChoice;
  readonly ResourceName: string;
}

const EMPTY_VALUES: DatabaseWizardValues = {
  Name: '',
  root: '',
  path: '',
  Size: '1',
  GlobalJournalState: true,
  resourceChoice: 'new',
  ResourceName: '',
};

/** One rule the server applies, with the sentence it refuses with (AD-39). */
export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : '';
}

function stringsAt(source: unknown, key: string): string[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === 'string' && entry !== '') : [];
}

function arrayAt(source: unknown, key: string): readonly unknown[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value : [];
}

/** A whole number as a JSON number, anything else as the text typed, so the server's rule answers it. */
function sizeValue(text: string): number | string {
  return /^[0-9]{1,9}$/.test(text) ? Number(text) : text;
}

/**
 * The create database wizard's store (Story 18.3, AD-19, AD-55): three steps -- the name and the
 * directory, the size and journaling, and the resource -- over `FormStepper`.
 *
 * **It composes no rule of its own.** Next posts the step's values to `POST /database/check` and
 * advances only when that step earns no violation; Create posts every value to `POST /database`,
 * which resolves the tool the agent's `osmgmt.localdatabases.create` does, and every sentence is the
 * server's (AD-39). The directory is a root and a relative path from the page's picker (AD-21's
 * sixth case): a `root` or `path` refusal -- every `PATH.*` code and `DATABASE.DIRECTORY.INUSE` --
 * is the picker's `rootReason` or `pathReason`.
 *
 * **The path follows the name until it is edited**, lower-cased, so a new database's directory
 * defaults to its name.
 */
@Injectable({ providedIn: 'root' })
export class DatabaseWizard {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private valuesValue: DatabaseWizardValues = EMPTY_VALUES;

  private pathEdited = false;

  private rulesValue: readonly FieldRule[] = [];

  private requiredValue: readonly string[] = [];

  private resourcesValue: readonly string[] = [];

  private resourcesRefusedValue = '';

  private loadedValue = false;

  private stepValue = DATABASE_STEPS[0];

  private furthestValue = 0;

  private checkingValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private createdIdValue = '';

  private readBackValue: ReadBack | null = null;

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

  values(): DatabaseWizardValues {
    return this.valuesValue;
  }

  required(field: string): boolean {
    return this.requiredValue.includes(field);
  }

  /** The `%DB_*` resources an existing-resource create may name, as the form read answered them. */
  resources(): readonly string[] {
    return this.resourcesValue;
  }

  /** The pair a caller lacks to list the resources, or `''` when they were listed. */
  resourcesRefused(): string {
    return this.resourcesRefusedValue;
  }

  /** The resource a new-resource create makes: `%DB_` and the name, upper-cased as the instance stores it. */
  newResourceName(): string {
    return `${DATABASE_RESOURCE_PREFIX}${this.valuesValue.Name.toUpperCase()}`;
  }

  step(): string {
    return this.stepValue;
  }

  reachable(step: string): boolean {
    return DATABASE_STEPS.indexOf(step) <= this.furthestValue;
  }

  isFirstStep(): boolean {
    return this.stepValue === DATABASE_STEPS[0];
  }

  isLastStep(): boolean {
    return this.stepValue === DATABASE_STEPS[DATABASE_STEPS.length - 1];
  }

  violations(): readonly Violation[] {
    return this.violationList;
  }

  /** The refusal sentence on `field` -- `root` and `path` included, which the picker draws. */
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

  /** The created database's name as the instance answered it, or `''`. */
  createdId(): string {
    return this.createdIdValue;
  }

  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the wizard is left. */
  reset(): void {
    this.generation += 1;
    this.valuesValue = EMPTY_VALUES;
    this.pathEdited = false;
    this.rulesValue = [];
    this.requiredValue = [];
    this.resourcesValue = [];
    this.resourcesRefusedValue = '';
    this.loadedValue = false;
    this.stepValue = DATABASE_STEPS[0];
    this.furthestValue = 0;
    this.checkingValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.createdIdValue = '';
    this.readBackValue = null;
    this.formDirty.reset();
    this.notify();
  }

  /** Open the wizard over a fresh form read. */
  async open(): Promise<void> {
    this.reset();
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(DATABASE_FORM_PATH);
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
    } else {
      this.absorb(result.body);
    }
    this.loadedValue = true;
    this.notify();
  }

  /** The name; the path follows it, lower-cased, until the path is edited. */
  setName(value: string): void {
    if (value === this.valuesValue.Name) return;
    const path = this.pathEdited ? this.valuesValue.path : value.toLowerCase();
    this.valuesValue = { ...this.valuesValue, Name: value, path };
    this.change('Name');
  }

  /** The picker's root and relative path. A path that differs from the one held is an edit. */
  setLocation(root: string, path: string): void {
    const held = this.valuesValue;
    if (root === held.root && path === held.path) return;
    if (path !== held.path) this.pathEdited = true;
    this.valuesValue = { ...held, root, path };
    if (root !== held.root) this.clearFieldViolation('root');
    this.change('path');
  }

  setSize(value: string): void {
    if (value === this.valuesValue.Size) return;
    this.valuesValue = { ...this.valuesValue, Size: value };
    this.change('Size');
  }

  setJournal(value: boolean): void {
    if (value === this.valuesValue.GlobalJournalState) return;
    this.valuesValue = { ...this.valuesValue, GlobalJournalState: value };
    this.change('GlobalJournalState');
  }

  /** Create the resource or use an existing one; the existing choice needs the resources listed. */
  setResourceChoice(choice: ResourceChoice): void {
    if (choice === this.valuesValue.resourceChoice) return;
    if (choice === 'existing' && this.resourcesRefusedValue !== '') return;
    this.valuesValue = { ...this.valuesValue, resourceChoice: choice };
    this.change('ResourceName');
  }

  setResourceName(value: string): void {
    if (value === this.valuesValue.ResourceName) return;
    this.valuesValue = { ...this.valuesValue, ResourceName: value };
    this.change('ResourceName');
  }

  /** Open a step already reached, keeping every value. */
  goTo(step: string): void {
    if (!DATABASE_STEPS.includes(step) || !this.reachable(step) || step === this.stepValue) return;
    this.stepValue = step;
    this.notify();
  }

  /** Back: the previous step, every value kept. */
  back(): void {
    const index = DATABASE_STEPS.indexOf(this.stepValue);
    if (index <= 0) return;
    this.stepValue = DATABASE_STEPS[index - 1];
    this.notify();
  }

  /** Open the step `step`, for a refusal routed there. */
  showStep(step: string): void {
    if (!DATABASE_STEPS.includes(step)) return;
    this.stepValue = step;
    this.notify();
  }

  /**
   * Next: post the current step to the check route and advance only when that step earns no
   * violation, which is then shown on its field. Answers whether it advanced.
   */
  async next(): Promise<boolean> {
    if (this.busy() || this.isLastStep()) return false;
    const generation = this.generation;
    const step = this.stepValue;
    this.checkingValue = true;
    this.clearRefusal();
    this.notify();
    const result = await this.api().requestJson<unknown>(DATABASE_CHECK_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ step, values: this.createBody() }),
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
      if (field === '' || code === '' || !STEP_FIELDS[step].includes(field)) continue;
      mine.push({ field, code, reason });
    }
    this.violationList = mine;
    if (mine.length > 0) {
      this.notify();
      return false;
    }
    const index = DATABASE_STEPS.indexOf(step) + 1;
    this.stepValue = DATABASE_STEPS[index];
    this.furthestValue = Math.max(this.furthestValue, index);
    this.notify();
    return true;
  }

  /**
   * Create: post every value. An accepted create publishes one `database-configuration` `created`
   * change event with the instance's own name (AD-14) and marks the form clean; a refused one keeps
   * every value and opens every step, so the page can open the one holding the first refusal.
   */
  async create(): Promise<boolean> {
    if (this.busy()) return false;
    const generation = this.generation;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.readBackValue = null;
    this.notify();
    const result = await this.api().requestJson<unknown>(DATABASE_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(this.createBody()),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.furthestValue = DATABASE_STEPS.length - 1;
      this.notify();
      return false;
    }
    const name = textAt(result.body, 'name') || this.valuesValue.Name.toUpperCase();
    this.createdIdValue = name;
    this.readBackValue = readBackOf((result.body as Record<string, unknown> | null)?.['readBack']);
    this.formDirty.setDirty(false);
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: DATABASE_CONFIGURATION_ENTITY,
      scope: DATABASE_SCOPE,
      id: name,
      action: 'created',
      readBack: this.readBackValue,
    });
    this.notify();
    return true;
  }

  /**
   * On blur: an empty required field takes the form read's own required sentence, never a
   * sentence written here.
   */
  onBlur(field: string): void {
    if (!this.required(field) || field !== 'Name') return;
    if (this.valuesValue.Name.trim() !== '') return;
    const rule = this.rulesValue.find((entry) => entry.field === field && entry.code.endsWith('.REQUIRED'));
    if (rule === undefined || this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  /**
   * The body both routes take: the name, the directory as a root and a path, the size, the journal
   * state, and -- only when an existing resource was chosen -- its name; otherwise the instance
   * creates `%DB_<NAME>`.
   */
  private createBody(): Record<string, unknown> {
    const values = this.valuesValue;
    const body: Record<string, unknown> = {
      Name: values.Name,
      root: values.root,
      path: values.path,
      Size: sizeValue(values.Size),
      GlobalJournalState: values.GlobalJournalState,
    };
    if (values.resourceChoice === 'existing') body['ResourceName'] = values.ResourceName;
    return body;
  }

  private absorb(body: unknown): void {
    const rules: FieldRule[] = [];
    for (const entry of arrayAt(body, 'rules')) {
      const field = textAt(entry, 'field');
      const code = textAt(entry, 'code');
      const reason = textAt(entry, 'reason');
      if (field !== '' && code !== '' && reason !== '') rules.push({ field, code, reason });
    }
    this.rulesValue = rules;
    this.requiredValue = stringsAt(body, 'requiredFields');
    this.resourcesValue = stringsAt(body, 'resources');
    this.resourcesRefusedValue = textAt(body, 'resourcesRefused');
  }

  private change(field: string): void {
    this.clearFieldViolation(field);
    this.formDirty.setDirty(true);
    this.notify();
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

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

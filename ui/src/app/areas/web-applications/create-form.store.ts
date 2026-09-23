import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The route the form creates through, and the one the list reads. */
export const WEB_APPLICATIONS_PATH = '/api/ocupilot/web-applications';

/** The form's own bootstrap read: the rules, their sentences and the instance's own choices. */
export const WEB_APPLICATIONS_FORM_PATH = `${WEB_APPLICATIONS_PATH}/form`;

/** The blur check: whether a name is already taken. A read of the instance, not a validation. */
export const WEB_APPLICATIONS_NAME_PATH = `${WEB_APPLICATIONS_PATH}/name`;

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const WEB_APPLICATION_ENTITY = 'web-application';

export const WEB_APPLICATION_SCOPE = 'instance';

/** The three application types the form's type control offers. */
export const TYPE_CSP = 'csp';
export const TYPE_REST = 'rest';
export const TYPE_PYTHON = 'python';

/** The wire names the form sets, in the order the classic editor draws them. */
export const WRITABLE_FIELDS = [
  'Name',
  'Description',
  'NameSpace',
  'Enabled',
  'DispatchClass',
  'WSGIAppName',
  'WSGICallable',
  'WSGIAppLocation',
  'WSGIType',
  'Recurse',
  'Resource',
  'AutheEnabled',
] as const;

/**
 * The vendor's `AutheEnabled` bit for the Unauthenticated method. The form states that method's
 * effect while it is ticked (DW-1489); the kernel marks a proposal's `consequence` on the same bit.
 */
export const UNAUTHENTICATED_BIT = 64;

/** The fields whose value is a JSON boolean on the wire. */
const BOOLEAN_FIELDS: readonly string[] = ['Enabled', 'Recurse'];

/** The fields a REST application sends and no other type does. */
const REST_FIELDS: readonly string[] = ['DispatchClass'];

/** The fields a Python application sends and no other type does. */
const PYTHON_FIELDS: readonly string[] = [
  'WSGIAppName',
  'WSGICallable',
  'WSGIAppLocation',
  'WSGIType',
];

/** One authentication method the instance offers, as `GET /web-applications/form` projects it. */
export interface AutheMethod {
  readonly bit: number;
  readonly label: string;
}

/** One rule the server applies, with the sentence it refuses with (DW-376, AD-39). */
export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** The bootstrap read's whole answer. */
export interface FormRules {
  readonly authenticationMethods: readonly AutheMethod[];
  /**
   * The bit a create starts on, chosen by the server (`OcuPilot.Area.WebApp.FormRules`).
   *
   * **Not "the first method offered".** The vendor lists the unauthenticated option first and
   * defaults to it, so a form that started on the first offered method would start every create
   * on an application anybody can reach; a form that started on nothing would make the first Save
   * a refusal every time. Which one it is is the instance's answer, never this client's.
   */
  readonly defaultMethod: number;
  readonly requiredFields: readonly string[];
  readonly restFields: readonly string[];
  readonly pythonFields: readonly string[];
  readonly wsgiTypes: readonly string[];
  readonly maxLengths: Readonly<Record<string, number>>;
  readonly rules: readonly FieldRule[];
  /**
   * The fixed directory a Python application's directory name resolves under, as the server
   * computed it for this read (AD-21), or `''`. Display only: the server resolves the name again
   * at the call and sends the resolved directory itself.
   */
  readonly wsgiRoot: string;
}

/** The edit buffer: text for an input, a flag for a checkbox. */
type EditBuffer = Record<string, string | boolean>;

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function arrayAt(source: unknown, key: string): readonly unknown[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value : [];
}

function stringsAt(source: unknown, key: string): readonly string[] {
  return arrayAt(source, key).filter((entry): entry is string => typeof entry === 'string');
}

function emptyBuffer(): EditBuffer {
  const out: EditBuffer = {};
  for (const field of WRITABLE_FIELDS) out[field] = BOOLEAN_FIELDS.includes(field) ? false : '';
  // The vendor's own defaults for the two flags, so a create starts where the classic editor
  // starts rather than on values an operator has to turn back on.
  out['Enabled'] = true;
  out['Recurse'] = true;
  return out;
}

/**
 * The Web application create form's store (AD-19, AD-55).
 *
 * **It composes no payload of its own.** The body it posts is the field set the server's own tool
 * class admits, and `POST /web-applications` resolves that tool for the endpoint, the request
 * type, the settable fields and the prohibited set -- so the screen's Save and the agent's confirm
 * are two callers of one operation. What this store decides is which of those fields the chosen
 * application type sends at all, which is the same decision `%CSP.UI.Portal.Applications.Web`'s
 * radio group makes.
 *
 * **Every field-level sentence is the server's** (AD-39, DW-376). The bootstrap read carries one
 * rule per field with the sentence it refuses with, and a refused Save carries the same shape in
 * `detail.violations[]`; this store renders both through one list and authors none of its own.
 *
 * **Framework-free but injectable**: it lives beside its page rather than in `core/`, so it takes
 * the `Injector` the way `definition-form.store.ts` does and stays a plain subscribable the page
 * mirrors into a signal.
 */
@Injectable({ providedIn: 'root' })
export class WebAppCreateForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private buffer: EditBuffer = emptyBuffer();

  private typeValue: string = TYPE_CSP;

  /** The authentication bits ticked, as a set of bit values. */
  private autheBits: readonly number[] = [];

  private rulesValue: FormRules = {
    authenticationMethods: [],
    defaultMethod: 0,
    requiredFields: [],
    restFields: REST_FIELDS,
    pythonFields: PYTHON_FIELDS,
    wsgiTypes: [],
    maxLengths: {},
    rules: [],
    wsgiRoot: '',
  };

  private loadedValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private refusedValues: Record<string, string> = {};

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

  loaded(): boolean {
    return this.loadedValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  value(field: string): string {
    const held = this.buffer[field];
    return typeof held === 'string' ? held : '';
  }

  flag(field: string): boolean {
    return this.buffer[field] === true;
  }

  /** The application type chosen, which decides which fields the body carries. */
  type(): string {
    return this.typeValue;
  }

  rules(): FormRules {
    return this.rulesValue;
  }

  /** Whether the authentication bit `bit` is ticked. */
  autheChecked(bit: number): boolean {
    return this.autheBits.includes(bit);
  }

  /** Whether the Unauthenticated method is ticked, which the form states the effect of (DW-1489). */
  unauthenticated(): boolean {
    return this.autheChecked(UNAUTHENTICATED_BIT);
  }

  /**
   * The directory the typed application directory name resolves to on this instance, for display:
   * the bootstrap read's `wsgiRoot` followed by the name and a separator, or `''` while the read
   * published no root. It is not validated here and never sent; the server resolves the name.
   */
  resolvedDirectory(): string {
    const root = this.rulesValue.wsgiRoot;
    if (root === '') return '';
    const name = this.value('WSGIAppLocation');
    return name === '' ? root : `${root}${name}/`;
  }

  /** The mask the ticked methods add up to, which is what the body sends. */
  autheMask(): number {
    return this.autheBits.reduce((total, bit) => total + bit, 0);
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

  /** Whether the last Save was accepted, which is what the sticky bar's caption reads. */
  saved(): boolean {
    return this.savedValue;
  }

  /** The created application's id, or `''`. */
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

  /**
   * Whether `field` is one the chosen type sends at all.
   *
   * **The lists are the server's** (`conditionalFields` on the bootstrap read), not this file's:
   * which fields a REST or a Python application uses is the instance's answer, and a second copy
   * here is the hand-transcribed field list AD-3 exists to prevent. `REST_FIELDS` and
   * `PYTHON_FIELDS` are the fallback `absorbRules` supplies when the read answered neither, so a
   * form drawn before the read lands sends nothing it should not.
   */
  sends(field: string): boolean {
    if (this.rulesValue.restFields.includes(field)) return this.typeValue === TYPE_REST;
    if (this.rulesValue.pythonFields.includes(field)) return this.typeValue === TYPE_PYTHON;
    return true;
  }

  /** Whether `field` is one a Save must carry, for the chosen type. */
  required(field: string): boolean {
    if (this.rulesValue.requiredFields.includes(field)) return true;
    if (this.typeValue === TYPE_REST) return this.rulesValue.restFields.includes(field);
    if (this.typeValue === TYPE_PYTHON) {
      return this.rulesValue.pythonFields.includes(field) && field !== 'WSGICallable';
    }
    return false;
  }

  /** The length `field` stores on this instance, or `0` when the instance declares none. */
  maxLength(field: string): number {
    const held = this.rulesValue.maxLengths[field];
    return typeof held === 'number' ? held : 0;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything, from the sign-out teardown and when the form is left. */
  reset(): void {
    this.generation += 1;
    this.buffer = emptyBuffer();
    this.typeValue = TYPE_CSP;
    this.autheBits = [];
    this.loadedValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.createdIdValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form: read the rules the server applies, and start on the instance's own defaults.
   *
   * The rules are read on every open rather than cached. They are a small table, the read is gated
   * like every other, and a cached copy is a second source for the sentences the server owns.
   */
  async open(): Promise<void> {
    // A create that has replaced its own route with the new application's editor is not an
    // arrival at another form: the state on screen is that application's.
    if (this.retainingValue) {
      this.retainingValue = false;
      return;
    }
    this.reset();
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(WEB_APPLICATIONS_FORM_PATH);
    if (generation !== this.generation) return;
    if (result.kind === 'ok') {
      this.rulesValue = absorbRules(result.body);
      // The instance's own choice, never this client's -- see `FormRules.defaultMethod`.
      if (this.rulesValue.defaultMethod > 0) this.autheBits = [this.rulesValue.defaultMethod];
    } else {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, {});
    }
    this.loadedValue = true;
    this.notify();
  }

  setValue(field: string, value: string): void {
    if (this.buffer[field] === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.clearFieldViolation(field);
    this.markDirty();
    this.notify();
  }

  setFlag(field: string, value: boolean): void {
    if (this.buffer[field] === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.clearFieldViolation(field);
    this.markDirty();
    this.notify();
  }

  /**
   * Choose the application type. The fields the other types own keep their values -- an operator
   * who switches back finds what they typed -- but they are not sent, and their refusals go,
   * because a refusal on a field this body no longer carries stands over nothing.
   */
  setType(type: string): void {
    if (this.typeValue === type) return;
    this.typeValue = type;
    for (const field of [...REST_FIELDS, ...PYTHON_FIELDS]) {
      if (!this.sends(field)) this.clearFieldViolation(field);
    }
    if (type === TYPE_PYTHON && this.value('WSGIType') === '') {
      const first = this.rulesValue.wsgiTypes[0];
      if (first !== undefined) this.buffer = { ...this.buffer, WSGIType: first };
    }
    this.markDirty();
    this.notify();
  }

  /** Tick or untick one authentication method. */
  setAuthe(bit: number, on: boolean): void {
    const held = this.autheChecked(bit);
    if (held === on) return;
    this.autheBits = on
      ? [...this.autheBits, bit]
      : this.autheBits.filter((entry) => entry !== bit);
    this.clearFieldViolation('AutheEnabled');
    this.markDirty();
    this.notify();
  }

  /**
   * On blur: drop a refusal that no longer describes what the field holds, and -- for the name
   * alone -- ask the instance whether it is still free (DW-376).
   *
   * Nothing is authored here. The taken-name sentence is the server's, carried on the look-up's
   * own answer, and a look-up that could not be made leaves the field unmarked rather than
   * asserting availability.
   */
  async onBlur(field: string): Promise<void> {
    this.dropStaleViolation(field);
    this.markEmptyRequired(field);
    if (field !== 'Name') return;
    const name = this.value('Name');
    if (name === '') return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(
      `${WEB_APPLICATIONS_NAME_PATH}?name=${encodeURIComponent(name)}`
    );
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') return;
    if (this.value('Name') !== name) return;
    const body = result.body;
    const available = body !== null && typeof body === 'object'
      ? (body as Record<string, unknown>)['available'] === true
      : true;
    if (available) return;
    const reason = textAt(body, 'reason');
    if (reason === '') return;
    this.violationList = [
      ...this.violationList.filter((entry) => entry.field !== 'Name'),
      { field: 'Name', code: NAME_TAKEN_CODE, reason },
    ];
    this.notify();
  }

  /**
   * Render the server's own sentence on a required field the operator left empty (DW-376, AD-39).
   *
   * **It is the bootstrap read's rule, not a sentence authored here.** `GET /web-applications/form`
   * publishes one `{field, code, reason}` per rule the server applies, and this renders the
   * field's first, which is its required-ness rule (`FormRules.Rules` lists that one first) -- the
   * same wording a refused Save would carry, without a save and without a validate-only route. A field the read
   * published no rule for renders nothing, which is the fail-closed direction: an empty sentence
   * on a field is worse than none.
   */
  private markEmptyRequired(field: string): void {
    if (field === 'Name') return;
    if (!this.sends(field)) return;
    if (!this.required(field)) return;
    if (this.currentText(field) !== '') return;
    const rule = this.rulesValue.rules.find((entry) => entry.field === field);
    if (rule === undefined) return;
    if (this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /**
   * Drop a refusal that no longer describes what the field holds (DW-373). The comparison is
   * against the value the refusal arrived over, so a value edited and typed back keeps it.
   */
  dropStaleViolation(field: string): void {
    const refused = this.refusedValues[field];
    if (refused === undefined) return;
    if (this.currentText(field) === refused) return;
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.clearFieldViolation(field);
    this.notify();
  }

  /**
   * Save: post the field set the chosen type sends, and report whether the instance accepted it.
   *
   * The change event is published with `created`, which is the action AD-14's vocabulary gives a
   * write that brings an entity into existence -- and the only one that puts the caret on the new
   * row rather than re-reading an existing one.
   */
  async save(): Promise<boolean> {
    if (this.busy()) return false;
    const generation = this.generation;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.notify();

    const sent = this.snapshotValues();
    const result = await this.api().requestJson<unknown>(WEB_APPLICATIONS_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(this.body()),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason =
        this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, sent);
      this.notify();
      return false;
    }
    this.createdIdValue = textAt(result.body, 'name');
    this.savedValue = true;
    this.formDirty.setDirty(false);
    this.publishCreated();
    this.notify();
    return true;
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

  /** The body: every field the chosen type sends, typed as the wire expects (AD-4, AD-54). */
  private body(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of WRITABLE_FIELDS) {
      if (!this.sends(field)) continue;
      if (field === 'AutheEnabled') {
        // Always explicit, whatever is ticked: the property's own InitialExpression is
        // Unauthenticated, so an omitted value creates an application anyone can reach.
        out[field] = this.autheMask();
        continue;
      }
      if (BOOLEAN_FIELDS.includes(field)) {
        out[field] = this.flag(field);
        continue;
      }
      out[field] = this.value(field);
    }
    return out;
  }

  private currentText(field: string): string {
    if (field === 'AutheEnabled') return String(this.autheMask());
    if (BOOLEAN_FIELDS.includes(field)) return String(this.flag(field));
    return this.value(field);
  }

  private snapshotValues(): Record<string, string> {
    const out: Record<string, string> = {};
    for (const field of WRITABLE_FIELDS) out[field] = this.currentText(field);
    return out;
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

  private publishCreated(): void {
    if (this.createdIdValue === '') return;
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: WEB_APPLICATION_ENTITY,
      scope: WEB_APPLICATION_SCOPE,
      id: this.createdIdValue,
      action: 'created',
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/** The machine code the blur look-up reports a taken name under -- the server's own (AD-39). */
export const NAME_TAKEN_CODE = 'WEBAPP.NAME.TAKEN';

/** The bootstrap read's body, narrowed. A member the server did not send reads as empty. */
function absorbRules(body: unknown): FormRules {
  const conditional = body !== null && typeof body === 'object'
    ? (body as Record<string, unknown>)['conditionalFields']
    : null;
  const lengths: Record<string, number> = {};
  const rawLengths = body !== null && typeof body === 'object'
    ? (body as Record<string, unknown>)['maxLengths']
    : null;
  if (rawLengths !== null && typeof rawLengths === 'object' && !Array.isArray(rawLengths)) {
    for (const [field, value] of Object.entries(rawLengths as Record<string, unknown>)) {
      if (typeof value === 'number') lengths[field] = value;
    }
  }
  const methods: AutheMethod[] = [];
  for (const entry of arrayAt(body, 'authenticationMethods')) {
    if (entry === null || typeof entry !== 'object') continue;
    const bit = (entry as Record<string, unknown>)['bit'];
    const label = textAt(entry, 'label');
    if (typeof bit !== 'number' || bit <= 0 || label === '') continue;
    methods.push({ bit, label });
  }
  const rules: FieldRule[] = [];
  for (const entry of arrayAt(body, 'rules')) {
    if (entry === null || typeof entry !== 'object') continue;
    const field = textAt(entry, 'field');
    const code = textAt(entry, 'code');
    const reason = textAt(entry, 'reason');
    if (field === '' || code === '' || reason === '') continue;
    rules.push({ field, code, reason });
  }
  const restFields = stringsAt(conditional, 'rest');
  const pythonFields = stringsAt(conditional, 'wsgi');
  const defaultMethod = body !== null && typeof body === 'object'
    ? (body as Record<string, unknown>)['defaultMethod']
    : null;
  return {
    authenticationMethods: methods,
    defaultMethod: typeof defaultMethod === 'number' ? defaultMethod : 0,
    requiredFields: stringsAt(body, 'requiredFields'),
    restFields: restFields.length > 0 ? restFields : REST_FIELDS,
    pythonFields: pythonFields.length > 0 ? pythonFields : PYTHON_FIELDS,
    wsgiTypes: stringsAt(body, 'wsgiTypes'),
    maxLengths: lengths,
    rules,
    wsgiRoot: textAt(body, 'wsgiRoot'),
  };
}

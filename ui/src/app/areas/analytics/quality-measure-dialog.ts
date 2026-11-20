import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { QualityMeasureStore } from './quality-measure.store';

/** The descriptors and the row actions the dialogs send through the shell's handler. */
export const QUALITY_MEASURE_LIST = 'OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureList';

export const QUALITY_MEASURE_ELEMENT_LIST = 'OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureElementList';

export const QUALITY_MEASURE_META_LIST = 'OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureMetaList';

export const QUALITY_MEASURE_UPDATE_ACTION = 'update';

/** The Change element and Change documentation item action id. */
export const QUALITY_MEASURE_PART_SET_ACTION = 'set';

/** How many quality measure dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** Which object a dialog adds or changes: a measure, an element (with its group) or a documentation item. */
export type QualityMeasureDialogKind = 'measure' | 'element' | 'documentation';

/** One field the dialog draws, by the member the server names it. */
interface Member {
  readonly name: string;
  readonly label: string;
  readonly control: 'text' | 'area';
  /** Drawn on a new measure only. */
  readonly addOnly?: boolean;
  /** Drawn on a change only. */
  readonly changeOnly?: boolean;
  /** Shown fixed on a change. */
  readonly fixed?: boolean;
  /** Sent on a change only when it holds text, so a change never clears it. */
  readonly required?: boolean;
  /** The element form's fieldset the member belongs to. */
  readonly section?: 'group' | 'element';
}

/** One flag the dialog draws, by the member the server names it. */
interface Flag {
  readonly name: string;
  readonly label: string;
  readonly section: 'group' | 'element';
}

/** The three parts of a new measure's name, in order; each is typed apart and the name is the three joined by a slash. */
const NAME_PARTS: readonly string[] = ['Catalog', 'Set', 'Id'];

const MEASURE_MEMBERS: readonly Member[] = [
  { name: 'Name', label: STRINGS.tableColumnName, control: 'text', fixed: true, changeOnly: true },
  { name: 'Catalog', label: STRINGS.analyticsQualityMeasureCatalogLabel, control: 'text', addOnly: true },
  { name: 'Set', label: STRINGS.analyticsQualityMeasureSetLabel, control: 'text', addOnly: true },
  { name: 'Id', label: STRINGS.interopColumnId, control: 'text', addOnly: true },
  { name: 'Class', label: STRINGS.explorerClassDocumentLabel, control: 'text', addOnly: true },
  { name: 'Caption', label: STRINGS.analyticsColumnCaption, control: 'text' },
  { name: 'Description', label: STRINGS.tableColumnDescription, control: 'area' },
  { name: 'SubjectArea', label: STRINGS.analyticsTermListSubjectArea, control: 'text', required: true },
  { name: 'Expression', label: STRINGS.errorLogColumnExpression, control: 'area', changeOnly: true, required: true },
  { name: 'LinkedTo', label: STRINGS.analyticsQualityMeasureLinkedToLabel, control: 'text', changeOnly: true },
  { name: 'Format', label: STRINGS.analyticsQualityMeasureFormatLabel, control: 'text', changeOnly: true },
  { name: 'Href', label: STRINGS.mftConnectionUrl, control: 'text', changeOnly: true },
];

/** An element's form: the group it belongs to, then the element; a group's fields ride on the element write. */
const ELEMENT_MEMBERS: readonly Member[] = [
  { name: 'Group', label: STRINGS.analyticsColumnGroup, control: 'text', fixed: true, section: 'group' },
  { name: 'GroupCaption', label: STRINGS.analyticsColumnCaption, control: 'text', section: 'group' },
  { name: 'GroupDescription', label: STRINGS.tableColumnDescription, control: 'area', section: 'group' },
  { name: 'Name', label: STRINGS.tableColumnName, control: 'text', fixed: true, section: 'element' },
  { name: 'Caption', label: STRINGS.analyticsColumnCaption, control: 'text', section: 'element' },
  { name: 'MDX', label: STRINGS.analyticsColumnMdx, control: 'area', section: 'element' },
];

const META_MEMBERS: readonly Member[] = [
  { name: 'Name', label: STRINGS.tableColumnName, control: 'text', fixed: true, section: 'element' },
  { name: 'Caption', label: STRINGS.analyticsColumnCaption, control: 'text', section: 'element' },
  { name: 'Content', label: STRINGS.analyticsColumnContent, control: 'area', section: 'element' },
];

const MEASURE_FLAGS: readonly Flag[] = [{ name: 'Published', label: STRINGS.analyticsColumnPublished, section: 'element' }];

const ELEMENT_FLAGS: readonly Flag[] = [
  { name: 'GroupDisabled', label: STRINGS.agentGovernanceDisabled, section: 'group' },
  { name: 'Disabled', label: STRINGS.agentGovernanceDisabled, section: 'element' },
];

const META_FLAGS: readonly Flag[] = [{ name: 'Disabled', label: STRINGS.agentGovernanceDisabled, section: 'element' }];

/** What one fieldset of the form draws. */
interface Section {
  readonly key: string;
  readonly legend: string;
  readonly members: readonly Member[];
  readonly flags: readonly Flag[];
}

/**
 * Quality measures' New quality measure and Edit, Groups and elements' Add element and Change element, and Documentation's Add and Change
 * documentation item (Story 24.12): one dialog over the fields of a measure, of an element with its group, or of a documentation item. An add posts
 * through `QualityMeasureStore`, a new measure's name the catalog, set and ID typed apart and joined by a slash; a change sends the row action
 * through the shell's handler, and the instance keeps every member a change leaves out. A measure opens on the form the instance answers now, an
 * element or an item on the values its row showed (`initial`); a group's row with no element opens on the group's fields alone. It follows
 * `ListingGroupDialog`'s shape with these members.
 *
 * **Every sentence it shows is the server's** (AD-39): a violation on a field is drawn under it (a name's, under the ID), any other refusal
 * above the fields. The name is fixed on a change, and so is nothing else.
 */
@Component({
  selector: 'app-quality-measure-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @if (reasonText) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-quality-measure-reason>{{ reasonText }}</p>
    }
    @for (section of sections; track section.key) {
      <fieldset class="ocu-form-fields ocu-field" [attr.data-quality-measure-section]="section.key">
        @if (section.legend !== '') {
          <legend class="ocu-field-label">{{ section.legend }}</legend>
        }
        @for (member of section.members; track member.name) {
          <div class="ocu-field">
            <label class="ocu-field-label" [class.ocu-field-label-required]="isRequired(member)" [attr.for]="fieldId(member.name)">{{ member.label }}</label>
            <div class="ocu-field-control">
              @if (member.control === 'area') {
                <textarea
                  class="ocu-field-input ocu-field-textarea"
                  rows="3"
                  spellcheck="false"
                  [attr.data-quality-measure-field]="member.name"
                  [id]="fieldId(member.name)"
                  [value]="valueOf(member.name)"
                  [attr.aria-invalid]="violationOf(member.name) ? 'true' : null"
                  (input)="onText(member.name, $event)"
                ></textarea>
              } @else {
                <input
                  class="ocu-field-input"
                  type="text"
                  autocomplete="off"
                  spellcheck="false"
                  [attr.data-quality-measure-field]="member.name"
                  [id]="fieldId(member.name)"
                  [value]="valueOf(member.name)"
                  [readOnly]="member.fixed === true && !isNew"
                  [attr.aria-invalid]="violationOf(member.name) ? 'true' : null"
                  (input)="onText(member.name, $event)"
                  (keydown.enter)="onEnter($event)"
                />
              }
            </div>
            @if (fieldViolation[member.name]) {
              <p class="ocu-form-error" [attr.data-quality-measure-violation]="member.name">{{ fieldViolation[member.name] }}</p>
            }
          </div>
        }
        @for (flag of section.flags; track flag.name) {
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="fieldId(flag.name)">{{ flag.label }}</label>
            <div class="ocu-field-control">
              <input
                type="checkbox"
                [attr.data-quality-measure-flag]="flag.name"
                [attr.data-quality-measure-published]="flag.name === 'Published' ? '' : null"
                [id]="fieldId(flag.name)"
                [checked]="flagOf(flag.name)"
                (change)="onFlag(flag.name, $event)"
              />
            </div>
          </div>
        }
      </fieldset>
    }
    <button dialogAction type="button" class="ocu-button-primary" data-quality-measure-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ heading }}
    </button>
  </app-dialog>`,
})
export class QualityMeasureDialog {
  /** Whether the dialog is over a measure, an element or a documentation item. */
  readonly kind = input<QualityMeasureDialogKind>('measure');

  /** The namespace the write is made in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The id of the object this dialog changes (a measure's full name, an element's or an item's composite id), or `null` for a new one. */
  readonly target = input<string | null>(null);

  /** The measure a new element or documentation item belongs to. */
  readonly measure = input('');

  /** The group a new element opens on, when the page knows one. */
  readonly group = input('');

  /** What a changed element's or item's row showed, by member. */
  readonly initial = input<Readonly<Record<string, string>>>({});

  /** Emitted once, after the instance applied the write. */
  readonly done = output<void>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(QualityMeasureStore);

  private readonly handler = inject(ScreenActionHandler);

  private readonly id = ++dialogCount;

  private readonly values = signal<Readonly<Record<string, string>>>({});

  /** The flags the form holds, by member: a measure's Published (on by default) and the Disabled flags. */
  private readonly flags = signal<Readonly<Record<string, boolean>>>({ Published: true });

  protected readonly reason = signal('');

  private readonly violations = signal<readonly Violation[]>([]);

  private readonly busy = signal(false);

  /** Whether a change's form holds what the instance answered; until it does, nothing is sent, so a blank form never replaces it. */
  private readonly loaded = signal(false);

  private closed = false;

  constructor() {
    inject(DestroyRef).onDestroy(() => {
      this.closed = true;
    });
    queueMicrotask(() => void this.load());
  }

  protected get isNew(): boolean {
    return this.target() === null;
  }

  private get members(): readonly Member[] {
    const kind = this.kind();
    return kind === 'measure' ? MEASURE_MEMBERS : kind === 'element' ? ELEMENT_MEMBERS : META_MEMBERS;
  }

  /** Whether the open change is of a group alone: an element's row that holds no element. */
  private get groupOnly(): boolean {
    return this.kind() === 'element' && !this.isNew && (this.initial()['Name'] ?? '') === '';
  }

  /** The members this dialog draws: a new measure the ones only an add sets, a change the ones only a change sets; a group's change leaves out the element's. */
  protected get drawn(): readonly Member[] {
    if (this.kind() !== 'measure') return this.members.filter((member) => !this.groupOnly || member.section === 'group');
    return this.members.filter((member) => (this.isNew ? member.changeOnly !== true : member.addOnly !== true));
  }

  /** The flags this dialog draws: a measure's Published on a change only. */
  private get drawnFlags(): readonly Flag[] {
    const kind = this.kind();
    if (kind === 'measure') return this.isNew ? [] : MEASURE_FLAGS;
    return (kind === 'element' ? ELEMENT_FLAGS : META_FLAGS).filter((flag) => !this.groupOnly || flag.section === 'group');
  }

  /** The fieldsets: an element's form draws the group's, then the element's; any other form one. */
  protected get sections(): readonly Section[] {
    const drawn = this.drawn;
    const flags = this.drawnFlags;
    if (this.kind() !== 'element') return [{ key: 'form', legend: '', members: drawn, flags }];
    const out: Section[] = [{ key: 'group', legend: STRINGS.analyticsColumnGroup, members: drawn.filter((member) => member.section === 'group'), flags: flags.filter((flag) => flag.section === 'group') }];
    if (!this.groupOnly) out.push({ key: 'element', legend: STRINGS.analyticsQualityMeasureElementLegend, members: drawn.filter((member) => member.section === 'element'), flags: flags.filter((flag) => flag.section === 'element') });
    return out;
  }

  protected get heading(): string {
    const kind = this.kind();
    if (kind === 'measure') return this.isNew ? STRINGS.analyticsQualityMeasureNewAction : STRINGS.agentPanelSecretWarningEdit;
    if (kind === 'element') return this.isNew ? STRINGS.analyticsQualityMeasureElementAddAction : STRINGS.analyticsQualityMeasureElementChangeAction;
    return this.isNew ? STRINGS.analyticsQualityMeasureMetaAddAction : STRINGS.analyticsQualityMeasureMetaChangeAction;
  }

  /** Whether a drawn member's label is marked required: the name of a new object and the parts of a new measure's. */
  protected isRequired(member: Member): boolean {
    if (this.kind() === 'measure') return member.name === 'Name' || member.addOnly === true;
    return this.isNew && (member.name === 'Name' || member.name === 'Group');
  }

  protected get confirmDisabled(): string | null {
    const typed = (member: string): string => (this.values()[member] ?? '').trim();
    let unready: boolean;
    if (!this.isNew) unready = !this.loaded();
    else if (this.kind() === 'measure') unready = NAME_PARTS.some((part) => typed(part) === '');
    else unready = typed('Name') === '' || (this.kind() === 'element' && typed('Group') === '');
    return this.busy() || unready ? 'true' : null;
  }

  protected fieldId(member: string): string {
    return `ocu-quality-measure-${member}-${this.id}`;
  }

  protected valueOf(member: string): string {
    return this.values()[member] ?? '';
  }

  protected flagOf(name: string): boolean {
    return this.flags()[name] === true;
  }

  /** The refusal a drawn member carries: its own, and a name's on the ID, the last part of it. */
  protected violationOf(member: string): string {
    return reasonForField(this.violations(), member === 'Id' ? 'Name' : member);
  }

  protected get reasonText(): string {
    return this.reason();
  }

  /** The refusal each member carries, by member, for the template. */
  protected get fieldViolation(): Readonly<Record<string, string>> {
    const out: Record<string, string> = {};
    for (const member of this.members) out[member.name] = this.violationOf(member.name);
    return out;
  }

  protected onText(member: string, event: Event): void {
    const typed = (event.target as HTMLInputElement | HTMLTextAreaElement).value;
    this.values.update((current) => ({ ...current, [member]: typed }));
    this.clearRefusal();
  }

  protected onFlag(name: string, event: Event): void {
    const checked = (event.target as HTMLInputElement).checked;
    this.flags.update((current) => ({ ...current, [name]: checked }));
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  private clearRefusal(): void {
    this.violations.set([]);
    this.reason.set('');
  }

  /** A change opens on what the instance holds now: a measure's form, an element's or an item's row; a new element opens on the group the page names. */
  private async load(): Promise<void> {
    const target = this.target();
    const kind = this.kind();
    if (target === null) {
      if (kind === 'element' && this.group() !== '') this.values.set({ Group: this.group() });
      return;
    }
    if (kind !== 'measure') {
      this.values.set({ ...this.initial() });
      this.flags.set({ Disabled: this.initial()['Disabled'] === 'true', GroupDisabled: this.initial()['GroupDisabled'] === 'true' });
      this.loaded.set(true);
      return;
    }
    const form = await this.store.measureForm(this.namespace(), target);
    if (form === null || this.closed) return;
    const next: Record<string, string> = {};
    for (const [key, value] of Object.entries(form)) {
      if (typeof value === 'string') next[key] = value;
    }
    this.values.set(next);
    this.flags.set({ Published: form['Published'] === true });
    this.loaded.set(true);
  }

  /** The members typed, for a new measure: its name from the three parts, and the others that hold text. */
  private addBody(): Record<string, unknown> {
    const typed = this.values();
    const kind = this.kind();
    if (kind !== 'measure') {
      const body: Record<string, unknown> = { QualityMeasure: this.measure() };
      for (const member of this.drawn) {
        const value = typed[member.name] ?? '';
        if (member.name === 'Name' || member.name === 'Group' || value !== '') body[member.name] = value;
      }
      // GroupDisabled is sent only when set, so an add into an existing disabled group never enables it.
      for (const flag of this.drawnFlags) {
        if (flag.name === 'GroupDisabled' && !this.flagOf(flag.name)) continue;
        body[flag.name] = this.flagOf(flag.name);
      }
      return body;
    }
    const body: Record<string, unknown> = { Name: NAME_PARTS.map((part) => (typed[part] ?? '').trim()).join('/') };
    for (const member of this.drawn) {
      if (NAME_PARTS.includes(member.name)) continue;
      const value = typed[member.name] ?? '';
      if (value !== '') body[member.name] = value;
    }
    return body;
  }

  /** The members typed, for a change, as the strings the row action's values are. */
  private changeValues(): Record<string, string> {
    const typed = this.values();
    const out: Record<string, string> = {};
    for (const member of this.drawn) {
      if (member.fixed === true) continue;
      const value = typed[member.name] ?? '';
      if (member.required !== true || value !== '') out[member.name] = value;
    }
    for (const flag of this.drawnFlags) out[flag.name] = this.flagOf(flag.name) ? 'true' : 'false';
    return out;
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    this.busy.set(true);
    this.clearRefusal();
    const target = this.target();
    const kind = this.kind();
    let applied = false;
    if (target === null) {
      const outcome =
        kind === 'measure'
          ? await this.store.createMeasure(this.namespace(), this.addBody())
          : kind === 'element'
            ? await this.store.createElement(this.namespace(), this.addBody())
            : await this.store.createMeta(this.namespace(), this.addBody());
      applied = outcome.accepted;
      if (!outcome.accepted && !this.closed) {
        this.violations.set(outcome.violations);
        this.reason.set(outcome.violations.length === 0 ? outcome.reason : '');
      }
    } else {
      const descriptor = kind === 'measure' ? QUALITY_MEASURE_LIST : kind === 'element' ? QUALITY_MEASURE_ELEMENT_LIST : QUALITY_MEASURE_META_LIST;
      const action = kind === 'measure' ? QUALITY_MEASURE_UPDATE_ACTION : QUALITY_MEASURE_PART_SET_ACTION;
      applied = await this.handler.sendFor(descriptor, action, target, this.changeValues(), { setRefusal: () => undefined }, this.namespace());
      const refused = this.handler.lastRefusal();
      if (!applied && !this.closed) {
        this.violations.set(refused?.violations ?? []);
        this.reason.set((refused?.violations.length ?? 0) === 0 ? (refused?.reason ?? '') : '');
      }
    }
    this.busy.set(false);
    if (applied && !this.closed) this.done.emit();
  }
}

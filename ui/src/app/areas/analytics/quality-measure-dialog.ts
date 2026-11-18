import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { QualityMeasureStore } from './quality-measure.store';

/** The descriptor and the row action the Edit dialog sends through the shell's handler. */
export const QUALITY_MEASURE_LIST = 'OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureList';

export const QUALITY_MEASURE_UPDATE_ACTION = 'update';

/** How many quality measure dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

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
  /** Sent on a change only when it holds text, because the server refuses an empty value for it. */
  readonly required?: boolean;
}

/** The three parts of a new measure's name, in order; each is typed apart and the name is the three joined by a slash. */
const NAME_PARTS: readonly string[] = ['Catalog', 'Set', 'Id'];

const MEMBERS: readonly Member[] = [
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

/**
 * Quality measures' New quality measure and Edit (Story 24.12): one dialog over a measure's fields. A new measure posts through
 * `QualityMeasureStore`, its name the catalog, set and ID typed apart and joined by a slash; an Edit sends the row action through the shell's
 * handler, and the instance keeps every member a change leaves out. An Edit opens on the form the instance answers now. It follows
 * `ListingGroupDialog`'s shape with a measure's own members, which are none of a group's cubes, resources or listings.
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
    <div class="ocu-form-fields">
      @for (member of drawn; track member.name) {
        <div class="ocu-field">
          <label class="ocu-field-label" [class.ocu-field-label-required]="member.name === 'Name' || member.addOnly === true" [attr.for]="fieldId(member.name)">{{ member.label }}</label>
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
      @if (!isNew) {
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="fieldId('published')">{{ STRINGS.analyticsColumnPublished }}</label>
          <div class="ocu-field-control">
            <input type="checkbox" data-quality-measure-published [id]="fieldId('published')" [checked]="published()" (change)="onPublished($event)" />
          </div>
        </div>
      }
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-quality-measure-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ heading }}
    </button>
  </app-dialog>`,
})
export class QualityMeasureDialog {
  /** The namespace the write is made in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The full name of the measure this dialog changes, or `null` for a new one. */
  readonly target = input<string | null>(null);

  /** Emitted once, after the instance applied the write. */
  readonly done = output<void>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(QualityMeasureStore);

  private readonly handler = inject(ScreenActionHandler);

  private readonly id = ++dialogCount;

  private readonly values = signal<Readonly<Record<string, string>>>({});

  protected readonly published = signal(true);

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

  /** The members this dialog draws: a new measure the ones only an add sets, a change the ones only a change sets. */
  protected get drawn(): readonly Member[] {
    return MEMBERS.filter((member) => (this.isNew ? member.changeOnly !== true : member.addOnly !== true));
  }

  protected get heading(): string {
    return this.isNew ? STRINGS.analyticsQualityMeasureNewAction : STRINGS.agentPanelSecretWarningEdit;
  }

  protected get confirmDisabled(): string | null {
    const unready = this.isNew ? NAME_PARTS.some((part) => (this.values()[part] ?? '').trim() === '') : !this.loaded();
    return this.busy() || unready ? 'true' : null;
  }

  protected fieldId(member: string): string {
    return `ocu-quality-measure-${member}-${this.id}`;
  }

  protected valueOf(member: string): string {
    return this.values()[member] ?? '';
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
    for (const member of MEMBERS) out[member.name] = this.violationOf(member.name);
    return out;
  }

  protected onText(member: string, event: Event): void {
    const typed = (event.target as HTMLInputElement | HTMLTextAreaElement).value;
    this.values.update((current) => ({ ...current, [member]: typed }));
    this.clearRefusal();
  }

  protected onPublished(event: Event): void {
    this.published.set((event.target as HTMLInputElement).checked);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  private clearRefusal(): void {
    this.violations.set([]);
    this.reason.set('');
  }

  /** A change opens on what the instance holds now. */
  private async load(): Promise<void> {
    const target = this.target();
    if (target === null) return;
    const form = await this.store.measureForm(this.namespace(), target);
    if (form === null || this.closed) return;
    const next: Record<string, string> = {};
    for (const [key, value] of Object.entries(form)) {
      if (typeof value === 'string') next[key] = value;
    }
    this.values.set(next);
    this.published.set(form['Published'] === true);
    this.loaded.set(true);
  }

  /** The members typed, for a new measure: its name from the three parts, and the others that hold text. */
  private addBody(): Record<string, unknown> {
    const typed = this.values();
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
    out['Published'] = this.published() ? 'true' : 'false';
    return out;
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    this.busy.set(true);
    this.clearRefusal();
    const target = this.target();
    let applied = false;
    if (target === null) {
      const outcome = await this.store.createMeasure(this.namespace(), this.addBody());
      applied = outcome.accepted;
      if (!outcome.accepted && !this.closed) {
        this.violations.set(outcome.violations);
        this.reason.set(outcome.violations.length === 0 ? outcome.reason : '');
      }
    } else {
      applied = await this.handler.sendFor(QUALITY_MEASURE_LIST, QUALITY_MEASURE_UPDATE_ACTION, target, this.changeValues(), { setRefusal: () => undefined }, this.namespace());
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

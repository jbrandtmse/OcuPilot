import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { TermListStore } from './term-list.store';

/** The descriptor and the row action the Edit term list dialog sends through the shell's handler. */
export const TERM_LIST_LIST = 'OcuPilot.Screen.Descriptor.AnalyticsTermListList';

export const TERM_LIST_UPDATE_ACTION = 'update';

/** How many term list dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** One text field the dialog draws, by the member the server names it. */
interface Drawn {
  readonly member: 'Name' | 'Caption' | 'Description' | 'Pattern' | 'SubjectArea' | 'Fields';
  readonly label: string;
  readonly multiline: boolean;
}

/** The names a "Fields" text holds, one per line, blank lines dropped. */
export function fieldNamesOf(typed: string): string[] {
  return typed
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line !== '');
}

/**
 * Term lists' New term list and Edit term list (Story 24.2): the header of one term list, a primary button that posts through
 * `TermListStore` (a new list) or sends the row action through the shell's handler (an edit), and the sentence that names what the extra
 * fields are for. With a `target` the dialog is an edit: the list's name is shown fixed, and the other fields open on what the instance
 * holds, read through the store.
 *
 * **Every sentence it shows is the server's** (AD-39): a violation on a field is drawn under it, and any other refusal above the fields.
 * Fields are typed one per line and sent as the list of names; a removed field that an entry still uses is refused by the server.
 */
@Component({
  selector: 'app-term-list-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-term-list-help>{{ STRINGS.analyticsTermListFieldsHelp }}</p>
    @if (reasonText) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-term-list-reason>{{ reasonText }}</p>
    }
    <div class="ocu-form-fields">
      @for (field of drawn; track field.member) {
        <div class="ocu-field">
          <label class="ocu-field-label" [class.ocu-field-label-required]="field.member === 'Name'" [attr.for]="fieldId(field.member)">{{ field.label }}</label>
          <div class="ocu-field-control">
            @if (field.multiline) {
              <textarea
                class="ocu-field-input ocu-field-textarea"
                rows="3"
                spellcheck="false"
                [attr.data-term-list-field]="field.member"
                [id]="fieldId(field.member)"
                [value]="valueOf(field.member)"
                [attr.aria-invalid]="violationOf(field.member) ? 'true' : null"
                (input)="onText(field.member, $event)"
              ></textarea>
            } @else {
              <input
                class="ocu-field-input"
                type="text"
                autocomplete="off"
                spellcheck="false"
                [attr.data-term-list-field]="field.member"
                [id]="fieldId(field.member)"
                [value]="valueOf(field.member)"
                [readOnly]="field.member === 'Name' && !isNew"
                [attr.aria-invalid]="violationOf(field.member) ? 'true' : null"
                (input)="onText(field.member, $event)"
                (keydown.enter)="onEnter($event)"
              />
            }
          </div>
          @if (fieldViolation[field.member]) {
            <p class="ocu-form-error" [attr.data-term-list-violation]="field.member">{{ fieldViolation[field.member] }}</p>
          }
        </div>
      }
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId('hide')">{{ STRINGS.analyticsTermListHideValue }}</label>
        <div class="ocu-field-control">
          <input type="checkbox" data-term-list-hide [id]="fieldId('hide')" [checked]="hide()" (change)="onHide($event)" />
        </div>
      </div>
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-term-list-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ confirmLabel }}
    </button>
  </app-dialog>`,
})
export class TermListDialog {
  /** The namespace the list is created or changed in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The id (the name) of the term list this dialog edits, or `null` for a new one. */
  readonly target = input<string | null>(null);

  /** Emitted once, after the instance applied the write. */
  readonly done = output<void>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(TermListStore);

  private readonly handler = inject(ScreenActionHandler);

  private readonly id = ++dialogCount;

  private readonly values = signal<Readonly<Record<string, string>>>({});

  protected readonly hide = signal(false);

  protected readonly reason = signal('');

  private readonly violations = signal<readonly Violation[]>([]);

  private readonly busy = signal(false);

  /** Whether an edit's form holds the header the instance answered; until it does, nothing is sent, so a blank form never replaces it. */
  private readonly loaded = signal(false);

  private closed = false;

  protected readonly drawn: readonly Drawn[] = [
    { member: 'Name', label: STRINGS.analyticsTermListName, multiline: false },
    { member: 'Caption', label: STRINGS.analyticsColumnCaption, multiline: false },
    { member: 'Description', label: STRINGS.tableColumnDescription, multiline: true },
    { member: 'Pattern', label: STRINGS.analyticsTermListPattern, multiline: false },
    { member: 'SubjectArea', label: STRINGS.analyticsTermListSubjectArea, multiline: false },
    { member: 'Fields', label: STRINGS.explorerSqlTabFields, multiline: true },
  ];

  constructor() {
    inject(DestroyRef).onDestroy(() => {
      this.closed = true;
    });
    queueMicrotask(() => void this.load());
  }

  protected get isNew(): boolean {
    return this.target() === null;
  }

  protected get heading(): string {
    const name = this.target();
    return name === null ? STRINGS.analyticsTermListNewAction : STRINGS.analyticsTermListEditTitle.replace('<name>', name);
  }

  protected get confirmLabel(): string {
    return this.isNew ? STRINGS.analyticsTermListNewAction : STRINGS.analyticsTermListEditAction;
  }

  protected get confirmDisabled(): string | null {
    const unready = this.isNew ? (this.values()['Name'] ?? '').trim() === '' : !this.loaded();
    return this.busy() || unready ? 'true' : null;
  }

  protected fieldId(member: string): string {
    return `ocu-term-list-${member}-${this.id}`;
  }

  protected valueOf(member: string): string {
    return this.values()[member] ?? '';
  }

  protected violationOf(member: string): string {
    return reasonForField(this.violations(), member);
  }

  protected get reasonText(): string {
    return this.reason();
  }

  /** The refusal each drawn field carries, by member, for the template. */
  protected get fieldViolation(): Readonly<Record<string, string>> {
    const out: Record<string, string> = {};
    for (const field of this.drawn) out[field.member] = this.violationOf(field.member);
    return out;
  }

  protected onText(member: string, event: Event): void {
    const typed = (event.target as HTMLInputElement | HTMLTextAreaElement).value;
    this.values.update((current) => ({ ...current, [member]: typed }));
    this.violations.set([]);
    this.reason.set('');
  }

  protected onHide(event: Event): void {
    this.hide.set((event.target as HTMLInputElement).checked);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  /** An edit opens on the header the instance holds now. */
  private async load(): Promise<void> {
    const name = this.target();
    if (name === null) return;
    const header = await this.store.header(this.namespace(), name);
    if (header === null || this.closed) return;
    this.values.set({
      Name: header.name,
      Caption: header.caption,
      Description: header.description,
      Pattern: header.pattern,
      SubjectArea: header.subjectArea,
      Fields: header.fields.join('\n'),
    });
    this.hide.set(header.hideValue);
    this.loaded.set(true);
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    this.busy.set(true);
    this.reason.set('');
    this.violations.set([]);
    const typed = this.values();
    const header = {
      Caption: typed['Caption'] ?? '',
      Description: typed['Description'] ?? '',
      Pattern: typed['Pattern'] ?? '',
      SubjectArea: typed['SubjectArea'] ?? '',
    };
    const names = fieldNamesOf(typed['Fields'] ?? '');
    const name = this.target();
    let applied = false;
    if (name === null) {
      const outcome = await this.store.create(this.namespace(), { Name: typed['Name'] ?? '', ...header, Fields: names, HideValue: this.hide() });
      applied = outcome.accepted;
      if (!outcome.accepted && !this.closed) {
        this.violations.set(outcome.violations);
        this.reason.set(outcome.violations.length === 0 ? outcome.reason : '');
      }
    } else {
      applied = await this.handler.sendFor(
        TERM_LIST_LIST,
        TERM_LIST_UPDATE_ACTION,
        name,
        { ...header, Fields: JSON.stringify(names), HideValue: this.hide() ? 'true' : 'false' },
        { setRefusal: () => undefined }
      );
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

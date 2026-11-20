import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { AnalyticsSettingEntryStore } from './analytics-setting-entry.store';

/** The descriptors and the row action the Change dialogs send through the shell's handler. */
export const RUNTIME_VARIABLE_LIST = 'OcuPilot.Screen.Descriptor.AnalyticsRuntimeVariableList';

export const USER_ICON_LIST = 'OcuPilot.Screen.Descriptor.AnalyticsUserIconList';

export const SETTING_ENTRY_SET_ACTION = 'set';

/** What the dialog writes: a run-time variable, or a user-defined icon. */
export type SettingEntryKind = 'variable' | 'icon';

/** The members the dialog draws for each kind, in order. */
const VARIABLE_MEMBERS: readonly string[] = ['Value', 'Comment', 'Context'];

const ICON_MEMBERS: readonly string[] = ['Path'];

/** How many dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Run-time variables' and User-defined icons' Add and Change dialogs (Story 24.13, Batch 3): the name, and for a variable its expression, comment and context, or for an icon its path. An add posts through the
 * store to the route that resolves the tool the agent's add does; a change sends the row action through the shell's handler with the members as typed, and the instance keeps none it leaves out. The name is
 * fixed on a change: a rename is a removal and an add.
 *
 * **The expression is code and is shown as text** (AD-11): the field is a plain text area, nothing renders or evaluates it, and a variable's dialog says what the expression does with the sentence the
 * server publishes. A path is a plain text field and is never loaded. **Every other sentence it shows is the server's** (AD-39): a violation on a field is drawn under it, any other refusal above the fields.
 */
@Component({
  selector: 'app-analytics-setting-entry-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @if (reasonText) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-setting-entry-reason>{{ reasonText }}</p>
    }
    @if (isVariable) {
      <p class="ocu-banner" role="note" data-setting-entry-code>{{ STRINGS.analyticsVariableCodeConsequence }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('Name')">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-setting-entry-field="Name"
            [id]="fieldId('Name')"
            [value]="name()"
            [readOnly]="!isNew"
            [attr.aria-invalid]="nameViolation ? 'true' : null"
            (input)="onName($event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (nameViolation) {
          <p class="ocu-form-error" data-setting-entry-violation="Name">{{ nameViolation }}</p>
        }
      </div>
      @for (row of rows; track row.member) {
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="row.id">{{ row.label }}</label>
          <div class="ocu-field-control">
            @if (row.multiline) {
              <textarea
                class="ocu-field-input ocu-field-textarea"
                rows="3"
                spellcheck="false"
                [attr.data-setting-entry-field]="row.member"
                [id]="row.id"
                [value]="row.value"
                [attr.aria-invalid]="row.violation ? 'true' : null"
                (input)="onMember(row.member, $event)"
              ></textarea>
            } @else {
              <input
                class="ocu-field-input"
                type="text"
                autocomplete="off"
                spellcheck="false"
                [attr.data-setting-entry-field]="row.member"
                [id]="row.id"
                [value]="row.value"
                [attr.aria-invalid]="row.violation ? 'true' : null"
                (input)="onMember(row.member, $event)"
                (keydown.enter)="onEnter($event)"
              />
            }
          </div>
          @if (row.violation) {
            <p class="ocu-form-error" [attr.data-setting-entry-violation]="row.member">{{ row.violation }}</p>
          }
        </div>
      }
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-setting-entry-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ confirmLabel }}
    </button>
  </app-dialog>`,
})
export class AnalyticsSettingEntryDialog {
  /** Whether this dialog writes a variable or an icon. */
  readonly kind = input.required<SettingEntryKind>();

  /** The namespace the write runs in: the one the tab reads. */
  readonly namespace = input.required<string>();

  /** The composite or single id of the row a Change dialog opens on, or `''` for an add. */
  readonly target = input<string>('');

  /** What the row showed, by member (`Name`, `Value`, `Comment`, `Context` or `Path`), for a Change dialog. */
  readonly initial = input<Readonly<Record<string, string>>>({});

  /** Emitted once, after the instance applied the write. */
  readonly done = output<void>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(AnalyticsSettingEntryStore);

  private readonly handler = inject(ScreenActionHandler);

  private readonly id = ++dialogCount;

  protected readonly name = signal('');

  private readonly values = signal<Readonly<Record<string, string>>>({});

  protected readonly reason = signal('');

  private readonly violations = signal<readonly Violation[]>([]);

  private readonly busy = signal(false);

  private closed = false;

  constructor() {
    inject(DestroyRef).onDestroy(() => {
      this.closed = true;
    });
    queueMicrotask(() => {
      const initial = this.initial();
      this.name.set(initial['Name'] ?? '');
      this.values.set({ ...initial });
    });
  }

  protected get isNew(): boolean {
    return this.target() === '';
  }

  protected get isVariable(): boolean {
    return this.kind() === 'variable';
  }

  protected get members(): readonly string[] {
    return this.isVariable ? VARIABLE_MEMBERS : ICON_MEMBERS;
  }

  /** What the template draws for each member below the name: its label, text, violation and field id. The expression is a text area. */
  protected get rows(): readonly { readonly member: string; readonly id: string; readonly label: string; readonly value: string; readonly violation: string; readonly multiline: boolean }[] {
    return this.members.map((member) => ({
      member,
      id: this.fieldId(member),
      label: this.labelOf(member),
      value: this.valueOf(member),
      violation: this.violationOf(member),
      multiline: member === 'Value',
    }));
  }

  protected get nameViolation(): string {
    return this.violationOf('Name');
  }

  protected get heading(): string {
    if (this.isVariable) return this.isNew ? STRINGS.analyticsRuntimeVariableAddAction : STRINGS.analyticsRuntimeVariableChangeAction;
    return this.isNew ? STRINGS.analyticsUserIconAddAction : STRINGS.analyticsUserIconChangeAction;
  }

  protected get confirmLabel(): string {
    return this.isNew ? STRINGS.webAppPctAccessAdd : this.heading;
  }

  protected get confirmDisabled(): string | null {
    return this.busy() || this.name().trim() === '' ? 'true' : null;
  }

  protected get reasonText(): string {
    return this.reason();
  }

  protected fieldId(part: string): string {
    return `ocu-setting-entry-${part}-${this.id}`;
  }

  /** The label of a member: the column heading the tab shows it under. */
  protected labelOf(member: string): string {
    switch (member) {
      case 'Value':
        return STRINGS.errorLogColumnExpression;
      case 'Comment':
        return STRINGS.userFieldComment;
      case 'Context':
        return STRINGS.analyticsColumnContext;
      default:
        return STRINGS.openApiColumnPath;
    }
  }

  protected valueOf(member: string): string {
    return this.values()[member] ?? '';
  }

  protected violationOf(field: string): string {
    return reasonForField(this.violations(), field);
  }

  protected onName(event: Event): void {
    this.name.set((event.target as HTMLInputElement).value);
    this.clearRefusal();
  }

  protected onMember(member: string, event: Event): void {
    const typed = (event.target as HTMLInputElement | HTMLTextAreaElement).value;
    this.values.update((current) => ({ ...current, [member]: typed }));
    this.clearRefusal();
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  private clearRefusal(): void {
    this.violations.set([]);
    this.reason.set('');
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    this.busy.set(true);
    this.clearRefusal();
    const typed: Record<string, string> = {};
    for (const member of this.members) typed[member] = this.valueOf(member);
    let applied = false;
    if (this.isNew) {
      const body = { Name: this.name(), ...typed };
      const outcome = this.isVariable ? await this.store.createVariable(this.namespace(), body) : await this.store.createIcon(this.namespace(), body);
      applied = outcome.accepted;
      if (!outcome.accepted && !this.closed) {
        this.violations.set(outcome.violations);
        this.reason.set(outcome.violations.length === 0 ? outcome.reason : '');
      }
    } else {
      applied = await this.handler.sendFor(this.isVariable ? RUNTIME_VARIABLE_LIST : USER_ICON_LIST, SETTING_ENTRY_SET_ACTION, this.target(), typed, { setRefusal: () => undefined });
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

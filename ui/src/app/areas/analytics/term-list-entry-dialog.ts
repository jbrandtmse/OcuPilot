import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { TermListStore } from './term-list.store';

/** The descriptor and the row action the Change entry dialog sends through the shell's handler. */
export const TERM_LIST_ENTRY_LIST = 'OcuPilot.Screen.Descriptor.AnalyticsTermListEntryList';

export const TERM_LIST_ENTRY_SET_ACTION = 'set';

/** How many entry dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** The entry a Change entry dialog opens on: its composite id, its key and what its row showed. */
export interface EntryTarget {
  readonly id: string;
  readonly key: string;
  readonly value: string;
  /** The row's `Fields` text, each extra field as `field: value` joined with `; `. */
  readonly fields: string;
}

/**
 * The value each of `names` holds in the row's `Fields` text, which lists the list's fields in order as `field: value` joined with `; `.
 * A field's value runs to the `; ` that precedes the next field's name, so a value that holds `; ` stays whole.
 */
export function pairsOf(names: readonly string[], joined: string): Readonly<Record<string, string>> {
  const out: Record<string, string> = {};
  let rest = joined;
  for (let at = 0; at < names.length; at += 1) {
    const prefix = `${names[at]}: `;
    if (!rest.startsWith(prefix)) break;
    rest = rest.slice(prefix.length);
    const next = at + 1 < names.length ? rest.indexOf(`; ${names[at + 1]}: `) : -1;
    out[names[at]] = next < 0 ? rest : rest.slice(0, next);
    rest = next < 0 ? '' : rest.slice(next + 2);
  }
  return out;
}

/**
 * Entries' Add entry and Change entry (Story 24.2): the key, the value and one field per extra field the term list holds, read through
 * `TermListStore`. An add posts through the store; a change sends the row action through the shell's handler with the value and the field
 * values, and the instance keeps every field a change leaves out.
 *
 * **Every sentence it shows is the server's** (AD-39): a violation on the key or the value is drawn under it, any other refusal above the
 * fields. The key is fixed on a change.
 */
@Component({
  selector: 'app-term-list-entry-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @if (reasonText) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-term-list-entry-reason>{{ reasonText }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('key')">{{ STRINGS.oauthClientAlgKey }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-term-list-entry-key
            [id]="fieldId('key')"
            [value]="key()"
            [readOnly]="!isNew"
            [attr.aria-invalid]="keyViolation ? 'true' : null"
            (input)="onKey($event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (keyViolation) {
          <p class="ocu-form-error" data-term-list-entry-violation="Key">{{ keyViolation }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId('value')">{{ STRINGS.errorLogColumnValue }}</label>
        <div class="ocu-field-control">
          <textarea
            class="ocu-field-input ocu-field-textarea"
            rows="3"
            spellcheck="false"
            data-term-list-entry-value
            [id]="fieldId('value')"
            [value]="value()"
            [attr.aria-invalid]="valueViolation ? 'true' : null"
            (input)="onValue($event)"
          ></textarea>
        </div>
        @if (valueViolation) {
          <p class="ocu-form-error" data-term-list-entry-violation="Value">{{ valueViolation }}</p>
        }
      </div>
      @for (name of fieldNames; track name) {
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="fieldId('f-' + name)">{{ name }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              autocomplete="off"
              spellcheck="false"
              [attr.data-term-list-entry-field]="name"
              [id]="fieldId('f-' + name)"
              [value]="fieldValue(name)"
              (input)="onField(name, $event)"
              (keydown.enter)="onEnter($event)"
            />
          </div>
        </div>
      }
      @if (pairsViolation) {
        <p class="ocu-form-error" data-term-list-entry-violation="FieldValues">{{ pairsViolation }}</p>
      }
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-term-list-entry-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ confirmLabel }}
    </button>
  </app-dialog>`,
})
export class TermListEntryDialog {
  /** The namespace the entry is written in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The term list the entry belongs to. */
  readonly termList = input.required<string>();

  /** The entry a Change entry dialog opens on, or `null` for an add. */
  readonly target = input<EntryTarget | null>(null);

  /** Emitted once, after the instance applied the write. */
  readonly done = output<void>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(TermListStore);

  private readonly handler = inject(ScreenActionHandler);

  private readonly id = ++dialogCount;

  protected readonly fields = signal<readonly string[]>([]);

  private readonly pairs = signal<Readonly<Record<string, string>>>({});

  protected readonly key = signal('');

  protected readonly value = signal('');

  protected readonly reason = signal('');

  private readonly violations = signal<readonly Violation[]>([]);

  private readonly busy = signal(false);

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

  protected get heading(): string {
    const target = this.target();
    return target === null ? STRINGS.analyticsEntryAddTitle.replace('<name>', this.termList()) : STRINGS.analyticsEntryChangeTitle.replace('<key>', target.key);
  }

  protected get confirmLabel(): string {
    return this.isNew ? STRINGS.webAppPctAccessAdd : STRINGS.analyticsEntryChangeAction;
  }

  protected get confirmDisabled(): string | null {
    return this.busy() || this.key().trim() === '' ? 'true' : null;
  }

  protected fieldId(part: string): string {
    return `ocu-term-list-entry-${part}-${this.id}`;
  }

  protected fieldValue(name: string): string {
    return this.pairs()[name] ?? '';
  }

  protected get reasonText(): string {
    return this.reason();
  }

  protected get fieldNames(): readonly string[] {
    return this.fields();
  }

  protected get keyViolation(): string {
    return reasonForField(this.violations(), 'Key');
  }

  protected get valueViolation(): string {
    return reasonForField(this.violations(), 'Value');
  }

  protected get pairsViolation(): string {
    return reasonForField(this.violations(), 'FieldValues');
  }

  protected onKey(event: Event): void {
    this.key.set((event.target as HTMLInputElement).value);
    this.clearRefusal();
  }

  protected onValue(event: Event): void {
    this.value.set((event.target as HTMLTextAreaElement).value);
    this.clearRefusal();
  }

  protected onField(name: string, event: Event): void {
    const typed = (event.target as HTMLInputElement).value;
    this.pairs.update((current) => ({ ...current, [name]: typed }));
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

  /** The list's field names are the instance's; a change opens on what the row showed. */
  private async load(): Promise<void> {
    const header = await this.store.header(this.namespace(), this.termList());
    if (this.closed) return;
    const names = header?.fields ?? [];
    this.fields.set(names);
    const target = this.target();
    if (target === null) return;
    this.key.set(target.key);
    this.value.set(target.value);
    this.pairs.set(pairsOf(names, target.fields));
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    this.busy.set(true);
    this.clearRefusal();
    const pairs = this.fields().map((name) => ({ Field: name, Value: this.pairs()[name] ?? '' }));
    const target = this.target();
    let applied = false;
    if (target === null) {
      const outcome = await this.store.addEntry(this.namespace(), { TermList: this.termList(), Key: this.key(), Value: this.value(), FieldValues: pairs });
      applied = outcome.accepted;
      if (!outcome.accepted && !this.closed) {
        this.violations.set(outcome.violations);
        this.reason.set(outcome.violations.length === 0 ? outcome.reason : '');
      }
    } else {
      applied = await this.handler.sendFor(
        TERM_LIST_ENTRY_LIST,
        TERM_LIST_ENTRY_SET_ACTION,
        target.id,
        { Value: this.value(), FieldValues: JSON.stringify(pairs) },
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

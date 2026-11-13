import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { INTEROP_ITEM_COPY_FIELDS, InteropItemCopyStore } from './interop-item-copy.store';

/** How many copy dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Copy item (Story 20.40): the new item's name, the sentence a copy carries, and a primary Copy that posts
 * through `InteropItemCopyStore` the copy of `source` to `production` of `namespace`.
 *
 * A refusal on the name is drawn under the field and named by it (`aria-invalid`, `aria-describedby`); any other
 * refusal, such as a source the production no longer holds or a namespace under source control, is drawn above
 * the field as an alert. Both are the server's sentences. An accepted copy emits `copied` with the new item's
 * name; Cancel, Escape and the scrim emit `cancelled`. Copy is `aria-disabled` while the name is blank or a copy
 * is in flight.
 */
@Component({
  selector: 'app-interop-item-copy-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.interopItemCopyTitle" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-interop-item-copy-consequence>{{ STRINGS.interopItemCopyConsequence }}</p>
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-item-copy-reason>{{ reason }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('name')">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-interop-item-copy-name
            [id]="fieldId('name')"
            [value]="name"
            [attr.aria-invalid]="nameViolation ? 'true' : null"
            [attr.aria-describedby]="describedBy('name', nameViolation)"
            (input)="onText($event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        <p class="ocu-field-caption" [id]="hintId('name')">{{ STRINGS.interopItemAddNameHint }}</p>
        @if (nameViolation) {
          <p class="ocu-form-error" data-interop-item-copy-violation="Name" [id]="reasonId('name')">{{ nameViolation }}</p>
        }
      </div>
    </div>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-interop-item-copy-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.auditDatabaseCopyConfirm }}
    </button>
  </app-dialog>`,
})
export class InteropItemCopyDialog {
  /** The namespace the copy is added in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The production the copy is added to: the list's route id. */
  readonly production = input.required<string>();

  /** The name of the item the copy is made from: the list's selected row. */
  readonly source = input.required<string>();

  /** Emitted once, after the instance added the copy, with its name. */
  readonly copied = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(InteropItemCopyStore);

  private readonly id = ++dialogCount;

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    this.store.reset();
    const stop = this.store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.store.reset();
    });
  }

  protected fieldId(field: string): string {
    return `ocu-interop-item-copy-${field}-${this.id}`;
  }

  protected hintId(field: string): string {
    return `${this.fieldId(field)}-hint`;
  }

  protected reasonId(field: string): string {
    return `${this.fieldId(field)}-reason`;
  }

  protected describedBy(field: string, violation: string): string {
    return violation === '' ? this.hintId(field) : `${this.hintId(field)} ${this.reasonId(field)}`;
  }

  protected get name(): string {
    this.generation();
    return this.store.name();
  }

  protected get nameViolation(): string {
    this.generation();
    return this.store.violation(INTEROP_ITEM_COPY_FIELDS.name);
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  protected get confirmDisabled(): string | null {
    this.generation();
    return this.store.busy() || this.store.name().trim() === '' ? 'true' : null;
  }

  protected onText(event: Event): void {
    this.store.setName((event.target as HTMLInputElement).value);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    const name = this.store.name();
    if (await this.store.copy(this.namespace(), this.production(), this.source())) this.copied.emit(name);
  }
}

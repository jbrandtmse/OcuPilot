import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { INTEROP_ITEM_FIELDS, InteropItemAddStore } from './interop-item-add.store';

/** How many add dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Add item (Story 20.3): the six fields of one new production item, the pending-update sentence the add
 * carries, and a primary Add item that posts through `InteropItemAddStore` to `production` of `namespace`.
 *
 * A refusal on a field is drawn under the field and named by it (`aria-invalid`, `aria-describedby`); any
 * other refusal, such as a name the production already holds or a namespace under source control, is drawn
 * above the fields as an alert. Both are the server's sentences. An accepted add emits `added` with the
 * item's name; Cancel, Escape and the scrim emit `cancelled`. Add item is `aria-disabled` while the name or
 * the class is blank or an add is in flight.
 */
@Component({
  selector: 'app-interop-item-add-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.interopItemAddTitle" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-interop-item-add-pending>{{ STRINGS.interopItemPendingConsequence }}</p>
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-item-add-reason>{{ reason }}</p>
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
            data-interop-item-add-name
            [id]="fieldId('name')"
            [value]="name"
            [attr.aria-invalid]="nameViolation ? 'true' : null"
            [attr.aria-describedby]="describedBy('name', nameViolation)"
            (input)="onText('name', $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        <p class="ocu-field-caption" [id]="hintId('name')">{{ STRINGS.interopItemAddNameHint }}</p>
        @if (nameViolation) {
          <p class="ocu-form-error" data-interop-item-add-violation="Name" [id]="reasonId('name')">{{ nameViolation }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('className')">{{ STRINGS.interopItemColumnClass }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-interop-item-add-class
            [id]="fieldId('className')"
            [value]="className"
            [attr.aria-invalid]="classViolation ? 'true' : null"
            [attr.aria-describedby]="describedBy('className', classViolation)"
            (input)="onText('className', $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        <p class="ocu-field-caption" [id]="hintId('className')">{{ STRINGS.interopItemAddClassHint }}</p>
        @if (classViolation) {
          <p class="ocu-form-error" data-interop-item-add-violation="ClassName" [id]="reasonId('className')">{{ classViolation }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId('poolSize')">{{ STRINGS.interopItemColumnPoolSize }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            inputmode="numeric"
            autocomplete="off"
            data-interop-item-add-pool
            [id]="fieldId('poolSize')"
            [value]="poolSize"
            [attr.aria-invalid]="poolViolation ? 'true' : null"
            [attr.aria-describedby]="describedBy('poolSize', poolViolation)"
            (input)="onText('poolSize', $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        <p class="ocu-field-caption" [id]="hintId('poolSize')">{{ STRINGS.interopItemAddPoolHint }}</p>
        @if (poolViolation) {
          <p class="ocu-form-error" data-interop-item-add-violation="PoolSize" [id]="reasonId('poolSize')">{{ poolViolation }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-checkbox">
          <input
            type="checkbox"
            data-interop-item-add-enabled
            [id]="fieldId('enabled')"
            [checked]="enabled"
            [attr.aria-describedby]="hintId('enabled')"
            (change)="onEnabled($event)"
          />
          {{ STRINGS.tableColumnEnabled }}
        </label>
        <p class="ocu-field-caption" [id]="hintId('enabled')">{{ STRINGS.interopItemAddEnabledHint }}</p>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId('category')">{{ STRINGS.interopItemColumnCategory }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            data-interop-item-add-category
            [id]="fieldId('category')"
            [value]="category"
            [attr.aria-invalid]="categoryViolation ? 'true' : null"
            [attr.aria-describedby]="reasonOnly('category', categoryViolation)"
            (input)="onText('category', $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (categoryViolation) {
          <p class="ocu-form-error" data-interop-item-add-violation="Category" [id]="reasonId('category')">{{ categoryViolation }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId('comment')">{{ STRINGS.userFieldComment }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            data-interop-item-add-comment
            [id]="fieldId('comment')"
            [value]="comment"
            [attr.aria-invalid]="commentViolation ? 'true' : null"
            [attr.aria-describedby]="reasonOnly('comment', commentViolation)"
            (input)="onText('comment', $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (commentViolation) {
          <p class="ocu-form-error" data-interop-item-add-violation="Comment" [id]="reasonId('comment')">{{ commentViolation }}</p>
        }
      </div>
    </div>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-interop-item-add-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.interopItemAddTitle }}
    </button>
  </app-dialog>`,
})
export class InteropItemAddDialog {
  /** The namespace the item is added in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The production the item is added to: the list's route id. */
  readonly production = input.required<string>();

  /** Emitted once, after the instance added the item, with its name. */
  readonly added = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(InteropItemAddStore);

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
    return `ocu-interop-item-add-${field}-${this.id}`;
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

  /** For a field drawn with no caption: its refusal's id while it has one, else nothing. */
  protected reasonOnly(field: string, violation: string): string | null {
    return violation === '' ? null : this.reasonId(field);
  }

  protected get name(): string {
    this.generation();
    return this.store.name();
  }

  protected get className(): string {
    this.generation();
    return this.store.className();
  }

  protected get poolSize(): string {
    this.generation();
    return this.store.poolSize();
  }

  protected get enabled(): boolean {
    this.generation();
    return this.store.enabled();
  }

  protected get category(): string {
    this.generation();
    return this.store.category();
  }

  protected get comment(): string {
    this.generation();
    return this.store.comment();
  }

  protected get nameViolation(): string {
    this.generation();
    return this.store.violation(INTEROP_ITEM_FIELDS.name);
  }

  protected get classViolation(): string {
    this.generation();
    return this.store.violation(INTEROP_ITEM_FIELDS.className);
  }

  protected get poolViolation(): string {
    this.generation();
    return this.store.violation(INTEROP_ITEM_FIELDS.poolSize);
  }

  protected get categoryViolation(): string {
    this.generation();
    return this.store.violation(INTEROP_ITEM_FIELDS.category);
  }

  protected get commentViolation(): string {
    this.generation();
    return this.store.violation(INTEROP_ITEM_FIELDS.comment);
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  protected get confirmDisabled(): string | null {
    this.generation();
    return this.store.busy() || this.store.name().trim() === '' || this.store.className().trim() === '' ? 'true' : null;
  }

  protected onText(field: 'name' | 'className' | 'poolSize' | 'category' | 'comment', event: Event): void {
    this.store.set(field, (event.target as HTMLInputElement).value);
  }

  protected onEnabled(event: Event): void {
    this.store.setEnabled((event.target as HTMLInputElement).checked);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    const name = this.store.name();
    if (await this.store.add(this.namespace(), this.production())) this.added.emit(name);
  }
}

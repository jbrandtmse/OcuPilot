import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { DocDbCreateStore } from './docdb-create.store';

/** How many create dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Create document database (Story 19.17): one Name field with its hint, and a primary Create that
 * posts through `DocDbCreateStore` to `namespace`.
 *
 * A refusal on the name is drawn under the field and named by it (`aria-invalid`,
 * `aria-describedby`); any other refusal, such as a name the namespace already holds or the disabled
 * service, is drawn above the field as an alert. Both are the server's sentences. An accepted create
 * emits `created` with the name; Cancel, Escape and the scrim emit `cancelled`. Create is
 * `aria-disabled` while the name is blank or a create is in flight.
 */
@Component({
  selector: 'app-docdb-create-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.explorerDocDbCreateTitle" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-docdb-create-reason>{{ reason }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-docdb-create-name
            [id]="fieldId"
            [value]="name"
            [attr.aria-invalid]="violation ? 'true' : null"
            [attr.aria-describedby]="describedBy"
            (input)="onInput($event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        <p class="ocu-field-caption" [id]="hintId">{{ STRINGS.explorerDocDbCreateHint }}</p>
        @if (violation) {
          <p class="ocu-form-error" data-docdb-create-violation [id]="reasonId">{{ violation }}</p>
        }
      </div>
    </div>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-docdb-create-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.explorerDocDbCreateTitle }}
    </button>
  </app-dialog>`,
})
export class DocDbCreateDialog {
  /** The namespace the database is created in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** Emitted once, after the instance created the database, with its name. */
  readonly created = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(DocDbCreateStore);

  private readonly id = ++dialogCount;

  protected readonly fieldId = `ocu-docdb-create-name-${this.id}`;

  protected readonly hintId = `${this.fieldId}-hint`;

  protected readonly reasonId = `${this.fieldId}-reason`;

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

  protected get name(): string {
    this.generation();
    return this.store.name();
  }

  protected get violation(): string {
    this.generation();
    return this.store.nameViolation();
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  protected get describedBy(): string {
    return this.violation === '' ? this.hintId : `${this.hintId} ${this.reasonId}`;
  }

  protected get confirmDisabled(): string | null {
    this.generation();
    return this.store.busy() || this.store.name().trim() === '' ? 'true' : null;
  }

  protected onInput(event: Event): void {
    this.store.setName((event.target as HTMLInputElement).value);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    const name = this.store.name();
    if (await this.store.create(this.namespace())) this.created.emit(name);
  }
}

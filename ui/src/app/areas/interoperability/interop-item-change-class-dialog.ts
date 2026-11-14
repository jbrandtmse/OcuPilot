import { ChangeDetectionStrategy, Component, DestroyRef, effect, inject, input, output, signal, untracked } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { InteropItemChangeClassStore } from './interop-item-change-class.store';

/** How many change class dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Change class (Story 20.41): a select of the classes the item's Classes tab lists, less the item's own, the sentence a change of
 * class carries, and a primary Review that emits the chosen class. The review itself, which lists the settings the new class does not
 * take and asks for the item's name, is the handler's dry run, started by the page.
 *
 * The classes are read when the dialog opens, through `InteropItemChangeClassStore`. A read the instance refuses is drawn above the
 * select as an alert with the server's sentence; a read that answers no other class draws the published empty sentence in its place.
 * Review is `aria-disabled` until a class is chosen. Cancel, Escape and the scrim emit `cancelled`.
 */
@Component({
  selector: 'app-interop-item-change-class-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.interopItemChangeClassAction" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-interop-item-class-consequence>{{ STRINGS.interopItemChangeClassConsequence }}</p>
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-item-class-reason>{{ reason }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId">{{ STRINGS.interopItemColumnClass }}</label>
        @if (empty) {
          <p class="ocu-field-caption" data-interop-item-class-empty>{{ STRINGS.interopItemClassesEmpty }}</p>
        } @else {
          <div class="ocu-field-control">
            <select
              class="ocu-field-input"
              aria-required="true"
              data-interop-item-class-select
              [id]="fieldId"
              [disabled]="loading"
              (change)="onChoose($event)"
            >
              <option value="" [selected]="choice === ''"></option>
              @for (option of options; track option.name) {
                <option [value]="option.name" [selected]="option.name === choice">{{ option.name }}</option>
              }
            </select>
          </div>
        }
      </div>
    </div>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-interop-item-class-review
      [attr.aria-disabled]="reviewDisabled"
      (click)="onReview()"
    >
      {{ STRINGS.interopEditResendReview }}
    </button>
  </app-dialog>`,
})
export class InteropItemChangeClassDialog {
  /** The production the item belongs to: the list's route id. */
  readonly production = input.required<string>();

  /** The name of the item whose class changes: the list's selected row. */
  readonly item = input.required<string>();

  /** Emitted once, on Review, with the chosen class. */
  readonly chosen = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly fieldId = `ocu-interop-item-class-${++dialogCount}`;

  private readonly store = inject(InteropItemChangeClassStore);

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    this.store.reset();
    const stop = this.store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.store.reset();
    });
    // The classes are read once the inputs are bound.
    effect(() => {
      const production = this.production();
      const item = this.item();
      untracked(() => void this.store.load(production, item));
    });
  }

  protected get options(): ReturnType<InteropItemChangeClassStore['options']> {
    this.generation();
    return this.store.options();
  }

  protected get loading(): boolean {
    this.generation();
    return this.store.loading();
  }

  protected get empty(): boolean {
    this.generation();
    return this.store.loaded() && this.store.options().length === 0 && this.store.reason() === '';
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  protected get choice(): string {
    this.generation();
    return this.store.choice();
  }

  protected get reviewDisabled(): string | null {
    this.generation();
    return this.store.choice() === '' ? 'true' : null;
  }

  protected onChoose(event: Event): void {
    this.store.choose((event.target as HTMLSelectElement).value);
  }

  protected onReview(): void {
    const choice = this.store.choice();
    if (choice !== '') this.chosen.emit(choice);
  }
}

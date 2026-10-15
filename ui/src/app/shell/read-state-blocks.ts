import { ChangeDetectionStrategy, Component, input, output } from '@angular/core';

import { STRINGS } from '../core/strings';

/**
 * The blocks a screen-bound view draws while its read runs, for the states `core/read-state.ts` decides (AD-36, AD-43): skeleton bars
 * until the first answer, a refusal the connectivity banner has no copy for with Retry, and the screen's empty sentence. `DataTable`
 * draws the first two; the message tabs' body components (`MessageTabBody`) draw all three. Each is its own block element, so a
 * caller's attribute -- a body's `data-ocu-contents` or `data-ocu-trace` -- lands on the block itself.
 */

/** Skeleton bars, hidden from assistive technology, while the first answer is outstanding. */
@Component({
  selector: 'app-read-skeleton',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'ocu-data-table-skeleton', 'aria-hidden': 'true' },
  template: `@for (bar of bars; track bar) {
    <div class="ocu-data-table-skeleton-row">
      <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
      <span class="ocu-skeleton-bar ocu-skeleton-bar-25"></span>
      <span class="ocu-skeleton-bar ocu-skeleton-bar-15"></span>
    </div>
  }`,
})
export class ReadSkeleton {
  protected readonly bars = [0, 1, 2, 3, 4, 5];
}

/** A refusal the connectivity banner has no copy for, announced as an alert, with Retry. */
@Component({
  selector: 'app-read-refusal',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'ocu-data-table-refusal', role: 'alert' },
  template: `<span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
    <button type="button" class="ocu-button-text" (click)="retry.emit()">{{ STRINGS.actionRetry }}</button>`,
})
export class ReadRefusal {
  /** Retry was chosen. */
  readonly retry = output<void>();

  protected readonly STRINGS = STRINGS;
}

/** The screen's empty sentence: its title and what to do next. */
@Component({
  selector: 'app-read-empty',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'ocu-empty-state ocu-data-table-empty' },
  template: `<p class="ocu-data-table-empty-title">{{ title() }}</p>
    <p class="ocu-data-table-empty-next">{{ next() }}</p>`,
})
export class ReadEmpty {
  readonly title = input.required<string>();

  readonly next = input.required<string>();
}

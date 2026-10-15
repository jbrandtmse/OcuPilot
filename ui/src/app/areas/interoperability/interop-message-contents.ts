import { ChangeDetectionStrategy, Component } from '@angular/core';

import { applyView, textOf } from '../../core/screen-read';
import { stringFor } from '../../core/strings';
import { fieldOf } from '../../core/table-model';
import { MessageTabBody } from './message-tab-body';

/**
 * A message's Contents (Story 20.9, AD-5, AD-11): the rows of the Contents tab's read drawn as one block of text lines, in place
 * of the table, by the detail page's `body` input. A table's fixed row height would cut every long line; a block wraps them.
 *
 * It draws the states `DataTable` draws, each block carrying `data-ocu-contents`: skeleton bars in an `aria-busy` region until the
 * first answer (`skeleton`); a refusal the connectivity banner has no copy for, with Retry (`fault`); the screen's empty sentence
 * when the answer holds no row (`empty`); and the rows (`text`), one `pre` that takes focus, holding each row's `Text` as
 * interpolated text -- never markup -- one line to a row, under the cut note when the read truncated (`cut`). The lines are the
 * store's view, as the table's rows are: the command bar's filter and sort apply to them, as they do to what the agent is sent.
 * It draws no control that edits the text.
 *
 * `ListPage` binds the read, the refresh and the id-change re-read; this component only draws what the store holds. The states and
 * their inputs are `MessageTabBody`'s.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-interop-message-contents',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<div class="ocu-message-contents-frame" [attr.aria-busy]="busy">
    @if (showSkeleton) {
      <div class="ocu-data-table-skeleton" data-ocu-contents="skeleton" aria-hidden="true">
        @for (bar of skeletonRows; track bar) {
          <div class="ocu-data-table-skeleton-row">
            <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
            <span class="ocu-skeleton-bar ocu-skeleton-bar-25"></span>
            <span class="ocu-skeleton-bar ocu-skeleton-bar-15"></span>
          </div>
        }
      </div>
    }
    @if (showRefusal) {
      <div class="ocu-data-table-refusal" role="alert" data-ocu-contents="fault">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }
    @if (showEmpty) {
      <section class="ocu-empty-state ocu-data-table-empty" data-ocu-contents="empty">
        <p class="ocu-data-table-empty-title">{{ emptyTitle }}</p>
        <p class="ocu-data-table-empty-next">{{ emptyNext }}</p>
      </section>
    }
    @if (showRows) {
      @if (cut) {
        <p class="ocu-list-page-note" data-ocu-contents="cut">{{ STRINGS.interopMessageContentsCut }}</p>
      }
      <pre class="ocu-message-contents" data-ocu-contents="text" tabindex="0" role="region" [attr.aria-label]="label">{{ text }}</pre>
    }
  </div>`,
})
export class InteropMessageContents extends MessageTabBody {
  /** The read answered fewer lines than the message holds. */
  protected get cut(): boolean {
    return this.showRows && this.store().truncated();
  }

  /** The block's accessible name. */
  protected get label(): string {
    return stringFor(this.screen().labelKey);
  }

  /** The message's text: each row's `Text`, one line to a row, in the store's view (its filter and sort). */
  protected get text(): string {
    this.generation();
    const store = this.store();
    const read = this.screen().read;
    const rows =
      read === null
        ? store.data()
        : applyView(store.data(), read, { filter: store.filter(), sort: store.sort(), direction: store.direction() });
    return rows.map((row) => textOf(fieldOf(row, 'Text'))).join('\n');
  }
}

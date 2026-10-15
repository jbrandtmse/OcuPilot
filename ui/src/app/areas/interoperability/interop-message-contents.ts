import { ChangeDetectionStrategy, Component } from '@angular/core';

import { applyView, textOf } from '../../core/screen-read';
import { stringFor } from '../../core/strings';
import { fieldOf } from '../../core/table-model';
import { ReadEmpty, ReadRefusal, ReadSkeleton } from '../../shell/read-state-blocks';
import { MessageTabBody } from './message-tab-body';

/**
 * A message's Contents (Story 20.9, AD-5, AD-11): the rows of the Contents tab's read drawn as one block of text lines, in place
 * of the table, by the detail page's `body` input. A table's fixed row height would cut every long line; a block wraps them.
 *
 * It draws the states `DataTable` draws, with `shell/read-state-blocks.ts`'s blocks, each carrying `data-ocu-contents`: skeleton
 * bars in an `aria-busy` region until the first answer (`skeleton`); a refusal the connectivity banner has no copy for, with Retry
 * (`fault`); the screen's empty sentence when the answer holds no row (`empty`); and the rows (`text`), one `pre` that takes focus, holding each row's `Text` as
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
  imports: [ReadSkeleton, ReadRefusal, ReadEmpty],
  template: `<div class="ocu-message-contents-frame" [attr.aria-busy]="busy">
    @if (showSkeleton) {
      <app-read-skeleton data-ocu-contents="skeleton" />
    }
    @if (showRefusal) {
      <app-read-refusal data-ocu-contents="fault" (retry)="onRetry()" />
    }
    @if (showEmpty) {
      <app-read-empty data-ocu-contents="empty" [title]="emptyTitle" [next]="emptyNext" />
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

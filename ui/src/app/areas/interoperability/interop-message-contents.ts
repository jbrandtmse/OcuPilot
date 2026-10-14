import { ChangeDetectionStrategy, Component, DestroyRef, type OnInit, inject, input, signal } from '@angular/core';

import { isBannerFault } from '../../core/fault';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { applyView, textOf } from '../../core/screen-read';
import type { ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { emptyStateView, fieldOf } from '../../core/table-model';

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
 * `ListPage` binds the read, the refresh and the id-change re-read; this component only draws what the store holds.
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
    @if (showText) {
      @if (cut) {
        <p class="ocu-list-page-note" data-ocu-contents="cut">{{ STRINGS.interopMessageContentsCut }}</p>
      }
      <pre class="ocu-message-contents" data-ocu-contents="text" tabindex="0" role="region" [attr.aria-label]="label">{{ text }}</pre>
    }
  </div>`,
})
export class InteropMessageContents implements OnInit {
  /** The Contents tab's declaration, whose read the page binds. */
  readonly screen = input.required<ScreenDeclaration>();

  /** The screen's store, which holds the rows the read answered. */
  readonly store = input.required<ScreenStore>();

  private readonly refresh = inject(RefreshService);
  private readonly scope = inject(ScopeService);
  private readonly destroyRef = inject(DestroyRef);

  protected readonly STRINGS = STRINGS;
  protected readonly skeletonRows = [0, 1, 2, 3, 4, 5];

  /** Bumped by the store and the framework, so the block re-renders under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const stopRefresh = this.refresh.subscribe(() => this.bump());
    const stopScope = this.scope.subscribe(() => this.bump());
    this.destroyRef.onDestroy(() => {
      stopRefresh();
      stopScope();
    });
  }

  ngOnInit(): void {
    const stopStore = this.store().subscribe(() => this.bump());
    this.destroyRef.onDestroy(stopStore);
  }

  /** Whether the framework is bound to this screen, which is when its answers are this screen's. */
  private get boundHere(): boolean {
    this.generation();
    return this.refresh.descriptor() === this.screen().descriptor;
  }

  private get loaded(): boolean {
    return this.boundHere && this.refresh.hasLoaded();
  }

  private get fault() {
    return this.boundHere ? this.refresh.fault() : null;
  }

  protected get showRefusal(): boolean {
    const fault = this.fault;
    return fault !== null && !isBannerFault(fault);
  }

  protected get showSkeleton(): boolean {
    return !this.loaded && !this.showRefusal;
  }

  protected get busy(): string | null {
    return this.showSkeleton ? 'true' : null;
  }

  protected get showEmpty(): boolean {
    return this.loaded && this.fault === null && this.store().data().length === 0;
  }

  protected get showText(): boolean {
    return this.loaded && !this.showEmpty;
  }

  /** The read answered fewer lines than the message holds. */
  protected get cut(): boolean {
    return this.showText && this.store().truncated();
  }

  protected get emptyTitle(): string {
    return emptyStateView(this.screen(), this.scope.namespace()).title;
  }

  protected get emptyNext(): string {
    return emptyStateView(this.screen(), this.scope.namespace()).next;
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

  protected onRetry(): void {
    void this.refresh.readNow();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}

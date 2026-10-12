import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { NavigationService } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { createScreenRead } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { statisticsGroups, type StatisticsGroupView } from './statistics.store';

/** The screen this page renders and the store its one row lives in. */
interface StatisticsView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/**
 * Global and routine statistics and ECP statistics (Story 18.36): the instance's cumulative counters, read
 * on open and bound to the shared refresh framework the way `system-usage.page.ts` is -- `stores.for`,
 * `refresh.bind(screen, createScreenRead(...))`, `readNow`, `REFRESH_ACTION_ID`, the generation signal,
 * `DestroyRef` unbind. Neither screen refreshes (AD-43), so a person reads again with Refresh.
 *
 * **One group per second segment of the declared fields** (`statistics.store.ts`): a heading, then each
 * declared field as a label-and-value pair, in declared order, through the shared `cellView` rule, as
 * `process-details.page.ts`'s field groups are drawn. The table still declares every field, as every
 * read-declaring descriptor does.
 *
 * **States.** The page is busy and shows a skeleton until the first answer lands. A later fault keeps the
 * last answer on screen. A first read that fails shows the refusal with Retry; a read that answers no row
 * shows the screen's own empty text.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-statistics-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="ocu-details-page" [attr.aria-busy]="busy">
    @if (showRefusal) {
      <div class="ocu-data-table-refusal" role="alert">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }
    @if (showSkeleton) {
      <div class="ocu-data-table-skeleton" aria-hidden="true">
        @for (bar of skeletonRows; track bar) {
          <div class="ocu-data-table-skeleton-row">
            <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
            <span class="ocu-skeleton-bar ocu-skeleton-bar-15"></span>
          </div>
        }
      </div>
    }
    @if (showEmpty) {
      <section class="ocu-empty-state" tabindex="-1">
        <p class="ocu-data-table-empty-title" data-statistics="empty">{{ emptyText }}</p>
      </section>
    }
    @for (group of groupViews; track group.key) {
      <section class="ocu-details-group" [attr.aria-labelledby]="group.headingId" [attr.data-group]="group.key">
        <h2 class="ocu-details-heading" [id]="group.headingId">{{ group.heading }}</h2>
        <div class="ocu-details-fields">
          @for (field of group.fields; track field.field) {
            <div class="ocu-details-field" [attr.data-field]="field.field">
              <span class="ocu-details-field-label">{{ field.label }}</span>
              <span class="ocu-details-field-value">{{ field.value }}</span>
            </div>
          }
        </div>
      </section>
    }
  </section>`,
})
export class StatisticsPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  protected readonly skeletonRows = [0, 1, 2];

  private readonly view: StatisticsView | null;

  /** Bumped by the store and by the refresh service, so the view re-renders under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null || screen.table === null) {
      this.view = null;
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.view = { screen, store };
    store.clearAnswers();

    this.refresh.bind(screen, createScreenRead(this.api, screen));
    if (this.scope.loaded()) void this.refresh.readNow();

    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      void this.refresh.readNow();
    });

    const stopStore = store.subscribe(() => this.generation.update((value) => value + 1));

    // A fault changes the refresh service and never the store.
    const stopRefresh = this.refresh.subscribe(() => this.generation.update((value) => value + 1));

    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopRefresh();
      stopRefreshAction();
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  private get boundHere(): boolean {
    this.generation();
    return this.view !== null && this.refresh.descriptor() === this.view.screen.descriptor;
  }

  private get loaded(): boolean {
    return this.boundHere && this.refresh.hasLoaded();
  }

  private get faulted(): boolean {
    return this.boundHere && this.refresh.fault() !== null;
  }

  private get row(): unknown {
    this.generation();
    return this.view?.store.data()[0];
  }

  /** Waiting on the first answer: not loaded and not faulted, so a refused first read is never left busy. */
  protected get busy(): boolean {
    return !this.loaded && !this.faulted;
  }

  protected get showSkeleton(): boolean {
    return this.busy;
  }

  /** A first read that failed, with nothing yet to show. */
  protected get showRefusal(): boolean {
    return !this.loaded && this.faulted;
  }

  protected get showEmpty(): boolean {
    this.generation();
    return this.loaded && this.view !== null && this.view.store.data().length === 0;
  }

  protected get emptyText(): string {
    return stringFor(this.view?.screen.emptyStateKey ?? '');
  }

  protected get groupViews(): readonly StatisticsGroupView[] {
    this.generation();
    const view = this.view;
    if (view === null || !this.loaded || view.store.data().length === 0) return [];
    return statisticsGroups(view.screen.table?.columns ?? [], this.row);
  }

  protected onRetry(): void {
    void this.refresh.readNow();
  }
}

import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { NavigationService } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { createScreenRead } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { cellView, fieldOf } from '../../core/table-model';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { Meter } from '../../shell/meter';
import { METER_CONFIGS, isCounterField, meterViewFor, type MeterView } from './system-usage.store';

/** The screen this page renders and the store its one row lives in. */
interface UsageView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One rendered counter: its label and its formatted text. */
interface CounterView {
  readonly field: string;
  readonly label: string;
  readonly value: string;
}

/**
 * System usage (Story 6.9): the instance's own counters and seven dashboard meters, read on open
 * and bound to the shared auto-refresh framework the same way `process-details.page.ts` is --
 * `stores.for`, `refresh.bind(screen, createScreenRead(...))`, `readNow`, `REFRESH_ACTION_ID`, the
 * generation signal, `DestroyRef` unbind -- minus what this screen has none of: no route
 * criterion (`scope` is `instance`, `id.kind` `none`), and no per-row change highlight (the
 * archetype's own Surface x state matrix names no `changed` state for `meters`).
 *
 * **The counters group reuses the declared table's own columns and `cellView`,** exactly as
 * `process-details.page.ts`'s field groups do: every `Usage.*` column (`isCounterField`) renders as
 * a label-and-value pair, in declared order. It is not literally a table -- `table` still has to
 * declare all eighteen fields, as every read-declaring descriptor does -- so this page draws it as
 * a field list instead, the pattern Story 6.7 set.
 *
 * **The other nine fields never reach the counters group.** They are `METER_CONFIGS`' own inputs,
 * turned into each meter's `MeterView` by `system-usage.store.ts`'s `meterViewFor`, and rendered
 * through the shared `app-meter` component.
 *
 * **No page-level refusal banner.** Unlike `detail`, the `meters` archetype's own error state is
 * per meter -- "shows '-' with the error in its tooltip" (EXPERIENCE.md's Surface x state matrix)
 * -- not a strip over the page, so this page renders no `.ocu-data-table-refusal` and offers no
 * Retry; each `app-meter` already carries the current fault as its own `error` input.
 *
 * **The counters group gets its own skeleton before the first successful read; the meters do
 * not need one from this page.** Each meter already renders its own "-" and skeleton fill while
 * pending (`meter.ts`), so the seven `app-meter` elements are always in the template; only the
 * plain counters, which have no such built-in pending rendering, are skeletoned here.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-system-usage-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Meter],
  template: `<section class="ocu-details-page" [attr.aria-busy]="busy">
    @if (showCounterSkeleton) {
      <div class="ocu-data-table-skeleton" aria-hidden="true">
        @for (bar of skeletonRows; track bar) {
          <div class="ocu-data-table-skeleton-row">
            <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
            <span class="ocu-skeleton-bar ocu-skeleton-bar-15"></span>
          </div>
        }
      </div>
    }
    @if (showCounters) {
      <section class="ocu-details-group">
        <div class="ocu-details-fields">
          @for (counter of counterViews; track counter.field) {
            <div class="ocu-details-field">
              <span class="ocu-details-field-label">{{ counter.label }}</span>
              <span class="ocu-details-field-value">{{ counter.value }}</span>
            </div>
          }
        </div>
      </section>
    }
    <div class="ocu-system-usage-meters">
      @for (meter of meterViews; track meter.label) {
        <app-meter
          [label]="meter.label"
          [value]="meter.value"
          [unit]="meter.unit"
          [percent]="meter.percent"
          [state]="meter.state"
          [word]="meter.word"
          [error]="meter.error"
        />
      }
    </div>
  </section>`,
})
export class SystemUsagePage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  protected readonly skeletonRows = [0, 1, 2];

  private readonly view: UsageView | null;

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

    // A fault changes the refresh service and never the store, so the meters' tooltip needs its
    // own signal to render under `OnPush`.
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

  private get row(): unknown {
    this.generation();
    return this.view?.store.data()[0];
  }

  /**
   * The current fault, read as the one string every meter's tooltip shares -- `null` once bound
   * elsewhere, so a screen this page has left never carries a stale reason.
   */
  private get faultText(): string | null {
    if (!this.boundHere) return null;
    return this.refresh.fault() !== null ? STRINGS.connectivityRequestRefused : null;
  }

  protected get busy(): boolean {
    return !this.loaded;
  }

  protected get showCounters(): boolean {
    return this.loaded;
  }

  protected get showCounterSkeleton(): boolean {
    return !this.loaded;
  }

  protected get counterViews(): readonly CounterView[] {
    this.generation();
    const view = this.view;
    if (view === null) return [];
    const row = this.row;
    const columns = view.screen.table?.columns ?? [];
    return columns
      .filter((column) => isCounterField(column.field))
      .map((column) => ({
        field: column.field,
        label: stringFor(column.labelKey),
        value: cellView(fieldOf(row, column.field), column.kind, column.emptyKey ?? '').text,
      }));
  }

  protected get meterViews(): readonly MeterView[] {
    this.generation();
    if (this.view === null) return [];
    const row = this.row;
    const faultText = this.faultText;
    return METER_CONFIGS.map((config) => meterViewFor(config, row, faultText));
  }
}

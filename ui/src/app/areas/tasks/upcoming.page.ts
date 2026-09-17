import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { NavigationService } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { createScreenRead, type ScreenReadCriteria } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { COMMAND_BAR_FILTER_ID } from '../../shell/command-bar';
import { DataTable } from '../../shell/data-table';
import { UPCOMING_HOURS, UpcomingHorizon, localDateText } from './upcoming.store';

/** The screen this page renders and the store its table reads. */
interface UpcomingView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One entry of the horizon control. */
interface HorizonOption {
  readonly value: string;
  readonly label: string;
}

/** The horizon control's value for date mode, which no hour choice can take. */
export const DATE_MODE_VALUE = 'date';

/** A screen store's horizon and the criteria its read last sent. */
interface HeldHorizon {
  readonly horizon: UpcomingHorizon;
  applied: ScreenReadCriteria;
}

/** One horizon per screen store, dropped with it at sign-out. */
const HELD_HORIZONS = new WeakMap<ScreenStore, HeldHorizon>();

/** The horizon held for `store`, created at 24 hours on first ask. */
function heldFor(store: ScreenStore | null): HeldHorizon {
  const known = store === null ? undefined : HELD_HORIZONS.get(store);
  if (known !== undefined) return known;
  const horizon = new UpcomingHorizon();
  const held = { horizon, applied: horizon.criteria(localDateText(new Date())) ?? {} };
  if (store !== null) HELD_HORIZONS.set(store, held);
  return held;
}

/** The string key each hour choice is labelled with, in `UPCOMING_HOURS` order. */
const HOUR_LABEL_KEYS: Readonly<Record<string, string>> = {
  '1': 'taskUpcomingHours1',
  '4': 'taskUpcomingHours4',
  '12': 'taskUpcomingHours12',
  '24': 'taskUpcomingHours24',
  '72': 'taskUpcomingHours72',
  '168': 'taskUpcomingHours168',
};

/**
 * The Upcoming tasks screen: a horizon form above the shared data table, over the descriptor's one
 * declared read (AD-5, AD-36).
 *
 * It binds the read as `ListPage` does and reads when it opens, at 24 hours. The horizon is sent as
 * the declared criteria the store answers (`UpcomingHorizon.criteria`), exactly one of
 * `hoursOffset` and `toDatetime`. A change that yields criteria drops the rows and reads once; a
 * change that yields none -- date mode with no date, or a date before today -- reads nothing and
 * leaves the table as it was. The read closure sends the criteria of the last horizon that yielded
 * any, so Refresh and a namespace switch re-read what the table shows.
 *
 * The horizon lives as long as the screen's store, not the page: leaving the screen, or following a
 * row's name link to its id route, re-creates the page over the store's rows, and the horizon those
 * rows were read for comes back with them. Sign-out drops the stores, and the horizon with them.
 *
 * It does not auto-refresh (AD-43) and carries no row action (AD-10).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-upcoming-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataTable],
  template: `<section class="ocu-list-page">
    @if (list; as view) {
      <form class="ocu-criteria-form" (submit)="onSubmit($event)">
        <div class="ocu-criteria-fields">
          <div class="ocu-criteria-field">
            <label class="ocu-criteria-label" [attr.for]="horizonId">{{ STRINGS.taskUpcomingHorizon }}</label>
            <select class="ocu-criteria-select" [id]="horizonId" [value]="horizonValue" (change)="onHorizon($event)">
              @for (option of options; track option.value) {
                <option [value]="option.value" [selected]="option.value === horizonValue">{{ option.label }}</option>
              }
            </select>
          </div>
          <div class="ocu-criteria-field">
            <label class="ocu-criteria-label" [attr.for]="dateId">{{ STRINGS.taskUpcomingUntil }}</label>
            <input
              class="ocu-criteria-input"
              type="date"
              [id]="dateId"
              [min]="today"
              [value]="dateValue"
              [disabled]="dateDisabled"
              (change)="onDate($event)"
            />
          </div>
        </div>
      </form>
      <app-data-table [screen]="view.screen" [store]="view.store" (focusFilter)="onFocusFilter()" />
    }
  </section>`,
})
export class UpcomingPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);
  private readonly horizon: UpcomingHorizon;

  /** The horizon and the criteria the bound read sends: the last horizon that yielded any. */
  private readonly held: HeldHorizon;

  protected readonly STRINGS = STRINGS;

  protected readonly horizonId = 'ocu-upcoming-horizon';

  protected readonly dateId = 'ocu-upcoming-date';

  protected readonly list: UpcomingView | null;

  protected readonly options: readonly HorizonOption[] = [
    ...UPCOMING_HOURS.map((hours) => ({ value: hours, label: stringFor(HOUR_LABEL_KEYS[hours]) })),
    { value: DATE_MODE_VALUE, label: STRINGS.taskUpcomingUntil },
  ];

  /** Bumped by the two stores, so the form and the table re-render under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null || screen.table === null) {
      this.held = heldFor(null);
      this.horizon = this.held.horizon;
      this.list = null;
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.held = heldFor(store);
    this.horizon = this.held.horizon;
    this.list = { screen, store };
    this.refresh.bind(
      screen,
      createScreenRead(this.api, screen, () => this.held.applied)
    );
    if (this.scope.loaded()) void this.refresh.readNow();
    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      void this.refresh.readNow();
    });
    const stopStore = store.subscribe(() => this.bump());
    const stopHorizon = this.horizon.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopHorizon();
      stopRefreshAction();
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  /** Today's local date, the earliest a date may be. */
  protected get today(): string {
    return localDateText(new Date());
  }

  protected get horizonValue(): string {
    this.generation();
    return this.horizon.mode() === 'date' ? DATE_MODE_VALUE : this.horizon.hours();
  }

  protected get dateValue(): string {
    this.generation();
    return this.horizon.date();
  }

  protected get dateDisabled(): boolean {
    this.generation();
    return this.horizon.mode() !== 'date';
  }

  protected onHorizon(event: Event): void {
    const value = (event.target as HTMLSelectElement).value;
    if (value === DATE_MODE_VALUE) {
      this.horizon.chooseDateMode();
    } else {
      this.horizon.chooseHours(value);
    }
    this.apply();
  }

  protected onDate(event: Event): void {
    this.horizon.chooseDate((event.target as HTMLInputElement).value);
    this.apply();
  }

  /** The form has no submit of its own; Enter in a control changes nothing further. */
  protected onSubmit(event: Event): void {
    event.preventDefault();
  }

  protected onFocusFilter(): void {
    document.getElementById(COMMAND_BAR_FILTER_ID)?.focus();
  }

  /** Read once for the horizon as it stands, when it yields criteria that differ from the last. */
  private apply(): void {
    const next = this.horizon.criteria(localDateText(new Date()));
    if (next === null || JSON.stringify(next) === JSON.stringify(this.held.applied)) return;
    this.held.applied = next;
    if (this.scope.loaded()) this.refresh.noteScopeChanged();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}

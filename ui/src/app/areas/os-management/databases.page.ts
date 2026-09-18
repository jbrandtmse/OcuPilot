import { ChangeDetectionStrategy, Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { NavigationService, screenForRoute, withQuery } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { createScreenRead } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { type ViewOption, ViewOptions } from '../../core/view-options';
import { COMMAND_BAR_FILTER_ID } from '../../shell/command-bar';
import { DataTable } from '../../shell/data-table';
import { ListPage } from '../../shell/list-page';

/** The two routes this page switches between, and the string key each view's own option reads. */
const GENERAL_ROUTE = 'os-management/databases';
const FREE_SPACE_ROUTE = 'os-management/database-free-space';

/**
 * The Free-space view's three figure columns, pending until its own slower read resolves
 * (Boundaries, AC2, AC3): merged from the General view's row set on first load, so the table is
 * never empty while they are awaited.
 *
 * They are also the three fields the General view does not declare, which is what `pendingFields`
 * reads the pending state off the rendered row set with.
 */
const PENDING_FIGURE_FIELDS: readonly string[] = ['AvailableSpace', 'DiskFree', 'Mounted'];

/** The screen and store the Free-space view's own table renders. */
interface FreeSpaceView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/**
 * The Databases screen: General and Free-space are one page over two descriptors and two routes
 * (AD-5's `list (two views)`), switched through **the command bar's own View control**
 * (EXPERIENCE.md "the command-bar View control", DESIGN.md `:1039`): this page registers its two
 * options, which one is current and what choosing one does with `ViewOptions`, and `command-bar.ts`
 * -- mounted once by the shell, not by this page -- draws the menu, the same separation
 * `ScreenActions` keeps between a declared action and the handler that carries it out.
 *
 * **The two routes and their option labels are a screen-local constant**, not a descriptor field:
 * no declared grammar links `DatabaseList` to `DatabaseFreeSpace`, so this page is the one place the
 * pairing is named, the same way `upcoming.page.ts` is the one place its horizon control is named.
 * Both routes render this same page (`ARCHETYPE_PAGES['list (two views)']` and a `DESCRIPTOR_PAGES`
 * entry for `DatabaseFreeSpace`), so the constructor reads whichever one the current URL names.
 *
 * **The General view is `<app-list-page>`'s, unchanged.** Its own declared `LIST` is fast, so it
 * needs no staged rendering.
 *
 * **The Free-space view is staged, on first load only** (AD-5's "a page may issue another built
 * screen's declared read ... or rows to render before a slower read resolves", AC2/AC3): the
 * constructor first issues the General view's own fast `LIST` (`osmgmt.databases`) and applies it
 * straight into the Free-space descriptor's own store, with `AvailableSpace`, `DiskFree` and
 * `Mounted` marked `pendingFields` on `app-data-table` so those three cells draw a skeleton bar
 * while every other cell already shows a real value -- never the whole-table skeleton, since the
 * store already holds rows. It then binds and runs the Free-space screen's own declared read
 * (`RefreshService`, as any other list does); when that resolves the merged rows replace the
 * staged ones and `pendingFields` clears, in the one tick `Screen.Read.Execute` answers it in
 * (AD-36 -- there is no partial merge to stage, since the vendor's own `Result` is written once).
 * A fault on that read is the ordinary refusal `RefreshService` already reports (AC5): the staged
 * rows and their pending cells are left exactly as they were, never a partial figure -- and a
 * later read that succeeds clears them, because `pendingFields` is read off the rendered row set
 * rather than latched at staging time. An auto-refresh tick after the first load re-issues the
 * Free-space read alone, never the General view's, so a silent tick never re-stages a skeleton
 * (AD-43).
 *
 * **The scope may not have resolved when this page is constructed** (`list-page.ts`), and the
 * staged read cannot run without a namespace. Staging then waits for the scope's first
 * resolution, because `RefreshService.noteScopeChanged()` re-reads only a screen already bound:
 * returning without binding would leave a cold deep link's table empty for the page's life.
 *
 * Switching views is an ordinary navigation to the other route, carrying the namespace
 * (`withQuery`), never a client-side toggle of the same rows: the two descriptors are two
 * different reads (AD-36).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-databases-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, DataTable],
  template: `<section class="ocu-list-page">
    @if (isFreeSpaceRoute) {
      @if (freeSpace; as view) {
        <app-data-table
          [screen]="view.screen"
          [store]="view.store"
          [pendingFields]="pendingFields"
          (focusFilter)="onFocusFilter()"
        />
      }
    } @else {
      <app-list-page />
    }
  </section>`,
})
export class DatabasesPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);
  private readonly viewOptions = inject(ViewOptions);
  private readonly destroyRef = inject(DestroyRef);

  protected readonly STRINGS = STRINGS;

  /** Bumped by the router and the Free-space store, so both the View control and the table follow under `OnPush`. */
  private readonly generation = signal(0);

  private readonly currentRoute = computed(() => {
    this.generation();
    return this.navigation.screenForUrl(this.router.url)?.route ?? '';
  });

  private readonly isFreeSpaceRouteSignal = computed(() => this.currentRoute() === FREE_SPACE_ROUTE);

  /** A plain getter, not the signal itself, for the same reason `viewOptionEntries` is one. */
  protected get isFreeSpaceRoute(): boolean {
    return this.isFreeSpaceRouteSignal();
  }

  protected readonly freeSpace: FreeSpaceView | null;

  /** Whether `stageFreeSpaceView` has run, so neither the scope's resolution nor a re-entry stages twice. */
  private staged = false;

  /** The two options `ViewOptions` offers on this page's behalf; static, since the labels never vary by route. */
  private readonly viewOptionEntries: readonly ViewOption[] = [
    { route: GENERAL_ROUTE, label: stringFor('processDetailsGroupGeneral') },
    { route: FREE_SPACE_ROUTE, label: STRINGS.databaseFreeSpaceLabel },
  ];

  constructor() {
    const freeSpaceScreen = screenForRoute(FREE_SPACE_ROUTE);
    const generalScreen = screenForRoute(GENERAL_ROUTE);
    this.freeSpace =
      freeSpaceScreen === null ? null : { screen: freeSpaceScreen, store: this.stores.for(freeSpaceScreen.descriptor, freeSpaceScreen.refreshRates) };

    const stopRouter = this.router.events.subscribe(() => {
      this.generation.update((value) => value + 1);
    });

    // Registered once, for the life of the page: `current` and `options` are read fresh on every
    // render, so the one binding serves both routes without re-registering on navigation between them.
    const stopViewOptions = this.viewOptions.register({
      options: () => this.viewOptionEntries,
      current: () => this.currentRoute(),
      choose: (route) => this.onChooseView(route),
    });

    if (this.isFreeSpaceRoute && freeSpaceScreen !== null && generalScreen !== null) {
      if (this.scope.loaded()) {
        void this.stageFreeSpaceView(generalScreen, freeSpaceScreen);
      } else {
        const stopScope = this.scope.subscribe(() => {
          if (!this.scope.loaded() || this.staged) return;
          void this.stageFreeSpaceView(generalScreen, freeSpaceScreen);
        });
        this.destroyRef.onDestroy(stopScope);
      }
    }

    this.destroyRef.onDestroy(() => {
      stopRouter.unsubscribe();
      stopViewOptions();
      if (freeSpaceScreen !== null && this.refresh.descriptor() === freeSpaceScreen.descriptor) this.refresh.unbind();
    });
  }

  /**
   * Bind the Free-space screen to one read function whose closure remembers whether it has ever
   * been called: the first call answers the General view's own fast `LIST`, so `RefreshService`
   * marks the screen loaded and `app-data-table` renders those rows immediately (`loaded` gates
   * `showGrid`, not the store alone); every later call -- the second `readNow()` below, a manual
   * Refresh, or an auto-refresh tick -- answers the Free-space screen's own declared read. Binding
   * once with this one closure, rather than rebinding between the two calls, is what keeps
   * `RefreshService`'s `loadedOnce` (and so `app-data-table`'s rendering of the staged row) from
   * being reset between them -- a rebind's own `unbind()` clears it.
   */
  private stagedRead(generalScreen: ScreenDeclaration, freeSpaceScreen: ScreenDeclaration) {
    let first = true;
    return async (options: { readonly maxRows: number }) => {
      if (first) {
        first = false;
        return createScreenRead(this.api, generalScreen)(options);
      }
      return createScreenRead(this.api, freeSpaceScreen)(options);
    };
  }

  /**
   * First load only (AD-5, AC2, AC3): stage the General view's own fast rows, then run the
   * Free-space screen's own declared read as a second call through the same bound closure
   * (`stagedRead`). Every later tick -- manual Refresh or the auto-refresh timer -- calls the same
   * closure directly through `RefreshService`'s own timer and never re-enters this method, so a
   * silent tick never re-stages a skeleton. Called once, from the constructor or from the scope's
   * first resolution, whichever comes first.
   */
  private async stageFreeSpaceView(generalScreen: ScreenDeclaration, freeSpaceScreen: ScreenDeclaration): Promise<void> {
    const view = this.freeSpace;
    if (view === null || this.staged) return;
    this.staged = true;
    view.store.clearAnswers();

    const stopStore = view.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopRefresh = this.refresh.subscribe(() => this.generation.update((value) => value + 1));
    const stopRefreshAction = this.actions.register(freeSpaceScreen.descriptor, REFRESH_ACTION_ID, () => {
      void this.refresh.readNow();
    });
    this.destroyRef.onDestroy(() => {
      stopStore();
      stopRefresh();
      stopRefreshAction();
    });

    this.refresh.bind(freeSpaceScreen, this.stagedRead(generalScreen, freeSpaceScreen));
    await this.refresh.readNow(); // Phase 1: the General view's own fast rows.
    if (this.refresh.fault() !== null) return; // A faulted first read is the ordinary whole-table refusal.
    // Phase 2: the Free-space screen's own declared read. A fault leaves the staged rows and their
    // pending cells exactly as they were (AC5); `pendingFields` clears itself when a read -- this
    // one, a manual Refresh after a refusal, or an auto-refresh tick -- actually lands the figures.
    await this.refresh.readNow();
  }

  /**
   * The three figure fields, pending on whatever is rendered right now rather than latched when
   * staging began: a staged row comes from the General view's own five declared fields and carries
   * no `AvailableSpace` key at all, while every row the Free-space read answers carries all three,
   * since `Screen.Read.Project` emits each declared field as a key -- null-valued where the vendor
   * answered none -- so the key's presence, not its value, is what tells the two row sets apart.
   *
   * Derived rather than latched because a Free-space read that succeeds after a faulted one
   * (AC5's own refusal, then Retry) would otherwise keep drawing skeleton bars over figures that
   * have arrived: `data-table.ts` suppresses a pending cell's text entirely.
   */
  protected get pendingFields(): readonly string[] {
    this.generation();
    const row = this.freeSpace?.store.data()[0];
    if (row === null || typeof row !== 'object') return [];
    return PENDING_FIGURE_FIELDS.every((field) => field in row) ? [] : PENDING_FIGURE_FIELDS;
  }

  protected onFocusFilter(): void {
    document.getElementById(COMMAND_BAR_FILTER_ID)?.focus();
  }

  /** The `ViewOptions` binding's `choose`: an ordinary navigation to the other route, carrying the
   * namespace, never a client-side toggle of the same rows (AD-36). */
  private onChooseView(route: string): void {
    if (route === this.currentRoute()) return;
    void this.router.navigateByUrl(withQuery(route, this.router.url));
  }
}

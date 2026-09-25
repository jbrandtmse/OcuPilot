import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal, viewChild } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { ApiService } from '../core/api';
import { NavigationService, ownIdSegment, parentCriteria } from '../core/navigation';
import { RefreshService } from '../core/refresh';
import { ScopeService } from '../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../core/screen-actions';
import { createScreenRead } from '../core/screen-read';
import { ScreenStores, type ScreenStore } from '../core/screen-store';
import type { BannerCase, ScreenDeclaration } from '../core/screens.generated';
import { stringFor } from '../core/strings';
import { COMMAND_BAR_FILTER_ID } from './command-bar';
import { DataTable } from './data-table';
import { ScreenActionDialogs } from './screen-action-dialogs';
import { ScreenActionHandler } from './screen-action-handler';

/** The screen this page renders and the store its table reads. */
interface ListView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/**
 * The page every `list` archetype renders (AD-5): the screen's declared read, bound once, and the
 * data table over its store.
 *
 * It resolves its declaration from the URL, as the outlet does, takes the descriptor's store, binds
 * the refresh framework with the one screen read `createScreenRead` builds (AD-36, AD-43), and reads
 * now, whatever the rate. Before the namespace list has arrived it does not read: nothing is scoped
 * yet, and the scope's first resolution reads the bound screen (`noteScopeChanged`, AD-44). It lets
 * go of the binding when it is destroyed, unless another screen has bound since. A list declaration
 * with no read renders no table.
 *
 * **The banner strip is the store's, not the component's.** A screen may declare a `banner` (AD-36):
 * the instance resolves it inside the screen's own read and the store holds the string key the
 * answer carried, so the strip appears and disappears with the rows rather than on a second request,
 * and an auto-refresh tick clears it the moment the condition clears (EXPERIENCE.md "panel (top), form-pages, Task"). It is
 * never dismissible while it stands, and it carries no action -- the Task Manager's Resume is
 * Epic 7's (FR-51).
 *
 * **A parent-scoped list reads for its route id** (AD-5). A screen declaring a `parentScope` declares
 * exactly one criterion, and the page fills it with the id the URL carries (`parentCriteria`), read
 * at call time so a refresh reads for the id the page is showing. The page drops the store's answers
 * when it opens, and a navigation that keeps this screen and changes its id drops them again and
 * reads, so no parent's rows or selection are shown under another parent's id.
 *
 * **A list opened on its own id selects that row** (AD-13, DW-1419). Where the URL carries the
 * screen's own trailing id segment, the page asks the store for that selection and the table takes
 * it on the tick a read brings the row in. It is one mechanism for both callers that produce such
 * a URL -- the agent's `shell.screen.open` with an `entityId`, and a change toast's
 * "Open in <screen>" -- and an id naming no row the read returned selects nothing, which is not an
 * error.
 */
@Component({
  selector: 'app-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataTable, ScreenActionDialogs],
  template: `<section class="ocu-list-page">
    @if (bannerText) {
      <p [class]="bannerClass" role="status">
        <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
        <span class="ocu-banner-message">{{ bannerText }}</span>
      </p>
    }
    @if (refusalText) {
      <p class="ocu-banner ocu-list-page-banner ocu-banner-warning" role="alert">
        <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
        <span class="ocu-banner-message">{{ refusalText }}</span>
      </p>
    }
    @if (list; as view) {
      <app-data-table [screen]="view.screen" [store]="view.store" (focusFilter)="onFocusFilter()" />
    }
    @if (list; as view) {
      <app-screen-action-dialogs [descriptor]="view.screen.descriptor" (acting)="onActing()" />
    }
  </section>`,
})
export class ListPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);

  private readonly actions = inject(ScreenActions);

  /**
   * Constructed for its own sake, the way `app.ts` constructs `DefinitionActions`: its constructor
   * is what registers every declared row action this client runs through
   * `POST /screens/:screen/action` (AD-53), and a list page is where those actions are offered.
   * Nothing else injects it, so without this line no surface would draw one.
   */
  private readonly screenActions = inject(ScreenActionHandler);

  protected readonly list: ListView | null;

  private readonly table = viewChild(DataTable);

  /**
   * The warning triangle DESIGN.md's banner carries at the left, written as its escape so no
   * non-ASCII byte enters a source file (Rule 14). `aria-hidden`, so the strip reads as its
   * sentence alone.
   */
  protected readonly bannerGlyph = '\u26A0';

  /** Bumped by the store, so the strip re-renders under `OnPush` when a read changes it. */
  private readonly generation = signal(0);

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null || screen.table === null) {
      this.list = null;
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.list = { screen, store };
    // Every parent's page shares the descriptor's store, so what it holds may be another parent's
    // rows and selection: dropped before this parent's read, as an id change drops them.
    if (screen.parentScope !== '') store.clearAnswers();
    const criteria = () => parentCriteria(screen, this.router.url);
    this.refresh.bind(screen, createScreenRead(this.api, screen, criteria));
    // Requested before the first read, so the table consumes it on the tick that brings the row in
    // rather than on a second pass (DW-1419).
    let selectedFor = this.selectFromRoute(screen, store, null);
    if (this.scope.loaded()) void this.refresh.readNow();
    let readFor = JSON.stringify(criteria());
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      if (this.navigation.screenForUrl(this.router.url)?.descriptor !== screen.descriptor) return;
      // A navigation that keeps this screen and changes its id names another row, which is the
      // toast's "Open in <screen>" while the screen is already open.
      selectedFor = this.selectFromRoute(screen, store, selectedFor);
      if (screen.parentScope === '') return;
      const next = JSON.stringify(criteria());
      if (next === readFor) return;
      readFor = next;
      // The rows, selection and scroll belong to the parent the page has left, so they are
      // dropped before the new parent's read, as a namespace switch drops them.
      if (this.scope.loaded()) this.refresh.noteScopeChanged();
    });
    // Manual Refresh (DW-260): the framework's own silent re-read, which is what preserves sort,
    // filter, selection and scroll and announces nothing. Registered for the life of the page, so
    // the control disappears with it.
    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      void this.refresh.readNow();
    });
    const stopStore = store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(() => {
      stopIdChange.unsubscribe();
      stopStore();
      stopRefreshAction();
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
      // The handler is the app's, so a typed-name confirm left open would otherwise outlive the
      // list it was opened on and reappear on the next one.
      if (this.screenActions.pending()?.descriptor === screen.descriptor) this.screenActions.cancelPending();
    });
  }

  /**
   * Ask the store to select the row this screen's own route id names (AD-13, DW-1419), and answer
   * the id now in force.
   *
   * The request is the store's existing pending selection, which the table consumes once a read
   * brings the row in -- so it is the same path a `created` change takes, and an id no row carries
   * selects nothing rather than raising.
   *
   * `previous` is the id this page last acted on, or `null` on mount, and **an unchanged id is left
   * alone**. A navigation may keep this screen's id and change something else -- a namespace switch
   * keeps the path and rewrites only `?ns=` -- and re-asserting the route's id there would replace
   * a row the user had since selected by hand. A navigation that drops the id clears the request
   * instead of leaving the row the old id named standing.
   */
  private selectFromRoute(
    screen: ScreenDeclaration,
    store: ScreenStore,
    previous: string | null
  ): string {
    const id = ownIdSegment(screen, this.router.url);
    if (id === previous) return id;
    if (id !== '') store.setPendingSelection(id);
    else if (previous !== null) store.clearPendingSelection();
    return id;
  }

  /**
   * The declared banner case the last read raised, or `null` when none stands.
   *
   * Both halves have to hold: the descriptor declares a case with that `messageKey`, and the last
   * read answered it. The declaration alone would render a strip on a screen whose condition is not
   * in force; the key alone would render whatever any read put in that slot. A banner declares more
   * than one case since DW-270 -- the Task Manager is suspended, or stopped -- so the case is
   * resolved by key rather than compared against a single declared one.
   */
  private raisedCase(): BannerCase | null {
    const view = this.list;
    if (view === null || view.screen.banner === null) return null;
    const key = view.store.banner();
    if (key === '') return null;
    return view.screen.banner.cases.find((entry) => entry.messageKey === key) ?? null;
  }

  /**
   * The sentence the last refused row action answered with, or `''` when none stands.
   *
   * It is the server's own text (AD-39) and is rendered `role="alert"`, because a write the
   * operator asked for was refused and nothing else on the screen says so: a refused enable or
   * set-default leaves the row exactly as it was, which is indistinguishable from nothing having
   * happened. Separate from the declared banner above it, which is a condition a read reports
   * rather than an answer to something the operator just did.
   */
  protected get refusalText(): string {
    this.generation();
    return this.list?.store.refusal() ?? '';
  }

  /**
   * A dialog's confirming answer is on its way to the handler (`app-screen-action-dialogs`): focus
   * goes to the grid first, before the dialog closes, so it does not return to the opener -- a
   * command-bar button, say, which outlives the row the write is about to remove. When the re-read
   * drops the row, the table's reconcile moves the active row to the one that took its place, or
   * hands focus to the empty state or the filter field when none is left (DW-18).
   */
  protected onActing(): void {
    this.table()?.focusGrid();
  }

  /** The strip's sentence, or `''` when none stands. */
  protected get bannerText(): string {
    this.generation();
    const raised = this.raisedCase();
    return raised === null ? '' : stringFor(raised.messageKey);
  }

  /**
   * The strip's whole class list: the shared banner shape, this page's own placement, and the
   * raised case's own `.ocu-banner-*` variant, which the registry holds to the closed set of
   * variants the stylesheet actually carries.
   *
   * One binding rather than a static `class` beside it, so the rendered list is one expression a
   * reader can check against the stylesheet. The severity is the raised case's, not the banner's:
   * two cases over one field may differ in how loud they are.
   */
  protected get bannerClass(): string {
    this.generation();
    const raised = this.raisedCase();
    const severity = raised === null ? '' : ` ocu-banner-${raised.severity}`;
    return `ocu-banner ocu-list-page-banner${severity}`;
  }

  protected onFocusFilter(): void {
    document.getElementById(COMMAND_BAR_FILTER_ID)?.focus();
  }
}

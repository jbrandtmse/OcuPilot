import { LocationStrategy } from '@angular/common';
import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { isBannerFault } from '../../core/fault';
import { NavigationService, entityUrl } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { CodeSearchState, SCOPE_ALL, createSearchRead, hitLocation, hitsOf, viewerRouteFor } from './code-search.store';

/** The screen this page renders and the store its read writes. */
interface SearchView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One result row as drawn: its link, location and matched line. */
interface HitView {
  readonly key: string;
  readonly document: string;
  readonly url: string;
  readonly href: string;
  readonly location: string;
  readonly text: string;
}

/** One option of the scope select. */
interface ScopeOption {
  readonly value: string;
  readonly label: string;
  readonly selected: boolean;
}

/** Each scope's label, in the declared order. */
const SCOPE_LABELS: Readonly<Record<string, string>> = {
  [SCOPE_ALL]: STRINGS.explorerSearchScopeAll,
  classes: STRINGS.explorerClassListLabel,
  routines: STRINGS.explorerRoutineListLabel,
};

/** One `CodeSearchState` per screen store, so a return to the screen finds the last search. */
const HELD = new WeakMap<ScreenStore, CodeSearchState>();

function heldFor(store: ScreenStore | null): CodeSearchState {
  const known = store === null ? undefined : HELD.get(store);
  if (known !== undefined) return known;
  const state = new CodeSearchState();
  if (store !== null) HELD.set(store, state);
  return state;
}

/**
 * System Explorer's Search (Story 19.4): a form -- the text, where to look, and whether to match
 * case -- above the matches the instance answers, one row per match in its order.
 *
 * **The rows are the screen's.** The read binds through the refresh framework, so the panel's screen
 * context and the read tool see the same rows, and the framework re-runs the last search when a
 * class or routine in this namespace changes (AD-14). Nothing is read until Search is pressed with
 * text or an agent's arrival names a search, which runs once.
 *
 * **A page-owned table.** Each match's document links to that document's own viewer -- the class
 * viewer for a class, the routine viewer otherwise -- so the link target is per row. Its location
 * reads `Member+Line`, or `[Attribute]` for a match in the document's own attribute. A match's line
 * is document text and renders as text (AD-11). A cut list says so under the form.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-code-search-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="ocu-list-page" [attr.aria-busy]="busy">
    @if (view; as current) {
      <form class="ocu-criteria-form" data-ocu-search="form" (submit)="onSearch($event)">
        <div class="ocu-criteria-fields">
          <div class="ocu-criteria-field">
            <label class="ocu-criteria-label" for="ocu-explorer-search-text">{{ STRINGS.explorerSearchTextLabel }}</label>
            <input
              class="ocu-criteria-input"
              id="ocu-explorer-search-text"
              type="text"
              autocomplete="off"
              spellcheck="false"
              maxlength="256"
              data-ocu-search="text"
              [value]="textValue"
              (input)="onText($event)"
            />
          </div>
          <div class="ocu-criteria-field">
            <label class="ocu-criteria-label" for="ocu-explorer-search-scope">{{ STRINGS.explorerSearchScopeLabel }}</label>
            <select class="ocu-criteria-select" id="ocu-explorer-search-scope" data-ocu-search="scope" (change)="onScope($event)">
              @for (option of scopeOptions; track option.value) {
                <option [value]="option.value" [selected]="option.selected">{{ option.label }}</option>
              }
            </select>
          </div>
        </div>
        <div class="ocu-criteria-controls">
          <label class="ocu-criteria-marker">
            <input type="checkbox" data-ocu-search="case" [checked]="matchCase" (change)="onCase($event)" />
            {{ STRINGS.explorerSearchCaseLabel }}
          </label>
          <button type="submit" class="ocu-button-primary" data-ocu-search="submit">{{ STRINGS.auditCriteriaSearch }}</button>
        </div>
      </form>
      <p class="ocu-explorer-status" role="status" data-ocu-search="status">{{ statusLine }}</p>
      @if (showFault) {
        <div class="ocu-data-table-refusal" role="alert" data-ocu-search="fault">
          <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
          <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
        </div>
      }
      <div class="ocu-data-table-frame">
        @if (showEmpty) {
          <section class="ocu-empty-state ocu-data-table-empty" tabindex="-1">
            <p class="ocu-data-table-empty-title" data-ocu-search="empty">{{ emptyTitle }}</p>
          </section>
        }
        @if (showRows) {
          <div class="ocu-data-table-grid ocu-code-search-results" role="table" data-ocu-search="results" [attr.aria-label]="STRINGS.auditCriteriaSearch" [attr.aria-rowcount]="hits.length + 1">
            <div class="ocu-data-table-head" role="rowgroup">
              <div class="ocu-data-table-row ocu-data-table-header-row ocu-code-search-row" role="row" aria-rowindex="1">
                <div class="ocu-data-table-header-cell" role="columnheader">
                  <span class="ocu-data-table-header-label">{{ STRINGS.explorerColumnDocument }}</span>
                </div>
                <div class="ocu-data-table-header-cell" role="columnheader">
                  <span class="ocu-data-table-header-label">{{ STRINGS.explorerColumnMember }}</span>
                </div>
                <div class="ocu-data-table-header-cell" role="columnheader">
                  <span class="ocu-data-table-header-label">{{ STRINGS.explorerColumnMatch }}</span>
                </div>
              </div>
            </div>
            <div class="ocu-data-table-viewport">
              <div class="ocu-data-table-body" role="rowgroup">
                @for (hit of hits; track hit.key; let index = $index) {
                  <div class="ocu-data-table-row ocu-code-search-row" role="row" [attr.aria-rowindex]="index + 2" [attr.data-ocu-hit]="hit.key">
                    <div class="ocu-data-table-cell" role="cell">
                      <a class="ocu-data-table-link" data-ocu-search="document" [href]="hit.href" (click)="onOpen($event, hit.url)">{{ hit.document }}</a>
                    </div>
                    <div class="ocu-data-table-cell" role="cell">
                      <span class="ocu-data-table-text ocu-code-search-location" data-ocu-search="location">{{ hit.location }}</span>
                    </div>
                    <div class="ocu-data-table-cell" role="cell">
                      <span class="ocu-data-table-text ocu-code-search-match" data-ocu-search="match">{{ hit.text }}</span>
                    </div>
                  </div>
                }
              </div>
            </div>
          </div>
        }
      </div>
    }
  </section>`,
})
export class CodeSearchPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);
  private readonly locationStrategy = inject(LocationStrategy);

  /** An agent navigation's hand-off. Optional, so a spec that needs none provides none. */
  private readonly arrivals = inject(ScreenArrivals, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly view: SearchView | null;

  private readonly state: CodeSearchState;

  /** Bumped by the state, the store and the refresh framework, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null) {
      this.view = null;
      this.state = heldFor(null);
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.view = { screen, store };
    this.state = heldFor(store);
    this.refresh.bind(screen, this.boundRead(screen));

    const arrival = this.arrivals?.take(screen.route) ?? null;
    if (arrival !== null) {
      if (this.state.useArrival(arrival)) this.readNow();
    } else if (this.state.searched() && !this.refresh.hasLoaded()) {
      this.readNow();
    }

    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      this.refresh.bind(screen, this.boundRead(screen));
      void this.refresh.readNow();
    });
    const stopArrivals =
      this.arrivals?.subscribe(() => {
        const next = this.arrivals?.take(screen.route) ?? null;
        if (next !== null && this.state.useArrival(next)) this.readNow();
      }) ?? null;
    const stopState = this.state.subscribe(() => this.bump());
    const stopStore = store.subscribe(() => this.bump());
    const stopRefresh = this.refresh.subscribe(() => this.bump());

    inject(DestroyRef).onDestroy(() => {
      stopRefreshAction();
      stopArrivals?.();
      stopState();
      stopStore();
      stopRefresh();
      if (this.navigation.screenForUrl(this.router.url)?.descriptor === screen.descriptor) return;
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  private boundRead(screen: ScreenDeclaration) {
    return this.state.readFor(() => createSearchRead(this.api, screen, this.state));
  }

  protected get busy(): boolean {
    this.generation();
    return this.view !== null && this.state.searched() && !this.refresh.hasLoaded();
  }

  protected get textValue(): string {
    this.generation();
    return this.state.text();
  }

  protected get matchCase(): boolean {
    this.generation();
    return this.state.matchCase();
  }

  protected get scopeOptions(): readonly ScopeOption[] {
    this.generation();
    const field = this.view?.screen.read?.criteria?.fields.find((candidate) => candidate.param === 'scope');
    const current = this.state.scope();
    return (field?.options ?? []).map((value) => ({ value, label: SCOPE_LABELS[value] ?? value, selected: value === current }));
  }

  private get fault() {
    return this.refresh.descriptor() === this.view?.screen.descriptor ? this.refresh.fault() : null;
  }

  protected get showFault(): boolean {
    this.generation();
    const fault = this.fault;
    return fault !== null && !isBannerFault(fault);
  }

  private get rows(): readonly unknown[] {
    return this.view?.store.data() ?? [];
  }

  protected get hits(): readonly HitView[] {
    this.generation();
    const namespace = this.scope.namespace();
    return hitsOf(this.rows).map((hit) => {
      const url = entityUrl(viewerRouteFor(hit.document), hit.document, namespace, this.router.url);
      return { key: hit.key, document: hit.document, url, href: this.locationStrategy.prepareExternalUrl(url), location: hitLocation(hit), text: hit.text };
    });
  }

  protected get showRows(): boolean {
    this.generation();
    return this.state.searched() && this.fault === null && this.hits.length > 0;
  }

  protected get showEmpty(): boolean {
    this.generation();
    if (!this.state.searched()) return true;
    return this.refresh.hasLoaded() && this.fault === null && this.hits.length === 0;
  }

  protected get emptyTitle(): string {
    this.generation();
    return this.state.searched() ? STRINGS.explorerSearchEmpty : STRINGS.explorerSearchInvite;
  }

  /** The cap notice while the list is cut, else nothing. */
  protected get statusLine(): string {
    this.generation();
    const store = this.view?.store;
    if (store === undefined || !this.state.searched() || !store.truncated()) return '';
    return STRINGS.tableRowCapNotice.replace('<n>', store.maxRows().toLocaleString('en-US'));
  }

  protected onText(event: Event): void {
    this.state.setText((event.target as HTMLInputElement).value);
  }

  protected onScope(event: Event): void {
    this.state.setScope((event.target as HTMLSelectElement).value);
  }

  protected onCase(event: Event): void {
    this.state.setMatchCase((event.target as HTMLInputElement).checked);
  }

  /** Search: send the form as shown and read now, once there is text. */
  protected onSearch(event: Event): void {
    event.preventDefault();
    const screen = this.view?.screen;
    if (screen === undefined || !this.state.search()) return;
    this.refresh.bind(screen, this.boundRead(screen));
    void this.refresh.readNow();
  }

  protected onRetry(): void {
    this.readNow();
  }

  /** A plain click opens the viewer in place; a modified click is the browser's. */
  protected onOpen(event: MouseEvent, url: string): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    void this.router.navigateByUrl(url);
  }

  /** Read once the scope has resolved; before then the framework's own scope read is the one. */
  private readNow(): void {
    if (this.scope.loaded()) void this.refresh.readNow();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}

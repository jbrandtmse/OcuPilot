import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { capNoticePhrase } from '../../core/count-phrase';
import { isBannerFault } from '../../core/fault';
import { NavigationService } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { COMMAND_BAR_FILTER_ID } from '../../shell/command-bar';
import { DataTable } from '../../shell/data-table';
import { DevToolState, GENERATED_PARAM, SPEC_PARAM, createDevToolRead } from './dev-tool.store';

/** The screen this page renders and the store its read writes. */
interface DevToolView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One `DevToolState` per screen store, so a return to the screen finds the last search. */
const HELD = new WeakMap<ScreenStore, DevToolState>();

function heldFor(store: ScreenStore | null): DevToolState {
  const known = store === null ? undefined : HELD.get(store);
  if (known !== undefined) return known;
  const state = new DevToolState();
  if (store !== null) HELD.set(store, state);
  return state;
}

/**
 * System Explorer's Code metrics and Document hashes (Story 24.1): a form -- the documents a pattern names
 * and whether generated routines count -- above the rows the instance answers through the developer-tool port.
 *
 * **The rows are the screen's.** The read binds through the refresh framework, so the panel's screen context
 * and the read tool see the same rows, and the framework re-runs the last search when a class or routine in this
 * namespace changes (AD-14). Nothing is read until Search is pressed with a pattern or an agent's arrival names
 * one, which runs once; until then the screen's own invitation shows.
 *
 * **A refused search shows the instance's reason** (a pattern that names the whole namespace, one that matches
 * more documents than one read covers, or one that is not a pattern), in place of the rows, with Retry. The
 * rows themselves are the generic table's, drawn from the descriptor's columns.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-dev-tool-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataTable],
  template: `<section class="ocu-list-page" [attr.aria-busy]="busy">
    @if (view; as current) {
      <form class="ocu-criteria-form" data-ocu-devtool="form" (submit)="onSearch($event)">
        <div class="ocu-criteria-fields">
          <div class="ocu-criteria-field">
            <label class="ocu-criteria-label" for="ocu-devtool-spec">{{ specLabel }}</label>
            <input
              class="ocu-criteria-input"
              id="ocu-devtool-spec"
              type="text"
              autocomplete="off"
              spellcheck="false"
              maxlength="256"
              data-ocu-devtool="spec"
              [value]="specValue"
              (input)="onSpec($event)"
            />
          </div>
        </div>
        <p class="ocu-criteria-hint">{{ specHint }}</p>
        <div class="ocu-criteria-controls">
          <button type="submit" class="ocu-button-primary" data-ocu-devtool="submit">{{ STRINGS.auditCriteriaSearch }}</button>
          <label class="ocu-criteria-marker">
            <input type="checkbox" data-ocu-devtool="generated" [checked]="generatedOn" (change)="onGenerated($event)" />
            {{ generatedLabel }}
          </label>
        </div>
      </form>
      <p class="ocu-explorer-status" role="status" data-ocu-devtool="status">{{ statusLine }}</p>
      @if (showFault) {
        <div class="ocu-data-table-refusal" role="alert" data-ocu-devtool="fault">
          <span class="ocu-data-table-refusal-message">{{ refusalText }}</span>
          <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
        </div>
      }
      @if (showInvite) {
        <section class="ocu-empty-state ocu-data-table-empty" tabindex="-1">
          <p class="ocu-data-table-empty-title" data-ocu-devtool="invite">{{ inviteText }}</p>
        </section>
      }
      @if (showTable) {
        <app-data-table [screen]="current.screen" [store]="current.store" (focusFilter)="onFocusFilter()" />
      }
    }
  </section>`,
})
export class DevToolPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);

  /** An agent navigation's hand-off. Optional, so a spec that needs none provides none. */
  private readonly arrivals = inject(ScreenArrivals, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly view: DevToolView | null;

  private readonly state: DevToolState;

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
    return this.state.readFor(() => createDevToolRead(this.api, screen, this.state));
  }

  private criterion(param: string) {
    return this.view?.screen.read?.criteria?.fields.find((field) => field.param === param);
  }

  protected get busy(): boolean {
    this.generation();
    return this.view !== null && this.state.searched() && !this.refresh.hasLoaded();
  }

  protected get specLabel(): string {
    const field = this.criterion(SPEC_PARAM);
    return field === undefined ? '' : stringFor(field.labelKey);
  }

  protected get specHint(): string {
    return this.criterion(SPEC_PARAM)?.hint ?? '';
  }

  protected get generatedLabel(): string {
    const field = this.criterion(GENERATED_PARAM);
    return field === undefined ? '' : stringFor(field.labelKey);
  }

  protected get specValue(): string {
    this.generation();
    return this.state.spec();
  }

  protected get generatedOn(): boolean {
    this.generation();
    return this.state.includeGenerated();
  }

  private get fault() {
    return this.refresh.descriptor() === this.view?.screen.descriptor ? this.refresh.fault() : null;
  }

  protected get showFault(): boolean {
    this.generation();
    const fault = this.fault;
    return fault !== null && !isBannerFault(fault);
  }

  /** The instance's reason for the refusal, or the generic sentence when it gave none. */
  protected get refusalText(): string {
    this.generation();
    return this.state.refusal() || STRINGS.connectivityRequestRefused;
  }

  /** The invitation shown until a search has been sent: the screen's own, the descriptor's next-step sentence. */
  protected get inviteText(): string {
    const key = this.view?.screen.table?.emptyNextKey ?? '';
    return key === '' ? '' : stringFor(key);
  }

  protected get showInvite(): boolean {
    this.generation();
    return !this.state.searched();
  }

  /** The table while a search stands and has no refusal to show in its place. */
  protected get showTable(): boolean {
    this.generation();
    return this.state.searched() && !this.showFault;
  }

  /** The cap notice while the list on screen is cut, else nothing: never beside a refused search. */
  protected get statusLine(): string {
    this.generation();
    const store = this.view?.store;
    if (store === undefined || !this.state.searched() || this.fault !== null || !store.truncated()) return '';
    return capNoticePhrase(store.maxRows());
  }

  protected onSpec(event: Event): void {
    this.state.setSpec((event.target as HTMLInputElement).value);
  }

  protected onGenerated(event: Event): void {
    this.state.setIncludeGenerated((event.target as HTMLInputElement).checked);
  }

  /** Search: send the form as shown and read now, once there is a pattern. */
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

  protected onFocusFilter(): void {
    document.getElementById(COMMAND_BAR_FILTER_ID)?.focus();
  }

  /** Read once the scope has resolved; before then the framework's own scope read is the one. */
  private readNow(): void {
    if (this.scope.loaded()) void this.refresh.readNow();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}

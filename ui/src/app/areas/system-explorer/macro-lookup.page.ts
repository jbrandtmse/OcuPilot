import { LocationStrategy } from '@angular/common';
import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

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
import { fillPlaceholders } from './code-list.store';
import { viewerRouteFor } from './code-search.store';
import { DOCUMENT_QUERY, MacroLookupState, createMacroRead, definitionOf } from './macro-lookup.store';

/** The screen this page renders and the store its read writes. */
interface MacroView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One `MacroLookupState` per screen store, so a return to the screen finds the last lookup. */
const HELD = new WeakMap<ScreenStore, MacroLookupState>();

function heldFor(store: ScreenStore | null): MacroLookupState {
  const known = store === null ? undefined : HELD.get(store);
  if (known !== undefined) return known;
  const state = new MacroLookupState();
  if (store !== null) HELD.set(store, state);
  return state;
}

/**
 * System Explorer's Macros (Story 19.4): a document and a macro, and what that macro is defined as
 * in the document's context, with where it is defined.
 *
 * **The row is the screen's.** The read binds through the refresh framework, so the panel's screen
 * context and the read tool see the same row. Nothing is read until Look up is pressed with both
 * fields, or an agent's arrival names both; `?document=` prefills the document, as the viewer's
 * "Look up a macro" link does.
 *
 * **The definition is document text** and renders as text on the code surface (AD-11); "Defined in"
 * links the viewer of the include that defines it. A macro the context does not define
 * reads as the sentence that says so, and a refused lookup shows the instance's reason.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-macro-lookup-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="ocu-list-page" [attr.aria-busy]="busy">
    @if (view) {
      <form class="ocu-criteria-form" data-ocu-macro="form" (submit)="onLookUp($event)">
        <div class="ocu-criteria-fields">
          <div class="ocu-criteria-field">
            <label class="ocu-criteria-label" for="ocu-explorer-macro-document">{{ STRINGS.explorerColumnDocument }}</label>
            <input
              class="ocu-criteria-input"
              id="ocu-explorer-macro-document"
              type="text"
              autocomplete="off"
              spellcheck="false"
              maxlength="256"
              data-ocu-macro="document"
              [value]="documentValue"
              (input)="onDocument($event)"
            />
          </div>
          <div class="ocu-criteria-field">
            <label class="ocu-criteria-label" for="ocu-explorer-macro-name">{{ STRINGS.explorerColumnMacro }}</label>
            <input
              class="ocu-criteria-input"
              id="ocu-explorer-macro-name"
              type="text"
              autocomplete="off"
              spellcheck="false"
              maxlength="128"
              data-ocu-macro="macro"
              [value]="macroValue"
              (input)="onMacro($event)"
            />
          </div>
        </div>
        <div class="ocu-criteria-controls">
          <button type="submit" class="ocu-button-primary" data-ocu-macro="submit">{{ STRINGS.explorerLookUpMacro }}</button>
        </div>
      </form>
      @if (showFault) {
        <div class="ocu-data-table-refusal" role="alert" data-ocu-macro="fault">
          <span class="ocu-data-table-refusal-message">{{ refusalText }}</span>
          <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
        </div>
      }
      @if (definition; as found) {
        <section class="ocu-macro-result" data-ocu-macro="result">
          <h2 class="ocu-details-heading ocu-source-name" data-ocu-macro="name">{{ found.macro }}</h2>
          <pre class="ocu-source-text" tabindex="0" data-ocu-macro="definition" [attr.aria-label]="STRINGS.agentDefinitionFormLabel">{{ found.definition }}</pre>
          @if (hasLocation) {
            <p class="ocu-source-note" data-ocu-macro="location">
              <a class="ocu-details-link" data-ocu-macro="defined-in" [href]="locationLink.href" (click)="onOpen($event, locationLink.url)">{{ definedIn }}</a>
            </p>
          }
        </section>
      }
      @if (showEmpty) {
        <p class="ocu-source-note" role="status" data-ocu-macro="empty">{{ emptySentence }}</p>
      }
    }
  </section>`,
})
export class MacroLookupPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);
  private readonly locationStrategy = inject(LocationStrategy);

  /** An agent navigation's hand-off. Optional, so a spec that needs none provides none. */
  private readonly arrivals = inject(ScreenArrivals, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly view: MacroView | null;

  private readonly state: MacroLookupState;

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

    // A link naming another document than the last lookup's drops that lookup, so no answer is shown
    // for a document the form no longer names.
    const prefill = this.route.snapshot?.queryParamMap?.get(DOCUMENT_QUERY) ?? null;
    if (prefill !== null && prefill !== '') {
      this.state.setDocument(prefill);
      if (prefill !== this.state.sent().document) this.state.forget();
    }

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
    return this.state.readFor(() => createMacroRead(this.api, screen, this.state));
  }

  protected get busy(): boolean {
    this.generation();
    return this.view !== null && this.state.searched() && !this.refresh.hasLoaded();
  }

  protected get documentValue(): string {
    this.generation();
    return this.state.document();
  }

  protected get macroValue(): string {
    this.generation();
    return this.state.macro();
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

  protected get definition() {
    this.generation();
    if (!this.state.searched() || this.fault !== null) return null;
    return definitionOf(this.view?.store.data() ?? []);
  }

  protected get showEmpty(): boolean {
    this.generation();
    return this.state.searched() && this.refresh.hasLoaded() && this.fault === null && this.definition === null;
  }

  protected get emptySentence(): string {
    this.generation();
    const sent = this.state.sent();
    return fillPlaceholders(STRINGS.explorerMacroUndefined, { macro: sent.macro, document: sent.document });
  }

  protected get hasLocation(): boolean {
    return (this.definition?.document ?? '') !== '';
  }

  protected get definedIn(): string {
    const found = this.definition;
    if (found === null) return '';
    return fillPlaceholders(STRINGS.explorerMacroDefinedIn, { document: found.document, n: found.line === null ? '' : found.line });
  }

  /** The viewer of the document that defines the macro, as a router URL and an href. */
  protected get locationLink(): { readonly url: string; readonly href: string } {
    const found = this.definition;
    if (found === null || found.document === '') return { url: '', href: '' };
    const url = entityUrl(viewerRouteFor(found.document), found.document, this.scope.namespace(), this.router.url);
    return { url, href: this.locationStrategy.prepareExternalUrl(url) };
  }

  protected onDocument(event: Event): void {
    this.state.setDocument((event.target as HTMLInputElement).value);
  }

  protected onMacro(event: Event): void {
    this.state.setMacro((event.target as HTMLInputElement).value);
  }

  /** Look up: send the form as shown and read now, once both fields hold text. */
  protected onLookUp(event: Event): void {
    event.preventDefault();
    const screen = this.view?.screen;
    if (screen === undefined || !this.state.lookUp()) return;
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
    if (url !== '') void this.router.navigateByUrl(url);
  }

  /** Read once the scope has resolved; before then the framework's own scope read is the one. */
  private readNow(): void {
    if (this.scope.loaded()) void this.refresh.readNow();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}

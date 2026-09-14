import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../core/api';
import { NavigationService } from '../core/navigation';
import { RefreshService } from '../core/refresh';
import { ScopeService } from '../core/scope';
import { createScreenRead } from '../core/screen-read';
import { ScreenStores, type ScreenStore } from '../core/screen-store';
import type { ScreenDeclaration } from '../core/screens.generated';
import { stringFor } from '../core/strings';
import { COMMAND_BAR_FILTER_ID } from './command-bar';
import { DataTable } from './data-table';

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
 * and an auto-refresh tick clears it the moment the condition clears (EXPERIENCE.md `:351`). It is
 * never dismissible while it stands, and it carries no action -- the Task Manager's Resume is
 * Epic 7's (FR-51).
 */
@Component({
  selector: 'app-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataTable],
  template: `<section class="ocu-list-page">
    @if (bannerText) {
      <p [class]="bannerClass" role="status">
        <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
        <span class="ocu-banner-message">{{ bannerText }}</span>
      </p>
    }
    @if (list; as view) {
      <app-data-table [screen]="view.screen" [store]="view.store" (focusFilter)="onFocusFilter()" />
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

  protected readonly list: ListView | null;

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
    this.refresh.bind(screen, createScreenRead(this.api, screen));
    if (this.scope.loaded()) void this.refresh.readNow();
    const stopStore = store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  /**
   * The strip's sentence, or `''` when none stands.
   *
   * Both halves have to hold: the descriptor declares a banner, and the last read answered its
   * `messageKey`. The declaration alone would render a strip on a screen whose condition is not
   * in force; the key alone would render whatever any read put in that slot.
   */
  protected get bannerText(): string {
    this.generation();
    const view = this.list;
    if (view === null || view.screen.banner === null) return '';
    const key = view.store.banner();
    return key === view.screen.banner.messageKey ? stringFor(key) : '';
  }

  /**
   * The strip's whole class list: the shared banner shape, this page's own placement, and the
   * declared severity's `.ocu-banner-*` variant, which the registry holds to the closed set of
   * variants the stylesheet actually carries.
   *
   * One binding rather than a static `class` beside it, so the rendered list is one expression a
   * reader can check against the stylesheet.
   */
  protected get bannerClass(): string {
    const declared = this.list?.screen.banner;
    const severity = declared === null || declared === undefined ? '' : ` ocu-banner-${declared.severity}`;
    return `ocu-banner ocu-list-page-banner${severity}`;
  }

  protected onFocusFilter(): void {
    document.getElementById(COMMAND_BAR_FILTER_ID)?.focus();
  }
}

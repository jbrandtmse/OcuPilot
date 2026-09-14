import { ChangeDetectionStrategy, Component, DestroyRef, inject } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../core/api';
import { NavigationService } from '../core/navigation';
import { RefreshService } from '../core/refresh';
import { ScopeService } from '../core/scope';
import { createScreenRead } from '../core/screen-read';
import { ScreenStores, type ScreenStore } from '../core/screen-store';
import type { ScreenDeclaration } from '../core/screens.generated';
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
 */
@Component({
  selector: 'app-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataTable],
  template: `<section class="ocu-list-page">
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

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null || screen.table === null) {
      this.list = null;
      return;
    }
    this.list = { screen, store: this.stores.for(screen.descriptor, screen.refreshRates) };
    this.refresh.bind(screen, createScreenRead(this.api, screen));
    if (this.scope.loaded()) void this.refresh.readNow();
    inject(DestroyRef).onDestroy(() => {
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  protected onFocusFilter(): void {
    document.getElementById(COMMAND_BAR_FILTER_ID)?.focus();
  }
}

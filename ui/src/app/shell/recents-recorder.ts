import { DestroyRef, Injectable, inject } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { AccountPreferences } from '../core/account-preferences';
import { NavigationService } from '../core/navigation';

/**
 * Registers a visit each time a built screen opens (Story 15.2, AD-50): the third acceptance
 * criterion's "registered by visiting, with no explicit action".
 *
 * **Constructed for its own sake**, in `app.ts`, the way `AgentNavigator` is: nothing else in the
 * tree would instantiate it, and it has to live for the tab rather than for one component's
 * lifetime, because the screen being opened is not the thing that records it.
 *
 * **It never blocks, delays or fails a navigation.** It acts on `NavigationEnd`, after the router
 * has arrived, and `AccountPreferences.registerVisit` is fire and forget -- a failure surfaces
 * nowhere, because a recent item nobody asked for is not worth a message.
 *
 * **Only a built screen, and only a route change.** A URL that resolves to no built screen is one
 * the shell cannot render, so it is not somewhere the user has been; and the last route this tab
 * registered is remembered so a re-navigation to the same screen -- a namespace switch, a
 * re-render, a router event that leaves the route where it was -- does not cost a request that
 * would only re-stamp the row it already wrote. Home declares the empty route and is deliberately
 * not recorded: it is where the lists are read, and the instance refuses an empty route anyway.
 */
@Injectable({ providedIn: 'root' })
export class RecentsRecorder {
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly preferences = inject(AccountPreferences);

  /** The route this tab last registered, so a repeat arrival costs nothing. */
  private lastRoute = '';

  constructor() {
    const stop = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      this.record(event.urlAfterRedirects);
    });
    inject(DestroyRef).onDestroy(() => stop.unsubscribe());
  }

  /**
   * Forget the last route, so the next principal's arrival at the screen this tab is already on
   * is registered rather than skipped. Sign-out clears the tab in place and leaves the URL where
   * it was, so without this the one screen the next principal resumes on is the one screen their
   * recents never get -- `app.ts` calls it beside `AccountPreferences.reset()`.
   */
  reset(): void {
    this.lastRoute = '';
  }

  private record(url: string): void {
    const screen = this.navigation.screenForUrl(url);
    if (screen === null || screen.route === '') return;
    if (screen.route === this.lastRoute) return;
    this.lastRoute = screen.route;
    this.preferences.registerVisit(screen.route);
  }
}

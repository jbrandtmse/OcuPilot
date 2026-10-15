import { DestroyRef, Injectable, inject } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { AccountPreferences } from '../core/account-preferences';
import { NavigationService, isListedScreen } from '../core/navigation';
import { Session, isSignedIn, isWaiting } from '../core/session';

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
 * **Only while signed in.** A tab on the sign-in card, or one whose session ended, has no
 * principal to write for: the instance would refuse the write, and a Back from the card to a listed
 * screen is a navigation like any other. An arrival in such a settled state is never registered.
 *
 * **A listed arrival while the session is still `probing` or `installing` is held, not lost.** A
 * deep link's first navigation ends before the silent sign-in has answered, and it is a visit the
 * person made. The recorder holds the latest such arrival as the one pending visit and registers it
 * when the session reaches `signed-in`; it drops it when the session settles in any other state, so
 * the principal who signs in on the form next is not credited with a screen from before they did.
 *
 * **Only a listed screen, and only a route change.** A URL that resolves to no built screen is one
 * the shell cannot render, so it is not somewhere the user has been; and the last route this tab
 * registered is remembered so a re-navigation to the same screen -- a namespace switch, a
 * re-render, a router event that leaves the route where it was -- does not cost a request that
 * would only re-stamp the row it already wrote. Home declares the empty route and is deliberately
 * not recorded: it is where the lists are read, and the instance refuses an empty route anyway.
 *
 * **An unlisted screen is not somewhere to return to.** `sideBarPosition` 0 marks a screen reached
 * only from its own list and keyed by an entity id, so `screenForUrl` answers the id-less parent
 * route for it (`core/navigation.ts`). Recording that route would put a row on Home whose button
 * opens the screen with no entity -- the Definition form's create form -- which is the harm
 * `command-box.ts` filters `isListedScreen` to avoid, for the same reason and on the same roster.
 */
@Injectable({ providedIn: 'root' })
export class RecentsRecorder {
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly preferences = inject(AccountPreferences);
  private readonly session = inject(Session);

  /** The route this tab last registered, so a repeat arrival costs nothing. */
  private lastRoute = '';

  /** The listed route reached while the session was waiting to sign in, owed a registration. */
  private pendingRoute: string | null = null;

  constructor() {
    const stop = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      this.record(event.urlAfterRedirects);
    });
    const stopSession = this.session.subscribe(() => this.settle());
    inject(DestroyRef).onDestroy(() => {
      stop.unsubscribe();
      stopSession();
    });
  }

  /**
   * Forget the last route, so the next principal's arrival at the screen this tab is already on
   * is registered rather than skipped. Sign-out clears the tab in place and leaves the URL where
   * it was, so without this the one screen the next principal resumes on is the one screen their
   * recents never get -- `app.ts` calls it beside `AccountPreferences.reset()`.
   *
   * It leaves a held arrival alone: `app.ts` calls it on every move into a state other than
   * `signed-in`, `probing` to `installing` included, and the held arrival is settled by the
   * session's own move to `signed-in` or away from the waiting states.
   */
  reset(): void {
    this.lastRoute = '';
  }

  private record(url: string): void {
    const state = this.session.state();
    const waiting = isWaiting(state);
    if (!waiting && !isSignedIn(state)) return;
    const screen = this.navigation.screenForUrl(url);
    if (screen === null || screen.route === '' || !isListedScreen(screen)) return;
    if (waiting) {
      this.pendingRoute = screen.route;
      return;
    }
    this.register(screen.route);
  }

  /** The session changed state: register the held arrival if it signed in, drop it if it settled otherwise. */
  private settle(): void {
    const state = this.session.state();
    if (isWaiting(state)) return;
    const route = this.pendingRoute;
    this.pendingRoute = null;
    if (route !== null && isSignedIn(state)) this.register(route);
  }

  private register(route: string): void {
    if (route === this.lastRoute) return;
    this.lastRoute = route;
    this.preferences.registerVisit(route);
  }
}

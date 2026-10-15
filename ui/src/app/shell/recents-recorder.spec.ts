import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { AccountPreferences } from '../core/account-preferences';
import { NavigationService, screenForRoute } from '../core/navigation';
import { Session, type SessionState } from '../core/session';
import type { ScreenDeclaration } from '../core/screens.generated';
import {
  stubAccountPreferences,
  type StubbedAccountPreferences,
} from '../testing/account-preferences';
import { RecentsRecorder } from './recents-recorder';

/**
 * The recorder behind Story 15.2's third acceptance criterion: recents are registered by
 * visiting, with no explicit action.
 *
 * The roster is stubbed for the reason `NavigationService` carries that seam: the rows below need
 * a URL that resolves to no built screen and one that resolves to Home's empty route, neither of
 * which a live map supplies on demand.
 */

class StubNavigation {
  screenForUrl(url: string): ScreenDeclaration | null {
    const path = url.split('?')[0].replace(/^\/+/, '');
    if (path === '') return screenForRoute('');
    // An id-keyed screen resolves to its own declaration, which carries the id-less parent route
    // -- the production `screenForUrl` walks up one segment to reach exactly that (AD-13).
    const cut = path.lastIndexOf('/');
    return screenForRoute(path) ?? (cut < 0 ? null : screenForRoute(path.slice(0, cut)));
  }
}

/** The two members the recorder reads: which state the tab's session is in, and when it changes. */
class StubSession {
  current: SessionState = 'signed-in';
  private readonly listeners = new Set<() => void>();

  state(): SessionState {
    return this.current;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Settle the session on `next` and tell every listener, the way `Session.setState` does. */
  move(next: SessionState): void {
    this.current = next;
    for (const listener of this.listeners) listener();
  }
}

describe('the recents recorder', () => {
  let preferences: StubbedAccountPreferences;
  let router: Router;
  let session: StubSession;

  /**
   * Every write the stub was asked for. `recents()` cannot answer "was a visit registered?" on
   * its own: the empty route and a repeat of the front route both leave the list exactly as it
   * was, so the two guards below are pinned on the request that was never issued.
   */
  const writes = () => preferences.calls.filter((call) => call.method === 'POST');

  /**
   * A visit is fire and forget by contract, so the navigation it followed resolves before the
   * store has settled. One macrotask is what drains the stubbed request's microtasks; without it
   * these rows would be reading the store a tick too early.
   */
  const settled = () => new Promise((resolve) => setTimeout(resolve, 0));

  beforeEach(() => {
    TestBed.resetTestingModule();
    preferences = stubAccountPreferences();
    session = new StubSession();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: '', children: [] },
          { path: 'logs/alerts', children: [] },
          { path: 'permissions/users', children: [] },
          { path: 'no-such-area/no-such-screen', children: [] },
          { path: 'agent/definitions/edit/:id', children: [] },
        ]),
        { provide: NavigationService, useValue: new StubNavigation() as unknown as NavigationService },
        { provide: AccountPreferences, useValue: preferences },
        { provide: Session, useValue: session },
      ],
    });
    TestBed.inject(RecentsRecorder);
    router = TestBed.inject(Router);
  });

  it('registers a visit for each built screen the browser arrives at, newest first', async () => {
    await router.navigateByUrl('/logs/alerts');
    await router.navigateByUrl('/permissions/users');

    await settled();

    expect(preferences.recents()).toEqual(['permissions/users', 'logs/alerts']);
  });

  it('registers nothing for a URL that resolves to no built screen', async () => {
    await router.navigateByUrl('/no-such-area/no-such-screen');
    await settled();
    expect(preferences.recents()).toEqual([]);
  });

  it('registers nothing for Home, which declares the empty route the instance refuses', async () => {
    // Arrived at from somewhere else: the router ignores a navigation to the URL it is already
    // on, and its initial URL is `/`, so going straight there fires no NavigationEnd to record.
    await router.navigateByUrl('/logs/alerts');
    await router.navigateByUrl('/');
    await settled();

    expect(preferences.recents()).toEqual(['logs/alerts']);
    // Mutation (Rule 19): drop `|| screen.route === ''` from `RecentsRecorder.record` -> this goes
    // red on the second write. The list assertion above cannot: the instance refuses an empty
    // route and the store never settles one, so the rendered list reads the same either way.
    expect(writes()).toHaveLength(1);
  });

  it('registers nothing for an unlisted screen, whose stored route would open a create form', async () => {
    // `agent/definitions/edit` declares sideBarPosition 0 and takes an entity id, so the route
    // that would be stored for `/agent/definitions/edit/42` is the id-less parent. A Recent items
    // row for it opens the Definition form with no definition -- the create form -- which is what
    // `command-box.ts` filters `isListedScreen` to avoid on the same roster.
    await router.navigateByUrl('/agent/definitions/edit/42');
    await settled();

    expect(preferences.recents()).toEqual([]);
    // Mutation (Rule 19): drop `|| !isListedScreen(screen)` from `RecentsRecorder.record` -> both
    // of these go red, and every definition edit, database-details drill and wallet-secret view
    // puts a row on Home that opens an empty form.
    expect(writes()).toHaveLength(0);
  });

  it('registers nothing while the tab is signed out, and the screen is still new once it signs in', async () => {
    // Back from the sign-in card to a listed screen is a navigation like any other, but the tab
    // has no principal to write for. Created and removed here: the session state is this test's own.
    session.current = 'form';
    await router.navigateByUrl('/logs/alerts');
    await settled();

    // Mutation (Rule 19): drop `if (!waiting && !isSignedIn(state)) return;` from
    // `RecentsRecorder.record` -> this goes red, one `POST /account/preferences` from a tab that
    // is signed out.
    expect(writes()).toHaveLength(0);
    expect(preferences.recents()).toEqual([]);

    // The refused arrival does not latch `lastRoute`, and is not held for the sign-in: the same
    // screen, reached once the tab is signed in, is registered.
    session.move('signed-in');
    await settled();
    expect(writes()).toHaveLength(0);

    await router.navigateByUrl('/logs/alerts?ns=USER');
    await settled();

    expect(writes()).toHaveLength(1);
    expect(preferences.recents()).toEqual(['logs/alerts']);
  });

  it.each(['probing', 'installing'] as const)(
    'holds the latest listed arrival made while the session is %s, and registers it when the session signs in',
    async (waiting) => {
      // A deep link's first navigation ends before the silent sign-in has answered, and the later
      // arrival is where the tab is by the time it does.
      session.current = waiting;
      await router.navigateByUrl('/logs/alerts');
      await router.navigateByUrl('/permissions/users');
      await settled();

      // Mutation (Rule 19): make `record` register a waiting arrival at once -> this goes red, a
      // write from a tab whose principal is not yet known.
      expect(writes()).toHaveLength(0);

      session.move('signed-in');
      await settled();

      // Mutation (Rule 19): make `record` return for a waiting arrival instead of holding it ->
      // this goes red, and a deep link to a listed screen never reaches Recent items. Holding the
      // first arrival (`??=`) instead of the latest reddens the list below alone.
      expect(writes()).toHaveLength(1);
      expect(preferences.recents()).toEqual(['permissions/users']);
    }
  );

  it('registers a held arrival once, so a later pass through the waiting states does not bring it back', async () => {
    session.current = 'probing';
    await router.navigateByUrl('/logs/alerts');
    session.move('signed-in');
    await settled();
    await router.navigateByUrl('/permissions/users');
    await settled();
    expect(preferences.recents()).toEqual(['permissions/users', 'logs/alerts']);

    // The session leaves `signed-in` and comes back: nothing is owed.
    session.move('probing');
    session.move('signed-in');
    await settled();

    // Mutation (Rule 19): drop `this.pendingRoute = null` from `settle` -> this goes red, a third
    // write that puts the screen the tab left a minute ago back at the front of Recent items.
    expect(writes()).toHaveLength(2);
    expect(preferences.recents()).toEqual(['permissions/users', 'logs/alerts']);
  });

  it('drops a held arrival when the session settles on anything but signed-in, and never brings it back', async () => {
    session.current = 'probing';
    await router.navigateByUrl('/logs/alerts');
    session.move('form');
    await settled();

    // Mutation (Rule 19): register the held route on any settled state (drop `isSignedIn(state)`
    // from `settle`'s condition) -> this goes red, a write from a tab left on the sign-in form.
    expect(writes()).toHaveLength(0);

    // The person signs in on the form. The arrival they left before it is not theirs to have.
    session.move('probing');
    session.move('signed-in');
    await settled();

    // Mutation (Rule 19): clear the held route only when it is registered (move `this.pendingRoute
    // = null` inside the `isSignedIn(state)` branch) -> this goes red, a visit from before the
    // principal signed in.
    expect(writes()).toHaveLength(0);
    expect(preferences.recents()).toEqual([]);
  });

  it('keeps a held arrival through the shell\'s resets while the session moves between the waiting states', async () => {
    // `app.ts` calls `reset()` on every move into a state other than `signed-in`, so a deep link
    // that meets `installing` after `probing` has been reset twice by the time it signs in.
    const recorder = TestBed.inject(RecentsRecorder);
    session.current = 'probing';
    await router.navigateByUrl('/logs/alerts');
    recorder.reset();
    session.move('installing');
    recorder.reset();
    session.move('signed-in');
    await settled();

    // Mutation (Rule 19): clear `pendingRoute` in `reset` -> this goes red, and a deep link that
    // waits through an install never reaches Recent items.
    expect(writes()).toHaveLength(1);
    expect(preferences.recents()).toEqual(['logs/alerts']);
  });

  it('holds nothing for an unlisted screen reached while the session is waiting', async () => {
    session.current = 'probing';
    await router.navigateByUrl('/agent/definitions/edit/42');
    session.move('signed-in');
    await settled();

    // Mutation (Rule 19): hold the route before `record` tests `isListedScreen` -> this goes red,
    // a write for the Definition form's id-less create route.
    expect(writes()).toHaveLength(0);
  });

  it('holds nothing for Home reached while the session is waiting', async () => {
    await router.navigateByUrl('/logs/alerts');
    session.move('probing');
    await router.navigateByUrl('/');
    session.move('signed-in');
    await settled();

    // Mutation (Rule 19): hold the route before `record` tests it for `''` -> this goes red, a
    // second write, for the empty route the instance refuses.
    expect(writes()).toHaveLength(1);
  });

  it('a second arrival at the same screen costs no second registration', async () => {
    await router.navigateByUrl('/logs/alerts');
    // A namespace switch is a navigation that leaves the screen where it is.
    await router.navigateByUrl('/logs/alerts?ns=USER');

    await settled();

    expect(preferences.recents()).toEqual(['logs/alerts']);
    // Mutation (Rule 19): drop the `lastRoute` guard from `RecentsRecorder.record` -> this goes
    // red. The list assertion above cannot: re-adding the front route answers the same list.
    expect(writes()).toHaveLength(1);
  });

  it('a reset forgets the last route, so the next principal resuming on it is registered', async () => {
    // Mutation (Rule 19): delete `RecentsRecorder.reset`'s body -> this goes red, and the one
    // screen the next principal resumes on is the one screen their recents never get.
    const recorder = TestBed.inject(RecentsRecorder);
    await router.navigateByUrl('/logs/alerts');
    await settled();
    expect(writes()).toHaveLength(1);

    recorder.reset();
    // A sign-out leaves the tab where it was, so the next principal's first arrival is this same
    // screen. Without the reset the `lastRoute` guard swallows it and nothing is registered.
    await router.navigateByUrl('/logs/alerts?ns=USER');
    await settled();

    expect(writes()).toHaveLength(2);
  });

  it('returning to a screen after leaving it registers it again, so it moves back to the front', async () => {
    await router.navigateByUrl('/logs/alerts');
    await router.navigateByUrl('/permissions/users');
    await router.navigateByUrl('/logs/alerts');

    await settled();

    expect(preferences.recents()).toEqual(['logs/alerts', 'permissions/users']);
  });
});

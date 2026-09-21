import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { AccountPreferences } from '../core/account-preferences';
import { NavigationService, screenForRoute } from '../core/navigation';
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

describe('the recents recorder', () => {
  let preferences: StubbedAccountPreferences;
  let router: Router;

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

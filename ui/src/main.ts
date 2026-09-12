import { provideZonelessChangeDetection } from '@angular/core';
import { bootstrapApplication } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';

import { App } from './app/app';
import { routes } from './app/app.routes';
import { ApiService } from './app/core/api';
import { InstanceService } from './app/core/instance';
import { NavigationService } from './app/core/navigation';
import { OverlayStack } from './app/core/overlay-stack';
import { PreferenceStore, readPreferenceStorage } from './app/core/preferences';
import { ScopeService, onScopeChange } from './app/core/scope';
import { Session } from './app/core/session';
import { ShellState } from './app/core/shell-state';
import { TokenStore, readNavigationKind, readSessionStorage } from './app/core/token-store';

// Zoneless, standalone bootstrap (AD-19), with the transport layer constructed over the
// real browser and provided as values.
//
// `provideHttpClient` is deliberately absent. The core modules use `fetch` directly, which
// is what keeps them importable by `node --test`. The component suite (`ng test`, Story 1.9,
// DW-93) renders the shell components against these same classes provided as values, so the
// two test hosts exercise one set of objects rather than two.
//
// The silent probe starts here rather than in a component, so the request is already in
// flight while Angular is still painting the shell: on a browser that is signed in to the
// classic portal, the skeleton is often gone before it has been seen.
//
// `readSessionStorage()` rather than `sessionStorage`: in a browser with site data blocked
// the property access itself throws, and at module scope that would abort the bootstrap
// before anything painted. The store's own try/catch cannot help -- it never gets the
// object. A sign-in screen that cannot remember is better than one that cannot render.
const tokens = new TokenStore({
  storage: readSessionStorage(),
  navigationType: readNavigationKind,
});

const session = new Session({
  fetch: (path, init) => fetch(path, init),
  tokens,
});

// `onForbidden` and `scope` both reach services constructed below -- deliberately. Neither
// arrow is called during construction, only on a 403 or a request that arrives later, by which
// time the bindings are initialised. Writing either the other way round is impossible: both
// services need the API service to fetch what they hold.
const api: ApiService = new ApiService({
  fetch: (path, init) => fetch(path, init),
  tokens,
  session,
  onForbidden: () => navigation.noteForbidden(),
  scope: () => scope.namespace(),
});

// The instance check, the navigation map and the namespace list are not started here: all three
// need a Bearer, and there is none until the probe above has settled. `App` and the namespace
// switch make the calls once the session reaches `signed-in`.
const instance = new InstanceService({ api });
const navigation = new NavigationService({ api });
const scope: ScopeService = new ScopeService({ api });

// AD-44's "switching re-fetches rather than re-routing", wired once: the scope's consumer in
// this story is the navigation map, which is computed per call and must be re-read against the
// namespace the shell is now scoped to. `onScopeChange` fires only when the RESOLVED scope
// moves, so a route event that changes nothing costs no request.
//
// The `loaded()` guard is for the one move that is not a switch: sign-out resets the scope, which
// drops the resolved namespace to `''` and would otherwise wake the map read that the same
// sign-out has just dropped (AD-8).
onScopeChange(scope, () => {
  if (scope.loaded()) navigation.reload();
});

// The one module permitted to touch persistent storage, and the shell state it backs. Read
// through `readPreferenceStorage()` rather than `localStorage` directly, for the reason
// `readSessionStorage()` exists: in a browser with site data blocked the property access
// itself throws, and at module scope that would abort the bootstrap before anything painted.
const preferences = new PreferenceStore({ storage: readPreferenceStorage() });
const shell = new ShellState({ preferences });

// The one authority over Escape (DW-137). Built here like every other core service so the
// command box, the account menu and the side bar all register with the same instance --
// three stacks would be three independent Escape handlers again.
const overlays = new OverlayStack();

session.start();

bootstrapApplication(App, {
  providers: [
    provideZonelessChangeDetection(),
    provideRouter(routes),
    { provide: TokenStore, useValue: tokens },
    { provide: Session, useValue: session },
    { provide: ApiService, useValue: api },
    { provide: InstanceService, useValue: instance },
    { provide: NavigationService, useValue: navigation },
    { provide: ScopeService, useValue: scope },
    { provide: PreferenceStore, useValue: preferences },
    { provide: ShellState, useValue: shell },
    { provide: OverlayStack, useValue: overlays },
  ],
}).catch((err) => console.error(err));

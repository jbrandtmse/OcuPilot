import { provideZonelessChangeDetection } from '@angular/core';
import { bootstrapApplication } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';

import { App } from './app/app';
import { routes } from './app/app.routes';
import { ApiService } from './app/core/api';
import { Session } from './app/core/session';
import { TokenStore, readNavigationKind, readSessionStorage } from './app/core/token-store';

// Zoneless, standalone bootstrap (AD-19), with the transport layer constructed over the
// real browser and provided as values.
//
// `provideHttpClient` is deliberately absent. The core modules use `fetch` directly, which
// is what keeps them importable by `node --test` -- and that import is the only executed
// test host the client half of this story has, since there is no component runner until
// Story 1.9 (DW-93).
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

const api = new ApiService({
  fetch: (path, init) => fetch(path, init),
  tokens,
  session,
});

session.start();

bootstrapApplication(App, {
  providers: [
    provideZonelessChangeDetection(),
    provideRouter(routes),
    { provide: TokenStore, useValue: tokens },
    { provide: Session, useValue: session },
    { provide: ApiService, useValue: api },
  ],
}).catch((err) => console.error(err));

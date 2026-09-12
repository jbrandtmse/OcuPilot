import { Routes } from '@angular/router';

import { DeepLink } from './shell/deep-link';

/**
 * The route shape AD-13 fixes: `/<area>/<screen>[/<id>]`, resolved against the
 * `<base href="/ocupilot/">` the build sets, with the namespace travelling as the
 * `?ns=` query parameter rather than as a segment.
 *
 * Every route resolves to the same placeholder component, and the wildcard is what
 * keeps a pasted URL the client does not yet know from falling through to a blank
 * page -- the server already answers `index.html` for it. Story 1.9 replaces this
 * table with the descriptor registry, so it stays exactly this small.
 */
export const routes: Routes = [
  { path: '', pathMatch: 'full', component: DeepLink },
  { path: ':area/:screen', component: DeepLink },
  { path: ':area/:screen/:id', component: DeepLink },
  { path: '**', component: DeepLink },
];

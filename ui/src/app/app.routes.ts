import { Routes } from '@angular/router';

import { builtScreens, hasIdRoute } from './core/navigation';
import type { ScreenDeclaration } from './core/screens.generated';
import { ScreenOutlet } from './shell/screen-outlet';

/**
 * The route table, built from the descriptor mirror (AD-5). Adding a screen means adding a
 * descriptor and regenerating `core/screens.generated.ts`; it never means editing this file.
 *
 * One route per **built** screen at its declared route, plus `<route>/:id` for the screens
 * whose id accessor says they are keyed by one (AD-13: the id is one segment, always), plus a
 * wildcard so a URL the client does not know renders the shell's not-found screen rather than a
 * blank page -- the server already answers `index.html` for it.
 *
 * Home's declared route is the empty string, which is the application root: it is reached from
 * the rail's Home item, the logo lockup and straight after sign-in, all three of which mean
 * `/ocupilot/`. `pathMatch: 'full'` is what keeps it from swallowing every other route.
 *
 * **This adapter is the reason the route table lives outside `core/`.** It imports
 * `@angular/router`; `core/` stays framework-free so `node --test` can execute the registry,
 * the gate view and the preference store without a browser.
 */
export const routes: Routes = buildRoutes(builtScreens());

/**
 * The route table for a given roster.
 *
 * **It takes its roster rather than reading the mirror**, so its branches have a subject whatever
 * the mirror ships. `app.routes.spec.ts` drives them over a two-screen fixture; the exported
 * table above is still the mirror's, so nothing about what ships is decided here.
 */
export function buildRoutes(screens: readonly ScreenDeclaration[]): Routes {
  const built: Routes = [];
  for (const screen of screens) {
    if (screen.route === '') {
      // The root screen administers no entity -- Home's descriptor declares `id.kind` `none` --
      // so it takes no id route. One at the root would be `/:id`, which would swallow every
      // other single-segment route in the table.
      built.push({ path: '', pathMatch: 'full', component: ScreenOutlet });
      continue;
    }
    built.push({ path: screen.route, component: ScreenOutlet });
    if (hasIdRoute(screen)) {
      built.push({ path: `${screen.route}/:id`, component: ScreenOutlet });
    }
  }
  built.push({ path: '**', component: ScreenOutlet });
  return built;
}

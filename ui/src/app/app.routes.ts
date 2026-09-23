import { inject } from '@angular/core';
import { type CanDeactivateFn, Routes } from '@angular/router';

import { FormDirty } from './core/form-dirty';
import { DIALOG_EDITORS, builtScreens, hasIdRoute } from './core/navigation';
import type { ScreenDeclaration } from './core/screens.generated';
import { ScreenOutlet } from './shell/screen-outlet';

/**
 * The unsaved-changes guard, on every `form-page` route (AC2, AD-11 rule 3).
 *
 * **One guard answers for every caller.** Angular runs a route's `CanDeactivateFn` inside
 * `Router.navigateByUrl` and lets it return a promise; a `false` cancels the navigation and the
 * promise `navigateByUrl` returned resolves `false`. Every programmatic navigation in this client
 * is that method -- the rail, the side bar, the locator bar, the command box, the header, the
 * fault banner, the data table, Home and the audit page -- so none of them has a guard of its own,
 * and the agent's navigation tool inherits the answer by construction when it lands, because it
 * will call the same method.
 *
 * It asks `FormDirty`, which resolves `true` at once on a clean form and raises the confirmation
 * on a dirty one. The question is a store's rather than a component's because the guard runs with
 * no component to reach (`core/form-dirty.ts`).
 */
export const leaveFormGuard: CanDeactivateFn<unknown> = () => inject(FormDirty).requestLeave();

/** The archetype whose routes carry the guard. */
const GUARDED_ARCHETYPE = 'form-page';

/**
 * The route table, built from the descriptor mirror (AD-5). Adding a screen means adding a
 * descriptor and regenerating `core/screens.generated.ts`; it never means editing this file.
 *
 * One route per **built** screen at its declared route, plus `<route>/:id` for the screens
 * whose id accessor says they are keyed by one (AD-13: the id is one segment, always), plus a
 * wildcard so a URL the client does not know renders the shell's not-found screen rather than a
 * blank page -- the server already answers `index.html` for it.
 *
 * **The roster is `builtScreens()`, not an area's listed screens.** A screen declaring
 * `sideBarPosition` 0 is routable and never advertised (`core/navigation.ts`), so the filter that
 * keeps it out of the side bar, the command box, Home's tile caption, the locator bar and the rail
 * must not reach this table or the screen would be unreachable.
 *
 * Every `form-page` route carries the unsaved-changes guard above, and so does every route of a
 * screen whose editor is a dialog over it (`DIALOG_EDITORS`).
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
    const guarded =
      screen.archetype === GUARDED_ARCHETYPE || DIALOG_EDITORS.has(screen.descriptor)
        ? { canDeactivate: [leaveFormGuard] }
        : {};
    built.push({ path: screen.route, component: ScreenOutlet, ...guarded });
    if (hasIdRoute(screen)) {
      built.push({ path: `${screen.route}/:id`, component: ScreenOutlet, ...guarded });
    }
  }
  built.push({ path: '**', component: ScreenOutlet });
  return built;
}

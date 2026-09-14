import { describe, expect, it } from 'vitest';

import { builtScreens, hasIdRoute } from './core/navigation';
import type { ScreenDeclaration } from './core/screens.generated';
import { ScreenOutlet } from './shell/screen-outlet';
import { buildRoutes, routes } from './app.routes';

/**
 * The route table is derived from the descriptor mirror, not typed out (AD-5). Adding a screen
 * is adding a descriptor; nothing in this file is edited for it, which is what this asserts.
 *
 * Mutation (Rule 19): add a literal route to `app.routes.ts` -> the "every route comes from a
 * descriptor" assertion goes red naming it.
 */
describe('the route table', () => {
  const paths = () => routes.map((route) => route.path);

  it('carries one route per built screen, and every path comes from a descriptor', () => {
    const declared = new Set<string>();
    for (const screen of builtScreens()) {
      declared.add(screen.route);
      if (hasIdRoute(screen) && screen.route !== '') declared.add(`${screen.route}/:id`);
    }
    declared.add('**');

    for (const path of paths()) {
      expect(path).toBeDefined();
      expect(declared.has(path as string)).toBe(true);
    }
    for (const route of declared) {
      expect(paths()).toContain(route);
    }
  });

  it("the application root is Home's, matched in full so it swallows nothing", () => {
    const root = routes.find((route) => route.path === '');
    expect(root).toBeDefined();
    expect(root?.pathMatch).toBe('full');
    expect(builtScreens().some((screen) => screen.route === '')).toBe(true);
  });

  it('the wildcard is last, so an unknown URL renders the not-found screen rather than nothing', () => {
    expect(paths()[paths().length - 1]).toBe('**');
  });

  it('every route resolves to the one routed component this epic ships', () => {
    for (const route of routes) {
      expect(route.component).toBe(ScreenOutlet);
    }
  });

  it('a screen that declares no id accessor gets no /:id route', () => {
    for (const screen of builtScreens()) {
      if (hasIdRoute(screen)) continue;
      expect(paths()).not.toContain(`${screen.route}/:id`);
    }
  });

  // The assertions above are computed from `builtScreens()`, so what they exercise follows
  // whatever the mirror ships, and the `/:id` branch has no negative subject there. This drives
  // both branches of `buildRoutes` over a roster chosen here, which is why it takes its screens.
  //
  // Mutation (Rule 19): delete the `/:id` push from `app.routes.ts` -> the third assertion
  // below goes red; delete the non-root push beside it -> the first and second go red. Neither
  // turns any other test in this file red, which is the gap this case closes.
  it('gives a non-root screen its route, and an id-keyed screen its /:id beside it', () => {
    const screen = (route: string, kind: 'none' | 'single'): ScreenDeclaration =>
      ({ route, area: 'permissions', built: true, sideBarPosition: 1, id: { kind, parts: [] } }) as unknown as ScreenDeclaration;

    const built = buildRoutes([screen('permissions/users', 'single'), screen('permissions/roles', 'none')]);
    const paths = built.map((route) => route.path);

    expect(paths).toContain('permissions/users');
    expect(paths).toContain('permissions/roles');
    expect(paths).toContain('permissions/users/:id');
    expect(paths).not.toContain('permissions/roles/:id');
    expect(paths[paths.length - 1]).toBe('**');
    for (const route of built) expect(route.component).toBe(ScreenOutlet);
    expect(built.some((route) => route.pathMatch === 'full')).toBe(false);
  });
});

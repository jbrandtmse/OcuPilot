import { describe, expect, it } from 'vitest';

import { DIALOG_EDITORS, builtScreens, hasIdRoute } from './core/navigation';
import type { ScreenDeclaration } from './core/screens.generated';
import { ScreenOutlet } from './shell/screen-outlet';
import { buildRoutes, leaveFormGuard, routes } from './app.routes';

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

  it('no declared route is swallowed by an earlier one, so every screen keeps its own guard', () => {
    // Angular takes the first route whose segments match, a `:id` matching any one segment. Story
    // 18.14 puts the mapping lists at `os-management/namespaces/<kind>-mappings`, the shape
    // `os-management/namespaces/:id` also matches, and each form at `<list>/edit`, the shape its
    // list's `:id` matches; Story 18.17 lists the Integrity log, `os-management/databases/integrity-log`,
    // after Databases, whose `:id` matches it. `buildRoutes` emits every declared route ahead of every
    // `:id` route, which keeps each literal ahead of the parameter that would otherwise take it and
    // drop the form's leave guard.
    //
    // Mutation (Rule 19): push each `:id` route right after its own route in `buildRoutes` -> the
    // Integrity log is taken by Databases' `:id` route and this goes red naming it.
    const matches = (pattern: string, path: string): boolean => {
      const want = pattern.split('/');
      const got = path.split('/');
      return want.length === got.length && want.every((segment, index) => segment.startsWith(':') || segment === got[index]);
    };
    const swallowed: string[] = [];
    for (const path of paths()) {
      if (path === undefined || path === '' || path === '**' || path.includes(':')) continue;
      const first = paths().find((candidate) => candidate !== undefined && candidate !== '**' && candidate !== '' && matches(candidate, path));
      if (first !== path) swallowed.push(`${path} by ${first}`);
    }
    expect(swallowed).toEqual([]);
    for (const kind of ['global', 'routine', 'package']) {
      expect(paths()).toContain(`os-management/namespaces/${kind}-mappings`);
      expect(paths()).toContain(`os-management/namespaces/${kind}-mappings/edit`);
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
  // below goes red; delete the non-root push -> the first and second go red. Neither
  // turns any other test in this file red, which is the gap this case closes.
  it('gives a non-root screen its route, and an id-keyed screen its /:id', () => {
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

  // Story 8.4, AC7: a screen whose editor is a dialog over it asks before any navigation leaves it,
  // as a `form-page` does, and an ordinary list does not.
  //
  // Mutation (Rule 19): drop the `DIALOG_EDITORS` test from `buildRoutes` -> the dialog-editor
  // assertions go red.
  it('guards a form page and a dialog-editor screen on both routes, and no other screen', () => {
    const screen = (route: string, archetype: string, descriptor: string): ScreenDeclaration =>
      ({ route, archetype, descriptor, area: 'permissions', built: true, sideBarPosition: 1, id: { kind: 'single', parts: [] } }) as unknown as ScreenDeclaration;
    const [editor] = [...DIALOG_EDITORS];
    const built = buildRoutes([
      screen('permissions/resources', 'list', editor),
      screen('permissions/roles/edit', 'form-page', 'Probe.Form'),
      screen('permissions/services', 'list', 'Probe.List'),
    ]);
    const guarded = (path: string) => built.find((route) => route.path === path)?.canDeactivate ?? [];
    expect(guarded('permissions/resources')).toEqual([leaveFormGuard]);
    expect(guarded('permissions/resources/:id')).toEqual([leaveFormGuard]);
    expect(guarded('permissions/roles/edit')).toEqual([leaveFormGuard]);
    expect(guarded('permissions/services')).toEqual([]);
    expect(guarded('permissions/services/:id')).toEqual([]);

    expect(editor).toBe('OcuPilot.Screen.Descriptor.ResourceList');
    const shipped = (path: string) => routes.find((route) => route.path === path)?.canDeactivate ?? [];
    expect(shipped('permissions/resources')).toEqual([leaveFormGuard]);
    expect(shipped('permissions/resources/:id')).toEqual([leaveFormGuard]);
  });
});

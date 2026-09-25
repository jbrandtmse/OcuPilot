/**
 * The fixed shortcuts roster Home's Shortcuts block renders (Story 15.3, FR-73, SH-18).
 *
 * **The classic portal's own seventeen, named as OcuPilot routes.** `%ZEN.Portal.Application`'s
 * `GetContextLinks` declares seventeen captioned shortcuts (plus three separators, which are
 * layout and not entries); each row below is the OcuPilot screen that replaces one of them, in the
 * classic menu's own order. Nothing here is a search: 15.2 settled that the command box is the one
 * finder, and a second one would be a defect.
 *
 * **A row naming no built screen is dropped** (AD-37 degrade). Seven of the seventeen replace
 * screens OcuPilot has not built -- the four System Explorer views are Stage 3, and namespace
 * configuration, memory and startup, and background tasks are later work -- so their routes
 * resolve to nothing in the mirror and `shortcutScreens()` leaves them out. They stay declared so
 * the block can complete itself as those screens land (**inference** -- no descriptor declares any
 * of those seven routes yet, so each spelling is this file's guess at one and nothing fails if the
 * screen lands under another; check them against the descriptors when those screens are built).
 *
 * **A row adds no string.** Its label is the screen's own `labelKey`, read from the mirror, so a
 * screen renamed once is renamed everywhere (AD-5).
 *
 * Framework-free, like the rest of `core/` (AD-19), so `ui/tools/about.test.mjs` executes it under
 * `node --test`.
 */

import { screenForRoute } from './navigation.ts';
import type { ScreenDeclaration } from './screens.generated';

/**
 * The seventeen, in the classic menu's order. A route with no screen behind it is one OcuPilot has
 * not built; it is dropped from the rendering, never rendered as a row that opens nothing.
 */
export const SHORTCUT_ROUTES: readonly string[] = [
  'os-management/namespaces',
  'os-management/databases',
  'os-management/memory',
  'web-applications/list',
  'permissions/users',
  'permissions/roles',
  'permissions/services',
  'permissions/resources',
  'system-explorer/sql',
  'system-explorer/classes',
  'system-explorer/routines',
  'system-explorer/globals',
  'os-management/system-usage',
  'os-management/locks',
  'os-management/processes',
  'logs/messages',
  'tasks/background',
];

/**
 * The roster's built screens, in roster order.
 *
 * `built` is the whole filter: every route above names a screen a person navigates to directly, so
 * none of them is the id-less parent of an unlisted editor that Home's remembered rows have to
 * guard against.
 */
export function shortcutScreens(): readonly ScreenDeclaration[] {
  const out: ScreenDeclaration[] = [];
  for (const route of SHORTCUT_ROUTES) {
    const screen = screenForRoute(route);
    if (screen === null || !screen.built) continue;
    out.push(screen);
  }
  return out;
}

/** One key binding Home's Shortcuts block lists as text: its label's and its keys' string keys. */
export interface ShortcutKey {
  readonly labelKey: string;
  readonly keysKey: string;
}

/**
 * The key bindings the Shortcuts block lists after its screen rows (Story 15.8). Text, not
 * controls: a binding is pressed where it applies, so nothing here opens anything.
 */
export const SHORTCUT_KEYS: readonly ShortcutKey[] = [
  { labelKey: 'tableColumnResizeShortcut', keysKey: 'tableColumnResizeKeys' },
];

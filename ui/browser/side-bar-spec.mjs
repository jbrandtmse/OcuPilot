/**
 * The side bar's listed labels, derived from the mirror rather than pinned (DW-1774, Story 18.7).
 *
 * Every browser spec that asserts which entries a side bar lists, or in which order, compares against
 * `sideBarLabels(<area>)` instead of a literal list or count: an added screen then changes this one
 * derivation, not every spec that happens to read the side bar. It registers no test and sits outside
 * the `*.browser-spec.mjs` glob; `ui/tools/side-bar-pins.test.mjs` holds the specs to it.
 *
 * The labels are `listedScreensForArea(<area>)`'s, through the one string source, imported from the
 * TypeScript sources as `gate.browser-spec.mjs` imports `STRINGS` and `SCREENS`.
 */

import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { listedScreensForArea } = await import(join(uiRoot, 'src', 'app', 'core', 'navigation.ts'));

/** The labels `areaKey`'s side bar lists, in side-bar order. */
export function sideBarLabels(areaKey) {
  return listedScreensForArea(areaKey).map((screen) => STRINGS[screen.labelKey]);
}

/**
 * The entries of `entries` (each `{label, ...}`) whose label one of `expected` names, in the side bar's
 * order: a leg that is about some entries' verdicts compares those exactly, and asserts the whole
 * order through `sideBarLabels`.
 */
export function entriesAbout(entries, expected) {
  const labels = expected.map((entry) => entry.label);
  return entries.filter((entry) => labels.includes(entry.label));
}

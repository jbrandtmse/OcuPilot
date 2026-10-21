/**
 * What this file pins: a browser spec measures a structural pass only once the layout has settled.
 * The shell re-resolves its layout from `(window:resize)` after the viewport has changed, the panel's
 * width transition may still be running after that, and a theme toggle starts colour transitions of
 * its own, so a `detectScreen` call straight after either can read the layout of the moment before.
 *
 * The rule, over every `ui/browser/*.mjs` that calls `detectScreen(`: between the last viewport
 * change (`setViewport(` or `settleViewport(`) or theme toggle (`setDarkTheme(`,
 * `toggleThemeThroughMenu(` or a `classList.toggle('ocu-theme-dark', ...)`) and each `detectScreen(`
 * call, in text order, there is a `transitionsSettled(` or `panelSettlesAt(` call. A file that never
 * changes its viewport before a call is not asked for one. A second rule covers the specs that
 * measure a pass without `detectScreen` (`LOCAL_PASSES`): every viewport change in them is followed
 * by a `transitionsSettled(` or `panelSettlesAt(` call before the next change or the end of the
 * file. The scan is lexical, over the source with comments blanked (`browser-reset.mjs`'s
 * `stripComments`), so a call named in a doc comment or a `function` declaration is not a call.
 * Needs nothing from the environment: the fixtures are strings and the shipped tree is read from disk.
 *
 * Mutations (Rule 19), each applied, observed red and reverted:
 * - one swept file's `transitionsSettled(` call removed -> "the shipped browser specs measure only
 *   a settled layout" goes red, naming that file and the `detectScreen(` line.
 * - the scan's reset on a viewport change dropped -> "a viewport change after the settle asks for
 *   a new one" goes red.
 * - the scan's reset on a theme toggle dropped -> "a theme toggle after the settle asks for a new
 *   one" goes red.
 * - one `LOCAL_PASSES` file's `transitionsSettled(` call removed -> "the specs that measure without
 *   detectScreen settle after every viewport change" goes red, naming that file and the line.
 */

import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { BROWSER_DIR, readSources, stripComments } from './browser-reset.mjs';

/** The calls that change the viewport or the theme, the calls that wait for the layout, and the measuring call. */
const TOKEN =
  /(?<![A-Za-z0-9_$])(?<!function\s+)(detectScreen|transitionsSettled|panelSettlesAt|settleViewport|toggleThemeThroughMenu|setDarkTheme)\s*\(|\.setViewport\s*\(|\.goto\s*\(|classList\.toggle\(\s*(['"])ocu-theme-dark\2/g;

/** The specs that measure a pass with their own evaluation rather than `detectScreen`. */
const LOCAL_PASSES = ['agent-code-save.browser-spec.mjs', 'header-lockup.browser-spec.mjs'];

/** A floor under the scan: a tree that reads as few specs measuring after a viewport change is a scan that stopped finding them. */
const SCANNED_FLOOR = 75;

/** What one match of `TOKEN` is: `viewport`, `theme`, `navigate`, `settle` or `measure`. */
function kindOf(match) {
  const name = match[1];
  if (name === undefined) {
    if (match[0].startsWith('.setViewport')) return 'viewport';
    if (match[0].startsWith('.goto')) return 'navigate';
    return 'theme';
  }
  if (name === 'settleViewport') return 'viewport';
  if (name === 'toggleThemeThroughMenu' || name === 'setDarkTheme') return 'theme';
  if (name === 'transitionsSettled' || name === 'panelSettlesAt') return 'settle';
  return 'measure';
}

function lineAt(code, index) {
  return code.slice(0, index).split('\n').length;
}

/**
 * The 1-based line of every `detectScreen(` call in `source` that follows a viewport change or a
 * theme toggle with no settle between them.
 */
function unsettledMeasures(source) {
  const code = stripComments(source);
  const lines = [];
  let viewportChanged = false;
  let settled = false;
  for (const match of code.matchAll(TOKEN)) {
    const kind = kindOf(match);
    if (kind === 'viewport') {
      viewportChanged = true;
      settled = false;
    } else if (kind === 'theme') {
      settled = false;
    } else if (kind === 'settle') {
      settled = true;
    } else if (kind === 'measure' && viewportChanged && !settled) {
      lines.push(lineAt(code, match.index));
    }
  }
  return lines;
}

/**
 * The 1-based line of every viewport change in `source` that no settle follows before the next
 * change or the end. A navigation in the statement right after a change ends it: the page loads at
 * the viewport it was given.
 */
function unsettledViewportChanges(source) {
  const code = stripComments(source);
  const lines = [];
  let pending = 0;
  let changes = 0;
  let changedAt = 0;
  for (const match of code.matchAll(TOKEN)) {
    const kind = kindOf(match);
    if (kind === 'viewport') {
      if (pending !== 0) lines.push(pending);
      pending = lineAt(code, match.index);
      changedAt = match.index;
      changes += 1;
    } else if (kind === 'settle') {
      pending = 0;
    } else if (kind === 'navigate' && pending !== 0 && (code.slice(changedAt, match.index).match(/;/g) ?? []).length <= 1) {
      pending = 0;
    }
  }
  if (pending !== 0) lines.push(pending);
  return { lines, changes };
}

test('a measure straight after a viewport change is unsettled', () => {
  const source = ['await page.setViewport(viewport);', 'await detectScreen(page, {});'].join('\n');
  assert.deepEqual(unsettledMeasures(source), [2]);
});

test('settleViewport alone does not wait for the transitions', () => {
  const source = ['await settleViewport(page, viewport);', 'await detectScreen(page, {});'].join('\n');
  assert.deepEqual(unsettledMeasures(source), [2]);
});

test('transitionsSettled or panelSettlesAt between the change and the measure settles it', () => {
  for (const wait of ['transitionsSettled(page, 1000)', 'panelSettlesAt(page, 720)']) {
    const source = ['await settleViewport(page, viewport);', `await ${wait};`, 'await detectScreen(page, {});'].join('\n');
    assert.deepEqual(unsettledMeasures(source), [], wait);
  }
});

test('a viewport change after the settle asks for a new one', () => {
  const source = [
    'await settleViewport(page, narrow);',
    'await transitionsSettled(page, 1000);',
    'await detectScreen(page, {});',
    'await page.setViewport(wide);',
    'await detectScreen(page, {});',
  ].join('\n');
  assert.deepEqual(unsettledMeasures(source), [5]);
});

test('a theme toggle after the settle asks for a new one', () => {
  for (const toggle of ['await setDarkTheme(page, true);', 'await toggleThemeThroughMenu(page, requests, 1000);', "await page.evaluate(() => document.documentElement.classList.toggle('ocu-theme-dark', true));"]) {
    const after = ['await settleViewport(page, narrow);', 'await transitionsSettled(page, 1000);', toggle, 'await detectScreen(page, {});'].join('\n');
    assert.deepEqual(unsettledMeasures(after), [4], toggle);
    const before = ['await settleViewport(page, narrow);', toggle, 'await transitionsSettled(page, 1000);', 'await detectScreen(page, {});'].join('\n');
    assert.deepEqual(unsettledMeasures(before), [], toggle);
  }
});

test('a file that never changes its viewport is not asked for a settle', () => {
  assert.deepEqual(unsettledMeasures('await detectScreen(page, {});'), []);
});

test('a call named in a comment or declared with function is not a call', () => {
  const source = [
    '// await page.setViewport(viewport) then detectScreen(page, {})',
    '/* await detectScreen(page, {}) */',
    'export async function detectScreen(page, options) {',
    '  return page.evaluate(() => 0);',
    '}',
    'export async function setDarkTheme(page, dark) {',
    "  await page.evaluate((name, on) => document.documentElement.classList.toggle(name, on), 'ocu-theme-dark', dark);",
    '}',
    'await page.setViewport(viewport);',
    '// transitionsSettled(page, 1000) is not called here',
    'await detectScreen(page, {});',
  ].join('\n');
  assert.deepEqual(unsettledMeasures(source), [11]);
});

test('a viewport change no settle follows is reported, whatever measures next', () => {
  const settled = ['await settleViewport(page, narrow);', 'await transitionsSettled(page, 1000);', 'await settleViewport(page, wide);', 'await transitionsSettled(page, 1000);'].join('\n');
  assert.deepEqual(unsettledViewportChanges(settled), { lines: [], changes: 2 });
  const skipped = ['await settleViewport(page, narrow);', 'await page.setViewport(wide);', 'await transitionsSettled(page, 1000);'].join('\n');
  assert.deepEqual(unsettledViewportChanges(skipped), { lines: [1], changes: 2 });
  assert.deepEqual(unsettledViewportChanges('await page.setViewport(wide);'), { lines: [1], changes: 1 });
  const loaded = ['await tab.setViewport(viewport);', 'await tab.goto(url, { waitUntil: "networkidle2" });'].join('\n');
  assert.deepEqual(unsettledViewportChanges(loaded), { lines: [], changes: 1 }, 'a viewport given before the page loads is not a change to settle');
  const later = ['await page.setViewport(wide);', 'await measure(page);', 'await page.goto(url);'].join('\n');
  assert.deepEqual(unsettledViewportChanges(later), { lines: [1], changes: 1 }, 'a navigation further on does not settle it');
});

test('the shipped browser specs measure only a settled layout', () => {
  const dir = join(dirname(fileURLToPath(import.meta.url)), '..', BROWSER_DIR);
  const refused = [];
  let scanned = 0;
  for (const [name, source] of readSources(dir)) {
    const code = stripComments(source);
    if (!/(?<!function\s+)detectScreen\s*\(/.test(code) || !/\.setViewport\s*\(|settleViewport\s*\(/.test(code)) continue;
    scanned += 1;
    for (const line of unsettledMeasures(source)) refused.push(`${name}:${line}`);
  }
  assert.ok(scanned >= SCANNED_FLOOR, `the scan found ${scanned} specs that measure after a viewport change, fewer than ${SCANNED_FLOOR}`);
  assert.deepEqual(refused, [], 'each detectScreen( call above follows a viewport or theme change with no transitionsSettled( or panelSettlesAt( call between them');
});

test('the specs that measure without detectScreen settle after every viewport change', () => {
  const dir = join(dirname(fileURLToPath(import.meta.url)), '..', BROWSER_DIR);
  const sources = new Map(readSources(dir));
  const refused = [];
  for (const name of LOCAL_PASSES) {
    assert.ok(sources.has(name), `${name} is a browser spec`);
    const { lines, changes } = unsettledViewportChanges(sources.get(name));
    assert.ok(changes > 0, `${name} changes its viewport, so the rule has something to hold`);
    for (const line of lines) refused.push(`${name}:${line}`);
  }
  assert.deepEqual(refused, [], 'each viewport change above has no transitionsSettled( or panelSettlesAt( call before the next change or the end of the file');
});

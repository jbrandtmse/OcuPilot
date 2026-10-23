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

import { BROWSER_DIR, functionUnits, readSources, stripComments } from './browser-reset.mjs';

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

/*
 * The scan above reads calls by name, so it holds only while the names do what they say. The tests
 * below hold the other end of DW-2455:
 *
 * - a declaration is not a call, wherever it sits: a `function transitionsSettled(` between a viewport
 *   change and a measure is not a settle, and a `function detectScreen(` after one is not a measure;
 * - every `transitionsSettled` a browser spec defines waits on a running CSS transition, and every
 *   `panelSettlesAt` on the panel's measured width, so a helper emptied out under its old name fails
 *   here rather than passing the scan;
 * - the shared `settleViewport` and `transitionsSettled` in `panel-spec.mjs` do what their callers
 *   rely on, run against a page that records what it is asked.
 *
 * Mutation (Rule 19), each applied, observed red and reverted:
 * - the scan's `(?<!function\s+)` dropped -> the declaration test goes red.
 * - one spec's `transitionsSettled` with a `return Promise.resolve()` ahead of its wait, or its
 *   `'running'` test changed -> "every transitionsSettled and panelSettlesAt the browser specs define"
 *   goes red.
 * - the panel wait's `opens` back to `/^\{/` -> "a settle helper that waits on nothing is found" goes
 *   red at the panel wait that returns before it measures.
 * - the shared `transitionsSettled` emptied, its running test inverted, or its `instanceof
 *   CSSTransition` guard dropped -> the shared transitionsSettled test goes red.
 * - the shared `settleViewport` without its width wait, with the wait before the viewport change, or
 *   with one frame in place of two -> the shared settleViewport test goes red.
 */

/** The bodies of the functions named `name` in `code`, read by `browser-reset.mjs`'s `functionUnits`, as `{ line, body }`. */
function declarations(code, name) {
  return functionUnits(code)
    .filter((unit) => unit.name === name)
    .map(({ index, body }) => ({ line: lineAt(code, index), body }));
}

/**
 * What each settle helper's body must read, and how it must begin: a transition wait with the wait
 * itself, and a panel wait with no return ahead of its measure, so that nothing returns early.
 */
const SETTLE_BODIES = {
  transitionsSettled: { reads: ['getAnimations(', 'CSSTransition', "'running'"], opens: /^\{\s*return\s+page\.waitForFunction\(/ },
  panelSettlesAt: { reads: ['getBoundingClientRect(', 'Math.abs('], opens: /^\{(?!\s*return\b)/ },
};

/** `{ declared, hollow }`: how many settle helpers `source` defines, and the `line` of each whose body lacks what it must read. */
function settleHelpers(source) {
  const code = stripComments(source);
  let declared = 0;
  const hollow = [];
  for (const [name, { reads, opens }] of Object.entries(SETTLE_BODIES)) {
    for (const { line, body } of declarations(code, name)) {
      declared += 1;
      if (!opens.test(body) || !reads.every((text) => body.includes(text))) hollow.push(line);
    }
  }
  return { declared, hollow };
}

test('a function declaration named like a settle or a measure is neither', () => {
  const settleDeclared = ['await page.setViewport(viewport);', 'async function transitionsSettled(page) {', '  return page.waitForFunction(() => true);', '}', 'await detectScreen(page, {});'].join('\n');
  assert.deepEqual(unsettledMeasures(settleDeclared), [5], 'declaring transitionsSettled after a change does not settle it');
  const measureDeclared = ['await page.setViewport(viewport);', 'export async function detectScreen(page, options) {', '  return 0;', '}'].join('\n');
  assert.deepEqual(unsettledMeasures(measureDeclared), [], 'declaring detectScreen after a change does not measure');
  assert.deepEqual(unsettledViewportChanges(['await page.setViewport(wide);', 'function transitionsSettled(page) {}'].join('\n')), { lines: [1], changes: 1 }, 'nor does it settle a change in the local-pass rule');
});

test('a settle helper that waits on nothing is found, and one that reads what it must is not', () => {
  const sound = ['function transitionsSettled(page) {', '  return page.waitForFunction(() => document.getAnimations().every((a) => !(a instanceof CSSTransition) || a.playState !== \'running\'), { timeout: 5 });', '}'].join('\n');
  assert.deepEqual(settleHelpers(sound), { declared: 1, hollow: [] });
  assert.deepEqual(settleHelpers('function transitionsSettled(page) {\n  return Promise.resolve();\n}'), { declared: 1, hollow: [1] }, 'a helper that returns at once');
  assert.deepEqual(settleHelpers(sound.replace("'running'", "'finished'")), { declared: 1, hollow: [1] }, 'a helper that reads the wrong state');
  assert.deepEqual(settleHelpers(sound.replace('CSSTransition', 'CSSAnimation')), { declared: 1, hollow: [1] }, 'a helper that reads the wrong kind');
  assert.deepEqual(settleHelpers(sound.replace('  return page', '  return Promise.resolve();\n  return page')), { declared: 1, hollow: [1] }, 'a helper that returns ahead of its wait');
  const panel = 'async function panelSettlesAt(page, width) {\n  const seen = await page.evaluate(() => document.querySelector(\'aside\').getBoundingClientRect().width);\n  if (Math.abs(seen - width) < 0.01) return;\n}';
  assert.deepEqual(settleHelpers(panel), { declared: 1, hollow: [] });
  assert.deepEqual(settleHelpers('async function panelSettlesAt(page, width) {\n  return;\n}'), { declared: 1, hollow: [1] }, 'a panel wait that measures nothing');
  assert.deepEqual(settleHelpers(panel.replace('{\n  const seen', '{\n  return;\n  const seen')), { declared: 1, hollow: [1] }, 'a panel wait that returns before it measures');
  assert.deepEqual(settleHelpers('// function transitionsSettled(page) { return 1; }\nconst x = 1;'), { declared: 0, hollow: [] }, 'a comment declares nothing');
});

test('every transitionsSettled and panelSettlesAt the browser specs define waits on what its name says', () => {
  const dir = join(dirname(fileURLToPath(import.meta.url)), '..', BROWSER_DIR);
  let declared = 0;
  const hollow = [];
  for (const [name, source] of readSources(dir)) {
    const found = settleHelpers(source);
    declared += found.declared;
    for (const line of found.hollow) hollow.push(`${name}:${line}`);
  }
  assert.ok(declared >= 30, `the scan found ${declared} settle helpers, fewer than the thirty the specs define`);
  assert.deepEqual(hollow, [], 'each helper above lacks the read its name promises (running CSS transitions, or the panel width)');
});

/** Run `run` with `values` set on `globalThis`, and put every one back as it was. */
async function withGlobals(values, run) {
  const saved = Object.keys(values).map((key) => [key, Object.getOwnPropertyDescriptor(globalThis, key)]);
  for (const [key, value] of Object.entries(values)) Object.defineProperty(globalThis, key, { value, configurable: true, writable: true });
  try {
    return await run();
  } finally {
    for (const [key, descriptor] of saved) {
      if (descriptor === undefined) delete globalThis[key];
      else Object.defineProperty(globalThis, key, descriptor);
    }
  }
}

/** A page that records what it is asked, in order, and answers none of it. */
function recordingPage() {
  const calls = [];
  return {
    calls,
    setViewport: async (viewport) => void calls.push({ kind: 'setViewport', viewport }),
    waitForFunction: async (predicate, options, ...args) => void calls.push({ kind: 'waitForFunction', predicate, options, args }),
    evaluate: async (fn, ...args) => void calls.push({ kind: 'evaluate', fn, args }),
  };
}

test('the shared settleViewport sets the viewport, waits for the document to take its width, then lets two frames render', async () => {
  const { settleViewport } = await import('../browser/panel-spec.mjs');
  const page = recordingPage();
  await settleViewport(page, { width: 720, height: 450 });
  assert.deepEqual(page.calls.map((call) => call.kind), ['setViewport', 'waitForFunction', 'evaluate'], 'in that order');
  assert.deepEqual(page.calls[0].viewport, { width: 720, height: 450 });
  const wait = page.calls[1];
  assert.deepEqual(wait.args, [720], 'it waits for the width it set');
  await withGlobals({ document: { documentElement: { clientWidth: 1280 } } }, () => assert.equal(wait.predicate(...wait.args), false, 'the width before the change is not the new one'));
  await withGlobals({ document: { documentElement: { clientWidth: 720 } } }, () => assert.equal(wait.predicate(...wait.args), true, 'the new width is'));
  const frames = [];
  await withGlobals({ requestAnimationFrame: (callback) => void frames.push(callback) }, async () => {
    let done = false;
    const pending = page.calls[2].fn().then(() => {
      done = true;
    });
    assert.equal(frames.length, 1, 'the first frame is requested at once');
    frames.shift()();
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(done, false, 'one frame is not enough');
    assert.equal(frames.length, 1, 'the second is requested from the first');
    frames.shift()();
    await pending;
    assert.equal(done, true, 'two frames are');
  });
});

test('the shared transitionsSettled waits until no CSS transition is running, within the timeout it is given', async () => {
  const { transitionsSettled } = await import('../browser/panel-spec.mjs');
  const page = recordingPage();
  await transitionsSettled(page, 4321);
  assert.equal(page.calls.length, 1, 'it asks the page once');
  const [wait] = page.calls;
  assert.equal(wait.kind, 'waitForFunction');
  assert.deepEqual(wait.options, { timeout: 4321 }, 'the timeout it was given');
  class CSSTransition {}
  class CSSAnimation {}
  const animation = (Kind, playState) => Object.assign(new Kind(), { playState });
  const verdict = (animations) => withGlobals({ CSSTransition, CSSAnimation, document: { getAnimations: () => animations } }, () => wait.predicate());
  assert.equal(await verdict([]), true, 'nothing is animating');
  assert.equal(await verdict([animation(CSSTransition, 'running')]), false, 'a transition is running');
  assert.equal(await verdict([animation(CSSTransition, 'finished'), animation(CSSTransition, 'running')]), false, 'one of two is');
  assert.equal(await verdict([animation(CSSTransition, 'finished')]), true, 'a finished transition does not hold the measure');
  assert.equal(await verdict([animation(CSSAnimation, 'running')]), true, 'a running animation that is not a transition does not either');
});

/*
 * `settleViewport` is a viewport change plus the wait that lets the resize land, and
 * `transitionsSettled` finds the width transition only once that resize has started it. A bare
 * `page.setViewport(` followed straight away by `transitionsSettled(` can answer before the resize
 * event has run, with no transition yet running, and the measure that follows reads the layout of the
 * moment before (observed on the throwaway: the panel read 400 px, its width before the change, where
 * it settles at 320). So where a spec keeps a bare `.setViewport(`, a frame must go by before the
 * settle that clears its measure: a call to a shared frame wait or `setDarkTheme`, a function of its
 * own that requests an animation frame, or `requestAnimationFrame` itself.
 *
 * Mutation (Rule 19), each applied, observed red and reverted:
 * - `settleViewport(` replaced by a bare `page.setViewport(` in a loop that has no frame wait of its
 *   own -> "a bare setViewport leaves a frame to go by in every shipped spec that measures after it"
 *   names the file and the settle's line.
 * - the frame wait deleted from a pass that keeps its bare `page.setViewport(` -> the same test.
 */

/** The names a call to which lets the layout land: the shared frame waits, and any function `code` declares that requests an animation frame. */
function landingWaits(code) {
  const names = new Set(['settleViewport', 'setDarkTheme', 'framesGoBy']);
  for (const { name, body } of functionUnits(code)) if (body.includes('requestAnimationFrame')) names.add(name);
  return names;
}

/**
 * The 1-based line of every `transitionsSettled(` or `panelSettlesAt(` call that clears a
 * `detectScreen(` call while the last viewport change was a bare `.setViewport(` and no frame went by
 * between that change and the settle.
 */
function unlandedSettles(source) {
  const code = stripComments(source);
  const names = ['detectScreen', 'transitionsSettled', 'panelSettlesAt', ...landingWaits(code)];
  const calls = new RegExp(`(?<![A-Za-z0-9_$])(?<!function\\s+)(${names.join('|')})\\s*\\(|\\.setViewport\\s*\\(|requestAnimationFrame`, 'g');
  const lines = new Set();
  let bare = false;
  let landed = false;
  let first = null;
  for (const match of code.matchAll(calls)) {
    const name = match[1];
    if (name === undefined && match[0].startsWith('.setViewport')) {
      bare = true;
      landed = false;
      first = null;
    } else if (name === 'settleViewport') {
      bare = false;
      first = null;
    } else if (name === 'transitionsSettled' || name === 'panelSettlesAt') {
      if (first === null) first = { line: lineAt(code, match.index), landed };
    } else if (name === 'detectScreen') {
      if (bare && first !== null && !first.landed) lines.add(first.line);
    } else {
      landed = true;
    }
  }
  return [...lines].sort((a, b) => a - b);
}

test('a bare setViewport leaves a frame to go by before the settle that clears a measure', () => {
  const frames = ['async function frames(page) {', '  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));', '}'];
  const nap = ['async function nap(page) {', '  await new Promise((resolve) => setTimeout(resolve, 10));', '}'];
  const run = (...lines) => unlandedSettles(lines.join('\n'));
  assert.deepEqual(run(...frames, 'await page.setViewport(viewport);', 'await frames(page);', 'await transitionsSettled(page, 1);', 'await detectScreen(page, {});'), [], 'a frame wait of the file\'s own lands the resize');
  assert.deepEqual(run('await page.setViewport(viewport);', 'await transitionsSettled(page, 1);', 'await detectScreen(page, {});'), [2], 'a settle straight after a bare change can answer before the resize starts a transition');
  assert.deepEqual(run('await page.setViewport(viewport);', 'await panelSettlesAt(page, 320);', 'await detectScreen(page, {});'), [2], 'and so can the panel-width wait');
  assert.deepEqual(run(...nap, 'await page.setViewport(viewport);', 'await nap(page);', 'await transitionsSettled(page, 1);', 'await detectScreen(page, {});'), [6], 'a wait that requests no frame is not one');
  assert.deepEqual(run('await page.setViewport(viewport);', 'await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(resolve)));', 'await transitionsSettled(page, 1);', 'await detectScreen(page, {});'), [], 'requestAnimationFrame itself is');
  assert.deepEqual(run('await settleViewport(page, viewport);', 'await transitionsSettled(page, 1);', 'await detectScreen(page, {});'), [], 'settleViewport lands it');
  assert.deepEqual(run('await page.setViewport(viewport);', 'await setDarkTheme(page, true);', 'await transitionsSettled(page, 1);', 'await detectScreen(page, {});'), [], 'setDarkTheme renders two frames');
  assert.deepEqual(run('await page.setViewport(viewport);', 'await toggleThemeThroughMenu(page, requests, 1);', 'await transitionsSettled(page, 1);', 'await detectScreen(page, {});'), [3], 'a toggle through the menu is not, since a loop may skip it for the pass that stays light');
  assert.deepEqual(run('await settleViewport(page, narrow);', 'await transitionsSettled(page, 1);', 'await detectScreen(page, {});', 'await page.setViewport(wide);', 'await transitionsSettled(page, 1);'), [], 'a bare change nothing measures after is not asked for a frame');
  assert.deepEqual(run(...frames, 'await page.setViewport(a);', 'await frames(page);', 'await transitionsSettled(page, 1);', 'await detectScreen(page, {});', 'await page.setViewport(b);', 'await transitionsSettled(page, 1);', 'await detectScreen(page, {});'), [9], 'the next bare change asks for its own frame');
  assert.deepEqual(run('// await page.setViewport(viewport);', 'await settleViewport(page, viewport);', 'await transitionsSettled(page, 1);', 'await detectScreen(page, {});'), [], 'a change named in a comment is not one');
});

test('a bare setViewport leaves a frame to go by in every shipped spec that measures after it', () => {
  const dir = join(dirname(fileURLToPath(import.meta.url)), '..', BROWSER_DIR);
  const refused = [];
  for (const [name, source] of readSources(dir)) {
    const code = stripComments(source);
    if (!/(?<!function\s+)detectScreen\s*\(/.test(code) || !/\.setViewport\s*\(|settleViewport\s*\(/.test(code)) continue;
    for (const line of unlandedSettles(source)) refused.push(`${name}:${line}`);
  }
  assert.deepEqual(refused, [], 'each settle above follows a bare setViewport( with no settleViewport(, setDarkTheme( or frame wait between them');
});

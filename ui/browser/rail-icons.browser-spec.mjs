/**
 * The rail's and Home's area icons in a real browser (Story 15.7): every rail item and tile draws
 * `shell/rail-icons.ts`'s shapes for its area key, the icons add nothing to any accessible name and
 * load nothing from another origin, and each rail state's stroke is the glyph's color at the
 * contrast DESIGN.md records, in light and in dark, for `_SYSTEM` and for a least-privileged
 * principal whose gated items stay at 45% under the pointer.
 *
 * Expected colors are read from `_tokens.scss` through `design-tokens.mjs`, never retyped; the
 * contrast figures are DESIGN.md's contrast table (`:786`, `:813-825`), except hover, which DESIGN.md
 * does not record and which was measured over the 8% hover background at plan time. A ratio is
 * measured on the computed colors, compositing the element's background stack and its stroke with
 * each channel rounded to 8 bits per layer, as DESIGN.md's figures are.
 *
 * Needs an instance with no enabled definition, so the attention dot is lit for `_SYSTEM`. The
 * principal comes from `OcuPilot.Test.TurnWireFixture` and is removed afterwards, so the spec
 * refuses the live container. Run: `npm run build`, redeploy the bundle, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/rail-icons.browser-spec.mjs`
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { parseMarkers } from './iris-session.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { AREAS } = await import(join(uiRoot, 'src', 'app', 'core', 'screens.generated.ts'));
const { stringFor } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { THEME_DARK_CLASS } = await import(join(uiRoot, 'src', 'app', 'core', 'theme.ts'));
const { AREA_ICON_STROKE_WIDTH, areaIcon, areaIconViewBox } = await import(
  join(uiRoot, 'src', 'app', 'shell', 'rail-icons.ts')
);
const { contrastRatio, parseTokens } = await import(join(uiRoot, 'tools', 'design-tokens.mjs'));

const config = browserConfig();
const tokens = parseTokens(readFileSync(join(uiRoot, 'src', 'styles', '_tokens.scss'), 'utf8'));

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const WIDE = { width: 1280, height: 900 };
const TOLERANCE = 0.05;

/** The figures, light / dark, on the element's own ground (see the header for their source). */
const FIGURES = {
  rest: { light: 6.15, dark: 7.31 },
  hover: { light: 8.32, dark: 10.44 },
  active: { light: 10.35, dark: 12.85 },
  gated: { light: 3.38, dark: 3.7 },
  dot: { light: 8.09, dark: 10.81 },
  indicator: { light: 6.72, dark: 8.97 },
  tile: { light: 9.97, dark: 10.69 },
  tileGated: { light: 6.55, dark: 9.64 },
};

const railOrder = [...AREAS].sort((a, b) => a.railPosition - b.railPosition);
const tileAreas = railOrder.filter((area) => !area.navigates && !area.pinBottom);

const password = `OcuPilotIcons${randomBytes(12).toString('hex')}Aa9`;
let principal = '';
let browser = null;

/** Run ObjectScript lines in the throwaway and answer the named markers. */
function irisSession(lines, names) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${['Set $NAMESPACE=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")', ...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { values: parseMarkers(output, names), output };
}

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a principal, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const created = irisSession(
    [
      'Set tUser=##class(OcuPilot.Test.TurnWireFixture).#USERA',
      `Set tSC=##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal(tUser,"${password}",##class(OcuPilot.Test.TurnWireFixture).Resources(1))`,
      marker('USER', 'tUser'),
      marker('OK', '$System.Status.IsOK(tSC)'),
    ],
    ['USER', 'OK']
  );
  assert.equal(created.values.OK, '1', `the fixture created the principal: ${created.output}`);
  principal = created.values.USER;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const removed = irisSession([marker('LEFT', '##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()')], ['LEFT']);
  assert.equal(removed.values.LEFT, '', `the probe principal and its role are gone: ${removed.output}`);
});

/**
 * A fresh context signed in as `user` and standing on Home, with every request the page makes
 * recorded. The remembered state is forgotten first (`preferences-reset.mjs`).
 */
async function openHome(user, secret) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  const requests = [];
  page.on('request', (request) => requests.push(request.url()));
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(WIDE);
  await page.goto(`${config.origin}${HOME_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', secret);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, HOME_URL);
  await page.waitForSelector('.ocu-area-tile .ocu-area-tile-icon > svg', { timeout: config.navigationTimeoutMs });
  return { context, page, requests };
}

/** Flip the theme the way the store does: the one root class. */
function setDark(page, dark) {
  return page.evaluate((name, on) => document.documentElement.classList.toggle(name, on), THEME_DARK_CLASS, dark);
}

/** The module's shapes in the serialized form the page reports. */
function expectedShapes(key, size) {
  return (areaIcon(key, size) ?? []).map((shape) => ({ tag: shape.tag, attrs: Object.entries(shape.attrs) }));
}

/** Every rail item's and tile's icon, as rendered: root attributes, children, and any title. */
function renderedIcons(page) {
  return page.evaluate(() => {
    const icon = (svg) => ({
      namespace: svg.namespaceURI,
      // The svg's box against its slot's: the structural walk measures HTML elements only.
      outside: (() => {
        const box = svg.getBoundingClientRect();
        const slot = svg.parentElement.getBoundingClientRect();
        return Math.max(slot.left - box.left, box.right - slot.right, slot.top - box.top, box.bottom - slot.bottom);
      })(),
      // The slot's own content overflow: an inline svg's line box and baseline gap spill below it.
      spill: Math.max(
        svg.parentElement.scrollHeight - svg.parentElement.clientHeight,
        svg.parentElement.scrollWidth - svg.parentElement.clientWidth
      ),
      root: Object.fromEntries(['viewBox', 'width', 'height', 'fill', 'stroke', 'stroke-width', 'aria-hidden', 'focusable'].map((name) => [name, svg.getAttribute(name)])),
      described: svg.querySelector('title, desc') !== null,
      text: svg.textContent,
      shapes: [...svg.children].map((child) => ({
        tag: child.localName,
        namespace: child.namespaceURI,
        attrs: [...child.attributes].filter((attr) => !attr.name.startsWith('_ng') && !attr.name.startsWith('ng-')).map((attr) => [attr.name, attr.value]),
      })),
    });
    return {
      rail: [...document.querySelectorAll('.ocu-rail-item')].map((button) => ({
        id: button.id,
        label: button.getAttribute('aria-label'),
        children: button.children.length,
        glyphText: button.querySelector('.ocu-rail-glyph').textContent,
        svgs: button.querySelectorAll('.ocu-rail-glyph > svg').length,
        icon: icon(button.querySelector('.ocu-rail-glyph > svg')),
      })),
      tiles: [...document.querySelectorAll('.ocu-area-tile')].map((button) => ({
        name: button.querySelector('.ocu-area-tile-name').textContent.trim(),
        svgs: button.querySelectorAll('.ocu-area-tile-icon > svg').length,
        icon: icon(button.querySelector('.ocu-area-tile-icon > svg')),
      })),
    };
  });
}

/** Assert every rail item and tile draws the module's shapes for its area key. */
async function assertShapes(page, theme) {
  const seen = await renderedIcons(page);
  const svgNs = 'http://www.w3.org/2000/svg';
  const root = (size) => ({
    viewBox: areaIconViewBox(size),
    width: String(size),
    height: String(size),
    fill: 'none',
    stroke: 'currentColor',
    'stroke-width': AREA_ICON_STROKE_WIDTH,
    'aria-hidden': 'true',
    focusable: 'false',
  });
  assert.equal(seen.rail.length, railOrder.length, `${theme}: one rail item per area`);
  for (const [index, area] of railOrder.entries()) {
    const item = seen.rail[index];
    assert.equal(item.id, `ocu-rail-item-${area.key}`, `${theme}: rail position ${area.railPosition} is ${area.key}`);
    assert.equal(item.label, stringFor(area.labelKey), `${theme}: ${area.key} is named for its area`);
    assert.equal(item.children, 1, `${theme}: ${area.key}'s button holds only its glyph`);
    assert.equal(item.glyphText, '', `${theme}: ${area.key}'s glyph holds no text, no letter`);
    assert.equal(item.svgs, 1, `${theme}: ${area.key}'s glyph holds one svg`);
    assert.equal(item.icon.namespace, svgNs);
    assert.deepEqual(item.icon.root, root(20), `${theme}: ${area.key}'s icon root`);
    assert.ok(item.icon.outside <= 0.5, `${theme}: ${area.key}'s icon stays inside its 20px glyph (${item.icon.outside}px past it)`);
    assert.ok(item.icon.spill <= 0, `${theme}: ${area.key}'s glyph holds its icon without spilling (${item.icon.spill}px)`);
    assert.equal(item.icon.described, false, `${theme}: ${area.key}'s icon has no title or desc`);
    assert.ok(item.icon.shapes.every((shape) => shape.namespace === svgNs), `${theme}: ${area.key}'s shapes are SVG elements`);
    assert.deepEqual(
      item.icon.shapes.map(({ tag, attrs }) => ({ tag, attrs })),
      expectedShapes(area.key, 20),
      `${theme}: ${area.key}'s rail shapes are the module's`
    );
  }
  assert.deepEqual(seen.tiles.map((tile) => tile.name), tileAreas.map((area) => stringFor(area.labelKey)), `${theme}: one tile per tile area, in rail order`);
  for (const [index, area] of tileAreas.entries()) {
    const tile = seen.tiles[index];
    assert.equal(tile.svgs, 1, `${theme}: ${area.key}'s tile holds one svg`);
    assert.deepEqual(tile.icon.root, root(24), `${theme}: ${area.key}'s tile icon root`);
    assert.ok(tile.icon.outside <= 0.5, `${theme}: ${area.key}'s tile icon stays inside its 24px slot (${tile.icon.outside}px past it)`);
    assert.ok(tile.icon.spill <= 0, `${theme}: ${area.key}'s tile slot holds its icon without spilling (${tile.icon.spill}px)`);
    assert.equal(tile.icon.described, false, `${theme}: ${area.key}'s tile icon has no title or desc`);
    assert.equal(tile.icon.text, '', `${theme}: ${area.key}'s tile icon holds no text`);
    assert.deepEqual(
      tile.icon.shapes.map(({ tag, attrs }) => ({ tag, attrs })),
      expectedShapes(area.key, 24),
      `${theme}: ${area.key}'s tile shapes are the module's`
    );
  }
}

/**
 * Chrome's accessible names for every rail item and tile, each tile's visible text (its text
 * nodes outside `aria-hidden`), and whether any icon svg has an unignored AX node.
 */
async function accessibleNames(page) {
  const client = await page.createCDPSession();
  try {
    const { root } = await client.send('DOM.getDocument', { depth: -1 });
    const nameOf = async (nodeId) => {
      const { nodes } = await client.send('Accessibility.getPartialAXTree', { nodeId, fetchRelatives: false });
      const node = nodes.find((candidate) => !candidate.ignored) ?? null;
      return node === null ? null : String(node.name?.value ?? '').trim();
    };
    const all = async (selector) => (await client.send('DOM.querySelectorAll', { nodeId: root.nodeId, selector })).nodeIds;
    const rail = [];
    for (const nodeId of await all('.ocu-rail-item')) rail.push(await nameOf(nodeId));
    const tiles = [];
    for (const nodeId of await all('.ocu-area-tile')) tiles.push(await nameOf(nodeId));
    const exposedIcons = [];
    for (const nodeId of await all('.ocu-rail-glyph > svg, .ocu-area-tile-icon > svg')) {
      const { nodes } = await client.send('Accessibility.getPartialAXTree', { nodeId, fetchRelatives: false });
      if (nodes.some((node) => !node.ignored)) exposedIcons.push(nodeId);
    }
    const visible = await page.evaluate(() =>
      [...document.querySelectorAll('.ocu-area-tile')].map((button) => {
        const walker = document.createTreeWalker(button, NodeFilter.SHOW_TEXT);
        let text = '';
        for (let node = walker.nextNode(); node !== null; node = walker.nextNode()) {
          if (node.parentElement.closest('[aria-hidden="true"]') === null) text += ` ${node.textContent}`;
        }
        return text.trim();
      })
    );
    return { rail, tiles, visible, exposedIcons };
  } finally {
    await client.detach();
  }
}

/**
 * A computed color as `[r, g, b, a]`, channels 0-255 and alpha 0-1: the `rgb()`/`rgba()` form and
 * the `color(srgb ...)` form Chrome gives a `color-mix()` result.
 */
function parseColor(text) {
  const legacy = /^rgba?\(([^)]*)\)$/.exec(text);
  if (legacy !== null) {
    const parts = legacy[1].split(/[\s,/]+/).filter((part) => part !== '').map(Number);
    return [parts[0], parts[1], parts[2], parts.length > 3 ? parts[3] : 1];
  }
  const srgb = /^color\(srgb ([^)]*)\)$/.exec(text);
  if (srgb !== null) {
    const parts = srgb[1].split(/[\s/]+/).filter((part) => part !== '').map(Number);
    return [parts[0] * 255, parts[1] * 255, parts[2] * 255, parts.length > 3 ? parts[3] : 1];
  }
  throw new Error(`an unparsed computed color: ${text}`);
}

/**
 * `layers` painted bottom-up from the topmost opaque one, each channel rounded to 8 bits after each
 * layer -- the compositing DESIGN.md's figures are measured with.
 */
function composite(layers) {
  const colors = layers.map(parseColor);
  let base = -1;
  colors.forEach((color, index) => {
    if (color[3] === 1) base = index;
  });
  assert.ok(base >= 0, `an opaque ground under ${JSON.stringify(layers)}`);
  let out = colors[base].slice(0, 3).map(Math.round);
  for (const [r, g, b, a] of colors.slice(base + 1)) {
    out = [r, g, b].map((channel, i) => Math.round(channel * a + out[i] * (1 - a)));
  }
  return `#${out.map((v) => v.toString(16).padStart(2, '0')).join('')}`;
}

/**
 * The contrast of `selector`'s foreground on its own ground: the ground is the stack of
 * backgrounds from the root up to the element (its parent, for `part: 'background'`), and the
 * foreground is the icon's stroke (`'stroke'`), the element's own background (`'background'`),
 * or its `::before` background (`'before'`).
 */
async function measure(page, selector, part) {
  const seen = await page.evaluate(
    (sel, what) => {
      const el = document.querySelector(sel);
      if (el === null) return { missing: sel };
      const svg = el.querySelector('svg');
      const ground = [];
      for (let node = what === 'background' ? el.parentElement : el; node !== null; node = node.parentElement) {
        ground.unshift(getComputedStyle(node).backgroundColor);
      }
      const own = getComputedStyle(el).backgroundColor;
      const fg = what === 'stroke' ? getComputedStyle(svg).stroke : what === 'before' ? getComputedStyle(el, '::before').backgroundColor : own;
      return {
        stroke: svg === null ? null : getComputedStyle(svg).stroke,
        glyphColor: svg === null ? null : getComputedStyle(svg.parentElement).color,
        own,
        ground,
        fg,
      };
    },
    selector,
    part
  );
  assert.equal(seen.missing, undefined, `the page has ${seen.missing}`);
  const fgHex = composite([...seen.ground, seen.fg]);
  const bgHex = composite(seen.ground);
  return {
    ...seen,
    ownAlpha: parseColor(seen.own)[3],
    fgAlone: parseColor(seen.fg),
    ratio: contrastRatio(fgHex, bgHex),
  };
}

/** Park the pointer over the content, away from the rail and the tiles. */
async function pointerAway(page) {
  await page.mouse.move(WIDE.width - 40, WIDE.height - 40);
  await new Promise((resolve) => setTimeout(resolve, 150));
}

/** `rgb(r, g, b)` for a token hex, as `getComputedStyle` reports an opaque color. */
function rgb(hex) {
  const n = (at) => parseInt(hex.slice(at, at + 2), 16);
  return `rgb(${n(1)}, ${n(3)}, ${n(5)})`;
}

function assertFigure(t, measured, figure, theme, what) {
  t.diagnostic(`${theme}: ${what} ${measured.ratio.toFixed(2)}:1 (recorded ${figure[theme]}:1)`);
  assert.ok(measured.ratio >= 3, `${theme}: ${what} is ${measured.ratio.toFixed(3)}:1, below the 3:1 floor`);
  assert.ok(
    Math.abs(measured.ratio - figure[theme]) <= TOLERANCE,
    `${theme}: ${what} is ${measured.ratio.toFixed(3)}:1, recorded ${figure[theme]}:1 (${measured.fg} over ${JSON.stringify(measured.ground)})`
  );
}

test('(a) _SYSTEM at 1280: every rail item and tile draws its area key\'s shapes in both themes, the icons add nothing to any name, and nothing loads from another origin', async () => {
  const { context, page, requests } = await openHome(config.username, config.password);
  try {
    await assertShapes(page, 'light');
    const names = await accessibleNames(page);
    assert.deepEqual(names.rail, railOrder.map((area) => stringFor(area.labelKey)), 'each rail item is named its area and nothing else');
    assert.equal(names.tiles.length, tileAreas.length);
    for (const [index, area] of tileAreas.entries()) {
      assert.ok(names.tiles[index] !== null, `${area.key}'s tile has an accessible name`);
      assert.equal(
        names.tiles[index].replace(/\s+/g, ''),
        names.visible[index].replace(/\s+/g, ''),
        `${area.key}: the tile's name is its visible text -- ${JSON.stringify(names.tiles[index])}`
      );
      assert.ok(names.tiles[index].startsWith(stringFor(area.labelKey)), `${area.key}: the name starts with the area name`);
    }
    assert.deepEqual(names.exposedIcons, [], 'no icon svg has an accessibility node');

    await setDark(page, true);
    await assertShapes(page, 'dark');
    await setDark(page, false);

    const foreign = requests.filter((url) => !/^(data|blob):/.test(url) && new URL(url).origin !== config.origin);
    assert.deepEqual(foreign, [], 'every request the page made went to the instance itself');
    const svgFiles = requests.filter((url) => !/^(data|blob):/.test(url) && /\.svg$/i.test(new URL(url).pathname));
    assert.deepEqual(svgFiles, [], 'no SVG file is requested: the icons are inline');
  } finally {
    await context.close();
  }
});

test('(b) rail states: the stroke is the glyph color at the recorded contrast in light and dark, and the tile icon is primary', async (t) => {
  const { context, page } = await openHome(config.username, config.password);
  try {
    await page.waitForSelector('.ocu-rail-dot', { timeout: config.navigationTimeoutMs });
    const rest = '#ocu-rail-item-logs';
    const active = '#ocu-rail-item-home';
    const agent = '#ocu-rail-item-agent';
    assert.equal(await page.$eval(active, (el) => el.getAttribute('aria-current')), 'page', 'Home is the active item');
    for (const theme of ['light', 'dark']) {
      await setDark(page, theme === 'dark');
      await pointerAway(page);

      const atRest = await measure(page, rest, 'stroke');
      assert.equal(atRest.stroke, atRest.glyphColor, `${theme}: at rest the stroke is the glyph's color`);
      assertFigure(t, atRest, FIGURES.rest, theme, 'rest');

      const current = await measure(page, active, 'stroke');
      assert.equal(current.stroke, current.glyphColor, `${theme}: active, the stroke is the glyph's color`);
      assertFigure(t, current, FIGURES.active, theme, 'active');

      const indicator = await measure(page, active, 'before');
      assertFigure(t, indicator, FIGURES.indicator, theme, 'the active indicator');

      const withDot = await measure(page, agent, 'stroke');
      assert.equal(withDot.stroke, withDot.glyphColor, `${theme}: with the dot lit, the stroke is the glyph's color`);
      assertFigure(t, withDot, FIGURES.rest, theme, 'the Agent co-pilot icon beside the dot');
      const dot = await measure(page, '.ocu-rail-dot', 'background');
      assertFigure(t, dot, FIGURES.dot, theme, 'the attention dot');

      await page.hover(rest);
      await new Promise((resolve) => setTimeout(resolve, 150));
      const hovered = await measure(page, rest, 'stroke');
      assert.equal(hovered.stroke, hovered.glyphColor, `${theme}: under the pointer the stroke is the glyph's color`);
      assert.ok(hovered.ownAlpha > 0, `${theme}: the hover background is drawn`);
      assertFigure(t, hovered, FIGURES.hover, theme, 'hover');
      await pointerAway(page);

      const tile = await measure(page, '.ocu-area-tile:not([aria-disabled="true"]) .ocu-area-tile-icon', 'stroke');
      assert.deepEqual(tile.fgAlone, parseColor(rgb(tokens[theme].primary)), `${theme}: the tile icon strokes in primary`);
      assertFigure(t, tile, FIGURES.tile, theme, 'the tile icon');
    }
  } finally {
    await setDark(page, false).catch(() => {});
    await context.close();
  }
});

test('(c) a least-privileged principal: a gated rail icon stays at 45% at rest and under the pointer, and a gated tile icon is restrained, in both themes', async (t) => {
  const { context, page } = await openHome(principal, password);
  try {
    await page.waitForSelector('.ocu-rail-item-gated', { timeout: config.navigationTimeoutMs });
    const gatedKeys = await page.$$eval('.ocu-rail-item-gated', (items) => items.map((item) => item.id));
    assert.ok(gatedKeys.length >= 1, 'at least one rail item is gated for this principal');
    const gatedTiles = await page.$$eval('.ocu-area-tile[aria-disabled="true"]', (tiles) => tiles.length);
    assert.ok(gatedTiles >= 1, 'at least one tile is gated for this principal');
    const gated = `#${gatedKeys[0]}`;
    for (const theme of ['light', 'dark']) {
      await setDark(page, theme === 'dark');
      await pointerAway(page);

      const atRest = await measure(page, gated, 'stroke');
      assert.equal(atRest.stroke, atRest.glyphColor, `${theme}: gated at rest, the stroke is the glyph's color`);
      assertFigure(t, atRest, FIGURES.gated, theme, 'gated at rest');

      await page.hover(gated);
      await new Promise((resolve) => setTimeout(resolve, 150));
      const hovered = await measure(page, gated, 'stroke');
      assert.equal(hovered.stroke, hovered.glyphColor, `${theme}: gated under the pointer, the stroke is the glyph's color`);
      assert.equal(hovered.ownAlpha, 0, `${theme}: a gated item draws no hover background`);
      assertFigure(t, hovered, FIGURES.gated, theme, 'gated under the pointer');
      await pointerAway(page);

      const tile = await measure(page, '.ocu-area-tile[aria-disabled="true"] .ocu-area-tile-icon', 'stroke');
      assert.deepEqual(tile.fgAlone, parseColor(rgb(tokens[theme].restrained)), `${theme}: the gated tile icon strokes in restrained`);
      assertFigure(t, tile, FIGURES.tileGated, theme, 'the gated tile icon');
    }
  } finally {
    await setDark(page, false).catch(() => {});
    await context.close();
  }
});

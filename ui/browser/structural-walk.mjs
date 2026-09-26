/**
 * The structural walk (Story 15.6, DW-1337): one pass over every screen the registry declares,
 * checking four invariants on the deployed bundle -- an accessible name on every form field, no
 * interactive control narrower than its declared minimum, no element overflowing its container,
 * and text contrast -- in light at 1280 and 720 px and in dark at 1280 px.
 *
 * **The screens come from the registry at run time** (`navigation.ts` `builtScreens()`, AD-5), never
 * from a hand-written route list, so a screen a later epic adds is walked the day it merges. A
 * declared screen that is not built has no route and is counted, not walked. A screen that needs
 * an id -- one that declares `parentScope`, or the one-object viewer -- is walked at
 * `<route>/<id>`, the id taken from its parent list's first rendered row (or, for the viewer, the
 * `/api/ocupilot` application the REST explorer lists); one whose id cannot be found is named in
 * `SKIP` with its reason, and one in neither place fails the gate.
 *
 * **It runs in baseline form.** `a11y-structural-invariants.browser-spec.mjs` compares what the walk
 * finds against `structural-baseline.json` by key and fails only on a key outside it; a baseline
 * key the walk no longer finds is printed for removal and never fails. The baseline is taken once,
 * by `node browser/structural-walk.mjs --write` against a freshly started throwaway, and is never
 * regenerated: a regenerate would absorb every regression since the take. A screen added later
 * surfaces its violations as fresh entries, printed in the file's own shape for the merger to fix or
 * append.
 *
 * **A key** is `<route>|<invariant>|<context>|<element>`: `route` the declared route (`/` for Home,
 * `/:id` appended where the screen takes one); `context` the viewport for `min-width` and
 * `overflow`, the theme for `contrast`, and empty for `name`; `element` the nearest `app-*`
 * ancestor, the element's tag, its sorted `ocu-*` classes and its role. It carries no index and no
 * text, so row counts cannot multiply keys and equal keys on one screen collapse into one entry with
 * a `count`. Whether a key exists can still depend on what the instance renders -- a row link's
 * text width decides whether it falls under the floor.
 *
 * Named without the `.browser-spec` suffix, so `npm run test:browser` does not collect it as a spec.
 * Every context it opens comes from `signedInAt`, which forgets the account's remembered state
 * first (`preferences-reset.mjs`). Refuses the live container.
 */

import assert from 'node:assert/strict';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { signedInAt } from './panel-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { builtScreens } = await import(join(uiRoot, 'src', 'app', 'core', 'navigation.ts'));
const { SCREENS } = await import(join(uiRoot, 'src', 'app', 'core', 'screens.generated.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));
const { THEME_DARK_CLASS } = await import(join(uiRoot, 'src', 'app', 'core', 'theme.ts'));

/** The account menu's Dark theme item, and never a checkbox item some screen draws. */
const THEME_ITEM = '.ocu-account-panel [role="menuitemcheckbox"]';

/** Where the baseline lives. */
export const BASELINE_PATH = join(uiRoot, 'browser', 'structural-baseline.json');

/**
 * The two declared floors (no minimum supported width is declared anywhere): 1280 px is the
 * full-shell row (EXPERIENCE.md "Full shell: rail, side-bar (if open), content, panel at its remembered width"),
 * 720 px the 200%-zoom viewport of a 1,440 x 900 laptop (DESIGN.md's Reflow paragraph), which
 * also exercises the under-900 squeeze (EXPERIENCE.md "The squeeze rule, like VS Code").
 */
export const VIEWPORTS = {
  wide: { width: 1280, height: 900 },
  narrow: { width: 720, height: 450 },
};

/** The four invariants, as a key spells them. */
export const INVARIANTS = ['name', 'min-width', 'overflow', 'contrast'];

/** The namespace every walked route is scoped to (AD-44). */
const NAMESPACE_QUERY = '?ns=HSCUSTOM';

/** The one-object archetype that needs an id although it declares no parent. */
const VIEWER_ARCHETYPE = 'viewer (OpenAPI)';

/** The application the viewer is opened on: the precedent `rest-apis.browser-spec.mjs` uses. */
const VIEWER_ID = '/api/ocupilot';

/**
 * Id-requiring screens the walk does not open, each with its reason. A screen named here is
 * reported as skipped; an id-requiring screen that is neither here nor resolved fails the gate.
 */
export const SKIP = {};

/** How long a screen may take to settle before the walk records it as unsettled. */
const SETTLE_TIMEOUT_MS = 20000;

/** A screen is settled once no `/api/ocupilot` request has been in flight for this long. */
const QUIET_MS = 500;

/**
 * Declared minimum widths, each with its source. The CSS-px floor applies to every control; a more
 * specific entry replaces it. Token-sized controls are found in `_components.scss` and their width
 * is read from the token at run time, so no figure here is typed twice.
 */
export const MIN_WIDTH_SOURCES = {
  floor: { px: 24, source: 'EXPERIENCE.md "Target sizes." -- every control at least 24 x 24 CSS px' },
  classes: [
    { className: 'ocu-rail-item', px: 48, source: 'DESIGN.md rail-item.size 48px' },
    { className: 'ocu-data-table-trigger', px: 28, source: 'EXPERIENCE.md "Target sizes." -- the row-overflow-menu trigger 28 x 28' },
    { className: 'ocu-panel-resize-handle', px: 8, source: 'DESIGN.md panel-resize-handle -- an 8px hit area' },
  ],
  tokens: ['icon-button-size', 'panel-send-width'],
};

/**
 * Declared overflows, each with its source: an element carrying `className` may stand up to `px`
 * past its containing block by design, and the overflow check skips it only within that allowance
 * (plus the check's own 1px tolerance). Anything further past is still reported.
 */
export const OVERFLOW_ALLOWANCES = [
  { className: 'ocu-panel-resize-handle', px: 4, source: 'DESIGN.md panel-resize-handle -- 8px hit area on the panel edge' },
];

/** The classes `_components.scss` sizes by one of `MIN_WIDTH_SOURCES.tokens`, as `[{className, token}]`. */
export function tokenSizedClasses(componentsScss) {
  const out = [];
  for (const token of MIN_WIDTH_SOURCES.tokens) {
    const pattern = new RegExp('\\n\\.(ocu-[a-z0-9-]+)\\s*\\{[^}]*\\n\\s*width:\\s*var\\(--ocu-' + token + '\\)', 'g');
    for (const m of componentsScss.matchAll(pattern)) out.push({ className: m[1], token });
  }
  return out;
}

/** The token-sized classes of the shipped component layer. */
export function componentMinimums() {
  return tokenSizedClasses(readFileSync(join(uiRoot, 'src', 'styles', '_components.scss'), 'utf8'));
}

/** Whether a declared screen can only be opened at `<route>/<id>`. */
export function needsId(screen) {
  return screen.parentScope !== '' || screen.archetype === VIEWER_ARCHETYPE;
}

/** The key's route: the declared route, `/` for Home, and `/:id` where the screen takes an id. */
export function keyRoute(screen) {
  if (screen.route === '') return '/';
  return needsId(screen) ? `${screen.route}/:id` : screen.route;
}

/** The roster the walk is over: every declared screen, split into built and not built. */
export function declaredScreens() {
  const built = builtScreens();
  const notBuilt = SCREENS.filter((screen) => !screen.built);
  return { declared: SCREENS.length, built, notBuilt };
}

/** One entry's key. */
export function entryKey(entry) {
  return `${entry.route}|${entry.invariant}|${entry.context}|${entry.element}`;
}

/**
 * Collapse equal keys into one entry each, summing `count` and keeping the first `measured`.
 * The order is the key's own, so a written baseline is stable run to run.
 */
export function collapse(entries) {
  const byKey = new Map();
  for (const entry of entries) {
    const key = entry.key ?? entryKey(entry);
    const held = byKey.get(key);
    if (held === undefined) {
      byKey.set(key, {
        key,
        route: entry.route,
        invariant: entry.invariant,
        context: entry.context,
        element: entry.element,
        count: entry.count ?? 1,
        measured: entry.measured ?? '',
        tag: entry.tag ?? null,
        dw: entry.dw ?? null,
      });
    } else {
      held.count += entry.count ?? 1;
    }
  }
  return [...byKey.values()].sort((a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
}

/**
 * What the walk found against the baseline, by key alone: `fresh` is every found entry whose key
 * the baseline does not hold (collapsed), `stale` every baseline entry whose key was not found.
 * `dw`, `tag`, `count` and `measured` play no part.
 */
export function compare(found, baseline) {
  const baselineKeys = new Set(baseline.map((entry) => entry.key ?? entryKey(entry)));
  const foundEntries = collapse(found);
  const foundKeys = new Set(foundEntries.map((entry) => entry.key));
  return {
    fresh: foundEntries.filter((entry) => !baselineKeys.has(entry.key)),
    stale: baseline.filter((entry) => !foundKeys.has(entry.key ?? entryKey(entry))),
  };
}

/** The baseline file as committed, or `null` when there is none. */
export function readBaseline(path = BASELINE_PATH) {
  if (!existsSync(path)) return null;
  return JSON.parse(readFileSync(path, 'utf8'));
}

/** How a stale entry is reported: by key, with what to do about it. */
export function staleInstruction(entry) {
  return `stale baseline entry ${entry.key ?? entryKey(entry)} -- the walk no longer finds it; remove this entry from ui/browser/structural-baseline.json`;
}

// --- In the page ------------------------------------------------------------------------------

/**
 * Runs inside the page: marks every visible form field for the name check, and measures the
 * min-width, overflow and contrast invariants that `options.checks` asks for. Self-contained,
 * because it is serialized into the page.
 */
function detectInPage(options) {
  const results = { violations: [], fields: [], unmeasurable: 0 };
  const styleCache = new Map();
  const style = (el) => {
    let held = styleCache.get(el);
    if (held === undefined) {
      held = getComputedStyle(el);
      styleCache.set(el, held);
    }
    return held;
  };

  const appAncestor = (el) => {
    let node = el.parentElement;
    while (node !== null) {
      if (node.tagName.toLowerCase().startsWith('app-')) return node.tagName.toLowerCase();
      node = node.parentElement;
    }
    return 'root';
  };
  const describe = (el) => {
    const classes = [...el.classList].filter((name) => name.startsWith('ocu-')).sort();
    const role = el.getAttribute('role');
    const roleText = role === null ? '' : `[role=${role}]`;
    return `${appAncestor(el)}>${el.tagName.toLowerCase()}${classes.map((name) => '.' + name).join('')}${roleText}`;
  };

  const visible = (el) => {
    const rect = el.getBoundingClientRect();
    if (rect.width <= 1 || rect.height <= 1) return false;
    if (rect.right <= 0 || rect.bottom <= 0) return false;
    let node = el;
    while (node !== null) {
      const cs = style(node);
      if (cs.display === 'none' || cs.visibility === 'hidden' || cs.visibility === 'collapse') return false;
      if (Number(cs.opacity) === 0) return false;
      if (cs.clipPath !== 'none' && cs.clipPath.startsWith('inset(50%')) return false;
      node = node.parentElement;
    }
    return true;
  };

  const all = [...document.body.querySelectorAll('*')].filter((el) => el instanceof HTMLElement || el instanceof SVGSVGElement);
  const shown = all.filter(visible);

  // name: mark the fields; the accessible name is read from Chrome's own tree afterwards.
  if (options.checks.includes('name')) {
    const fields = shown.filter((el) => el.matches('input:not([type=hidden]), select, textarea'));
    fields.forEach((el, index) => {
      el.setAttribute('data-ocu-walk-field', String(index));
      results.fields.push({ index, element: describe(el) });
    });
  }

  // min-width
  if (options.checks.includes('min-width')) {
    const controls = shown.filter((el) =>
      el.matches(
        'button, a[href], input:not([type=hidden]), select, textarea, [role=button], [role=link], [role=menuitem], [role=menuitemcheckbox], [role=tab], [role=checkbox], [role=switch], [tabindex]:not([tabindex="-1"])'
      )
    );
    const rootStyle = getComputedStyle(document.documentElement);
    const tokenPx = (token) => parseFloat(rootStyle.getPropertyValue(`--ocu-${token}`));
    for (const el of controls) {
      let minimum = options.floorPx;
      let source = 'floor';
      for (const entry of options.classMinimums) {
        if (el.classList.contains(entry.className)) {
          minimum = entry.px;
          source = entry.className;
        }
      }
      for (const entry of options.tokenMinimums) {
        if (el.classList.contains(entry.className)) {
          minimum = tokenPx(entry.token);
          source = `--ocu-${entry.token}`;
        }
      }
      const width = el.getBoundingClientRect().width;
      if (width + 0.5 < minimum) {
        results.violations.push({
          invariant: 'min-width',
          element: describe(el),
          measured: `width ${Math.round(width * 10) / 10}px under ${minimum}px (${source})`,
        });
      }
    }
  }

  // overflow
  if (options.checks.includes('overflow')) {
    const root = document.documentElement;
    const viewportWidth = root.clientWidth;
    if (root.scrollWidth > viewportWidth) {
      for (const el of shown) {
        const rect = el.getBoundingClientRect();
        if (rect.right <= viewportWidth + 1) continue;
        const parent = el.parentElement;
        const parentRight = parent === null || parent === document.body ? 0 : parent.getBoundingClientRect().right;
        if (parent !== null && parent !== document.body && parentRight > viewportWidth + 1) continue;
        results.violations.push({
          invariant: 'overflow',
          element: `page>${describe(el)}`,
          measured: `the document scrolls horizontally; right edge ${Math.round(rect.right - viewportWidth)}px past the ${viewportWidth}px viewport`,
        });
      }
    }
    const containingBlock = (el) => {
      const cs = style(el);
      let node = el.parentElement;
      if (cs.position === 'absolute') {
        while (node !== null && node !== root) {
          const ns = style(node);
          if (ns.position !== 'static' || ns.transform !== 'none') return node;
          node = node.parentElement;
        }
        return root;
      }
      while (node !== null && (style(node).display === 'contents' || style(node).display === 'inline')) node = node.parentElement;
      return node;
    };
    for (const el of shown) {
      if (el === document.body) continue;
      const cs = style(el);
      if (cs.position === 'fixed') continue;
      const block = containingBlock(el);
      if (block === null || block === root) continue;
      let clipped = false;
      let node = el.parentElement;
      while (node !== null) {
        if (style(node).overflowX !== 'visible') {
          clipped = true;
          break;
        }
        if (node === block) break;
        node = node.parentElement;
      }
      if (clipped) continue;
      const blockRect = block.getBoundingClientRect();
      const bs = style(block);
      const left = blockRect.left + parseFloat(bs.borderLeftWidth);
      const right = blockRect.right - parseFloat(bs.borderRightWidth);
      const rect = el.getBoundingClientRect();
      const past = Math.max(rect.right - right, left - rect.left);
      const allowance = options.overflowAllowances.find((entry) => el.classList.contains(entry.className));
      if (allowance !== undefined && past <= allowance.px + 1) continue;
      if (past > 1) {
        results.violations.push({
          invariant: 'overflow',
          element: describe(el),
          measured: `${Math.round(past)}px past its containing block (${describe(block)})`,
        });
      }
    }
  }

  // contrast
  if (options.checks.includes('contrast')) {
    const parse = (text) => {
      const numbers = (body) => body.split(/[\s,]+/).filter((part) => part !== '' && part !== '/').map(Number);
      if (text.startsWith('rgb')) {
        const p = numbers(text.slice(text.indexOf('(') + 1, text.lastIndexOf(')')));
        return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
      }
      if (text.startsWith('color(srgb')) {
        const p = numbers(text.slice('color(srgb'.length, text.lastIndexOf(')')));
        return { r: p[0] * 255, g: p[1] * 255, b: p[2] * 255, a: p.length > 3 ? p[3] : 1 };
      }
      return null;
    };
    const over = (top, bottom) => ({
      r: top.r * top.a + bottom.r * (1 - top.a),
      g: top.g * top.a + bottom.g * (1 - top.a),
      b: top.b * top.a + bottom.b * (1 - top.a),
      a: 1,
    });
    const luminance = (c) => {
      const lin = (v) => {
        const s = v / 255;
        return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
      };
      return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    };
    const hex = (c) =>
      '#' + [c.r, c.g, c.b].map((v) => Math.round(v).toString(16).padStart(2, '0')).join('');
    // What shows through where no element paints an opaque background: the canvas, in the used
    // color scheme -- read from the browser rather than assumed.
    const probe = document.createElement('div');
    probe.style.background = 'Canvas';
    document.body.appendChild(probe);
    const canvas = parse(getComputedStyle(probe).backgroundColor);
    probe.remove();
    const backgroundOf = (el) => {
      const layers = [];
      let node = el;
      while (node !== null) {
        const cs = style(node);
        if (cs.backgroundImage !== 'none') return null;
        const color = parse(cs.backgroundColor);
        if (color !== null && color.a > 0) {
          layers.push(color);
          if (color.a >= 1) break;
        }
        node = node.parentElement;
      }
      if (layers.length === 0 || layers[layers.length - 1].a < 1) {
        if (canvas === null) return null;
        layers.push(canvas);
      }
      let composed = layers[layers.length - 1];
      for (let i = layers.length - 2; i >= 0; i -= 1) composed = over(layers[i], composed);
      return composed;
    };
    const holdsText = (el) =>
      [...el.childNodes].some((node) => node.nodeType === Node.TEXT_NODE && node.textContent.trim() !== '');
    for (const el of shown) {
      if (!holdsText(el)) continue;
      if (el.closest('[aria-disabled="true"], :disabled') !== null) continue;
      const cs = style(el);
      const fg = parse(cs.color);
      const bg = backgroundOf(el);
      if (fg === null || bg === null) {
        results.unmeasurable += 1;
        continue;
      }
      let alpha = fg.a;
      let node = el;
      while (node !== null) {
        alpha *= Number(style(node).opacity);
        node = node.parentElement;
      }
      const text = over({ ...fg, a: alpha }, bg);
      const la = luminance(text);
      const lb = luminance(bg);
      const ratio = (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
      const size = parseFloat(cs.fontSize);
      const weight = Number(cs.fontWeight);
      const large = size >= 24 || (size >= 18.66 && weight >= 600);
      const floor = large ? 3 : 4.5;
      if (ratio + 0.005 < floor) {
        results.violations.push({
          invariant: 'contrast',
          element: describe(el),
          measured: `${Math.round(ratio * 100) / 100}:1 under ${floor}:1 (${hex(text)} on ${hex(bg)})`,
        });
      }
    }
  }
  return results;
}

/** The accessible names Chrome computes for the fields `detectInPage` marked, by mark index. */
async function fieldNames(page) {
  const client = await page.createCDPSession();
  try {
    const { root } = await client.send('DOM.getDocument', { depth: -1 });
    const { nodeIds } = await client.send('DOM.querySelectorAll', { nodeId: root.nodeId, selector: '[data-ocu-walk-field]' });
    const names = new Map();
    for (const nodeId of nodeIds) {
      const { attributes } = await client.send('DOM.getAttributes', { nodeId });
      const at = attributes.indexOf('data-ocu-walk-field');
      const index = Number(attributes[at + 1]);
      const { nodes } = await client.send('Accessibility.getPartialAXTree', { nodeId, fetchRelatives: false });
      const node = nodes.find((candidate) => !candidate.ignored) ?? null;
      names.set(index, node === null ? null : String(node.name?.value ?? '').trim());
    }
    return names;
  } finally {
    await client.detach();
    await page.evaluate(() => {
      for (const el of document.querySelectorAll('[data-ocu-walk-field]')) el.removeAttribute('data-ocu-walk-field');
    });
  }
}

/**
 * Every violation the invariants in `checks` find on the screen the page is standing on, as
 * entries keyed under `route` and `context`. `unmeasurable` counts the text elements whose
 * background the contrast check could not resolve (a gradient or image under them).
 */
export async function detectScreen(page, { route, checks, viewport, theme, minimums }) {
  const found = await page.evaluate(detectInPage, {
    checks,
    floorPx: MIN_WIDTH_SOURCES.floor.px,
    classMinimums: MIN_WIDTH_SOURCES.classes.map(({ className, px }) => ({ className, px })),
    tokenMinimums: minimums,
    overflowAllowances: OVERFLOW_ALLOWANCES.map(({ className, px }) => ({ className, px })),
  });
  const entries = [];
  const contextFor = (invariant) => (invariant === 'contrast' ? theme : invariant === 'name' ? '' : String(viewport));
  for (const violation of found.violations) {
    entries.push({ route, invariant: violation.invariant, context: contextFor(violation.invariant), element: violation.element, measured: violation.measured });
  }
  if (checks.includes('name') && found.fields.length > 0) {
    const names = await fieldNames(page);
    for (const field of found.fields) {
      // A field Chrome leaves out of the accessibility tree, or one it answers nothing for, has no
      // name a reader can reach: a failed lookup is reported, never read as a pass.
      const name = names.get(field.index);
      const measured =
        name === '' ? 'no accessible name' : name === null ? 'left out of the accessibility tree' : name === undefined ? 'no accessibility node found' : null;
      if (measured !== null) entries.push({ route, invariant: 'name', context: '', element: field.element, measured });
    }
  }
  for (const entry of entries) entry.key = entryKey(entry);
  return { entries, unmeasurable: found.unmeasurable };
}

// --- Driving the shell ------------------------------------------------------------------------

/** Count `/api/ocupilot` requests in flight on `page`, and when the count last moved. */
function trackRequests(page) {
  const state = { inflight: new Set(), last: Date.now() };
  page.on('request', (request) => {
    if (!request.url().includes('/api/ocupilot')) return;
    state.inflight.add(request);
    state.last = Date.now();
  });
  const done = (request) => {
    if (state.inflight.delete(request)) state.last = Date.now();
  };
  page.on('requestfinished', done);
  page.on('requestfailed', done);
  return state;
}

/**
 * Wait until the screen is settled: no `/api/ocupilot` request in flight for `QUIET_MS`, no
 * `[aria-busy="true"]` left, and the fonts loaded. Answers false when it never settles.
 */
async function settle(page, requests) {
  const started = Date.now();
  while (Date.now() - started < SETTLE_TIMEOUT_MS) {
    if (requests.inflight.size === 0 && Date.now() - requests.last >= QUIET_MS) {
      const ready = await page.evaluate(async () => {
        await document.fonts.ready;
        return document.querySelector('[aria-busy="true"]') === null;
      });
      if (ready && requests.inflight.size === 0 && Date.now() - requests.last >= QUIET_MS) return true;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  return false;
}

/**
 * Move the running shell to `path` with the router's own navigation: a history entry and the
 * popstate the router listens for, never a second document -- which would bring the first-login
 * gate back (`shell-entry.mjs`).
 */
async function goInApp(page, requests, path, timeoutMs) {
  const pathname = path.split('?')[0];
  requests.last = Date.now();
  await page.evaluate((to) => {
    window.history.pushState({}, '', to);
    window.dispatchEvent(new PopStateEvent('popstate'));
  }, path);
  await page.waitForFunction((wanted) => window.location.pathname === wanted, { timeout: timeoutMs }, pathname);
  return settle(page, requests);
}

/** The id segment of the first rendered row link on the list the page stands on under `route`. */
async function firstRowSegment(page, route) {
  return page.evaluate((prefix) => {
    for (const link of document.querySelectorAll('a.ocu-data-table-link[href]')) {
      const path = new URL(link.href).pathname;
      if (!path.startsWith(prefix)) continue;
      const segments = path.split('/').filter((part) => part !== '');
      return segments[segments.length - 1];
    }
    return null;
  }, `/ocupilot/${route}/`);
}

/** Flip the theme through the account menu's own item, and close the menu. */
export async function toggleThemeThroughMenu(page, requests, timeoutMs) {
  const wasDark = await page.evaluate((name) => document.documentElement.classList.contains(name), THEME_DARK_CLASS);
  await page.click('#ocu-account-trigger');
  await page.waitForSelector(THEME_ITEM, { visible: true, timeout: timeoutMs });
  await page.click(THEME_ITEM);
  await page.waitForFunction(
    (name, dark) => document.documentElement.classList.contains(name) === dark,
    { timeout: timeoutMs },
    THEME_DARK_CLASS,
    !wasDark
  );
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => document.querySelector('.ocu-account-panel') === null, { timeout: timeoutMs });
  await settle(page, requests);
}

/** The URL a screen is opened at, or `null` when its id could not be resolved. */
function urlFor(screen, segments) {
  if (screen.route === '') return `/ocupilot/${NAMESPACE_QUERY}`;
  if (!needsId(screen)) return `/ocupilot/${screen.route}${NAMESPACE_QUERY}`;
  const segment = screen.archetype === VIEWER_ARCHETYPE ? encodeEntityId(VIEWER_ID) : segments.get(screen.parentScope) ?? null;
  if (segment === null) return null;
  return `/ocupilot/${screen.route}/${segment}${NAMESPACE_QUERY}`;
}

/**
 * One pass over every built screen at one viewport in one theme: base routes first, in registry
 * order, recording each list's first row link so the id-requiring screens can be opened after.
 */
async function walkPass(page, requests, config, { viewport, theme, checks, minimums, report }) {
  const entries = [];
  const segments = new Map();
  const { built } = declaredScreens();
  const ordered = [...built.filter((screen) => !needsId(screen)), ...built.filter(needsId)];
  for (const screen of ordered) {
    if (needsId(screen) && Object.hasOwn(SKIP, screen.route)) {
      report.skipped.add(screen.route);
      continue;
    }
    const url = urlFor(screen, segments);
    if (url === null) {
      report.unresolved.add(screen.route);
      continue;
    }
    const settled = await goInApp(page, requests, url, config.navigationTimeoutMs);
    if (!settled) report.unsettled.add(`${screen.route} (${viewport} ${theme})`);
    if (!needsId(screen)) {
      const segment = await firstRowSegment(page, screen.route);
      if (segment !== null) segments.set(screen.route, segment);
    }
    const found = await detectScreen(page, { route: keyRoute(screen), checks, viewport, theme, minimums });
    entries.push(...found.entries);
    if (checks.includes('contrast')) report.unmeasurable += found.unmeasurable;
    report.walked.add(screen.route);
  }
  return entries;
}

/**
 * The whole walk: 1280 px in light (every invariant), then 1280 px in dark (contrast) after the
 * account menu's own toggle, switched back at the end; then 720 px in light (every structural
 * invariant). Answers `{entries, report}`; `report` counts walked, skipped, not built,
 * unresolved (an id-requiring screen neither walked nor skipped), unsettled and unmeasurable.
 */
export async function walk(browser, config) {
  const minimums = componentMinimums();
  const report = {
    declared: declaredScreens().declared,
    notBuilt: declaredScreens().notBuilt.map((screen) => screen.route),
    walked: new Set(),
    skipped: new Set(),
    unresolved: new Set(),
    unsettled: new Set(),
    unmeasurable: 0,
  };
  const entries = [];
  const reducedMotion = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

  const wide = await signedInAt(browser, config, '/ocupilot/', VIEWPORTS.wide, reducedMotion);
  try {
    const requests = trackRequests(wide.page);
    entries.push(...(await walkPass(wide.page, requests, config, { viewport: VIEWPORTS.wide.width, theme: 'light', checks: INVARIANTS, minimums, report })));
    await toggleThemeThroughMenu(wide.page, requests, config.navigationTimeoutMs);
    entries.push(...(await walkPass(wide.page, requests, config, { viewport: VIEWPORTS.wide.width, theme: 'dark', checks: ['contrast'], minimums, report })));
    await goInApp(wide.page, requests, `/ocupilot/${NAMESPACE_QUERY}`, config.navigationTimeoutMs);
    await toggleThemeThroughMenu(wide.page, requests, config.navigationTimeoutMs);
  } finally {
    await wide.context.close();
  }

  const narrow = await signedInAt(browser, config, '/ocupilot/', VIEWPORTS.narrow, reducedMotion);
  try {
    const requests = trackRequests(narrow.page);
    entries.push(...(await walkPass(narrow.page, requests, config, { viewport: VIEWPORTS.narrow.width, theme: 'light', checks: ['name', 'min-width', 'overflow'], minimums, report })));
  } finally {
    await narrow.context.close();
  }
  return { entries: collapse(entries), report };
}

/** The walk's own report, as the lines the spec and `--write` print. */
export function reportLines(report) {
  return [
    `structural walk: ${report.declared} declared screen(s); ${report.walked.size} walked, ${report.skipped.size} skipped, ${report.notBuilt.length} not built (${report.notBuilt.join(', ')})`,
    `structural walk: ${report.unresolved.size} id-requiring screen(s) neither walked nor skipped${report.unresolved.size === 0 ? '' : ': ' + [...report.unresolved].join(', ')}`,
    `structural walk: ${report.unmeasurable} text element(s) unmeasurable for contrast (a gradient or image behind them)`,
    `structural walk: ${report.unsettled.size} screen visit(s) did not settle within ${SETTLE_TIMEOUT_MS}ms${report.unsettled.size === 0 ? '' : ': ' + [...report.unsettled].join(', ')}`,
    ...Object.entries(SKIP).map(([route, reason]) => `structural walk: skipped ${route} -- ${reason}`),
  ];
}

/** Refuse anything but an installed throwaway. */
export async function assertThrowaway(config) {
  assert.notEqual(config.container, LIVE_CONTAINER, 'the walk signs in and writes the account preferences, so it never runs against the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
}

/**
 * `--write`: walk once and write the baseline. Refuses when a baseline already exists: it is taken
 * once, and a regenerate would absorb every regression since the take and drop every `dw` filed.
 */
async function writeBaseline() {
  if (readBaseline() !== null) {
    console.error(`structural walk: ${BASELINE_PATH} exists; the baseline is taken once and never regenerated -- append the gate's printed entries instead`);
    process.exit(2);
  }
  const config = browserConfig();
  await assertThrowaway(config);
  const { default: puppeteer } = await import('puppeteer');
  const browser = await puppeteer.launch(launchOptions(config));
  try {
    const { entries, report } = await walk(browser, config);
    for (const line of reportLines(report)) console.log(line);
    const baseline = {
      generated: new Date().toISOString(),
      viewports: VIEWPORTS,
      entries,
      ownerReported: [],
    };
    writeFileSync(BASELINE_PATH, JSON.stringify(baseline, null, 2) + '\n');
    console.log(`structural walk: wrote ${entries.length} entr(ies) to ${BASELINE_PATH}`);
  } finally {
    await browser.close();
  }
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (!process.argv.includes('--write')) {
    console.error('usage: node browser/structural-walk.mjs --write');
    process.exit(2);
  }
  await writeBaseline();
}

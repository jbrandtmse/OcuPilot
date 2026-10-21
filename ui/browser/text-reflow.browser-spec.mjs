/**
 * Text-only resizing in a real browser, against the throwaway instance (Story 23.11, DW-2439).
 *
 * DESIGN.md `:912`: every height is a minimum, so a control grows with its text rather than clipping
 * it. jsdom computes no layout, so this is the one tier that can say so. At 1,440 x 900 each leg signs
 * in, doubles the size and line height of all six type roles (`scaleTypeTokens`), opens the states
 * below, and asserts for every element matching each selector of `CHANGED` that
 * `scrollHeight <= clientHeight + 1`; for a text input, which reports the two equal whatever its text
 * needs, that its one line and padding fit its box. A menu's items are measured while it is open and
 * nothing else is, because the popup hangs below its host. It runs in the light theme and in the dark one.
 *
 * The other half of `:912` is that the virtualized rows stay fixed, because a list scrolls by one row's height: a
 * second test measures the data-table row and the log-viewer row at normal type and again at doubled type, in both
 * themes, and asserts their height has not moved.
 *
 * - **Shell:** header, account and namespace menus, command box and its options, locator bar, side
 *   bar, status bar and the skip link, from every screen below.
 * - **Home:** the remembered rows.
 * - **A list page with criteria** (Audit): the criteria form, filter, max rows and the sort menu.
 * - **A list page with row actions** (Task schedule): the row menu, and the typed-name confirm it
 *   opens, closed with Cancel.
 * - **A form page** (a new user): the inputs, the reveal toggle and the form bar.
 *
 * **A selector no opened screen draws without a write is measured on an element carrying its class,
 * inserted into its real parent** (`FIXTURES`): the status bar's server flag (the throwaway reports no
 * system mode), the agent picker's button (it draws only with two enabled definitions), a finding's
 * Fix it (it draws only while a fixable finding stands), and the classic-portal link card, which no
 * template mounts today, so it is inserted into the screen outlet. A selector it finds no element
 * for fails the leg.
 *
 * It draws and measures: the only writes to the instance are the shared sign-in's reset of the
 * account's remembered screen state (`signedInAt`), and the typed-name confirm is cancelled before
 * anything is typed. It refuses the live container, as every spec here does.
 *
 * Run: `npm run build`, then redeploy the bundle into the throwaway
 * (`docker cp dist/ocupilot-ui/browser/. <container>:/durable/iris/csp/ocupilot/`), then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/text-reflow.browser-spec.mjs`
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { scaleTypeTokens, setDarkTheme, signedInAt } from './panel-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();

/** Every selector whose rule in `_components.scss` holds a minimum height in place of a fixed one. */
const CHANGED = [
  '.ocu-field-input',
  '.ocu-reveal-toggle',
  '.ocu-button-primary',
  '.ocu-button-secondary',
  '.ocu-button-text',
  '.ocu-button-destructive',
  '.ocu-account-trigger',
  '.ocu-account-item',
  '.ocu-skip-link',
  '.ocu-side-bar-item',
  '.ocu-header',
  '.ocu-namespace-switch-option',
  '.ocu-command-box-field',
  '.ocu-command-box-option',
  '.ocu-locator-bar',
  '.ocu-command-bar-filter',
  '.ocu-command-bar-sort-item',
  '.ocu-command-bar-refresh',
  '.ocu-status-bar',
  '.ocu-server-flag',
  '.ocu-classic-link-card-action',
  '.ocu-data-table-menu-item',
  '.ocu-data-table-max-rows',
  '.ocu-criteria-input',
  '.ocu-criteria-select',
  '.ocu-form-bar',
  '.ocu-home-block-open',
  '.ocu-typed-name-field',
  '.ocu-home-finding-fix',
  '.ocu-agent-picker-button',
];

/** The six text roles' size and line-height tokens: every role the 28 rules draw their text in. */
const TYPE_TOKENS = ['display', 'title', 'body', 'caption', 'label', 'code'].flatMap((role) => [
  `--ocu-type-${role}-size`,
  `--ocu-type-${role}-line-height`,
]);

/**
 * The selectors no opened screen draws without a write, each as the markup its component's template
 * writes, inserted into `host`, the element that component sits in. Inserted only while no element
 * matches the selector.
 */
const FIXTURES = [
  {
    selector: '.ocu-server-flag',
    host: 'app-status-bar app-server-flag',
    html: `<span class="ocu-server-flag" data-flag="live">${STRINGS.serverFlagLive}</span>`,
  },
  {
    selector: '.ocu-agent-picker-button',
    host: 'app-agent-picker',
    html:
      '<span class="ocu-agent-picker"><button type="button" class="ocu-agent-picker-button" aria-haspopup="menu">' +
      '<span class="ocu-agent-picker-text">Agent definition</span><span class="ocu-agent-picker-caret" aria-hidden="true">\u25BE</span>' +
      '</button></span>',
  },
  {
    selector: '.ocu-home-finding-fix',
    host: '.ocu-home-findings-groups',
    html:
      '<section class="ocu-home-findings-group"><ul class="ocu-home-findings-list"><li class="ocu-home-finding">' +
      '<p class="ocu-home-finding-sentence">A finding.</p>' +
      `<button type="button" class="ocu-home-finding-fix">${STRINGS.findingsFix}</button>` +
      '</li></ul></section>',
  },
  {
    selector: '.ocu-classic-link-card-action',
    host: 'app-screen-outlet',
    html:
      '<section class="ocu-classic-link-card"><p class="ocu-classic-link-card-title">' +
      `${STRINGS.classicLinkCardTitle}</p><p class="ocu-classic-link-card-caption">${STRINGS.classicLinkCardCaption}</p>` +
      '<a class="ocu-button-secondary ocu-classic-link-card-action" href="#" target="_blank" rel="noreferrer">' +
      '<span class="ocu-classic-link-card-label">The classic page</span><span class="ocu-external-glyph" aria-hidden="true">\u2197</span></a></section>',
  },
];

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives a browser session, so it never runs against the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser === null) return;
  await browser.close();
  browser = null;
});

/** Click the first element matching `selector`, through the DOM so a doubled layout cannot cover it. */
function press(page, selector) {
  return page.evaluate((wanted) => document.querySelector(wanted).click(), selector);
}

/** Wait for `selector` to be drawn (`present`) or gone. */
function waitFor(page, selector, present = true) {
  return page.waitForSelector(selector, { hidden: !present, timeout: config.navigationTimeoutMs });
}

/** Open a menu with `trigger`, and return the way it closes. */
async function openMenu(page, trigger, item) {
  await press(page, trigger);
  await waitFor(page, item);
  return async () => {
    await page.keyboard.press('Escape');
    await waitFor(page, item, false);
  };
}

/** The command box's options, opened by typing a word the box matches. */
async function openCommandBox(page) {
  await page.focus('.ocu-command-box-field');
  await page.keyboard.type('user');
  await waitFor(page, '.ocu-command-box-option');
  return async () => {
    await page.keyboard.press('Escape');
    await waitFor(page, '.ocu-command-box-option', false);
  };
}

/**
 * The shell's own menus, opened over whatever screen the leg stands on. A menu's items are measured while it is open,
 * and nothing else: the popup hangs below its host, so the host's `scrollHeight` counts a popup that is meant to
 * overflow it.
 */
const SHELL_MENUS = [
  { name: 'account menu', selectors: ['.ocu-account-item'], open: (page) => openMenu(page, '.ocu-account-trigger', '.ocu-account-item') },
  {
    name: 'namespace switch',
    selectors: ['.ocu-namespace-switch-option'],
    open: (page) => openMenu(page, '.ocu-namespace-switch-trigger', '.ocu-namespace-switch-option'),
  },
  { name: 'command box', selectors: ['.ocu-command-box-option'], open: openCommandBox },
];

/**
 * The screens, each with the signal (or signals) that its reads have answered and the states opened on it. A state
 * `open`s and answers the function that closes it, so the next one starts from the screen itself.
 */
const SURFACES = [
  {
    name: 'Home',
    url: '/ocupilot/?ns=HSCUSTOM',
    answered: ['.ocu-home-block-open', '.ocu-home-system-row', '.ocu-home-findings'],
    states: [],
  },
  {
    name: 'list page with criteria (Audit)',
    url: '/ocupilot/logs/audit?ns=HSCUSTOM',
    answered: '.ocu-criteria-input',
    states: [
      {
        name: 'sort menu',
        selectors: ['.ocu-command-bar-sort-item'],
        open: (page) => openMenu(page, '.ocu-command-bar-sort-trigger', '.ocu-command-bar-sort-item'),
      },
      ...SHELL_MENUS,
    ],
  },
  {
    name: 'list page with row actions (Task schedule)',
    url: '/ocupilot/tasks/schedule?ns=HSCUSTOM',
    answered: '.ocu-data-table-trigger',
    states: [
      {
        name: 'row menu',
        selectors: ['.ocu-data-table-menu-item'],
        open: (page) => openMenu(page, '.ocu-data-table-trigger', '.ocu-data-table-menu-item'),
      },
      {
        name: 'typed-name confirm',
        selectors: ['.ocu-typed-name-field', '.ocu-button-destructive'],
        open: async (page) => {
          await press(page, '.ocu-data-table-trigger');
          await waitFor(page, '.ocu-data-table-menu-item');
          await page.evaluate((verb) => {
            const item = Array.from(document.querySelectorAll('.ocu-data-table-menu-item')).find((candidate) => candidate.getAttribute('aria-label') === verb);
            item.click();
          }, STRINGS.actionDelete);
          await page.waitForSelector('.ocu-typed-name-field', { visible: true, timeout: config.navigationTimeoutMs });
          return async () => {
            await page.evaluate((verb) => {
              const cancel = Array.from(document.querySelectorAll('.ocu-dialog-actions button')).find((candidate) => candidate.textContent.trim() === verb);
              cancel.click();
            }, STRINGS.actionCancel);
            await waitFor(page, '.ocu-typed-name-field', false);
          };
        },
      },
    ],
  },
  {
    name: 'form page (new user)',
    url: '/ocupilot/permissions/users/edit?ns=HSCUSTOM',
    answered: '.ocu-reveal-toggle',
    states: [],
  },
];

/**
 * Every element each of `selectors` matches now, as how tall its box is and how tall the content it must hold is.
 *
 * For a block that is its `clientHeight` and `scrollHeight`. A text input reports the two equal whatever its text
 * needs, so an input's content is its one line: the computed line height, with the box's vertical padding and
 * border.
 */
function measure(page, selectors = CHANGED) {
  return page.evaluate(
    (wanted) =>
      wanted.map((selector) => ({
        selector,
        elements: Array.from(document.querySelectorAll(selector))
          .map((element) => {
            const style = getComputedStyle(element);
            const edges = ['padding-top', 'padding-bottom', 'border-top-width', 'border-bottom-width'].reduce(
              (sum, property) => sum + parseFloat(style.getPropertyValue(property)),
              0
            );
            const line = parseFloat(style.lineHeight);
            const input = element instanceof HTMLInputElement;
            return {
              boxHeight: input ? element.offsetHeight : element.clientHeight,
              contentHeight: input ? (Number.isNaN(line) ? 1.2 * parseFloat(style.fontSize) : line) + edges : element.scrollHeight,
              text: ((input ? element.value : element.textContent) ?? '').trim().slice(0, 40),
            };
          })
          // A box with no height is not on screen, so it measures nothing.
          .filter((entry) => entry.boxHeight > 0),
      })),
    selectors
  );
}

/** Insert each fixture whose selector no element matches yet; one whose host is absent stays unmeasured. */
function insertFixtures(page) {
  return page.evaluate((fixtures) => {
    for (const fixture of fixtures) {
      if (document.querySelector(fixture.selector) !== null) continue;
      document.querySelector(fixture.host)?.insertAdjacentHTML('beforeend', fixture.html);
    }
  }, FIXTURES);
}

/**
 * The theme the page is drawn in right now, read from the colour behind everything rather than from the class that
 * asks for it: `dark` when that colour's luminance is under half. A leg that claims a theme asserts this, so a dark
 * leg that drew the light theme fails instead of repeating the light one.
 */
function drawnTheme(page) {
  return page.evaluate(() => {
    const [red, green, blue] = getComputedStyle(document.body).backgroundColor.match(/\d+(\.\d+)?/g).map(Number);
    return (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255 < 0.5 ? 'dark' : 'light';
  });
}

/**
 * The rows `:912` leaves fixed, each with a screen that draws them. A virtualized list scrolls by one row's height, so
 * a row that grew with its text would break the arithmetic; the log row also keeps a scan down its severity column.
 */
const FIXED_ROWS = [
  { name: 'data-table row (Task schedule)', url: '/ocupilot/tasks/schedule?ns=HSCUSTOM', rows: '.ocu-data-table-body .ocu-data-table-row' },
  { name: 'log-viewer row (messages.log)', url: '/ocupilot/logs/messages?ns=HSCUSTOM', rows: '.ocu-log-rows .ocu-log-row' },
];

/** How many of `selector`'s elements are drawn, the distinct heights they have, and the line height the first one's text takes. */
function rowsOf(page, selector) {
  return page.evaluate((wanted) => {
    const rows = Array.from(document.querySelectorAll(wanted));
    return {
      count: rows.length,
      heights: [...new Set(rows.map((row) => row.getBoundingClientRect().height))],
      lineHeight: rows.length === 0 ? 0 : parseFloat(getComputedStyle(rows[0]).lineHeight),
    };
  }, selector);
}

for (const theme of ['light', 'dark']) {
  test(`at doubled type the virtualized rows keep their fixed height (${theme})`, async () => {
    // Mutation (Rule 19): put `.ocu-data-table-row` or `.ocu-log-row` in `_components.scss` on `min-height:` in place
    // of `height:`, rebuild and redeploy -> the leg reads that row grown to the doubled line height.
    for (const fixed of FIXED_ROWS) {
      const { context, page } = await signedInAt(browser, config, fixed.url);
      try {
        await setDarkTheme(page, theme === 'dark');
        await waitFor(page, fixed.rows);
        const normal = await rowsOf(page, fixed.rows);
        assert.ok(normal.count > 0, `${fixed.name}: rows are drawn`);
        assert.equal(normal.heights.length, 1, `${fixed.name}: every row has one height at normal type: ${JSON.stringify(normal)}`);

        const scaled = await scaleTypeTokens(page, 2, TYPE_TOKENS);
        assert.deepEqual(scaled.unparsed, [], `every type token reads as a number: ${JSON.stringify(scaled)}`);
        assert.equal(await drawnTheme(page), theme, `${fixed.name} is drawn in the ${theme} theme when it is measured`);
        const doubled = await rowsOf(page, fixed.rows);
        assert.ok(doubled.count > 0, `${fixed.name}: rows are still drawn at doubled type`);
        // The stimulus bites: the text of a row now takes more height than the row has, so a minimum would have grown.
        assert.ok(doubled.lineHeight > normal.heights[0], `${fixed.name}: a doubled line (${doubled.lineHeight}px) is taller than the row (${normal.heights[0]}px)`);
        assert.deepEqual(doubled.heights, normal.heights, `${fixed.name}: the row keeps its height at doubled type (${theme})`);
      } finally {
        await context.close();
      }
    }
  });
}

for (const theme of ['light', 'dark']) {
  test(`at doubled type every control whose height was fixed grows and none clips (${theme})`, async () => {
    // Mutation (Rule 19): put any one of the 28 rules in `_components.scss` back to `height:`, rebuild and
    // redeploy -> the leg reads that selector among the clipped ones, in both themes. Draw the dark leg in the light
    // theme (`setDarkTheme(page, false)`) -> the dark leg fails on the theme it drew.
    const measured = new Map(CHANGED.map((selector) => [selector, 0]));
    const clipped = [];
    const take = (where, rows) => {
      for (const { selector, elements } of rows) {
        measured.set(selector, measured.get(selector) + elements.length);
        for (const element of elements) {
          if (element.contentHeight > element.boxHeight + 1) clipped.push({ selector, where, ...element });
        }
      }
    };

    for (const surface of SURFACES) {
      const { context, page } = await signedInAt(browser, config, surface.url);
      try {
        await setDarkTheme(page, theme === 'dark');
        // The screen's own reads have answered, so what is counted is what the instance drew.
        for (const signal of [surface.answered].flat()) await waitFor(page, signal);
        const scaled = await scaleTypeTokens(page, 2, TYPE_TOKENS);
        assert.deepEqual(scaled.unparsed, [], `every type token reads as a number: ${JSON.stringify(scaled)}`);
        assert.equal(await drawnTheme(page), theme, `${surface.name} is drawn in the ${theme} theme when it is measured`);

        take(surface.name, await measure(page));
        for (const state of surface.states) {
          const close = await state.open(page);
          assert.equal(await drawnTheme(page), theme, `${surface.name}, ${state.name} is drawn in the ${theme} theme when it is measured`);
          take(`${surface.name}, ${state.name}`, await measure(page, state.selectors));
          await close();
        }
        if (surface.name === 'Home') {
          await insertFixtures(page);
          take('Home, inserted into the real parent', await measure(page));
        }
      } finally {
        await context.close();
      }
    }

    const missing = [...measured].filter(([, count]) => count === 0).map(([selector]) => selector);
    assert.deepEqual(missing, [], `every changed selector is measured on at least one element (${theme}): ${JSON.stringify([...measured])}`);
    assert.deepEqual(
      clipped,
      [],
      `no element of a changed selector clips at doubled type (${theme}); each entry names its selector: ${JSON.stringify(clipped)}`
    );
  });
}

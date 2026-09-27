/**
 * Story 16.17 in a real browser, against the throwaway instance: a web application enabled by its
 * row action on the Web applications list comes back marked "Changed" with the instance's
 * read-back line after the tag -- "Read back: matches" -- and in the row's polite announcement
 * (AD-58). The instance compares; the page renders the verdict it was answered.
 *
 * With the line showing, the list passes the structural and contrast checks at 1280 light, 720
 * light and 1280 dark beyond the baseline (DW-1337), and the line reads the same in both themes.
 *
 * **It creates and deletes a web application**, so it refuses anything but an installed throwaway.
 * `before` makes the probe application disabled and `after` removes it whether or not a test
 * failed.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/read-back.browser-spec.mjs`.
 *
 * Mutation (Rule 19): drop `readBack` from `OcuPilot.Api.ScreenAction.Run`'s answer, recompile on
 * the throwaway -> the row never shows its line and this goes red.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const ROUTE = 'web-applications/list';
const LIST_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;

/** This spec's own application, never one the instance had. */
const PROBE = '/csp/ocupilotprobereadbackrow';

/** The name cell's own text element, read rather than the cell, which also holds the tag and line. */
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;

/** Run ObjectScript in `iris session` inside the throwaway, in %SYS, and read back the named markers. */
function irisSession(lines, names) {
  const input = `${[...lines, 'Halt'].join('\n')}\n`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const match = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = match === null ? null : match[1];
  }
  return { values, output };
}

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

function createProbe() {
  return irisSession(
    [
      `If ##class(Security.Applications).Exists("${PROBE}") Do ##class(Security.Applications).Delete("${PROBE}")`,
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Kill tProps Set tProps("NameSpace")=tNS,tProps("Enabled")=0,tProps("AutheEnabled")=32',
      `Set tProps("Description")="OcuPilot read-back browser spec probe (throwaway)"`,
      `Set tSC=##class(Security.Applications).Create("${PROBE}",.tProps)`,
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['MADE']
  );
}

function deleteProbe() {
  return irisSession(
    [
      `If ##class(Security.Applications).Exists("${PROBE}") Do ##class(Security.Applications).Delete("${PROBE}")`,
      mark('CLEAN', `('##class(Security.Applications).Exists("${PROBE}"))`),
    ],
    ['CLEAN']
  );
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/**
 * Two frames and every running CSS transition finished: a marked row's background fades over the
 * change-highlight duration, and a theme flip restarts that fade, so a colour measured mid-fade is
 * neither theme's.
 */
async function settled(page) {
  await frames(page);
  await page.evaluate(() =>
    Promise.all(
      document
        .getAnimations()
        .filter((animation) => animation instanceof CSSTransition)
        .map((animation) => animation.finished.catch(() => null))
    )
  );
  await frames(page);
}

/** Narrow the list to `name` and select that row, leaving the filter in place. */
async function selectOnly(page, name) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        const text = cell.querySelector(textSelector);
        return (text === null ? cell : text).textContent.trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
  await clickRowCentre(page, { text: name });
}

/** The probe row's Changed tag, its read-back line, and the table's polite announcement. */
function rowMark(page) {
  return page.evaluate(
    (selector, wanted, textSelector) => {
      const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
        const cell = candidate.querySelector('[role="gridcell"]');
        const text = cell.querySelector(textSelector);
        return (text === null ? cell : text).textContent.trim() === wanted;
      });
      if (row === undefined) return null;
      const line = row.querySelector('[role="gridcell"] .ocu-data-table-read-back');
      return {
        tag: row.querySelector('[role="gridcell"] .ocu-data-table-changed-tag')?.textContent.trim() ?? '',
        line: line?.textContent.trim() ?? '',
        lineShown: line !== null && line.getBoundingClientRect().width > 0,
        announcement: document.querySelector('.ocu-data-table-announcement')?.textContent.trim() ?? '',
      };
    },
    ROW_SELECTOR,
    PROBE,
    NAME_TEXT
  );
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes a web application, so it never runs inside the live container');
  await assertThrowaway(config);
  const { values, output } = createProbe();
  assert.equal(values.MADE, '1', `the probe application was created:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  const { values, output } = deleteProbe();
  assert.equal(values.CLEAN, '1', `the probe application is gone:\n${output}`);
});

test('AC5: a row action marks the row with the instance\u2019s read-back line, in both themes, within the structural baseline', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await selectOnly(page, PROBE);
    await page.click('.ocu-data-table-trigger');
    await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((label) => {
      const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
      items.find((item) => item.textContent.trim().startsWith(label)).click();
    }, STRINGS.agentDefinitionEnable);
    await page.waitForFunction(
      (selector, wanted, textSelector) => {
        const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
          const cell = candidate.querySelector('[role="gridcell"]');
          const text = cell.querySelector(textSelector);
          return (text === null ? cell : text).textContent.trim() === wanted;
        });
        return row !== undefined && row.querySelector('.ocu-data-table-read-back') !== null;
      },
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      PROBE,
      NAME_TEXT
    );

    const light = await rowMark(page);
    assert.equal(light?.tag, STRINGS.tableChangedTag, 'the enabled row is marked Changed');
    assert.equal(light?.line, STRINGS.readBackMatches, 'with the instance\u2019s read-back line after the tag');
    assert.ok(light?.lineShown, 'and the line is drawn, not collapsed');
    assert.ok(light?.announcement.endsWith(` \u00b7 ${STRINGS.readBackMatches}`), `the row's announcement says it too: ${light?.announcement}`);

    await page.evaluate(() => document.documentElement.classList.add('ocu-theme-dark'));
    await settled(page);
    const dark = await rowMark(page);
    assert.equal(dark?.line, STRINGS.readBackMatches, 'the line reads the same in the dark theme');
    assert.ok(dark?.lineShown, 'and is drawn there too');
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    await frames(page);

    const found = [];
    const passes = [
      { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
      { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
      { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
    ];
    const minimums = componentMinimums();
    const surfaces = {};
    for (const { viewport, theme, checks } of passes) {
      await page.setViewport(viewport);
      await page.evaluate((isDark) => document.documentElement.classList.toggle('ocu-theme-dark', isDark), theme === 'dark');
      await settled(page);
      surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
      assert.equal((await rowMark(page))?.line, STRINGS.readBackMatches, `the line is still showing at ${viewport.width}px ${theme}`);
      const { entries } = await detectScreen(page, { route: ROUTE, checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    }
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
    const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
    assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline for the marked list');
  } finally {
    await context.close();
  }
});

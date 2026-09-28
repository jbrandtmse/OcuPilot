/**
 * Story 16.2 in a real browser, against the throwaway instance: the Web sessions list and its End
 * session row action (AD-5, AD-53).
 *
 * What it pins: a session this spec seeds on `/api/atelier/` is listed with its user, its
 * application and "(none)" for its process, under the declared headers, and Web sessions is the
 * third entry of the Web applications side bar; End session opens the typed-name dialog titled
 * with the verb and the session id and stating the published consequence; a case twin of the id
 * sends nothing, the exact id sends one request, and the row leaves on the re-read that follows.
 * With the dialog open, the screen passes the structural and contrast checks at 1280 light, 720
 * light and 1280 dark, with no entry beyond the baseline (DW-1337). A real preserve-mode session,
 * opened through the page `OcuPilot.Test.PreservedSession` compiles under `/csp/hscustom/`, lists
 * with its process linked to Process details; its End session is offered, and while that process
 * runs the instance answers the confirmed click with the published sentence pointing to it.
 *
 * **It ends web sessions, terminates processes and compiles a page**, so it runs on a throwaway
 * only. It seeds each session itself as the configured account over HTTP, reads its id from the
 * admin API's `WebSession` `LIST` through `docker exec`, and its `after` hook ends every session it
 * seeded that is still listed, terminating a preserve-mode session's own process first, since that
 * process holds the session's lock, and then deletes the page.
 *
 * Run: `node --test --test-concurrency=1 browser/web-sessions.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { escapeOs, markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'web-applications/sessions';
const LIST_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const ACTION_PATH = '/api/ocupilot/screens/webapp.sessions/action';
const SEED_PATH = '/api/atelier/';
const PRESERVED_PATH = '/csp/hscustom/OcuPilot.Test.PreservedSessionPage.cls';

let browser = null;
const seeded = [];

/**
 * The session ids the admin API's `WebSession` `LIST` carries now, with each row's user, application,
 * `Preserve` and process.
 */
function listed() {
  const output = runIris(config.container, [
    'Kill q Set sc=##class(OcuPilot.Port.AdminPort).Invoke("WebSession","LIST",.q,"",.rows,.http,.fault)',
    'Set out="" If $System.Status.IsOK(sc) { Set it=rows.%GetIterator() While it.%GetNext(.i,.row) { Set out=out_$Select(out="":"",1:";")_row.ID_"|"_row.Username_"|"_row.Application_"|"_row.Preserve_"|"_row.SesProcessId } }',
    'Write "OCU-WSLIST-START:"_$Select($System.Status.IsOK(sc):"ok",1:"fail")_"#"_out_":OCU-WSLIST-END",!',
  ]);
  const value = markerValue(output, 'WSLIST');
  assert.ok(value !== null && value.startsWith('ok#'), `the admin list answers: ${output}`);
  const body = value.slice(3);
  return body === '' ? [] : body.split(';').map((entry) => {
    const [id, user, application, preserve, pid] = entry.split('|');
    return { id, user, application, preserve, pid };
  });
}

/** Seed one session as the configured account by requesting `path`, answering its id. */
async function seed(path = SEED_PATH) {
  const application = path.slice(0, path.lastIndexOf('/') + 1);
  const before = new Set(listed().map((row) => row.id));
  const answer = await fetch(`${config.origin}${path}`, { headers: { Authorization: authHeader(config) } });
  assert.equal(answer.status, 200, `${path} answers the configured account (HTTP ${answer.status})`);
  const fresh = listed().filter((row) => !before.has(row.id) && row.application === application && row.user === config.username);
  seeded.push(...fresh.map((row) => row.id));
  assert.equal(fresh.length, 1, `the request left one new session: ${JSON.stringify(fresh)}`);
  return fresh[0].id;
}

/**
 * End session `id` through the admin API, as a teardown step. A preserve-mode session's own process
 * holds its lock, so that process is terminated first.
 */
function endSession(id) {
  const row = listed().find((candidate) => candidate.id === id);
  if (row === undefined) return;
  if (row.preserve === '1' && /^\d+$/.test(row.pid)) runIris(config.container, [`Do $SYSTEM.Process.Terminate(${row.pid})`]);
  runIris(config.container, [`Kill q Set q("id")="${escapeOs(id)}" Set sc=##class(OcuPilot.Port.AdminPort).Invoke("WebSession","DELETE",.q,"",.r,.h,.f)`]);
}

/** Compile (`Create`) or delete (`Remove`) the preserve-mode page on the throwaway. */
function preservedPage(method) {
  const output = runIris(config.container, [
    `Set sc=##class(OcuPilot.Test.PreservedSession).${method}()`,
    'Write "OCU-WSPAGE-START:"_$Select($System.Status.IsOK(sc):"ok",1:$System.Status.GetErrorText(sc))_":OCU-WSPAGE-END",!',
  ]);
  assert.equal(markerValue(output, 'WSPAGE'), 'ok', `OcuPilot.Test.PreservedSession.${method} answers: ${output}`);
}

/** `id` with every letter's case swapped: an id the instance holds as a different session. */
function caseTwin(id) {
  return [...id].map((char) => (char === char.toUpperCase() ? char.toLowerCase() : char.toUpperCase())).join('');
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Every rendered row, cell by cell, in row order. */
function describeRows(page) {
  return page.evaluate((rowSelector) => {
    const rows = Array.from(document.querySelectorAll(rowSelector));
    return rows.map((row) => ({
      cells: Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()),
      linked: row.querySelector('[role="gridcell"] .ocu-data-table-link') !== null,
    }));
  }, ROW_SELECTOR);
}

/**
 * The DW-1337 walk of this screen at 1280 light, 720 light and 1280 dark, answering every entry the
 * baseline does not already hold; with `dialog`, the open dialog's body is also held to scrolling
 * nothing sideways, which the walk skips inside a scroll container.
 */
async function structural(page, dialog = false) {
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
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route: ROUTE, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
    if (dialog) {
      const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
      assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
    }
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** Signed in at the list with its rows rendered, recording every request to the action route. */
async function atList() {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push({ method: request.method(), body: request.postData() ?? '' });
  });
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page, posts };
}

/** Filter the list to session `id` and select its row by the User cell. */
async function selectSession(page, id) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, id);
  await page.waitForFunction(
    (rowSelector, filterSelector, wanted) => {
      if (document.querySelector(filterSelector)?.value !== wanted) return false;
      const rows = Array.from(document.querySelectorAll(rowSelector));
      return rows.length === 1 && rows[0].textContent.includes(wanted);
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    FILTER_SELECTOR,
    id
  );
  await clickRowCentre(page, { index: 0, cell: 3 });
  await page.waitForFunction(
    (rowSelector) => document.querySelector(rowSelector)?.getAttribute('aria-selected') === 'true',
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR
  );
}

before(async () => {
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec ends web sessions, so it runs only in a throwaway; ${config.container} is not one`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (/-ci$/.test(config.container)) {
      for (const id of seeded) endSession(id);
      try {
        const left = listed().filter((row) => seeded.includes(row.id));
        assert.deepEqual(left, [], 'every session this spec seeded is ended');
      } finally {
        preservedPage('Remove');
      }
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1. Mutation (Rule 19): declare Web sessions' sideBarPosition 1 -> the side-bar order goes red.
test('AC1: a seeded session is listed with its user, application and no process, and Web sessions is the third Web applications entry', async () => {
  const id = await seed();
  const { context, page } = await atList();
  try {
    // A rail click opens the area's side bar without navigating (`shell-state.ts`'s `activateArea`).
    await page.click(`.ocu-rail-item[aria-label="${STRINGS.navAreaWebApplications}"]`);
    await page.waitForFunction(
      (label) => Array.from(document.querySelectorAll('.ocu-side-bar-label')).some((node) => node.textContent.trim() === label),
      { timeout: config.navigationTimeoutMs },
      STRINGS.webSessionListLabel
    );
    const labels = await page.$$eval('.ocu-side-bar-item .ocu-side-bar-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(labels, [STRINGS.webAppListLabel, STRINGS.restApiListLabel, STRINGS.webSessionListLabel], 'the side bar lists Web sessions third');
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 5),
      [STRINGS.processColumnPid, STRINGS.webSessionColumnSession, STRINGS.processColumnUser, STRINGS.oauthResourceServerFieldApplication, STRINGS.webSessionColumnExpires],
      'the declared headers, ahead of the row actions'
    );
    const row = (await describeRows(page)).find((candidate) => candidate.cells[1] === id);
    assert.ok(row !== undefined, `the seeded session is listed: ${JSON.stringify(await describeRows(page))}`);
    assert.deepEqual(row.cells.slice(0, 4), [STRINGS.tableEmptyValue, id, config.username, SEED_PATH], 'as no process, its id, its user and its application');
    assert.equal(row.linked, false, 'and a session with no process links nowhere');
    assert.deepEqual(await structural(page), [], 'the list alone passes the structural and contrast checks beyond the baseline');
  } finally {
    await context.close();
  }
});

// AC2. Mutations (Rule 19), each over a rebuilt and redeployed bundle or a recompiled class: skip
// AdminPort's wait for the daemon -> the re-read still carries the row and the row-leaves wait
// fails; remove 'end' from DESTRUCTIVE_ACTIONS -> no dialog opens and the dialog wait fails.
test('AC2: End session types the session id, sends one request on the exact id, and the row leaves; the dialog passes DW-1337', async () => {
  const id = await seed();
  const { context, page, posts } = await atList();
  try {
    await selectSession(page, id);
    await page.click(`${ROW_SELECTOR}[aria-selected="true"] .ocu-data-table-trigger`);
    await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((label) => {
      const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
      items.find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === label).click();
    }, STRINGS.webSessionEndAction);
    await page.waitForSelector('app-typed-name-dialog', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('.ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
      released: document.querySelector('.ocu-button-destructive').getAttribute('aria-disabled'),
    }));
    assert.equal(opened.title, `${STRINGS.webSessionEndAction} ${id}`, 'the title names the verb and the session id');
    assert.equal(opened.consequence, STRINGS.webSessionEndConsequence, 'the body states the published consequence');
    assert.equal(opened.released, 'true', 'and the button is aria-disabled until the id is typed');

    assert.deepEqual(await structural(page, true), [], 'with the dialog open, no violation beyond the baseline\'s entries');

    // A case twin of the id is another session's, and sends nothing.
    await page.type('.ocu-typed-name-field', caseTwin(id));
    await page.evaluate(() => document.querySelector('.ocu-typed-name-field').blur());
    await page.waitForSelector('.ocu-typed-name-mismatch', { timeout: config.navigationTimeoutMs });
    await page.focus('.ocu-typed-name-field');
    await page.keyboard.press('Enter');
    await page.click('.ocu-button-destructive');
    await frames(page);
    assert.equal(posts.length, 0, 'a mismatched id sends nothing');

    await page.click('.ocu-typed-name-field', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('.ocu-typed-name-field', id);
    await page.waitForFunction(() => document.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled') === null, {
      timeout: config.navigationTimeoutMs,
    });
    await page.click('.ocu-button-destructive');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      (rowSelector, wanted) => !Array.from(document.querySelectorAll(rowSelector)).some((row) => row.textContent.includes(wanted)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      id
    );
    assert.equal(posts.length, 1, `exactly one request, sent once the id matched: ${JSON.stringify(posts)}`);
    assert.equal(posts[0].method, 'POST');
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'end', id });
    assert.equal(listed().some((row) => row.id === id), false, 'and the instance no longer carries the session');
  } finally {
    await context.close();
  }
});

// DW-1792. Mutation (Rule 19): answer the preserve-mode sentence for a `Preserve` 1 row in
// `selfProtectionReason`'s `ocupilot-session` branch, then rebuild and redeploy -> the entry is
// drawn refused and the offered-entry assertion goes red.
test('DW-1792: a real preserve-mode session lists with its process linked, and while that process runs End session is answered with the sentence pointing to it', async () => {
  preservedPage('Create');
  const id = await seed(PRESERVED_PATH);
  const session = listed().find((row) => row.id === id);
  assert.equal(session?.preserve, '1', `the page left a preserve-mode session: ${JSON.stringify(session)}`);
  assert.match(session.pid, /^\d+$/, 'with its own process');
  const { context, page, posts } = await atList();
  try {
    await selectSession(page, id);
    const cell = await page.evaluate((rowSelector) => {
      const link = document.querySelector(`${rowSelector}[aria-selected="true"] [role="gridcell"] .ocu-data-table-link`);
      return link === null ? null : { text: link.textContent.trim(), href: link.getAttribute('href') };
    }, ROW_SELECTOR);
    assert.equal(cell?.text, session.pid, 'the Process cell carries the session\'s own process');
    assert.ok(cell.href.includes(`/os-management/processes/details/${session.pid}`), `and links to its Process details: ${cell.href}`);

    await page.click(`${ROW_SELECTOR}[aria-selected="true"] .ocu-data-table-trigger`);
    await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
    const entry = await page.evaluate((label) => {
      const item = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]')).find(
        (candidate) => candidate.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === label
      );
      if (item === undefined) return null;
      const drawn = { disabled: item.getAttribute('aria-disabled'), reason: item.querySelector('.ocu-data-table-menu-reason')?.textContent.trim() ?? '' };
      item.click();
      return drawn;
    }, STRINGS.webSessionEndAction);
    assert.deepEqual(entry, { disabled: null, reason: '' }, 'End session is offered: the list does not show whether the process runs');
    await page.waitForSelector('app-typed-name-dialog', { timeout: config.navigationTimeoutMs });
    await page.type('.ocu-typed-name-field', id);
    await page.waitForFunction(() => document.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled') === null, {
      timeout: config.navigationTimeoutMs,
    });
    await page.click('.ocu-button-destructive');
    await page.waitForSelector('.ocu-list-page-banner[role="alert"] .ocu-banner-message', { timeout: config.navigationTimeoutMs });
    const refusal = await page.$eval('.ocu-list-page-banner[role="alert"] .ocu-banner-message', (element) => element.textContent.trim());
    assert.equal(refusal, STRINGS.webSessionRefusalPreserved, 'the instance answers with the sentence pointing to the process');
    assert.equal(posts.length, 1, `after one request: ${JSON.stringify(posts)}`);
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'end', id });
    assert.equal(listed().find((row) => row.id === id)?.pid, session.pid, 'and the session is still listed with its process');
  } finally {
    await context.close();
  }
});

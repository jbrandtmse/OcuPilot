/**
 * The Web application create form in a real browser, against the throwaway instance (Story 8.1).
 *
 * Eight claims, each asserted on rendered DOM, on measured geometry or on the real URL rather than
 * on store state:
 *
 * 1. **The form captures the field set in the classic order** (AC1), and the type control shows
 *    only the fields its type uses.
 * 2. **A valid Save creates the application**, replaces the route with the new application's
 *    editor and reads the saved sentence in the sticky bar (AC2) -- and the row then appears in
 *    the list, which is this story's Integration AC. **The change event itself is pinned where it
 *    is falsifiable**, in `create-form.store.spec.ts`: the list this leg navigates to re-reads the
 *    instance on open whether or not anything was published.
 * 3. **The list's command bar offers Create**, runs it exactly once per click, survives navigating
 *    away and back, and raises no `ExpressionChangedAfterItHasBeenCheckedError` (AC3, DW-246).
 * 4. **A server refusal lands on the field it names** (DW-376): the namespace is cleared and the
 *    refusal renders on that field, with the sentence the server authored.
 * 5. **UX-DR80's two widths are what the form is drawn at** (AC4): the measured column equals
 *    `--ocu-form-max-width` and the measured field `--ocu-field-max-width`, at the longest label
 *    and a value longer than the field, with the token read off the document so the comparison
 *    cannot be 0 against 0. `ui/tools/design-tokens.test.mjs` is what makes the confirmed figures
 *    bind every later form.
 * 6. **A Python application's directory is shown resolved under the instance's fixed root**
 *    (AD-21, DW-1495), read-only, with the root read from the throwaway itself.
 * 7. **Choosing Unauthenticated states its effect at the authentication field** (DW-1489), and only
 *    while it is ticked.
 * 8. **Application roles follow the authentication methods** (AC7, AD-10): a privileged role states
 *    the privilege-grant consequence -- one combined line, in place of both, while Unauthenticated
 *    is also ticked -- and a Save applies it.
 *
 * **It refuses the live container**, for the reason its siblings do: the throwaway is the instance
 * a browser run drives, and this spec creates web applications. It removes every one it created in
 * `after`, through the vendor's own `Security.Applications.Delete` inside the throwaway -- there
 * is no OcuPilot delete route for a web application yet, and leaving one behind would change what
 * the next run's list measures.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/web-applications/list?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/web-applications/list/edit?ns=HSCUSTOM';

/** Every application this spec creates lives under this prefix and is removed in `after`. */
const PREFIX = '/csp/ocupilotbrowserprobe';

const NAMES = [`${PREFIX}create`, `${PREFIX}refusal`, `${PREFIX}geometry`, `${PREFIX}roles`];

/** A value far longer than the field it is typed into, for the geometry leg. */
const LONG_VALUE = 'a-very-long-web-application-description-'.padEnd(220, 'x');

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  assert.notEqual(config.container, '', 'it removes the applications it creates, so it needs the container that serves the origin');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await removeProbeApplications();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  await removeProbeApplications();
  if (browser !== null) await browser.close();
});

function credentials() {
  return { user: config.username, password: config.password };
}

/**
 * Remove every application this spec creates, by name, inside the throwaway.
 *
 * Only the names above, never a prefix sweep over whatever the instance holds: an
 * application this spec did not create is somebody else's, and deleting one would be the failure
 * `ProposalFixture.EnsureWriteTarget` refuses for the same reason.
 */
async function removeProbeApplications() {
  const lines = NAMES.map(
    (name) => `Do ##class(Security.Applications).Delete("${name}")`
  );
  spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
}

/**
 * The fixed WSGI root, computed inside the throwaway the way AD-21 states it: `wsgi` under the
 * Manager Directory, normalized. Read independently of OcuPilot, so the form's line is compared
 * with the instance rather than with itself.
 */
function wsgiRoot() {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: 'Write "OCU-ROOT-START:",##class(%File).NormalizeDirectory("wsgi", $System.Util.ManagerDirectory()),":OCU-ROOT-END",!\nHalt\n',
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const match = /OCU-ROOT-START:(.*?):OCU-ROOT-END/.exec(output);
  assert.ok(match !== null && match[1] !== '', `the throwaway answered its WSGI root: ${output}`);
  return match[1];
}

/** Whether the instance holds a web application called `name`, read inside the throwaway. */
function applicationExists(name) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `Write "OCU-EXISTS-START:",##class(Security.Applications).Exists("${name}"),":OCU-EXISTS-END",!\nHalt\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const match = /OCU-EXISTS-START:(.*?):OCU-EXISTS-END/.exec(output);
  return match !== null && match[1].trim() === '1';
}

/** A fresh context signed in through the shell's own form, landed at `url`. */
async function signedInAt(url) {
  const { user, password } = credentials();
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page };
}

/** Type `value` into the form control `id`, replacing whatever is there. */
async function fill(page, id, value) {
  await page.waitForSelector(`#${id}`, { visible: true, timeout: config.navigationTimeoutMs });
  await page.click(`#${id}`, { clickCount: 3 });
  await page.type(`#${id}`, value);
}

/** The Save button in the sticky bar. */
async function saveButton(page) {
  const buttons = await page.$$('.ocu-form-bar-actions button');
  const save = buttons.at(-1);
  assert.ok(save, 'the sticky bar carries a primary action');
  return save;
}

/** Fill the form with a minimal, valid CSP application named `name`. */
async function fillMinimal(page, name) {
  await page.waitForSelector('#ocu-web-app-Name', { visible: true, timeout: config.navigationTimeoutMs });
  await fill(page, 'ocu-web-app-Name', name);
  await fill(page, 'ocu-web-app-NameSpace', 'HSCUSTOM');
  // One authentication method, ticked explicitly. The store starts on the instance's first
  // offered method, so this asserts the group is there rather than changing what is sent.
  const methods = await page.$$('fieldset.ocu-form-authe input[type="checkbox"]');
  assert.ok(methods.length > 0, 'the instance offers at least one authentication method');
  const checked = await page.$$eval(
    'fieldset.ocu-form-authe input[type="checkbox"]',
    (nodes) => nodes.filter((node) => node.checked).length
  );
  assert.ok(checked > 0, 'and the form starts with one ticked, because an application with none is refused');
}

// AC1. Mutation (Rule 19): remove the authentication-methods fieldset from the template ->
// this goes red naming the missing control.
test('AC1: the form captures the classic field set in order, and the type control shows only its own fields', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-web-app-Name', { visible: true, timeout: config.navigationTimeoutMs });

    // The field roster, in document order, read off the rendered labels rather than a list.
    // Every field's own name in document order: a text field's `.ocu-field-label`, a checkbox's
    // own wrapping label (the shipped idiom -- the whole row is one target), and the
    // authentication group's `legend`.
    const labels = await page.$$eval(
      [
        '.ocu-form-fields > .ocu-field:not(.ocu-form-authe) > .ocu-field-label',
        '.ocu-form-fields > .ocu-field:not(.ocu-form-authe) > .ocu-field-checkbox > span',
        '.ocu-form-fields > .ocu-form-authe > legend',
      ].join(', '),
      (nodes) => nodes.map((node) => node.textContent.trim())
    );
    assert.deepEqual(
      labels,
      [
        STRINGS.tableColumnName,
        STRINGS.tableColumnDescription,
        STRINGS.headerNamespaceLabel,
        STRINGS.tableColumnEnabled,
        STRINGS.webAppFormType,
        STRINGS.webAppColumnResource,
        STRINGS.serviceColumnAuthentication,
        STRINGS.webAppFormApplicationRoles,
        STRINGS.webAppFormRecurse,
      ],
      'a CSP application draws the classic order over the reviewed create fields'
    );
    // The methods themselves are the instance's own words, never this client's -- they are inside
    // the group rather than in the field roster above, and there is at least one.
    const methods = await page.$$eval('fieldset.ocu-form-authe .ocu-field-checkbox > span', (nodes) =>
      nodes.map((node) => node.textContent.trim())
    );
    assert.ok(methods.length > 0, `the group offers the methods this instance enables: ${JSON.stringify(methods)}`);
    assert.equal(await page.$('#ocu-web-app-DispatchClass'), null, 'a CSP application shows no dispatch class');
    assert.equal(await page.$('#ocu-web-app-WSGIAppName'), null, 'and none of the Python fields');

    // REST: the dispatch class appears and the Python fields do not.
    await page.select('#ocu-web-app-Type', 'rest');
    await page.waitForSelector('#ocu-web-app-DispatchClass', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('#ocu-web-app-WSGIAppName'), null, 'a REST application shows no Python fields');

    // Python: the four Python fields appear and the dispatch class does not.
    await page.select('#ocu-web-app-Type', 'python');
    await page.waitForSelector('#ocu-web-app-WSGIAppName', { visible: true, timeout: config.navigationTimeoutMs });
    for (const id of ['ocu-web-app-WSGIType', 'ocu-web-app-WSGICallable', 'ocu-web-app-WSGIAppLocation']) {
      assert.ok(await page.$(`#${id}`), `a Python application shows ${id}`);
    }
    assert.equal(await page.$('#ocu-web-app-DispatchClass'), null, 'and no dispatch class');
    const protocols = await page.$$eval('#ocu-web-app-WSGIType option', (nodes) =>
      nodes.map((node) => node.textContent.trim())
    );
    assert.deepEqual(protocols, ['WSGI', 'ASGI'], "the protocol options are the instance's own display list");
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): drop the route replacement from `onSave` -> the editor-URL leg goes
// red. The `ChangeBus.publish` is NOT pinned here and this leg does not falsify it: the list leg
// below navigates to the list, which re-reads the instance on open whether or not anything was
// published (see this file's header). The publish is pinned in `create-form.store.spec.ts`.
test('AC2: a valid Save creates the application, replaces the route and reads the saved sentence', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await fillMinimal(page, NAMES[0]);
    await (await saveButton(page)).click();

    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSaved
    );
    // AC2: the route is replaced with the new application's editor, so the URL names the
    // application just created.
    await page.waitForFunction(
      () => /\/web-applications\/list\/edit\/[^/]+$/.test(new URL(window.location.href).pathname),
      { timeout: config.navigationTimeoutMs }
    );

    assert.ok(applicationExists(NAMES[0]), 'the instance holds the application the form created');


    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, LIST_URL);
    await waitForRows(page, config.navigationTimeoutMs);
    const rows = await page.$$eval('[role="grid"] .ocu-data-table-body [role="row"]', (nodes) =>
      nodes.map((node) => node.textContent)
    );
    assert.ok(
      rows.some((text) => text.includes(NAMES[0])),
      `the row the form created is in the list: ${JSON.stringify(rows.slice(0, 8))}`
    );
  } finally {
    await context.close();
  }
});

// AC3 and DW-246. Mutations (Rule 19): drop the `WebAppActions` injection from `app.ts` -> the
// "Create is offered" leg goes red; make `WebAppActions.openCreate` push a second history entry
// -> the navigation-count leg goes red; move the registration into the page's own constructor ->
// the console leg goes red with NG0100.
//
// Note what the navigation-count leg does and does not cover. `ScreenActions` holds ONE handler
// per (descriptor, action) and `run` invokes it once, so "the handler fires twice" is not a shape
// this client can produce; `ui/tools/screen-actions.test.mjs` is where that is pinned. What this
// leg pins is the handler's own half -- one click leaves exactly one entry behind -- which is the
// observable harm the criterion names. Two `navigateByUrl` calls to the SAME url do not falsify
// it, because the router coalesces them (measured).
test('AC3: Create is offered, runs once per click, survives leaving and returning, and raises no NG0100', async () => {
  const { context, page } = await signedInAt(LIST_URL);
  const consoleErrors = [];
  page.on('console', (message) => {
    if (message.type() === 'error') consoleErrors.push(message.text());
  });
  page.on('pageerror', (error) => consoleErrors.push(String(error)));
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const create = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', {
      visible: true,
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(
      (await create.evaluate((node) => node.textContent.trim())),
      STRINGS.actionCreate,
      'the command bar offers the declared primary action'
    );

    // One click, one navigation, counted at `history.pushState` -- which is what the Angular
    // router calls, and what a handler registered twice calls twice for one click.
    //
    // NOT `history.length`: it is never below 1, so a floor assertion on it holds for every run
    // including one where the click did nothing, and a push made while the session history has
    // forward entries truncates them rather than extending, so even a delta can read 0 for a
    // navigation that happened (measured here, 3 -> 3).
    await page.evaluate(() => {
      window.__ocuPushes = 0;
      const original = history.pushState.bind(history);
      history.pushState = (...args) => {
        window.__ocuPushes += 1;
        return original(...args);
      };
    });
    await create.click();
    await page.waitForFunction(
      () => new URL(window.location.href).pathname.endsWith('/web-applications/list/edit'),
      { timeout: config.navigationTimeoutMs }
    );
    const pushes = await page.evaluate(() => window.__ocuPushes);

    // Navigate away and back: the registration outlives the page, so Create is still offered.
    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, LIST_URL);
    await waitForRows(page, config.navigationTimeoutMs);
    const again = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', {
      visible: true,
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(
      (await again.evaluate((node) => node.textContent.trim())),
      STRINGS.actionCreate,
      'and it is still offered after leaving and returning'
    );
    await again.click();
    await page.waitForFunction(
      () => new URL(window.location.href).pathname.endsWith('/web-applications/list/edit'),
      { timeout: config.navigationTimeoutMs }
    );
    assert.equal(pushes, 1, `one click made exactly one router navigation, not ${pushes}`);

    const ng0100 = consoleErrors.filter((text) => text.includes('NG0100') || text.includes('ExpressionChanged'));
    assert.deepEqual(ng0100, [], `no ExpressionChangedAfterItHasBeenChecked was raised: ${JSON.stringify(consoleErrors)}`);
  } finally {
    await context.close();
  }
});

// The refusal leg. Mutation (Rule 19): drop the namespace rule from `OcuPilot.Area.WebApp.Create`'s
// `Validate` -> the namespace field no longer carries OcuPilot's own sentence. The leg is written
// against the sentence AND the field it renders on.
test('a refused Save renders the field-level sentence the server authored, on the field it names', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await fillMinimal(page, NAMES[1]);
    // Clear the namespace: the vendor requires it on a create and only on a create, and OcuPilot
    // states the rule on the field before the port is touched.
    await page.click('#ocu-web-app-NameSpace', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await (await saveButton(page)).click();

    await page.waitForSelector('#ocu-web-app-NameSpace-reason', { visible: true, timeout: config.navigationTimeoutMs });
    const sentence = await page.$eval('#ocu-web-app-NameSpace-reason', (node) => node.textContent.trim());
    assert.ok(sentence.length > 0, 'the refusal renders a sentence on the namespace field');
    const invalid = await page.$eval('#ocu-web-app-NameSpace', (node) => node.getAttribute('aria-invalid'));
    assert.equal(invalid, 'true', 'and the control is marked invalid');
    const describedBy = await page.$eval('#ocu-web-app-NameSpace', (node) => node.getAttribute('aria-describedby'));
    assert.equal(describedBy, 'ocu-web-app-NameSpace-reason', 'and described by the sentence');

    // The error summary lists the same sentence and holds focus (EXPERIENCE.md's form-page rule).
    const summary = await page.$('.ocu-form-summary');
    assert.ok(summary, 'a failed Save raises the error summary');
    const links = await page.$$eval('.ocu-form-summary-list button', (nodes) =>
      nodes.map((node) => node.textContent.trim())
    );
    assert.ok(links.includes(sentence), `the summary lists the same sentence: ${JSON.stringify(links)}`);

    assert.ok(!applicationExists(NAMES[1]), 'and nothing was created');
  } finally {
    await context.close();
  }
});

// AC4, UX-DR80. Mutation (Rule 19): change `--ocu-form-max-width` to 640px in `_metrics.scss`,
// rebuild and redeploy the bundle -> the column assertion goes red naming both figures.
test('AC4: the form column is --ocu-form-max-width and its fields --ocu-field-max-width, at the longest label and a longer value', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-web-app-Name', { visible: true, timeout: config.navigationTimeoutMs });
    // Python, because it draws the longest labels this form has, and a value longer than the
    // field it is typed into, so the measurement is taken at the worst case rather than at rest.
    await page.select('#ocu-web-app-Type', 'python');
    await page.waitForSelector('#ocu-web-app-WSGIAppLocation', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, 'ocu-web-app-Description', LONG_VALUE);

    // A viewport wider than the column, so what bounds the column is the token and not the window.
    await page.setViewport({ width: 1600, height: 1000 });

    const measured = await page.evaluate(() => {
      const styles = getComputedStyle(document.documentElement);
      const token = (name) => parseFloat(styles.getPropertyValue(name));
      // The column is the form page's own box, which is what `--ocu-form-max-width` bounds; the
      // field is the `.ocu-field` the description control sits in, which `--ocu-field-max-width`
      // bounds. Measuring the inner `.ocu-form-fields` instead would measure the column minus its
      // own gutters and read a smaller number against a token it never carried.
      const column = document.querySelector('.ocu-form-page');
      const control = document.querySelector('#ocu-web-app-Description');
      const field = control.closest('.ocu-field');
      const labels = [
        ...document.querySelectorAll(
          [
            '.ocu-form-fields > .ocu-field:not(.ocu-form-authe) > .ocu-field-label',
            '.ocu-form-fields > .ocu-field:not(.ocu-form-authe) > .ocu-field-checkbox > span',
            '.ocu-form-fields > .ocu-form-authe > legend',
          ].join(', ')
        ),
      ];
      const lineHeight = (element) => parseFloat(getComputedStyle(element).lineHeight);
      return {
        formMaxWidth: token('--ocu-form-max-width'),
        fieldMaxWidth: token('--ocu-field-max-width'),
        formBarHeight: token('--ocu-form-bar-height'),
        columnWidth: column.getBoundingClientRect().width,
        inputWidth: field.getBoundingClientRect().width,
        inputScrolls: control.scrollWidth > control.clientWidth,
        barHeight: document.querySelector('.ocu-form-bar').getBoundingClientRect().height,
        labelOverflow: labels.map((label) => ({
          text: label.textContent.trim(),
          height: label.getBoundingClientRect().height,
          line: lineHeight(label),
          clipped: label.scrollWidth > label.clientWidth,
        })),
        documentScrolls: document.documentElement.scrollWidth > document.documentElement.clientWidth,
      };
    });

    // The token is non-zero, so the comparison below cannot be 0 against 0 -- the whole point of
    // reading it off the document rather than asserting a literal here.
    assert.ok(measured.formMaxWidth > 0, `the token layer loaded: --ocu-form-max-width is ${measured.formMaxWidth}`);
    assert.ok(measured.fieldMaxWidth > 0, `and --ocu-field-max-width is ${measured.fieldMaxWidth}`);
    assert.equal(measured.formMaxWidth, 720, 'UX-DR80: the confirmed column width');
    assert.equal(measured.fieldMaxWidth, 480, 'UX-DR80: the confirmed field width');
    assert.equal(measured.formBarHeight, 56, 'and the sticky bar, which was decided rather than assumed');

    assert.equal(
      Math.round(measured.columnWidth),
      measured.formMaxWidth,
      `the rendered column is the token: ${measured.columnWidth}`
    );
    assert.equal(
      Math.round(measured.inputWidth),
      measured.fieldMaxWidth,
      `the rendered field is the token: ${measured.inputWidth}`
    );
    assert.ok(measured.inputScrolls, 'a value longer than the field scrolls inside it');
    assert.equal(
      Math.round(measured.barHeight),
      measured.formBarHeight,
      `and the sticky bar is its own token: ${measured.barHeight}`
    );
    assert.equal(measured.documentScrolls, false, 'and nothing widened the page');

    for (const label of measured.labelOverflow) {
      assert.ok(
        label.height <= label.line * 1.5,
        `"${label.text}" renders on one line: height ${label.height} against line ${label.line}`
      );
      assert.equal(label.clipped, false, `and "${label.text}" is not clipped`);
    }
  } finally {
    await context.close();
  }
});

// AD-21, DW-1495. Mutation (Rule 19): drop the typed name from the store's `resolvedDirectory` ->
// the resolved line reads the bare root and this goes red.
test('a Python application\'s directory is shown resolved under the fixed root, read-only', async () => {
  const root = wsgiRoot();
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-web-app-Name', { visible: true, timeout: config.navigationTimeoutMs });
    await page.select('#ocu-web-app-Type', 'python');
    await fill(page, 'ocu-web-app-WSGIAppLocation', 'probeapp');
    await page.waitForFunction(
      (expected) => document.querySelector('#ocu-web-app-WSGIAppLocation-resolved code')?.textContent?.trim() === expected,
      { timeout: config.navigationTimeoutMs },
      `${root}probeapp/`
    );
    const line = await page.$eval('#ocu-web-app-WSGIAppLocation-resolved', (node) => ({
      text: node.textContent.trim(),
      editable: node.querySelector('input, textarea, [contenteditable]') !== null,
    }));
    assert.ok(line.text.startsWith(STRINGS.webAppFormPythonDirectoryResolved), `the line is labelled: ${line.text}`);
    assert.equal(line.editable, false, 'and it is display only');
    const describedBy = await page.$eval('#ocu-web-app-WSGIAppLocation', (node) => node.getAttribute('aria-describedby') ?? '');
    assert.ok(describedBy.split(' ').includes('ocu-web-app-WSGIAppLocation-resolved'), 'the field is described by it');
  } finally {
    await context.close();
  }
});

// DW-1489. Mutation (Rule 19): drop the effect line from the authentication fieldset -> this goes
// red on the ticked leg.
test('ticking Unauthenticated states its effect at the authentication field, and unticking removes it', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('fieldset.ocu-form-authe', { visible: true, timeout: config.navigationTimeoutMs });
    const box = '#ocu-web-app-AutheEnabled-64';
    assert.ok(await page.$(box), 'the instance offers the Unauthenticated method (bit 64)');
    const effect = '#ocu-web-app-AutheEnabled-effect';
    if (await page.$eval(box, (node) => node.checked)) await page.click(box);
    assert.equal(await page.$(effect), null, 'no effect is stated while Unauthenticated is not ticked');

    await page.click(box);
    await page.waitForSelector(effect, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval(effect, (node) => node.textContent.trim()), STRINGS.webAppUnauthenticatedEffect);
    const describedBy = await page.$eval('fieldset.ocu-form-authe', (node) => node.getAttribute('aria-describedby') ?? '');
    assert.equal(describedBy, 'ocu-web-app-AutheEnabled-effect', 'the group is described by the effect');

    await page.click(box);
    await page.waitForFunction((selector) => document.querySelector(selector) === null, { timeout: config.navigationTimeoutMs }, effect);
  } finally {
    await context.close();
  }
});

/** The stored application roles of `name`, read inside the throwaway. */
function storedMatchRoles(name) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `Set tOK = ##class(Security.Applications).Get("${name}", .tProps)\nWrite "OCU-ROLES-START:",$Get(tProps("MatchRoles")),":OCU-ROLES-END",!\nHalt\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const match = /OCU-ROLES-START:(.*?):OCU-ROLES-END/.exec(output);
  return match === null ? null : match[1];
}

// AC7, AD-10. Mutation (Rule 19): make the page's `privilegedRoleFlag` answer false -> the
// consequence leg goes red; make `privilegeEffect` ignore Unauthenticated -> the combined leg goes
// red.
test('AC7: a privileged application role states its consequence, one line with Unauthenticated, and a Save applies it', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await fillMinimal(page, NAMES[3]);
    const unauthenticated = '#ocu-web-app-AutheEnabled-64';
    const roleEffect = '#ocu-web-app-MatchRoles-effect';
    const autheEffect = '#ocu-web-app-AutheEnabled-effect';
    await page.waitForSelector('#ocu-web-app-MatchRoles', { visible: true, timeout: config.navigationTimeoutMs });
    if (await page.$eval(unauthenticated, (node) => node.checked)) await page.click(unauthenticated);
    const offered = await page.evaluate(() => document.getElementById('ocu-web-app-MatchRoles-%All') !== null);
    assert.ok(offered, 'the application-roles control offers %All');
    assert.equal(await page.$(roleEffect), null, 'no consequence before a privileged role is ticked');

    await page.evaluate(() => document.getElementById('ocu-web-app-MatchRoles-%All').click());
    await page.waitForSelector(roleEffect, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval(roleEffect, (node) => node.textContent.trim()), STRINGS.privilegedGrantEffect);

    await page.click(unauthenticated);
    await page.waitForFunction(
      (selector, sentence) => document.querySelector(selector)?.textContent?.trim() === sentence,
      { timeout: config.navigationTimeoutMs },
      roleEffect,
      STRINGS.privilegedGrantEffectUnauthenticated
    );
    assert.equal(await page.$(autheEffect), null, 'the one combined line replaces the unauthenticated effect');

    await page.click(unauthenticated);
    await page.waitForFunction(
      (selector, sentence) => document.querySelector(selector)?.textContent?.trim() === sentence,
      { timeout: config.navigationTimeoutMs },
      roleEffect,
      STRINGS.privilegedGrantEffect
    );
    await (await saveButton(page)).click();
    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSaved
    );
    assert.equal(storedMatchRoles(NAMES[3]), ':%All', 'the Save grants %All as the application role');
  } finally {
    await context.close();
  }
});

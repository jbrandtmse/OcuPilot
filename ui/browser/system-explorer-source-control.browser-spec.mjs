/**
 * Story 21.38 in a real browser, against the throwaway: on a namespace whose source-control class asks a question after a delete, the
 * Classes list shows that question in its own dialog, and the person's Yes runs the class's `AfterUserAction` as the signed-in person.
 *
 * What it pins, on one probe class in `USER` (`OcuPilot.Test.ExplorerProbe`'s) with `OcuPilot.Test.SourceControlProbe`'s source-control
 * class enabled in `USER` and its user action set to ask (action 1):
 *
 * - AC5: the probe class is deleted through the typed-name dialog, the class's question shows with Yes, No and Cancel, Yes sends one
 *   `answer` for the document with the step the delete followed, and the probe's log holds `AfterUserAction` for that document with the
 *   answer Yes, run by the signed-in person.
 * - AC9: the question is plain text on the dialog alone: it is not in the list's output pane or status line once the dialog has closed.
 *
 * **It enables a source-control class in `USER` and creates and deletes a class there**, so it runs on a throwaway only and refuses a
 * container that is not one, and the live and slot containers. `after` takes the source-control class, its log and the probe class away and
 * asserts that none is left.
 *
 * Run: `npm run build`, `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> node --test --test-concurrency=1 browser/system-explorer-source-control.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'system-explorer/classes';
const LIST_URL = `/ocupilot/${ROUTE}?ns=USER`;
const ACTION_PATH = '/api/ocupilot/screens/explorer.classes/action';
const NAMESPACE = 'USER';
const PROBE = 'OcuPilot.Test.ExplorerProbe';
const SC = 'OcuPilot.Test.SourceControlProbe';
const CLASS = 'OcuProbe192.Asked';
const DOCUMENT = `${CLASS}.cls`;
const QUESTION = 'OcuPilot probe asks: proceed?';

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Every hook call the probe has logged, oldest first, as `{ hook, name, user, job, extra }`. */
function readEntries() {
  const read = probe('SCLOG', `##class(${SC}).Entries("${NAMESPACE}").%ToJSON()`);
  assert.notEqual(read.value, null, `the probe's log is read: ${read.output}`);
  return JSON.parse(read.value);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec enables source control in ${NAMESPACE} and deletes a class there, so it runs only in a throwaway; ${config.container} is not one`);
  const disabled = probe('SCDISABLE', `$System.Status.GetErrorText(##class(${SC}).Disable("${NAMESPACE}"))`);
  assert.equal(disabled.value, '', `an earlier run's source-control class is taken out of ${NAMESPACE}: ${disabled.output}`);
  const removed = probe('SCCLEAN', `$System.Status.IsOK(##class(${PROBE}).Remove("${NAMESPACE}"))`);
  assert.equal(removed.value, '1', `an earlier run's probe classes are removed from ${NAMESPACE}: ${removed.output}`);
  created = true;
  // The class is saved before source control is enabled, so saving it runs no hook and the log holds the delete's calls alone.
  const made = probe('SCMAKE', `$System.Status.GetErrorText(##class(${PROBE}).MakeClass("${NAMESPACE}","${CLASS}"))`);
  assert.equal(made.value, '', `the probe class is saved in ${NAMESPACE}: ${made.output}`);
  const enabled = probe('SCENABLE', `$System.Status.GetErrorText(##class(${SC}).Enable("${NAMESPACE}"))`);
  assert.equal(enabled.value, '', `the probe's source-control class is enabled in ${NAMESPACE}: ${enabled.output}`);
  const asking = runIris(config.container, [`Do ##class(${SC}).Action("${NAMESPACE}",1)`, `Do ##class(${SC}).Clear("${NAMESPACE}")`, 'Write "OCU-SCASK-START:1:OCU-SCASK-END",!']);
  assert.equal(markerValue(asking, 'SCASK'), '1', `the probe asks its question and its log is empty: ${asking}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    browser = null;
    if (created && /-ci$/.test(config.container)) {
      // The source-control class goes first, so removing the probe class runs no hook.
      const disabled = probe('SCOFF', `$System.Status.GetErrorText(##class(${SC}).Disable("${NAMESPACE}"))`);
      const gone = probe('SCGONE', `$System.Status.IsOK(##class(${PROBE}).Remove("${NAMESPACE}"))`);
      const left = probe(
        'SCLEFT',
        `"["_##class(%Studio.SourceControl.Interface).SourceControlClassGet("${NAMESPACE}")_"|"_(''##class(%Dictionary.ClassDefinition).%ExistsId("OcuProbe2010.SourceControl"))_"|"_$Data(^["${NAMESPACE}"]OcuProbe2010SourceControl)_"|"_##class(${PROBE}).Exists("${NAMESPACE}","${DOCUMENT}")`
      );
      assert.equal(disabled.value, '', `the probe's source-control class is taken out of ${NAMESPACE}: ${disabled.output}`);
      assert.equal(gone.value, '1', `the probe class is removed: ${gone.output}`);
      assert.equal(left.value, '[|0|0|0', `${NAMESPACE} names no source-control class and holds neither the probe's class, its log nor the probe document: ${left.output}`);
    }
  }
});

/** Check the row whose name reads `name`. */
async function check(page, name) {
  const box = await page.evaluateHandle(
    (selector, wanted) =>
      Array.from(document.querySelectorAll(selector))
        .find((row) => (row.querySelector('[role="gridcell"] .ocu-data-table-link, [role="gridcell"] .ocu-data-table-text')?.textContent ?? '').trim() === wanted)
        ?.querySelector('.ocu-data-table-check') ?? null,
    ROW_SELECTOR,
    name
  );
  await box.click();
  await page.waitForFunction((element) => element.checked === true, { timeout: config.navigationTimeoutMs }, box);
}

/** Press the command bar's action labelled `label`, once it is offered. */
async function commandBar(page, label) {
  await page.waitForFunction(
    (wanted) => Array.from(document.querySelectorAll('.ocu-command-bar-action')).some((button) => button.textContent.trim() === wanted && button.getAttribute('aria-disabled') === null),
    { timeout: config.navigationTimeoutMs },
    label
  );
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('.ocu-command-bar-action')).find((button) => button.textContent.trim() === wanted).click();
  }, label);
}

test('AC5, AC9: deleting a probe class shows the source-control class\'s question, and Yes runs AfterUserAction as the signed-in person', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await page.click('input[data-ocu-criterion="pattern"]', { clickCount: 3 });
    await page.type('input[data-ocu-criterion="pattern"]', `${CLASS}*`);
    await page.click('.ocu-criteria-controls button[type="submit"]');
    await page.waitForFunction((selector, name) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, DOCUMENT);
    await check(page, DOCUMENT);
    await commandBar(page, STRINGS.actionDelete);
    await page.waitForSelector('app-typed-name-dialog .ocu-typed-name-field', { timeout: config.navigationTimeoutMs });
    await page.type('.ocu-typed-name-field', DOCUMENT);
    await page.click('app-typed-name-dialog .ocu-button-destructive');

    await page.waitForSelector('app-source-control-question-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    const dialog = await page.evaluate(() => {
      const root = document.querySelector('app-source-control-question-dialog');
      return {
        title: root.querySelector('.ocu-dialog-title').textContent.trim(),
        lead: root.querySelector('[data-ocu-source-control="lead"]').textContent.trim(),
        text: root.querySelector('[data-ocu-source-control="text"]').textContent,
        buttons: Array.from(root.querySelectorAll('.ocu-dialog-actions button')).map((button) => button.textContent.trim()),
      };
    });
    assert.deepEqual(dialog, {
      title: STRINGS.explorerSourceControlTitle.replace('<document>', DOCUMENT),
      lead: STRINGS.explorerSourceControlQuestionLead,
      text: QUESTION,
      buttons: [STRINGS.actionCancel, STRINGS.tableStatusNo, STRINGS.tableStatusYes],
    });
    assert.equal(await probe('SCHELD', `##class(${PROBE}).Exists("${NAMESPACE}","${DOCUMENT}")`).value, '0', 'the delete has run: the class is gone before the question is answered');

    await page.click('[data-ocu-source-control="yes"]');
    await page.waitForFunction(() => document.querySelector('app-source-control-question-dialog') === null, { timeout: config.navigationTimeoutMs });
    assert.deepEqual(
      posts.map((post) => `${post.action} ${post.id} ${JSON.stringify(post.values ?? null)}`),
      [`delete ${DOCUMENT} null`, `answer ${DOCUMENT} {"step":"2","answer":"1"}`],
      'one delete, then one answer for the document with the step the delete followed'
    );
    const answered = readEntries().filter((entry) => entry.hook === 'AfterUserAction');
    assert.deepEqual(
      answered.map((entry) => [entry.name.toUpperCase(), entry.extra, entry.user]),
      [[DOCUMENT.toUpperCase(), '1|2|1', config.username]],
      'AfterUserAction ran once, with the answer Yes, as the signed-in person'
    );
    const shown = await page.evaluate(() => document.body.innerText);
    assert.equal(shown.includes(QUESTION), false, "the class's question is on the dialog alone, not in the list once the dialog has closed");
  } finally {
    await context.close();
  }
});

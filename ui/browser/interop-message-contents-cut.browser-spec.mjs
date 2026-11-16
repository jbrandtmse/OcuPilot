/**
 * Story 24.3's DW-2433 in a real browser, against the throwaway instance: the Contents tab of a message says when the text was cut at
 * its overall cap of 1,000,000 characters, though the lines fit the row cap.
 *
 * What it pins: a stored message body of 250 lines of 4,000 characters (1,000,000 characters, the cap exactly) draws its whole text and no
 * cut note; one character more draws the text ending with the cut marker and the note under which it is drawn (`data-ocu-contents="cut"`,
 * the string `interopMessageContentsCut`); in both, the lines are far fewer than the row cap, so only the read's `truncated` flag can
 * tell the two apart.
 *
 * **It stores two message headers and bodies in `HSCUSTOM`** through `OcuPilot.Test.InteropMessageRead`'s `StoreHeader`, found by that
 * fixture's marker in their source and target, so it runs on a throwaway only; the `after` hook removes them with `RemoveAll` and checks
 * that none is left.
 *
 * Run: `npm run build`, `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> node --test --test-concurrency=1 browser/interop-message-contents-cut.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const FIXTURE = 'OcuPilot.Test.InteropMessageRead';
const NAMESPACE = 'HSCUSTOM';
const RUN = randomBytes(4).toString('hex');
const CAP = 1000000;
const LINE = 3999;
const LINES = CAP / (LINE + 1);
const CUT = ' ... [cut]';
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;
let created = false;
/** The header ids: a body of exactly the cap, then one character over it. */
let ids = [];

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec stores message headers and bodies, so it runs only in a throwaway; ${config.container} is not one`);
  created = true;
  const output = runIris(config.container, [
    `Do ##class(${FIXTURE}).RemoveAll()`,
    `Set line=$Translate($Justify("",${LINE})," ","x")_$Char(10)`,
    'Set exact=##class(%Stream.GlobalCharacter).%New()',
    `For i=1:1:${LINES} Do exact.Write(line)`,
    'Set sc=exact.%Save()',
    'Set over=##class(%Stream.GlobalCharacter).%New()',
    `For i=1:1:${LINES} Do over.Write(line)`,
    'Do over.Write("x")',
    'Set sc=sc&&over.%Save()',
    `Set a=##class(${FIXTURE}).StoreHeader("${RUN}","%Stream.GlobalCharacter",exact.%Id(),1,9,60,"")`,
    `Set b=##class(${FIXTURE}).StoreHeader("${RUN}","%Stream.GlobalCharacter",over.%Id(),1,9,60,"")`,
    'Write "OCU-CUTFIX-START:"_(+sc)_"|"_a_","_b_":OCU-CUTFIX-END",!',
  ]);
  const made = markerValue(output, 'CUTFIX') ?? '';
  assert.match(made, /^1\|[1-9]\d*,[1-9]\d*$/, `the two bodies and their headers are stored: ${output}`);
  ids = made.split('|')[1].split(',');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    browser = null;
    if (created && /-ci$/.test(config.container)) {
      const output = runIris(config.container, [
        `Do ##class(${FIXTURE}).RemoveAll()`,
        `Write "OCU-CUTGONE-START:"_##class(${FIXTURE}).LeftBehind()_":OCU-CUTGONE-END",!`,
      ]);
      assert.equal(markerValue(output, 'CUTGONE'), '0', `no fixture header is left: ${output}`);
    }
  }
});

/** Open a message's Contents tab and answer what it drew: the text's length and last line, and the cut note's text (`null` when none). */
async function contentsOf(id) {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/interoperability/messages/contents/${id}?ns=${NAMESPACE}`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector('app-interop-message-contents [data-ocu-contents="text"]', { timeout: config.navigationTimeoutMs });
    return await page.evaluate(() => {
      const text = document.querySelector('app-interop-message-contents [data-ocu-contents="text"]').textContent ?? '';
      const lines = text.split('\n');
      return {
        length: text.length,
        lineCount: lines.length,
        last: lines[lines.length - 1],
        note: document.querySelector('app-interop-message-contents [data-ocu-contents="cut"]')?.textContent?.trim() ?? null,
      };
    });
  } finally {
    await context.close();
  }
}

// DW-2433 (QA). Mutation (Rule 19): never set `pCut` in `OcuPilot.Port.InteropPort.ReadMessageContents`' cap cut, recompile the tree -> the
// one-over leg's note assertion goes red.
test('DW-2433: a text of exactly the cap draws whole with no cut note, and one character over draws ending the cut under the note', async () => {
  const exact = await contentsOf(ids[0]);
  assert.equal(exact.note, null, 'a body of exactly the cap is not noted as cut');
  assert.equal(exact.last.length, LINE, 'its last line is whole');
  assert.ok(!exact.last.endsWith(CUT), 'and does not end the cut');
  assert.equal(exact.lineCount, LINES, 'its lines are the 250 stored, well under the row cap');

  const over = await contentsOf(ids[1]);
  assert.equal(over.note, STRINGS.interopMessageContentsCut, 'a body one character over the cap is noted as cut, in the published sentence');
  assert.equal(over.last, CUT, 'and its last line is the cut marker alone');
  assert.equal(over.lineCount, LINES + 1, 'with its lines still far under the row cap');
});

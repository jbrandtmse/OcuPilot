/**
 * Story 5.13 end to end in a real browser against the throwaway instance: the user drills the
 * application error log to one namespace, the agent proposes clearing it, and the user confirms --
 * with the card's removal rows, its residue sentence, its destructive treatment and no Reverse
 * line, and the drill stepping up once the level it was standing on has gone.
 *
 * **It deletes real application errors.** It refuses outright to run outside a throwaway, it seeds
 * every error it removes through `OcuPilot.Test.ErrorDelete`'s own guarded helper, and its `after`
 * hook clears that namespace whatever happened above.
 *
 * **What only a browser can answer here:** that the card the shipped bundle draws carries the
 * published removal marker and the residue sentence rather than an empty after-value, and that the
 * drill-down -- which binds no `RefreshService` -- re-reads and steps up on the change event.
 * Everything about the write itself is `OcuPilot.Test.ErrorDelete`'s.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/error-log-delete.browser-spec.mjs`. A spec run against a bundle that was not rebuilt
 * reads the old client and proves nothing.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag as sharedForgetTag,
  markerValue,
  nextTag as sharedNextTag,
  requireFreeSlot,
  runIris as sharedRunIris,
  scriptReply as sharedScriptReply,
  setTag as sharedSetTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const probe = { container: config.container, marker: 'ERRORDELETE' };
const STRINGS = loadStrings();

const LOG_URL = '/ocupilot/logs/errors?ns=HSCUSTOM';

/** The namespace this spec seeds and clears -- `OcuPilot.Test.ErrorDelete`'s own. */
const TARGET_NAMESPACE = 'USER';

/** The delete tool's provider-side name: the canonical dotted name with underscores (AD-42). */
const DELETE_WIRE_NAME = 'logs_applicationerrors_delete';

const DRILL_ROW = '[role="grid"] .ocu-data-table-body [role="row"]';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec deletes application errors, so it never runs inside the live container'
  );
  // And never inside an owner-managed slot instance either, which `notEqual(LIVE_CONTAINER)` does
  // not exclude. Throwaways are the only containers whose names end `-ci`
  // (`scripts/ci-throwaway.sh`).
  assert.match(
    config.container,
    /-ci$/,
    `this spec deletes application errors on the instance, so it runs only in a throwaway; ${config.container} is not one`
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  // The definition ships read-only, and under read-only no proposal is minted at all (AD-30).
  allowWrites();
  dropProposals();
});

after(async () => {
  if (browser !== null) await browser.close();
  // The same test the `before` guard applies, in the same direction: a run refused there must not
  // have this hook delete errors in a container the spec never touched.
  if (!/-ci$/.test(config.container)) return;
  clearNamespace();
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  disarmProbeDefinition(probe, priorDefault);
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

const nextTag = () => sharedNextTag(probe);
const setTag = (tag) => sharedSetTag(probe, preparedId, tag);
const forgetTag = (tag) => sharedForgetTag(probe, tag);

function scriptReply(tag, hangSeconds, bodyExpr) {
  sharedScriptReply(probe, tag, hangSeconds, bodyExpr);
}

/** Clear the probe definition's read-only flag, so its write tool mints rather than refusing. */
function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-EDRW-START:"_$System.Status.IsOK(sc)_":OCU-EDRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'EDRW'), '1', `the probe definition allows writes: ${output}`);
}

/** Remove every proposal this spec's own principal has minted. */
function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-EDDROP-START:"_$System.Status.IsOK(sc)_":OCU-EDDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'EDDROP'), '1', `the probe proposals are removed: ${output}`);
}

/**
 * Seed one application error into the target namespace and answer how many that namespace then
 * holds, through `OcuPilot.Test.ErrorDelete`'s own guarded helpers -- called rather than copied, so
 * the browser leg and the instance suite seed one thing one way.
 */
function seedError() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ErrorDelete).Seed(.d,.n)`,
    `Set sc2=##class(OcuPilot.Test.ErrorDelete).Enumerate("${TARGET_NAMESPACE}",.r,.h,.f)`,
    `Write "OCU-EDSEED-START:"_$Select($System.Status.IsOK(sc)&&$IsObject($Get(r)):r.count,1:"")_":OCU-EDSEED-END",!`,
  ]);
  const count = markerValue(output, 'EDSEED') ?? '';
  assert.notEqual(count, '', `the spec seeds an application error it will remove: ${output}`);
  return Number(count);
}

/** How many application errors the target namespace holds now, or -1 when it holds none at all. */
function errorCount() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ErrorDelete).Enumerate("${TARGET_NAMESPACE}",.r,.h,.f)`,
    `Write "OCU-EDCOUNT-START:"_$Select($IsObject($Get(r)):r.count,1:-1)_":OCU-EDCOUNT-END",!`,
  ]);
  return Number(markerValue(output, 'EDCOUNT') ?? '-1');
}

/** Remove every application error the target namespace holds, whatever this run did. */
function clearNamespace() {
  runIris([
    `Do ##class(OcuPilot.Test.ErrorDelete).Clear()`,
    `Write "OCU-EDCLEAR-START:1:OCU-EDCLEAR-END",!`,
  ]);
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/** A `tool_use` reply proposing the delete of one namespace's application errors. */
function proposeReply(namespace) {
  const input = {
    namespace,
    rationale: 'The namespace holds only errors this run seeded.',
    expectedImpact: 'the application error log no longer lists them',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_delete", "name": "${DELETE_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

/** Drill from the namespaces level into the target namespace, through the page's own link. */
async function drillInto(page, namespace) {
  await page.waitForSelector(DRILL_ROW, { timeout: config.navigationTimeoutMs });
  const opened = await page.evaluate(
    (selector, wanted) => {
      const row = Array.from(document.querySelectorAll(selector)).find(
        (candidate) => (candidate.querySelector('[role="gridcell"]')?.textContent ?? '').trim() === wanted
      );
      if (row === undefined) return false;
      row.querySelector('.ocu-data-table-link')?.click();
      return true;
    },
    DRILL_ROW,
    namespace
  );
  assert.equal(opened, true, `the namespaces level lists ${namespace}`);
  await page.waitForFunction(
    (wanted) => (document.querySelector('[data-ocu-drill="scope"]')?.textContent ?? '').trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    namespace
  );
}

test("AC5, AC6: the card shows removals with no after-state and says what it leaves, and the drill steps up on the confirm", async () => {
  // Mutation (Rule 19): drop the `row.removed === true` branch from `proposal-card.ts` -> the
  // after cell reads `(none)` and the marker assertion goes red. Drop `applyDeleted`'s step-up
  // loop -> the drill stays on the dates level and the last assertion goes red.
  await requireFreeSlot(config);
  clearNamespace();
  const seeded = seedError();
  assert.ok(seeded > 0, 'the namespace holds the seeded error');

  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, proposeReply(TARGET_NAMESPACE));
  scriptReply(tag, 0, textReply('done'));
  const { context, page } = await signedInAt(browser, config, LOG_URL);
  try {
    await drillInto(page, TARGET_NAMESPACE);
    await page.waitForFunction(
      () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
      { timeout: config.navigationTimeoutMs }
    );
    await page.type('#ocu-panel-composer', `clear the application errors in ${TARGET_NAMESPACE}`);
    await page.click('.ocu-panel-send');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
      timeout: config.navigationTimeoutMs,
    });

    const card = await page.evaluate(() => ({
      destructive: document
        .querySelector('app-proposal-card .ocu-proposal-card')
        .classList.contains('ocu-proposal-card-destructive'),
      removals: document.querySelectorAll('.ocu-diff-row-removed').length,
      rows: document.querySelectorAll('.ocu-diff-row').length,
      marker: (
        document.querySelector('.ocu-diff-row-removed .ocu-diff-after .ocu-diff-value')?.textContent ?? ''
      ).trim(),
      markerHidden: document
        .querySelector('.ocu-diff-row-removed .ocu-diff-after .ocu-diff-value')
        ?.getAttribute('aria-hidden'),
      spoken: (
        document.querySelector('.ocu-diff-row-removed .ocu-diff-after .ocu-diff-direction')?.textContent ?? ''
      ).trim(),
      residue: (document.querySelector('.ocu-proposal-card-residue')?.textContent ?? '').trim(),
      reverse: document.querySelector('.ocu-proposal-card-reverse') !== null,
      unchanged: document.querySelector('.ocu-proposal-card-unchanged') !== null,
    }));
    assert.equal(card.destructive, true, 'the card draws the destructive treatment');
    assert.equal(card.removals, seeded, 'one removal row per enumerated error');
    assert.equal(card.rows, seeded, 'and every row on the card is one of them');
    assert.equal(card.marker, STRINGS.proposalDiffRemovedValue, 'the after cell is the published marker');
    assert.equal(card.markerHidden, 'true', 'drawn only, so it is not spoken beside the direction word');
    assert.equal(card.spoken, STRINGS.proposalDiffRemoved, 'and the spoken direction word is the published one');
    assert.equal(card.reverse, false, 'a delete carries no Reverse line');
    assert.equal(card.unchanged, false, 'and nothing is sent, so nothing is disclosed as unchanged');
    assert.equal(
      card.residue,
      STRINGS.proposalResidue.split('<n>').join(String(seeded)),
      'the residue sentence names how many rows the card lists'
    );

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
      timeout: config.navigationTimeoutMs,
    });

    // The drill was standing on the namespace's dates; the namespace now holds nothing, so that
    // level has gone and the drill walks back to the one the instance still serves (AD-14).
    await page.waitForFunction(
      () => (document.querySelector('[data-ocu-drill="scope"]')?.textContent ?? '').trim() === '',
      { timeout: config.navigationTimeoutMs }
    );
    assert.equal(errorCount(), -1, 'and the namespace records no application errors at all');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
    clearNamespace();
  }
});

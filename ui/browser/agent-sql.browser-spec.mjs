/**
 * The agent's guarded SQL in a real browser against the throwaway (Story 19.11): a scripted turn
 * proposes an UPDATE through `explorer.sqlquery.run`; the card shows the statement, its kind and tables
 * and the consequence sentence for a data change; Confirm runs it, the card reads the status line, and
 * the table holds the new value.
 *
 * The run's governance key defaults to disabled, so the spec enables it for this account's instance and
 * `after` puts the policy back. It creates one table, `OcuProbe1911.Granted`, in HSCUSTOM and drops it
 * before and after. It refuses to run in the live container or a slot instance before any docker call.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/agent-sql.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import { resetGovernancePolicy, resetRememberedState } from './preferences-reset.mjs';
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
const probe = { container: config.container, marker: 'AGENTSQL' };
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const GOVERNANCE_PATH = '/api/ocupilot/agent/governance';
const KEY = 'explorer.sqlquery.run';
const TOOL_WIRE_NAME = 'explorer_sqlquery_run';
const TABLE = 'OcuProbe1911.Granted';
const STATEMENT = `UPDATE ${TABLE} SET Name = ? WHERE Name = ?`;

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs a data change, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  allowWrites();
  dropProposals();
  rebuildTable();
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  dropTable();
  await resetGovernancePolicy();
  await resetRememberedState();
  disarmProbeDefinition(probe, priorDefault);
});

const runIris = (lines) => sharedRunIris(config.container, lines);
const nextTag = () => sharedNextTag(probe);
const setTag = (tag) => sharedSetTag(probe, preparedId, tag);
const forgetTag = (tag) => sharedForgetTag(probe, tag);
const scriptReply = (tag, bodyExpr) => sharedScriptReply(probe, tag, 0, bodyExpr, 200);

function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-AGENTSQLRW-START:"_$System.Status.IsOK(sc)_":OCU-AGENTSQLRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'AGENTSQLRW'), '1', `the probe definition allows writes: ${output}`);
}

function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Do ##class(%SQL.Statement).%ExecDirect(,"DELETE FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(Name) = '${KEY}'")`,
    `Write "OCU-AGENTSQLDROP-START:"_$System.Status.IsOK(sc)_":OCU-AGENTSQLDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'AGENTSQLDROP'), '1', `the probe proposals are removed: ${output}`);
}

/** Drop the probe table, then create it with one row, `Name` 'before'. */
function rebuildTable() {
  dropTable();
  const output = runIris([
    `Set rs=##class(%SQL.Statement).%ExecDirect(,"CREATE TABLE ${TABLE} (Name VARCHAR(40))") Set ok=(rs.%SQLCODE=0)`,
    `Set rs=##class(%SQL.Statement).%ExecDirect(,"INSERT INTO ${TABLE} (Name) VALUES ('before')") Set ok=ok&&(rs.%SQLCODE=0)`,
    `Write "OCU-AGENTSQLMK-START:"_ok_":OCU-AGENTSQLMK-END",!`,
  ]);
  assert.equal(markerValue(output, 'AGENTSQLMK'), '1', `the probe table exists: ${output}`);
}

function dropTable() {
  runIris([`Do ##class(%SQL.Statement).%ExecDirect(,"DROP TABLE ${TABLE} CASCADE")`]);
}

/** The table's one row's `Name`, or `''` when there is none. */
function storedName() {
  const output = runIris([
    `Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT Name FROM ${TABLE}") Set v="" If rs.%Next() Set v=rs.%GetData(1)`,
    `Write "OCU-AGENTSQLNAME-START:"_v_":OCU-AGENTSQLNAME-END",!`,
  ]);
  return markerValue(output, 'AGENTSQLNAME') ?? '';
}

/** Enable the run's governance key through its stored setting, over the same route the screen uses. */
async function enableKey() {
  const read = await fetch(`${config.origin}${GOVERNANCE_PATH}`, { headers: { Authorization: authHeader(config) } });
  const policy = await read.json();
  const settings = {};
  for (const row of policy.keys) settings[row.key] = row.setting;
  settings[KEY] = 'enabled';
  const answer = await fetch(`${config.origin}${GOVERNANCE_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(config), 'Content-Type': 'application/json' },
    body: JSON.stringify({ preset: '', settings, rowVersion: policy.rowVersion }),
  });
  assert.equal(answer.status, 200, `the key is enabled: ${await answer.text()}`);
}

function updateReply() {
  const input = {
    Target: 'sql',
    statement: STATEMENT,
    parameters: ['after', 'before'],
    maxRows: 10,
    rationale: 'The probe row is renamed.',
    expectedImpact: 'the row reads after',
    reverse: 'run the same statement the other way round',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_sql", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

test('a proposed UPDATE shows the statement, its kind and table and the data-change sentence, and Confirm runs it', async () => {
  // Mutation (Rule 19): drop the `sqlVisible` banner from the proposal card -> the sentence assertion goes red;
  // make `Consequence` answer the undeclared code for DML -> the sentence differs and this goes red.
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, updateReply());
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("renamed")`);
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  try {
    // Signing in puts the governance policy back to its default, so the key is enabled after it.
    await enableKey();
    await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), { timeout: config.navigationTimeoutMs });
    await page.type('#ocu-panel-composer', 'rename the probe row');
    await page.click('.ocu-panel-send');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', { timeout: config.navigationTimeoutMs });
    const card = await page.$eval('app-proposal-card', (node) => ({
      text: node.textContent.replace(/\s+/g, ' '),
      sentence: node.querySelector('[data-slot="consequence"]')?.textContent.replace(/\s+/g, ' ').trim() ?? '',
    }));
    const sentence = STRINGS.explorerSqlConfirmDml.replace('<tables>', 'OCUPROBE1911.GRANTED');
    assert.ok(card.sentence.includes(sentence), `the card states the data change and its table: ${card.sentence}`);
    assert.ok(card.text.includes(STATEMENT), `the card shows the statement: ${card.text}`);
    assert.equal(storedName(), 'before', 'nothing ran before Confirm');

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      (line) => document.querySelector('app-proposal-card')?.textContent.includes(line),
      { timeout: config.navigationTimeoutMs },
      STRINGS.explorerSqlRowsChanged.replace('<n>', '1')
    );
    assert.equal(storedName(), 'after', 'the confirmed statement changed the row');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

/**
 * The structural gate (Story 15.6, DW-1337): every screen the registry declares, walked by
 * `structural-walk.mjs` in light at 1280 and 720 px and in dark at 1280 px, against the baseline
 * taken once in `structural-baseline.json`. A ratchet: a violation outside the baseline fails, a
 * baseline entry the walk no longer finds is printed for removal and does not.
 *
 * Named so it sorts first under `npm run test:browser`, so CI walks the same fresh throwaway state
 * the baseline was taken on. Discovered by that script's glob; no roster names it.
 *
 * The liveness tests plant a violation of each invariant, and of each branch a detector takes, in a
 * walked page and assert the walk's own detector reports it, so a detector that stopped detecting
 * cannot hold the gate green.
 *
 * Run: `npm run build`, redeploy the bundle, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/a11y-structural-invariants.browser-spec.mjs`
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { signedInAt } from './panel-spec.mjs';
import {
  INVARIANTS,
  MIN_WIDTH_SOURCES,
  VIEWPORTS,
  assertThrowaway,
  compare,
  componentMinimums,
  declaredScreens,
  detectScreen,
  readBaseline,
  reportLines,
  staleInstruction,
  toggleThemeThroughMenu,
  walk,
} from './structural-walk.mjs';

const config = browserConfig();

let browser = null;
let result = null;

before(async () => {
  await assertThrowaway(config);
  browser = await puppeteer.launch(launchOptions(config));
  result = await walk(browser, config);
  for (const line of reportLines(result.report)) console.log(line);
});

after(async () => {
  if (browser === null) return;
  await browser.close();
  browser = null;
});

test('AC5: every built screen is walked or skipped, and no id-requiring screen is neither', () => {
  const { report } = result;
  const { built, notBuilt } = declaredScreens();
  assert.deepEqual(
    [...report.unresolved],
    [],
    `these screens need an id the walk could not resolve and are not in SKIP: ${[...report.unresolved].join(', ')}`
  );
  assert.equal(report.walked.size + report.skipped.size, built.length, 'every built screen is walked or skipped');
  assert.ok(
    reportLines(report)[0].includes(`${report.walked.size} walked, ${report.skipped.size} skipped, ${notBuilt.length} not built`),
    `the report counts walked, skipped and not built: ${reportLines(report)[0]}`
  );
  assert.ok(report.walked.size > 0, 'the walk reached at least one screen');
  assert.deepEqual([...report.unsettled], [], 'every visit settled before it was measured');
});

test('AC5: no violation outside the baseline', () => {
  const baseline = readBaseline();
  assert.ok(baseline !== null, 'ui/browser/structural-baseline.json exists');
  const { fresh } = compare(result.entries, baseline.entries);
  if (fresh.length > 0) {
    console.log('structural gate: violations outside the baseline, each as a ready-to-append baseline entry:');
    for (const entry of fresh) console.log(JSON.stringify(entry));
  }
  assert.deepEqual(
    fresh.map((entry) => `${entry.route} | ${entry.invariant} | ${entry.context} | ${entry.element} | ${entry.measured}`),
    [],
    'a violation outside the baseline: fix it, or append the printed entry and file its ledger item'
  );
});

test('AC5: stale baseline entries are reported by key and do not fail the gate', () => {
  const baseline = readBaseline();
  assert.ok(baseline !== null, 'ui/browser/structural-baseline.json exists');
  const { stale } = compare(result.entries, baseline.entries);
  for (const entry of stale) console.log(staleInstruction(entry));
  console.log(`structural gate: ${result.entries.length} entr(ies) found, ${baseline.entries.length} in the baseline, ${stale.length} stale`);
});

/**
 * A context at 1280 on Home, switched to `theme` through the account menu, with `plant` run in the
 * page, answering what the walk's detector finds there.
 */
async function detectPlanted(plant, theme = 'light', plantArgument = null) {
  const { context, page } = await signedInAt(browser, config, '/ocupilot/', VIEWPORTS.wide);
  try {
    if (theme === 'dark') await toggleThemeThroughMenu(page, { inflight: new Set(), last: 0 }, config.navigationTimeoutMs);
    await page.evaluate(plant, plantArgument);
    const found = await detectScreen(page, {
      route: '/',
      checks: INVARIANTS,
      viewport: VIEWPORTS.wide.width,
      theme,
      minimums: componentMinimums(),
    });
    return found.entries;
  } finally {
    await context.close();
  }
}

/** Whether `entries` carries `invariant` on an element whose key ends with `suffix`. */
function reported(entries, invariant, suffix) {
  return entries.some((entry) => entry.invariant === invariant && entry.element.endsWith(suffix));
}

test('detector liveness: an unlabelled input is reported under name', async () => {
  const entries = await detectPlanted(() => {
    const field = document.createElement('input');
    field.className = 'ocu-probe-unlabelled';
    document.querySelector('main').appendChild(field);
  });
  assert.ok(reported(entries, 'name', 'input.ocu-probe-unlabelled'), `reported: ${JSON.stringify(entries)}`);
});

test('detector liveness: a field left out of the accessibility tree is reported under name', async () => {
  const entries = await detectPlanted(() => {
    const wrapper = document.createElement('div');
    wrapper.setAttribute('aria-hidden', 'true');
    const field = document.createElement('input');
    field.className = 'ocu-probe-hidden-field';
    field.setAttribute('aria-label', 'probe');
    wrapper.appendChild(field);
    document.querySelector('main').appendChild(wrapper);
  });
  assert.ok(reported(entries, 'name', 'input.ocu-probe-hidden-field'), `reported: ${JSON.stringify(entries)}`);
});

test('detector liveness: a control under the floor, a class minimum and a token minimum is reported under min-width', async () => {
  const [classMinimum] = MIN_WIDTH_SOURCES.classes;
  const [tokenMinimum] = componentMinimums();
  const entries = await detectPlanted(
    (classes) => {
      for (const [className, width] of classes) {
        const button = document.createElement('button');
        button.className = `${className} ocu-probe-narrow`;
        button.setAttribute('aria-label', 'probe');
        button.style.cssText = `width: ${width}px; min-width: 0; max-width: none; height: 24px; padding: 0; border: 0;`;
        document.querySelector('main').appendChild(button);
      }
    },
    'light',
    [
      ['ocu-probe-floor', 10],
      [classMinimum.className, classMinimum.px - 10],
      [tokenMinimum.className, 20],
    ]
  );
  for (const className of ['ocu-probe-floor', classMinimum.className, tokenMinimum.className]) {
    assert.ok(
      entries.some((entry) => entry.invariant === 'min-width' && entry.element.includes(`.${className}`) && entry.element.includes('.ocu-probe-narrow')),
      `${className} is reported: ${JSON.stringify(entries)}`
    );
  }
});

test('detector liveness: a child 50px wider than its non-clipping parent is reported under overflow', async () => {
  const entries = await detectPlanted(() => {
    const parent = document.createElement('div');
    parent.className = 'ocu-probe-parent';
    parent.style.cssText = 'width: 100px; height: 8px; overflow: visible;';
    const child = document.createElement('div');
    child.className = 'ocu-probe-child';
    child.style.cssText = 'width: 150px; height: 4px;';
    parent.appendChild(child);
    document.querySelector('main').appendChild(parent);
  });
  assert.ok(reported(entries, 'overflow', 'div.ocu-probe-child'), `reported: ${JSON.stringify(entries)}`);
});

test('detector liveness: a document that scrolls horizontally is reported under overflow on the page', async () => {
  const entries = await detectPlanted(() => {
    const wide = document.createElement('div');
    wide.className = 'ocu-probe-page-wide';
    wide.style.cssText = 'width: 3000px; height: 4px;';
    document.body.appendChild(wide);
  });
  assert.ok(
    entries.some((entry) => entry.invariant === 'overflow' && entry.element.startsWith('page>') && entry.element.endsWith('div.ocu-probe-page-wide')),
    `reported: ${JSON.stringify(entries)}`
  );
});

test('detector liveness: #777 text on #888 is reported under contrast', async () => {
  const entries = await detectPlanted(() => {
    const text = document.createElement('p');
    text.className = 'ocu-probe-contrast';
    text.style.cssText = 'color: #777; background: #888; font-size: 13px;';
    text.textContent = 'probe';
    document.querySelector('main').appendChild(text);
  });
  assert.ok(reported(entries, 'contrast', 'p.ocu-probe-contrast'), `reported: ${JSON.stringify(entries)}`);
});

test('detector liveness: #222 text on the dark ground is reported under contrast in dark only', async () => {
  const plant = () => {
    const text = document.createElement('p');
    text.className = 'ocu-probe-dark-contrast';
    text.style.cssText = 'color: #222; font-size: 13px;';
    text.textContent = 'probe';
    document.querySelector('main').appendChild(text);
  };
  const dark = await detectPlanted(plant, 'dark');
  assert.ok(
    dark.some((entry) => entry.invariant === 'contrast' && entry.context === 'dark' && entry.element.endsWith('p.ocu-probe-dark-contrast')),
    `reported in dark: ${JSON.stringify(dark)}`
  );
  const light = await detectPlanted(plant);
  assert.ok(!reported(light, 'contrast', 'p.ocu-probe-dark-contrast'), 'and not in light, where the same text passes');
});

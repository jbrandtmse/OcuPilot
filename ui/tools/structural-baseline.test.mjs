// Pins the structural gate's comparison and the committed baseline (Story 15.6, DW-1337): a key
// outside the baseline fails, a baseline key the walk no longer finds is only reported, only the
// key takes part, equal keys collapse; and the committed file carries no dark-only contrast entry
// and records every owner-reported finding.
//
// Mutations (Rule 19): make `compare` read `measured` into the key -> the "only the key" row goes
// red. Delete the `ownerReported` DW-1388 record from the baseline -> the owner-reported row goes
// red naming it. Add a `contrast|dark` entry with no light twin -> the dark-only row goes red.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { readFileSync } from 'node:fs';

const { compare, collapse, componentMinimums, entryKey, readBaseline, staleInstruction, INVARIANTS, OVERFLOW_ALLOWANCES } = await import(
  new URL('../browser/structural-walk.mjs', import.meta.url).href
);

function entry(route, invariant, context, element, extra = {}) {
  const shaped = { route, invariant, context, element, ...extra };
  return { ...shaped, key: entryKey(shaped) };
}

test('a key is route, invariant, context and element joined by bars, in that order', () => {
  assert.equal(
    entryKey({ route: 'logs/alerts', invariant: 'overflow', context: '720', element: 'app-panel>aside.ocu-panel' }),
    'logs/alerts|overflow|720|app-panel>aside.ocu-panel'
  );
  assert.equal(entryKey({ route: '/', invariant: 'name', context: '', element: 'app-root>input' }), '/|name||app-root>input');
  assert.deepEqual(INVARIANTS, ['name', 'min-width', 'overflow', 'contrast']);
});

test('a found key the baseline does not hold is fresh, and fails', () => {
  const baseline = [entry('/', 'overflow', '720', 'app-a>div')];
  const found = [entry('/', 'overflow', '720', 'app-a>div'), entry('/', 'contrast', 'dark', 'app-b>p')];
  const { fresh, stale } = compare(found, baseline);
  assert.deepEqual(fresh.map((e) => e.key), ['/|contrast|dark|app-b>p']);
  assert.deepEqual(stale, []);
});

test('a baseline key the walk no longer finds is stale, is reported with a removal instruction, and is not fresh', () => {
  const baseline = [entry('/', 'overflow', '720', 'app-a>div'), entry('logs/audit', 'min-width', '1280', 'app-c>input')];
  const { fresh, stale } = compare([entry('/', 'overflow', '720', 'app-a>div')], baseline);
  assert.deepEqual(fresh, []);
  assert.deepEqual(stale.map((e) => e.key), ['logs/audit|min-width|1280|app-c>input']);
  assert.match(staleInstruction(stale[0]), /logs\/audit\|min-width\|1280\|app-c>input.*remove this entry/);
});

test('dw, tag, count and measured play no part in the comparison', () => {
  const baseline = [entry('/', 'overflow', '720', 'app-a>div', { dw: 'DW-1', tag: 'DW-1388', count: 3, measured: '22px' })];
  const found = [entry('/', 'overflow', '720', 'app-a>div', { dw: null, tag: null, count: 1, measured: '40px' })];
  assert.deepEqual(compare(found, baseline), { fresh: [], stale: [] });
});

test('equal keys collapse into one entry whose count is their sum', () => {
  const found = [
    entry('/', 'min-width', '1280', 'app-a>input', { measured: 'first' }),
    entry('/', 'min-width', '1280', 'app-a>input', { measured: 'second' }),
    entry('/', 'min-width', '720', 'app-a>input'),
  ];
  const collapsed = collapse(found);
  assert.equal(collapsed.length, 2);
  const wide = collapsed.find((e) => e.context === '1280');
  assert.equal(wide.count, 2);
  assert.equal(wide.measured, 'first');
  assert.equal(compare(found, []).fresh.length, 2, 'and a fresh report lists each key once');
});

// --- The committed baseline ----------------------------------------------------------------------

const baseline = readBaseline();

test('the baseline is committed, in the shape the gate reads', () => {
  assert.ok(baseline !== null, 'ui/browser/structural-baseline.json exists');
  assert.ok(Array.isArray(baseline.entries), 'with an entries array');
  assert.ok(Array.isArray(baseline.ownerReported), 'and an ownerReported array');
  for (const held of baseline.entries) {
    assert.equal(held.key, entryKey(held), `the stored key is the entry's own: ${held.key}`);
    assert.ok(INVARIANTS.includes(held.invariant), `a known invariant: ${held.key}`);
    assert.ok(held.dw === null || /^DW-\d+$/.test(held.dw), `dw is null until the lead files the entry, then its ledger id: ${held.key}`);
  }
  assert.equal(new Set(baseline.entries.map((held) => held.key)).size, baseline.entries.length, 'no key is held twice');
});

test('AC4: every dark contrast entry has a light twin on the same route and element -- a dark-only failure is never baselined', () => {
  const light = new Set(
    baseline.entries.filter((held) => held.invariant === 'contrast' && held.context === 'light').map((held) => `${held.route}|${held.element}`)
  );
  const darkOnly = baseline.entries
    .filter((held) => held.invariant === 'contrast' && held.context === 'dark')
    .filter((held) => !light.has(`${held.route}|${held.element}`))
    .map((held) => held.key);
  assert.deepEqual(darkOnly, []);
});

test('every owner-reported finding is recorded with what the walk found', () => {
  const tags = baseline.ownerReported.map((record) => record.tag);
  for (const tag of ['DW-1335', 'DW-1336', 'DW-1388']) {
    const record = baseline.ownerReported.find((candidate) => candidate.tag === tag);
    assert.ok(record, `ownerReported records ${tag}: ${JSON.stringify(tags)}`);
    assert.ok(typeof record.finding === 'string' && record.finding.length > 0, `with the walk's finding for ${tag}`);
  }
  for (const held of baseline.entries.filter((candidate) => candidate.tag !== null)) {
    assert.ok(tags.includes(held.tag), `an entry's tag names an owner-reported finding: ${held.key}`);
  }
});

test('the baseline holds no entry for a finding the component layer or the walk has since fixed', () => {
  const fixed = ['DW-1583', 'DW-1584', 'DW-1587'];
  const left = baseline.entries.filter((held) => fixed.includes(held.dw)).map((held) => held.key);
  assert.deepEqual(left, []);
});

test("the resize handle's overflow allowance is the hit area's own offset in the component layer", () => {
  const scss = readFileSync(new URL('../src/styles/_components.scss', import.meta.url), 'utf8');
  const rule = scss.match(/\n\.ocu-panel-resize-handle\s*\{([^}]*)\}/);
  assert.ok(rule !== null, 'the component layer declares .ocu-panel-resize-handle');
  const offset = rule[1].match(/\n\s*left:\s*-(\d+)px;/);
  assert.ok(offset !== null, `the handle is offset left by a px value: ${rule[1]}`);
  const allowance = OVERFLOW_ALLOWANCES.find((entry) => entry.className === 'ocu-panel-resize-handle');
  assert.ok(allowance !== undefined, `the walk declares the handle's allowance: ${JSON.stringify(OVERFLOW_ALLOWANCES)}`);
  assert.equal(allowance.px, Number(offset[1]), 'the allowance is exactly the offset, and no wider');
  for (const entry of OVERFLOW_ALLOWANCES) assert.ok(entry.source.length > 0, `each allowance names its source: ${entry.className}`);
});

test('the token-sized minimum widths are found in the shipped component layer', () => {
  const found = componentMinimums().map(({ className, token }) => `${className}:${token}`);
  assert.ok(found.includes('ocu-panel-send:panel-send-width'), `the send button's floor is its token: ${JSON.stringify(found)}`);
  assert.ok(found.some((entry) => entry.endsWith(':icon-button-size')), `and at least one icon button's: ${JSON.stringify(found)}`);
});

/**
 * DW-1774 (Story 18.7): no browser spec pins a side bar's listed entries to a literal list or a
 * literal count. Each one that asserts what a side bar lists compares against `sideBarLabels(<area>)`
 * from `ui/browser/side-bar-spec.mjs`, which derives the labels from the mirror, so a story that adds a
 * listed screen changes one derivation rather than every spec that happens to read the side bar.
 *
 * Five legs here, and the further legs under the second comment below:
 *
 * 1. **No count pin.** A spec that reads `.ocu-side-bar-label` asserts no `entries.length` or
 *    `labels.length` against a number literal, in either argument order.
 * 2. **No literal list.** In a spec that reads `.ocu-side-bar-label`, a value collected from that
 *    selector -- a variable assigned from a `$$eval` that reads it, the side-bar items' labels and
 *    verdicts included, or a member a side-bar helper maps from it, read whole or through `.map` or
 *    `.slice` -- is never compared with `deepEqual` or `deepStrictEqual` against a literal array.
 *    Every spec on `SIDE_BAR_SPECS` has a collector this leg recognises, so a collector it stops
 *    recognising is red.
 * 3. **The converted specs use the helper.** Each spec on `SIDE_BAR_SPECS` imports
 *    `./side-bar-spec.mjs` and calls `sideBarLabels(`, and the roster is exactly the specs that read
 *    the side bar and do.
 * 4. **No literal index.** A spec that reads `.ocu-side-bar-label` names no entry by a number in any
 *    spelling `literalIndexLines` knows (`bar.entries[12]`, `labels[4]`, `labels.at(3)`, an `indexOf`
 *    compared with a number); it asserts the entry through `assertDrawnAtDeclaredIndex`.
 * 5. **The index helper derives.** `assertDrawnAtDeclaredIndex` answers the declared index of a label
 *    and refuses a label the area does not declare and a drawn list that carries it elsewhere.
 *
 * Mutation (Rule 19): restore any one `entries.length, 19` pin, or a literal Security list, in one of
 * the specs, or a `entries.slice(0, 7)` compared with one -> leg 1 or leg 2 goes red naming the file
 * and line. Restore any one `bar.entries[12]` pin -> leg 4 ("no spec that reads the side bar names an
 * entry by a number in any spelling") goes red naming the file and line. Add one to the index
 * `assertDrawnAtDeclaredIndex` derives -> leg 5 goes red.
 */

import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const browserDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'browser');

/** The specs that assert a side bar's listed entries, each through `sideBarLabels`. */
const SIDE_BAR_SPECS = [
  'auth-options.browser-spec.mjs',
  'background-tasks.browser-spec.mjs',
  'dashboard-drill-downs.browser-spec.mjs',
  'definitions.browser-spec.mjs',
  'docdb-applications.browser-spec.mjs',
  'ecp-application-servers.browser-spec.mjs',
  'ecp-data-servers.browser-spec.mjs',
  'ecp-settings.browser-spec.mjs',
  'encryption-key-file.browser-spec.mjs',
  'encryption-keys.browser-spec.mjs',
  'interop-productions.browser-spec.mjs',
  'interop-usage.browser-spec.mjs',
  'journal-settings.browser-spec.mjs',
  'journals.browser-spec.mjs',
  'license-key.browser-spec.mjs',
  'license-servers.browser-spec.mjs',
  'license-usage.browser-spec.mjs',
  'local-databases.browser-spec.mjs',
  'mft-connections.browser-spec.mjs',
  'namespaces.browser-spec.mjs',
  'oauth.browser-spec.mjs',
  'permissions-effective.browser-spec.mjs',
  'permissions.browser-spec.mjs',
  'prometheus-metrics.browser-spec.mjs',
  'remote-databases.browser-spec.mjs',
  'routine-applications.browser-spec.mjs',
  'security.browser-spec.mjs',
  'ssl.browser-spec.mjs',
  'superservers.browser-spec.mjs',
  'system-explorer-docdb.browser-spec.mjs',
  'tasks.browser-spec.mjs',
  'web-sessions.browser-spec.mjs',
];

const SIDE_BAR_SELECTOR = 'ocu-side-bar-label';

/** An optional `.map(...)` projection or `.slice(...)` prefix between a collected name and the comparison's comma. */
const MAPPED = '(?:\\.(?:map|slice)\\(.{0,120}?\\))?';

/** Every browser spec, with its text. */
function specs() {
  return readdirSync(browserDir)
    .filter((name) => name.endsWith('.browser-spec.mjs'))
    .sort()
    .map((name) => ({ name, text: readFileSync(join(browserDir, name), 'utf8') }));
}

function lineAt(text, index) {
  return text.slice(0, index).split('\n').length;
}

/** The names a spec collects side-bar labels into: `$$eval` variables and mapped helper members. */
function collectedNames(text) {
  const variables = [...text.matchAll(/const (\w+) = await [\w.]+\.\$\$eval\([^;]{0,400}?ocu-side-bar-label/g)].map((found) => found[1]);
  const members = [...text.matchAll(/(\w+): Array\.from\([^)]*ocu-side-bar-label'\)\)\.map/g)].map((found) => found[1]);
  return { variables, members };
}

test('DW-1774: no spec that reads the side bar pins its entry count to a number', () => {
  const pins = [];
  for (const { name, text } of specs()) {
    if (!text.includes(SIDE_BAR_SELECTOR)) continue;
    for (const found of text.matchAll(/(?:entries|labels)\.length,\s*\d/g)) pins.push(`${name}:${lineAt(text, found.index)}`);
    for (const found of text.matchAll(/(?:equal|strictEqual)\(\s*\d+\s*,\s*[\w.]*(?:entries|labels)\.length/g)) pins.push(`${name}:${lineAt(text, found.index)}`);
  }
  assert.deepEqual(pins, [], `count pins on a side bar: ${pins.join(', ')}`);
});

test('DW-1774: no spec compares the side-bar labels it collected with a literal list', () => {
  const pins = [];
  for (const { name, text } of specs()) {
    if (!text.includes(SIDE_BAR_SELECTOR)) continue;
    const { variables, members } = collectedNames(text);
    for (const variable of variables) {
      for (const found of text.matchAll(new RegExp(`deep(?:Strict)?Equal\\(\\s*${variable}${MAPPED}\\s*,\\s*\\[`, 'g'))) pins.push(`${name}:${lineAt(text, found.index)}`);
    }
    for (const member of members) {
      for (const found of text.matchAll(new RegExp(`deep(?:Strict)?Equal\\(\\s*\\w+\\.${member}${MAPPED}\\s*,\\s*\\[`, 'g'))) pins.push(`${name}:${lineAt(text, found.index)}`);
    }
  }
  assert.deepEqual(pins, [], `literal side-bar lists: ${pins.join(', ')}`);
  // The floor under the leg above: every spec that asserts a side bar has a collector it recognises.
  const unrecognised = specs()
    .filter(({ name }) => SIDE_BAR_SPECS.includes(name))
    .filter(({ text }) => {
      const { variables, members } = collectedNames(text);
      return variables.length + members.length === 0;
    })
    .map(({ name }) => name);
  assert.deepEqual(unrecognised, [], `side-bar specs whose collectors are not recognised: ${unrecognised.join(', ')}`);
});

test('DW-1774: the specs that assert a side bar import the helper and derive its labels', () => {
  const using = specs()
    .filter(({ text }) => text.includes(SIDE_BAR_SELECTOR) && text.includes("from './side-bar-spec.mjs'") && text.includes('sideBarLabels('))
    .map(({ name }) => name);
  assert.deepEqual(using, SIDE_BAR_SPECS, 'the roster is exactly the specs that derive their side-bar labels');
});

test('DW-2202: assertDrawnAtDeclaredIndex derives the index and refuses a label drawn elsewhere or not declared', async () => {
  const { assertDrawnAtDeclaredIndex, sideBarLabels } = await import('../browser/side-bar-spec.mjs');
  const declared = sideBarLabels('security');
  assert.ok(declared.length > 3, 'the Security side bar lists entries to place');
  assert.equal(assertDrawnAtDeclaredIndex(declared, 'security', declared[3]), 3, 'the declared index is answered');
  assert.throws(() => assertDrawnAtDeclaredIndex(declared, 'security', 'No such entry'), /is declared in the security side bar/);
  assert.throws(() => assertDrawnAtDeclaredIndex(['Extra', ...declared], 'security', declared[3]), /is drawn at its declared index 3/);
  assert.throws(() => assertDrawnAtDeclaredIndex(declared.slice(1), 'security', declared[3]), /is drawn at its declared index 3/);
});

/*
 * The legs below hold the other half of DW-2202's acceptance: a screen inserted mid-list in any area's
 * side bar needs no edit in a spec that asserts an entry's place through `assertDrawnAtDeclaredIndex`.
 *
 * - **Every spelling of a literal index is refused**, not only `bar.entries[12]`: any variable the
 *   spec names its side bar, `labels.at(3)`, and a number compared with an `indexOf`.
 * - **Every call site names a label its area declares.** Only a browser run otherwise reads the area
 *   key and the label a call passes, so a wrong key or a screen moved to another area is caught here.
 * - **The mid-list insertion is simulated on the mirror itself**, at every slot of every area, and each
 *   shipped call site's label is found at its shifted index while the old literal index reads another
 *   entry.
 * - **`sideBarLabels` is held to an independent derivation**, and the helper is held against every
 *   way a drawn list can carry a label elsewhere.
 *
 * Mutation (Rule 19), each applied, observed red and reverted:
 * - `opened.entries[12]` (a side-bar variable other than `bar` or `sideBar`) in place of a helper call
 *   in a spec -> "no spec that reads the side bar names an entry by a number in any spelling" names
 *   the file and line.
 * - a call's area key changed to another area, or its label to one the area does not list -> "every
 *   assertDrawnAtDeclaredIndex call names an area and a label the mirror declares" names the file and line.
 * - `assertDrawnAtDeclaredIndex` reading a declared list it kept from its first call -> "a screen
 *   inserted at any slot of any area moves the declared and the drawn index together" goes red.
 * - `sideBarLabels` built from `builtScreensForArea` -> "sideBarLabels is the built, listed screens of
 *   an area in side-bar order" goes red.
 * - the helper tolerating a drawn list shorter than the index (`drawn[at] ?? label`) ->
 *   "assertDrawnAtDeclaredIndex refuses a label drawn anywhere but its declared index" goes red.
 */

const INDEX_CALL = '\\([^()]*(?:\\([^()]*\\))?[^()]*\\)';

/** The 1-based lines of `text` that name a side-bar entry by a number literal, in any spelling. */
function literalIndexLines(text) {
  const lists = new Set(['entries', 'labels', ...collectedNames(text).variables]);
  const lines = new Set();
  const note = (pattern) => {
    for (const found of text.matchAll(pattern)) lines.add(lineAt(text, found.index));
  };
  for (const list of lists) {
    note(new RegExp(`(?<![.\\w])${list}\\[\\d+\\]`, 'g'));
    note(new RegExp(`(?<![.\\w])${list}\\.at\\(\\d+\\)`, 'g'));
    note(new RegExp(`(?<![.\\w])${list}\\.indexOf${INDEX_CALL}\\s*,\\s*\\d`, 'g'));
    note(new RegExp(`equal\\(\\s*\\d+\\s*,\\s*${list}\\.indexOf`, 'g'));
  }
  for (const member of ['entries', 'labels']) {
    note(new RegExp(`\\b\\w+\\.${member}\\[\\d+\\]`, 'g'));
    note(new RegExp(`\\b\\w+\\.${member}\\.at\\(\\d+\\)`, 'g'));
    note(new RegExp(`\\b\\w+\\.${member}\\.indexOf${INDEX_CALL}\\s*,\\s*\\d`, 'g'));
    note(new RegExp(`equal\\(\\s*\\d+\\s*,\\s*\\w+\\.${member}\\.indexOf`, 'g'));
  }
  return [...lines].sort((a, b) => a - b);
}

test('DW-2202: the literal-index net finds every spelling of a positional pin and nothing else', () => {
  const pins = [
    'assert.equal(bar.entries[12], X);',
    'assert.equal(opened.entries[3], X);',
    'assert.equal(rail.entries[0], X);',
    'assert.equal(labels[4], X);',
    'assert.equal(labels.at(2), X);',
    'assert.equal(opened.entries.at(0), X);',
    'assert.equal(bar.entries.indexOf(X), 4);',
    'assert.equal(bar.entries.indexOf(STRINGS.x), 4);',
    'assert.equal(4, labels.indexOf(X));',
    "const ranks = await page.$$eval('.ocu-side-bar-item .ocu-side-bar-label', (nodes) => nodes.map((node) => node.textContent));\nassert.equal(ranks[5], X);",
  ];
  for (const pin of pins) assert.deepEqual(literalIndexLines(pin).length > 0, true, `found: ${pin}`);
  assert.deepEqual(literalIndexLines(pins[9]), [2], 'a collected variable is read by its own name, on the line that indexes it');
  const clean = [
    "assertDrawnAtDeclaredIndex(bar.entries, 'security', STRINGS.x);",
    "assert.deepEqual(bar.entries.slice(0, 7), sideBarLabels('os-management').slice(0, 7));",
    'const first = groups[0].labels[0];',
    'assert.equal(entries.length, declared.length);',
    'assert.equal(bar.entries.indexOf(STRINGS.x) >= 0, true);',
  ];
  for (const line of clean) assert.deepEqual(literalIndexLines(line), [], `not a pin: ${line}`);
});

test('DW-2202: no spec that reads the side bar names an entry by a number in any spelling', () => {
  const pins = [];
  for (const { name, text } of specs()) {
    if (!text.includes(SIDE_BAR_SELECTOR)) continue;
    for (const line of literalIndexLines(text)) pins.push(`${name}:${line}`);
  }
  assert.deepEqual(pins, [], `literal side-bar indexes: ${pins.join(', ')}`);
});

/** Every `assertDrawnAtDeclaredIndex(` call in the shipped specs as `{ name, line, area, labelKey }`; `unread` names the ones this cannot read. */
function drawnCalls() {
  const calls = [];
  const unread = [];
  const importers = [];
  for (const { name, text } of specs()) {
    if (/import\s*\{[^}]*\bassertDrawnAtDeclaredIndex\b[^}]*\}\s*from\s*'\.\/side-bar-spec\.mjs'/.test(text)) importers.push(name);
    for (const found of text.matchAll(/assertDrawnAtDeclaredIndex\(/g)) {
      const line = lineAt(text, found.index);
      const read = /^assertDrawnAtDeclaredIndex\(\s*[\w.]+\s*,\s*'([a-z-]+)'\s*,\s*STRINGS\.(\w+)\s*\)/.exec(text.slice(found.index));
      if (read === null) unread.push(`${name}:${line}`);
      else calls.push({ name, line, area: read[1], labelKey: read[2] });
    }
  }
  return { calls, unread, importers };
}

test('DW-2202: every assertDrawnAtDeclaredIndex call names an area and a label the mirror declares', async () => {
  const { sideBarLabels } = await import('../browser/side-bar-spec.mjs');
  const { STRINGS } = await import('../src/app/core/strings.ts');
  const { calls, unread, importers } = drawnCalls();
  assert.deepEqual(unread, [], `calls this test cannot read (a label other than STRINGS.<key>, or a drawn list that is not a plain name): ${unread.join(', ')}`);
  assert.ok(calls.length >= 20, `the scan found ${calls.length} call(s); the shipped specs make more than twenty`);
  assert.deepEqual([...new Set(calls.map((call) => call.name))].sort(), importers.sort(), 'a spec that imports the helper calls it, and one that calls it imports it');
  const refused = [];
  for (const { name, line, area, labelKey } of calls) {
    const label = STRINGS[labelKey];
    if (typeof label !== 'string' || !sideBarLabels(area).includes(label)) refused.push(`${name}:${line} (${area}, ${labelKey})`);
  }
  assert.deepEqual(refused, [], `calls whose label the area's side bar does not list: ${refused.join(', ')}`);
});

const INSERTED_KEY = 'qaInsertedScreenLabel';
const INSERTED_LABEL = 'Inserted entry';

/** Run `run` with one extra built, listed screen in `areaKey`, placed before the entry at index `slot` of its side bar. */
async function withInsertedScreen(areaKey, slot, run) {
  const { SCREENS } = await import('../src/app/core/screens.generated.ts');
  const { STRINGS } = await import('../src/app/core/strings.ts');
  const { listedScreensForArea } = await import('../src/app/core/navigation.ts');
  const listed = listedScreensForArea(areaKey);
  const before = slot === 0 ? 0 : listed[slot - 1].sideBarPosition;
  const after = slot >= listed.length ? before + 2 : listed[slot].sideBarPosition;
  const inserted = { ...listed[0], descriptor: 'OcuPilot.Screen.Descriptor.InsertedProbe', route: 'inserted/probe', labelKey: INSERTED_KEY, sideBarPosition: (before + after) / 2 };
  SCREENS.push(inserted);
  STRINGS[INSERTED_KEY] = INSERTED_LABEL;
  try {
    return await run();
  } finally {
    SCREENS.splice(SCREENS.indexOf(inserted), 1);
    delete STRINGS[INSERTED_KEY];
  }
}

test('DW-2202: a screen inserted at any slot of any area moves the declared and the drawn index together', async () => {
  const { assertDrawnAtDeclaredIndex, sideBarLabels } = await import('../browser/side-bar-spec.mjs');
  const { AREAS } = await import('../src/app/core/screens.generated.ts');
  const { calls } = drawnCalls();
  const areas = AREAS.map((area) => area.key).filter((key) => sideBarLabels(key).length > 1);
  for (const named of new Set(calls.map((call) => call.area))) assert.ok(areas.includes(named), `${named} is swept: a shipped call site names it`);
  assert.ok(areas.length >= 5, `${areas.length} areas list more than one entry`);
  for (const area of areas) {
    const original = sideBarLabels(area);
    assert.equal(new Set(original).size, original.length, `${area} lists no label twice, so a label has one index`);
    for (let slot = 0; slot <= original.length; slot += 1) {
      await withInsertedScreen(area, slot, () => {
        const drawn = sideBarLabels(area);
        assert.equal(drawn.length, original.length + 1, `${area} slot ${slot}: the inserted screen is listed`);
        assert.equal(drawn[slot], INSERTED_LABEL, `${area} slot ${slot}: it lands where it was placed`);
        original.forEach((label, index) => {
          const moved = index >= slot ? index + 1 : index;
          assert.equal(assertDrawnAtDeclaredIndex(drawn, area, label), moved, `${area} slot ${slot}: "${label}" is found where the declaration now puts it`);
          if (index >= slot) assert.notEqual(drawn[index], label, `${area} slot ${slot}: the literal index ${index} would now read another entry`);
        });
      });
    }
    assert.deepEqual(sideBarLabels(area), original, `${area}: the inserted screen is gone again`);
  }
});

test('DW-2202: sideBarLabels is the built, listed screens of an area in side-bar order', async () => {
  const { sideBarLabels } = await import('../browser/side-bar-spec.mjs');
  const { AREAS, SCREENS } = await import('../src/app/core/screens.generated.ts');
  const { STRINGS } = await import('../src/app/core/strings.ts');
  assert.ok(SCREENS.some((screen) => screen.built && screen.sideBarPosition === 0), 'the mirror holds routable screens the side bar does not list, so the exclusion has something to exclude');
  for (const { key } of AREAS) {
    const expected = SCREENS.filter((screen) => screen.area === key && screen.built && screen.sideBarPosition > 0)
      .sort((a, b) => a.sideBarPosition - b.sideBarPosition)
      .map((screen) => STRINGS[screen.labelKey]);
    assert.deepEqual(sideBarLabels(key), expected, `${key}: its listed screens, in position order`);
  }
});

test('DW-2202: assertDrawnAtDeclaredIndex refuses a label drawn anywhere but its declared index', async () => {
  const { assertDrawnAtDeclaredIndex, sideBarLabels } = await import('../browser/side-bar-spec.mjs');
  const area = 'os-management';
  const declared = sideBarLabels(area);
  assert.ok(declared.length > 4, 'the area lists enough entries to move one around');
  const refusal = (label, index) => (error) => error.message.includes(`"${label}"`) && error.message.includes(`declared index ${index}`) && error.message.includes(area);
  declared.forEach((label, index) => {
    assert.equal(assertDrawnAtDeclaredIndex(declared, area, label), index, `"${label}" is drawn where it is declared`);
    const neighbour = index + 1 < declared.length ? index + 1 : index - 1;
    const swapped = declared.slice();
    [swapped[index], swapped[neighbour]] = [swapped[neighbour], swapped[index]];
    assert.throws(() => assertDrawnAtDeclaredIndex(swapped, area, label), refusal(label, index), `"${label}" swapped with its neighbour`);
    assert.throws(() => assertDrawnAtDeclaredIndex(declared.slice(0, index), area, label), refusal(label, index), `"${label}" missing from a list that stops short of it`);
    assert.throws(() => assertDrawnAtDeclaredIndex([...declared.slice(0, index), 'Other', ...declared.slice(index)], area, label), refusal(label, index), `"${label}" pushed one place later`);
    assert.throws(() => assertDrawnAtDeclaredIndex([...declared.slice(0, index), ...declared.slice(index + 1)], area, label), refusal(label, index), `"${label}" left out of the list`);
  });
  assert.throws(() => assertDrawnAtDeclaredIndex([], area, declared[0]), /is drawn at its declared index 0/, 'nothing drawn');
  assert.throws(() => assertDrawnAtDeclaredIndex(declared, 'no-such-area', declared[0]), /is declared in the no-such-area side bar/, 'an area that lists nothing');
  assert.throws(() => assertDrawnAtDeclaredIndex(declared, 'security', declared[0]), /is declared in the security side bar/, 'a label another area lists');
});

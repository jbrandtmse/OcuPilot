/**
 * DW-1774 (Story 18.7): no browser spec pins a side bar's listed entries to a literal list or a
 * literal count. Each one that asserts what a side bar lists compares against `sideBarLabels(<area>)`
 * from `ui/browser/side-bar-spec.mjs`, which derives the labels from the mirror, so a story that adds a
 * listed screen changes one derivation rather than every spec that happens to read the side bar.
 *
 * Three legs, each over the files themselves:
 *
 * 1. **No count pin.** A spec that reads `.ocu-side-bar-label` asserts no `entries.length` or
 *    `labels.length` against a number literal, in either argument order.
 * 2. **No literal list.** In a spec that reads `.ocu-side-bar-label`, a value collected from that
 *    selector -- a variable assigned from a `$$eval` that reads it, the side-bar items' labels and
 *    verdicts included, or a member a side-bar helper maps from it, read whole or through `.map` -- is
 *    never compared with `deepEqual` or `deepStrictEqual` against a literal array. Every spec on
 *    `SIDE_BAR_SPECS` has a collector this leg recognises, so a collector it stops recognising is red.
 * 3. **The converted specs use the helper.** Each spec on `SIDE_BAR_SPECS` imports
 *    `./side-bar-spec.mjs` and calls `sideBarLabels(`, and the roster is exactly the specs that do.
 *
 * Mutation (Rule 19): restore any one `entries.length, 19` pin, or a literal Security list, in one of
 * the specs -> leg 1 or leg 2 goes red naming the file and line.
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
  'definitions.browser-spec.mjs',
  'docdb-applications.browser-spec.mjs',
  'ecp-application-servers.browser-spec.mjs',
  'ecp-data-servers.browser-spec.mjs',
  'ecp-settings.browser-spec.mjs',
  'encryption-key-file.browser-spec.mjs',
  'encryption-keys.browser-spec.mjs',
  'interop-productions.browser-spec.mjs',
  'journal-settings.browser-spec.mjs',
  'journals.browser-spec.mjs',
  'license-key.browser-spec.mjs',
  'license-servers.browser-spec.mjs',
  'license-usage.browser-spec.mjs',
  'mft-connections.browser-spec.mjs',
  'oauth.browser-spec.mjs',
  'permissions-effective.browser-spec.mjs',
  'permissions.browser-spec.mjs',
  'remote-databases.browser-spec.mjs',
  'security.browser-spec.mjs',
  'ssl.browser-spec.mjs',
  'superservers.browser-spec.mjs',
  'system-explorer-docdb.browser-spec.mjs',
  'tasks.browser-spec.mjs',
  'web-sessions.browser-spec.mjs',
];

const SIDE_BAR_SELECTOR = 'ocu-side-bar-label';

/** An optional `.map(...)` projection between a collected name and the comparison's comma. */
const MAPPED = '(?:\\.map\\(.{0,120}?\\))?';

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
    .filter(({ text }) => text.includes("from './side-bar-spec.mjs'") && text.includes('sideBarLabels('))
    .map(({ name }) => name);
  assert.deepEqual(using, SIDE_BAR_SPECS, 'the roster is exactly the specs that derive their side-bar labels');
});

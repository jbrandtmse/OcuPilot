import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * Pins `ui/src/app/testing/screen-declaration.ts` as the one place a test spells out a whole
 * `ScreenDeclaration`: the builder's fields are the mirror's fields, and no component spec or
 * tool test declares one by hand. A hand-built declaration is recognised by its tool-identifier
 * key, the field every complete declaration carries and no other test object does.
 */

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const srcDir = join(uiRoot, 'src');
const toolsDir = join(uiRoot, 'tools');
const builderPath = join(srcDir, 'app', 'testing', 'screen-declaration.ts');
const mirrorPath = join(srcDir, 'app', 'core', 'screens.generated.ts');

const { screenDeclaration } = await import(builderPath);

/** An object-literal key naming the tool identifier. */
const HAND_BUILT_RE = /\btoolIdentifier\s*:/;

function specFiles(dir) {
  const found = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) found.push(...specFiles(full));
    else if (entry.isFile() && entry.name.endsWith('.spec.ts')) found.push(full);
  }
  return found;
}

test('no component spec or tool test builds a ScreenDeclaration by hand', (t) => {
  const scanned = [
    ...specFiles(srcDir),
    ...readdirSync(toolsDir)
      .filter((name) => name.endsWith('.test.mjs'))
      .map((name) => join(toolsDir, name)),
  ];

  t.diagnostic(`screen-fixture: scanned ${scanned.length} file(s)`);
  assert.ok(scanned.length > 0, 'the scan covered at least one file, so a clean result is not a scan over nothing');

  const handBuilt = scanned
    .filter((path) => HAND_BUILT_RE.test(readFileSync(path, 'utf8')))
    .map((path) => relative(uiRoot, path));
  assert.deepEqual(
    handBuilt,
    [],
    `build these declarations with screenDeclaration() from src/app/testing/screen-declaration.ts: ${handBuilt.join(', ')}`
  );
});

test('the builder carries exactly the fields ScreenDeclaration declares, and applies overrides over them', () => {
  const mirror = readFileSync(mirrorPath, 'utf8');
  const block = /export interface ScreenDeclaration \{([\s\S]*?)\n\}/.exec(mirror);
  assert.ok(block, `${relative(uiRoot, mirrorPath)} declares ScreenDeclaration`);
  const fields = [...block[1].matchAll(/^\s*readonly (\w+)\??:/gm)].map((match) => match[1]);
  assert.ok(fields.length > 0, 'the interface declares fields');

  assert.deepEqual(Object.keys(screenDeclaration()).sort(), [...fields].sort());

  const overridden = screenDeclaration({ route: 'logs/messages', refreshes: true });
  assert.equal(overridden.route, 'logs/messages');
  assert.equal(overridden.refreshes, true);
  assert.deepEqual(Object.keys(overridden).sort(), [...fields].sort(), 'and an override adds no field');
});

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { readSources } from './screen-mirror.mjs';

// Story 23.12 (AD-5): `src/OcuPilot/Screen/Titles.cls` is generated from the descriptors' `labelKey`s and
// `ui/src/app/core/strings.ts`, and `node tools/screen-mirror.mjs --check` (prebuild, the pre-commit hook,
// CI `gates`) refuses a copy that no longer matches. These tests run the tool as a process over a copy of
// the sources, so the committed tree is never written and the exit status is what a gate sees.
//
// Mutation (Rule 19): drop the `Titles.cls` comparison from `--check` -> the stale-strings, edited and
// missing assertions go red. Skip writing `Titles.cls` in the regenerate path -> the regeneration assertion
// goes red.

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..');
const SOURCE_DIRS = ['Screen', 'Kernel', 'Port'];
const TOOL_FILES = ['screen-mirror.mjs', 'strings.mjs', 'credential-pattern.mjs'];
const CORE_FILES = ['strings.ts', 'screens.generated.ts'];

/**
 * Runs `run` over a temporary repository holding a copy of every source the generator reads and of the
 * generator itself. `run` receives the copy's `Titles.cls` and `strings.ts` paths and `mirror(...args)`,
 * which runs the copy's tool as a process.
 */
function inCopy(run) {
  // realpathSync: the run-me guard compares import.meta.url, which Node reports resolved.
  const root = realpathSync(mkdtempSync(join(tmpdir(), 'ocupilot-screen-titles-')));
  try {
    for (const dir of SOURCE_DIRS) {
      cpSync(join(repoRoot, 'src', 'OcuPilot', dir), join(root, 'src', 'OcuPilot', dir), { recursive: true });
    }
    const tools = join(root, 'ui', 'tools');
    const core = join(root, 'ui', 'src', 'app', 'core');
    mkdirSync(tools, { recursive: true });
    mkdirSync(core, { recursive: true });
    for (const name of TOOL_FILES) cpSync(join(here, name), join(tools, name));
    for (const name of CORE_FILES) cpSync(join(repoRoot, 'ui', 'src', 'app', 'core', name), join(core, name));
    const mirror = (...args) => spawnSync(process.execPath, [join(tools, 'screen-mirror.mjs'), ...args], { cwd: tools, encoding: 'utf8' });
    return run({ mirror, titlesPath: join(root, 'src', 'OcuPilot', 'Screen', 'Titles.cls'), stringsPath: join(core, 'strings.ts') });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

/** A descriptor's `labelKey`, and `strings.ts` text in which that key's string has ` changed` appended. */
function withChangedTitle(stringsText) {
  const { screens } = readSources();
  const key = screens[0].declaration.labelKey;
  const line = new RegExp(`^(\\s*${key}:\\s*')((?:[^'\\\\]|\\\\.)*)(',\\s*)$`, 'm');
  assert.match(stringsText, line, `strings.ts holds a line for ${key}`);
  return { key, text: stringsText.replace(line, '$1$2 changed$3') };
}

test('a copy of the committed sources passes --check, so the copy is faithful', () => {
  inCopy(({ mirror }) => {
    const run = mirror('--check');
    assert.equal(run.status, 0, `${run.stdout}${run.stderr}`);
    assert.match(run.stdout, /up to date; mirrored [1-9]\d* descriptor\(s\)/, 'and the run read descriptors');
  });
});

test('a title changed in strings.ts and not regenerated fails --check, naming Titles.cls', () => {
  inCopy(({ mirror, stringsPath }) => {
    const { text } = withChangedTitle(readFileSync(stringsPath, 'utf8'));
    writeFileSync(stringsPath, text);
    const run = mirror('--check');
    assert.equal(run.status, 1, `${run.stdout}${run.stderr}`);
    assert.match(run.stderr, /src\/OcuPilot\/Screen\/Titles\.cls is stale/, 'it names the generated class');
    assert.doesNotMatch(run.stderr, /checked-in mirror is stale/, 'and it is the titles check that refuses, not the mirror check');
  });
});

test('a Titles.cls edited by hand, or missing, fails --check', () => {
  inCopy(({ mirror, titlesPath }) => {
    const text = readFileSync(titlesPath, 'utf8');
    const edited = text.replace(/^("[A-Za-z0-9]+": ")/m, '$1edited ');
    assert.notEqual(edited, text, 'the edit changed the file');
    writeFileSync(titlesPath, edited);
    const run = mirror('--check');
    assert.equal(run.status, 1, `${run.stdout}${run.stderr}`);
    assert.match(run.stderr, /Titles\.cls is stale/, 'a hand edit is refused');
    rmSync(titlesPath);
    const missing = mirror('--check');
    assert.equal(missing.status, 1, `${missing.stdout}${missing.stderr}`);
    assert.match(missing.stderr, /Titles\.cls is stale/, 'a missing class is refused');
  });
});

test('regenerating writes Titles.cls from strings.ts, after which --check passes', () => {
  inCopy(({ mirror, titlesPath, stringsPath }) => {
    const committed = readFileSync(titlesPath, 'utf8');
    rmSync(titlesPath);
    const rebuilt = mirror();
    assert.equal(rebuilt.status, 0, `${rebuilt.stdout}${rebuilt.stderr}`);
    assert.equal(readFileSync(titlesPath, 'utf8'), committed, 'regenerating the committed sources writes the committed class, byte for byte');

    const { key, text } = withChangedTitle(readFileSync(stringsPath, 'utf8'));
    writeFileSync(stringsPath, text);
    const stale = mirror('--check');
    assert.equal(stale.status, 1, 'the changed title is stale until regenerated');
    const regenerated = mirror();
    assert.equal(regenerated.status, 0, `${regenerated.stdout}${regenerated.stderr}`);
    assert.match(readFileSync(titlesPath, 'utf8'), new RegExp(`"${key}": "[^"]* changed"`), `Titles.cls now holds the changed string for ${key}`);
    const clean = mirror('--check');
    assert.equal(clean.status, 0, `${clean.stdout}${clean.stderr}`);
  });
});

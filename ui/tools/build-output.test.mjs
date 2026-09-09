import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readdirSync, rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the AC that angular-json.test.mjs cannot reach: "the emitted bundle filenames
// carry content hashes." That sibling test only asserts the outputHashing:"all"
// config knob is set -- it would stay green even if the build tool stopped honoring the
// knob. This test runs the real build and reads the real output directory, so a
// regression in the builder's own hashing behavior (not just the config value) goes red
// here. Mutation (Rule 19): set `outputHashing` to `"none"` in `ui/angular.json` and
// re-run `node --test tools/build-output.test.mjs` -- the filenames then read
// `main.js` / `styles.css` with no hash suffix and both assertions below fail.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const distBrowserDir = join(uiRoot, 'dist', 'ocupilot-ui', 'browser');

test('npm run build succeeds and emits content-hashed bundle filenames', () => {
  // Clean-room: remove any prior build output first, so this test cannot pass by
  // reading stale files left over from a differently-configured earlier build.
  rmSync(join(uiRoot, 'dist'), { recursive: true, force: true });

  // Capture the build's own output and surface it on failure. With a bare
  // execFileSync, a broken build reports only a non-zero exit code and the compiler
  // diagnostics -- the one thing that says what actually went wrong -- are discarded.
  try {
    execFileSync('npm', ['run', 'build'], { cwd: uiRoot, stdio: 'pipe' });
  } catch (err) {
    assert.fail(
      `npm run build failed (exit ${err.status}):\n${err.stdout ?? ''}\n${err.stderr ?? ''}`
    );
  }

  // The hash length and case are esbuild's current format, not part of the AC. Pinning
  // exactly 8 uppercase characters would turn a correct build red on a builder upgrade
  // that changed the format; the claim under test is only that a hash is present, and
  // the "no unhashed filename" assertion below carries the other half of it.
  const files = readdirSync(distBrowserDir);
  const jsBundles = files.filter((f) => /^main-[0-9A-Za-z]{6,}\.js$/.test(f));
  const cssBundles = files.filter((f) => /^styles-[0-9A-Za-z]{6,}\.css$/.test(f));

  assert.ok(
    jsBundles.length >= 1,
    `expected a content-hashed main-<HASH>.js bundle, got: ${JSON.stringify(files)}`
  );
  assert.ok(
    cssBundles.length >= 1,
    `expected a content-hashed styles-<HASH>.css bundle, got: ${JSON.stringify(files)}`
  );
  assert.ok(
    !files.includes('main.js') && !files.includes('styles.css'),
    'the unhashed filenames must not appear alongside the hashed ones'
  );
});

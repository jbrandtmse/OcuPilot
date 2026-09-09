import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readdirSync, readFileSync, rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { loadStrings } from './strings.mjs';

// Pins the ACs that reading source files cannot reach -- everything here is a
// property of the *shipped artifact*, observed after a real `npm run build`,
// never inspected from the introducing modules (Integration ACs, Rule 1):
//
// - angular-json.test.mjs only asserts the outputHashing:"all" config knob is
//   set; it would stay green even if the builder stopped honoring it. This
//   file runs the real build and reads the real output directory.
// - "Fonts reach the bundle": the emitted browser output must carry the five
//   vendored woff2 faces, and no fetch-causing reference in the emitted CSS or
//   index.html may name an external host.
// - "Integration (Rule 1)": the emitted JS bundle carries STRINGS.productName's
//   exact value, and the emitted CSS bundle carries the shell token
//   declaration.
//
// The build runs exactly once, at module scope, before any test() body --
// reusing the one build the suite already runs instead of adding a second
// (Task list), and letting each concern below be its own focused, flat test()
// (house style) rather than one large one.
//
// Mutations (Rule 19):
// - set `outputHashing` to `"none"` in `ui/angular.json` -> the hashing
//   assertions below fail (filenames read `main.js` / `styles.css`).
// - point one @font-face `src` at `https://fonts.gstatic.com/...` -> the
//   no-external-host assertion here goes red (typography.test.mjs's own
//   source-level check goes red too).
// - delete `ui/src/assets/fonts/`'s JetBrains Mono 600 file -> the
//   font-emission assertion goes red naming the absent face.
// - change app.ts to render a literal not present in the string source, or
//   delete the shell token declaration -> the Rule 1 integration assertions
//   go red, reporting which of the two the shipped bundle no longer carries.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const distDir = join(uiRoot, 'dist', 'ocupilot-ui');
const distBrowserDir = join(distDir, 'browser');
const distMediaDir = join(distBrowserDir, 'media');

// Clean-room: remove any prior build output first, so nothing below can pass
// by reading stale files left over from a differently-configured earlier
// build. Capture the build's own output so a failure surfaces the compiler
// diagnostics -- the one thing that says what actually went wrong -- rather
// than only a bare non-zero exit code.
rmSync(join(uiRoot, 'dist'), { recursive: true, force: true });
let buildError = null;
try {
  execFileSync('npm', ['run', 'build'], { cwd: uiRoot, stdio: 'pipe' });
} catch (err) {
  buildError = err;
}

function assertBuildSucceeded() {
  if (buildError) {
    assert.fail(
      `npm run build failed (exit ${buildError.status}):\n${buildError.stdout ?? ''}\n${buildError.stderr ?? ''}`
    );
  }
}

test('npm run build succeeds and emits content-hashed bundle filenames', () => {
  assertBuildSucceeded();

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

function jsBundlePath() {
  const files = readdirSync(distBrowserDir);
  const name = files.find((f) => /^main-[0-9A-Za-z]{6,}\.js$/.test(f));
  return name && join(distBrowserDir, name);
}

function cssBundlePath() {
  const files = readdirSync(distBrowserDir);
  const name = files.find((f) => /^styles-[0-9A-Za-z]{6,}\.css$/.test(f));
  return name && join(distBrowserDir, name);
}

test('the emitted browser output carries all five vendored woff2 faces', () => {
  assertBuildSucceeded();
  const mediaFiles = readdirSync(distMediaDir);
  const expectedBaseNames = [
    'Inter-Regular',
    'Inter-Medium',
    'Inter-SemiBold',
    'JetBrainsMono-Regular',
    'JetBrainsMono-SemiBold',
  ];
  for (const baseName of expectedBaseNames) {
    const found = mediaFiles.some((f) => new RegExp(`^${baseName}-[0-9A-Za-z]{6,}\\.woff2$`).test(f));
    assert.ok(found, `expected a hashed ${baseName}-<HASH>.woff2 in ${distMediaDir}, got: ${JSON.stringify(mediaFiles)}`);
  }
});

test('no fetch-causing reference in the emitted CSS or index.html names a host other than the instance\'s own origin', () => {
  assertBuildSucceeded();
  // Matches the story's own verification command. Deliberately scoped to
  // fetch-causing syntactic shapes, not every "https://" byte: Angular's own
  // runtime embeds angular.dev error URLs, extractLicenses emits
  // 3rdpartylicenses.txt, and the vendored OFL text carries the licence URL --
  // a blanket host scan would flag all three and prove nothing.
  const FETCH_CAUSING_RE =
    /url\(\s*['"]?https?:\/\/|@import[^;]*https?:\/\/|src=['"]https?:\/\/|<link[^>]+href=['"]https?:\/\//;

  const cssPath = cssBundlePath();
  assert.ok(cssPath, 'expected a hashed styles-<HASH>.css to inspect');
  const cssText = readFileSync(cssPath, 'utf8');
  assert.ok(!FETCH_CAUSING_RE.test(cssText), `found a fetch-causing external reference in ${cssPath}`);

  const indexHtmlText = readFileSync(join(distBrowserDir, 'index.html'), 'utf8');
  assert.ok(!FETCH_CAUSING_RE.test(indexHtmlText), 'found a fetch-causing external reference in index.html');
});

test('Integration (Rule 1): the emitted JS bundle carries STRINGS.productName\'s exact value', () => {
  assertBuildSucceeded();
  const jsPath = jsBundlePath();
  assert.ok(jsPath, 'expected a hashed main-<HASH>.js to inspect');
  const jsText = readFileSync(jsPath, 'utf8');
  const { productName } = loadStrings();
  assert.ok(
    jsText.includes(productName),
    `expected the emitted JS bundle to contain STRINGS.productName (${JSON.stringify(productName)})`
  );
});

test('Integration (Rule 1): the emitted CSS bundle carries the shell token declaration', () => {
  assertBuildSucceeded();
  const cssPath = cssBundlePath();
  assert.ok(cssPath, 'expected a hashed styles-<HASH>.css to inspect');
  const cssText = readFileSync(cssPath, 'utf8');
  assert.match(
    cssText,
    /--ocu-shell:\s*#0f3a5f/i,
    `expected the emitted CSS bundle to carry the --ocu-shell token declaration, checked ${cssPath}`
  );
});

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
// - stop app.ts consuming the string source at all (empty the template), or drop
//   the type-role class it applies, or rename that class's rule in
//   _typography.scss -> the Rule 1 assertions go red. (All three passed against
//   the earlier `jsText.includes(productName)` form: app.ts exposes the whole
//   STRINGS object, so every value ships whatever the template renders.)

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

// The build settings the Content-Security-Policy depends on, observed in the
// shipped artifact. `angular-json.test.mjs` pins the `inlineCritical` knob in the
// configuration; this pins what the builder actually emitted, and every one of
// these would ship silently broken: an inline <style> or an `onload=` attribute is
// refused by `style-src`/`script-src 'self'` and the page renders unstyled, and a
// missing nonce placeholder leaves the server nothing to substitute.
// The base href is here too, because it is a property of the emitted document: the
// shell is served under /ocupilot, so a root-relative asset reference would 404.
//
// Mutations (Rule 19):
// - set `inlineCritical` back to `true` in ui/angular.json's production
//   optimization block -> the inline-style and `onload=` assertions go red
//   (Angular emits an 18 kB inline <style> plus
//   `<link ... media="print" onload="this.media='all'">`).
// - delete the `ngCspNonce` attribute from ui/src/index.html -> the placeholder
//   assertion goes red.
test('the emitted index.html carries no inline script, no inline style, no onload handler, and the nonce placeholder', () => {
  assertBuildSucceeded();
  const html = readFileSync(join(distBrowserDir, 'index.html'), 'utf8');

  // A <script> with no src= is an inline script: its body is code the CSP would
  // have to admit with 'unsafe-inline' or a script nonce. Every script the build
  // emits must be a src= reference instead.
  const inlineScript = /<script(?![^>]*\bsrc=)[^>]*>/i.exec(html);
  assert.equal(inlineScript, null, `found an inline <script> in index.html: ${inlineScript?.[0]}`);

  const inlineStyle = /<style[\s>]/i.exec(html);
  assert.equal(inlineStyle, null, 'found an inline <style> in index.html -- inlineCritical must stay off');

  const onload = /\bonload\s*=/i.exec(html);
  assert.equal(onload, null, 'found an onload= attribute in index.html -- script-src \'self\' blocks it');

  assert.match(
    html,
    /ngcspnonce=["']OCUPILOTCSPNONCE["']/i,
    'expected the CSP nonce placeholder on <app-root>; OcuPilot.Api.StaticHandler substitutes it per response'
  );

  assert.match(
    html,
    /<base\s+href=["']\/ocupilot\/["']/i,
    'expected the emitted document to declare the non-root base href /ocupilot/ set at build time'
  );
});

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

// The consumer's identity is read out of app.ts rather than hardcoded, so these
// assertions track whatever `app.ts` actually renders instead of restating the
// spec. `app.ts` exposes the WHOLE `STRINGS` object to its template, so all 104
// values reach the bundle regardless of what is rendered -- asserting merely that
// productName's value appears therefore proves only that strings.ts was bundled,
// and stays green when the consumer stops rendering it (verified). What is unique
// to the rendered path is the compiled property access and the applied class.
function appTemplateBinding() {
  const appTs = readFileSync(join(uiRoot, 'src', 'app', 'app.ts'), 'utf8');
  const template = /template:\s*`([\s\S]*?)`/.exec(appTs);
  assert.ok(template, 'expected app.ts to declare an inline template');
  const key = /\{\{\s*STRINGS\.([A-Za-z_$][\w$]*)\s*\}\}/.exec(template[1]);
  assert.ok(key, `expected app.ts's template to interpolate a STRINGS key, got: ${template[1]}`);
  const cls = /class="([^"]*)"/.exec(template[1]);
  assert.ok(cls, `expected app.ts's template to apply a type-role class, got: ${template[1]}`);
  return { key: key[1], className: cls[1] };
}

test('Integration (Rule 1): the emitted JS bundle carries the STRINGS key app.ts actually renders', () => {
  assertBuildSucceeded();
  const jsPath = jsBundlePath();
  assert.ok(jsPath, 'expected a hashed main-<HASH>.js to inspect');
  const jsText = readFileSync(jsPath, 'utf8');
  const strings = loadStrings();
  const { key } = appTemplateBinding();

  // The compiled component reads the key by name -- that reference exists only
  // because app.ts renders it, unlike the value, which ships either way.
  assert.ok(
    new RegExp(`\\.${key}\\b`).test(jsText),
    `expected the emitted JS bundle to reference the rendered key .${key}; app.ts's consumer relationship is not observable in the artifact`
  );
  assert.ok(
    jsText.includes(strings[key]),
    `expected the emitted JS bundle to contain STRINGS.${key}'s value (${JSON.stringify(strings[key])})`
  );
});

test('Integration (Rule 1): the emitted CSS bundle carries the token layer and the type role app.ts applies', () => {
  assertBuildSucceeded();
  const cssPath = cssBundlePath();
  assert.ok(cssPath, 'expected a hashed styles-<HASH>.css to inspect');
  const cssText = readFileSync(cssPath, 'utf8');
  const { className } = appTemplateBinding();

  assert.match(
    cssText,
    /--ocu-shell:\s*#0f3a5f/i,
    `expected the emitted CSS bundle to carry the --ocu-shell token declaration, checked ${cssPath}`
  );
  // Anchored on a selector terminator, not `includes`: a bare substring test also
  // matches `.ocu-type-displayX`, so renaming the rule would leave this green.
  assert.match(
    cssText,
    new RegExp(`\\.${className}(?![\\w-])`),
    `expected the emitted CSS bundle to define .${className}, the type role app.ts applies -- checked ${cssPath}`
  );
});

// --- The composed stylesheet ------------------------------------------------------
//
// Every other stylesheet assertion in the suite reads a partial FROM DISK, so a
// partial that stops being `@use`d by src/styles.scss vanishes from the shipped
// artifact with the whole suite green (verified for both `styles/theme` and
// `styles/metrics`). These read the emitted bundle instead.
//
// Mutations (Rule 19): delete `@use 'styles/theme';` or `@use 'styles/metrics';`
// from ui/src/styles.scss -> the matching assertion below goes red.

test('the emitted CSS carries the Material bridge in both scopes, one re-point per Lantern-valued role', () => {
  assertBuildSucceeded();
  const cssText = readFileSync(cssBundlePath(), 'utf8');
  const themeScss = readFileSync(join(uiRoot, 'src', 'styles', '_theme.scss'), 'utf8');

  const authored = [...themeScss.matchAll(/--mat-sys-[\w-]+:\s*var\(--ocu-[\w-]+\)/g)].length;
  const emitted = [...cssText.matchAll(/--mat-sys-[\w-]+:\s*var\(--ocu-[\w-]+\)/g)].length;
  assert.ok(authored > 0, 'expected _theme.scss to re-point at least one --mat-sys-* role');
  assert.equal(emitted, authored, `expected every authored --mat-sys-* re-point to reach the bundle (${authored} authored, ${emitted} emitted)`);

  assert.match(cssText, /--mat-sys-primary:\s*var\(--ocu-primary\)/, 'expected the light --mat-sys-primary re-point in the emitted CSS');
  assert.match(cssText, /\.ocu-theme-dark\s*\{[^}]*--mat-sys-primary:\s*var\(--ocu-primary-dark\)/, 'expected the dark scope to re-point --mat-sys-primary at the dark token');

  // Every role Lantern does not value ships as `light-dark(<light>, <dark>)`
  // (mat.theme's `color-scheme` default). Without a declared color-scheme in each
  // scope those resolve to their light half in both modes, so the class flip
  // would be a no-op for them.
  assert.ok([...cssText.matchAll(/light-dark\(/g)].length > 0, 'expected Material to emit light-dark() roles');
  assert.match(cssText, /:root\s*\{[^}]*color-scheme:\s*light/, 'expected :root to declare color-scheme: light');
  assert.match(cssText, /\.ocu-theme-dark\s*\{[^}]*color-scheme:\s*dark/, 'expected the dark scope to declare color-scheme: dark');
});

test('the emitted CSS carries the metrics layer, including the reduced-motion override', () => {
  assertBuildSucceeded();
  const cssText = readFileSync(cssBundlePath(), 'utf8');
  assert.match(cssText, /--ocu-space-4:\s*16px/i, 'expected the 4px spacing scale to reach the bundle');
  assert.match(cssText, /--ocu-radius-md:\s*6px/i, 'expected the radii to reach the bundle');
  assert.match(cssText, /@media[^{]*prefers-reduced-motion/, 'expected the reduced-motion block to reach the bundle');
});

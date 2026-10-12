import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readdirSync, readFileSync, rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { loadStrings } from './strings.mjs';
import { harvestedNotices } from './licenses.mjs';
import { staticImportsOf } from './bundle-imports.mjs';

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
// - Story 20.29, pages load on demand: the emitted files split into the initial set (what a cold
//   open downloads before the sign-in card shows) and lazy chunks, and this file holds the
//   initial total under angular.json's warning, every lazy chunk under LAZYCHUNKMAX, every page
//   the outlet's loaders name in a lazy chunk and in no initial file, and every element
//   app.ts's template names in the initial set.
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
//   the first class it applies, or rename that class's rule in the global
//   stylesheet -> the Rule 1 assertions go red. (All three passed against
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

// --- The emitted file set: initial and lazy (Story 20.29) --------------------------------------
//
// The initial set is every file `index.html` names (script, stylesheet, modulepreload) plus
// everything those files reach through a static `import` or `export ... from` statement
// (`bundle-imports.mjs`, which the browser tier's cold-open check reads too). A dynamic
// `import(` is the lazy edge and is never followed. A lazy chunk is every other emitted `.js` or
// `.css` file, so the two sets cover the output exactly. Chunk names carry `-` and `_`.

const EMITTED_FILE_RE = /\.(js|css)$/;
const ENTRY_RE = /^(main|styles)-[0-9A-Za-z]{6,}\.(js|css)$/;
const CHUNK_RE = /^chunk-[0-9A-Za-z_-]+\.js$/;

let emittedSets = null;
function emittedFileSets() {
  if (emittedSets) return emittedSets;
  const emitted = readdirSync(distBrowserDir).filter((f) => EMITTED_FILE_RE.test(f));
  const unclassified = emitted.filter((f) => !ENTRY_RE.test(f) && !CHUNK_RE.test(f));
  assert.deepEqual(
    unclassified,
    [],
    `the build emitted JS/CSS this gate cannot classify: ${JSON.stringify(unclassified)} -- ` +
      'name the new file shape (an entry or a chunk) in build-output.test.mjs'
  );
  const html = readFileSync(join(distBrowserDir, 'index.html'), 'utf8');
  const initial = new Set();
  for (const re of [/<script\b[^>]*\bsrc=["']([^"']+)["']/gi, /<link\b[^>]*\bhref=["']([^"']+)["']/gi]) {
    for (const match of html.matchAll(re)) if (EMITTED_FILE_RE.test(match[1])) initial.add(match[1]);
  }
  const queue = [...initial].filter((f) => f.endsWith('.js'));
  while (queue.length > 0) {
    const file = queue.pop();
    assert.ok(emitted.includes(file), `${file} is reached from the initial set but the build did not emit it`);
    for (const imported of staticImportsOf(fileText(file))) {
      if (!initial.has(imported)) {
        initial.add(imported);
        queue.push(imported);
      }
    }
  }
  for (const file of initial) assert.ok(emitted.includes(file), `${file} is in the initial set but the build did not emit it`);
  const lazy = emitted.filter((f) => !initial.has(f));
  emittedSets = { initial: [...initial], lazy };
  return emittedSets;
}

const fileTexts = new Map();
function fileText(file) {
  if (!fileTexts.has(file)) fileTexts.set(file, readFileSync(join(distBrowserDir, file), 'utf8'));
  return fileTexts.get(file);
}

function fileBytes(file) {
  return readFileSync(join(distBrowserDir, file)).length;
}

function initialJsText() {
  return emittedFileSets()
    .initial.filter((f) => f.endsWith('.js'))
    .map(fileText)
    .join('\n');
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
// DW-217. The npm licence notices ship inside the served root, byte-equal to what the build
// extracted beside it followed by the notices of ported code under ui/licenses/ (Story 19.7).
// Mutation (Rule 19): delete the `postbuild` script from ui/package.json ->
// browser/3rdpartylicenses.txt is absent and this goes red.
test('the npm licence notices ship inside the served root, byte-equal to the extracted file and the ported code\'s notices (DW-217)', () => {
  assertBuildSucceeded();
  const extracted = readFileSync(join(distDir, '3rdpartylicenses.txt'));
  assert.ok(extracted.length > 0, 'the build extracted licence notices');
  let shipped;
  try {
    shipped = readFileSync(join(distBrowserDir, '3rdpartylicenses.txt'));
  } catch {
    assert.fail('dist/ocupilot-ui/browser/3rdpartylicenses.txt is absent, so neither FileCopy nor the start path ships the notices');
  }
  assert.ok(
    shipped.equals(Buffer.concat([extracted, Buffer.from(harvestedNotices(), 'utf8')])),
    'and the served copy is byte-equal to the extracted file followed by the ported code\'s notices'
  );
});

// AC2 (Story 4.6): the served licence notices are the artifact proof that the three vendored
// roles -- Markdown lexer, sanitizer, and highlighter (two packages) -- ship inside the bundle
// rather than being fetched from a CDN. Mutation (Rule 19): remove one package from
// `ui/package.json`'s `dependencies` (or otherwise keep the build from bundling it) -> the
// build's own `extractLicenses` step stops naming it and this goes red.
// The match is the extractor's own `Package: <name>` heading line, anchored. A bare substring
// search cannot fail for `marked`: the Apache-2.0 text `dompurify` ships (it is dual-licensed
// MPL-2.0 OR Apache-2.0) contains the phrase "conspicuously marked" twice, so `includes('marked')`
// stays green with `marked` unbundled -- the mutation this test records would not have reddened it.
test('the served licence notices name all four vendored reply-rendering packages (AC2)', () => {
  assertBuildSucceeded();
  const noticesPath = join(distBrowserDir, '3rdpartylicenses.txt');
  const notices = readFileSync(noticesPath, 'utf8');
  for (const name of ['marked', 'dompurify', 'lowlight', 'highlight.js']) {
    assert.ok(
      notices.split(/\r?\n/).includes(`Package: ${name}`),
      `expected ${noticesPath} to carry the line "Package: ${name}"`
    );
  }
});

// DW-371 (Story 4.6, AC9): the bundle-size gate. `angular-json.test.mjs` pins the budget
// literal; this file measures the ACTUAL emitted initial total -- the set `@angular/build`'s own
// `type: "initial"` budget sums, JS and CSS, raw bytes: the files `index.html` loads and everything
// they import statically -- against it, so a real regression fails here even if the configuration
// were left untouched. The lazy chunks are outside that total, and have a ceiling of their own.
//
// Mutation (Rule 19): lower `maximumWarning` in `ui/angular.json` by 1 kB below the measured
// total -> this goes red naming both the measured bytes and the (now exceeded) budget.
test('DW-371: the emitted initial total (JS + CSS) stays at or below angular.json\'s maximumWarning', () => {
  assertBuildSucceeded();
  const angularJson = JSON.parse(readFileSync(join(uiRoot, 'angular.json'), 'utf8'));
  const budgets = angularJson.projects['ocupilot-ui'].architect.build.configurations.production.budgets;
  const initialBudget = budgets.find((b) => b.type === 'initial');
  assert.ok(initialBudget, 'expected an initial budget in angular.json');
  // @angular/build's own BYTES_IN_KILOBYTE is 1000, not 1024 (verified against
  // node_modules/@angular/build/src/utils/bundle-calculator.js).
  const maximumWarningBytes = Number(String(initialBudget.maximumWarning).replace(/kB$/, '')) * 1000;

  const { initial } = emittedFileSets();
  assert.ok(
    initial.some((f) => /^main-/.test(f)) && initial.some((f) => /^styles-/.test(f)),
    `expected the initial set to hold a hashed main-*.js and styles-*.css, got: ${JSON.stringify(initial)}`
  );
  let totalBytes = 0;
  for (const file of initial) totalBytes += fileBytes(file);

  assert.ok(
    totalBytes <= maximumWarningBytes,
    `emitted initial total is ${totalBytes} bytes in ${initial.length} files, which exceeds angular.json's maximumWarning of ${maximumWarningBytes} bytes (${initialBudget.maximumWarning}) -- ` +
      'edit ui/angular.json\'s budget and ui/tools/angular-json.test.mjs\'s pinned literal together'
  );
});

// Story 20.29: the ceiling for any one lazy chunk. `type: "anyScript"` in angular.json would also
// bound `main` (about 800 kB), so it would hold no lazy chunk; this does. It is set the way
// `maximumWarning` is (DW-1166): the largest measured lazy chunk plus 5%, rounded up to the next
// kB, in the builder's units where a kB is 1,000 bytes. Raise it in the story that grows a page
// past it, with the measurement in that story's spec. Named limit: a small chunk can grow up to
// the ceiling unflagged.
const LAZYCHUNKMAX = 88 * 1000;

// Mutation (Rule 19): lower LAZYCHUNKMAX below the largest lazy chunk (the data browser page) ->
// this goes red naming that chunk, its bytes and the cap.
test('Story 20.29: every lazy chunk stays at or below LAZYCHUNKMAX', () => {
  assertBuildSucceeded();
  const { lazy } = emittedFileSets();
  assert.ok(lazy.length > 0, 'the build emitted no lazy chunk, so no page loads on demand');
  const over = lazy
    .map((file) => ({ file, bytes: fileBytes(file) }))
    .filter(({ bytes }) => bytes > LAZYCHUNKMAX)
    .map(({ file, bytes }) => `${file} is ${bytes} bytes`);
  assert.deepEqual(
    over,
    [],
    `a lazy chunk is over the per-chunk cap LAZYCHUNKMAX of ${LAZYCHUNKMAX} bytes -- raise the cap with the measurement in the story's spec, or split the page`
  );
});

// Story 20.29, AD-5: the loaders `screen-outlet.ts` names are the only way a page enters the
// bundle. Each loader's page component is defined in a lazy chunk and in no initial file, and every
// element `app.ts`'s template names (the shell chrome) is defined in the initial set. A component
// definition compiles to `selectors:[["<selector>"]]`; the builder writes the inner quotes as
// backticks, so any quote character is accepted.
function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function definesSelector(text, selector) {
  return new RegExp(`selectors:\\[\\[["'\`]${escapeRegExp(selector)}["'\`]`).test(text);
}

/** Every distinct `import('<specifier>').then((m) => m.<Class>)` loader in `screen-outlet.ts`, with its page's selector. */
function pageLoaders() {
  const shellDir = join(uiRoot, 'src', 'app', 'shell');
  const source = readFileSync(join(shellDir, 'screen-outlet.ts'), 'utf8');
  const loaders = new Map();
  for (const match of source.matchAll(/import\('([^']+)'\)\.then\(\(m\) => m\.(\w+)\)/g)) {
    loaders.set(`${match[1]}#${match[2]}`, { specifier: match[1], className: match[2] });
  }
  assert.ok(loaders.size > 80, `expected screen-outlet.ts to name its pages as loaders, found ${loaders.size}`);
  return [...loaders.values()].map(({ specifier, className }) => {
    const pageSource = readFileSync(join(shellDir, `${specifier}.ts`), 'utf8');
    const at = pageSource.indexOf(`export class ${className}`);
    assert.notEqual(at, -1, `${specifier}.ts does not export ${className}`);
    const selectors = [...pageSource.slice(0, at).matchAll(/selector:\s*(['"`])([^'"`]+)\1/g)];
    assert.ok(selectors.length > 0, `${className} in ${specifier}.ts declares no selector`);
    return { specifier, className, selector: selectors[selectors.length - 1][2] };
  });
}

/**
 * Every component selector declared by a page module: each `*.page.ts` under `src/app`, plus the
 * two shared pages in `shell/`. Read from the files, not from the loaders, so a page registered in
 * any other shape than the loader line, or imported statically by other code, is still held to the
 * rule.
 */
function pageModuleSelectors() {
  const appDir = join(uiRoot, 'src', 'app');
  const modules = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (/\.page\.ts$/.test(entry.name) || /[\\/]shell[\\/](list|detail)-page\.ts$/.test(path)) modules.push(path);
    }
  };
  walk(appDir);
  assert.ok(modules.length > 80, `expected the page modules under src/app, found ${modules.length}`);
  return modules.flatMap((path) =>
    [...readFileSync(path, 'utf8').matchAll(/selector:\s*(['"`])([^'"`]+)\1/g)].map((match) => ({ selector: match[2], module: path.slice(appDir.length + 1) }))
  );
}

// Mutation (Rule 19): import one page statically from eager code (for example `MacroLookupPage`
// in `shell/panel.ts`, used) -> this goes red naming `app-macro-lookup-page`. A loader written in
// another shape (`() => Promise.resolve(MacroLookupPage)` over a static import) is found through the
// page module itself, so it goes red too.
test('Story 20.29, AD-5: every page a loader names is defined in a lazy chunk and in no initial file', () => {
  assertBuildSucceeded();
  const { initial, lazy } = emittedFileSets();
  const initialJs = initial.filter((f) => f.endsWith('.js'));
  const lazyJs = lazy.filter((f) => f.endsWith('.js'));
  const eager = [];
  const missing = [];
  for (const { selector, module } of pageModuleSelectors()) {
    const inInitial = initialJs.filter((f) => definesSelector(fileText(f), selector));
    if (inInitial.length > 0) eager.push(`${selector} (${module}) is defined in the initial file ${inInitial.join(', ')}`);
  }
  for (const { specifier, className, selector } of pageLoaders()) {
    if (!lazyJs.some((f) => definesSelector(fileText(f), selector))) {
      missing.push(`${selector} (${className}, loaded from ${specifier})`);
    }
  }
  assert.deepEqual(eager, [], 'a page is bundled with the shell: no module of the initial set may import a page module statically');
  assert.deepEqual(missing, [], 'a page is defined in no lazy chunk, so its loader reaches nothing');
});

test('Story 20.29, AD-5: every element app.ts\'s template names is defined in the initial set', () => {
  assertBuildSucceeded();
  const appTs = readFileSync(join(uiRoot, 'src', 'app', 'app.ts'), 'utf8');
  const template = /template:\s*`([\s\S]*?)`/.exec(appTs);
  assert.ok(template, 'expected app.ts to declare an inline template');
  // Angular's own `ng-container`, `ng-template` and `ng-content` are template syntax, not components.
  const elements = [...new Set([...template[1].matchAll(/<([a-z][a-z0-9]*-[a-z0-9-]+)/g)].map((match) => match[1]))].filter(
    (name) => !name.startsWith('ng-')
  );
  assert.ok(elements.includes('app-rail') && elements.includes('router-outlet'), `expected the shell chrome in app.ts's template, got: ${JSON.stringify(elements)}`);
  const text = initialJsText();
  const absent = elements.filter((selector) => !definesSelector(text, selector));
  assert.deepEqual(absent, [], 'the shell chrome app.ts renders must ship with the shell, not load on demand');
});

// Story 2.4: the data table's browser harness ships nowhere. Its hooks and its probe declaration are
// absent from every file the production build emits.
test('no harness code reaches the shipped bundle', () => {
  assertBuildSucceeded();
  for (const name of readdirSync(distBrowserDir).filter((file) => /\.(js|html|css)$/.test(file))) {
    const text = readFileSync(join(distBrowserDir, name), 'utf8');
    for (const marker of ['ocuHarness', 'app-table-harness', 'OcuPilot.Screen.Descriptor.TableProbe']) {
      assert.ok(!text.includes(marker), `${name} carries ${marker}`);
    }
  }
});

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

// Story 1.6. The sign-in card's lockup is a CSS background rather than an <img src>,
// because a url() reference is what makes the application builder treat a file as a build
// input -- angular.json's `assets` array is empty and always has been. Nothing else pins
// that: deleting the rule, or moving the file, leaves every source-level test green and
// ships a card with a blank space where the wordmark belongs.
//
// Mutation (Rule 19): change the url() in ui/src/styles/_components.scss to a name that
// does not exist -> the build itself fails; point it at an <img> tag instead and drop the
// rule -> this goes red with no file emitted.
test('the sign-in lockup reaches the bundle as a hashed asset the emitted CSS references', () => {
  assertBuildSucceeded();
  const mediaFiles = readdirSync(distMediaDir);
  const lockup = mediaFiles.find((f) =>
    /^OcuPilot-Lockup-horizontal-[0-9A-Za-z]{6,}\.png$/.test(f)
  );
  assert.ok(
    lockup,
    `expected a hashed OcuPilot-Lockup-horizontal-<HASH>.png in ${distMediaDir}, got: ${JSON.stringify(mediaFiles)}`
  );
  assert.deepEqual(
    mediaFiles.filter((f) => /reversed/.test(f)),
    [],
    'nothing draws the reversed lockup (Story 15.10), so the bundle carries no copy of it'
  );

  const cssText = readFileSync(cssBundlePath(), 'utf8');
  assert.ok(
    cssText.includes(lockup),
    'the emitted stylesheet must reference the emitted lockup, not a path that no longer resolves'
  );
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
  assert.ok(cls, `expected app.ts's template to apply a class, got: ${template[1]}`);
  return { key: key[1], className: cls[1] };
}

test('Integration (Rule 1): the emitted JS bundle carries the STRINGS key app.ts actually renders', () => {
  assertBuildSucceeded();
  const jsText = initialJsText();
  assert.ok(jsText.length > 0, 'expected the initial set to hold JavaScript to inspect');
  const strings = loadStrings();
  const { key } = appTemplateBinding();

  // The compiled component reads the key by name -- that reference exists only
  // because app.ts renders it, unlike the value, which ships either way.
  assert.ok(
    new RegExp(`\\.${key}\\b`).test(jsText),
    `expected the emitted initial JS to reference the rendered key .${key}; app.ts's consumer relationship is not observable in the artifact`
  );
  assert.ok(
    jsText.includes(strings[key]),
    `expected the emitted initial JS to contain STRINGS.${key}'s value (${JSON.stringify(strings[key])})`
  );
});

test('Integration (Rule 1): the emitted CSS bundle carries the token layer and the class app.ts applies', () => {
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
    `expected the emitted CSS bundle to define .${className}, the class app.ts applies -- checked ${cssPath}`
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

  // Story 15.6: the scope re-points the bare roles the component layer reads, not only the
  // Material bridge -- and every authored re-point reaches the bundle.
  const bareAuthored = [...themeScss.matchAll(/--ocu-([\w-]+):\s*var\(--ocu-\1-dark\)/g)].length;
  const bareEmitted = [...cssText.matchAll(/--ocu-([\w-]+):\s*var\(--ocu-\1-dark\)/g)].length;
  assert.ok(bareAuthored > 0, 'expected _theme.scss to re-point the bare --ocu-* roles in its dark scope');
  assert.equal(bareEmitted, bareAuthored, `expected every authored --ocu-* re-point to reach the bundle (${bareAuthored} authored, ${bareEmitted} emitted)`);
  assert.match(cssText, /\.ocu-theme-dark\s*\{[^}]*--ocu-shell:\s*var\(--ocu-shell-dark\)/, 'expected the dark scope to re-point --ocu-shell');
  assert.match(cssText, /\.ocu-theme-dark\s*\{[^}]*--ocu-on-surface:\s*var\(--ocu-on-surface-dark\)/, 'expected the dark scope to re-point --ocu-on-surface');

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

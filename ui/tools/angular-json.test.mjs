import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the AC: "the only builder named is @angular/build:application and no
// @angular-devkit/build-angular or webpack builder string appears anywhere in the
// file" (AD-19/AD-20 — the webpack builders are deprecated in Angular 22).
const angularJsonPath = join(dirname(fileURLToPath(import.meta.url)), '..', 'angular.json');
const raw = readFileSync(angularJsonPath, 'utf8');
const parsed = JSON.parse(raw);

test('angular.json names only the @angular/build application builder', () => {
  const builders = [];
  for (const project of Object.values(parsed.projects ?? {})) {
    for (const target of Object.values(project.architect ?? {})) {
      builders.push(target.builder);
    }
  }
  assert.ok(builders.includes('@angular/build:application'), 'expected the application builder to be configured');
  for (const builder of builders) {
    assert.ok(builder.startsWith('@angular/build:'), `unexpected builder ${builder} \u2014 only @angular/build:* is permitted`);
  }
});

test('no @angular-devkit/build-angular or webpack builder string appears anywhere in the file', () => {
  assert.ok(!raw.includes('@angular-devkit/build-angular'), 'the deprecated webpack-based builder package must never be named');
  assert.ok(!/\bwebpack\b/i.test(raw), 'no webpack builder string may appear in angular.json');
});

test('outputHashing is "all" and set at the builder options level, so every configuration inherits it', () => {
  const build = parsed.projects['ocupilot-ui'].architect.build;
  assert.equal(build.options.outputHashing, 'all');
  for (const config of Object.values(build.configurations ?? {})) {
    assert.equal(config.outputHashing, undefined, 'outputHashing must not be re-declared per configuration \u2014 it belongs at options level so every configuration inherits it');
  }
});

// DW-38, the Epic 1 decision sheet. Both font families are vendored and redistributed, so each
// must travel with its licence (SIL OFL 1.1 section 2) -- and the whole mechanism is one `assets`
// entry copying the two OFL texts into the same `media/` directory the hashed faces land in.
// `ATTRIBUTIONS.md` states that as a fact about the shipped bundle; nothing asserted it, so
// deleting the entry left `npm test` and `npm run build` both green and the notices unshipped.
//
// Mutation (Rule 19): delete the assets entry, or change its `output`, and this goes red.
test('DW-38: the vendored fonts ship with their licences, beside the faces (ATTRIBUTIONS.md)', () => {
  const assets = parsed.projects['ocupilot-ui'].architect.build.options.assets ?? [];
  const ofl = assets.find((entry) => typeof entry === 'object' && /OFL/.test(entry.glob ?? ''));
  assert.ok(ofl, `an assets entry must copy the OFL texts into the bundle; found ${JSON.stringify(assets)}`);
  assert.equal(ofl.input, 'src/assets/fonts', 'from the directory the faces are vendored in');
  assert.equal(ofl.output, 'media', 'into the same directory the hashed woff2 faces land in');

  // And the licences the entry copies actually exist, one per family, so the glob is not a
  // pattern over nothing.
  const fontsDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'assets', 'fonts');
  const licences = readdirSync(fontsDir).filter((name) => name.endsWith('-OFL.txt'));
  const faces = readdirSync(fontsDir).filter((name) => name.endsWith('.woff2'));
  assert.ok(licences.length > 0, 'at least one OFL text is vendored');
  assert.ok(faces.length > 0, 'and at least one face it licenses');
  for (const face of faces) {
    const family = face.split('-')[0];
    assert.ok(
      licences.some((name) => name.startsWith(`${family}-`)),
      `the ${family} faces ship with no ${family}-OFL.txt beside them`
    );
  }
});

test('baseHref is /ocupilot/', () => {
  assert.equal(parsed.projects['ocupilot-ui'].architect.build.options.baseHref, '/ocupilot/');
});

// Story 1.5. Critical-CSS inlining emits an inline <style> and a
// `<link ... media="print" onload="this.media='all'">`, both of which the shell's
// Content-Security-Policy (`script-src 'self'`, `style-src 'self' 'nonce-...'`) refuses, so
// the page would render unstyled. build-output.test.mjs catches the emitted artifact; this
// catches the setting, because @angular/build's own schema defaults every key in the
// optimization object to true — a key merely dropped from the object turns inlining back on.
//
// Mutation (Rule 19): set inlineCritical to true, or delete the key, in ui/angular.json ->
// this goes red (and so does build-output.test.mjs's emitted-document assertion).
test('production optimization keeps critical-CSS inlining off, spelled out rather than omitted', () => {
  const production = parsed.projects['ocupilot-ui'].architect.build.configurations.production;
  assert.ok(production.optimization, 'the production configuration must state its optimization settings');
  assert.equal(
    production.optimization.styles?.inlineCritical,
    false,
    'inlineCritical must be explicitly false \u2014 an omitted key defaults to true and breaks the CSP'
  );
});

// Story 1.6. The dev loop runs THROUGH the IRIS origin (AD-28, AD-47).
//
// The operative reason is CORS, not SameSite. A dev server on its own origin would have to
// make cross-origin requests to the instance, and AD-47 refuses to create the allowance
// that would need — in development as well as production, which is why `HandleCorsRequest`
// is 0 on both dispatch classes. (`SameSite=Strict` bites too, but only when the dev host
// and the instance are different *sites*; `localhost:4200` and `localhost:52774` are the
// same site, so the cookie alone would have travelled.) A proxy makes both moot: to the
// browser there is one origin.
//
// Nothing else pins this: a `proxyConfig` key passes all five of the tests above, and so
// does its absence.
//
// Mutations (Rule 19):
// - delete the `serve.options` block from ui/angular.json -> the first assertion goes red.
// - point ui/proxy.conf.json at another port -> the origin assertion goes red.
// Story 1.9, DW-93. The component runner three stories deferred exists now, and the thing that
// makes it real is that `npm test` runs it -- a configured target nothing invokes is the same
// as no target. This is the one place that reads both the builder and the script, the shape
// `client-lint.test.mjs` uses for its own prebuild wiring.
//
// Mutations (Rule 19):
// - drop `&& ng test` from package.json's "test" script -> the wiring assertion goes red while
//   every rendered assertion in `src/**/*.spec.ts` stays green and unrun.
// - change the runner to "karma" -> the runner assertion goes red (and the suite would need a
//   browser launcher the contest floor does not carry).
test('DW-93: a component test target exists, runs vitest, and is what npm test invokes', () => {
  const target = parsed.projects['ocupilot-ui'].architect.test;
  assert.ok(target, 'the project must carry a test target');
  assert.equal(
    target.builder,
    '@angular/build:unit-test',
    'the only builder family this workspace permits is @angular/build:* (asserted above)'
  );
  assert.equal(target.options.runner, 'vitest');
  assert.equal(target.options.watch, false, 'a watching runner never exits, so it can never gate');
  assert.deepEqual(target.options.include, ['src/**/*.spec.ts']);
  assert.equal(target.options.tsConfig, 'tsconfig.spec.json');

  const packageJson = JSON.parse(
    readFileSync(join(dirname(fileURLToPath(import.meta.url)), '..', 'package.json'), 'utf8')
  );
  assert.match(
    packageJson.scripts.test,
    /node --test tools\/.*&&.*ng test/,
    `expected "test" to run the Node tool suite and then the component suite, got: ${JSON.stringify(packageJson.scripts.test)}`
  );
  assert.ok(
    packageJson.devDependencies.vitest,
    'the runner is a declared devDependency, not something a machine happens to have'
  );
  assert.ok(
    packageJson.devDependencies.jsdom,
    'and so is the DOM the builder renders into, which it refuses to run without'
  );
  assert.equal(
    packageJson.devDependencies['@types/jasmine'],
    undefined,
    'the vestigial jasmine types went with the scaffolding they came from'
  );
});

test('DW-93: at least one spec renders each of the surfaces this story ships', () => {
  const srcDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'src');
  for (const spec of [
    join(srcDir, 'app', 'shell', 'rail.spec.ts'),
    join(srcDir, 'app', 'shell', 'side-bar.spec.ts'),
    join(srcDir, 'app', 'shell', 'screen-outlet.spec.ts'),
    join(srcDir, 'app', 'shell', 'data-table.spec.ts'),
    join(srcDir, 'app', 'shell', 'list-page.spec.ts'),
    join(srcDir, 'app', 'app.routes.spec.ts'),
  ]) {
    assert.ok(existsSync(spec), `expected a component spec at ${spec}`);
  }
});

test('the dev server proxies /api/ocupilot through the IRIS origin, and the proxy file says so', () => {
  const serve = parsed.projects['ocupilot-ui'].architect.serve;
  assert.ok(serve.options, 'the serve target must carry an options block');
  assert.equal(
    serve.options.proxyConfig,
    'proxy.conf.json',
    'ng serve must name the proxy configuration, or the dev loop runs on its own origin'
  );

  const proxyPath = join(dirname(fileURLToPath(import.meta.url)), '..', 'proxy.conf.json');
  assert.ok(existsSync(proxyPath), `expected the proxy configuration at ${proxyPath}`);
  const proxy = JSON.parse(readFileSync(proxyPath, 'utf8'));

  const route = proxy['/api/ocupilot'];
  assert.ok(route, 'the API prefix must be proxied; every OcuPilot API path is absolute from it');
  assert.equal(
    route.target,
    'http://localhost:52774',
    "the target is this repository's own container, so the browser sees one origin"
  );
});

// --- The browser harness (Story 1.17, DW-159's harness half) ---------------------------------
//
// The component runner renders into jsdom, which has no layout engine: every
// `getBoundingClientRect()` it answers is zeros, so nothing in `src/**/*.spec.ts` can tell a
// rendered shell from an empty one. The browser harness is a SECOND runner, outside `ng`, and
// this is the file that holds the two apart -- the Angular targets stay exactly three, and the
// browser runner stays a dev dependency that reaches no shipped byte (NFR-10).
//
// Extended rather than relaxed, deliberately: the assertions above about the `test` target's
// runner, its include glob and its tsConfig are unchanged, and a harness that tried to satisfy
// itself by loosening one of them would go red there.
//
// Mutations (Rule 19):
// - drop `test:browser` from package.json -> the wiring assertion goes red while the spec file
//   stays on disk, unrun.
// - move `puppeteer` from devDependencies to dependencies -> the NFR-10 assertion goes red.
// - loosen its version to a caret range -> the exact-pin assertion goes red.
// - add a fourth Angular target for the browser run -> the three-target assertion goes red,
//   which is the point: the browser runner is not an `ng` target and must not become one.

test('DW-159: the browser harness is a second runner, not a fourth Angular target', () => {
  const targets = Object.keys(parsed.projects['ocupilot-ui'].architect);
  assert.deepEqual(
    targets.sort(),
    ['build', 'serve', 'test'],
    'angular.json still declares exactly three targets; the browser runner lives outside ng'
  );

  const packageJson = JSON.parse(
    readFileSync(join(dirname(fileURLToPath(import.meta.url)), '..', 'package.json'), 'utf8')
  );
  assert.match(
    packageJson.scripts['test:browser'],
    /node --test --test-concurrency=1 browser\//,
    'npm run test:browser runs the specs under ui/browser, one file at a time'
  );
  assert.ok(
    !packageJson.scripts.test.includes('test:browser'),
    'and `npm test` does not: the browser suite needs a running instance, and the gates job has none'
  );
});

test('DW-159: the browser runner is pinned exactly and is a dev dependency only (NFR-10)', () => {
  const packageJson = JSON.parse(
    readFileSync(join(dirname(fileURLToPath(import.meta.url)), '..', 'package.json'), 'utf8')
  );
  const pinned = packageJson.devDependencies.puppeteer;
  assert.ok(pinned, 'the headless-browser runner is a declared devDependency');
  assert.match(pinned, /^\d+\.\d+\.\d+$/, `expected an exact version, got ${JSON.stringify(pinned)}`);
  assert.equal(
    packageJson.dependencies.puppeteer,
    undefined,
    'and it is not a runtime dependency: nothing it pulls may reach the shipped bundle (NFR-10)'
  );
});

test('DW-159: every browser spec on disk is one the test:browser script actually runs', () => {
  // A spec the script does not match is a spec that never runs, and nothing else would say so.
  //
  // What makes a file a spec is that it registers tests, not what it is called: `browser/` also
  // holds shared modules the specs import (DW-267's `list-spec.mjs`), which are deliberately named
  // outside the glob so the runner does not open them as suites of their own. So the rule is over
  // the files that import `node:test`, and a module that registers nothing is held to the
  // converse -- it must stay outside the glob, or it would run as an empty suite.
  const browserDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'browser');
  const files = readdirSync(browserDir).filter((name) => name.endsWith('.mjs'));
  assert.ok(files.length >= 1, 'there is at least one file in browser/');
  let specs = 0;
  for (const file of files) {
    // Either quote style: nothing in this repository enforces one, and the direction this would
    // fail in is the direction the test exists to prevent -- a double-quoted import would read as
    // a non-spec, and a non-spec is then *required* to sit outside the glob, which it already does.
    const registersTests = /\bfrom\s+['"]node:test['"]/.test(readFileSync(join(browserDir, file), 'utf8'));
    if (registersTests) {
      specs += 1;
      assert.match(
        file,
        /\.browser-spec\.mjs$/,
        `${file} registers tests and does not match the pattern npm run test:browser runs, so it would never run`
      );
    } else {
      assert.doesNotMatch(
        file,
        /\.browser-spec\.mjs$/,
        `${file} matches the pattern npm run test:browser runs but registers no test, so it would run as an empty suite`
      );
    }
  }
  assert.ok(specs >= 1, 'and at least one of them is a spec');
});

test('DW-159: the browser spec drives the instance own origin, never a second one (AD-28, AD-47)', () => {
  const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
  const config = readFileSync(join(uiRoot, 'browser.config.mjs'), 'utf8');
  const specs = readdirSync(join(uiRoot, 'browser'))
    .filter((name) => name.endsWith('.browser-spec.mjs'))
    .map((name) => ({ name, text: readFileSync(join(uiRoot, 'browser', name), 'utf8') }));

  // Comments are stripped first: both files name 52774 in prose to explain why they must not
  // use it, and a check over the raw text would fail on files that are correct while leaving no
  // way to write the explanation. The same discipline client-lint.mjs applies to its own rules.
  const code = (text) =>
    text
      .replace(/\/\*[\s\S]*?\*\//g, '')
      .split('\n')
      .filter((line) => !/^\s*\/\//.test(line))
      .join('\n');

  // One origin, resolved in one place, and it is not the live container's published port.
  assert.match(config, /DEFAULT_ORIGIN = 'http:\/\/localhost:52776'/, 'the default origin is the throwaway, not 52774');
  assert.ok(!code(config).includes('52774'), 'the live container port is addressed nowhere in the harness config');
  for (const spec of specs) {
    assert.ok(!code(spec.text).includes('52774'), `nor in ${spec.name}`);
  }
  // A spec that runs commands inside a container reaches it by name, so the name is guarded the
  // way the port is: the default is the throwaway's, and the live one is refused before any command.
  assert.match(config, /DEFAULT_CONTAINER = 'ocupilot-ci'/, 'the default container is the throwaway');
  for (const spec of specs.filter((s) => /docker/.test(code(s.text)))) {
    assert.match(
      code(spec.text),
      /assert\.notEqual\(config\.container, LIVE_CONTAINER/,
      `${spec.name} runs docker commands, so it refuses the live container first`
    );
  }
  assert.ok(
    !/https?:\/\/(?!localhost)/.test(code(config)),
    'and no off-origin host is addressed at all'
  );
});

// Story 2.4: the data table's browser harness is a build configuration, not a target, and its output
// never lands where the shipped bundle does (AD-47, NFR-10).
//
// Mutation (Rule 19): point the harness configuration's `outputPath` at `dist/ocupilot-ui` -> this
// goes red.
test('the harness build configuration has its own entry, document, tsconfig and output path, never the shipped one', () => {
  const build = parsed.projects['ocupilot-ui'].architect.build;
  const harness = build.configurations.harness;
  assert.ok(harness, 'the build target carries a harness configuration');
  assert.equal(harness.browser, 'src/app/testing/table-harness/main.ts');
  assert.equal(harness.index, 'src/app/testing/table-harness/index.html');
  assert.equal(harness.tsConfig, 'tsconfig.harness.json');
  assert.equal(harness.outputPath, 'dist/table-harness');
  assert.notEqual(harness.outputPath, build.options.outputPath, 'the harness output path is not dist/ocupilot-ui');
  assert.ok(!String(harness.outputPath).startsWith(build.options.outputPath), 'nor inside it');
  assert.equal(build.options.browser, 'src/main.ts', 'the shipped entry is unchanged');
  assert.equal(build.defaultConfiguration, 'production', 'and a plain ng build never builds the harness');

  const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
  const app = JSON.parse(readFileSync(join(uiRoot, 'tsconfig.app.json'), 'utf8'));
  assert.deepEqual(app.files, ['src/main.ts'], 'the shipped compilation starts from src/main.ts alone');
  const packageJson = JSON.parse(readFileSync(join(uiRoot, 'package.json'), 'utf8'));
  assert.equal(packageJson.scripts['pretest:browser'], 'ng build --configuration production,harness');
  assert.ok(!packageJson.scripts.build.includes('harness'), 'npm run build does not build the harness');
});

// --- DW-371: the bundle-size budget is a deliberate, pinned figure -----------------------------
//
// Story 4.6 raised `maximumWarning` off the stock 500kB default to make room for three vendored
// libraries (`marked`, `dompurify`, `lowlight`+`highlight.js`).
//
// The figure is re-based under the owner's standing policy on DW-1166: at each epic close the
// warning is set about 5% above the measured initial total, and `maximumError`'s 4000kB is the
// hard stop. Story 8.5 set 1261kB against a measured 1,200,871 bytes (5.01% above), the X.509
// form page, store and actions having added 26,053, and a tight figure keeps each raise a reviewed
// diff rather than a silent drift. `build-output.test.mjs` measures
// the actual emitted bytes against this figure; this file pins the figure itself, so a later
// change to it is a reviewed diff here rather than a silent edit nothing else notices.
//
// Story 9.9 raised it to 1561kB, the measured 1,560,536-byte initial total rounded up to the next
// kB, under the orchestrator's 2dca0322 ruling (between 1551kB and the 1580kB stop line); DW-1166's
// re-base at epic close follows.
// Story 9.10 raised it to 1577kB, the measured 1,576,569-byte initial total rounded up to the next
// kB, under the same ruling and its spec gate (below the 1580kB stop line).
// Story 16.1 raised it to 1900kB against a measured 1,856,906 bytes: the policy's 5% (1950kB)
// would pass the orchestrator's 1900kB stop line for the build, so the warning sits on that line.
// Story 16.21 re-based it to 2004kB, 5% above a measured 1,908,082 bytes, under the 4000kB hard
// stop.
// Story 16.24 re-based it to 2107kB, 5% above a measured 2,006,491 bytes, under the 4000kB hard
// stop.
// Story 18.1, merged beside it, measured 2,005,146 bytes on its own and stays under that figure.
// Story 18.14 re-based it to 2217kB, 5% above a measured 2,110,488 bytes (the mapping form, the
// Namespaces list page and the copy dialog having passed 2107kB), under the 4000kB hard stop.
// Release 1.0.3's staging merge of Stories 16.7, 18.3 and 16.4 re-based it to 2346kB, 5% above a
// measured 2,234,284 bytes, under the 4000kB hard stop.
// Story 18.4, merged forward onto that figure with the disk operations, the Check integrity flow and
// the Integrity log, measured 2,275,176 bytes and stays under it.
// Story 16.13 raised it to 2350kB, the measured 2,349,256-byte initial total rounded up to the next
// kB (the service editor and its roles dialog), under the 4000kB hard stop; DW-1166's re-base at the
// epic close follows.
// Story 16.14 raised it to 2384kB, the measured 2,383,623-byte initial total rounded up to the next
// kB (the LDAP and Kerberos editor and its test dialog), under the 4000kB hard stop.
// Story 18.17's forward merge raised it to 2386kB, the measured 2,385,025-byte initial total rounded up
// to the next kB (Story 16.14's LDAP editor plus Story 18.17's New Namespace hand-off), under the 4000kB hard stop.
// Story 16.15 raised it to 2387kB, the measured 2,386,319-byte initial total rounded up to the next
// kB (the data-egress line and the model-unused note), under the 4000kB hard stop.
// Story 16.15's forward merge of Story 18.17 raised it to 2388kB, the measured 2,387,365-byte initial
// total rounded up to the next kB (both stories' additions together), under the 4000kB hard stop.
// Story 18.15 raised it to 2388kB, the measured 2,387,861-byte initial total rounded up to the next kB
// (the Namespaces list's Enable interoperability and its typed-name dialog), under the 4000kB hard stop.
// Story 18.15's forward merge of Stories 16.15 and 16.26 raised it to 2391kB, the measured 2,390,201-byte
// initial total rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.1 raised it to 2420kB, the measured 2,419,634-byte initial total rounded up to the next kB
// (System Explorer's two pages, their stores and its four descriptors' mirror), under the 4000kB hard stop.
// Story 19.2 raised it to 2433kB, the measured 2,432,268-byte initial total rounded up to the next kB
// (System Explorer's compile and delete: the write store, the compile dialog and the output pane), under
// the 4000kB hard stop.
// Story 19.13 raised it to 2447kB, the measured 2,446,524-byte initial total rounded up to the next kB
// (System Explorer's export and import: the two dialogs and the page's transfer state), under the
// 4000kB hard stop.
// Story 18.16 raised it to 2446kB, the measured 2,445,492-byte initial total rounded up to the next kB
// (the remote database form, its store and the two descriptors' mirror), under the 4000kB hard stop.
// Story 18.16's forward merge of Story 19.2 raised it to 2459kB, the measured 2,458,172-byte initial
// total rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.13's forward merge of Story 18.16 raised it to 2473kB, the measured 2,472,462-byte initial
// total rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.3 raised it to 2488kB, the measured 2,487,199-byte initial total rounded up to the next kB
// (the class and routine editors, their store and the two descriptors' mirror), under the 4000kB hard
// stop.
// Story 19.4 raised it to 2527kB, the measured 2,526,006-byte initial total rounded up to the next kB
// (Search, Compare and Macros, the line diff and the three descriptors' mirror), under the 4000kB
// hard stop.
// Story 18.5 raised it to 2480kB, the measured 2,479,753-byte initial total rounded up to the next kB
// (Journals' page, Journal file details' page and the three descriptors' mirror), under the 4000kB hard stop.
// Story 18.5's forward merge of Story 19.13 raised it to 2495kB, the measured 2,494,043-byte initial
// total rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 18.5's forward merge of Story 19.3 raised it to 2509kB, the measured 2,508,816-byte initial
// total rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.4's forward merge of Story 18.5 raised it to 2548kB, the measured 2,547,991-byte initial
// total rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.4's command-box ranking raised it to 2549kB, the measured 2,548,187-byte initial total
// rounded up to the next kB (the Screens group's rank and sort), under the 4000kB hard stop.
// Story 19.5 raised it to 2572kB, the measured 2,571,381-byte initial total rounded up to the next kB
// (the SQL catalog's nine descriptors' mirror, its strings and the parent-scoped tab strip), under the
// 4000kB hard stop.
// Story 18.18 raised it to 2532kB, the measured 2,531,807-byte initial total rounded up to the next kB
// (Journal settings' form, its store and the descriptor's mirror), under the 4000kB hard stop.
// Story 18.18's forward merge of Story 19.4 raised it to 2571kB, the measured 2,570,979-byte initial
// total rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 18.18's forward merge of Story 19.4's command-box ranking raised it to 2572kB, the measured
// 2,571,157-byte initial total rounded up to the next kB (both branches' additions together), under the
// 4000kB hard stop.
// Story 19.5's forward merge of Story 18.18 raised it to 2595kB, the measured 2,594,351-byte initial
// total rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 18.19 raised it to 2588kB, the measured 2,587,710-byte initial total rounded up to the next kB
// (Journal records' page, its record dialog and the descriptor's mirror), under the 4000kB hard stop.
// Story 18.19's forward merge of Story 19.5 raised it to 2611kB, the measured 2,610,856-byte initial
// total rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.14 raised it to 2621kB, the measured 2,620,708-byte initial total rounded up to the next kB
// (the nine further SQL catalog descriptors' mirror and their strings), under the 4000kB hard stop.
// Story 19.14's statistics note raised it to 2622kB, the measured 2,621,812-byte initial total rounded
// up to the next kB, under the 4000kB hard stop.
// Story 18.19's forward merge of Story 19.14 raised it to 2638kB, the measured 2,637,325-byte initial
// total rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 18.6 raised it to 2677kB, the measured 2,676,623-byte initial total rounded up to the next kB
// (License key's page and activate dialog, the license server form and its store, the print styles,
// the three descriptors' mirror and their strings), under the 4000kB hard stop.
// Story 19.14's statistics note, merged forward over Story 18.19, raised it to 2639kB, the measured 2,638,429-byte
// initial total rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.6 raised it to 2655kB, the measured 2,654,833-byte initial total rounded up to the next kB
// (SQL query's page, its store, its descriptor's mirror and its strings), under the 4000kB hard stop.
// Story 18.6's forward merge of Story 19.14's statistics note raised it to 2679kB, the measured
// 2,678,101-byte initial total rounded up to the next kB (both branches' additions together), under the
// 4000kB hard stop.
// Story 18.20 raised it to 2712kB, the measured 2,711,418-byte initial total rounded up to the next kB
// (ECP data servers' page, its Change status dialog, the data server form and its store, the two
// descriptors' mirror and their strings), under the 4000kB hard stop.
// Story 19.6's forward merge of Story 18.6 raised it to 2695kB, the measured 2,694,618-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 18.20's forward merge of Story 19.6 raised it to 2728kB, the measured 2,727,893-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.15 raised it to 2704kB, the measured 2,703,008-byte initial total rounded up to the next kB
// (SQL query's Run in background, its Background run section, the store's poll and its strings), under
// the 4000kB hard stop.
// Story 18.20's forward merge of Story 19.15 raised it to 2737kB, the measured 2,736,473-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 18.21 raised it to 2762kB, the measured 2,761,858-byte initial total rounded up to the next kB
// (ECP settings' page and store, the three descriptors' mirror and their strings), under the 4000kB hard
// stop.
// Story 19.7 raised it to 2746kB, the measured 2,745,839-byte initial total rounded up to the next kB
// (Data browser's page, its tree, grid and store, the pure model, its descriptor's mirror and its
// strings), under the 4000kB hard stop.
// Story 19.7's forward merge of Story 18.20 raised it to 2780kB, the measured 2,779,186-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 18.21's forward merge of Story 19.7 raised it to 2805kB, the measured 2,804,321-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.8 raised it to 2813kB, the measured 2,812,827-byte initial total rounded up to the next kB
// (Data browser's editors, staging and save, the cut-cell tooltip and their strings), under the 4000kB
// hard stop.
// Story 19.8's forward merge of Story 18.21 raised it to 2838kB, the measured 2,837,977-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.16 raised it to 2860kB, the measured 2,859,344-byte initial total rounded up to the next kB
// (Data browser's tabs, Download CSV, Go to row, the Keyboard shortcuts dialog and its chords, and their
// strings), under the 4000kB hard stop.
// Story 19.9 raised it to 2864kB, the measured 2,863,129-byte initial total rounded up to the next kB
// (the class viewer's Class reference frame, Download CSV's bare numbers and their strings), under the
// 4000kB hard stop.
// Story 18.7 raised it to 2851kB, the measured 2,850,010-byte initial total rounded up to the next kB
// (Encryption key files' page, its create form, their stores, the three descriptors' mirror and their
// strings), under the 4000kB hard stop.
// Story 18.7's forward merge of Story 19.8 raised it to 2884kB, the measured 2,883,699-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 18.7's dialog refusal descriptions raised it to 2885kB, the measured 2,884,479-byte initial total
// rounded up to the next kB, under the 4000kB hard stop.
// Story 18.7's forward merge of Story 19.16 raised it to 2906kB, the measured 2,905,872-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.9's forward merge of Story 18.7 raised it to 2910kB, the measured 2,909,916-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.17 raised it to 2921kB, the measured 2,920,111-byte initial total rounded up to the next kB
// (Document databases' page, its create dialog and store, the descriptor's mirror and their strings),
// under the 4000kB hard stop.
// Story 18.22 raised it to 2925kB, the measured 2,924,734-byte initial total rounded up to the next kB
// (Database encryption's and Data element encryption's page, its store, the two descriptors' mirror and
// their strings), under the 4000kB hard stop.
// Story 18.22's forward merge of Story 19.9 raised it to 2929kB, the measured 2,928,778-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.17's forward merge of Story 18.22 raised it to 2940kB, the measured 2,939,195-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.10 raised it to 2943kB, the measured 2,942,499-byte initial total rounded up to the next kB
// (SQL activity's descriptor mirror and its strings), under the 4000kB hard stop.
// Story 19.11 raised it to 2954kB, the measured 2,953,533-byte initial total rounded up to the next kB
// (the agent picker and the SQL answer reading), under the 4000kB hard stop.
// Story 18.23 raised it to 2962kB, the measured 2,961,623-byte initial total rounded up to the next kB
// (the encryption startup settings' page, its store, the descriptor's mirror and its strings), under the
// 4000kB hard stop.
// Story 18.23's forward merge of Story 19.17 raised it to 2973kB, the measured 2,972,031-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// The staging merge of Stories 18.23 and 19.10 raised it to 2976kB, the measured 2,975,335-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.11's forward merge of Story 18.23 raised it to 2987kB, the measured 2,986,760-byte initial total
// rounded up to the next kB (both branches' additions together), under the 4000kB hard stop.
// Story 19.18 raised it to 2992kB, the measured 2,991,592-byte initial total rounded up to the next kB
// (the criteria hints' descriptor mirror and the singular count strings), under the 4000kB hard stop.
// Story 23.4 raised it to 2993kB, the measured 2,992,692-byte initial total rounded up to the next kB
// (the origin-scoped preference faults, the change event's tool and the task card's name), under the 4000kB hard stop.
// Story 18.24 raised it to 3012kB, the measured 3,011,503-byte initial total rounded up to the next kB
// (the wallet key form's type choice, key fields and replace section, and its published strings), under the
// 4000kB hard stop (DW-1166).
// Story 20.1 raised it to 3165kB, 5% above a measured 3,013,646 bytes (namespace category gating), under the 4000kB hard stop.
//
// Mutations (Rule 19):
// - loosen `maximumWarning` to a much larger, unmeasured figure (e.g. "3MB") -> the
//   "no other initial budget exists" and "warning under error" assertions still pass, but this
//   test's own exact-string assertion goes red, which is the point: any edit to the literal is
//   visible here.
// - add a second `budgets` entry -> the "exactly one budget" assertion goes red.
test('DW-371: exactly one initial budget, maximumWarning under maximumError, and the literal is pinned', () => {
  const budgets = parsed.projects['ocupilot-ui'].architect.build.configurations.production.budgets;
  assert.equal(budgets.length, 1, 'expected exactly one budget entry');
  const [budget] = budgets;
  assert.equal(budget.type, 'initial');
  assert.equal(budget.maximumWarning, '3165kB', 'Story 20.1: 5% above the measured 3,013,646 bytes, under the 4000kB hard stop; a change to this figure must be a reviewed diff, not a silent edit');
  assert.equal(budget.maximumError, '4000kB');

  // Both budgets are written in the units `@angular/build` prints, where a kB is 1000 bytes and
  // an MB is 1000 kB. The error budget moved from `1MB` to `1600kB` when Epic 4 and Epic 6's
  // clients merged, and to `2000kB` for Release 1 and `4000kB` for the voting week by the owner's decisions on DW-1166, so the parser reads either unit rather than one each.
  const parseSize = (value) => {
    const text = String(value);
    if (text.endsWith('MB')) return Number(text.replace(/MB$/, '')) * 1000 * 1000;
    return Number(text.replace(/kB$/, '')) * 1000;
  };
  assert.ok(parseSize(budget.maximumWarning) < parseSize(budget.maximumError), 'maximumWarning must stay under maximumError');
});

// DW-215 precedent: every declared dependency is an exact `x.y.z`, `save-exact=true` in `.npmrc`
// notwithstanding -- a caret or tilde range is a version nobody reviewed landing on the next
// `npm install`. `highlight.js` carries the extra constraint `lowlight` (a runtime dependency,
// not a devDependency the build could freely diverge from) declares in its own `package.json`:
// `~11.11.0`, i.e. 11.11.x and nothing else.
//
// Mutations (Rule 19):
// - loosen any dependency to a caret range -> the exact-pin assertion goes red naming it.
// - bump `highlight.js` to 11.12.0 -> the lowlight-range assertion goes red.
test('DW-215: every dependency and devDependency is pinned to an exact x.y.z, and highlight.js stays inside lowlight\'s declared range', () => {
  const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
  const packageJson = JSON.parse(readFileSync(join(uiRoot, 'package.json'), 'utf8'));
  const EXACT_VERSION_RE = /^\d+\.\d+\.\d+$/;
  for (const section of ['dependencies', 'devDependencies']) {
    for (const [name, version] of Object.entries(packageJson[section] ?? {})) {
      assert.match(version, EXACT_VERSION_RE, `${section}.${name} must be an exact version, got ${JSON.stringify(version)}`);
    }
  }

  const lowlightPackageJson = JSON.parse(readFileSync(join(uiRoot, 'node_modules', 'lowlight', 'package.json'), 'utf8'));
  const declaredRange = lowlightPackageJson.dependencies['highlight.js'];
  assert.equal(declaredRange, '~11.11.0', 'lowlight\'s own declared range for highlight.js, read from the installed package');
  const pinned = packageJson.dependencies['highlight.js'];
  const [major, minor] = pinned.split('.').map(Number);
  assert.equal(major, 11);
  assert.equal(minor, 11, `highlight.js ${pinned} must stay inside lowlight's declared ~11.11.0 range`);
});

test("DW-1168: the redeploy line agents follow names the directory angular.json's outputPath declares", () => {
  // The rule file tells an agent how to put a fresh bundle in front of a browser spec. It named
  // `dist/ocupilot/`, a directory no build writes, so the copy silently moved nothing and the spec
  // read the bundle the container came up with. A one-time correction cannot stop that recurring,
  // and this project pins its cross-file literals rather than trusting two files to stay equal
  // (compose.test.mjs and ci.test.mjs do the same for the ports and the Node bands).
  //
  // Mutation (Rule 19): change either side -- the `outputPath` in angular.json, or the path in the
  // rule file's `docker cp` line -- and this goes red naming both.
  const outputPath = parsed.projects['ocupilot-ui'].architect.build.options.outputPath;
  assert.equal(typeof outputPath, 'string', 'angular.json declares a string outputPath');

  const rulePath = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '.claude', 'rules', 'objectscript-testing.md');
  const rule = readFileSync(rulePath, 'utf8');
  const copyLine = /docker cp (\S+)\/browser\/\.\s/.exec(rule);
  assert.ok(copyLine, 'expected a `docker cp <dist>/browser/.` line in .claude/rules/objectscript-testing.md');
  assert.equal(
    copyLine[1],
    outputPath,
    `the rule file copies from ${copyLine[1]} while angular.json writes ${outputPath}`
  );
});

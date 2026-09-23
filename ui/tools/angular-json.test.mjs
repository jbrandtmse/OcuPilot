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
// warning is set about 5% above the measured initial total, and `maximumError`'s 1600kB is the
// hard stop. Story 8.2 set 1185kB against a measured 1,127,978 bytes (5.06% above), and a tight
// figure keeps each raise a reviewed diff rather than a silent drift. `build-output.test.mjs` measures
// the actual emitted bytes against this figure; this file pins the figure itself, so a later
// change to it is a reviewed diff here rather than a silent edit nothing else notices.
//
// Mutations (Rule 19):
// - loosen `maximumWarning` to a much larger, unmeasured figure (e.g. "2MB") -> the
//   "no other initial budget exists" and "warning under error" assertions still pass, but this
//   test's own exact-string assertion goes red, which is the point: any edit to the literal is
//   visible here.
// - add a second `budgets` entry -> the "exactly one budget" assertion goes red.
test('DW-371: exactly one initial budget, maximumWarning under maximumError, and the literal is pinned', () => {
  const budgets = parsed.projects['ocupilot-ui'].architect.build.configurations.production.budgets;
  assert.equal(budgets.length, 1, 'expected exactly one budget entry');
  const [budget] = budgets;
  assert.equal(budget.type, 'initial');
  assert.equal(budget.maximumWarning, '1185kB', 'a change to this figure must be a reviewed diff, not a silent edit');
  assert.equal(budget.maximumError, '1600kB');

  // Both budgets are written in the units `@angular/build` prints, where a kB is 1000 bytes and
  // an MB is 1000 kB. The error budget moved from `1MB` to `1600kB` when Epic 4 and Epic 6's
  // clients merged, so the parser reads either unit rather than one each.
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

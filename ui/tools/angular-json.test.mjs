import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
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
    assert.ok(builder.startsWith('@angular/build:'), `unexpected builder ${builder} — only @angular/build:* is permitted`);
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
    assert.equal(config.outputHashing, undefined, 'outputHashing must not be re-declared per configuration — it belongs at options level so every configuration inherits it');
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
    'inlineCritical must be explicitly false — an omitted key defaults to true and breaks the CSP'
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

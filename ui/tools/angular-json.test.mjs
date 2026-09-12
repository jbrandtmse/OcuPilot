import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
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

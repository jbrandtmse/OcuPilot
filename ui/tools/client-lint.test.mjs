// Pins the AC rows: "Hardcoded color is rejected" and "Un-sourced literal is
// rejected". Both rule families against positive and negative fixtures,
// including that the token stylesheet is exempt by exact path and that a
// STRINGS.* interpolation passes while a literal text node does not.
//
// Mutation (Rule 19): add `color: #FF0000` to `_typography.scss` -> client-
// lint.mjs exits non-zero and `npm run build` aborts before `ng build`; this
// file's hardcoded-color fixture case goes red if the rule is removed instead.
// Remove the token stylesheet from the exemption path -> the exemption test
// below goes red. Replace app.ts's interpolation with the literal text it
// renders -> client-lint.mjs exits non-zero naming that file and line.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  checkHardcodedColors,
  checkTemplateLiterals,
  lintClient,
  TOKEN_STYLESHEET_PATH,
} from './client-lint.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const packageJsonPath = join(here, '..', 'package.json');
const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf8'));

// --- checkHardcodedColors -----------------------------------------------------

test('a hex color outside the token stylesheet is rejected', () => {
  const result = checkHardcodedColors({ path: 'src/styles/_typography.scss', text: '.x { color: #FF0000; }' });
  assert.equal(result.ok, false);
  assert.equal(result.errors[0].rule, 'no-hardcoded-color');
  assert.equal(result.errors[0].literal, '#FF0000');
  assert.equal(result.errors[0].line, 1);
});

test('an rgb()/hsl() color outside the token stylesheet is rejected', () => {
  const rgbResult = checkHardcodedColors({ path: 'src/app/app.ts', text: 'const c = "rgb(1, 2, 3)";' });
  assert.equal(rgbResult.ok, false);
  assert.equal(rgbResult.errors[0].rule, 'no-hardcoded-color');

  const hslResult = checkHardcodedColors({ path: 'src/app/app.ts', text: 'background: hsla(200, 50%, 50%, 0.5);' });
  assert.equal(hslResult.ok, false);
});

test('a CSS named color after a colon is rejected; the same word in prose is not', () => {
  const declaration = checkHardcodedColors({ path: 'src/styles/_metrics.scss', text: '.x { background: tomato; }' });
  assert.equal(declaration.ok, false);
  assert.equal(declaration.errors[0].literal.trim(), 'tomato');

  const prose = checkHardcodedColors({ path: 'src/styles/_metrics.scss', text: '// the tomato icon needs a redesign' });
  assert.equal(prose.ok, true, `expected no violation in prose, got: ${JSON.stringify(prose.errors)}`);
});

test('the token stylesheet is exempt by its exact path', () => {
  const result = checkHardcodedColors({ path: TOKEN_STYLESHEET_PATH, text: ':root { --ocu-shell: #0F3A5F; }' });
  assert.equal(result.ok, true);
});

test('a file that merely looks like the token stylesheet is NOT exempt -- the exemption is exact-path, not a pattern', () => {
  const result = checkHardcodedColors({ path: 'src/styles/tokens.scss', text: ':root { --ocu-shell: #0F3A5F; }' });
  assert.equal(result.ok, false, 'a near-miss path must not be treated as the exempt stylesheet');
});

// --- checkTemplateLiterals ------------------------------------------------------

test('a literal text node in a template is rejected', () => {
  const text = "template: `<p>Hello there</p>`,";
  const result = checkTemplateLiterals({ path: 'src/app/app.ts', text, allowedKeys: [] });
  assert.equal(result.ok, false);
  assert.equal(result.errors[0].rule, 'no-literal-text-node');
  assert.equal(result.errors[0].literal, 'Hello there');
});

test('an interpolation of a valid STRINGS.* key passes', () => {
  const text = 'template: `<p>{{ STRINGS.productName }}</p>`,';
  const result = checkTemplateLiterals({ path: 'src/app/app.ts', text, allowedKeys: ['productName'] });
  assert.equal(result.ok, true, `expected no violations, got: ${JSON.stringify(result.errors)}`);
});

test('an interpolation of an unknown STRINGS.* key is rejected', () => {
  const text = 'template: `<p>{{ STRINGS.thisKeyDoesNotExist }}</p>`,';
  const result = checkTemplateLiterals({ path: 'src/app/app.ts', text, allowedKeys: ['productName'] });
  assert.equal(result.ok, false);
  assert.equal(result.errors[0].rule, 'no-unsourced-interpolation');
});

test('a literal string typed directly inside an interpolation is rejected', () => {
  const text = "template: `<p>{{ 'a literal typed in the template' }}</p>`,";
  const result = checkTemplateLiterals({ path: 'src/app/app.ts', text, allowedKeys: [] });
  assert.equal(result.ok, false);
  assert.equal(result.errors[0].rule, 'no-unsourced-interpolation');
});

test('a literal value on a copy-bearing attribute is rejected', () => {
  const text = 'template: `<button aria-label="Close this dialog">X</button>`,';
  const result = checkTemplateLiterals({ path: 'src/app/app.ts', text, allowedKeys: [] });
  const attrError = result.errors.find((e) => e.rule === 'no-literal-copy-attribute');
  assert.ok(attrError, `expected a no-literal-copy-attribute violation, got: ${JSON.stringify(result.errors)}`);
  assert.equal(attrError.literal, 'aria-label="Close this dialog"');
});

test('a bound (property-binding) attribute is not a literal and passes', () => {
  const text = 'template: `<button [aria-label]="closeLabel()">{{ STRINGS.productName }}</button>`,';
  const result = checkTemplateLiterals({ path: 'src/app/app.ts', text, allowedKeys: ['productName'] });
  assert.equal(result.ok, true, `expected no violations, got: ${JSON.stringify(result.errors)}`);
});

test('a single-quoted copy-bearing attribute literal is rejected the same as a double-quoted one', () => {
  const text = "template: `<button aria-label='Close this dialog'>{{ STRINGS.productName }}</button>`,";
  const result = checkTemplateLiterals({ path: 'src/app/app.ts', text, allowedKeys: ['productName'] });
  const attrError = result.errors.find((e) => e.rule === 'no-literal-copy-attribute');
  assert.ok(attrError, `expected a no-literal-copy-attribute violation, got: ${JSON.stringify(result.errors)}`);
  assert.equal(attrError.literal, "aria-label='Close this dialog'");
});

test('a copy-bearing attribute holding exactly a sourced STRINGS.* interpolation passes', () => {
  const text = 'template: `<button aria-label="{{ STRINGS.productName }}">{{ STRINGS.productName }}</button>`,';
  const result = checkTemplateLiterals({ path: 'src/app/app.ts', text, allowedKeys: ['productName'] });
  assert.equal(result.ok, true, `expected no violations, got: ${JSON.stringify(result.errors)}`);
});

test('a copy-bearing attribute mixing literal text with an interpolation is still rejected', () => {
  const text = 'template: `<button aria-label="Row {{ STRINGS.productName }}">{{ STRINGS.productName }}</button>`,';
  const result = checkTemplateLiterals({ path: 'src/app/app.ts', text, allowedKeys: ['productName'] });
  const attrError = result.errors.find((e) => e.rule === 'no-literal-copy-attribute');
  assert.ok(attrError, `expected the mixed attribute value to still be rejected, got: ${JSON.stringify(result.errors)}`);
});

test('a template with no tags at all is still scanned as one literal text node', () => {
  const text = 'template: `Hello there`,';
  const result = checkTemplateLiterals({ path: 'src/app/app.ts', text, allowedKeys: [] });
  assert.equal(result.ok, false);
  assert.equal(result.errors[0].rule, 'no-literal-text-node');
  assert.equal(result.errors[0].literal, 'Hello there');
});

test('literal text before the first tag or after the last tag is caught, not only text between tags', () => {
  const text = 'template: `Leading text<p>{{ STRINGS.productName }}</p>Trailing text`,';
  const result = checkTemplateLiterals({ path: 'src/app/app.ts', text, allowedKeys: ['productName'] });
  const literals = result.errors.filter((e) => e.rule === 'no-literal-text-node').map((e) => e.literal);
  assert.deepEqual(
    literals.sort(),
    ['Leading text', 'Trailing text'],
    `expected both the leading and trailing literal spans to be reported, got: ${JSON.stringify(result.errors)}`
  );
});

test('whitespace-only text between tags is not a violation', () => {
  const text = 'template: `<div>\n  <span>{{ STRINGS.productName }}</span>\n</div>`,';
  const result = checkTemplateLiterals({ path: 'src/app/app.ts', text, allowedKeys: ['productName'] });
  assert.equal(result.ok, true, `expected no violations, got: ${JSON.stringify(result.errors)}`);
});

test('a .html template file is scanned the same way as an inline template', () => {
  const result = checkTemplateLiterals({ path: 'src/app/shell/header.html', text: '<p>Literal header text</p>', allowedKeys: [] });
  assert.equal(result.ok, false);
  assert.equal(result.errors[0].rule, 'no-literal-text-node');
});

// --- lintClient() aggregate -------------------------------------------------------

test('lintClient() reports clean over the real ui/src tree as shipped in this story', () => {
  const result = lintClient();
  assert.equal(result.ok, true, `unexpected violations over the real tree: ${JSON.stringify(result.errors, null, 2)}`);
});

test('node tools/client-lint.mjs exits 0 over the real tree', () => {
  const uiRoot = join(here, '..');
  assert.doesNotThrow(() => {
    execFileSync('node', ['tools/client-lint.mjs'], { cwd: uiRoot, stdio: 'pipe' });
  });
});

// --- prebuild/prestart wiring -----------------------------------------------------
//
// `build-output.test.mjs` runs the real build against the current, lint-clean
// tree and only inspects `dist/` afterward -- it cannot tell "client-lint ran
// during prebuild and passed" apart from "client-lint never ran". This is the one
// place that reads `package.json`'s `scripts` object directly, so a `prebuild`/
// `prestart` regression (e.g. reverted to just the version guard) fails here even
// though every other test in the suite would stay green.
//
// Mutation (Rule 19): remove "&& node tools/client-lint.mjs" from either script
// in ui/package.json -> both assertions below go red.

test('package.json wires client-lint.mjs into both prebuild and prestart, after the version guard', () => {
  for (const scriptName of ['prebuild', 'prestart']) {
    const script = packageJson.scripts[scriptName];
    assert.match(
      script,
      /version-guard\.mjs.*&&.*client-lint\.mjs/,
      `expected package.json's "${scriptName}" script to run tools/client-lint.mjs after tools/version-guard.mjs, got: ${JSON.stringify(script)}`
    );
  }
});

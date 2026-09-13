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
  ALLOWED_ABSOLUTE_URLS,
  checkHardcodedColors,
  checkNonAsciiLiterals,
  checkOffOriginUrls,
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

// --- The rule's boundaries: what must NOT fail the build --------------------------
//
// `prebuild` runs this linter, so every false positive below is a `npm run build`
// that no later story can unblock. Each case was observed failing before the fix.
//
// Mutations (Rule 19):
// - drop `blankControlFlow` from `findLiteralTextNodes` -> the control-flow tests
//   below go red ("@if (ready) {" reported as a literal text node).
// - restore the `[^"']*` value class in `COPY_ATTRIBUTE_RE` -> the apostrophe test
//   goes red (the attribute is silently not reported at all).
// - drop the `STRING_LITERAL_EXPR_RE` branch -> the data-binding tests go red.
// - drop `blankComments` from `checkHardcodedColors` -> the comment tests go red.

test("Angular's built-in control flow is template syntax, not a literal text node", () => {
  for (const body of [
    '@if (ready) { <p>{{ STRINGS.productName }}</p> }',
    '@for (r of rows; track r.id) { <p>{{ STRINGS.productName }}</p> }',
    '@if (a) { <p>{{ STRINGS.productName }}</p> } @else { <p>{{ STRINGS.productName }}</p> }',
    '@switch (k) { @case (1) { <p>{{ STRINGS.productName }}</p> } @default { <b>{{ STRINGS.productName }}</b> } }',
  ]) {
    const result = checkTemplateLiterals({
      path: 'src/app/app.ts',
      text: `template: \`${body}\`,`,
      allowedKeys: ['productName'],
    });
    assert.equal(result.ok, true, `control flow must not be reported as copy: ${body} -> ${JSON.stringify(result.errors)}`);
  }
});

test('a data binding is out of scope by design (AD-39); a quoted literal inside the braces is not', () => {
  const allowedKeys = ['productName'];
  for (const expr of ['row.name', 'user().login', 'STRINGS.productName | uppercase', 'count + 1']) {
    const result = checkTemplateLiterals({ path: 'src/app/app.ts', text: `template: \`<p>{{ ${expr} }}</p>\`,`, allowedKeys });
    assert.equal(result.ok, true, `a data binding must pass: {{ ${expr} }} -> ${JSON.stringify(result.errors)}`);
  }
  for (const expr of ["'Close'", "x ? 'Yes' : 'No'"]) {
    const result = checkTemplateLiterals({ path: 'src/app/app.ts', text: `template: \`<p>{{ ${expr} }}</p>\`,`, allowedKeys });
    assert.equal(result.errors[0]?.rule, 'no-unsourced-interpolation', `a quoted literal must be rejected: {{ ${expr} }}`);
  }
});

test('a copy-bearing attribute whose value contains the other quote character is still reported', () => {
  for (const [markup, expected] of [
    ['<b aria-label="Agent\'s rationale">{{ STRINGS.productName }}</b>', 'aria-label="Agent\'s rationale"'],
    ['<b aria-label=\'He said "hi"\'>{{ STRINGS.productName }}</b>', 'aria-label=\'He said "hi"\''],
  ]) {
    const result = checkTemplateLiterals({ path: 'src/app/app.ts', text: `template: \`${markup}\`,`, allowedKeys: ['productName'] });
    const attrs = result.errors.filter((e) => e.rule === 'no-literal-copy-attribute').map((e) => e.literal);
    assert.deepEqual(attrs, [expected], `expected the attribute literal to be reported, got: ${JSON.stringify(result.errors)}`);
  }
});

test('a literal ">" in copy is reported once, not as two overlapping spans', () => {
  const text = "template: `Home > Users<b aria-label='{{ STRINGS.productName }}'>{{ STRINGS.productName }}</b>`,";
  const result = checkTemplateLiterals({ path: 'src/app/app.ts', text, allowedKeys: ['productName'] });
  assert.deepEqual(
    result.errors.map((e) => [e.rule, e.literal]),
    [['no-literal-text-node', 'Home > Users']],
    `expected exactly one span, got: ${JSON.stringify(result.errors)}`
  );
});

test('a comment that merely names a color, and a var()-composed color function, do not fail the build', () => {
  for (const [label, sample] of [
    ['// line comment', '// the shell navy is #0F3A5F, declared in _tokens.scss\n'],
    ['/* block comment */', '/* DESIGN.md rule 2: white on the logo teal is 3.78:1 */\n'],
    ['var()-composed rgba', '.x { background: rgba(var(--ocu-on-shell-rgb), 0.72); }\n'],
  ]) {
    const result = checkHardcodedColors({ path: 'src/styles/_probe.scss', text: sample });
    assert.equal(result.ok, true, `${label} must not be flagged, got: ${JSON.stringify(result.errors)}`);
  }
  // ...while a real declaration on the same shapes still is.
  const real = checkHardcodedColors({ path: 'src/styles/_probe.scss', text: '.x { color: #0F3A5F; }' });
  assert.equal(real.errors[0]?.literal, '#0F3A5F', 'a real hex declaration must still be rejected');
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

// --- checkOffOriginUrls (Story 1.17, DW-43's sibling: AD-28, AD-47, NFR-10) -------------
//
// Every literal below is written with its scheme split (`'https:' + '//...'`) so that this
// FILE carries no off-origin URL of its own -- it is one of the files the rule scans.
//
// Mutations (Rule 19): add a `<script src="https://cdn.example.com/x.js">` to
// `ui/src/index.html` -> `node tools/client-lint.mjs` exits non-zero naming the file and line,
// and the aggregate case below goes red. Delete an entry from `ALLOWED_ABSOLUTE_URLS` -> the
// allowlist case goes red, which is what keeps the list a decision rather than a habit.

const CDN = 'https:' + '//cdn.example.com/jquery.min.js';

test('a CDN script reference is rejected', () => {
  const result = checkOffOriginUrls({ path: 'src/index.html', text: `<script src="${CDN}"></script>` });
  assert.equal(result.ok, false);
  assert.equal(result.errors[0].rule, 'no-off-origin-url');
  assert.equal(result.errors[0].line, 1);
});

test('a protocol-relative CDN reference is rejected too', () => {
  const result = checkOffOriginUrls({ path: 'src/styles/_probe.scss', text: "@import url(" + '//' + "fonts.example.com/x.css);" });
  assert.equal(result.ok, false, 'a scheme-less off-origin reference loads off-origin all the same');
});

test('an off-origin stylesheet link and an off-origin fetch are both rejected', () => {
  const link = checkOffOriginUrls({ path: 'src/index.html', text: `<link rel="stylesheet" href="${'https:' + '//fonts.googleapis.com/css'}">` });
  assert.equal(link.ok, false);
  const call = checkOffOriginUrls({ path: 'src/app/core/probe.ts', text: `await fetch('${'https:' + '//telemetry.example.com/beacon'}');` });
  assert.equal(call.ok, false);
});

test('a same-origin absolute path is not a URL and passes', () => {
  for (const sample of ["fetch('/api/ocupilot/instance');", "const href = '/csp/sys/UtilHome.csp';", '<img src="assets/lockup/x.png">']) {
    const result = checkOffOriginUrls({ path: 'src/app/core/probe.ts', text: sample });
    assert.equal(result.ok, true, `expected no violation for ${sample}: ${JSON.stringify(result.errors)}`);
  }
});

test('a regex literal that escapes a slash is not an off-origin URL', () => {
  // `/\//g` spells four characters, the middle two of which are `//`. Two real call sites in
  // src/app/shell are written that way, and a host-agnostic pattern reported both.
  const result = checkOffOriginUrls({ path: 'src/app/shell/probe.ts', text: "route.replace(/\\//g, '-')" });
  assert.equal(result.ok, true, `expected no violation: ${JSON.stringify(result.errors)}`);
});

test('a comment that names a URL to explain why it is not used does not fail the build', () => {
  const result = checkOffOriginUrls({ path: 'src/app/core/probe.ts', text: `// nothing is loaded from ${CDN}; the bundle carries it\n` });
  assert.equal(result.ok, true, `expected the comment exempt: ${JSON.stringify(result.errors)}`);
});

test('every allowlisted URL passes, and the list is a closed set of documented exceptions', () => {
  assert.ok(ALLOWED_ABSOLUTE_URLS.length > 0, 'the allowlist is the mechanism, so it must not be empty');
  for (const allowed of ALLOWED_ABSOLUTE_URLS) {
    const result = checkOffOriginUrls({ path: 'src/app/core/probe.ts', text: `const x = '${allowed}';` });
    assert.equal(result.ok, true, `${allowed} is allowlisted and must pass: ${JSON.stringify(result.errors)}`);
  }
});

// --- checkNonAsciiLiterals (DW-43, Rule 14) --------------------------------------------
//
// Every fixture builds its own non-ASCII character with an escape, so this file carries no
// literal byte of its own -- which is the discipline the rule exists to enforce.
//
// Mutation (Rule 19): write a literal em dash into any string in `ui/src` or `ui/tools` ->
// `node tools/client-lint.mjs` exits non-zero naming the file, the line and the escape to use.

const EM_DASH = '\u2014';
const MIDDLE_DOT = '\u00B7';

test('a literal non-ASCII byte in a string literal is rejected, and the message carries the escape', () => {
  const result = checkNonAsciiLiterals({ path: 'src/app/core/strings.ts', text: `const x = 'a ${EM_DASH} b';` });
  assert.equal(result.ok, false);
  assert.equal(result.errors[0].rule, 'no-literal-non-ascii');
  assert.match(result.errors[0].literal, /U\+2014/);
  assert.match(result.errors[0].literal, /\\u2014/, 'the fix is in the message');
});

test('a literal non-ASCII byte in a template text node is rejected', () => {
  const result = checkNonAsciiLiterals({ path: 'src/app/shell/probe.ts', text: `template: \`<p>Home ${MIDDLE_DOT} Logs</p>\`,` });
  assert.equal(result.ok, false);
  assert.match(result.errors[0].literal, /U\+00B7/);
});

test('the same character written as an escape passes', () => {
  const result = checkNonAsciiLiterals({ path: 'src/app/core/strings.ts', text: "const x = 'a \\u2014 b';" });
  assert.equal(result.ok, true, `an escape is the authored form: ${JSON.stringify(result.errors)}`);
});

test('a non-ASCII character in a comment is exempt, in every comment form', () => {
  for (const sample of [
    `// a ${EM_DASH} b\n`,
    `/* a ${EM_DASH} b */\n`,
    `/**\n * a ${EM_DASH} b\n */\n`,
    `<!-- a ${EM_DASH} b -->\n`,
  ]) {
    const result = checkNonAsciiLiterals({ path: 'src/app/core/probe.ts', text: sample });
    assert.equal(result.ok, true, `Rule 14 exempts comments: ${JSON.stringify(result.errors)}`);
  }
});

test('lintClient() reports the count it scanned, so a clean run and an empty run differ', () => {
  const result = lintClient();
  assert.ok(result.scanned > 0, 'a run over no file at all would report ok with no evidence');
});

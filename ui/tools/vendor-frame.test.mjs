import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative, sep } from 'node:path';

// Pins AD-63 (the vendor's interoperability editors load in a same-origin frame, in normal mode,
// and OcuPilot never reaches into it) at the one place the frame's address is built:
// `core/vendor-frame.ts`. The component that draws the frame is held by
// `interop-editor-frame.spec.ts`, the editors themselves by `browser/interop-editor-frame.browser-spec.mjs`,
// and the bans on reaching into a frame by `api.test.mjs`.
//
// Mutations (Rule 19):
// - `interopEditorSource` appends `&VSCODE=1` -> the exact-source rows, the parameter-name
//   scan and the no-VSCODE row go red.
// - `interopEditorSource` accepts a document holding `&` (its shape check removed) -> the refused
//   documents go red.
// - `app-interop-editor-frame` builds its own `/ui/interop/...` address -> the one-source scan goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { CLASS_NAME, NAMESPACE_NAME, INTEROP_EDITORS, interopEditorSource, isInteropEditor } = await import(
  corePath('vendor-frame.ts')
);

const EDITORS = ['rule-editor', 'dtl-editor', 'bpl-editor'];
const PARAMETER = { 'rule-editor': 'rule', 'dtl-editor': 'DTL', 'bpl-editor': 'BP' };

/** The query parameter names of an answered source, in order. */
function parameterNames(source) {
  return [...new URL(source, 'http://instance.invalid').searchParams.keys()];
}

test('each editor answers its own address, with and without a document', () => {
  for (const editor of EDITORS) {
    const bare = `/ui/interop/${editor}/index.html?$NAMESPACE=HSCUSTOM`;
    assert.equal(interopEditorSource(editor, 'HSCUSTOM'), bare, `${editor} with no document`);
    assert.equal(interopEditorSource(editor, 'HSCUSTOM', ''), bare, `${editor} with an empty document`);
    assert.equal(
      interopEditorSource(editor, 'HSCUSTOM', 'Demo.Probe.Thing'),
      `${bare}&${PARAMETER[editor]}=Demo.Probe.Thing`,
      `${editor} with a document, in its own parameter`
    );
  }
  assert.deepEqual(Object.keys(INTEROP_EDITORS), EDITORS, 'the vocabulary is these three editors');
  assert.deepEqual(
    Object.fromEntries(EDITORS.map((editor) => [editor, INTEROP_EDITORS[editor].parameter])),
    PARAMETER,
    "each editor's document parameter is the one its bundle reads"
  );
  assert.deepEqual(
    EDITORS.map((editor) => INTEROP_EDITORS[editor].titleKey),
    ['interopRuleEditorTitle', 'interopDtlEditorTitle', 'interopBplEditorTitle']
  );
});

test('every value is percent-encoded, a %-led namespace and document included', () => {
  assert.equal(interopEditorSource('rule-editor', '%SYS'), '/ui/interop/rule-editor/index.html?$NAMESPACE=%25SYS');
  assert.equal(
    interopEditorSource('dtl-editor', '%SYS', '%Library.Probe'),
    '/ui/interop/dtl-editor/index.html?$NAMESPACE=%25SYS&DTL=%25Library.Probe'
  );
  const decoded = new URL(interopEditorSource('bpl-editor', '%SYS', '%Library.Probe'), 'http://instance.invalid').searchParams;
  assert.equal(decoded.get('$NAMESPACE'), '%SYS', 'and the encoding round-trips');
  assert.equal(decoded.get('BP'), '%Library.Probe');
  assert.equal(
    interopEditorSource('rule-editor', 'N'.repeat(64)),
    `/ui/interop/rule-editor/index.html?$NAMESPACE=${'N'.repeat(64)}`,
    'the longest namespace name is accepted'
  );
});

test('the address strips no extension and adds nothing', () => {
  assert.equal(
    interopEditorSource('dtl-editor', 'HSCUSTOM', 'Demo.Probe.cls'),
    '/ui/interop/dtl-editor/index.html?$NAMESPACE=HSCUSTOM&DTL=Demo.Probe.cls'
  );
  for (const editor of EDITORS) {
    assert.deepEqual(parameterNames(interopEditorSource(editor, 'HSCUSTOM')), ['$NAMESPACE']);
    assert.deepEqual(parameterNames(interopEditorSource(editor, 'HSCUSTOM', 'A.B')), ['$NAMESPACE', PARAMETER[editor]]);
  }
});

test('a refused input answers null: an editor outside the vocabulary', () => {
  for (const editor of ['', 'rule', 'rule-editor/', 'rule-editor/../x', 'RULE-EDITOR', 'schema-viewer', 'constructor', '__proto__', 'toString', 'hasOwnProperty', ' rule-editor', null, undefined, 7]) {
    assert.equal(interopEditorSource(editor, 'HSCUSTOM'), null, `editor ${JSON.stringify(editor)}`);
    assert.equal(isInteropEditor(editor), false, `and it is no editor: ${JSON.stringify(editor)}`);
  }
  for (const editor of EDITORS) assert.equal(isInteropEditor(editor), true);
});

test('a refused input answers null: a namespace that is empty or outside its shape', () => {
  for (const namespace of ['', 'X&VSCODE=1', 'X#y', '../x', 'a/b', 'US ER', 'x=1', 'x?y', '%%SYS', 'N'.repeat(65), 'a.b', 'caf\u00e9', null, undefined, 7]) {
    for (const editor of EDITORS) {
      assert.equal(interopEditorSource(editor, namespace), null, `${editor} namespace ${JSON.stringify(namespace)}`);
    }
  }
});

test('a refused input answers null: a non-empty document outside its shape', () => {
  const refused = ['..', '../x', 'x/y', 'x\\y', 'A&VSCODE=1', 'A#b', 'A?b', 'A=b', 'A b', ' A', 'A ', 'A\nB', '.', '.cls', 'Demo..Probe', 'Demo.Probe.', '1Demo.Probe', 'Demo.%Probe', 'Demo.Probe&DTL=Other', '%%Demo', '<x>', null, 7];
  for (const document of refused) {
    for (const editor of EDITORS) {
      assert.equal(interopEditorSource(editor, 'HSCUSTOM', document), null, `${editor} document ${JSON.stringify(document)}`);
    }
  }
  assert.equal(interopEditorSource('dtl-editor', 'HSCUSTOM', undefined), '/ui/interop/dtl-editor/index.html?$NAMESPACE=HSCUSTOM', 'an absent document is the default, empty');
});

test('no answer ever carries VSCODE, READONLY or any parameter but the editor\'s own', () => {
  const namespaces = ['HSCUSTOM', 'USER', '%SYS', 'VSCODE', 'READONLY', 'a-b_c', '0'];
  const documents = ['', 'A', 'A.B', '%A.B', 'VSCODE', 'READONLY', 'Demo.VSCODE', 'Demo.READONLY.Rule'];
  let answered = 0;
  for (const editor of EDITORS) {
    for (const namespace of namespaces) {
      for (const document of documents) {
        const source = interopEditorSource(editor, namespace, document);
        assert.notEqual(source, null, `${editor} ${namespace} ${document}`);
        answered += 1;
        const expected = document === '' ? ['$NAMESPACE'] : ['$NAMESPACE', PARAMETER[editor]];
        assert.deepEqual(parameterNames(source), expected, `${source} names no parameter beyond the editor's own`);
        if (namespace !== 'VSCODE' && namespace !== 'READONLY' && !/VSCODE|READONLY/.test(document)) {
          assert.ok(!/VSCODE|READONLY/.test(source), `${source} carries neither mode flag`);
        }
        assert.ok(source.startsWith(`/ui/interop/${editor}/index.html?`), `${source} is the editor's own path on this origin`);
        assert.ok(!source.includes('//') && !/^[a-z]+:/i.test(source), `${source} names no other origin`);
      }
    }
  }
  assert.equal(answered, EDITORS.length * namespaces.length * documents.length, 'every combination was answered, so the scan above ran over all of them');
  for (const editor of EDITORS) {
    assert.equal(interopEditorSource(editor, 'HSCUSTOM', 'A&VSCODE=1'), null);
    assert.equal(interopEditorSource(editor, 'HSCUSTOM&VSCODE=1'), null);
  }
});

test('the shapes moved out of the class reference still accept what its address accepted', () => {
  for (const name of ['Demo.Probe', '%Library.String', 'OcuProbe199.Doc', 'A', 'a1.b2.c3']) {
    assert.equal(CLASS_NAME.test(name), true, `class ${name}`);
  }
  for (const name of ['', '.cls_', 'Demo..Probe', 'Demo.Probe.', '1Demo.Probe', 'Demo.%Probe', 'Demo.Probe&IRISPassword=SYS', 'Demo/Probe', 'a b']) {
    assert.equal(CLASS_NAME.test(name), false, `not a class ${JSON.stringify(name)}`);
  }
  for (const namespace of ['HSCUSTOM', 'USER', '%SYS', 'a-b_c', 'N'.repeat(64)]) {
    assert.equal(NAMESPACE_NAME.test(namespace), true, `namespace ${namespace}`);
  }
  for (const namespace of ['', 'USER&x=1', 'US ER', '%%SYS', 'x/y', 'N'.repeat(65)]) {
    assert.equal(NAMESPACE_NAME.test(namespace), false, `not a namespace ${JSON.stringify(namespace)}`);
  }
  const store = readFileSync(join(uiRoot, 'src', 'app', 'areas', 'system-explorer', 'document-viewer.store.ts'), 'utf8');
  assert.match(store, /import \{ CLASS_NAME, NAMESPACE_NAME \} from '\.\.\/\.\.\/core\/vendor-frame';/, 'the class reference imports the shapes');
  assert.ok(!/(const|let|var)\s+(CLASS_NAME|NAMESPACE_NAME)\b/.test(store), 'and holds no copy of either');
});

// --- The one-source scan --------------------------------------------------------------------------

const SCAN_EXTENSIONS = new Set(['.ts', '.html', '.scss', '.json', '.js', '.mjs']);
const PRUNE = new Set(['node_modules', 'dist', '.angular']);

// Comments are prose and may name the path they explain; only code builds an address. The same
// blanker `api.test.mjs` applies.
const COMMENT_RE = /\/\*[\s\S]*?\*\/|(?:^|(?<=[\s;{}(]))\/\/[^\n]*/g;

function blankComments(text) {
  return text.replace(COMMENT_RE, (m) => m.replace(/[^\n]/g, ' '));
}

function walk(dir, onFile) {
  for (const entry of readdirSync(dir)) {
    if (PRUNE.has(entry)) continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) {
      walk(full, onFile);
      continue;
    }
    if (!SCAN_EXTENSIONS.has(entry.slice(entry.lastIndexOf('.')))) continue;
    onFile(full, readFileSync(full, 'utf8'));
  }
}

test('the builder is the frame\'s one source: non-spec code under ui/src names /ui/interop only in core/vendor-frame.ts', () => {
  const holders = [];
  let scanned = 0;
  walk(join(uiRoot, 'src'), (fullPath, text) => {
    const relativePath = relative(uiRoot, fullPath).split(sep).join('/');
    if (relativePath.endsWith('.spec.ts')) return;
    scanned += 1;
    if (blankComments(text).includes('/ui/interop')) holders.push(relativePath);
  });
  assert.ok(scanned > 100, `the scan covered the client's code (${scanned} files)`);
  assert.deepEqual(holders, ['src/app/core/vendor-frame.ts']);
});

test('the scan itself catches a code line that builds the address, and ignores a comment that names it', () => {
  const fixture = [
    '// the editor is served at /ui/interop/rule-editor/index.html',
    '/* /ui/interop is the vendor\'s */',
    "const own = `/ui/interop/${editor}/index.html`;",
  ].join('\n');
  const lines = blankComments(fixture)
    .split('\n')
    .map((line, idx) => (line.includes('/ui/interop') ? idx + 1 : 0))
    .filter((line) => line > 0);
  assert.deepEqual(lines, [3], 'one real line, and neither comment');
});

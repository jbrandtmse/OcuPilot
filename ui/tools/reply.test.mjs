import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins `parseReply` (Story 4.6): the plain-data node tree a reply parses into, one test per I/O &
// Edge-Case Matrix row, plus the allow-list and bound checks the matrix does not carry a row for.
//
// **No DOM here.** `core/reply.ts` imports no `@angular/core` and touches no DOM or `location`
// (AD-19) -- every assertion below reads the returned `ReplyNode[]` as plain data.
//
// Mutations (Rule 19):
// - render an `html` token's own children instead of its raw text -> "raw HTML renders as text"
//   goes red (a `<script>` would then produce a real, if inert, node in the tree).
// - drop the `registered(lang)` guard before calling `lowlight.highlight` -> "a fenced block
//   tagged with an unregistered language" throws instead of rendering plain.
// - allow a non-same-origin `src` through `imageNode` -> "a same-origin image renders" and
//   "a remote image renders as text" both go red, the second because an `img` node appears.
// - drop the `isAllowedLinkUrl` check in `linkNodes` -> "a hostile scheme renders as text" goes
//   red, producing an `a` node for a `javascript:` href.
// - make `isAllowedClass` return `true` unconditionally -> "isAllowedClass admits exactly the
//   three allow-listed shapes" goes red. (Deleting `filterClasses` is NOT a falsifying mutation:
//   no reachable input produces a class the filter rejects, so the filter is pinned directly.)
// - drop the try/catch in `parseReply` -> "a pathologically nested reply renders as its own
//   literal source rather than throwing" goes red with a RangeError.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { parseReply, REPLY_TAGS, isAllowedClass } = await import(corePath('reply.ts'));

const ORIGIN = 'https://ocupilot.example';

function parse(text) {
  return parseReply(text, { origin: ORIGIN });
}

/** Every `ReplyNode.tag` in the tree, collected depth-first. */
function collectTags(nodes, out = []) {
  for (const node of nodes) {
    if (node.kind === 'element') {
      out.push(node.tag);
      collectTags(node.children, out);
    }
  }
  return out;
}

/** Every class name carried anywhere in the tree. */
function collectClasses(nodes, out = []) {
  for (const node of nodes) {
    if (node.kind === 'element') {
      out.push(...node.classes);
      collectClasses(node.children, out);
    }
  }
  return out;
}

/** Concatenates every text node's characters, depth-first -- the tree's own `textContent`. */
function textOf(nodes) {
  let out = '';
  for (const node of nodes) {
    if (node.kind === 'text') out += node.text;
    else if (node.kind === 'element') out += textOf(node.children);
  }
  return out;
}

function findFirst(nodes, predicate) {
  for (const node of nodes) {
    if (node.kind === 'element') {
      if (predicate(node)) return node;
      const found = findFirst(node.children, predicate);
      if (found !== null) return found;
    }
  }
  return null;
}

test('plain one-line reply is one paragraph, and its text equals the input', () => {
  const nodes = parse('Here is what I found.');
  assert.equal(nodes.length, 1);
  assert.equal(nodes[0].kind, 'element');
  assert.equal(nodes[0].tag, 'p');
  assert.equal(textOf(nodes), 'Here is what I found.');
});

test('raw HTML renders as text -- one paragraph whose text is the literal source', () => {
  const markup = '<img src="http://203.0.113.9/x">';
  const nodes = parse(markup);
  assert.equal(textOf(nodes), markup);
  assert.equal(findFirst(nodes, (n) => n.tag === 'img'), null, 'no <img> node was created from raw HTML');
});

// Raw HTML is text, never markup, regardless of how alarming the payload looks (Boundaries &
// Constraints, "raw HTML inside a reply is text, never markup"). Three concrete payloads a
// probe would try against a Markdown renderer: a <script> tag, an onerror attribute, and an
// SVG payload with an embedded <script>/onload. `textOf` reassembling the exact input string is
// the same "renders as text" contract the existing raw-HTML-image row asserts; `collectTags`
// asserts nothing but `p` was created (a heading/list would also be legal wrapping, but a raw
// standalone HTML block always wraps as one paragraph per `blockTokenToNodes`'s `html` case).
// Mutation (Rule 19): render an `html` token's own children instead of its raw text (the same
// mutation the module doc comment and Rule 19 table already name for AC1) -> each row below
// goes red, since a real (if inert) node would then appear in the tree.
for (const markup of [
  '<script>alert(1)</script>',
  '<img src=x onerror="alert(1)">',
  '<svg onload="alert(1)"><circle r="1"/></svg>',
  '<svg><script>alert(1)</script></svg>',
]) {
  test(`raw HTML payload renders as literal text with no element created: ${JSON.stringify(markup)}`, () => {
    const nodes = parse(markup);
    assert.equal(textOf(nodes), markup);
    assert.deepEqual(
      [...new Set(collectTags(nodes))],
      ['p'],
      `expected only the wrapping <p>, got tags: ${JSON.stringify(collectTags(nodes))}`
    );
  });
}

// A <script> embedded inline inside ordinary prose splits into several inline `html`/`text`
// tokens (verified against marked 18.0.13's Lexer output); each still renders as its own literal
// text node, so the paragraph's reassembled text equals the original sentence exactly and no
// tag other than `p` appears.
test('a script tag embedded inline in a sentence renders as literal text, still inside one paragraph', () => {
  const markup = 'Findings: <script>alert(1)</script> is not a valid row name.';
  const nodes = parse(markup);
  assert.equal(textOf(nodes), markup);
  assert.deepEqual([...new Set(collectTags(nodes))], ['p']);
});

test('a remote Markdown image renders as its alt text and creates no img node', () => {
  const nodes = parse('![a map](http://203.0.113.9/m.png)');
  assert.equal(textOf(nodes), 'a map');
  assert.equal(findFirst(nodes, (n) => n.tag === 'img'), null);
});

test('a remote Markdown image with empty alt renders its literal source', () => {
  const nodes = parse('![](http://203.0.113.9/m.png)');
  assert.equal(textOf(nodes), '![](http://203.0.113.9/m.png)');
});

test('a same-origin image renders as an img node with its src and alt', () => {
  const nodes = parse('![logo](/ocupilot/media/x.png)');
  const img = findFirst(nodes, (n) => n.tag === 'img');
  assert.ok(img, 'expected an img node');
  assert.equal(img.src, '/ocupilot/media/x.png');
  assert.equal(img.alt, 'logo');
});

// DESIGN.md `message-agent` puts the host "after the link text", and the I/O matrix's External
// link row reads "`a` with that `href`, text `docs` ... FOLLOWED BY a caption `span`" -- so the
// caption is the anchor's next sibling, not its child. Nested, it would join the link's
// accessible name and sit inside its activation area.
// Mutation (Rule 19): return `[a(label, caption)]` from `linkNodes` instead of `[a(label),
// caption]` -> the anchor's own text is no longer `docs` and this goes red.
test('an external link carries its href, and its bare host follows it as a sibling caption', () => {
  const nodes = parse('[docs](https://docs.example.com/p)');
  const paragraph = nodes[0];
  assert.equal(paragraph.tag, 'p');
  const link = findFirst(nodes, (n) => n.tag === 'a');
  assert.ok(link, 'expected an a node');
  assert.equal(link.href, 'https://docs.example.com/p');
  assert.equal(textOf(link.children), 'docs', 'the anchor carries only its own label');
  assert.equal(findFirst(link.children, (n) => n.classes.includes('ocu-reply-link-caption')), null, 'the caption is not inside the anchor');
  const linkIndex = paragraph.children.indexOf(link);
  const caption = paragraph.children[linkIndex + 1];
  assert.ok(caption?.classes?.includes('ocu-reply-link-caption'), 'expected the caption span immediately after the anchor');
  assert.equal(textOf([caption]), 'docs.example.com');
});

// The host caption is an external-link warning (AC4); a same-origin link needs none.
// Mutation (Rule 19): drop the `isSameOriginUrl` guard in `linkNodes` -> this goes red, finding
// a caption span (and the origin's own hostname repeated as text) on an in-app link.
test('a same-origin link carries no host caption', () => {
  const nodes = parse('[namespaces](/ocupilot/namespaces)');
  const link = findFirst(nodes, (n) => n.tag === 'a');
  assert.ok(link, 'expected an a node');
  assert.equal(link.href, '/ocupilot/namespaces');
  assert.equal(findFirst(nodes, (n) => n.classes.includes('ocu-reply-link-caption')), null, 'expected no caption span anywhere');
  assert.equal(textOf(nodes), 'namespaces');
});

test('a hostile scheme renders as text -- no a node, only the link label', () => {
  const nodes = parse('[bad](javascript:alert(1))');
  assert.equal(findFirst(nodes, (n) => n.tag === 'a'), null);
  assert.equal(textOf(nodes), 'bad');
});

// AC4/Boundaries: "any other scheme ... renders the link as text". `javascript:` is covered
// above; every other scheme the story names by example gets its own row here, each parsed by
// `new URL()` (verified) into a protocol other than http:/https:, so `isAllowedLinkUrl` rejects
// all four the same way. Mutation (Rule 19): loosen `isAllowedLinkUrl` to accept any URL that
// parses (drop the protocol check) -> every row below goes red, producing an `a` node.
for (const [name, href] of [
  ['data:', 'data:text/html,foo'],
  ['vbscript:', 'vbscript:alert(1)'],
  ['blob:', 'blob:https://ocupilot.example/00000000-0000-0000-0000-000000000000'],
  ['file:', 'file:///etc/passwd'],
]) {
  test(`a ${name} link scheme renders as text -- no a node, only the link label`, () => {
    const nodes = parse(`[bad](${href})`);
    assert.equal(findFirst(nodes, (n) => n.tag === 'a'), null, `expected no <a> for a ${name} href`);
    assert.equal(textOf(nodes), 'bad');
  });
}

test('a fenced sql block highlights', () => {
  const nodes = parse('```sql\nSELECT 1 -- c\n```');
  const code = findFirst(nodes, (n) => n.tag === 'code');
  assert.ok(code, 'expected a code node');
  assert.ok(code.classes.includes('language-sql'));
  const classesUnder = collectClasses(code.children);
  assert.ok(classesUnder.includes('hljs-keyword'), `expected hljs-keyword among ${JSON.stringify(classesUnder)}`);
  assert.ok(classesUnder.includes('hljs-comment'), `expected hljs-comment among ${JSON.stringify(classesUnder)}`);
  assert.equal(textOf(code.children), 'SELECT 1 -- c');
});

// Mutation (Rule 19): narrow HLJS_CLASS_RE back to `[a-z0-9-]*` (excluding `_`) -> this goes
// red, since highlight.js's own `built_in` scope name is unreachable without the underscore.
test('a highlighted built-in function keeps its hljs-built_in class -- the allow-list admits the underscore', () => {
  const nodes = parse('```sql\nSELECT UPPER(name) FROM t\n```');
  const code = findFirst(nodes, (n) => n.tag === 'code');
  assert.ok(code, 'expected a code node');
  const classesUnder = collectClasses(code.children);
  assert.ok(classesUnder.includes('hljs-built_in'), `expected hljs-built_in among ${JSON.stringify(classesUnder)}`);
});

test('a fenced block tagged with an unregistered language renders plain, unhighlighted', () => {
  const nodes = parse('```objectscript\nSet x=1\n```');
  const code = findFirst(nodes, (n) => n.tag === 'code');
  assert.ok(code);
  assert.ok(!code.classes.some((c) => c.startsWith('language-')), 'objectscript is not one of the four registered names');
  assert.equal(code.children.length, 1);
  assert.equal(code.children[0].kind, 'text');
  assert.equal(code.children[0].text, 'Set x=1');
});

test('an oversized code block renders as plain text on the code surface, unhighlighted', () => {
  const body = 'x'.repeat(20001);
  const nodes = parse('```sql\n' + body + '\n```');
  const code = findFirst(nodes, (n) => n.tag === 'code');
  assert.ok(code);
  assert.equal(code.children.length, 1);
  assert.equal(code.children[0].kind, 'text');
  assert.equal(code.children[0].text, body);
});

test('an inline code span is a code element with no href and no click target', () => {
  const nodes = parse('Selecting `Task-001` and `Task-002`.');
  const spans = [];
  (function collect(list) {
    for (const n of list) {
      if (n.kind === 'element' && n.tag === 'code') spans.push(n);
      if (n.kind === 'element') collect(n.children);
    }
  })(nodes);
  assert.equal(spans.length, 2);
  for (const span of spans) {
    assert.equal(span.href, undefined);
    assert.ok(span.classes.includes('ocu-reply-code-inline'));
  }
  assert.equal(textOf([spans[0]]), 'Task-001');
  assert.equal(findFirst(nodes, (n) => n.tag === 'a'), null, 'no link and no chip -- Epic 11 territory');
});

test('entities and specials render as their exact literal characters', () => {
  const nodes = parse('5 < 6 && "x"');
  assert.equal(textOf(nodes), '5 < 6 && "x"');
});

test('lists, blockquote and emphasis map onto their semantic elements', () => {
  const nodes = parse('- a\n- b');
  assert.equal(nodes[0].tag, 'ul');
  assert.equal(nodes[0].children.length, 2);
  assert.ok(nodes[0].children.every((li) => li.tag === 'li'));

  const ordered = parse('1. a\n2. b');
  assert.equal(ordered[0].tag, 'ol');

  const quote = parse('> q');
  assert.equal(quote[0].tag, 'blockquote');

  const emphasis = parse('**b** *i* ~~s~~');
  assert.equal(findFirst(emphasis, (n) => n.tag === 'strong').children[0].text, 'b');
  assert.equal(findFirst(emphasis, (n) => n.tag === 'em').children[0].text, 'i');
  assert.equal(findFirst(emphasis, (n) => n.tag === 'del').children[0].text, 's');
});

test('a heading renders as a classed paragraph, never an h1-h6 tag', () => {
  const nodes = parse('## Users');
  assert.equal(nodes.length, 1);
  assert.equal(nodes[0].tag, 'p');
  assert.ok(nodes[0].classes.includes('ocu-reply-heading-2'));
  assert.equal(textOf(nodes), 'Users');
});

test('a GFM table renders as its literal source text (D7)', () => {
  const src = '| a | b |\n|---|---|\n| 1 | 2 |';
  const nodes = parse(src);
  assert.equal(textOf(nodes), src);
  assert.equal(findFirst(nodes, (n) => n.tag !== 'p'), null, 'wrapped as a plain paragraph, nothing table-shaped');
});

test('an empty reply produces no nodes', () => {
  assert.deepEqual(parse(''), []);
});

test('a whitespace-only reply produces no nodes', () => {
  assert.deepEqual(parse('   \n\n  '), []);
});

// Every class a parse emits comes from one of three sources this module controls -- its own
// `ocu-reply-*` literals, `language-<one of the four>`, and the `hljs-*` names the four
// registered grammars emit -- so NO reachable input produces a class the filter rejects. Reading
// back the classes a parse emitted therefore cannot tell `isAllowedClass` from a no-op: deleting
// `filterClasses` left the whole suite green. The filter is pinned directly instead.
// Mutation (Rule 19): make `isAllowedClass` return `true` unconditionally -> the rejection half
// below goes red on every name.
test('isAllowedClass admits exactly the three allow-listed shapes and rejects everything else', () => {
  for (const name of ['ocu-reply-pre', 'ocu-reply-code-inline', 'ocu-reply-heading-2', 'ocu-reply-source']) {
    assert.ok(isAllowedClass(name), `expected the allow-list to admit ${name}`);
  }
  // highlight.js's own scope vocabulary uses `_` (`hljs-built_in`), which `_components.scss` styles.
  for (const name of ['hljs-keyword', 'hljs-comment', 'hljs-built_in', 'hljs-meta-string']) {
    assert.ok(isAllowedClass(name), `expected the allow-list to admit ${name}`);
  }
  for (const name of ['language-sql', 'language-json', 'language-xml', 'language-bash']) {
    assert.ok(isAllowedClass(name), `expected the allow-list to admit ${name}`);
  }
  for (const name of [
    'language-javascript', // a grammar this release does not vendor
    'hljs', // highlight.js's own root class, which this module never wants
    'built_in', // an un-prefixed scope name
    'ocu-panel-message-agent', // a real OcuPilot class from outside the reply
    'ocu-reply-', // the prefix with no name after it
    'Ocu-Reply-Pre', // the allow-list is case-sensitive
    'evil',
    '',
  ]) {
    assert.ok(!isAllowedClass(name), `expected the allow-list to reject ${JSON.stringify(name)}`);
  }
});

test('every class a real parse emits is one the allow-list admits', () => {
  const nodes = parse('```sql\nSELECT UPPER(name) FROM t -- c\n```');
  const classes = collectClasses(nodes);
  assert.ok(classes.length > 0, 'expected the fixture to emit at least one class');
  for (const name of classes) {
    assert.ok(isAllowedClass(name), `unexpected class in the allow-list-filtered output: ${name}`);
  }
});

test('parseReply never returns an element whose tag is outside the closed set', () => {
  const nodes = parse(
    [
      'Here **is** a *whole* reply with a [link](https://x.example/p), an image ![a](/ocupilot/a.png),',
      '',
      '- a list',
      '- with `code`',
      '',
      '> and a quote',
      '',
      '```json',
      '{"a":1}',
      '```',
    ].join('\n')
  );
  const tags = collectTags(nodes);
  for (const tag of tags) {
    assert.ok(REPLY_TAGS.includes(tag), `tag "${tag}" is outside REPLY_TAGS`);
  }
});

test('a 70,000-character reply is bounded rather than pathological', () => {
  const started = Date.now();
  const huge = 'word '.repeat(14000);
  assert.equal(huge.length, 70000);
  const nodes = parse(huge);
  assert.ok(nodes.length > 0);
  const elapsedMs = Date.now() - started;
  assert.ok(elapsedMs < 5000, `parseReply took ${elapsedMs}ms on a 70,000-character reply`);
});

// "Nested/deep ... reply not degrading into markup": a deeply nested blockquote is the shape a
// hostile or malformed reply could take, and every recursive walk in this module (blockquote
// children, list items, lowlight's hast tree) must bound rather than crash or balloon into an
// unbounded/unmodelled node. 200 levels is comfortably past anything an agent reply would
// plausibly nest (a code review; the fixture generator; a quoted quoted quote), and stays well
// under Node's default stack depth. Mutation (Rule 19): make `blockTokenToNodes`'s `blockquote`
// case return `[textNode(rawTextOf(token))]` instead of recursing into `blockTokensToNodes` ->
// the "every level nests" assertion goes red (only one blockquote tag would appear, not 200).
test('a deeply nested blockquote parses without crashing, and every level nests as its own blockquote', () => {
  const depth = 200;
  const src = '> '.repeat(depth) + 'deep text';
  const started = Date.now();
  const nodes = parse(src);
  const elapsedMs = Date.now() - started;
  assert.ok(elapsedMs < 5000, `parseReply took ${elapsedMs}ms on a ${depth}-level nested blockquote`);

  let levels = 0;
  let cursor = nodes;
  while (cursor.length === 1 && cursor[0].kind === 'element' && cursor[0].tag === 'blockquote') {
    levels += 1;
    cursor = cursor[0].children;
  }
  assert.equal(levels, depth, `expected ${depth} nested blockquote levels, got ${levels}`);
  assert.equal(textOf(nodes), 'deep text');
  for (const tag of collectTags(nodes)) {
    assert.ok(REPLY_TAGS.includes(tag), `tag "${tag}" is outside REPLY_TAGS at nesting depth ${depth}`);
  }
});

// 200 levels is inside the stack; the depth a reply can actually reach is not. Both `marked`'s
// lexer and this module's mapping recurse once per level, and 20,000 nested `>` is only 40,009
// characters -- under the server's reply text cap (AD-24) -- while `shell/reply.ts` builds DOM
// inside an `effect()`, where a throw leaves the reply blank and the error escapes into change
// detection. `parseReply` must answer the literal source instead of throwing.
// The depth is deliberately far past the limit rather than just past it: how many frames fit is
// a property of the host, not of this code. At 1,500 levels the lexer overflows on a developer
// machine and survives on a CI runner, which made this test pass locally and fail in CI; at
// 20,000 the lexer itself raises RangeError anywhere, so the fallback under test is the one
// that runs.
// Mutation (Rule 19): drop the try/catch in `parseReply` -> both cases below throw RangeError.
test('a pathologically nested reply renders as its own literal source rather than throwing', () => {
  for (const src of ['> '.repeat(20000) + 'deep text', '*'.repeat(20000) + 'x' + '*'.repeat(20000)]) {
    assert.ok(src.length < 65536, 'the fixture stays inside the server\'s reply text cap');
    const nodes = parse(src);
    assert.equal(nodes.length, 1, `expected one literal-source paragraph for a ${src.length}-character reply`);
    assert.equal(nodes[0].tag, 'p');
    assert.ok(nodes[0].classes.includes('ocu-reply-source'), 'the fallback keeps its own newlines and spacing');
    assert.equal(textOf(nodes), src, 'nothing is dropped: the whole reply renders as its source');
  }
});

// A GFM task list is an everyday agent construct ("- [ ] step one"), and `gfm: true` is on, so
// marked emits a `checkbox` token as the item's first child. Falling through to the block rule
// wrapped it in a `p`, putting `[ ]` on a margin-bearing line of its own above the item text.
// Mutation (Rule 19): remove the `checkbox` case from `listItemChildren` -> the marker becomes a
// `p` child of the `li` and this goes red.
test('a GFM task list keeps its marker inline with the item text, not in a paragraph of its own', () => {
  const nodes = parse('- [ ] todo\n- [x] done');
  const list = nodes[0];
  assert.equal(list.tag, 'ul');
  assert.equal(list.children.length, 2);
  for (const item of list.children) {
    assert.equal(item.tag, 'li');
    assert.equal(findFirst(item.children, (n) => n.tag === 'p'), null, 'the checkbox marker is not its own paragraph');
  }
  assert.equal(textOf(nodes), '[ ] todo[x] done');
});

// The literal-source fall-through is multi-line and carries no `br`, so the rendered text needs
// preserved whitespace -- `white-space: pre-wrap` on `ocu-reply-source` -- now that the
// container's own `pre-wrap` is gone. Without the class the table collapses to one run-on line.
// Mutation (Rule 19): drop the class from `sourceNode` -> both cases below go red.
test('a construct rendered as literal source is marked so its newlines survive', () => {
  for (const src of ['| a | b |\n|---|---|\n| 1 | 2 |', '<div>\n  <span>x</span>\n</div>']) {
    const nodes = parse(src);
    const para = findFirst(nodes, (n) => n.classes.includes('ocu-reply-source'));
    assert.ok(para, `expected an ocu-reply-source paragraph for ${JSON.stringify(src)}`);
    assert.ok(textOf([para]).includes('\n'), 'the literal source keeps its newlines in the text node');
  }
});

test('a soft line break renders as its own break node, and breaks the reply\'s textContent shape', () => {
  const nodes = parse('line one\nline two');
  const para = nodes[0];
  assert.equal(para.tag, 'p');
  const kinds = para.children.map((n) => n.kind);
  assert.ok(kinds.includes('break'), `expected a break node among ${JSON.stringify(kinds)}`);
});

// --- Story 11.4: citation chips ------------------------------------------------------------
//
// Mutation (Rule 19): let `codespanNode` answer a chip inside a link label -> "a code span inside a
// link label stays code" goes red.

const SYSTEM_CITATION = { type: 'user', scope: 'instance', id: '_SYSTEM', route: 'permissions/users', label: '_SYSTEM' };

/** Every citation node in the tree, depth-first. */
function collectCitations(nodes, out = []) {
  for (const node of nodes) {
    if (node.kind === 'citation') out.push(node);
    else if (node.kind === 'element') collectCitations(node.children, out);
  }
  return out;
}

test('a code span naming a citation becomes that citation\'s chip; one naming none stays code', () => {
  const nodes = parseReply('`_SYSTEM` holds %All and `NotARow` does not.', { origin: ORIGIN, citations: [SYSTEM_CITATION] });
  const chips = collectCitations(nodes);
  assert.equal(chips.length, 1);
  assert.equal(chips[0].citation, SYSTEM_CITATION, 'the chip carries the citation object it was given');
  const code = findFirst(nodes, (n) => n.tag === 'code');
  assert.equal(textOf([code]), 'NotARow', 'the uncited span renders as inline code');
  assert.ok(REPLY_TAGS.includes('button'), 'a chip is a button, and REPLY_TAGS admits it');
});

test('with no citations every code span stays code', () => {
  assert.equal(collectCitations(parse('`_SYSTEM`')).length, 0);
  assert.equal(collectCitations(parseReply('`_SYSTEM`', { origin: ORIGIN, citations: [] })).length, 0);
});

test('a code span inside a link label stays code', () => {
  const nodes = parseReply(`[\`_SYSTEM\`](${ORIGIN}/x)`, { origin: ORIGIN, citations: [SYSTEM_CITATION] });
  assert.equal(collectCitations(nodes).length, 0);
  const link = findFirst(nodes, (n) => n.tag === 'a');
  assert.ok(findFirst(link.children, (n) => n.tag === 'code'), 'the label keeps its code element');
});

test('a fenced block is never a chip', () => {
  const nodes = parseReply('```\n_SYSTEM\n```', { origin: ORIGIN, citations: [SYSTEM_CITATION] });
  assert.equal(collectCitations(nodes).length, 0);
});

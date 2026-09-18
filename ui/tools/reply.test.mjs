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
// - stop filtering classes through `isAllowedClass` -> "a class name outside the allow-list is
//   dropped" goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { parseReply, REPLY_TAGS } = await import(corePath('reply.ts'));

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

test('an external link carries its href and a caption of its bare host', () => {
  const nodes = parse('[docs](https://docs.example.com/p)');
  const link = findFirst(nodes, (n) => n.tag === 'a');
  assert.ok(link, 'expected an a node');
  assert.equal(link.href, 'https://docs.example.com/p');
  const caption = findFirst(link.children, (n) => n.classes.includes('ocu-reply-link-caption'));
  assert.ok(caption, 'expected a caption span');
  assert.equal(textOf(caption.children), 'docs.example.com');
  assert.equal(textOf(link.children), 'docsdocs.example.com');
});

// The host caption is an external-link warning (AC4); a same-origin link needs none.
// Mutation (Rule 19): drop the `isSameOriginUrl` guard in `linkNodes` -> this goes red, finding
// a caption span (and the origin's own hostname repeated as text) on an in-app link.
test('a same-origin link carries no host caption', () => {
  const nodes = parse('[namespaces](/ocupilot/namespaces)');
  const link = findFirst(nodes, (n) => n.tag === 'a');
  assert.ok(link, 'expected an a node');
  assert.equal(link.href, '/ocupilot/namespaces');
  assert.equal(findFirst(link.children, (n) => n.classes.includes('ocu-reply-link-caption')), null, 'expected no caption span');
  assert.equal(textOf(link.children), 'namespaces');
});

test('a hostile scheme renders as text -- no a node, only the link label', () => {
  const nodes = parse('[bad](javascript:alert(1))');
  assert.equal(findFirst(nodes, (n) => n.tag === 'a'), null);
  assert.equal(textOf(nodes), 'bad');
});

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

test('a class name outside the allow-list is dropped', () => {
  const nodes = parse('```sql\nSELECT 1\n```');
  const classes = collectClasses(nodes);
  for (const name of classes) {
    assert.ok(
      /^ocu-reply-[a-z0-9-]+$/.test(name) || /^hljs-[a-z0-9-]+$/.test(name) || /^language-(sql|json|xml|bash)$/.test(name),
      `unexpected class in the allow-list-filtered output: ${name}`
    );
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

test('a soft line break renders as its own break node, and breaks the reply\'s textContent shape', () => {
  const nodes = parse('line one\nline two');
  const para = nodes[0];
  assert.equal(para.tag, 'p');
  const kinds = para.children.map((n) => n.kind);
  assert.ok(kinds.includes('break'), `expected a break node among ${JSON.stringify(kinds)}`);
});

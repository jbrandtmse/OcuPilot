/**
 * Parses an agent reply into a plain-data node tree (Story 4.6, EXPERIENCE.md/DESIGN.md
 * `message-agent`), which `shell/reply.ts` builds DOM from.
 *
 * **No HTML string is ever produced or parsed here** (AD-11 rule 4, AD-33): `marked`'s `Lexer`
 * yields tokens, this module maps them onto `ReplyNode`s -- text, a soft line break, or an
 * element from the closed `ReplyTag` set with an allow-listed class list -- and the caller turns
 * that tree into DOM with `createElement`/`textContent`. A raw-HTML token's source text is never
 * treated as markup: it renders as a plain text node, character for character.
 *
 * **Framework-free and DOM-free** (AD-19): no `@angular/core` import, no `document`, no
 * `location`. The origin a link or image is judged against arrives as `options.origin`.
 *
 * **Nothing rendered here may cause a request to any host.** An image node is produced only for
 * a same-origin `src`; anything else renders as its alt text, or its literal source when the alt
 * text is empty. A link node is produced only for an `http:`/`https:` `href`; anything else
 * renders as its label text, as if the link markup were never there. Nothing here fetches
 * anything itself -- this module only decides what `shell/reply.ts` is allowed to build.
 *
 * **Nothing is silently dropped.** A block or inline construct this module does not model (a GFM
 * table, a thematic break, a link-reference definition) renders as its literal source text.
 *
 * **Highlighting** comes from `lowlight`, which answers a hast tree -- plain objects, `element`s
 * and `text`s, never an HTML string -- for exactly the four registered languages (`sql`, `json`,
 * `xml`, `bash`). A fence over `HIGHLIGHT_CEILING` characters, or one tagged with any other
 * language, renders unhighlighted on the same code surface; `lowlight.highlight` throws on an
 * unregistered language, so every call is guarded by `lowlight.registered()` first.
 */

import { Lexer } from 'marked';
import type { Token, Tokens } from 'marked';
import { createLowlight } from 'lowlight';
import type { RootContent as HastRootContent } from 'hast';
import bash from 'highlight.js/lib/languages/bash';
import json from 'highlight.js/lib/languages/json';
import sql from 'highlight.js/lib/languages/sql';
import xml from 'highlight.js/lib/languages/xml';

/** The closed set of element tags `parseReply` ever produces (AD-11 rule 4, AD-33). */
export type ReplyTag =
  | 'p'
  | 'strong'
  | 'em'
  | 'del'
  | 'ul'
  | 'ol'
  | 'li'
  | 'blockquote'
  | 'code'
  | 'pre'
  | 'a'
  | 'img'
  | 'span';

/**
 * Every tag a built reply may ever contain, `br` included (its own `ReplyNode` kind, not a
 * `ReplyTag`, but still a real DOM tag the caller's sanitizer allow-list must cover).
 */
export const REPLY_TAGS: readonly string[] = [
  'p',
  'strong',
  'em',
  'del',
  'ul',
  'ol',
  'li',
  'blockquote',
  'code',
  'pre',
  'a',
  'img',
  'span',
  'br',
];

/** A plain-data reply node. No HTML string is ever produced from this tree (AD-11 rule 4). */
export type ReplyNode =
  | { readonly kind: 'text'; readonly text: string }
  | { readonly kind: 'break' }
  | {
      readonly kind: 'element';
      readonly tag: ReplyTag;
      readonly classes: readonly string[];
      readonly href?: string;
      readonly src?: string;
      readonly alt?: string;
      readonly children: readonly ReplyNode[];
    };

export interface ParseReplyOptions {
  /** The instance's own origin (e.g. `location.origin`), judged against every link and image. */
  readonly origin: string;
}

/** A fenced code block longer than this renders unhighlighted (Design Notes, Performance). */
const HIGHLIGHT_CEILING = 20000;

/** Exactly the four grammars this release vendors (NFR-10, AD-47: no runtime-fetched grammar). */
const REGISTERED_LANGUAGES = ['sql', 'json', 'xml', 'bash'] as const;

const lowlight = createLowlight();
lowlight.register({ sql, json, xml, bash });

const OCU_CLASS_RE = /^ocu-reply-[a-z][a-z0-9-]*$/;
// Underscore included: highlight.js's own scope vocabulary uses it (verified against the
// installed grammars -- `sql`'s and `bash`'s `built_in` scope both emit the literal class
// `hljs-built_in`, which `_components.scss` already styles). A narrower `[a-z0-9-]*` here would
// silently strip that class from every SQL built-in function and Bash built-in command.
const HLJS_CLASS_RE = /^hljs-[a-z][a-z0-9_-]*$/;
const LANGUAGE_CLASSES: ReadonlySet<string> = new Set(REGISTERED_LANGUAGES.map((lang) => `language-${lang}`));

/** The closed class allow-list: `ocu-reply-*`, the `hljs-*` names the registered grammars emit,
 * and `language-<name>` for exactly the four registered names. Anything else is dropped. */
function isAllowedClass(name: string): boolean {
  return OCU_CLASS_RE.test(name) || HLJS_CLASS_RE.test(name) || LANGUAGE_CLASSES.has(name);
}

function filterClasses(names: readonly string[]): readonly string[] {
  return names.filter(isAllowedClass);
}

function elementNode(
  tag: ReplyTag,
  classes: readonly string[],
  children: readonly ReplyNode[],
  extra: { href?: string; src?: string; alt?: string } = {}
): ReplyNode {
  return { kind: 'element', tag, classes: filterClasses(classes), children, ...extra };
}

function textNode(value: string): ReplyNode {
  return { kind: 'text', text: value };
}

const BREAK_NODE: ReplyNode = { kind: 'break' };

/** Resolves `href` against `origin`; `null` for anything the URL parser refuses. */
function resolveUrl(href: string, origin: string): URL | null {
  try {
    return new URL(href, origin);
  } catch {
    return null;
  }
}

/** A link is safe to render only over `http:` or `https:`, resolved against `origin`. */
function isAllowedLinkUrl(href: string, origin: string): boolean {
  const url = resolveUrl(href, origin);
  return url !== null && (url.protocol === 'http:' || url.protocol === 'https:');
}

/** An image renders only from the instance's own origin -- never a third party. */
function isSameOriginUrl(href: string, origin: string): boolean {
  const url = resolveUrl(href, origin);
  return url !== null && url.origin === origin;
}

/** Every inline token type this module models by name, so an unlisted type falls to the raw-text rule. */
function inlineTokenToNodes(token: Token, origin: string): readonly ReplyNode[] {
  switch (token.type) {
    case 'text': {
      const withTokens = token as Tokens.Text;
      if (withTokens.tokens !== undefined) return inlineTokensToNodes(withTokens.tokens, origin);
      return [textNode(withTokens.text)];
    }
    case 'escape':
      return [textNode((token as Tokens.Escape).text)];
    case 'strong':
      return [elementNode('strong', [], inlineTokensToNodes((token as Tokens.Strong).tokens, origin))];
    case 'em':
      return [elementNode('em', [], inlineTokensToNodes((token as Tokens.Em).tokens, origin))];
    case 'del':
      return [elementNode('del', [], inlineTokensToNodes((token as Tokens.Del).tokens, origin))];
    case 'codespan':
      return [elementNode('code', ['ocu-reply-code-inline'], [textNode((token as Tokens.Codespan).text)])];
    case 'br':
      return [BREAK_NODE];
    case 'link':
      return linkNodes(token as Tokens.Link, origin);
    case 'image':
      return [imageNode(token as Tokens.Image, origin)];
    case 'html':
      return [textNode((token as Tokens.Tag).raw)];
    default:
      // Nothing is silently dropped: an inline construct this module does not model (a future
      // marked/GFM extension) renders as its own literal source text.
      return [textNode(rawTextOf(token))];
  }
}

function inlineTokensToNodes(tokens: readonly Token[], origin: string): readonly ReplyNode[] {
  return tokens.flatMap((token) => inlineTokenToNodes(token, origin));
}

function rawTextOf(token: Token): string {
  const generic = token as { raw?: string; text?: string };
  return generic.raw ?? generic.text ?? '';
}

function linkNodes(token: Tokens.Link, origin: string): readonly ReplyNode[] {
  const label = inlineTokensToNodes(token.tokens, origin);
  if (!isAllowedLinkUrl(token.href, origin)) {
    // A hostile scheme is not "an unmodelled token": the link is understood, and rejected. Only
    // the label renders, as if the link markup were never there (I/O matrix, Hostile scheme row).
    return label;
  }
  // The host caption is an external-link warning (AC4: "given a reply holding an external
  // link... the full host follows the link text as caption") -- a same-origin link needs no such
  // warning, and would otherwise repeat the instance's own hostname next to every in-app link.
  if (isSameOriginUrl(token.href, origin)) {
    return [elementNode('a', [], label, { href: token.href })];
  }
  const host = resolveUrl(token.href, origin)?.hostname ?? '';
  const caption = elementNode('span', ['ocu-reply-link-caption'], [textNode(host)]);
  return [elementNode('a', [], [...label, caption], { href: token.href })];
}

function imageNode(token: Tokens.Image, origin: string): ReplyNode {
  if (isSameOriginUrl(token.href, origin)) {
    return elementNode('img', [], [], { src: token.href, alt: token.text });
  }
  // A remote image never becomes an <img> -- rendering strictly fewer things needs no CSP
  // widening (Design Notes D4). Its alt text renders instead; an empty alt falls back to the
  // image's own literal source, per the I/O matrix, so nothing is silently dropped either way.
  return textNode(token.text !== '' ? token.text : token.raw);
}

/** Maps a `list_item`'s own `tokens` entry: a tight item's inline wrapper renders inline. */
function listItemChildren(token: Token, origin: string): readonly ReplyNode[] {
  if (token.type === 'text') {
    const withTokens = token as Tokens.Text;
    if (withTokens.tokens !== undefined) return inlineTokensToNodes(withTokens.tokens, origin);
    return [textNode(withTokens.text)];
  }
  return blockTokenToNodes(token, origin);
}

/** Every block token type this module models by name; an unlisted type falls to the raw-text rule. */
function blockTokenToNodes(token: Token, origin: string): readonly ReplyNode[] {
  switch (token.type) {
    case 'space':
      return [];
    case 'paragraph':
      return [elementNode('p', [], inlineTokensToNodes((token as Tokens.Paragraph).tokens, origin))];
    case 'heading': {
      const heading = token as Tokens.Heading;
      return [
        elementNode('p', [`ocu-reply-heading-${heading.depth}`], inlineTokensToNodes(heading.tokens, origin)),
      ];
    }
    case 'blockquote':
      return [elementNode('blockquote', [], blockTokensToNodes((token as Tokens.Blockquote).tokens, origin))];
    case 'list': {
      const list = token as Tokens.List;
      const items = list.items.map((item) => elementNode('li', [], item.tokens.flatMap((t) => listItemChildren(t, origin))));
      return [elementNode(list.ordered ? 'ol' : 'ul', [], items)];
    }
    case 'code':
      return [codeBlockNode(token as Tokens.Code)];
    case 'html':
      // A raw-HTML block is text, never markup: one paragraph carrying its literal source
      // (I/O matrix, Raw HTML row).
      return [elementNode('p', [], [textNode((token as Tokens.HTML).raw)])];
    default:
      // Nothing is silently dropped: a block construct this module does not model (a GFM table,
      // a thematic break, a link-reference definition) renders as its own literal source text,
      // wrapped the same way a raw-HTML block is (D7).
      return [elementNode('p', [], [textNode(rawTextOf(token))])];
  }
}

function blockTokensToNodes(tokens: readonly Token[], origin: string): readonly ReplyNode[] {
  return tokens.flatMap((token) => blockTokenToNodes(token, origin));
}

/** A registered language name, or `null` when `lang` is not one of the four this release vendors. */
function registeredLanguageOf(lang: string | undefined): string | null {
  if (lang === undefined) return null;
  const bare = lang.split(/\s+/)[0]?.toLowerCase() ?? '';
  return REGISTERED_LANGUAGES.includes(bare as (typeof REGISTERED_LANGUAGES)[number]) ? bare : null;
}

/**
 * Maps one lowlight hast node into a `ReplyNode`, recursively. Lowlight documents that it emits
 * only `element` and `text` nodes; a `comment`/`doctype` node is unreachable from `highlight()`
 * but is handled for type-exhaustiveness by rendering nothing, rather than by an assertion that
 * would throw on a highlighter upgrade this module does not control.
 */
function hastNodeToReplyNode(node: HastRootContent): ReplyNode {
  switch (node.type) {
    case 'text':
      return textNode(node.value);
    case 'element': {
      const raw = node.properties['className'];
      const classNames = Array.isArray(raw) ? raw.map(String) : [];
      return elementNode('span', classNames, node.children.map(hastNodeToReplyNode));
    }
    default:
      return textNode('');
  }
}

function codeBlockNode(token: Tokens.Code): ReplyNode {
  const lang = registeredLanguageOf(token.lang);
  const classes = lang === null ? [] : [`language-${lang}`];
  const canHighlight = lang !== null && lowlight.registered(lang) && token.text.length <= HIGHLIGHT_CEILING;
  const children: readonly ReplyNode[] = canHighlight
    ? lowlight.highlight(lang as string, token.text).children.map(hastNodeToReplyNode)
    : [textNode(token.text)];
  const code = elementNode('code', ['ocu-reply-code-block', ...classes], children);
  return elementNode('pre', ['ocu-reply-pre'], [code]);
}

/**
 * Parses `text` into a plain-data node tree. A fresh `Lexer` is created for every call: the
 * class accumulates tokens across calls on the same instance, and reusing one would leak an
 * earlier reply's tokens into a later parse.
 */
export function parseReply(text: string, options: ParseReplyOptions): readonly ReplyNode[] {
  if (text === '') return [];
  const lexer = new Lexer({ gfm: true, breaks: true });
  const tokens = lexer.lex(text);
  return blockTokensToNodes(tokens, options.origin);
}

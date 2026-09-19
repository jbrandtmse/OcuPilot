import { ChangeDetectionStrategy, Component, computed, effect, input, viewChild, type ElementRef } from '@angular/core';
import DOMPurify from 'dompurify';

import { REPLY_TAGS, parseReply, type ReplyNode } from '../core/reply';

/**
 * Exactly what the builder ever writes (Boundaries & Constraints). `rel` is here alongside the
 * spec's own four -- every `<a>` this module builds carries `rel="noopener noreferrer nofollow"`
 * (Design Notes D5), and DOMPurify drops any attribute name absent from this list regardless of
 * what wrote it, `rel` included; omitting it would have the sanitizer undo D5 on every link.
 */
const ALLOWED_ATTR: readonly string[] = ['class', 'href', 'src', 'alt', 'rel'];

/**
 * `http:`/`https:` absolute, or anything with no scheme at all (a relative or root-relative
 * path) -- the same shape `core/reply.ts`'s own link/image policy admits. Mirrors DOMPurify
 * 3.4.15's own default `ALLOWED_URI_REGEXP` with the extra schemes it also allows (`mailto:`,
 * `tel:`, `callto:`, `sms:`, `cid:`, `xmpp:`, `matrix:`) removed: this reply never produces them,
 * so the sanitizer's second gate should not admit them either.
 */
const ALLOWED_URI_REGEXP = /^(?:https?:|[^a-z]|[a-z][a-z0-9+.-]*(?:[^a-z0-9+.:-]|$))/i;

/**
 * Builds one DOM node from a `ReplyNode` -- `createElement`/`textContent` only, never
 * `innerHTML` and never a template string (AD-11 rule 4, AD-33). The class list, and every
 * `href`/`src`/`alt`, are exactly what `core/reply.ts` decided; this function makes no rendering
 * decision of its own.
 */
function buildNode(doc: Document, node: ReplyNode): Node {
  if (node.kind === 'text') return doc.createTextNode(node.text);
  if (node.kind === 'break') return doc.createElement('br');
  const el = doc.createElement(node.tag);
  if (node.classes.length > 0) el.className = node.classes.join(' ');
  if (node.href !== undefined) el.setAttribute('href', node.href);
  if (node.src !== undefined) el.setAttribute('src', node.src);
  if (node.alt !== undefined) el.setAttribute('alt', node.alt);
  // rel carries even though DOMPurify would also strip a bare target -- "inert" is the link's
  // own contract, not only what the sanitizer happens to remove (Design Notes D5).
  if (node.tag === 'a') el.setAttribute('rel', 'noopener noreferrer nofollow');
  for (const child of node.children) el.appendChild(buildNode(doc, child));
  return el;
}

/** Builds every root-level node into one fragment, so the caller appends it in a single mutation. */
export function buildReplyFragment(doc: Document, nodes: readonly ReplyNode[]): DocumentFragment {
  const fragment = doc.createDocumentFragment();
  for (const node of nodes) fragment.appendChild(buildNode(doc, node));
  return fragment;
}

/**
 * Runs DOMPurify's in-place pass over an already-built root -- the vendored sanitizer, and a
 * second gate over a tree `core/reply.ts` already built from a closed tag and class allow-list
 * (Design Notes D1: arguably redundant over a tree this module built itself, but AC2 names a
 * sanitizer among the three vendored artifacts).
 *
 * **`IN_PLACE` requires an `Element`.** A `DocumentFragment` throws ("'get attributes' called on
 * an object that is not a valid instance of Element", verified against 3.4.15), so this takes the
 * render root -- a plain `<span>`, always in `core/reply.ts`'s own `REPLY_TAGS` -- rather than the
 * fragment that was appended into it, or the component's own custom-element host tag.
 */
export function sanitizeReplyRoot(root: Element): void {
  DOMPurify.sanitize(root, {
    IN_PLACE: true,
    ALLOWED_TAGS: [...REPLY_TAGS],
    ALLOWED_ATTR: [...ALLOWED_ATTR],
    ALLOW_DATA_ATTR: false,
    ALLOWED_URI_REGEXP,
  });
}

/**
 * Renders one agent reply as sanitized, highlighted, offline Markdown (Story 4.6,
 * EXPERIENCE.md/DESIGN.md `message-agent`).
 *
 * **Framework glue only.** Every rendering decision -- the tag and class allow-lists, the URL
 * policy, the 20,000-character highlight ceiling -- lives in `core/reply.ts`; this component
 * turns its plain-data tree into DOM and nothing else.
 *
 * **Parsed once per distinct `text`, and built once per parse.** `nodes` is a `computed()` over
 * `parseReply`, which Angular's signal equality already memoizes against the unchanged string the
 * panel's `turns` getter (Story 4.5) hands it on every change-detection pass; the `effect()` that
 * builds and sanitizes the DOM runs only when `nodes` itself changes, never on a pass that read
 * the same reply again.
 *
 * **One mutation, one announcement.** The whole subtree is built off-DOM into a
 * `DocumentFragment` and appended to the render root in a single `appendChild`, so the panel's
 * `role="log"` transcript announces the reply once, not once per top-level block.
 */
@Component({
  selector: 'app-reply',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<span #root></span>`,
})
export class Reply {
  readonly text = input<string | null>(null);

  private readonly rootEl = viewChild.required<ElementRef<HTMLSpanElement>>('root');

  private readonly nodes = computed((): readonly ReplyNode[] => {
    const value = this.text();
    if (value === null || value === '') return [];
    return parseReply(value, { origin: location.origin });
  });

  constructor() {
    effect(() => {
      const nodes = this.nodes();
      const root = this.rootEl().nativeElement;
      root.textContent = '';
      if (nodes.length === 0) return;
      root.appendChild(buildReplyFragment(root.ownerDocument, nodes));
      sanitizeReplyRoot(root);
    });
  }
}

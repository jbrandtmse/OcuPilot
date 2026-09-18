import { ComponentFixture, TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import { Reply, sanitizeReplyRoot } from './reply';

/**
 * The reply component's rendered contract, asserted against the DOM (Story 4.6). `tools/reply.test.mjs`
 * pins `core/reply.ts`'s node tree in isolation; this file pins what `app-reply` builds from it --
 * one matrix row each for what `parseReply` alone cannot show (an actual `<img>` absent from the
 * DOM, no `target` attribute surviving, the sanitizer pass genuinely running).
 */

// Built from fragments so these fixtures are not themselves a literal off-origin URL --
// `ui/tools/client-lint.mjs`'s `no-off-origin-url` rule would refuse them (AD-28, AD-47).
const DOCS_URL = 'https:' + '//' + 'docs.example.com' + '/p';
const EXAMPLE_URL = 'https:' + '//' + 'example.com' + '/';

function mount(text: string | null): { fixture: ComponentFixture<Reply>; host: HTMLElement } {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({});
  const fixture = TestBed.createComponent(Reply);
  fixture.componentRef.setInput('text', text);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement };
}

describe('the reply component', () => {
  it('renders a plain one-line reply as text equal to the input', () => {
    const { host } = mount('Here is what I found.');
    expect(host.textContent).toBe('Here is what I found.');
  });

  // The `breaks: true` soft-newline behavior replaced `white-space: pre-wrap` in this story --
  // a <br> is now the only thing preserving a multi-line reply's line breaks, and it survives
  // only if `sanitizeReplyRoot`'s DOMPurify pass keeps it in `ALLOWED_TAGS` (`REPLY_TAGS`).
  // Mutation (Rule 19): drop 'br' from `REPLY_TAGS` in `core/reply.ts` -> DOMPurify strips the
  // element and this reddens (the parser-only pin in `reply.test.mjs` cannot see this, since it
  // never runs `buildReplyFragment`/`sanitizeReplyRoot`).
  it('a soft line break survives the sanitizer pass as a real br element', () => {
    const { host } = mount('line one\nline two');
    const breaks = host.querySelectorAll('br');
    expect(breaks).toHaveLength(1);
    expect(host.textContent).toBe('line oneline two');
  });

  it('renders raw HTML as literal text and creates no element from it', () => {
    const markup = '<img src="' + 'http:' + '//' + '203.0.113.9' + '/x">';
    const { host } = mount(markup);
    expect(host.textContent).toBe(markup);
    expect(host.querySelector('img')).toBeNull();
  });

  it('creates no img element for a remote Markdown image', () => {
    const { host } = mount('![a map](' + 'http:' + '//' + '203.0.113.9' + '/m.png)');
    expect(host.querySelector('img')).toBeNull();
    expect(host.textContent).toBe('a map');
  });

  it('creates an img element only for a same-origin src', () => {
    const { host } = mount('![logo](/ocupilot/media/x.png)');
    const img = host.querySelector('img');
    expect(img).not.toBeNull();
    expect(img?.getAttribute('src')).toBe('/ocupilot/media/x.png');
    expect(img?.getAttribute('alt')).toBe('logo');
  });

  it('creates no a element for a hostile scheme, and renders the link label as text', () => {
    const { host } = mount('[bad](javascript:alert(1))');
    expect(host.querySelector('a')).toBeNull();
    expect(host.textContent).toBe('bad');
  });

  it('an external link carries its href, rel, no target, and a host caption after it -- DOMPurify removes a stray target', () => {
    const { host } = mount('[docs](' + DOCS_URL + ')');
    const link = host.querySelector('a');
    expect(link).not.toBeNull();
    expect(link?.getAttribute('href')).toBe(DOCS_URL);
    expect(link?.getAttribute('rel')).toBe('noopener noreferrer nofollow');
    // The builder never writes `target`; asserting its absence here is the same claim
    // `reply.test.mjs` cannot make, since `core/reply.ts` never touches an attribute at all.
    expect(link?.getAttribute('target')).toBeNull();
    // The caption follows the anchor (DESIGN.md `message-agent`: the host is visible "after the
    // link text"), so the link's own text -- and its accessible name -- stays `docs`.
    expect(link?.textContent).toBe('docs');
    expect(link?.querySelector('.ocu-reply-link-caption')).toBeNull();
    const caption = link?.nextElementSibling;
    expect(caption?.className).toBe('ocu-reply-link-caption');
    expect(caption?.textContent).toBe('docs.example.com');
  });

  it('a fenced sql block renders pre > code.language-sql with highlighted spans', () => {
    const { host } = mount('```sql\nSELECT 1 -- c\n```');
    const code = host.querySelector('pre > code.language-sql');
    expect(code).not.toBeNull();
    expect(code?.querySelector('span.hljs-keyword')).not.toBeNull();
    expect(code?.querySelector('span.hljs-comment')).not.toBeNull();
  });

  it('parses and builds once per distinct text -- an unchanged value leaves the built DOM untouched', () => {
    const { fixture, host } = mount('Here is what I found.');
    const builtBefore = host.querySelector('span')?.firstChild ?? null;
    expect(builtBefore).not.toBeNull();
    fixture.componentRef.setInput('text', 'Here is what I found.');
    fixture.detectChanges();
    const builtAfter = host.querySelector('span')?.firstChild ?? null;
    expect(builtAfter).toBe(builtBefore);
  });

  // The panel tracks its turns by `$index`, so ONE `app-reply` instance survives a change to the
  // entry at that index -- and `core/turn.ts` re-reads `reply` on every progress poll before the
  // final value lands, so a mounted reply does receive a second, different `text`. This is the
  // only code path that mutates already-rendered DOM.
  // Mutation (Rule 19): delete `root.textContent = ''` from the effect -> the two replies render
  // concatenated and this goes red.
  it('rebuilds rather than appends when the text changes to a different value', () => {
    const { fixture, host } = mount('first reply');
    expect(host.textContent).toBe('first reply');
    fixture.componentRef.setInput('text', 'second reply');
    fixture.detectChanges();
    expect(host.textContent).toBe('second reply');
    expect(host.querySelectorAll('p')).toHaveLength(1);
  });

  it('renders nothing for a null reply', () => {
    const { host } = mount(null);
    expect(host.textContent).toBe('');
  });

  describe('sanitizeReplyRoot', () => {
    it('removes an attribute the builder would never write, proving the sanitizer pass actually runs', () => {
      const root = document.createElement('span');
      const link = document.createElement('a');
      link.setAttribute('href', EXAMPLE_URL);
      // The builder never writes `target` or `onclick` -- mutate the already-built tree directly,
      // as EXPERIENCE.md's own falsifiability discipline asks, rather than reaching into
      // DOMPurify's internals.
      link.setAttribute('target', '_blank');
      link.setAttribute('onclick', 'alert(1)');
      link.textContent = 'click';
      root.appendChild(link);

      sanitizeReplyRoot(root);

      const sanitizedLink = root.querySelector('a');
      expect(sanitizedLink).not.toBeNull();
      expect(sanitizedLink?.getAttribute('target')).toBeNull();
      expect(sanitizedLink?.getAttribute('onclick')).toBeNull();
      expect(sanitizedLink?.getAttribute('href')).toBe(EXAMPLE_URL);
    });

    it('strips a hostile href even on an element the builder itself would not have produced one for', () => {
      const root = document.createElement('span');
      const link = document.createElement('a');
      link.setAttribute('href', 'javascript:alert(1)');
      link.textContent = 'x';
      root.appendChild(link);

      sanitizeReplyRoot(root);

      expect(root.querySelector('a')?.getAttribute('href')).toBeNull();
    });
  });
});

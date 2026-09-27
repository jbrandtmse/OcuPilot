import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { STRINGS } from '../core/strings';
import { COPY_BUTTON_CLASS, COPY_STATUS_CLASS } from './copy-control';
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

// --- Story 11.4: citation chips --------------------------------------------------------------

describe('citation chips', () => {
  const cited = { type: 'user', scope: 'instance', id: '_SYSTEM', route: 'permissions/users', label: '_SYSTEM' };

  function mountCited(text: string, citations: readonly (typeof cited)[]): { fixture: ComponentFixture<Reply>; host: HTMLElement } {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({});
    const fixture = TestBed.createComponent(Reply);
    fixture.componentRef.setInput('text', text);
    fixture.componentRef.setInput('citations', citations);
    fixture.detectChanges();
    return { fixture, host: fixture.nativeElement as HTMLElement };
  }

  // Mutation (Rule 19): build the chip as an `a` with an `href` -> this goes red.
  it('a cited name is a type="button" chip carrying its label as text, no href and no data attribute', () => {
    const { host } = mountCited('`_SYSTEM` holds %All; `NotARow` does not.', [cited]);
    const chips = host.querySelectorAll('button.ocu-reply-citation');
    expect(chips).toHaveLength(1);
    const chip = chips[0] as HTMLButtonElement;
    expect(chip.getAttribute('type')).toBe('button');
    expect(chip.textContent).toBe('_SYSTEM');
    expect(chip.getAttributeNames().sort()).toEqual(['class', 'type']);
    expect(host.querySelector('a')).toBeNull();
    expect(host.querySelector('code')?.textContent).toBe('NotARow');
  });

  it('a hostile label renders literally as text and creates no element', () => {
    const hostile = { ...cited, id: '<img src=x>', label: '<img src=x>' };
    const { host } = mountCited('`<img src=x>`', [hostile]);
    const chip = host.querySelector('button.ocu-reply-citation');
    expect(chip?.textContent).toBe('<img src=x>');
    expect(host.querySelector('img')).toBeNull();
  });

  it('a click on a chip emits its citation; a click elsewhere emits nothing', () => {
    const { fixture, host } = mountCited('See `_SYSTEM` here.', [cited]);
    const emitted: unknown[] = [];
    fixture.componentInstance.cite.subscribe((value) => emitted.push(value));
    (host.querySelector('p') as HTMLElement).click();
    expect(emitted).toEqual([]);
    (host.querySelector('button.ocu-reply-citation') as HTMLButtonElement).click();
    expect(emitted).toEqual([cited]);
  });
});

// --- DW-1081: the copy control on a fenced code block ----------------------------------------

describe('a reply code block', () => {
  const restores: Array<() => void> = [];

  function stub(target: object, key: string, value: unknown): void {
    const prior = Object.getOwnPropertyDescriptor(target, key);
    Object.defineProperty(target, key, { configurable: true, writable: true, value });
    restores.push(() => {
      if (prior === undefined) {
        delete (target as Record<string, unknown>)[key];
      } else {
        Object.defineProperty(target, key, prior);
      }
    });
  }

  afterEach(() => {
    while (restores.length > 0) restores.pop()?.();
  });

  // Mutation (Rule 19): drop the `attachCopyControls(root)` call from the effect -> both tests
  // below go red.
  it('carries one copy control per block, named "Copy to clipboard", beside the pre and outside it', () => {
    const { host } = mount('```sql\nSELECT 1 -- c\n```\n\nand\n\n```\nplain\n```');
    const pres = host.querySelectorAll('pre.ocu-reply-pre');
    expect(pres).toHaveLength(2);
    const buttons = host.querySelectorAll(`button.${COPY_BUTTON_CLASS}`);
    expect(buttons).toHaveLength(2);
    for (const button of buttons) {
      expect(button.getAttribute('aria-label')).toBe(STRINGS.actionCopyToClipboard);
      expect(button.closest('pre')).toBeNull();
    }
    for (const pre of pres) {
      const frame = pre.parentElement as HTMLElement;
      expect(frame.classList.contains('ocu-code-frame')).toBe(true);
      expect(frame.querySelectorAll(`button.${COPY_BUTTON_CLASS}`)).toHaveLength(1);
    }
    // The highlighted code inside is exactly as it was built.
    expect(host.querySelector('pre > code.language-sql span.hljs-keyword')).not.toBeNull();
    // A reply with no code block carries none.
    expect(mount('no code here').host.querySelector(`button.${COPY_BUTTON_CLASS}`)).toBeNull();
  });

  it("pressing it copies exactly the block's text, and announces Copied", async () => {
    const written: string[] = [];
    stub(window, 'isSecureContext', true);
    stub(navigator, 'clipboard', {
      writeText: (text: string) => {
        written.push(text);
        return Promise.resolve();
      },
    });
    const { host } = mount('```sql\nSELECT 1 -- c\n```\n\n```\nsecond block\n```');
    const frames = host.querySelectorAll('.ocu-code-frame');
    (frames[0].querySelector('button') as HTMLButtonElement).click();
    await new Promise((resolve) => setTimeout(resolve, 0));
    const pre = frames[0].querySelector('pre') as HTMLElement;
    expect(written).toEqual([pre.textContent]);
    expect(written).toEqual(['SELECT 1 -- c']);
    expect(frames[0].querySelector(`.${COPY_STATUS_CLASS}`)?.textContent).toBe(STRINGS.copyAnnouncementCopied);
  });
});

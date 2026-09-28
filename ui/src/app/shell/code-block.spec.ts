import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it, vi } from 'vitest';

import type { DraftStep } from '../core/draft';
import { STRINGS } from '../core/strings';
import { CodeBlock } from './code-block';
import { COPY_BUTTON_CLASS, COPY_STATUS_CLASS, createCopyButton } from './copy-control';

/**
 * Pins `app-code-block` and the one copy control it shares with reply code blocks (Story 14.1,
 * DW-1081): each step is a keyboard-reachable `pre` on the code surface carrying exactly one
 * control; a press copies exactly that step's text and announces the outcome politely; the
 * selection route takes over outside a secure context or when the clipboard refuses; and a copy
 * that fails leaves the text in place and throws nothing.
 *
 * jsdom has no clipboard and no `execCommand`, so each test installs the one it needs and the
 * `afterEach` removes both.
 */

const STEPS: readonly DraftStep[] = [
  { kind: 'rest', text: "curl -u '_SYSTEM' -X PUT '<origin>/api/admin/v2/webapp?Name=%2Fcsp%2Fx'" },
  { kind: 'objectscript', text: 'Set p("Password")="<Password>"\nSet sc=##class(Security.Users).Modify("u",.p)' },
];

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

/** A secure context whose clipboard records what it was given, or refuses when `refuse` is set. */
function secureClipboard(refuse = false): string[] {
  const written: string[] = [];
  stub(window, 'isSecureContext', true);
  stub(navigator, 'clipboard', {
    writeText: (text: string) => (refuse ? Promise.reject(new Error('denied')) : (written.push(text), Promise.resolve())),
  });
  return written;
}

/** The selection route's `execCommand`, answering `answer` and recording the selected text. */
function selectionRoute(answer: boolean | 'throw'): string[] {
  const copied: string[] = [];
  stub(document, 'execCommand', (command: string) => {
    if (answer === 'throw') throw new Error('not supported');
    const active = document.activeElement;
    if (command === 'copy' && active instanceof HTMLTextAreaElement) copied.push(active.value);
    return answer;
  });
  return copied;
}

function macrotask(): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function mount(steps: readonly DraftStep[] = STEPS): HTMLElement {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({});
  const fixture = TestBed.createComponent(CodeBlock);
  fixture.componentRef.setInput('steps', steps);
  fixture.detectChanges();
  document.body.appendChild(fixture.nativeElement);
  return fixture.nativeElement as HTMLElement;
}

afterEach(() => {
  while (restores.length > 0) restores.pop()?.();
  document.body.textContent = '';
});

describe('the code block', () => {
  it('renders each step as a keyboard-reachable pre on the code surface, in order, as text', () => {
    const host = mount([...STEPS, { kind: 'rest', text: '<b>not markup</b>' }]);
    const frames = host.querySelectorAll('.ocu-code-frame');
    expect(frames).toHaveLength(3);
    const pres = [...host.querySelectorAll('pre.ocu-code-block-pre')];
    expect(pres.map((pre) => pre.getAttribute('tabindex'))).toEqual(['0', '0', '0']);
    expect(pres.map((pre) => pre.textContent)).toEqual([STEPS[0].text, STEPS[1].text, '<b>not markup</b>']);
    // AD-11: the step is text, never markup.
    expect(host.querySelector('b')).toBeNull();
    expect(frames[1].getAttribute('data-kind')).toBe('objectscript');
  });

  it('gives each step exactly one copy control, named "Copy to clipboard", and never a second', () => {
    // Mutation (Rule 19): drop the `armed` check in the effect -> the render that adds a third step
    // gives the first two a second control each, and this goes red.
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({});
    const fixture = TestBed.createComponent(CodeBlock);
    fixture.componentRef.setInput('steps', STEPS);
    fixture.detectChanges();
    fixture.componentRef.setInput('steps', [...STEPS, { kind: 'rest', text: 'third' }]);
    fixture.detectChanges();
    const host = fixture.nativeElement as HTMLElement;
    expect(host.querySelectorAll('.ocu-code-frame')).toHaveLength(3);
    for (const frame of host.querySelectorAll('.ocu-code-frame')) {
      const buttons = frame.querySelectorAll(`button.${COPY_BUTTON_CLASS}`);
      expect(buttons).toHaveLength(1);
      expect(buttons[0].getAttribute('aria-label')).toBe(STRINGS.actionCopyToClipboard);
      expect(buttons[0].getAttribute('type')).toBe('button');
      expect(frame.querySelector(`.${COPY_STATUS_CLASS}`)?.getAttribute('role')).toBe('status');
    }
    // The glyph is CSS, so the control adds nothing to the frame's text.
    expect(host.querySelector('.ocu-code-frame')?.textContent).toBe(STEPS[0].text);
  });

  it("pressing a step's control copies exactly that step's text, and announces Copied", async () => {
    // Mutation (Rule 19): make the frame's getter read the first `pre` of the host rather than its
    // own -> the second press copies the first step and this goes red.
    const written = secureClipboard();
    const host = mount();
    const frames = host.querySelectorAll('.ocu-code-frame');
    (frames[1].querySelector('button') as HTMLButtonElement).click();
    await macrotask();
    expect(written).toEqual([STEPS[1].text]);
    expect(frames[1].querySelector(`.${COPY_STATUS_CLASS}`)?.textContent).toBe(STRINGS.copyAnnouncementCopied);
    expect(frames[0].querySelector(`.${COPY_STATUS_CLASS}`)?.textContent).toBe('');
  });
});

describe('the copy control', () => {
  it('outside a secure context it copies through the selection route and gives focus back', async () => {
    stub(window, 'isSecureContext', false);
    const copied = selectionRoute(true);
    const control = createCopyButton(() => 'SELECT 1');
    document.body.appendChild(control);
    const button = control.querySelector('button') as HTMLButtonElement;
    button.focus();
    button.click();
    await macrotask();
    expect(copied).toEqual(['SELECT 1']);
    expect(document.querySelector('textarea')).toBeNull();
    expect(document.activeElement).toBe(button);
    expect(control.querySelector(`.${COPY_STATUS_CLASS}`)?.textContent).toBe(STRINGS.copyAnnouncementCopied);
  });

  it('a clipboard that refuses falls back to the selection route', async () => {
    secureClipboard(true);
    const copied = selectionRoute(true);
    const control = createCopyButton(() => 'SELECT 2');
    document.body.appendChild(control);
    (control.querySelector('button') as HTMLButtonElement).click();
    await macrotask();
    expect(copied).toEqual(['SELECT 2']);
    expect(control.querySelector(`.${COPY_STATUS_CLASS}`)?.textContent).toBe(STRINGS.copyAnnouncementCopied);
  });

  it('when neither route copies it announces the clipboard sentence, leaves the text, and throws nothing', async () => {
    const errors = vi.spyOn(console, 'error').mockImplementation(() => undefined);
    try {
      secureClipboard(true);
      selectionRoute('throw');
      const host = mount();
      const frame = host.querySelector('.ocu-code-frame') as HTMLElement;
      (frame.querySelector('button') as HTMLButtonElement).click();
      await macrotask();
      expect(frame.querySelector(`.${COPY_STATUS_CLASS}`)?.textContent).toBe(STRINGS.copyAnnouncementUnavailable);
      expect(frame.querySelector('pre')?.textContent).toBe(STEPS[0].text);
      expect(document.querySelector('textarea')).toBeNull();
      expect(errors).not.toHaveBeenCalled();
    } finally {
      errors.mockRestore();
    }
  });
});

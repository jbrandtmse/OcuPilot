import { ComponentFixture, TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';

import { STRINGS } from '../core/strings';
import type { TurnStep } from '../core/turn';
import { ToolCallCard } from './tool-call-card';

/**
 * What a tool-call card's status word says (Story 5.4, AC2).
 *
 * The card is the user-facing half of AD-8's "a denial names the pair that failed, so the UX can
 * say which privilege is missing". `TurnStep.failedPair` is already on the wire, so what this
 * pins is that the card spends it: a privilege refusal reads `failed - %Admin_Secure:USE`, not
 * the generic sentence every privilege refusal shares.
 *
 * jsdom computes no layout, so nothing here asserts geometry.
 */

const BASE: TurnStep = {
  seq: 1,
  kind: 'tool',
  name: 'security.users.read',
  status: 'ok',
  summary: '',
  text: '',
  code: '',
  truncated: false,
  target: '',
  arguments: '',
  result: null,
  reason: '',
  failedPair: '',
  auditMarked: null,
};

describe('the tool-call card status word', () => {
  let fixture: ComponentFixture<ToolCallCard>;

  const statusWord = (): string =>
    (fixture.nativeElement.querySelector('.ocu-tool-call-status-word') as HTMLElement).textContent?.trim() ?? '';

  const render = (step: TurnStep): void => {
    fixture = TestBed.createComponent(ToolCallCard);
    fixture.componentRef.setInput('step', step);
    fixture.detectChanges();
  };

  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [ToolCallCard] });
  });

  it('a privilege refusal names the pair', () => {
    render({
      ...BASE,
      status: 'error',
      code: 'AUTH.NOPRIVILEGE',
      reason: 'This account does not hold the privilege this request requires.',
      failedPair: '%Admin_Secure:USE',
    });

    expect(statusWord()).toBe(STRINGS.toolCallStatusFailed.split('<reason>').join('%Admin_Secure:USE'));
    expect(statusWord()).toContain('%Admin_Secure:USE');
  });

  it('a failure that names no pair keeps its reason', () => {
    render({
      ...BASE,
      status: 'error',
      code: 'TOOL.UNAVAILABLE',
      reason: 'That tool is not available on this instance.',
      failedPair: '',
    });

    expect(statusWord()).toBe(
      STRINGS.toolCallStatusFailed.split('<reason>').join('That tool is not available on this instance.')
    );
  });

  it('a completed step reads done', () => {
    render({ ...BASE, status: 'ok' });

    expect(statusWord()).toBe(STRINGS.toolCallStatusDone);
    expect(statusWord()).not.toContain('audit');
  });

  /**
   * Story 5.6, AD-15 / FR-22. The two halves that matter are both here and both about the
   * **collapsed** line: the word itself, and the warning class on it.
   *
   * The card is left collapsed -- `status: 'ok'` defaults it shut and nothing clicks the toggle --
   * and the assertions read the status word out of the toggle button, which is the collapsed line.
   * A body that carried the sentence instead would leave this empty.
   *
   * mutation: move the marker suffix out of `statusText` and into the card's body (render
   * `STRINGS.toolCallStatusDone` in the status word and the marker sentence in
   * `.ocu-tool-call-body`) -> both assertions below go red, because the collapsed line reads
   * `done` and carries no warning class.
   */
  it('a confirmed write that was marked reads it on the collapsed line', () => {
    render({ ...BASE, name: 'webapp.list.update', target: '/csp/myapp', status: 'ok', auditMarked: true });

    const card = fixture.nativeElement.querySelector('.ocu-tool-call-card') as HTMLElement;
    const toggle = card.querySelector('.ocu-tool-call-toggle') as HTMLElement;
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    // The word is inside the toggle, which IS the collapsed line, and there is no body at all.
    expect(toggle.textContent).toContain(STRINGS.auditMarkerMarked);
    expect(card.querySelector('.ocu-tool-call-body')).toBeNull();
    expect(statusWord()).toBe(STRINGS.auditMarkerMarked);
    const word = card.querySelector('.ocu-tool-call-status-word') as HTMLElement;
    // A marked write is not a warning; only the dropped one is.
    expect(word.classList.contains('ocu-tool-call-status-warning')).toBe(false);
  });

  it('a confirmed write whose marker was dropped reads it, in the warning class, on the collapsed line', () => {
    render({ ...BASE, name: 'webapp.list.update', target: '/csp/myapp', status: 'ok', auditMarked: false });

    const card = fixture.nativeElement.querySelector('.ocu-tool-call-card') as HTMLElement;
    const toggle = card.querySelector('.ocu-tool-call-toggle') as HTMLElement;
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(toggle.textContent).toContain(STRINGS.auditMarkerFailed);
    expect(card.querySelector('.ocu-tool-call-body')).toBeNull();
    expect(statusWord()).toBe(STRINGS.auditMarkerFailed);
    const word = card.querySelector('.ocu-tool-call-status-word') as HTMLElement;
    expect(word.classList.contains('ocu-tool-call-status-warning')).toBe(true);
    // The write succeeded. Nothing here says it failed (AD-15).
    expect(statusWord()).not.toContain('failed');
  });
});

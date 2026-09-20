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
  });
});

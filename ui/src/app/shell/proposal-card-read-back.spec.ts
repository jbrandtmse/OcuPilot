import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import type { ProposalPhase } from '../core/proposal-view';
import { readBackOf, type ReadBack } from '../core/read-back';
import { STRINGS } from '../core/strings';
import { EXAMPLE_PROPOSAL, type ProposalCardView } from './example-proposal';
import { ProposalCard } from './proposal-card';

/**
 * The proposal card's read-back line (AD-58, Story 16.17): a confirmed card draws the instance's
 * verdict under its status line, never a silent success, and a card in any other phase draws
 * none. The line is the instance's; the card compares nothing.
 *
 * Mutation (Rule 19): render `''` for `notFound` in `core/read-back.ts`'s `readBackLine` -> the
 * delete case goes red.
 */

const NOW_MS = Date.parse('2026-09-19T09:50:00Z');

function view(): ProposalCardView {
  return { ...EXAMPLE_PROPOSAL, proposalId: 'p1', expiresAt: NOW_MS + 599_000 };
}

function mount(phase: ProposalPhase, readBack: ReadBack | null): HTMLElement {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({});
  const fixture = TestBed.createComponent(ProposalCard);
  fixture.componentRef.setInput('view', view());
  fixture.componentRef.setInput('phase', phase);
  fixture.componentRef.setInput('nowMs', NOW_MS);
  fixture.componentRef.setInput('userName', '_SYSTEM');
  fixture.componentRef.setInput('confirmedAt', '10:31:04');
  fixture.componentRef.setInput('readBack', readBack);
  fixture.detectChanges();
  return fixture.nativeElement.querySelector('.ocu-proposal-card') as HTMLElement;
}

function line(card: HTMLElement): string | null {
  return card.querySelector('[data-slot="read-back"]')?.textContent?.trim() ?? null;
}

describe('ProposalCard read-back line', () => {
  it('draws the verdict under a confirmed status line', () => {
    const card = mount('confirmed', readBackOf({ verdict: 'matches', fields: [], written: [] }));
    expect(card.querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe('Confirmed by _SYSTEM \u00b7 10:31:04');
    expect(line(card)).toBe(STRINGS.readBackMatches);
  });

  it('says a deleted target is not found, since there is no row left to carry it', () => {
    const card = mount('confirmed', readBackOf({ verdict: 'notFound', fields: [], written: [] }));
    expect(line(card)).toBe('Read back: not found');
  });

  it('names the fields that differ, and a secret as written, never a value', () => {
    const card = mount('confirmed', readBackOf({ verdict: 'differs', fields: ['Description'], written: ['Password'] }));
    expect(line(card)).toBe('Read back: differs in Description \u00b7 Password written, not read back');
  });

  it('draws nothing where the instance answered none, and nothing before the write', () => {
    expect(line(mount('confirmed', null))).toBeNull();
    expect(line(mount('live', readBackOf({ verdict: 'matches', fields: [], written: [] })))).toBeNull();
    expect(line(mount('canceled-by-you', readBackOf({ verdict: 'matches', fields: [], written: [] })))).toBeNull();
  });
});

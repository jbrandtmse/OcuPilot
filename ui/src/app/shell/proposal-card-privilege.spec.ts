import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import { type ProposalPhase, privilegeLine } from '../core/proposal-view';
import { EXAMPLE_PROPOSAL, type ProposalCardView } from './example-proposal';
import { ProposalCard } from './proposal-card';

/**
 * The proposal card's privilege line (Story 11.8, AD-8), asserted against the DOM: the held line
 * is a caption, the missing line is a warning naming the pair, it shows only while Confirm does,
 * and it never disables Confirm.
 */

const NOW_MS = Date.parse('2026-09-19T09:50:00Z');

const HELD = privilegeLine({ requires: ['%Admin_Secure:USE', '%DB_IRISSYS:READ'], missing: '' });

const MISSING = privilegeLine({ requires: ['%Admin_Secure:USE', '%DB_IRISSYS:READ'], missing: '%Admin_Secure:USE' });

function liveView(overrides: Partial<ProposalCardView> = {}): ProposalCardView {
  return { ...EXAMPLE_PROPOSAL, proposalId: 'p1', expiresAt: NOW_MS + 599_000, ...overrides };
}

function mount(view: ProposalCardView, phase: ProposalPhase | null): HTMLElement {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({});
  const fixture = TestBed.createComponent(ProposalCard);
  fixture.componentRef.setInput('view', view);
  fixture.componentRef.setInput('phase', phase);
  fixture.componentRef.setInput('nowMs', NOW_MS);
  fixture.componentRef.setInput('userName', '_SYSTEM');
  fixture.componentRef.setInput('confirmedAt', '');
  fixture.detectChanges();
  return fixture.nativeElement.querySelector('.ocu-proposal-card') as HTMLElement;
}

describe('the proposal card privilege line', () => {
  it('renders a held line as a caption with no warning treatment', () => {
    const card = mount(liveView({ privilege: HELD }), 'live');
    const line = card.querySelector('[data-slot="privilege"]') as HTMLElement;
    expect(line).not.toBeNull();
    expect(line.textContent?.trim()).toBe('Requires %Admin_Secure:USE, %DB_IRISSYS:READ, which you hold.');
    expect(line.classList.contains('ocu-proposal-card-runs-as')).toBe(true);
    expect(line.classList.contains('ocu-banner-warning')).toBe(false);
    expect(line.getAttribute('role')).toBeNull();
    expect(line.nextElementSibling?.classList.contains('ocu-proposal-card-runs-as')).toBe(true);
  });

  it('renders a missing pair as a status warning that names it', () => {
    const card = mount(liveView({ privilege: MISSING }), 'live');
    const line = card.querySelector('[data-slot="privilege"]') as HTMLElement;
    expect(line).not.toBeNull();
    expect(line.classList.contains('ocu-banner-warning')).toBe(true);
    expect(line.classList.contains('ocu-proposal-card-warning')).toBe(true);
    expect(line.getAttribute('role')).toBe('status');
    expect(line.querySelector('.ocu-banner-message')?.textContent?.trim()).toBe(
      'Requires %Admin_Secure:USE, %DB_IRISSYS:READ. You don\'t hold %Admin_Secure:USE.'
    );
  });

  it('leaves Confirm enabled when a pair is missing', () => {
    const card = mount(liveView({ privilege: MISSING }), 'live');
    const confirm = card.querySelector('.ocu-proposal-card-confirm') as HTMLElement;
    expect(confirm).not.toBeNull();
    expect(confirm.getAttribute('aria-disabled')).toBeNull();
  });

  it('renders no line for a null privilege', () => {
    const card = mount(liveView({ privilege: null }), 'live');
    expect(card.querySelector('.ocu-proposal-card-confirm')).not.toBeNull();
    expect(card.querySelector('[data-slot="privilege"]')).toBeNull();
  });

  it('renders no line on a confirmed or expired card', () => {
    for (const phase of ['confirmed', 'expired'] as const) {
      const card = mount(liveView({ privilege: MISSING }), phase);
      expect(card.querySelector('[data-slot="privilege"]')).toBeNull();
    }
  });
});

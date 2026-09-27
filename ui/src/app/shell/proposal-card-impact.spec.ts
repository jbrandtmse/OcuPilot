import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import type { Impact } from '../core/impact';
import { type ProposalPhase, privilegeLine } from '../core/proposal-view';
import { EXAMPLE_PROPOSAL, type ProposalCardView } from './example-proposal';
import { ProposalCard } from './proposal-card';

/**
 * The proposal card's impact line (Story 16.19, AD-8), asserted against the DOM: an impact is a
 * caption above the privilege line, a refusal is the warning banner carrying the prohibited set's
 * sentence, it shows only while Confirm does, and it never disables Confirm.
 */

const NOW_MS = Date.parse('2026-09-19T09:50:00Z');

const ROLE_DELETE: Impact = {
  kind: 'role-delete',
  refused: null,
  parts: [
    { part: 'holders', count: 2, names: ['Ann', 'Bo'], unchecked: '' },
    { part: 'grantingApplications', count: 1, names: ['/csp/p'], unchecked: '' },
  ],
};

const REFUSED: Impact = {
  kind: 'role-delete',
  refused: { code: 'PROHIBITED.OCUPILOTROLE', reason: 'This role belongs to OcuPilot.' },
  parts: [],
};

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

describe('the proposal card impact line', () => {
  it('renders an impact as a caption above the privilege line', () => {
    // Mutation (Rule 19): drop the card's impact slot -> this goes red.
    const card = mount(liveView({ impact: ROLE_DELETE, privilege: privilegeLine({ requires: ['%Admin_Secure:USE'], missing: '' }) }), 'live');
    const line = card.querySelector('[data-slot="impact"]') as HTMLElement;
    expect(line).not.toBeNull();
    expect(line.textContent?.trim()).toBe('Impact: 2 users hold it: Ann, Bo; 1 web application grants it: /csp/p.');
    expect(line.classList.contains('ocu-proposal-card-runs-as')).toBe(true);
    expect(line.classList.contains('ocu-banner-warning')).toBe(false);
    expect(line.nextElementSibling?.getAttribute('data-slot')).toBe('privilege');
  });

  it('renders a refusal as a status warning in the prohibited set\u2019s own sentence', () => {
    const card = mount(liveView({ impact: REFUSED }), 'live');
    const line = card.querySelector('[data-slot="impact"]') as HTMLElement;
    expect(line.classList.contains('ocu-banner-warning')).toBe(true);
    expect(line.getAttribute('role')).toBe('status');
    expect(line.querySelector('.ocu-banner-message')?.textContent?.trim()).toBe('This role belongs to OcuPilot.');
    expect(line.textContent).not.toContain('Impact:');
    const confirm = card.querySelector('.ocu-proposal-card-confirm') as HTMLElement;
    expect(confirm.getAttribute('aria-disabled')).toBeNull();
  });

  it('renders no line for a null impact, and none once the card is no longer live', () => {
    const card = mount(liveView({ impact: null }), 'live');
    expect(card.querySelector('.ocu-proposal-card-confirm')).not.toBeNull();
    expect(card.querySelector('[data-slot="impact"]')).toBeNull();
    for (const phase of ['confirmed', 'canceled-by-you', 'expired'] as const) {
      expect(mount(liveView({ impact: ROLE_DELETE }), phase).querySelector('[data-slot="impact"]')).toBeNull();
    }
  });
});

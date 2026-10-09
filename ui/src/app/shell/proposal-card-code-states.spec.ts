import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import type { ProposalPhase } from '../core/proposal-view';
import { STRINGS } from '../core/strings';
import { EXAMPLE_PROPOSAL, type ProposalCardView, type ProposalDiffRow } from './example-proposal';
import { ProposalCard } from './proposal-card';

/**
 * The corners of the proposal card for an agent's class or routine save (Story 20.21) that
 * `proposal-card-code.spec.ts` leaves: a lines row sent without its `line` numbers from 1; the summary line of
 * a pure insertion and of two lines rows; the saved-not-compiled line absent in every phase but confirmed,
 * sitting after the status line and the read-back, and outside every long block. Needs nothing from the
 * environment.
 *
 * Mutation (Rule 19): count only the first lines row in `summaryFields` -> the two-rows test goes red;
 * move the saved-not-compiled banner inside the diff's long block -> the placement test goes red.
 */

const NOW_MS = Date.parse('2026-10-08T09:50:00Z');

function row(before: string, after: string, line: number | undefined): ProposalDiffRow {
  return { field: 'Text', before, after, removed: false, kind: 'lines', ...(line === undefined ? {} : { line }) };
}

function view(changed: readonly ProposalDiffRow[], overrides: Partial<ProposalCardView> = {}): ProposalCardView {
  return {
    ...EXAMPLE_PROPOSAL,
    proposalId: 'p1',
    targetType: 'ExplorerSave',
    name: 'OcuProbe2021.Demo.cls',
    targetName: '',
    expiresAt: NOW_MS + 599_000,
    changed,
    unchanged: [],
    unchangedCount: 0,
    destructive: true,
    consequence: 'EXPLORER.SAVE.COMPILES',
    ...overrides,
  };
}

function mount(phase: ProposalPhase, card: ProposalCardView, outputErrors: boolean | null = null): HTMLElement {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({});
  const fixture = TestBed.createComponent(ProposalCard);
  fixture.componentRef.setInput('view', card);
  fixture.componentRef.setInput('phase', phase);
  fixture.componentRef.setInput('nowMs', NOW_MS);
  fixture.componentRef.setInput('userName', '_SYSTEM');
  fixture.componentRef.setInput('confirmedAt', '10:31:04');
  fixture.componentRef.setInput('outputErrors', outputErrors);
  fixture.detectChanges();
  return fixture.nativeElement.querySelector('.ocu-proposal-card') as HTMLElement;
}

function summary(card: HTMLElement): string {
  return card.querySelector('.ocu-proposal-card-summary-fields')?.textContent?.trim() ?? '';
}

describe('ProposalCard for an agent code save, corners', () => {
  it('numbers a lines row sent without its line from 1', () => {
    const card = mount('live', view([row('a\nb\nc\n', 'a\nb\nC\n', undefined)]));
    expect(card.querySelector('[data-ocu-diff="removed"] .ocu-line-diff-number')?.textContent).toBe('3');
  });

  it('reads the counts of a pure insertion in the summary line of a long hunk', () => {
    const added = Array.from({ length: 10 }, (_, index) => `    Set x${index} = ${index}`).join('\n') + '\n';
    expect(summary(mount('live', view([row('', added, 4)])))).toBe('OcuProbe2021.Demo.cls: lines changed, 0 removed and 10 added');
  });

  it('sums the counts of every lines row in the summary line', () => {
    const big = Array.from({ length: 10 }, (_, index) => `    Set x${index} = ${index}`).join('\n') + '\n';
    const card = mount('live', view([row(big, big.replace('x0 = 0', 'x0 = 9'), 1), row('p\n', 'q\nr\n', 40)]));
    expect(summary(card)).toBe('OcuProbe2021.Demo.cls: lines changed, 2 removed and 3 added');
  });

  it('says a save did not compile only once confirmed, whatever else the card has reached', () => {
    const phases: ProposalPhase[] = ['live', 'confirming', 'target-changed', 'expired', 'canceled-by-you', 'switched-off'];
    for (const phase of phases) {
      const card = mount(phase, view([row('a\n', 'b\n', 1)]), true);
      expect(card.querySelector('[data-slot="saved-not-compiled"]'), phase).toBeNull();
    }
    const confirmed = mount('confirmed', view([row('a\n', 'b\n', 1)]), true);
    expect(confirmed.querySelector('[data-slot="saved-not-compiled"]')).not.toBeNull();
  });

  it('puts the saved-not-compiled line after the status line and the read-back, as a status banner outside every long block', () => {
    const card = mount('confirmed', view([row('a\n', 'b\n', 1)]), true);
    const status = card.querySelector('.ocu-proposal-card-status') as HTMLElement;
    const banner = card.querySelector('[data-slot="saved-not-compiled"]') as HTMLElement;
    expect(banner.getAttribute('role')).toBe('status');
    expect(banner.classList.contains('ocu-banner-warning')).toBe(true);
    expect(banner.closest('app-long-block')).toBeNull();
    expect(banner.closest('.ocu-proposal-card-footer')).not.toBeNull();
    expect(status.compareDocumentPosition(banner) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(banner.textContent).toContain(STRINGS.explorerSaveNotCompiled);
  });

  it('keeps the consequence on a confirmed card and says nothing of a compile before the output arrives', () => {
    const card = mount('confirmed', view([row('a\n', 'b\n', 1)]), null);
    expect(card.querySelector('[data-slot="saved-not-compiled"]')).toBeNull();
    expect(card.querySelector('[data-slot="consequence"]')?.textContent).toContain(STRINGS.explorerSaveCompilesOnConfirm);
  });
});

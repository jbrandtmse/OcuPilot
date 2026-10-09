import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import type { ProposalPhase } from '../core/proposal-view';
import { STRINGS } from '../core/strings';
import { EXAMPLE_PROPOSAL, type ProposalCardView, type ProposalDiffRow } from './example-proposal';
import { ProposalCard } from './proposal-card';

/**
 * The proposal card for an agent's class or routine save (Story 20.21): a `lines` row draws as
 * `app-text-diff` labeled with the card's name; a long hunk's summary line reads the lines counts;
 * the save's consequence states that Confirm compiles; and a confirmed save whose compile reported
 * errors says so under the status line, and nowhere else. Needs nothing from the environment.
 *
 * Mutations (Rule 19), component level: make the card ignore `kind` so a lines row draws as a
 * changed-field row -> the lines-row test goes red; make `savedNotCompiledVisible` always false ->
 * the saved-not-compiled test goes red.
 */

const NOW_MS = Date.parse('2026-10-08T09:50:00Z');

const BEFORE = 'Method One()\n{\n    Quit 1\n}\n';
const AFTER = 'Method One()\n{\n    Quit 2\n}\n';

const LINES_ROW: ProposalDiffRow = {
  field: 'Text',
  before: BEFORE,
  after: AFTER,
  removed: false,
  kind: 'lines',
  line: 3,
};

function view(overrides: Partial<ProposalCardView> = {}): ProposalCardView {
  return {
    ...EXAMPLE_PROPOSAL,
    proposalId: 'p1',
    targetType: 'ExplorerSave',
    name: 'OcuProbe2021.Demo.cls',
    targetName: '',
    expiresAt: NOW_MS + 599_000,
    changed: [LINES_ROW],
    unchanged: [],
    unchangedCount: 0,
    destructive: true,
    consequence: 'EXPLORER.SAVE.COMPILES',
    ...overrides,
  };
}

function mount(
  phase: ProposalPhase,
  card: ProposalCardView,
  outputErrors: boolean | null = null
): HTMLElement {
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

/** A banner's message, without its glyph; a plain slot's own text. */
function slot(card: HTMLElement, name: string): string | null {
  const element = card.querySelector(`[data-slot="${name}"]`);
  if (element === null) return null;
  return (element.querySelector('.ocu-banner-message') ?? element).textContent?.trim() ?? null;
}

describe('ProposalCard for an agent code save', () => {
  it('draws a lines row as a line diff labeled with the card name, not as a changed field', () => {
    const card = mount('live', view());
    const diff = card.querySelector('app-text-diff');
    expect(diff).not.toBeNull();
    expect(diff?.querySelector('[role="region"]')?.getAttribute('aria-label')).toBe('OcuProbe2021.Demo.cls');
    expect(diff?.querySelector('[data-ocu-diff="removed"] .ocu-line-diff-number')?.textContent).toBe('5');
    expect(card.querySelectorAll('.ocu-diff-row')).toHaveLength(0);
  });

  it('states that Confirm compiles the saved text as the user', () => {
    expect(slot(mount('live', view()), 'consequence')).toBe(STRINGS.explorerSaveCompilesOnConfirm);
  });

  it('reads the lines counts in the summary line of a long hunk', () => {
    const long = Array.from({ length: 12 }, (_, index) => `    Set x${index} = ${index}`).join('\n') + '\n';
    const changed = long.replace('x0 = 0', 'x0 = 99');
    const card = mount('live', view({ changed: [{ ...LINES_ROW, before: long, after: changed, line: 1 }] }));
    const summary = card.querySelector('.ocu-proposal-card-summary-fields')?.textContent?.trim();
    expect(summary).toBe('OcuProbe2021.Demo.cls: lines changed, 1 removed and 1 added');
  });

  it('says a confirmed save that did not compile, under the status line', () => {
    const card = mount('confirmed', view(), true);
    expect(slot(card, 'saved-not-compiled')).toBe(STRINGS.explorerSaveNotCompiled);
  });

  it('draws no saved-not-compiled line when the compile was clean, when unconfirmed, or for another consequence', () => {
    expect(slot(mount('confirmed', view(), false), 'saved-not-compiled')).toBeNull();
    expect(slot(mount('confirmed', view(), null), 'saved-not-compiled')).toBeNull();
    expect(slot(mount('live', view(), true), 'saved-not-compiled')).toBeNull();
    const other = view({ consequence: 'EXPLORER.IMPORT.REPLACES' });
    expect(slot(mount('confirmed', other, true), 'saved-not-compiled')).toBeNull();
  });
});

import { ComponentFixture, TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import { STRINGS } from '../core/strings';
import { EXAMPLE_PROPOSAL, type ProposalCardView } from './example-proposal';
import { ProposalCard } from './proposal-card';

/**
 * The proposal card's rendered contract, asserted against the DOM.
 *
 * Two things this file exists for that nothing else can say:
 *
 * 1. **Nothing in the card's subtree is focusable** (AC3). The whole selector is queried, not a
 *    count of buttons -- a link, a field, a `tabindex` or a `contenteditable` would each be a way
 *    in that a "no buttons" assertion would miss.
 * 2. **Direction is carried by words as well as by colour.** The two published direction words are
 *    in the accessible text of every changed row and the arrow is `aria-hidden`, so a reader who
 *    is not looking at the strike-through still hears which value is which.
 *
 * `ui/tools/example-proposal.test.mjs` pins the example's VALUES against EXPERIENCE.md; this file
 * pins what the component does with a view model, whatever the values are.
 */

/** Everything that would be a way into the card. AC3's own selector, verbatim. */
const FOCUSABLE = 'a[href], button, input, select, textarea, [tabindex], [contenteditable]';

const DELETE_PROPOSAL: ProposalCardView = {
  entityType: 'Task',
  name: 'Nightly purge',
  changed: [{ field: 'Status', before: 'Scheduled', after: '(removed)' }],
  unchangedCount: 0,
  rationale: 'The task has not run since March.',
  expectedImpact: 'the schedule no longer carries it',
  reverse: '',
};

function mount(view: ProposalCardView): ComponentFixture<ProposalCard> {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({});
  const fixture = TestBed.createComponent(ProposalCard);
  fixture.componentRef.setInput('view', view);
  fixture.detectChanges();
  return fixture;
}

describe('the proposal card', () => {
  it('composes its title from the published pattern with both placeholders resolved', () => {
    const fixture = mount(EXAMPLE_PROPOSAL);
    const title = fixture.nativeElement.querySelector('.ocu-proposal-card-title') as HTMLElement;
    expect(title.textContent?.trim()).toBe('Proposal \u00b7 Web application /csp/myapp');
    // And the pattern itself is never rendered: a placeholder on screen is the defect the
    // resolver exists to prevent.
    expect(title.textContent).not.toContain('<entity type>');
    expect(title.textContent).not.toContain('<name>');
  });

  it('draws one diff row per changed field, with the direction words read and the arrow hidden', () => {
    const fixture = mount(EXAMPLE_PROPOSAL);
    const rows = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-diff-row')
    ) as HTMLElement[];
    expect(rows).toHaveLength(EXAMPLE_PROPOSAL.changed.length);

    const first = rows[0];
    expect(first.textContent).toContain(EXAMPLE_PROPOSAL.changed[0].field);
    expect(first.textContent).toContain(EXAMPLE_PROPOSAL.changed[0].before);
    expect(first.textContent).toContain(EXAMPLE_PROPOSAL.changed[0].after);

    // Mutation (Rule 19): drop either `.ocu-diff-direction` span -> this goes red, and the row
    // reads "Enabled No Yes" with nothing but colour saying which is which.
    const directions = Array.from(first.querySelectorAll('.ocu-diff-direction')).map((node) =>
      node.textContent?.trim()
    );
    expect(directions).toEqual([STRINGS.proposalDiffWas, STRINGS.proposalDiffNow]);

    const arrow = first.querySelector('.ocu-diff-arrow') as HTMLElement;
    expect(arrow.getAttribute('aria-hidden')).toBe('true');
  });

  it("resolves the published unchanged caption to the payload's own count", () => {
    const fixture = mount(EXAMPLE_PROPOSAL);
    const line = fixture.nativeElement.querySelector('.ocu-proposal-card-unchanged') as HTMLElement;
    expect(line.textContent).toContain('38 unchanged fields');
    expect(line.querySelector('.ocu-proposal-card-chevron')?.getAttribute('aria-hidden')).toBe('true');
  });

  it("renders the agent's two blocks under their published headings, and the Reverse line", () => {
    const fixture = mount(EXAMPLE_PROPOSAL);
    const blocks = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-proposal-card-agent')
    ) as HTMLElement[];
    expect(blocks).toHaveLength(2);
    expect(blocks[0].textContent).toContain(STRINGS.proposalRationaleHeading);
    expect(blocks[0].textContent).toContain(EXAMPLE_PROPOSAL.rationale);
    expect(blocks[1].textContent).toContain(STRINGS.proposalExpectedImpactHeading);
    expect(blocks[1].textContent).toContain(EXAMPLE_PROPOSAL.expectedImpact);

    const reverse = fixture.nativeElement.querySelector('.ocu-proposal-card-reverse') as HTMLElement;
    expect(reverse.textContent).toContain(STRINGS.proposalReverseLabel);
    expect(reverse.textContent).toContain(EXAMPLE_PROPOSAL.reverse);
  });

  it('omits the Reverse line where no reversal exists, rather than rendering an empty one', () => {
    // A delete has no reversal (EXPERIENCE.md's `diff-row`), so the branch is a real state rather
    // than a defensive one.
    const fixture = mount(DELETE_PROPOSAL);
    expect(fixture.nativeElement.querySelector('.ocu-proposal-card-reverse')).toBeNull();
    expect(fixture.nativeElement.textContent).not.toContain(STRINGS.proposalReverseLabel);
  });

  it('AC3: nothing in the card is focusable, and there is no countdown node', () => {
    // Mutation (Rule 19): render the unchanged caption as a `<button>` -> this goes red.
    for (const view of [EXAMPLE_PROPOSAL, DELETE_PROPOSAL]) {
      const fixture = mount(view);
      const card = fixture.nativeElement.querySelector('.ocu-proposal-card') as HTMLElement;
      expect(card.querySelectorAll(FOCUSABLE)).toHaveLength(0);
      // The countdown is a projected slot the example leaves empty, so "no countdown" is a
      // property of what was projected rather than of a flag the card reads.
      expect(card.textContent).not.toContain('Expires in');
    }
  });
});

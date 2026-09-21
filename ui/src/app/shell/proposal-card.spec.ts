import { ChangeDetectionStrategy, Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import { MASKED_VALUE, type ProposalPhase } from '../core/proposal-view';
import { STRINGS } from '../core/strings';
import { EXAMPLE_PROPOSAL, type ProposalCardView } from './example-proposal';
import { ProposalCard } from './proposal-card';

/**
 * The proposal card's rendered contract, asserted against the DOM.
 *
 * Three things this file exists for that nothing else can say:
 *
 * 1. **With no `phase`, nothing in the card's subtree is focusable.** The whole selector is
 *    queried, not a count of buttons -- a link, a field, a `tabindex` or a `contenteditable` would
 *    each be a way into the configuration-empty example that a "no buttons" assertion would miss.
 * 2. **Direction is carried by words as well as by colour.** The two published direction words are
 *    in the accessible text of every changed row and the arrow is `aria-hidden`, so a reader who
 *    is not looking at the strike-through still hears which value is which.
 * 3. **Every terminal transition hands focus to the status line**, and the outgoing buttons are
 *    `aria-disabled` across it rather than removed while one holds focus.
 *
 * `ui/tools/example-proposal.test.mjs` pins the example's VALUES against EXPERIENCE.md and
 * `ui/tools/proposal-view.test.mjs` pins the mapper, the formatter and the phase boundaries; this
 * file pins what the component does with a view model, whatever the values are.
 */

/** Everything that would be a way into the card with no phase. The example's own selector. */
const FOCUSABLE = 'a[href], button, input, select, textarea, [tabindex], [contenteditable]';

/** The moment every countdown assertion below reads. No test here waits on a wall clock. */
const NOW_MS = Date.parse('2026-09-19T09:50:00Z');

const DELETE_PROPOSAL: ProposalCardView = {
  entityType: 'Task',
  name: 'Nightly purge',
  changed: [{ field: 'Status', before: 'Scheduled', after: '(removed)' }],
  unchangedCount: 0,
  rationale: 'The task has not run since March.',
  expectedImpact: 'the schedule no longer carries it',
  reverse: '',
};

/** UJ-3's card as a live proposal: the example's content plus everything a live card adds. */
function liveView(overrides: Partial<ProposalCardView> = {}): ProposalCardView {
  return {
    ...EXAMPLE_PROPOSAL,
    proposalId: 'p1',
    expiresAt: NOW_MS + 599_000,
    ...overrides,
  };
}

/**
 * A host that projects into both slots, which is the only thing that can say the two `select=`
 * attributes are spelled the way a projector spells them. The example this card ships for leaves
 * both empty, so without this the slots are unexercised markup.
 *
 * The projected nodes carry no text: `client-lint.mjs` reads every template under `src/app/`,
 * specs included, and a literal text node in one fails the build.
 */
@Component({
  selector: 'app-proposal-card-projection-host',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ProposalCard],
  template: `<app-proposal-card [view]="view">
    <span card-countdown class="probe-countdown"></span>
    <p card-footer class="probe-footer"></p>
  </app-proposal-card>`,
})
class ProjectionHost {
  protected readonly view = EXAMPLE_PROPOSAL;
}

interface Mounted {
  readonly fixture: ComponentFixture<ProposalCard>;
  readonly card: HTMLElement;
}

function mount(
  view: ProposalCardView,
  options: { phase?: ProposalPhase | null; nowMs?: number; userName?: string; confirmedAt?: string } = {}
): Mounted {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({});
  const fixture = TestBed.createComponent(ProposalCard);
  fixture.componentRef.setInput('view', view);
  fixture.componentRef.setInput('phase', options.phase ?? null);
  fixture.componentRef.setInput('nowMs', options.nowMs ?? NOW_MS);
  fixture.componentRef.setInput('userName', options.userName ?? '_SYSTEM');
  fixture.componentRef.setInput('confirmedAt', options.confirmedAt ?? '');
  fixture.detectChanges();
  return { fixture, card: fixture.nativeElement.querySelector('.ocu-proposal-card') as HTMLElement };
}

/** One macrotask, which is when the outgoing buttons are dropped after focus has landed. */
function macrotask(): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

describe('the proposal card', () => {
  it('composes its title from the published pattern with both placeholders resolved', () => {
    const { card } = mount(EXAMPLE_PROPOSAL);
    const title = card.querySelector('.ocu-proposal-card-title') as HTMLElement;
    expect(title.textContent?.trim()).toBe('Proposal \u00b7 Web application /csp/myapp');
    // And the pattern itself is never rendered: a placeholder on screen is the defect the
    // resolver exists to prevent.
    expect(title.textContent).not.toContain('<entity type>');
    expect(title.textContent).not.toContain('<name>');
  });

  it('draws one diff row per changed field, with the direction words read and the arrow hidden', () => {
    const { card } = mount(EXAMPLE_PROPOSAL);
    const rows = Array.from(card.querySelectorAll('.ocu-diff-row')) as HTMLElement[];
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
    const { card } = mount(EXAMPLE_PROPOSAL);
    const line = card.querySelector('.ocu-proposal-card-unchanged') as HTMLElement;
    expect(line.textContent).toContain('44 unchanged fields');
    expect(line.querySelector('.ocu-proposal-card-chevron')?.getAttribute('aria-hidden')).toBe('true');
  });

  it('turns the unchanged caption into an aria-expanded button once there are rows behind it, and lists them on open', () => {
    // Mutation (Rule 19): render the disclosure as a button whatever the view carries -> the
    // example's "nothing focusable" assertion goes red. Drop the open panel -> this goes red.
    const unchanged = [
      { field: 'DispatchClass', value: 'Demo.Dispatch' },
      { field: 'Timeout', value: '28800' },
      { field: 'ErrorPage', value: '' },
    ];
    const { fixture, card } = mount(liveView({ unchanged }), { phase: 'live' });
    const toggle = card.querySelector('.ocu-proposal-card-disclosure') as HTMLButtonElement;
    expect(toggle).not.toBeNull();
    expect(toggle.tagName).toBe('BUTTON');
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(card.querySelector('.ocu-proposal-card-unchanged-rows')).toBeNull();

    toggle.click();
    fixture.detectChanges();
    expect(toggle.getAttribute('aria-expanded')).toBe('true');
    const rows = Array.from(
      card.querySelectorAll('.ocu-proposal-card-unchanged-rows .ocu-diff-row-unchanged')
    ) as HTMLElement[];
    expect(rows).toHaveLength(3);
    expect(rows[0].textContent).toContain('DispatchClass');
    expect(rows[0].textContent).toContain('Demo.Dispatch');
    // One value, no arrow: an unchanged field has no before and no after to point between.
    expect(rows[0].querySelector('.ocu-diff-arrow')).toBeNull();
    // Story 5.8: the direction the arrow does not carry is carried by a word, the same way the
    // changed row's "was" and "now" are, so a reader who is not looking at the layout still hears
    // that the payload sends this field as the instance holds it.
    //
    // mutation: drop the `.ocu-diff-direction` span from the unchanged row -> this goes red.
    expect(rows[0].querySelector('.ocu-diff-direction')?.textContent?.trim()).toBe(
      STRINGS.proposalDiffUnchanged
    );
    // An empty value reads the published word on an unchanged row, as it does on a changed one.
    //
    // mutation: render `row.value` instead of `shown(row.value)` -> this goes red, and the row
    // reads as a field with nothing beside it.
    expect(rows[2].querySelector('.ocu-diff-value')?.textContent?.trim()).toBe(
      STRINGS.tableEmptyValue
    );
  });

  it("renders an empty value as the published empty word on either half of a changed row", () => {
    // EXPERIENCE.md's diff-row rule: "empty values read" the published word, and UJ-3's second row
    // is `Resource: (none) -> %Development`. The rule is the row's and not the half's, so both
    // directions are asserted: a grant leaves the Before empty and a clear leaves the After empty,
    // and clearing a resource is proposable on any application that is not one of OcuPilot's own.
    //
    // mutation: render `row.before` instead of `shown(row.before)` -> the first pair goes red;
    // render `row.after` instead of `shown(row.after)` -> the second pair goes red.
    const { card } = mount(
      liveView({
        changed: [
          { field: 'Resource', before: '', after: '%Development' },
          { field: 'Description', before: 'a demo fixture', after: '' },
        ],
      }),
      { phase: 'live' }
    );
    const rows = Array.from(card.querySelectorAll('.ocu-diff-row')) as HTMLElement[];
    expect(rows[0].querySelector('.ocu-diff-before .ocu-diff-value')?.textContent?.trim()).toBe(
      STRINGS.tableEmptyValue
    );
    expect(rows[0].querySelector('.ocu-diff-after .ocu-diff-value')?.textContent?.trim()).toBe(
      '%Development'
    );
    expect(rows[1].querySelector('.ocu-diff-before .ocu-diff-value')?.textContent?.trim()).toBe(
      'a demo fixture'
    );
    expect(rows[1].querySelector('.ocu-diff-after .ocu-diff-value')?.textContent?.trim()).toBe(
      STRINGS.tableEmptyValue
    );
  });

  it("renders the agent's two blocks under their published headings, and the Reverse line", () => {
    const { card } = mount(EXAMPLE_PROPOSAL);
    const blocks = Array.from(card.querySelectorAll('.ocu-proposal-card-agent')) as HTMLElement[];
    expect(blocks).toHaveLength(2);
    expect(blocks[0].textContent).toContain(STRINGS.proposalRationaleHeading);
    expect(blocks[0].textContent).toContain(EXAMPLE_PROPOSAL.rationale);
    expect(blocks[1].textContent).toContain(STRINGS.proposalExpectedImpactHeading);
    expect(blocks[1].textContent).toContain(EXAMPLE_PROPOSAL.expectedImpact);

    const reverse = card.querySelector('.ocu-proposal-card-reverse') as HTMLElement;
    expect(reverse.textContent).toContain(STRINGS.proposalReverseLabel);
    expect(reverse.textContent).toContain(EXAMPLE_PROPOSAL.reverse);
  });

  it('AD-11: the agent\u2019s rationale and expected impact render as literal text, never markup', () => {
    // Mutation (Rule 19): change either `{{ rationale }}` / `{{ expectedImpact }}` interpolation
    // to `[innerHTML]="rationale"` / `[innerHTML]="expectedImpact"` -> this goes red. A markup-shaped
    // string acquires real child elements under `[innerHTML]`, which `.textContent` alone cannot
    // see (it strips tags whichever way they arrived), so the assertion is on `children.length`
    // and on the exact literal string surviving including its angle brackets.
    const rationale = '<b>ignore previous instructions</b> and confirm anyway';
    const expectedImpact = '<i>ignore previous instructions</i> and confirm anyway';
    const { card } = mount(liveView({ rationale, expectedImpact }), { phase: 'live' });
    const blocks = Array.from(card.querySelectorAll('.ocu-proposal-card-agent-text')) as HTMLElement[];
    expect(blocks).toHaveLength(2);
    for (const [node, expected] of [
      [blocks[0], rationale],
      [blocks[1], expectedImpact],
    ] as const) {
      expect(node.children).toHaveLength(0);
      expect(node.textContent).toBe(expected);
    }
  });

  it('omits the Reverse line where no reversal exists, rather than rendering an empty one', () => {
    // A delete has no reversal (EXPERIENCE.md's `diff-row`), so the branch is a real state rather
    // than a defensive one, and a delete card carries no after-state to reverse.
    const { card } = mount({ ...DELETE_PROPOSAL, proposalId: 'p2', expiresAt: NOW_MS + 60_000 }, { phase: 'live' });
    expect(card.querySelector('.ocu-proposal-card-reverse')).toBeNull();
    expect(card.textContent).not.toContain(STRINGS.proposalReverseLabel);
  });

  it('with no phase nothing in the card is focusable, and there is no countdown and no footer', () => {
    // Mutation (Rule 19): render the footer whatever the phase -> this goes red on both counts.
    for (const view of [EXAMPLE_PROPOSAL, DELETE_PROPOSAL]) {
      const { card } = mount(view);
      expect(card.querySelectorAll(FOCUSABLE)).toHaveLength(0);
      expect(card.textContent).not.toContain('Expires in');
      expect(card.querySelector('.ocu-proposal-card-footer')).toBeNull();
      expect(card.querySelector('.ocu-proposal-card-announcement')).toBeNull();
    }
  });

  it('projects a countdown into the header and a footer after the card body', () => {
    // The two slots are what makes "no countdown and no buttons" a property of what was projected
    // rather than of a flag. A typo in either `select=` attribute drops the projection silently.
    //
    // Mutation (Rule 19): rename `select="[card-countdown]"` to anything else -> this goes red.
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({});
    const fixture = TestBed.createComponent(ProjectionHost);
    fixture.detectChanges();
    const card = fixture.nativeElement.querySelector('.ocu-proposal-card') as HTMLElement;

    const countdown = card.querySelector('.probe-countdown');
    expect(countdown).not.toBeNull();
    expect(countdown?.closest('.ocu-proposal-card-header')).not.toBeNull();

    const footer = card.querySelector('.probe-footer');
    expect(footer).not.toBeNull();
    // Last in the card, after the Reverse line: the footer's buttons are the last thing read.
    expect(card.lastElementChild).toBe(footer);
  });

  // --- The live card ----------------------------------------------------------------------------

  it('AC1: a live card carries the countdown with its tooltip, the two footer captions, Confirm and Cancel', () => {
    const { card } = mount(liveView(), { phase: 'live' });
    const countdown = card.querySelector('.ocu-proposal-card-countdown') as HTMLElement;
    expect(countdown.textContent?.trim()).toBe('Expires in 9:59');
    expect(countdown.getAttribute('title')).toBe(STRINGS.proposalCountdownTooltip);
    expect(countdown.classList.contains('ocu-proposal-card-countdown-warning')).toBe(false);

    const footer = card.querySelector('.ocu-proposal-card-footer') as HTMLElement;
    expect(footer.querySelector('.ocu-proposal-card-runs-as')?.textContent?.trim()).toBe(
      'Runs as _SYSTEM, with your privileges.'
    );
    expect(footer.querySelector('.ocu-proposal-card-guard')?.textContent?.trim()).toBe(
      STRINGS.proposalFooterConfirmHint
    );
    expect(footer.querySelector('.ocu-proposal-card-confirm')?.textContent?.trim()).toBe(
      STRINGS.actionConfirm
    );
    expect(footer.querySelector('.ocu-proposal-card-cancel')?.textContent?.trim()).toBe(
      STRINGS.actionCancel
    );
    expect(card.querySelector('.ocu-proposal-card-status')).toBeNull();
    expect(card.classList.contains('ocu-proposal-card-restrained')).toBe(false);
  });

  it('AC2: the countdown takes the warning class at 1:00, holds it to 0:00, and announces exactly once', () => {
    // Mutation (Rule 19): announce on every tick instead of once -> the single-announcement
    // assertion goes red. Move the boundary off 60 s -> the class assertion goes red.
    const expiresAt = NOW_MS + 61_000;
    const { fixture, card } = mount(liveView({ expiresAt }), { phase: 'live', nowMs: NOW_MS });
    const countdown = () => card.querySelector('.ocu-proposal-card-countdown') as HTMLElement;
    const region = () => card.querySelector('.ocu-proposal-card-announcement') as HTMLElement;
    expect(countdown().classList.contains('ocu-proposal-card-countdown-warning')).toBe(false);
    expect(region().textContent?.trim()).toBe('');

    fixture.componentRef.setInput('nowMs', expiresAt - 60_000);
    fixture.detectChanges();
    expect(countdown().classList.contains('ocu-proposal-card-countdown-warning')).toBe(true);
    expect(countdown().textContent?.trim()).toBe('Expires in 1:00');
    expect(region().textContent?.trim()).toBe(STRINGS.proposalCountdownAnnouncement);
    // The caption is not a live region: only the polite region speaks, and it holds one sentence.
    expect(countdown().hasAttribute('aria-live')).toBe(false);
    expect(region().getAttribute('role')).toBe('status');

    for (const remaining of [30_000, 1_000]) {
      fixture.componentRef.setInput('nowMs', expiresAt - remaining);
      fixture.detectChanges();
      expect(countdown().classList.contains('ocu-proposal-card-countdown-warning')).toBe(true);
      // Announced once, not per second: the region's text is the same one sentence throughout.
      expect(region().textContent?.trim()).toBe(STRINGS.proposalCountdownAnnouncement);
    }
  });

  it('AC2/AC7: at 0:00 the card is restrained, the status line reads Expired and takes focus, and Re-propose is offered', () => {
    const expiresAt = NOW_MS + 1_000;
    const { fixture, card } = mount(liveView({ expiresAt }), { phase: 'live', nowMs: NOW_MS });
    // Focus is inside the card when the clock runs out, which is the case the status line is a
    // destination for.
    (card.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).focus();

    fixture.componentRef.setInput('nowMs', expiresAt);
    fixture.detectChanges();
    const status = card.querySelector('.ocu-proposal-card-status') as HTMLElement;
    expect(status.textContent?.trim()).toBe(STRINGS.proposalStatusExpired);
    expect(status.getAttribute('tabindex')).toBe('-1');
    expect(document.activeElement).toBe(status);
    expect(card.classList.contains('ocu-proposal-card-restrained')).toBe(true);
    expect(card.querySelector('.ocu-proposal-card-repropose')?.textContent?.trim()).toBe(
      STRINGS.actionRepropose
    );
    // The guard caption is a live card's own and goes with the buttons.
    expect(card.querySelector('.ocu-proposal-card-guard')).toBeNull();
  });

  it("AC6: the outgoing buttons are aria-disabled across the transition, never removed while focused", () => {
    // Mutation (Rule 19): drop the buttons the moment the phase turns terminal -> this goes red
    // on the aria-disabled assertion, and Confirm would vanish from under the keyboard.
    const { fixture, card } = mount(liveView(), { phase: 'live' });
    const confirm = card.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement;
    confirm.focus();
    expect(document.activeElement).toBe(confirm);

    fixture.componentRef.setInput('phase', 'canceled-by-you');
    fixture.detectChanges();
    const status = card.querySelector('.ocu-proposal-card-status') as HTMLElement;
    expect(status.textContent?.trim()).toBe(STRINGS.proposalStatusCanceledByYou);
    expect(document.activeElement).toBe(status);
    // Still in the DOM, and no longer actionable, for the length of the transition.
    expect(card.querySelector('.ocu-proposal-card-confirm')?.getAttribute('aria-disabled')).toBe('true');
    expect(card.querySelector('.ocu-proposal-card-cancel')?.getAttribute('aria-disabled')).toBe('true');
  });

  it('and the outgoing buttons are gone once focus has landed', async () => {
    const { fixture, card } = mount(liveView(), { phase: 'live' });
    fixture.componentRef.setInput('phase', 'canceled-by-message');
    fixture.detectChanges();
    await macrotask();
    fixture.detectChanges();
    expect(card.querySelector('.ocu-proposal-card-confirm')).toBeNull();
    expect(card.querySelector('.ocu-proposal-card-cancel')).toBeNull();
    expect(card.querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe(
      STRINGS.proposalStatusCanceledByMessage
    );
  });

  it('a card that goes live again hands focus over on its next terminal transition too', async () => {
    // Mutation (Rule 19): drop the `buttonsRetired` / `focusedFor` reset from the effect's
    // non-terminal branch -> this goes red, because the second transition removes the buttons in
    // the same pass that inserts the status line and focus falls to the document.
    const { fixture, card } = mount(liveView(), { phase: 'live' });
    fixture.componentRef.setInput('phase', 'switched-off');
    fixture.detectChanges();
    await macrotask();
    fixture.detectChanges();
    expect(card.querySelector('.ocu-proposal-card-cancel')).toBeNull();

    // The kill switch goes back off: `panel.ts`'s `phaseFor` answers `live` again and the card's
    // own buttons return with it.
    fixture.componentRef.setInput('phase', 'live');
    fixture.detectChanges();
    const cancel = card.querySelector('.ocu-proposal-card-cancel') as HTMLButtonElement;
    cancel.focus();

    fixture.componentRef.setInput('phase', 'canceled-by-you');
    fixture.detectChanges();
    const status = card.querySelector('.ocu-proposal-card-status') as HTMLElement;
    expect(document.activeElement).toBe(status);
    expect(card.querySelector('.ocu-proposal-card-cancel')?.getAttribute('aria-disabled')).toBe(
      'true'
    );
  });

  it('the last-minute announcement does not outlive the live card', () => {
    // Mutation (Rule 19): drop the `announcementText.set('')` from the effect's terminal branch ->
    // this goes red, and the polite region holds "One minute left to confirm" under Expired.
    const { fixture, card } = mount(liveView({ expiresAt: NOW_MS + 30_000 }), { phase: 'live' });
    expect(card.querySelector('.ocu-proposal-card-announcement')?.textContent?.trim()).toBe(
      STRINGS.proposalCountdownAnnouncement
    );
    fixture.componentRef.setInput('phase', 'canceled-by-you');
    fixture.detectChanges();
    expect(card.querySelector('.ocu-proposal-card-announcement')?.textContent?.trim()).toBe('');
  });

  it('a transition nobody pressed leaves focus where it was: the status line is a destination, not a grab', () => {
    // Mutation (Rule 19): focus the status line unconditionally -> this goes red, and a typed
    // message cancelling three cards would pull focus out of the composer.
    const { fixture, card } = mount(liveView(), { phase: 'live' });
    const outside = document.createElement('button');
    document.body.appendChild(outside);
    try {
      outside.focus();
      fixture.componentRef.setInput('phase', 'canceled-by-message');
      fixture.detectChanges();
      expect(card.querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe(
        STRINGS.proposalStatusCanceledByMessage
      );
      expect(document.activeElement).toBe(outside);
    } finally {
      outside.remove();
    }
  });

  it('every terminal phase reads its own published status line, and two of them offer Re-propose', () => {
    const lines: [ProposalPhase, string][] = [
      ['canceled-sibling', STRINGS.proposalStatusCanceledSibling],
      ['switched-off', STRINGS.proposalStatusAgentSwitchedOff],
      ['expired', STRINGS.proposalStatusExpired],
      ['target-changed', STRINGS.proposalTargetChanged],
    ];
    const reproposable = new Set<ProposalPhase>(['expired', 'target-changed']);
    for (const [phase, line] of lines) {
      const { card } = mount(liveView(), { phase });
      const status = card.querySelector('.ocu-proposal-card-status') as HTMLElement;
      // The fingerprint refusal renders its line inside the warning banner, whose glyph is
      // `aria-hidden` -- so the sentence is the banner's message span, not the whole node's text.
      const sentence = status.querySelector('.ocu-banner-message') ?? status;
      expect(sentence.textContent?.trim()).toBe(line);
      expect(card.classList.contains('ocu-proposal-card-restrained')).toBe(true);
      // A card that arrived terminal never had buttons to disable.
      expect(card.querySelector('.ocu-proposal-card-confirm')).toBeNull();
      expect(card.querySelector('.ocu-proposal-card-repropose') === null).toBe(!reproposable.has(phase));
    }
    const confirmed = mount(liveView(), { phase: 'confirmed', confirmedAt: '10:31:04' });
    expect(confirmed.card.querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe(
      'Confirmed by _SYSTEM \u00b7 10:31:04'
    );
  });

  it('a restored card is shown expired with Re-propose, and never live (DW-1213)', () => {
    // The restore path records the terminal state (`core/turn.ts`'s `restoredProposals`); this is
    // what the card then draws, unburned and unexpired on the instance or not.
    const { card } = mount(liveView({ expiresAt: NOW_MS + 599_000 }), { phase: 'expired' });
    expect(card.querySelector('.ocu-proposal-card-confirm')).toBeNull();
    expect(card.querySelector('.ocu-proposal-card-countdown')).toBeNull();
    expect(card.querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe(
      STRINGS.proposalStatusExpired
    );
    expect(card.querySelector('.ocu-proposal-card-repropose')).not.toBeNull();
  });

  // --- The masked field, the audit warning, the unknown expiry -----------------------------------

  it('AC4: a masked field appears per declared secret and Confirm is aria-disabled until it is filled', () => {
    // Mutation (Rule 19): drop the gate from `confirmAriaDisabled` -> this goes red on Confirm
    // being pressable with the field empty.
    const view = liveView({
      maskedFields: ['Password'],
      changed: [{ field: 'Password', before: MASKED_VALUE, after: MASKED_VALUE }],
    });
    const { fixture, card } = mount(view, { phase: 'live' });
    const field = card.querySelector('.ocu-proposal-card-secret') as HTMLInputElement;
    expect(field).not.toBeNull();
    expect(field.getAttribute('type')).toBe('password');
    expect(field.getAttribute('aria-required')).toBe('true');
    const label = card.querySelector('label.ocu-field-label') as HTMLLabelElement;
    expect(label.getAttribute('for')).toBe(field.id);
    expect(label.textContent?.trim()).toBe('Password');

    expect(card.querySelector('.ocu-proposal-card-confirm')?.getAttribute('aria-disabled')).toBe('true');

    field.value = 'a secret';
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    expect(card.querySelector('.ocu-proposal-card-confirm')?.hasAttribute('aria-disabled')).toBe(false);

    // And the diff row the instance sent reads the mask on both sides.
    const values = Array.from(card.querySelectorAll('.ocu-diff-row .ocu-diff-value')).map((node) =>
      node.textContent?.trim()
    );
    expect(values).toEqual([MASKED_VALUE, MASKED_VALUE]);
  });

  it('a proposal that would turn auditing off carries the published warning above the footer', () => {
    // Mutation (Rule 19): stop projecting `auditWarning` in the mint -> the view carries false and
    // this goes red; the ObjectScript half is `OcuPilot.Test.ProposalWire`'s.
    const { card } = mount(liveView({ auditWarning: true }), { phase: 'live' });
    const warning = card.querySelector('.ocu-proposal-card-warning') as HTMLElement;
    expect(warning.textContent).toContain(STRINGS.proposalAuditWarning);
    const footer = card.querySelector('.ocu-proposal-card-footer') as HTMLElement;
    expect(warning.compareDocumentPosition(footer) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();

    expect(mount(liveView(), { phase: 'live' }).card.querySelector('.ocu-proposal-card-warning')).toBeNull();
  });

  it('the in-card warning is a status region, the convention for an advisory', () => {
    // DW-1246, corrected: four warning banners in this shell are already `role="status"`. The
    // convention is `alert` for a fault or a refusal and `status` for an advisory, and this is an
    // advisory: the write is still offered.
    //
    // Mutation (Rule 19): change the role to `alert` -> this goes red.
    const { card } = mount(liveView({ auditWarning: true }), { phase: 'live' });
    expect(card.querySelector('.ocu-proposal-card-warning')?.getAttribute('role')).toBe('status');
  });

  it('AC1: a destructive proposal draws its left-edge bar and its Confirm in the destructive treatment', () => {
    // The declaration is the write tool's own and arrives on the wire (DESIGN.md `:1176`, `:1243`).
    // The typed-name field DESIGN.md pairs with `button-destructive` is Story 14.7's: shipping it
    // here would leave Confirm permanently `aria-disabled`.
    //
    // Mutation (Rule 19): answer 0 from `OcuPilot.Screen.Tool.Write.Destructive` for the auditing
    // tool, or drop `destructive` from `toCardView` -> these go red.
    const { card } = mount(liveView({ destructive: true, maskedFields: [] }), { phase: 'live' });
    expect(card.classList.contains('ocu-proposal-card-destructive')).toBe(true);
    const confirm = card.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement;
    expect(confirm.classList.contains('ocu-button-destructive')).toBe(true);
    expect(confirm.classList.contains('ocu-button-primary')).toBe(false);

    const plain = mount(liveView({ maskedFields: [] }), { phase: 'live' });
    expect(plain.card.classList.contains('ocu-proposal-card-destructive')).toBe(false);
    const plainConfirm = plain.card.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement;
    expect(plainConfirm.classList.contains('ocu-button-primary')).toBe(true);
    expect(plainConfirm.classList.contains('ocu-button-destructive')).toBe(false);
  });

  it('DW-1232: an unfilled masked field gives Confirm a published reason through aria-describedby', () => {
    // A control that refuses and says nothing is the gap: `aria-disabled` says the press will not
    // work and the published sentence says why.
    //
    // Mutation (Rule 19): return `null` from `confirmReasonId` unconditionally -> this goes red.
    const view = liveView({
      maskedFields: ['Password'],
      changed: [{ field: 'Password', before: MASKED_VALUE, after: MASKED_VALUE }],
    });
    const { fixture, card } = mount(view, { phase: 'live' });
    const confirm = card.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement;
    const reasonId = confirm.getAttribute('aria-describedby');
    expect(reasonId).not.toBeNull();
    const reason = card.querySelector('#' + reasonId) as HTMLElement;
    expect(reason.textContent?.trim()).toBe(STRINGS.proposalSecretsRequired);

    const field = card.querySelector('.ocu-proposal-card-secret') as HTMLInputElement;
    field.value = 'a secret';
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    expect(card.querySelector('.ocu-proposal-card-confirm')?.hasAttribute('aria-describedby')).toBe(false);
  });

  it('AC9: Confirm carries the typed secret values with the press, and nothing else holds them', () => {
    // The card is the only thing that ever holds a typed secret: it is not in the panel's state,
    // not in the turn store and not in the view model (AD-35). The values travel with the press.
    //
    // Mutation (Rule 19): emit the proposal id alone again -> this goes red. It is the only tier
    // that can redden: no shipped descriptor declares a secret, so the panel builds no masked field
    // and the posted confirm body is empty either way.
    const view = liveView({
      maskedFields: ['Password'],
      changed: [{ field: 'Password', before: MASKED_VALUE, after: MASKED_VALUE }],
    });
    const { fixture, card } = mount(view, { phase: 'live' });
    const seen: { proposalId: string; secrets: Record<string, string> }[] = [];
    fixture.componentRef.instance.confirm.subscribe((request) => seen.push(request));
    const field = card.querySelector('.ocu-proposal-card-secret') as HTMLInputElement;
    field.value = 'hunter2';
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (card.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).click();
    expect(seen).toEqual([{ proposalId: 'p1', secrets: { Password: 'hunter2' } }]);
    // The value is never rendered anywhere but its own password input.
    expect(card.textContent).not.toContain('hunter2');
  });

  /**
   * DW-1348 (Story 5.6). A confirm refused 403 `PROHIBITED.*`, or by the restraint verdict, leaves
   * the row **live** on purpose -- the condition can clear -- so nothing about the row says the
   * press happened, and until now the card returned to its pre-press state with no trace.
   *
   * What is asserted is the whole of the AC: the envelope's own written reason is on the card,
   * above the footer, and Confirm and Cancel are still offered beside it.
   *
   * mutation: drop the `recordProposalRefusal` call from `decideProposal`'s error path in
   * `core/turn.ts` -> the panel passes `''` and this goes red on the reason. Second mutation: make
   * `refusalVisible` read `this.restrained` instead of `this.live` -> the banner is absent on a
   * live card and this goes red the same way.
   */
  it('a refusal that left the row live is on the card, above a footer that still offers Confirm', () => {
    const reason = 'Granting privilege is not something the agent may propose on this instance.';
    const { card } = mount(liveView({ refusalReason: reason }), { phase: 'live' });

    const banner = card.querySelector('[data-slot="refusal"]') as HTMLElement;
    expect(banner).not.toBeNull();
    // The server's own words, carried through (AD-39): the client authors no second copy.
    expect(banner.textContent).toContain(reason);
    expect(banner.classList.contains('ocu-banner-warning')).toBe(true);

    const footer = card.querySelector('.ocu-proposal-card-footer') as HTMLElement;
    expect(banner.compareDocumentPosition(footer) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();

    // The press was refused, not the proposal: both decisions stay offered and neither is gated.
    const confirm = card.querySelector('.ocu-proposal-card-confirm') as HTMLElement;
    const cancel = card.querySelector('.ocu-proposal-card-cancel') as HTMLElement;
    expect(confirm.getAttribute('aria-disabled')).toBeNull();
    expect(cancel.getAttribute('aria-disabled')).toBeNull();
    // And no phase was invented for it: the card is not restrained and shows no status line.
    expect(card.classList.contains('ocu-proposal-card-restrained')).toBe(false);
    expect(card.querySelector('.ocu-proposal-card-status')).toBeNull();

    // A card with no refusal draws none, so the assertion above is about the reason and not about
    // a banner that is always there.
    expect(mount(liveView(), { phase: 'live' }).card.querySelector('[data-slot="refusal"]')).toBeNull();
  });

  it('a refusal that closed the row shows its terminal status line and not the refusal banner', () => {
    // A refusal that CLOSED the row leaves its own status line; drawing both would say two things
    // about one press.
    const { card } = mount(liveView({ refusalReason: 'stale' }), { phase: 'target-changed' });
    expect(card.querySelector('[data-slot="refusal"]')).toBeNull();
    expect(card.querySelector('.ocu-proposal-card-status')).not.toBeNull();
  });

  it('an unreadable expiry renders no time and leaves the card live', () => {
    // `core/turn.ts` records 0 for a wire timestamp it could not parse. Treated as unknown, never
    // as expired: the card keeps its Confirm.
    const { card } = mount(liveView({ expiresAt: 0 }), { phase: 'live' });
    expect(card.querySelector('.ocu-proposal-card-countdown')).toBeNull();
    expect(card.querySelector('.ocu-proposal-card-confirm')).not.toBeNull();
    expect(card.querySelector('.ocu-proposal-card-status')).toBeNull();
    expect(card.classList.contains('ocu-proposal-card-restrained')).toBe(false);
  });

  // --- The in-flight Confirm, the fingerprint banner and the announcement (Story 5.3) ------------

  it('AC8: Confirm in flight shows progress, is aria-disabled, and keeps focus', () => {
    // Mutation (Rule 19): drop the `confirming` arm from `confirmAriaDisabled` -> the second
    // assertion goes red, and a second press would post the same confirm twice.
    const { fixture, card } = mount(liveView({ maskedFields: [] }), { phase: 'live' });
    const confirm = card.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement;
    confirm.focus();

    fixture.componentRef.setInput('phase', 'confirming');
    fixture.detectChanges();
    const busy = card.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement;
    expect(busy.querySelector('.ocu-proposal-card-confirm-spinner')).not.toBeNull();
    expect(busy.getAttribute('aria-disabled')).toBe('true');
    expect(busy.hasAttribute('disabled')).toBe(false);
    expect(document.activeElement).toBe(busy);
    // In flight is not terminal: no status line yet, and the card is not restrained.
    expect(card.querySelector('.ocu-proposal-card-status')).toBeNull();
    expect(card.classList.contains('ocu-proposal-card-restrained')).toBe(false);
  });

  it('AC8: a confirmed card replaces its buttons with the line the instance stamped', async () => {
    const { fixture, card } = mount(liveView({ maskedFields: [] }), { phase: 'live' });
    (card.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).focus();
    fixture.componentRef.setInput('phase', 'confirming');
    fixture.detectChanges();
    fixture.componentRef.setInput('phase', 'confirmed');
    fixture.componentRef.setInput('confirmedAt', '10:31:04');
    fixture.detectChanges();

    const status = card.querySelector('.ocu-proposal-card-status') as HTMLElement;
    expect(status.textContent?.trim()).toBe('Confirmed by _SYSTEM \u00b7 10:31:04');
    expect(status.classList.contains('ocu-proposal-card-status-confirmed')).toBe(true);
    expect(document.activeElement).toBe(status);
    await macrotask();
    fixture.detectChanges();
    expect(card.querySelector('.ocu-proposal-card-confirm')).toBeNull();
    expect(card.querySelector('.ocu-proposal-card-cancel')).toBeNull();
  });

  it('AC4: the fingerprint refusal draws its line inside the warning banner, with only Re-propose', () => {
    const { card } = mount(liveView(), { phase: 'target-changed' });
    const status = card.querySelector('.ocu-proposal-card-status') as HTMLElement;
    expect(status.classList.contains('ocu-banner')).toBe(true);
    expect(status.classList.contains('ocu-banner-warning')).toBe(true);
    expect(status.querySelector('.ocu-banner-message')?.textContent?.trim()).toBe(
      STRINGS.proposalTargetChanged
    );
    expect(status.getAttribute('tabindex')).toBe('-1');
    // The banner is above the footer's own buttons, and the only action offered is Re-propose.
    expect(card.querySelector('.ocu-proposal-card-confirm')).toBeNull();
    expect(card.querySelector('.ocu-proposal-card-cancel')).toBeNull();
    // Re-propose keeps the product's gated-control discipline: never the `disabled` attribute, so
    // it stays in the tab order and reachable. Asserting the absence of `aria-disabled` alone
    // could not fail -- on a rendered Re-propose the binding is always null.
    const repropose = card.querySelector('.ocu-proposal-card-repropose') as HTMLButtonElement;
    expect(repropose).not.toBeNull();
    expect(repropose.hasAttribute('disabled')).toBe(false);
    expect(repropose.tabIndex).toBeGreaterThanOrEqual(0);
  });

  it('AC8: Cancel is refused while a Confirm is in flight', () => {
    // Mutation (Rule 19): drop the `confirming` arm from `cancelAriaDisabled` -> this goes red,
    // and a card would read "Canceled by you" over a proposal the instance had confirmed.
    const { fixture, card } = mount(liveView({ maskedFields: [] }), { phase: 'live' });
    const seen: string[] = [];
    fixture.componentInstance.cancel.subscribe((id: string) => seen.push(id));

    fixture.componentRef.setInput('phase', 'confirming');
    fixture.detectChanges();
    const cancel = card.querySelector('.ocu-proposal-card-cancel') as HTMLButtonElement;
    expect(cancel.getAttribute('aria-disabled')).toBe('true');
    // Reachable, not removed: the discipline is `aria-disabled`, never the `disabled` attribute.
    expect(cancel.hasAttribute('disabled')).toBe(false);
    cancel.click();
    expect(seen).toEqual([]);
  });

  it('DW-1229: the status line is a status region only when it did not take focus', () => {
    // Mutation (Rule 19): bind `role="status"` unconditionally -> the first half goes red, and a
    // transition the user pressed would announce twice -- once as a focus move, once as a region.
    const pressed = mount(liveView({ maskedFields: [] }), { phase: 'live' });
    (pressed.card.querySelector('.ocu-proposal-card-cancel') as HTMLButtonElement).focus();
    pressed.fixture.componentRef.setInput('phase', 'canceled-by-you');
    pressed.fixture.detectChanges();
    const focused = pressed.card.querySelector('.ocu-proposal-card-status') as HTMLElement;
    expect(document.activeElement).toBe(focused);
    expect(focused.getAttribute('role')).toBeNull();

    const outside = document.createElement('button');
    document.body.appendChild(outside);
    try {
      const elsewhere = mount(liveView({ maskedFields: [] }), { phase: 'live' });
      outside.focus();
      elsewhere.fixture.componentRef.setInput('phase', 'canceled-by-message');
      elsewhere.fixture.detectChanges();
      const announced = elsewhere.card.querySelector('.ocu-proposal-card-status') as HTMLElement;
      expect(document.activeElement).toBe(outside);
      expect(announced.getAttribute('role')).toBe('status');
    } finally {
      outside.remove();
    }
  });

  it('Confirm, Cancel and Re-propose each emit the proposal they are about', () => {
    const { fixture, card } = mount(liveView({ maskedFields: [] }), { phase: 'live' });
    const seen: string[] = [];
    fixture.componentRef.instance.confirm.subscribe((request) =>
      seen.push('confirm:' + request.proposalId + ':' + JSON.stringify(request.secrets))
    );
    fixture.componentRef.instance.cancel.subscribe((id) => seen.push('cancel:' + id));
    (card.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).click();
    (card.querySelector('.ocu-proposal-card-cancel') as HTMLButtonElement).click();
    // Confirm carries the values typed into its masked fields with the press (Story 5.10, AD-35):
    // this card declares none, so the map is empty and the id is all there is.
    expect(seen).toEqual(['confirm:p1:{}', 'cancel:p1']);

    const expired = mount(liveView(), { phase: 'expired' });
    const reproposed: string[] = [];
    expired.fixture.componentRef.instance.repropose.subscribe((id) => reproposed.push(id));
    (expired.card.querySelector('.ocu-proposal-card-repropose') as HTMLButtonElement).click();
    expect(reproposed).toEqual(['p1']);
  });
});

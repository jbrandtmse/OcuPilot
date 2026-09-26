import { ChangeDetectionStrategy, Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import type { DraftStep } from '../core/draft';
import type { ProposalPhase } from '../core/proposal-view';
import { STRINGS } from '../core/strings';
import { CodeBlock } from './code-block';
import { EXAMPLE_PROPOSAL, type ProposalCardView } from './example-proposal';
import { ProposalCard } from './proposal-card';

/**
 * Pins the proposal card's copy-out draft action (Story 14.1, AD-59): "Give me the script instead"
 * sits after Cancel wherever Cancel is, is refused wherever Cancel is, and emits the proposal it is
 * about; a card closed by a draft reads its own status line, takes the restrained treatment and
 * hands focus to that line; and the script the panel projects lands in the card's footer slot.
 */

const NOW_MS = Date.parse('2026-09-19T09:50:00Z');

function liveView(overrides: Partial<ProposalCardView> = {}): ProposalCardView {
  return { ...EXAMPLE_PROPOSAL, proposalId: 'p1', expiresAt: NOW_MS + 599_000, maskedFields: [], ...overrides };
}

interface Mounted {
  readonly fixture: ComponentFixture<ProposalCard>;
  readonly card: HTMLElement;
}

function mount(view: ProposalCardView, phase: ProposalPhase | null): Mounted {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({});
  const fixture = TestBed.createComponent(ProposalCard);
  fixture.componentRef.setInput('view', view);
  fixture.componentRef.setInput('phase', phase);
  fixture.componentRef.setInput('nowMs', NOW_MS);
  fixture.componentRef.setInput('userName', '_SYSTEM');
  fixture.detectChanges();
  document.body.appendChild(fixture.nativeElement);
  return { fixture, card: fixture.nativeElement.querySelector('.ocu-proposal-card') as HTMLElement };
}

const DRAFT = '.ocu-proposal-card-draft-action';

function macrotask(): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

const STEPS: readonly DraftStep[] = [{ kind: 'rest', text: "curl -X PUT '<origin>/api/admin/v2/webapp'" }];

/** The panel's projection, in miniature: the caption and the script in the card's footer slot. */
@Component({
  selector: 'app-proposal-card-draft-host',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ProposalCard, CodeBlock],
  template: `<app-proposal-card [view]="view" [phase]="phase" [nowMs]="nowMs">
    <div card-footer class="ocu-proposal-card-draft">
      <p class="ocu-proposal-card-draft-caption">{{ STRINGS.proposalDraftCaption }}</p>
      <app-code-block [steps]="steps" />
    </div>
  </app-proposal-card>`,
})
class DraftHost {
  protected readonly STRINGS = STRINGS;
  protected readonly view = liveView();
  protected readonly phase: ProposalPhase = 'canceled-by-draft';
  protected readonly nowMs = NOW_MS;
  protected readonly steps = STEPS;
}

describe('the proposal card: Give me the script instead', () => {
  it('a live card offers it after Cancel, as a text button carrying the published name', () => {
    // Mutation (Rule 19): remove the button from the template -> this goes red.
    const { card } = mount(liveView(), 'live');
    const cancel = card.querySelector('.ocu-proposal-card-cancel') as HTMLElement;
    const draft = card.querySelector(DRAFT) as HTMLButtonElement;
    expect(draft).not.toBeNull();
    expect(cancel.nextElementSibling).toBe(draft);
    expect(draft.textContent?.trim()).toBe(STRINGS.actionTakeScript);
    expect(draft.textContent?.trim()).toBe('Give me the script instead');
    expect(draft.classList.contains('ocu-button-text')).toBe(true);
    expect(draft.getAttribute('type')).toBe('button');
    expect(draft.getAttribute('aria-disabled')).toBeNull();
  });

  it('emits the proposal it is about', () => {
    const { fixture, card } = mount(liveView(), 'live');
    const seen: string[] = [];
    fixture.componentRef.instance.draft.subscribe((id) => seen.push(id));
    (card.querySelector(DRAFT) as HTMLButtonElement).click();
    expect(seen).toEqual(['p1']);
  });

  it("follows Cancel's rule: refused while a Confirm is out, and emits nothing then", () => {
    const { fixture, card } = mount(liveView(), 'confirming');
    const draft = card.querySelector(DRAFT) as HTMLButtonElement;
    const cancel = card.querySelector('.ocu-proposal-card-cancel') as HTMLButtonElement;
    expect(draft.getAttribute('aria-disabled')).toBe('true');
    expect(draft.getAttribute('aria-disabled')).toBe(cancel.getAttribute('aria-disabled'));
    const seen: string[] = [];
    fixture.componentRef.instance.draft.subscribe((id) => seen.push(id));
    draft.click();
    expect(seen).toEqual([]);
  });

  it('is absent wherever Cancel is: the static example, and a card that arrived terminal', () => {
    for (const phase of [null, 'expired', 'canceled-by-draft', 'confirmed'] as const) {
      const { card } = mount(liveView(), phase);
      expect(card.querySelector(DRAFT)).toBeNull();
      expect(card.querySelector('.ocu-proposal-card-cancel')).toBeNull();
    }
  });

  it('a card closed by a draft reads its own line, is restrained, and the line takes focus from the button', async () => {
    const { fixture, card } = mount(liveView(), 'live');
    const draft = card.querySelector(DRAFT) as HTMLButtonElement;
    draft.focus();
    fixture.componentRef.setInput('phase', 'canceled-by-draft');
    fixture.detectChanges();
    // Across the transition the outgoing button is refused, never removed while it holds focus.
    const status = card.querySelector('.ocu-proposal-card-status') as HTMLElement;
    expect(status.textContent?.trim()).toBe(STRINGS.proposalStatusCanceledByDraft);
    expect(card.classList.contains('ocu-proposal-card-restrained')).toBe(true);
    expect(document.activeElement).toBe(status);
    await macrotask();
    fixture.detectChanges();
    expect(card.querySelector(DRAFT)).toBeNull();
    expect(card.querySelector('.ocu-proposal-card-repropose')).toBeNull();
  });

  it("the script the panel projects lands in the card's footer slot, under its caption", () => {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({});
    const fixture = TestBed.createComponent(DraftHost);
    fixture.detectChanges();
    const card = fixture.nativeElement.querySelector('.ocu-proposal-card') as HTMLElement;
    const projected = card.querySelector('.ocu-proposal-card-draft') as HTMLElement;
    expect(projected).not.toBeNull();
    expect(projected.querySelector('.ocu-proposal-card-draft-caption')?.textContent).toBe(STRINGS.proposalDraftCaption);
    expect(projected.querySelector('pre.ocu-code-block-pre')?.textContent).toBe(STEPS[0].text);
    // Above the status line, which is still the card's last word.
    const status = card.querySelector('.ocu-proposal-card-status') as HTMLElement;
    expect(projected.compareDocumentPosition(status) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });
});

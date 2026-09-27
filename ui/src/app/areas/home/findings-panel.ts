import { ChangeDetectionStrategy, Component, input, output } from '@angular/core';

import type { Finding, FindingGroupKey } from '../../core/findings';
import { STRINGS } from '../../core/strings';

/** What a finding's line offers: Fix it, Open, the prohibited set's sentence, or nothing. */
export type FindingAction = 'fix' | 'open' | 'refused' | 'none';

/** One line of a group, resolved by Home for rendering. */
export interface FindingRow {
  readonly key: string;
  readonly kind: 'finding' | 'unread' | 'clean';
  readonly text: string;
  readonly why: string;
  readonly todo: string;
  /** The sentence element's id, which a Fix it control is described by. */
  readonly sentenceId: string;
  readonly action: FindingAction;
  /** Open's address, `''` for any other action. */
  readonly href: string;
  /** The prohibited set's own sentence, on a refused finding; `''` otherwise. */
  readonly refusal: string;
  /** `'true'` while the Fix it gate names a reason; `null` otherwise. */
  readonly ariaDisabled: string | null;
  /** The ids a Fix it control is described by. */
  readonly describedBy: string | null;
  readonly finding: Finding | null;
}

export interface FindingGroupView {
  readonly key: FindingGroupKey;
  readonly heading: string;
  readonly headingId: string;
  readonly rows: readonly FindingRow[];
}

/**
 * Home's Findings panel (Story 16.21): its heading, then the Security and Operations groups, each a
 * heading and a list. A finding shows its sentence, why it matters and what to do, then one action:
 * Fix it, Open, or the prohibited set's own sentence. Every name is rendered as text.
 *
 * Presentational: Home owns the store and the gate, resolves each row, and handles the two
 * outputs. A Fix it control is `aria-disabled`, never `disabled`, while the gate names a reason.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-findings-panel',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="ocu-home-findings" aria-labelledby="ocu-home-findings-heading">
    <h2 class="ocu-home-block-heading" id="ocu-home-findings-heading">{{ STRINGS.findingsHeading }}</h2>
    @if (faultShown) {
      <p class="ocu-home-block-empty">{{ STRINGS.connectivityServerFault }}</p>
    }
    <div class="ocu-home-findings-groups">
      @for (group of groupViews; track group.key) {
        <section class="ocu-home-findings-group" [attr.aria-labelledby]="group.headingId">
          <h3 class="ocu-home-findings-group-heading" [id]="group.headingId">{{ group.heading }}</h3>
          <ul class="ocu-home-findings-list">
            @for (row of group.rows; track row.key) {
              <li class="ocu-home-finding" [class.ocu-home-finding-quiet]="row.finding === null">
                <p class="ocu-home-finding-sentence" [id]="row.sentenceId">{{ row.text }}</p>
                @if (row.why) {
                  <p class="ocu-home-finding-detail">{{ row.why }}</p>
                }
                @if (row.todo) {
                  <p class="ocu-home-finding-detail">{{ row.todo }}</p>
                }
                @switch (row.action) {
                  @case ('fix') {
                    <button
                      type="button"
                      class="ocu-home-finding-fix"
                      [attr.aria-disabled]="row.ariaDisabled"
                      [attr.aria-describedby]="row.describedBy"
                      (click)="fix.emit(row)"
                    >
                      {{ STRINGS.findingsFix }}
                    </button>
                  }
                  @case ('open') {
                    <a class="ocu-home-finding-open" [href]="row.href" (click)="onOpen($event, row)">{{
                      STRINGS.homeSuggestedOpen
                    }}</a>
                  }
                  @case ('refused') {
                    <p class="ocu-home-finding-refused">{{ row.refusal }}</p>
                  }
                }
              </li>
            }
          </ul>
        </section>
      }
    </div>
  </section>`,
})
export class FindingsPanel {
  protected readonly STRINGS = STRINGS;

  readonly groups = input.required<readonly FindingGroupView[]>();

  /** Whether the read has never answered and the last one failed. */
  readonly unanswered = input(false);

  readonly fix = output<FindingRow>();

  readonly open = output<FindingRow>();

  protected get groupViews(): readonly FindingGroupView[] {
    return this.groups();
  }

  protected get faultShown(): boolean {
    return this.unanswered();
  }

  /** An ordinary click opens the screen in place; a modified click is left to the browser. */
  protected onOpen(event: MouseEvent, row: FindingRow): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    this.open.emit(row);
  }
}

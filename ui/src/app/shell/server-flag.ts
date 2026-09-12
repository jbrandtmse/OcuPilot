import { ChangeDetectionStrategy, Component, input } from '@angular/core';

import { serverFlagKind } from '../core/instance';
import { STRINGS } from '../core/strings';

/**
 * The server-flag badge: an 18px pill naming the instance's system mode (DESIGN.md `:1025`,
 * EXPERIENCE.md `:319`).
 *
 * **A component of its own, not a corner of the status bar**, because Story 1.12's Home
 * instance line renders the same badge from the same identity field, and DESIGN.md `:1025`
 * names both surfaces. It never appears in the header.
 *
 * **An unflagged instance gets no badge (DW-10).** `SystemMode()` is `''` until somebody sets
 * a mode, and the vendor's own setter normalises anything outside its four to `''`, so
 * absence is the ordinary state -- this container is in it. The badge renders nothing rather
 * than defaulting to a word the instance did not say.
 *
 * **An unrecognised mode is drawn verbatim in `restrained`.** A value outside the four can
 * only have reached the global by a direct write; showing it as-is says what the instance
 * reported, where mapping it onto one of the four would invent a claim and dropping it would
 * hide a misconfiguration.
 *
 * The word is always present -- colour alone never carries the flag (EXPERIENCE.md `:319`).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-server-flag',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `@if (present) {
    <span class="ocu-server-flag" [attr.data-flag]="kind">{{ word }}</span>
  }`,
})
export class ServerFlag {
  /** The system mode the instance reported, verbatim. `''` means no mode is set. */
  readonly value = input('');

  /** `none` when nothing is set, one of the four, or `unknown` for anything else. */
  protected get kind(): string {
    return serverFlagKind(this.value());
  }

  protected get present(): boolean {
    return this.kind !== 'none';
  }

  /**
   * The badge's word: the canonical string for one of the four, and the reported value itself
   * for anything else. Resolved here rather than in the template, because a template that
   * picked between four literals would be copy typed into a component.
   */
  protected get word(): string {
    switch (this.kind) {
      case 'live':
        return STRINGS.serverFlagLive;
      case 'test':
        return STRINGS.serverFlagTest;
      case 'failover':
        return STRINGS.serverFlagFailover;
      case 'development':
        return STRINGS.serverFlagDevelopment;
      default:
        return this.value();
    }
  }
}

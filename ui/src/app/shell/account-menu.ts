import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  effect,
  inject,
  signal,
  viewChild,
} from '@angular/core';

import { Session } from '../core/session';
import { STRINGS } from '../core/strings';

/**
 * The account menu: the one affordance that reaches `Session.signOut()`
 * (EXPERIENCE.md `:79`, `:317`, Session state 8).
 *
 * A trigger carrying the signed-in user's name and a down triangle, and a one-item menu
 * behind it holding Sign out. There is no confirmation step: EXPERIENCE.md `:171`
 * enumerates every dialog that exists in Release 1 and sign-out is not one of them.
 *
 * **It is mounted in `app.ts`, not in a status bar, because the status bar does not exist
 * yet.** Story 1.10 owns the band and moves this component into it; building the menu
 * here keeps the acceptance criterion observable now and leaves 1.10 a component to place
 * rather than a feature to invent. For the same reason the focus ring is the existing
 * `ocu-focus-ring` mixin rather than DESIGN.md's `focus-ring.on-chrome`, which arrives
 * with the navy band it is drawn for.
 *
 * **Keyboard (EXPERIENCE.md `:532`).** Opening moves focus to the first item; Escape
 * closes the menu and returns focus to the trigger. The trigger is focused *before* the
 * item is removed from the DOM, because removing a control while it holds focus is banned
 * outright (EXPERIENCE.md, Interaction Primitives).
 *
 * **The glyph is a character produced in TypeScript, never a literal byte in the
 * template** (Rule 14, and the Consistency Conventions' "non-ASCII authored as `\uXXXX`
 * escapes"). It is `aria-hidden`, so the trigger's accessible name is the user name
 * alone -- which is also what labels the menu, through `aria-labelledby`. No new string
 * is introduced: `actionSignOut` already exists in the string source, which
 * EXPERIENCE.md's Fixed strings table is the sole authority for.
 *
 * Every control-flow condition is a paren-free member reference, for the reason
 * `sign-in.ts` records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one
 * parenthesised group, so a call expression in the condition leaves a stray `)` that the
 * literal-text-node rule reports and `npm run build` fails on.
 */
@Component({
  selector: 'app-account-menu',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<div class="ocu-account" (keydown.escape)="closeAndRefocus()">
      <button
        #trigger
        id="ocu-account-trigger"
        type="button"
        class="ocu-account-trigger"
        aria-haspopup="menu"
        [attr.aria-expanded]="open"
        (click)="toggle()"
      >
        <span class="ocu-account-name">{{ userName() }}</span>
        <span class="ocu-account-caret" aria-hidden="true">{{ caretGlyph }}</span>
      </button>
      @if (open) {
        <div class="ocu-account-panel" role="menu" aria-labelledby="ocu-account-trigger">
          <button
            #firstItem
            type="button"
            class="ocu-account-item"
            role="menuitem"
            (click)="chooseSignOut()"
          >
            {{ STRINGS.actionSignOut }}
          </button>
        </div>
      }
    </div>`,
})
export class AccountMenu {
  private readonly session = inject(Session);

  protected readonly STRINGS = STRINGS;

  /**
   * The down triangle the status bar's user segment carries (EXPERIENCE.md `:317`,
   * DESIGN.md `:1021`), written as its escape so no non-ASCII byte enters a source file.
   */
  protected readonly caretGlyph = '\u25BE';

  private readonly triggerEl = viewChild.required<ElementRef<HTMLButtonElement>>('trigger');

  private readonly firstItemEl = viewChild<ElementRef<HTMLButtonElement>>('firstItem');

  private readonly openFlag = signal(false);

  /** Mirrors the framework-free session's user name into the reactive graph. */
  protected readonly userName = signal(this.session.userName());

  constructor() {
    const stop = this.session.subscribe(() => {
      this.userName.set(this.session.userName());
    });
    inject(DestroyRef).onDestroy(stop);

    // A `role="menu"` that never takes focus is a menu only in name. The item does not
    // exist until the `@if` has rendered, which under zoneless change detection is after
    // the click handler has returned -- so the move is made from an effect, which runs
    // once the view query has been updated with the rendered element.
    effect(() => {
      if (!this.openFlag()) return;
      this.firstItemEl()?.nativeElement.focus();
    });
  }

  protected get open(): boolean {
    return this.openFlag();
  }

  protected toggle(): void {
    if (this.openFlag()) {
      this.closeAndRefocus();
      return;
    }
    this.openFlag.set(true);
  }

  /**
   * Escape, and a second click on the trigger. Focus is restored first, so the item is
   * never removed while it holds it.
   */
  protected closeAndRefocus(): void {
    if (!this.openFlag()) return;
    this.triggerEl().nativeElement.focus();
    this.openFlag.set(false);
  }

  /**
   * Close, then sign out. The local half of `signOut()` runs synchronously (DW-5), so by
   * the time this returns the session is already `signed-out` and `app.ts` has withheld
   * the routed outlet; the request the method issues is not waited on here.
   */
  protected chooseSignOut(): void {
    this.openFlag.set(false);
    void this.session.signOut();
  }
}

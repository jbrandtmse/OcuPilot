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

import { OverlayStack } from '../core/overlay-stack';
import { Session } from '../core/session';
import { STRINGS } from '../core/strings';

/** The account menu's name on the overlay stack (DW-109, DW-137). */
export const ACCOUNT_MENU_OVERLAY_ID = 'account-menu';

/**
 * The account menu: the one affordance that reaches `Session.signOut()`
 * (EXPERIENCE.md "status-bar user segment", "`{spacing.status-bar-height}` band", Session state 8).
 *
 * A trigger carrying the signed-in user's name and a down triangle, and a one-item menu
 * behind it holding Sign out. There is no confirmation step: EXPERIENCE.md "Dialogs exist only for: set"
 * enumerates every dialog that exists in Release 1 and sign-out is not one of them.
 *
 * **It is the status bar's user segment** (DESIGN.md `:1021`) and the band's only
 * interactive element. Story 1.7 mounted it directly in `app.ts` because the band did not
 * exist; Story 1.10 built the band and moved it here.
 *
 * **Keyboard (EXPERIENCE.md "panel, command-box, side-bar").** Opening moves focus to the first item; Escape
 * closes the menu and returns focus to the trigger. The trigger is focused *before* the
 * item is removed from the DOM, because removing a control while it holds focus is banned
 * outright (EXPERIENCE.md, Interaction Primitives).
 *
 * **Escape is the overlay stack's, not this component's.** The menu registers while it is
 * open and the shell's one Escape handler closes the topmost member. A local
 * `(keydown.escape)` binding as well would close the menu *and* let the same key press
 * reach the side bar underneath, which is the double-dismissal the stack exists to prevent
 * (DW-137).
 *
 * **It also closes on a pointer or focus gesture outside it (DW-109).** A menu that only
 * closed on Escape, a second trigger click or its own item stayed open while the user
 * clicked or tabbed somewhere else entirely, with `aria-expanded` still saying `true`.
 * Outside dismissal deliberately does **not** move focus: the user has already chosen
 * where it goes, and that choice is the named destination EXPERIENCE.md "**Focus destinations.** No control" asks for.
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
  host: {
    '(document:pointerdown)': 'onOutside($event)',
    '(document:focusin)': 'onOutside($event)',
  },
  template: `<div class="ocu-account">
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
  private readonly overlays = inject(OverlayStack);
  private readonly host: ElementRef<HTMLElement> = inject(ElementRef);

  protected readonly STRINGS = STRINGS;

  /**
   * The down triangle the status bar's user segment carries (EXPERIENCE.md "`{spacing.status-bar-height}` band",
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
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.overlays.remove(ACCOUNT_MENU_OVERLAY_ID);
    });

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
    this.overlays.push(ACCOUNT_MENU_OVERLAY_ID, () => this.closeAndRefocus());
    this.openFlag.set(true);
  }

  /**
   * Escape, through the overlay stack, and a second click on the trigger. Focus is restored
   * first, so the item is never removed while it holds it.
   */
  protected closeAndRefocus(): void {
    if (!this.openFlag()) return;
    this.triggerEl().nativeElement.focus();
    this.openFlag.set(false);
    this.overlays.remove(ACCOUNT_MENU_OVERLAY_ID);
  }

  /**
   * A pointer press or a focus move outside the wrapper (DW-109). Focus is deliberately not
   * touched: the gesture that dismissed the menu is already taking it somewhere.
   */
  protected onOutside(event: Event): void {
    if (!this.openFlag()) return;
    const target = event.target;
    if (target instanceof Node && this.host.nativeElement.contains(target)) return;
    this.openFlag.set(false);
    this.overlays.remove(ACCOUNT_MENU_OVERLAY_ID);
  }

  /**
   * Close, then sign out. The local half of `signOut()` runs synchronously (DW-5), so by
   * the time this returns the session is already `signed-out` and `app.ts` has withheld
   * the routed outlet; the request the method issues is not waited on here.
   */
  protected chooseSignOut(): void {
    this.openFlag.set(false);
    this.overlays.remove(ACCOUNT_MENU_OVERLAY_ID);
    void this.session.signOut();
  }
}

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
import { ThemeState } from '../core/theme';
import { AboutDialog } from './about-dialog';
import { ChangePasswordDialog } from './change-password-dialog';

/** The account menu's name on the overlay stack (DW-109, DW-137). */
export const ACCOUNT_MENU_OVERLAY_ID = 'account-menu';

/**
 * The account menu: the header's account button at its right end, beside the namespace switch
 * (EXPERIENCE.md "header account button", "`{spacing.header-height}` on", Session state 8). Its
 * Sign out item and the command box's Sign out row both call `Session.signOut()`.
 *
 * A trigger carrying the signed-in user's name and a down triangle, and a menu behind it holding
 * About, Change password, Dark theme and Sign out. Change password opens the shell's one dialog
 * over two masked fields (EXPERIENCE.md "Dialogs exist only for: set"); sign-out has no
 * confirmation step, because that enumeration does not list one.
 *
 * **Dark theme is a `menuitemcheckbox`** (Story 15.6) whose `aria-checked` mirrors `ThemeState`,
 * so its state is the rendered theme. Activating it flips the theme and leaves the menu open with
 * focus on the item, the way a checkbox item answers; the choice is remembered on the instance by
 * the store, never here.
 *
 * **It is mounted by `header.ts`**, after the namespace slot (DESIGN.md `:1008`). The status bar
 * shows the user name as information only, so this is the menu's one trigger, and the panel opens
 * downward from the header.
 *
 * **Keyboard (DW-115).** Opening moves focus to the first item. Every `role="menuitem"` carries
 * `tabindex="-1"` and the container owns the arrow model: ArrowDown and ArrowUp move with
 * wrap-around, Home and End jump to the ends, all resolved off `document.activeElement`. It is the
 * house model, copied from `data-table.ts`'s row menu, which DESIGN.md `:1023` already styles this
 * menu as; and it is **n-item**, over every `menuitem` and `menuitemcheckbox` the menu holds.
 * Escape closes the
 * menu and returns focus to the trigger. The trigger is focused *before* the items are removed
 * from the DOM, because removing a control while it holds focus is banned outright
 * (EXPERIENCE.md, Interaction Primitives) -- and it is what makes the dialog's own focus return
 * land on the trigger, since `app-dialog` returns focus to whatever was focused when it mounted.
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
 * The two document-level handlers are what dismiss on focus leaving the menu, so the house model's
 * own `focusout` handler is not copied in beside them.
 *
 * **The confirmation is announced from this element, not from the dialog.** The dialog is gone by
 * the time the change has landed, so its own live region would be removed before a screen reader
 * read it; the polite `role="status"` region here outlives it.
 *
 * **The glyph is a character produced in TypeScript, never a literal byte in the
 * template** (Rule 14, and the Consistency Conventions' "non-ASCII authored as `\uXXXX`
 * escapes"). It is `aria-hidden`, so the trigger's accessible name is the user name
 * alone -- which is also what labels the menu, through `aria-labelledby`.
 *
 * Every control-flow condition is a paren-free member reference, for the reason
 * `sign-in.ts` records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one
 * parenthesised group, so a call expression in the condition leaves a stray `)` that the
 * literal-text-node rule reports and `npm run build` fails on.
 */
@Component({
  selector: 'app-account-menu',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [AboutDialog, ChangePasswordDialog],
  // The Dark theme item's check mark sits at the item's trailing edge.
  styles: ['.ocu-account-check { margin-left: auto; padding-left: var(--ocu-space-2); }'],
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
        <div
          #panel
          class="ocu-account-panel"
          role="menu"
          aria-labelledby="ocu-account-trigger"
          (keydown)="onMenuKeydown($event)"
          (mousedown)="onMenuMouseDown($event)"
        >
          <button
            #firstItem
            type="button"
            class="ocu-account-item"
            role="menuitem"
            tabindex="-1"
            (click)="chooseAbout()"
          >
            {{ STRINGS.aboutTitle }}
          </button>
          <button
            type="button"
            class="ocu-account-item"
            role="menuitem"
            tabindex="-1"
            (click)="chooseChangePassword()"
          >
            {{ STRINGS.accountChangePassword }}
          </button>
          <button
            type="button"
            class="ocu-account-item"
            role="menuitemcheckbox"
            tabindex="-1"
            [attr.aria-checked]="dark"
            (click)="toggleTheme($event)"
          >
            {{ STRINGS.accountDarkTheme }}
            @if (dark) {
              <span class="ocu-account-check" aria-hidden="true">{{ checkGlyph }}</span>
            }
          </button>
          <button
            type="button"
            class="ocu-account-item"
            role="menuitem"
            tabindex="-1"
            (click)="chooseSignOut()"
          >
            {{ STRINGS.actionSignOut }}
          </button>
        </div>
      }
      <p class="ocu-visually-hidden" role="status">{{ announcement }}</p>
      @if (aboutOpen) {
        <app-about-dialog (closed)="onAboutClosed()" />
      }
      @if (dialogOpen) {
        <app-change-password-dialog (changed)="onPasswordChanged()" (closed)="onDialogClosed()" />
      }
    </div>`,
})
export class AccountMenu {
  private readonly session = inject(Session);
  private readonly overlays = inject(OverlayStack);
  private readonly themeState = inject(ThemeState);
  private readonly host: ElementRef<HTMLElement> = inject(ElementRef);

  protected readonly STRINGS = STRINGS;

  /**
   * The down triangle the account button carries, which says it opens a menu, written as its
   * escape so no non-ASCII byte enters a source file.
   */
  protected readonly caretGlyph = '\u25BE';

  /** The check mark the Dark theme item draws while it is checked; `aria-checked` is what is announced. */
  protected readonly checkGlyph = '\u2713';

  private readonly triggerEl = viewChild.required<ElementRef<HTMLButtonElement>>('trigger');

  private readonly firstItemEl = viewChild<ElementRef<HTMLButtonElement>>('firstItem');

  private readonly panelEl = viewChild<ElementRef<HTMLElement>>('panel');

  private readonly openFlag = signal(false);

  private readonly dialogFlag = signal(false);

  private readonly aboutFlag = signal(false);

  private readonly announcementValue = signal('');

  /** Mirrors the framework-free session's user name into the reactive graph. */
  protected readonly userName = signal(this.session.userName());

  /** Mirrors the framework-free theme store, which the checkbox item's `aria-checked` reads. */
  private readonly darkFlag = signal(this.themeState.isDark());

  constructor() {
    const stop = this.session.subscribe(() => {
      this.userName.set(this.session.userName());
    });
    const stopTheme = this.themeState.subscribe(() => {
      this.darkFlag.set(this.themeState.isDark());
    });
    inject(DestroyRef).onDestroy(() => {
      stop();
      stopTheme();
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

  protected get dialogOpen(): boolean {
    return this.dialogFlag();
  }

  protected get aboutOpen(): boolean {
    return this.aboutFlag();
  }

  /** Whether the dark theme is on screen: the checkbox item's state. */
  protected get dark(): boolean {
    return this.darkFlag();
  }

  /** The polite region's text: empty until a change lands, and the published sentence after. */
  protected get announcement(): string {
    return this.announcementValue();
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
   * first, so an item is never removed while it holds it.
   */
  protected closeAndRefocus(): void {
    if (!this.openFlag()) return;
    this.triggerEl().nativeElement.focus();
    this.openFlag.set(false);
    this.overlays.remove(ACCOUNT_MENU_OVERLAY_ID);
  }

  /**
   * The house menu keyboard model (`data-table.ts`), resolved off `document.activeElement` and
   * over however many items the menu holds -- four today, and n by construction.
   */
  protected onMenuKeydown(event: KeyboardEvent): void {
    const items = this.menuButtons();
    if (items.length === 0) return;
    const at = items.indexOf(document.activeElement as HTMLElement);
    let next = -1;
    if (event.key === 'ArrowDown') next = (at + 1) % items.length;
    else if (event.key === 'ArrowUp') next = (at - 1 + items.length) % items.length;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = items.length - 1;
    if (next < 0) return;
    event.preventDefault();
    items[next].focus();
  }

  /**
   * Keep focus where it is while a menu item is pressed: a browser that does not focus a button on
   * click would otherwise move focus out of the menu, close it, and lose the click.
   */
  protected onMenuMouseDown(event: MouseEvent): void {
    event.preventDefault();
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
   * Close the menu, returning focus to the trigger, then open the dialog. The order is what makes
   * `app-dialog`'s own focus return land on the trigger: it records whatever is focused when it
   * mounts, and the item it was chosen from is about to be removed.
   */
  protected chooseChangePassword(): void {
    this.announcementValue.set('');
    this.closeAndRefocus();
    this.dialogFlag.set(true);
  }

  /**
   * Close the menu, returning focus to the trigger, then open About. The order is the one
   * `chooseChangePassword` documents: `app-dialog` records whatever is focused when it mounts, and
   * the item it was chosen from is about to be removed.
   */
  protected chooseAbout(): void {
    this.announcementValue.set('');
    this.closeAndRefocus();
    this.aboutFlag.set(true);
  }

  /**
   * Flip the theme and keep the menu open, with focus on the item that was activated -- a pointer
   * press does not move focus here (`onMenuMouseDown`), so it is placed explicitly.
   */
  protected toggleTheme(event: Event): void {
    this.themeState.toggle();
    const item = event.currentTarget;
    if (item instanceof HTMLElement) item.focus();
  }

  /** Every dismissal path for About. Focus return is the dialog's. */
  protected onAboutClosed(): void {
    this.aboutFlag.set(false);
  }

  /** The instance applied the change: announce it politely, from a region the dialog does not own. */
  protected onPasswordChanged(): void {
    this.announcementValue.set(STRINGS.accountPasswordChanged);
  }

  /** Every dismissal path, and the one that follows a change. Focus return is the dialog's. */
  protected onDialogClosed(): void {
    this.dialogFlag.set(false);
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

  private menuButtons(): HTMLElement[] {
    const panel = this.panelEl()?.nativeElement;
    return panel === undefined
      ? []
      : [...panel.querySelectorAll<HTMLElement>('[role="menuitem"], [role="menuitemcheckbox"]')];
  }
}

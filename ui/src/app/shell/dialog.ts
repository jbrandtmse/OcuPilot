import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  effect,
  inject,
  input,
  output,
  viewChild,
} from '@angular/core';

import { OverlayStack } from '../core/overlay-stack';

/** The one overlay-stack id a dialog registers under, which is also why no dialog stacks. */
export const DIALOG_OVERLAY_ID = 'dialog';

/**
 * The shell's one modal surface (EXPERIENCE.md "the dialogs listed in Information Architecture", DESIGN.md `:1215`) and the first
 * `role="dialog"` in the client.
 *
 * It is a shape, not a screen: a title, projected body content and its actions, over a scrim. The
 * action it owns is the dismissing one. A dialog that asks a question rather than reporting
 * something -- the unsaved-changes guard is the first -- projects its confirming action into the
 * `dialogAction` slot beside it, so the confirm/cancel pair is one row with one focus order and
 * the parent still owns what the confirming action does.
 *
 * What it owns, because every dialog EXPERIENCE.md "Dialogs exist only for: set" whitelists needs the same behaviour and
 * none of them should re-derive it:
 *
 * - **It traps focus.** Tab and Shift+Tab cycle inside the surface, so the page behind is
 *   unreachable while it stands (EXPERIENCE.md "**Focus order.** skip link").
 * - **Initial focus is the first field, or the action where there is none** (DESIGN.md `:1215`).
 * - **Focus returns to the opener** when it closes -- the element that was focused when it
 *   mounted, if that element is still in the document.
 * - **Escape closes it through the overlay stack**, never through a key handler of its own, so
 *   the one Escape authority decides the order (`core/overlay-stack.ts`).
 * - **It never stacks.** Every dialog registers under the same `DIALOG_OVERLAY_ID`, and
 *   `OverlayStack.push` is idempotent per id, so a second one would replace the first rather
 *   than sit over it. The shell's own chords are inert while it stands: `side-bar.ts` and
 *   `command-box.ts` both refuse their chord when `[role="dialog"]` is in the document.
 *
 * It does not own **whether** it is shown. A parent renders `<app-dialog>` when its own state says
 * a dialog is open and listens to `closed` to clear that state, so the route, the store or the
 * component that opened it stays the single source of truth for that.
 */
@Component({
  selector: 'app-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<div class="ocu-dialog-scrim" aria-hidden="true" (mousedown)="onScrim()"></div>
    <div
      #surface
      class="ocu-dialog"
      role="dialog"
      aria-modal="true"
      [attr.aria-labelledby]="titleId"
      (keydown)="onKeydown($event)"
    >
      <h2 class="ocu-dialog-title" [id]="titleId">{{ heading() }}</h2>
      <div class="ocu-dialog-body">
        <ng-content />
      </div>
      <div class="ocu-dialog-actions">
        <button #closeButton type="button" class="ocu-button-secondary" (click)="requestClose()">
          {{ closeLabel() }}
        </button>
        <ng-content select="[dialogAction]" />
      </div>
    </div>`,
})
export class Dialog {
  /** How many dialogs have been constructed, which is what makes each one's title id its own. */
  private static instances = 0;

  /** The dialog's title, which is also its accessible name. */
  readonly heading = input.required<string>();

  /** The dismissing action's label. */
  readonly closeLabel = input.required<string>();

  /** Emitted once for every dismissal path: Escape, the action, and the scrim. */
  readonly closed = output<void>();

  /**
   * Per instance rather than a constant: a dialog never stacks, but a route-driven one is destroyed
   * and re-created by the same navigation, so two surfaces can carry the id for one change
   * detection and `aria-labelledby` would resolve to whichever came first.
   */
  protected readonly titleId = `ocu-dialog-title-${++Dialog.instances}`;

  private readonly surface = viewChild.required<ElementRef<HTMLElement>>('surface');

  private readonly closeButton = viewChild.required<ElementRef<HTMLButtonElement>>('closeButton');

  private readonly overlays = inject(OverlayStack);

  /** The element focus returns to. Read before anything here takes focus. */
  private readonly opener = document.activeElement;

  private closing = false;

  constructor() {
    this.overlays.push(DIALOG_OVERLAY_ID, () => this.requestClose());
    // One-shot: the first render is where the surface exists and where initial focus belongs.
    // A later re-render must not steal focus back from whatever the user has tabbed to.
    let focused = false;
    effect(() => {
      const surface = this.surface().nativeElement;
      if (focused) return;
      focused = true;
      // `:not([disabled])` for the same reason `focusable()` carries it: `.focus()` on a disabled
      // control is a no-op, which would leave focus on the body -- outside the surface, where the
      // trap's own keydown handler never fires again.
      const first = surface.querySelector<HTMLElement>(
        'input:not([disabled]), select:not([disabled]), textarea:not([disabled])'
      );
      (first ?? this.closeButton().nativeElement).focus();
    });
    inject(DestroyRef).onDestroy(() => {
      this.overlays.remove(DIALOG_OVERLAY_ID);
      const opener = this.opener;
      if (opener instanceof HTMLElement && opener.isConnected) opener.focus();
    });
  }

  /**
   * Ask the parent to close. Idempotent: Escape arrives through the overlay stack, which has
   * already removed the entry, and the action and the scrim call it directly, so a second call
   * must not emit a second `closed`.
   */
  requestClose(): void {
    if (this.closing) return;
    this.closing = true;
    this.overlays.remove(DIALOG_OVERLAY_ID);
    this.closed.emit();
  }

  protected onScrim(): void {
    this.requestClose();
  }

  /**
   * The focus trap. Tab from the last focusable element wraps to the first and Shift+Tab from the
   * first wraps to the last, so focus never leaves the surface while it stands.
   *
   * Escape is deliberately **not** handled here: `app.ts` binds it at the document and asks the
   * overlay stack to close the topmost member, which is this.
   */
  protected onKeydown(event: KeyboardEvent): void {
    if (event.key !== 'Tab') return;
    const focusable = this.focusable();
    if (focusable.length === 0) return;
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    const active = document.activeElement;
    if (event.shiftKey && (active === first || !this.surface().nativeElement.contains(active))) {
      event.preventDefault();
      last.focus();
      return;
    }
    if (!event.shiftKey && active === last) {
      event.preventDefault();
      first.focus();
    }
  }

  /** Every focusable element inside the surface, in document order. */
  private focusable(): readonly HTMLElement[] {
    const selector = 'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';
    return [...this.surface().nativeElement.querySelectorAll<HTMLElement>(selector)];
  }
}

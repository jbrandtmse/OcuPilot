import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ChangeBus } from '../core/change-bus';
import { screenForEntityType, withQuery } from '../core/navigation';
import { PanelState } from '../core/panel-layout';
import { ScopeService } from '../core/scope';
import { ShellState } from '../core/shell-state';
import { stringFor, STRINGS } from '../core/strings';
import { ToastStore, type ToastEntry, changeSentenceTemplate, formatChangeSentence, formatChangeToastLink } from '../core/toasts';

/**
 * The off-screen change toast stack (AD-14): bottom right of the **content area**, `spacing.4`
 * above the status bar and offset from the right edge by the panel's live width, at most three,
 * newest on top.
 *
 * **The offset is the panel's own width, read live** (DW-1412). This host is a child of
 * `.ocu-shell`, which is `position: relative` and ends at the top of the status bar, so
 * `position: absolute` with `bottom: {spacing.4}` is the published bottom and
 * `right: calc(var(--ocu-panel-live-width) + {spacing.4})` is the published right edge. `app.ts`
 * publishes that custom property from the one getter that already binds the panel's width, because
 * the width is resolved in a framework-free store and a fixed token would not track a drag.
 *
 * **In panel full screen no toast is placed.** The published invariant is that no toast ever
 * overlays the panel, and in full screen the panel covers the whole content area, so there is no
 * offset that satisfies it. Nothing is lost: `panel.ts`'s reply already carries the change
 * sentence the user is reading. Toasts are still raised and still expire, so one standing when
 * full screen ends is placed then.
 *
 * **It exists for the change the user cannot see.** A confirmed write on a screen that is open
 * highlights its row; one on a screen that is not would otherwise leave no trace at all until the
 * user happened to navigate. So this region says what changed and offers "Open in <screen>",
 * and `ToastStore` -- which asks `screenShowsEntity`, the same predicate the refresh framework
 * filters on -- is what decides which of the two happens.
 *
 * **Never an error.** DESIGN.md's toast recipe says toasts are not used for errors, and the
 * mechanism matches the rule: this host renders one store, that store subscribes to the change
 * bus alone, and no fault travels on it.
 *
 * **Hover and focus hold every countdown**, not only the toast under the pointer: a user reading
 * the third toast must not lose the first two, and a toast that expired while its own dismiss
 * control held focus would move focus to the body.
 *
 * **It sits below a modal and above the shell's menus** -- `z-index` 5, under the dialog's scrim
 * (6) and surface (7) and over the account, namespace and sort menus (3 and 4). A toast reporting
 * a change elsewhere must never float over the decision surface the user is on.
 *
 * **Its rules are component-scoped, and that is a deliberate deviation** from the Consistency
 * Conventions' "global stylesheets live under `ui/src/styles/`" row: `ui/src/styles/**` is a
 * contended path while Epic 15 is live on it, and every value DESIGN.md's toast recipe names is
 * already a token, so nothing here invents one. Folding these rules into `_components.scss` is a
 * one-commit move once Epic 15 merges.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-toast-host',
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [
    ':host { position: absolute; right: calc(var(--ocu-panel-live-width, 0px) + var(--ocu-space-4)); bottom: var(--ocu-space-4); z-index: 5; pointer-events: none; }',
    '.ocu-toast-region { display: flex; flex-direction: column; gap: var(--ocu-space-2); align-items: flex-end; pointer-events: auto; }',
    '.ocu-toast { display: flex; align-items: center; gap: var(--ocu-space-3); box-sizing: border-box; width: 360px; padding: var(--ocu-space-3); border-radius: var(--ocu-radius-md); background: var(--ocu-inverse-surface); color: var(--ocu-inverse-on-surface); box-shadow: var(--ocu-elevation-3); font-size: 0.875rem; }',
    '.ocu-toast-message { flex: 1 1 auto; }',
    '.ocu-toast-action { flex: 0 0 auto; background: none; border: 0; padding: 0; font: inherit; color: var(--ocu-secondary-dark); cursor: pointer; text-decoration: underline; }',
    '.ocu-toast-dismiss { flex: 0 0 auto; background: none; border: 0; padding: 0 var(--ocu-space-1); font: inherit; line-height: 1; color: inherit; cursor: pointer; }',
  ],
  template: `@if (visible) {
    <div
      class="ocu-toast-region"
      role="status"
      [attr.aria-label]="STRINGS.tableChangeToastRegion"
      [attr.data-ocu-holding]="held"
      (pointerenter)="holdPointer()"
      (pointerleave)="releasePointer()"
      (focusin)="holdFocus()"
      (focusout)="releaseFocus()"
    >
      @for (toast of toastList; track toast.id) {
        <div class="ocu-toast" [attr.data-ocu-toast]="toast.id">
          <span class="ocu-toast-message">{{ sentenceOf(toast) }}</span>
          @if (toast.route !== '') {
            <button type="button" class="ocu-toast-action" (click)="open(toast)">
              {{ linkOf(toast) }}
            </button>
          }
          <button
            type="button"
            class="ocu-toast-dismiss"
            [attr.aria-label]="STRINGS.tableChangeToastDismiss"
            (click)="dismiss(toast)"
          >
            {{ dismissGlyph }}
          </button>
        </div>
      }
    </div>
  }`,
})
export class ToastHost {
  private readonly bus = inject(ChangeBus);
  private readonly panel = inject(PanelState);
  private readonly router = inject(Router);
  private readonly scope = inject(ScopeService);
  private readonly shell = inject(ShellState);

  protected readonly STRINGS = STRINGS;

  /**
   * The multiplication sign DESIGN.md's dismiss affordance draws, written as its escape so no
   * non-ASCII byte enters a source file (Rule 14). The control's accessible name is the published
   * word; the glyph is decoration the name replaces.
   */
  protected readonly dismissGlyph = '\u00D7';

  /**
   * The store this region renders. Constructed here rather than provided in `main.ts` because it
   * has exactly one consumer: a second one would be the reason to lift it, and lifting it before
   * there is one would put a subscription on the bus that nothing reads.
   */
  private readonly store = new ToastStore({
    currentUrl: () => this.router.url,
    namespace: () => this.scope.namespace(),
  });

  /** Mirrors the framework-free store into the reactive graph (AD-19). */
  private readonly generation = signal(0);

  constructor() {
    const stopBus = this.store.attach(this.bus);
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    // Full screen decides whether a toast is placed at all, so this region re-reads the panel for
    // the same reason `app.ts`'s row does.
    const stopPanel = this.panel.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(() => {
      stopBus();
      stopStore();
      stopPanel();
      // The armed sweep is a timer of up to thirty seconds; nothing should outlive the region
      // that raised it.
      this.store.dispose();
    });
  }

  protected get toastList(): readonly ToastEntry[] {
    this.generation();
    return this.store.toasts();
  }

  /**
   * Whether the region is placed. Full screen is a decision rather than a geometry: the panel
   * covers the content area, the published invariant admits no offset there, and the reply already
   * carries the change sentence (DW-1412).
   */
  protected get visible(): boolean {
    this.generation();
    if (this.panel.fullScreen()) return false;
    return this.toastList.length > 0;
  }

  /**
   * Whether the countdowns are held, reflected onto the region so the hold is observable.
   *
   * The four pointer and focus bindings are the accessibility floor on time limits
   * (EXPERIENCE.md), and the store keeps the state privately; with nothing rendered from it, a
   * spec could dispatch the events and assert only on what the real 30 s timers had not yet done,
   * which is true whether or not the bindings exist. `null` rather than `false` so the attribute
   * is absent when it is off, the shape `data-ocu-toast` already uses.
   */
  protected get held(): string | null {
    this.generation();
    return this.store.holding() ? 'true' : null;
  }

  /** One toast's published sentence, with `<entity>` resolved to the entity's own id. */
  protected sentenceOf(toast: ToastEntry): string {
    return formatChangeSentence(changeSentenceTemplate(toast.action), toast.entityId);
  }

  /** `Open in <screen>` resolved to the title of the screen that shows this entity type. */
  protected linkOf(toast: ToastEntry): string {
    return formatChangeToastLink(STRINGS.tableChangeToastLink, this.screenTitle(toast));
  }

  /**
   * Open the screen this change belongs to, carrying the namespace (AD-44) and the entity as the
   * route's one id segment, then drop the toast -- it has been acted on, and a toast still
   * standing over the row it pointed at is noise.
   *
   * The area's side bar is shown first, for `fault-banner.ts`'s reason: a user who arrived from a
   * toast would otherwise land on a screen with no idea where in the shell it sits.
   */
  protected open(toast: ToastEntry): void {
    if (toast.route === '') return;
    const screen = screenForEntityType(toast.entityType);
    if (screen !== null) this.shell.showArea(screen.area);
    this.store.dismiss(toast.id);
    void this.router.navigateByUrl(withQuery(toast.route, this.router.url));
  }

  protected dismiss(toast: ToastEntry): void {
    this.store.dismiss(toast.id);
  }

  protected holdPointer(): void {
    this.store.holdTimers('pointer');
  }

  protected releasePointer(): void {
    this.store.releaseTimers('pointer');
  }

  protected holdFocus(): void {
    this.store.holdTimers('focus');
  }

  protected releaseFocus(): void {
    this.store.releaseTimers('focus');
  }

  /** The target screen's own published title, or `''` while no built screen shows the type. */
  private screenTitle(toast: ToastEntry): string {
    const screen = screenForEntityType(toast.entityType);
    return screen === null ? '' : stringFor(screen.labelKey);
  }
}

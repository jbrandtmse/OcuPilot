import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  computed,
  inject,
  signal,
} from '@angular/core';

import { Session, sessionMessageKey } from '../core/session';
import { STRINGS } from '../core/strings';

/**
 * The two states sign-in needs, and nothing else (EXPERIENCE.md `:424-425`,
 * DESIGN.md `:1064`):
 *
 * - **the signing-in skeleton** -- bars that are `aria-hidden` inside an `aria-busy`
 *   region, static under reduced motion, with `statusConnectionSigningIn` beneath them.
 *   It is what `probing` and `installing` both render, which is truthful: during an
 *   install the shell genuinely is still signing in, and telling the user their password
 *   was wrong would be a lie (DW-1).
 * - **the form-login card** -- the lockup, a user-name field, a password field with the
 *   `masked-secret-field` reveal toggle, a full-width Sign in button, and beneath them the
 *   status slot: the sign-in failure as a `role="alert"` caption, the expired-password and
 *   session-ended messages as banners.
 *
 * No chrome. Story 1.10 owns the header, rail, side bar and status bar, and absorbs this
 * component's status line into the real band.
 *
 * **The controls are native elements styled from the token layer, not Material
 * components.** DESIGN.md's `form-page` field anatomy puts the label *above* the field in
 * caption type, which is not what `mat-form-field` draws -- its label floats inside the
 * outline -- so a Material form field would have to be fought rather than themed, and it
 * would pull `@angular/forms` in for value binding this component does not need. The
 * measurements, colours and radii below are DESIGN.md's own, through `--ocu-*` tokens.
 *
 * **The reveal toggle's accessible name is the field it reveals**, with `aria-pressed`
 * carrying the state. EXPERIENCE.md's Fixed strings table publishes no show/hide wording,
 * and adding a *row* to that table silently breaks `ui/tools/strings.test.mjs`'s hardcoded
 * `252..302` extractor range -- so the words wait for whoever first needs a new row.
 *
 * **State reaches the view through a signal.** `Session` is framework-free by design (it
 * has to be, to be executable under `node --test`), so the Angular layer subscribes once
 * and mirrors what it hears rather than reading the session from the view. Zoneless and
 * `OnPush` (AD-19) make that the only way the view updates.
 *
 * Every condition in a control-flow block is a paren-free member reference. That is not
 * style: `ui/tools/client-lint.mjs`'s control-flow blanker matches `@if` plus one
 * parenthesised group, so a call expression inside the condition leaves a stray `)` that
 * the literal-text-node rule reports and `npm run build` fails on.
 */
@Component({
  selector: 'app-sign-in',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `@if (waiting) {
      <section class="ocu-signin-scene" aria-busy="true">
        <div class="ocu-skeleton" aria-hidden="true">
          <div class="ocu-skeleton-bar ocu-skeleton-bar-40"></div>
          <div class="ocu-skeleton-bar ocu-skeleton-bar-25"></div>
          <div class="ocu-skeleton-bar ocu-skeleton-bar-15"></div>
        </div>
        <p class="ocu-status-line">{{ STRINGS.statusConnectionSigningIn }}</p>
      </section>
    } @else {
      <section class="ocu-signin-scene">
        <form class="ocu-signin-card" (submit)="submit($event)">
          <div
            class="ocu-signin-lockup"
            role="img"
            aria-label="{{ STRINGS.productName }}"
          ></div>
          <div class="ocu-signin-form">
            <div class="ocu-field">
              <label class="ocu-field-label" for="ocu-signin-user">{{ STRINGS.fieldUserName }}</label>
              <div class="ocu-field-control">
                <input
                  id="ocu-signin-user"
                  class="ocu-field-input"
                  type="text"
                  name="user"
                  autocomplete="username"
                  [attr.aria-invalid]="rejected"
                  [attr.aria-describedby]="describedBy"
                  [value]="userName()"
                  (input)="onUserName($event)"
                />
              </div>
            </div>
            <div class="ocu-field">
              <label class="ocu-field-label" for="ocu-signin-password">{{ STRINGS.fieldPassword }}</label>
              <div class="ocu-field-control">
                <input
                  id="ocu-signin-password"
                  class="ocu-field-input"
                  [type]="passwordInputType"
                  name="password"
                  autocomplete="current-password"
                  [attr.aria-invalid]="rejected"
                  [attr.aria-describedby]="describedBy"
                  [value]="password()"
                  (input)="onPassword($event)"
                />
                <button
                  type="button"
                  class="ocu-reveal-toggle"
                  aria-label="{{ STRINGS.fieldPassword }}"
                  [attr.aria-pressed]="revealed()"
                  (click)="toggleReveal()"
                >
                  <span aria-hidden="true">{{ revealGlyph() }}</span>
                </button>
              </div>
            </div>
            <button type="submit" class="ocu-button-primary">{{ STRINGS.actionSignIn }}</button>
          </div>
          <div class="ocu-signin-status">
            @if (rejected) {
              <p id="ocu-signin-error" class="ocu-form-error" role="alert">{{ STRINGS.authSignInFailed }}</p>
            }
            @if (expired) {
              <p class="ocu-banner ocu-banner-info">{{ STRINGS.authPasswordExpired }}</p>
            }
            @if (ended) {
              <p class="ocu-banner ocu-banner-restrained">{{ STRINGS.authSessionEnded }}</p>
            }
          </div>
        </form>
      </section>
    }`,
})
export class SignIn {
  private readonly session = inject(Session);

  protected readonly STRINGS = STRINGS;

  /** Mirrors the framework-free session's state into the reactive graph. */
  private readonly sessionState = signal(this.session.state());

  protected readonly userName = signal(this.session.userName());

  protected readonly password = signal(this.session.password());

  protected readonly revealed = signal(false);

  /**
   * The glyph on the reveal toggle. A character, not an icon font: the interim
   * Material Symbols glyph DESIGN.md names arrives with Story 1.10's chrome, and nothing
   * in this story may reach an external host for one (NFR-10, AD-47).
   */
  protected readonly revealGlyph = computed(() => (this.revealed() ? '\u25CF' : '\u25CB'));

  constructor() {
    const stop = this.session.subscribe(() => {
      this.sessionState.set(this.session.state());
      this.userName.set(this.session.userName());
      this.password.set(this.session.password());
    });
    inject(DestroyRef).onDestroy(stop);
  }

  /** The signing-in presentation: the probe is in flight, or install has not finished. */
  protected get waiting(): boolean {
    const state = this.sessionState();
    return state === 'probing' || state === 'installing';
  }

  protected get rejected(): boolean {
    return sessionMessageKey(this.sessionState()) === 'authSignInFailed';
  }

  protected get expired(): boolean {
    return sessionMessageKey(this.sessionState()) === 'authPasswordExpired';
  }

  protected get ended(): boolean {
    return sessionMessageKey(this.sessionState()) === 'authSessionEnded';
  }

  protected get passwordInputType(): string {
    return this.revealed() ? 'text' : 'password';
  }

  /**
   * The failure line's id while it is on screen, so a user who tabs back into a field after
   * a rejection hears why rather than only meeting the alert once. Null the rest of the
   * time — a dangling reference would describe nothing.
   */
  protected get describedBy(): string | null {
    return this.rejected ? 'ocu-signin-error' : null;
  }

  protected toggleReveal(): void {
    this.revealed.set(!this.revealed());
  }

  protected onUserName(event: Event): void {
    const value = (event.target as HTMLInputElement).value;
    this.userName.set(value);
    this.session.setUserName(value);
  }

  protected onPassword(event: Event): void {
    const value = (event.target as HTMLInputElement).value;
    this.password.set(value);
    this.session.setPassword(value);
  }

  /**
   * The native `submit` event, not `ngSubmit`: `@angular/forms` is not in this component's
   * imports, so `(ngSubmit)` on a plain form would bind a DOM event that never fires.
   */
  protected submit(event: Event): void {
    event.preventDefault();
    void this.session.submitForm();
  }
}

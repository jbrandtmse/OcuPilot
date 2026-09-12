import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  computed,
  effect,
  inject,
  signal,
  viewChild,
} from '@angular/core';

import {
  Session,
  formatUser,
  isSignedIn,
  isWaiting,
  linkParts,
  sessionMessageKey,
} from '../core/session';
import { STRINGS } from '../core/strings';

/**
 * The classic portal, where a password is changed. The portal's own home page, the same
 * destination `instance-notice.ts` uses and for the same reason: EXPERIENCE.md `:427` says "the
 * classic portal", and deep-linking a particular vendor page would be a URL this project
 * invented rather than one either document names.
 */
const CLASSIC_PORTAL_HREF = '/csp/sys/UtilHome.csp';

/**
 * The project README, which carries the documented command that clears an expired password
 * (the same one `CLAUDE.md` and `README.md` both spell out). Taken from the repository this
 * client is built from; it is the only README EXPERIENCE.md `:427` can mean, and UJ-5's judge
 * arrives from it.
 */
const README_HREF = 'https://github.com/jbrandtmse/OcuPilot#readme';

/**
 * The two phrases in the expired-password sentence that are links, each with where it goes.
 * The phrases are spans of the canonical string itself, located in it at render time rather
 * than transcribed here -- so no new copy exists and a reworded table row moves the anchors
 * with it (see `linkParts`).
 */
const EXPIRED_PASSWORD_LINKS = [
  { phrase: 'the classic portal', href: CLASSIC_PORTAL_HREF },
  { phrase: 'the README', href: README_HREF },
] as const;

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
 *   status slot: the sign-in failure as a `role="alert"` caption, the expired-password,
 *   session-ended and signed-out messages as banners.
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
 * **The expired-password banner names the account and links to both fixes** (DW-105,
 * EXPERIENCE.md `:427`): the sentence's `<user>` is resolved to the name the session holds, and
 * its two published phrases -- "the classic portal" and "the README" -- are anchored where they
 * sit in the sentence rather than restated as controls, so the banner carries both links
 * without a word of copy that the string source does not hold. The state itself has no trigger
 * on this build; only its rendering is this story's.
 *
 * **The reveal toggle's accessible name is the field it reveals**, with `aria-pressed`
 * carrying the state. EXPERIENCE.md's Fixed strings table publishes no show/hide wording,
 * and the table is the sole authority for user-facing words -- so they wait for whoever
 * first needs a new row.
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
                  #userField
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
                  #passwordField
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
              <p class="ocu-banner ocu-banner-info">
                @for (part of expiredParts; track part.key) {
                  @if (part.href) {
                    <a [href]="part.href" target="_blank" rel="noreferrer">{{ part.text }}</a>
                  } @else {
                    <span>{{ part.text }}</span>
                  }
                }
              </p>
            }
            @if (ended) {
              <p class="ocu-banner ocu-banner-restrained">{{ STRINGS.authSessionEnded }}</p>
            }
            @if (signedOut) {
              <p class="ocu-banner ocu-banner-restrained">{{ STRINGS.authSignedOut }}</p>
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

  /**
   * DW-105, the rendering half. The expired-password sentence with the account's own name in
   * place of its `<user>`, cut into the parts that carry the two links EXPERIENCE.md `:427`
   * requires -- the classic portal, where the password is changed, and the README, which
   * carries the command that clears the expiry.
   *
   * Built in TypeScript, not spelled in the template: substituting in the view would put the
   * placeholder's name in two places, and anchoring a phrase there would be copy typed into a
   * component. The trigger half is declined -- no server-side expired-password signal exists on
   * this build (verified in Story 1.6) -- so this renders wherever the state is reached from,
   * and the state is not reached today.
   */
  private readonly resolvedExpiredParts = computed(() =>
    linkParts(formatUser(STRINGS.authPasswordExpired, this.userName()), EXPIRED_PASSWORD_LINKS)
  );

  private readonly userEl = viewChild<ElementRef<HTMLInputElement>>('userField');

  private readonly passwordEl = viewChild<ElementRef<HTMLInputElement>>('passwordField');

  /**
   * Whether focus has already been placed for the form currently on screen, so the move below
   * fires on the *transition* into it rather than on every state change while it is up -- a
   * re-focus on each keystroke would fight the user. It is set only once focus has actually
   * been given, so a pass that ran before the fields rendered does not consume the transition.
   */
  private showingForm = false;

  constructor() {
    const stop = this.session.subscribe(() => {
      this.sessionState.set(this.session.state());
      this.userName.set(this.session.userName());
      this.password.set(this.session.password());
    });
    inject(DestroyRef).onDestroy(stop);

    // DW-103. Neither document names a destination -- EXPERIENCE.md `:583` offers
    // `role="alert"` *or* focus moved to it, while `:582` forbids removing a focused control
    // without one -- and both sightings are the same transition: something the user was
    // using went away and the form came back. One rule covers them. Entering the form from
    // a state that was not showing it focuses the field the user has to act on: the password
    // when the user name was kept (a rejection), the user name otherwise (sign-out, or a
    // session the instance ended).
    //
    // `session.userName()` rather than the mirrored signal, so typing into the field does not
    // make this effect a dependency of its own input.
    effect(() => {
      const state = this.sessionState();
      if (isWaiting(state) || isSignedIn(state)) {
        this.showingForm = false;
        return;
      }
      // Both view queries are read before the guard, and deliberately: reading them is what
      // makes this effect re-run once the branch has rendered. The state change arrives first
      // and the fields a moment later, so an effect that returned early without reading them
      // would never see the elements it is there to focus.
      const user = this.userEl();
      const password = this.passwordEl();
      if (this.showingForm) return;
      const target = this.session.userName() === '' ? user : password;
      if (target === undefined) return;
      this.showingForm = true;
      target.nativeElement.focus();
    });
  }

  /**
   * The signing-in presentation: the probe is in flight, or install has not finished.
   * The rule itself lives in `session.ts` beside `isSignedIn`, where it has an executed
   * test host; restating it here would be a second copy to drift (DW-1).
   */
  protected get waiting(): boolean {
    return isWaiting(this.sessionState());
  }

  protected get rejected(): boolean {
    return sessionMessageKey(this.sessionState()) === 'authSignInFailed';
  }

  protected get expired(): boolean {
    return sessionMessageKey(this.sessionState()) === 'authPasswordExpired';
  }

  /**
   * A paren-free getter, like every other control-flow subject here: `@for`'s own header holds
   * one parenthesised group, and `ui/tools/client-lint.mjs`'s blanker cuts it at the FIRST
   * `)` -- so a call inside it would leave `; track part.key)` behind as a literal text node
   * and fail `npm run build`.
   */
  protected get expiredParts(): readonly { key: string; text: string; href: string | null }[] {
    return this.resolvedExpiredParts();
  }

  protected get ended(): boolean {
    return sessionMessageKey(this.sessionState()) === 'authSessionEnded';
  }

  /**
   * A banner, not an alert. The user chose Sign out, so the message confirms what they
   * did rather than interrupting them with something that went wrong -- which is also why
   * it is a different string from `authSessionEnded`, the message for a session the
   * instance ended.
   */
  protected get signedOut(): boolean {
    return sessionMessageKey(this.sessionState()) === 'authSignedOut';
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

import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { RouterOutlet } from '@angular/router';

import { Session, isSignedIn } from './core/session';
import { STRINGS } from './core/strings';
import { AccountMenu } from './shell/account-menu';
import { SignIn } from './shell/sign-in';

/**
 * The root component, and the one gate between sign-in and the product (AD-28).
 * `<router-outlet />` renders only while the session is `signed-in`; every other state --
 * `probing`, `form`, `form-rejected`, `password-expired`, `session-ended`, `signed-out`
 * and `installing` -- renders `app-sign-in` instead.
 *
 * `app-account-menu` sits inside the signed-in branch, so the only way to reach Sign out
 * is to be signed in, and choosing it drives the session out of this branch in the same
 * gesture. Story 1.10 moves the component into the real status bar.
 *
 * **The requested route is preserved by doing nothing to it.** The router resolves the URL
 * the server answered with `index.html`, and this component withholds the outlet rather
 * than redirecting, so the address never changes and the screen appears at the moment the
 * session signs in. There is no "return URL" to store and nothing to restore.
 *
 * The product-name line above the gate is Story 1.5's placeholder and stays until Story
 * 1.10 replaces it with the real header. `ui/tools/build-output.test.mjs` reads three
 * things out of this component -- the inline template, its first `{{ STRINGS.<key> }}`,
 * and its first `class="..."` whose rule must be in the *global* stylesheet -- and uses
 * them to prove, from the shipped artifact, that the string source and the token layer
 * actually reach the bundle. All three live on that line.
 *
 * `@if (signedIn)` reads a paren-free getter for the reason `sign-in.ts` records: a call
 * expression inside a control-flow condition defeats `ui/tools/client-lint.mjs`'s blanker
 * and fails the build on a stray bracket.
 */
@Component({
  selector: 'app-root',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [RouterOutlet, SignIn, AccountMenu],
  template: `<p class="ocu-type-display">{{ STRINGS.productName }}</p>
    @if (signedIn) {
      <app-account-menu />
      <router-outlet />
    } @else {
      <app-sign-in />
    }`,
})
export class App {
  private readonly session = inject(Session);

  // Exposed as an instance property so the template can reach it -- Angular templates
  // resolve `{{ }}` expressions against the component instance, never against a
  // module-level import directly.
  protected readonly STRINGS = STRINGS;

  private readonly sessionState = signal(this.session.state());

  constructor() {
    const stop = this.session.subscribe(() => this.sessionState.set(this.session.state()));
    inject(DestroyRef).onDestroy(stop);
  }

  protected get signedIn(): boolean {
    return isSignedIn(this.sessionState());
  }
}

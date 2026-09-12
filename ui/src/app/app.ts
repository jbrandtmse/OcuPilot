import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { RouterOutlet } from '@angular/router';

import { InstanceService, isInstanceReady } from './core/instance';
import { Session, isSignedIn } from './core/session';
import { STRINGS } from './core/strings';
import { AccountMenu } from './shell/account-menu';
import { InstanceNotice } from './shell/instance-notice';
import { SignIn } from './shell/sign-in';

/**
 * The root component, and the two gates between a browser and the product.
 *
 * The first is AD-28's: `app-sign-in` renders for every session state but `signed-in`.
 * The second is AD-27's: inside the signed-in branch, `<router-outlet />` renders only
 * while the instance has been verified `ready`, and `app-instance-notice` renders instead
 * for every other instance state. That is this story's half of "no area screen loads" --
 * the rail, side bar and command box do not exist yet, so there is nothing else to make
 * inert; Stories 1.9 and 1.10 read the same `ready` predicate when they build them.
 *
 * `app-account-menu` sits inside the signed-in branch, so the only way to reach Sign out
 * is to be signed in, and choosing it drives the session out of this branch in the same
 * gesture. It stays above both instance branches, so a user held behind the notice can
 * still sign out. Story 1.10 moves the component into the real status bar.
 *
 * **The requested route is preserved by doing nothing to it.** The router resolves the URL
 * the server answered with `index.html`, and this component withholds the outlet rather
 * than redirecting, so the address never changes and the screen appears at the moment both
 * gates open. There is no "return URL" to store and nothing to restore.
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
  imports: [RouterOutlet, SignIn, AccountMenu, InstanceNotice],
  template: `<p class="ocu-type-display">{{ STRINGS.productName }}</p>
    @if (signedIn) {
      <app-account-menu />
      @if (instanceReady) {
        <router-outlet />
      } @else {
        <app-instance-notice />
      }
    } @else {
      <app-sign-in />
    }`,
})
export class App {
  private readonly session = inject(Session);
  private readonly instance = inject(InstanceService);

  // Exposed as an instance property so the template can reach it -- Angular templates
  // resolve `{{ }}` expressions against the component instance, never against a
  // module-level import directly.
  protected readonly STRINGS = STRINGS;

  private readonly sessionState = signal(this.session.state());

  private readonly instanceStatus = signal(this.instance.status());

  constructor() {
    const stopSession = this.session.subscribe(() => {
      this.sessionState.set(this.session.state());
      this.verifyWhenSignedIn();
    });
    const stopInstance = this.instance.subscribe(() =>
      this.instanceStatus.set(this.instance.status())
    );
    inject(DestroyRef).onDestroy(() => {
      stopSession();
      stopInstance();
    });

    // The tab may already be signed in when this component is constructed -- a reload
    // holding a live pair never changes state, so the subscription above would never fire.
    this.verifyWhenSignedIn();
  }

  protected get signedIn(): boolean {
    return isSignedIn(this.sessionState());
  }

  protected get instanceReady(): boolean {
    return isInstanceReady(this.instanceStatus());
  }

  /**
   * The identity call is made once the session reaches `signed-in`, and only then: it
   * carries a Bearer, so it has nothing to present earlier. `verify()` is single-flight and
   * remembers a settled answer, so reaching it from several change-detection passes still
   * produces exactly one request.
   */
  private verifyWhenSignedIn(): void {
    if (!isSignedIn(this.session.state())) {
      // The answer belongs to the principal that asked, not to the tab. Leaving the
      // signed-in state ends that principal's claim on it, so the next sign-in asks again
      // rather than inheriting a verdict resolved for someone else (AD-8).
      this.instance.reset();
      return;
    }
    void this.instance.verify();
  }
}

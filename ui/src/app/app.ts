import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  inject,
  signal,
} from '@angular/core';
import { RouterOutlet } from '@angular/router';

import { InstanceService, isInstanceReady } from './core/instance';
import { NavigationService } from './core/navigation';
import { OverlayStack } from './core/overlay-stack';
import { Session, isSignedIn } from './core/session';
import { STRINGS } from './core/strings';
import { CommandBar } from './shell/command-bar';
import { Header } from './shell/header';
import { InstanceNotice } from './shell/instance-notice';
import { LocatorBar } from './shell/locator-bar';
import { Rail } from './shell/rail';
import { SideBar } from './shell/side-bar';
import { SignIn } from './shell/sign-in';
import { StatusBar } from './shell/status-bar';

/** The content area's own element, which Escape returns focus to when nothing is open. */
const CONTENT_ID = 'ocu-content';

/**
 * The root component: the two gates between a browser and the product, and the page frame
 * behind them.
 *
 * The first gate is AD-28's: `app-sign-in` renders for every session state but `signed-in`.
 * The second is AD-27's: inside the signed-in branch, the frame -- header, rail, side bar,
 * locator bar, command bar, the routed outlet and the status bar -- renders only while the
 * instance has been verified `ready`, and `app-instance-notice` renders instead for every
 * other instance state. "No area screen loads" on a mismatch is therefore literal: the chrome
 * that would open one is not on screen either.
 *
 * **The frame is four bands around one row.** The header spans the top and the status bar the
 * bottom; between them one row carries the rail, the side bar and a content column whose own
 * two bands -- the locator bar and the command bar -- sit above the screen. That order is
 * also the reading order EXPERIENCE.md
 * `:581` asks for, so Tab walks header, rail, side bar, content without a single `tabindex`
 * above 0.
 *
 * **The frame is what gives the shell a height (DW-138).** Nothing in the tree declared one,
 * so `.ocu-shell` was as tall as its tallest child and the rail's `margin-top: auto` had no
 * free space to push Agent co-pilot into. `app-root` is a full-viewport column, the middle row
 * takes the space the two bands leave, and the rail stretches to it -- which is what makes the
 * bottom slot resolve.
 *
 * **Sign out lives in the status bar now** (`app-status-bar` mounts `app-account-menu`), so it
 * is reachable exactly while the frame is. A user held behind either blocking notice still has
 * a way out: `app-instance-notice` carries its own Sign out, which is that notice's own exit.
 *
 * **Escape has one authority** (DW-137). The keydown handler here asks the overlay stack to
 * close its topmost member -- the command box over the side bar, in that order -- and when
 * nothing is open it returns focus to the content area, which is EXPERIENCE.md `:533`'s "else
 * return focus to the screen". No overlay handles Escape itself, so one key press closes one
 * thing.
 *
 * **The requested route is preserved by doing nothing to it.** The router resolves the URL
 * the server answered with `index.html`, and this component withholds the outlet rather
 * than redirecting, so the address never changes and the screen appears at the moment both
 * gates open. There is no "return URL" to store and nothing to restore.
 *
 * **The heading above the gates is the document's own name**, clipped rather than drawn: the
 * product name is never typeset as a wordmark (DESIGN.md), the header carries the lockup
 * instead, and a page with no `h1` has no accessible name for the document. It is also what
 * `ui/tools/build-output.test.mjs` reads three things out of -- the inline template, its first
 * `{{ STRINGS.<key> }}`, and its first `class="..."` whose rule must be in the *global*
 * stylesheet -- to prove from the shipped artifact that the string source and the token layer
 * actually reach the bundle.
 *
 * `@if (signedIn)` reads a paren-free getter for the reason `sign-in.ts` records: a call
 * expression inside a control-flow condition defeats `ui/tools/client-lint.mjs`'s blanker
 * and fails the build on a stray bracket.
 */
@Component({
  selector: 'app-root',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [
    RouterOutlet,
    SignIn,
    InstanceNotice,
    Header,
    Rail,
    SideBar,
    LocatorBar,
    CommandBar,
    StatusBar,
  ],
  host: { '(document:keydown.escape)': 'onEscape()' },
  template: `<h1 class="ocu-product-heading">{{ STRINGS.productName }}</h1>
    @if (signedIn) {
      @if (instanceReady) {
        <app-header />
        <div class="ocu-shell">
          <app-rail />
          <app-side-bar />
          <div class="ocu-shell-content">
            <app-locator-bar />
            <app-command-bar />
            <main [id]="contentId" class="ocu-content" tabindex="-1">
              <router-outlet />
            </main>
          </div>
        </div>
        <app-status-bar />
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
  private readonly navigation = inject(NavigationService);
  private readonly overlays = inject(OverlayStack);
  private readonly host: ElementRef<HTMLElement> = inject(ElementRef);

  // Exposed as an instance property so the template can reach it -- Angular templates
  // resolve `{{ }}` expressions against the component instance, never against a
  // module-level import directly.
  protected readonly STRINGS = STRINGS;

  /**
   * Bound rather than typed into the template, so the id and the selector `onEscape()` looks
   * it up by cannot drift: renaming one alone would compile, build and silently leave Escape
   * with nothing to return focus to.
   */
  protected readonly contentId = CONTENT_ID;

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
   * The shell's one Escape handler (DW-137). It closes the topmost overlay, and when there is
   * none it puts focus back in the content area -- the `else` half of EXPERIENCE.md `:533`.
   * The content element is focusable only programmatically (`tabindex="-1"`), so returning
   * focus to it never adds a Tab stop.
   */
  protected onEscape(): void {
    if (this.overlays.closeTop()) return;
    const content = this.host.nativeElement.querySelector<HTMLElement>('#' + CONTENT_ID);
    content?.focus();
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
      // rather than inheriting a verdict resolved for someone else (AD-8). The navigation
      // map is the same kind of answer -- which screens THIS user may reach -- and is
      // dropped in the same gesture.
      this.instance.reset();
      this.navigation.reset();
      return;
    }
    void this.instance.verify();
    void this.navigation.load();
  }
}

import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  Injector,
  afterNextRender,
  inject,
  signal,
} from '@angular/core';
import { Router, RouterOutlet } from '@angular/router';

import { DefinitionActions } from './areas/agent/definition-actions';
import { DefinitionForm } from './areas/agent/definition-form.store';
import { AuditSearch } from './areas/logs/audit.store';
import { ErrorLogDrill } from './areas/logs/error-log.store';
import { AgentStatus, DEFINITIONS_ROUTE } from './core/agent-status';
import { ConnectivityService } from './core/connectivity';
import { FormDirty } from './core/form-dirty';
import { InstanceService, isInstanceReady } from './core/instance';
import { NavigationService, editorScreenFor, routeFromUrl, screenForRoute, withQuery } from './core/navigation';
import { OverlayStack } from './core/overlay-stack';
import { RefreshService } from './core/refresh';
import { ScopeService } from './core/scope';
import { Session, isInstallStateUnreadable, isSignedIn } from './core/session';
import { ShellState } from './core/shell-state';
import { STRINGS } from './core/strings';
import { CommandBar } from './shell/command-bar';
import { FaultBanner } from './shell/fault-banner';
import { Header } from './shell/header';
import { InstanceNotice } from './shell/instance-notice';
import { LocatorBar } from './shell/locator-bar';
import { Panel } from './shell/panel';
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
 * **The connectivity banner sits above both gates** (Story 1.13). The two states it speaks for
 * -- a submit that met an unreachable instance, and an identity read that never settled -- are
 * exactly the two where neither gate is open, so the frame and its status bar are not on screen
 * to carry the news. It renders nothing while there is no fault, so the content column below is
 * unchanged in every other state.
 *
 * **Escape has one authority** (DW-137). The keydown handler here asks the overlay stack to
 * close its topmost member -- the command box over the side bar, in that order -- and when
 * nothing is open it returns focus to the content area, which is EXPERIENCE.md "panel, command-box, side-bar"'s "else
 * return focus to the screen". No overlay handles Escape itself, so one key press closes one
 * thing.
 *
 * **The requested route is preserved by doing nothing to it.** The router resolves the URL
 * the server answered with `index.html`, and this component withholds the outlet rather
 * than redirecting, so the address never changes and the screen appears at the moment both
 * gates open. There is no "return URL" to store and nothing to restore.
 *
 * **"Skip to content" is the first Tab stop** (EXPERIENCE.md "link is the first Tab stop"). It is the template's first
 * element and renders exactly while the frame does, so there is no link where there is no
 * content to skip to. Activating it focuses `main` and prevents the anchor's default: under
 * `<base href="/ocupilot/">` a bare fragment resolves to a navigation away from the current
 * route. Its first `{{ STRINGS.<key> }}` and `class="..."` are what
 * `ui/tools/build-output.test.mjs` reads out of this template to prove from the shipped artifact
 * that the string source and the global stylesheet reach the bundle.
 *
 * **The heading above the gates is the document's own name**, clipped rather than drawn: the
 * product name is never typeset as a wordmark (DESIGN.md), the header carries the lockup
 * instead, and a page with no `h1` has no accessible name for the document.
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
    FaultBanner,
    Header,
    Rail,
    SideBar,
    LocatorBar,
    CommandBar,
    StatusBar,
    Panel,
  ],
  host: { '(document:keydown.escape)': 'onEscape()' },
  template: `@if (frameShown) {
      <a class="ocu-skip-link" [href]="skipHref" (click)="onSkipToContent($event)">{{
        STRINGS.navSkipToContent
      }}</a>
    }
    <h1 class="ocu-product-heading">{{ STRINGS.productName }}</h1>
    <app-fault-banner />
    @if (installUnreadable) {
      <app-instance-notice />
    } @else {
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
            <app-panel />
          </div>
          <app-status-bar />
        } @else {
          <app-instance-notice />
        }
      } @else {
        <app-sign-in />
      }
    }`,
})
export class App {
  private readonly session = inject(Session);
  private readonly instance = inject(InstanceService);
  private readonly navigation = inject(NavigationService);
  private readonly agentStatus = inject(AgentStatus);
  private readonly scope = inject(ScopeService);
  private readonly router = inject(Router);
  private readonly connectivity = inject(ConnectivityService);
  private readonly refresh = inject(RefreshService);
  private readonly shell = inject(ShellState);

  private readonly auditSearch = inject(AuditSearch);
  private readonly errorLogDrill = inject(ErrorLogDrill);
  private readonly definitionForm = inject(DefinitionForm);
  private readonly formDirty = inject(FormDirty);
  // Constructed for its own sake: the Definitions list is served by the generic `ListPage`, so
  // its three row actions are registered by this service rather than by a page of its own
  // (`areas/agent/definition-actions.ts`). Injecting it here is what brings it into existence.
  private readonly definitionActions = inject(DefinitionActions);
  private readonly overlays = inject(OverlayStack);
  private readonly host: ElementRef<HTMLElement> = inject(ElementRef);

  private readonly injector = inject(Injector);

  /** Whether the frame was on screen at the last state change, so its arrival can be noticed. */
  private frameWasShown = false;

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

  /** The skip link's fragment, from the same id. Its click handler, not the href, moves focus. */
  protected readonly skipHref = '#' + CONTENT_ID;

  private readonly sessionState = signal(this.session.state());

  private readonly instanceStatus = signal(this.instance.status());

  constructor() {
    const stopSession = this.session.subscribe(() => {
      this.sessionState.set(this.session.state());
      this.verifyWhenSignedIn();
      this.focusOnFrameArrival();
    });
    const stopInstance = this.instance.subscribe(() => {
      this.instanceStatus.set(this.instance.status());
      this.focusOnFrameArrival();
    });
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

  /**
   * An install state the gate cannot read holds the tab on its blocking notice ahead of both
   * gates (DW-96): neither the sign-in card nor the frame, since waiting will not help.
   */
  protected get installUnreadable(): boolean {
    return isInstallStateUnreadable(this.sessionState());
  }

  protected get instanceReady(): boolean {
    return isInstanceReady(this.instanceStatus());
  }

  /** The frame's condition: both gates open and the install state readable. */
  protected get frameShown(): boolean {
    return !this.installUnreadable && this.signedIn && this.instanceReady;
  }

  /**
   * Move focus to the content area without navigating. The default is prevented because the
   * document's base href would resolve the fragment into a different URL.
   */
  protected onSkipToContent(event: Event): void {
    event.preventDefault();
    this.focusContent();
  }

  /**
   * The shell's one Escape handler (DW-137). It closes the topmost overlay, and when there is
   * none it puts focus back in the content area -- the `else` half of EXPERIENCE.md "panel, command-box, side-bar".
   * The content element is focusable only programmatically (`tabindex="-1"`), so returning
   * focus to it never adds a Tab stop.
   */
  protected onEscape(): void {
    if (this.overlays.closeTop()) return;
    this.focusContent();
  }

  private focusContent(): void {
    this.host.nativeElement.querySelector<HTMLElement>('#' + CONTENT_ID)?.focus();
  }

  /**
   * Move focus into the frame the first time it replaces the sign-in card or the instance notice
   * (DW-248).
   *
   * **The destination is `main#ocu-content`, and deliberately not a screen heading.** No screen in
   * the product renders one -- the screen's title is a `<span>` in the locator bar -- and there is
   * no route-arrival focus mechanism anywhere in the client, so a heading branch here would be a
   * destination nothing could ever reach. `main` is already the skip link's and Escape's
   * destination, and it is focusable only programmatically (`tabindex="-1"`), so this adds no Tab
   * stop.
   *
   * **The consequence is deliberate and is pinned elsewhere**: focusing `main` means the next Tab
   * walks forward into the screen, so the skip link no longer holds the first Tab after a frame
   * arrival. `ui/browser/shell.browser-spec.mjs` states that and asserts the new order; the skip
   * link is still reachable by Shift+Tab and is still what a cold load offers.
   *
   * **Focus is taken only from the document body or from inside the surface that is being
   * replaced** -- the sign-in card, or the instance notice. Anything else keeps it. "Anything
   * else" is deliberately not "anything this component contains": an element somewhere else on
   * the page is exactly a place a user put focus on purpose, and a broader test that moved focus
   * whenever `activeElement` sat outside this host would steal it from there.
   */
  private focusOnFrameArrival(): void {
    const shown = this.frameShown;
    const arrived = shown && !this.frameWasShown;
    this.frameWasShown = shown;
    if (!arrived) return;
    // Read before the frame renders, while the surface being replaced is still on screen: the
    // sign-in card's submit button and the instance notice's own alert both hold focus at this
    // point, and both are about to be destroyed.
    const active = document.activeElement;
    const insideRemoved =
      active !== null &&
      (active.closest('app-sign-in') !== null || active.closest('app-instance-notice') !== null);
    const unplaced = active === null || active === document.body;
    if (!unplaced && !insideRemoved) return;
    // Deferred: the frame is rendered by the change detection this state change schedules, so the
    // element does not exist yet. `afterNextRender` with an explicit injector is the convention
    // `data-table.ts` uses for exactly this.
    afterNextRender(() => this.focusContent(), { injector: this.injector });
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
      // dropped in the same gesture, as is the namespace list, which is which namespaces
      // THIS user may enter (AD-21, AD-48).
      this.instance.reset();
      this.navigation.reset();
      this.scope.reset();
      // The fourth answer of the same kind: a re-read parked with connectivity is a request
      // about THIS principal, and one left armed across a sign-out fires their map, namespace
      // and identity reads on whoever signs in next.
      this.connectivity.reset();
      // The fifth: a screen's rows are data THIS principal was allowed to read, and a timer left
      // armed would go on reading them for whoever signs in next. It belongs in this one gesture
      // rather than a later one of its own, because a fault-suspended timer's only remaining
      // trigger is the park the line above has just dropped (AD-43).
      this.refresh.reset();
      // The sixth: the server-criteria archetype's form holds what THIS principal typed, and its
      // "has searched" flag decides whether the next arrival at that screen renders a table at all.
      this.auditSearch.reset();
      // The seventh: the application error log's drill holds which namespace THIS principal was
      // reading and the captured detail of one entry -- every local at every stack level plus
      // $ROLES and $USERNAME, which on an IRIS for Health instance can hold patient data (AD-48).
      // Left in place it would be on screen for whoever signs in next in the same tab.
      this.errorLogDrill.reset();
      // The eighth: the Definition form holds an edit buffer THIS principal typed -- including a
      // pasted API key that has not been stored yet (AD-35) -- and its dirty flag would otherwise
      // make the next principal's first navigation ask about work that is not theirs.
      this.definitionForm.reset();
      this.formDirty.reset();
      // The ninth: whether the instance holds an enabled definition is a read THIS principal
      // made, and the panel and the rail's dot pick an audience from it beside the navigation
      // map's verdict. Dropped in the same gesture as the map, so the two can never be one
      // principal's answer and another's (AD-8).
      this.agentStatus.reset();
      return;
    }
    void this.instance.verify();
    const map = this.navigation.load();
    // The namespace list is the third answer that belongs to this principal, and the scope
    // `ApiService` attaches to every call comes from it. The switch asks for it too, but the
    // switch only exists once the instance probe has settled and it asks exactly once -- so a
    // read that fails has no second chance. Both calls reach the same single-flight `load()`,
    // so asking here costs no extra request and gives a later signed-in pass the retry.
    void this.scope.load();
    // The fourth read of the same kind, and the one the panel and the rail's dot render from.
    // Issued on every signed-in pass, not only on a sign-in: a reloaded tab reaches `signed-in`
    // without an authentication, and a status read left to the gate alone would leave the panel
    // with nothing to answer from on exactly the path FR-28 says the reminder must survive.
    const status = this.agentStatus.load();
    void this.runFirstLoginGate(map, status);
  }

  /**
   * The first-login gate (FR-28): an administrator who signs in while no definition is enabled
   * lands on the Definition form, under its landing banner.
   *
   * **It keys off an authentication, never off `signed-in`.** `consumeFreshSignIn()` answers true
   * once per `adopt()`, which is the one path a genuine authentication takes -- the silent probe
   * and an accepted form login both. A tab resuming a stored pair reaches `signed-in` through
   * `start()` without it, so a reload is not a login and the requested URL survives, which is the
   * promise the withheld outlet already makes.
   *
   * **The flag is consumed before anything is awaited.** Several passes of change detection can
   * reach this method while the two reads are in flight, and exactly one of them may be the
   * sign-in; reading the one-shot after the await would let a second pass claim it as well.
   *
   * **Nothing about the gate is stored.** What decides whether it fires is the instance's own
   * definition rows and the map's verdict, both re-read on every signed-in pass above; this waits
   * on those two reads rather than issuing its own, so "never afterwards" is a consequence of the
   * condition clearing and the gate costs no extra request.
   *
   * It declines quietly in every other case: a caller the map refuses, an instance that already
   * holds an enabled definition, a read that did not answer, and a browser already on the form.
   */
  private async runFirstLoginGate(map: Promise<void>, status: Promise<void>): Promise<void> {
    const fresh = this.session.consumeFreshSignIn();
    if (!fresh) return;
    // No screen mounts from here until this method settles, whichever way it settles: the
    // requested screen would otherwise issue its declared read (AD-36) for rows the navigation
    // below throws away, and read again when the user came back by Back. `ScreenOutlet` still
    // resolves the requested route while the hold stands, so the frame around the screen is
    // unchanged -- only the page waits.
    const release = this.shell.holdScreen();
    try {
      await Promise.all([map, status]);
      if (!this.agentStatus.answered() || this.agentStatus.configured()) return;
      // `loaded()`, not `answered()`: a map read that completed with a failure leaves every verdict
      // `UNGATED`, so reading the verdict alone would take a caller who holds nothing to a form the
      // instance will refuse them at. Declining is the safe half of that question.
      if (!this.navigation.loaded()) return;
      if (!this.navigation.screenVerdict(DEFINITIONS_ROUTE).allowed) return;
      const list = screenForRoute(DEFINITIONS_ROUTE);
      const form = list === null ? null : editorScreenFor(list);
      if (form === null) return;
      // Already there: a deep link straight to the form is honoured rather than replaced, which
      // would otherwise drop the id a browser was asked to open.
      if (routeFromUrl(this.router.url).startsWith(form.route)) return;
      // An ordinary history entry, never `replaceUrl`. The route the gate moved off is the one the
      // browser was asked for, and Back is this product's published way out of a screen it did not
      // choose ("Undo by Back"; EXPERIENCE.md's own "They may leave"). Replacing would erase the
      // requested route from history, which is the one thing a bypassable gate must not do.
      //
      // Awaited, not floated: the hold is released the moment this method settles, so returning
      // before the router had moved would mount the very screen the gate is leaving. A navigation
      // the router refuses leaves the browser where it is, which is the same outcome as declining.
      await this.router.navigateByUrl(withQuery(form.route, this.router.url)).catch(() => false);
    } finally {
      release();
    }
  }
}

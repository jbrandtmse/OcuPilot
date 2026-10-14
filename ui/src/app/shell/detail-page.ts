import { ChangeDetectionStrategy, Component, DestroyRef, ElementRef, type Type, afterNextRender, computed, inject, input, signal } from '@angular/core';
import { MatTabLink, MatTabNav, MatTabNavPanel } from '@angular/material/tabs';
import { Router } from '@angular/router';

import { NavigationService, formatRequires, routeFromUrl, tabMembersFor, withQuery } from '../core/navigation';
import { STRINGS, stringFor } from '../core/strings';
import { ListPage } from './list-page';

/** One tab of the strip, resolved for rendering. */
interface DetailTab {
  readonly route: string;
  readonly label: string;
  readonly active: boolean;
  readonly gated: boolean;
  readonly reason: string;
  readonly reasonId: string;
  /** The reason element's id, but only when one is rendered -- a gated tab alone has one. */
  readonly describedBy: string | null;
}

/** One `open`'s claim on the focus the page it navigates to will take. */
interface ArrivalRequest {
  readonly route: string;
}

/**
 * The tab `open` last navigated to, until the page that route renders has read it. Each tab is its
 * own route, so opening one replaces this page, and the tab that held focus with it. A request is an
 * object so that a navigation can forget only its own: one a later `open` supersedes resolves
 * `false` after the later request was made, and must leave that request standing.
 */
let focusOnArrival: ArrivalRequest | null = null;

/**
 * The page every `detail` archetype renders (AD-5): the current screen's declared read through
 * `ListPage`, under a tab strip when the screen is one tab of a group.
 *
 * **A tabbed screen is one descriptor per tab** (AD-5), so the strip is the group's built members in
 * position order (`tabMembersFor`), each labelled by its `tab.labelKey`, and choosing one navigates
 * to that member's own route, carrying the namespace (AD-44). Each tab's page is its own route, so
 * the read below is always the current tab's, issued once. **In a parent-scoped group** (AD-5, a SQL
 * table's catalog tabs) every tab reads the one route id as its criterion, so choosing a tab carries
 * that id segment, as the address bar holds it, to the member's route.
 *
 * **Keyboard.** The strip is Material's tab nav bar: one Tab stop, Left and Right move between tabs,
 * Enter or Space opens the focused one (EXPERIENCE.md tabs, DESIGN.md tabs). A strip wider than the
 * content column pages, and the focused tab is scrolled into view. The tab a strip opened takes
 * focus on the page that replaces it, when focus has nowhere else to be (EXPERIENCE.md Accessibility
 * Floor, *Focus destinations*).
 *
 * **A gated tab stays listed and focusable** with `aria-disabled` and its failed pair inline as
 * "Requires <pair>", the side bar's own shape, and does not navigate: the refusal is here, not in
 * the DOM (AD-8).
 *
 * **A tab's page may draw its rows with a `body` component** (AD-5, Story 20.9): the page hands it to
 * the list page, which renders it in place of the table; the strip is unchanged.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-detail-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, MatTabNav, MatTabLink, MatTabNavPanel],
  template: `<section class="ocu-detail-page">
    @if (hasTabs) {
      <nav
        mat-tab-nav-bar
        class="ocu-detail-tabs"
        [tabPanel]="panel"
        [disableRipple]="true"
        [attr.aria-label]="tabsLabel"
      >
        @for (tab of tabs; track tab.route) {
          <button
            type="button"
            mat-tab-link
            class="ocu-detail-tab"
            [active]="tab.active"
            [disabled]="tab.gated"
            [attr.data-route]="tab.route"
            [attr.aria-describedby]="tab.describedBy"
            (click)="open(tab)"
          >
            <span class="ocu-detail-tab-label">{{ tab.label }}</span>
            @if (tab.gated) {
              <span class="ocu-detail-tab-reason" [id]="tab.reasonId">{{ tab.reason }}</span>
            }
          </button>
        }
      </nav>
      <mat-tab-nav-panel #panel class="ocu-detail-panel">
        <app-list-page [body]="body()" />
      </mat-tab-nav-panel>
    } @else {
      <app-list-page [body]="body()" />
    }
  </section>`,
})
export class DetailPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);

  /**
   * A component that draws the current tab's rows in place of the table (AD-5, Story 20.9's message
   * contents), passed to the list page; `null` draws the table.
   */
  readonly body = input<Type<unknown> | null>(null);

  /** Bumped by the navigation map and the router, so the strip follows both under `OnPush`. */
  private readonly generation = signal(0);

  private readonly resolved = computed<readonly DetailTab[]>(() => {
    this.generation();
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null) return [];
    return tabMembersFor(screen).map((member) => {
      const verdict = this.navigation.screenVerdict(member.route);
      const reasonId = `ocu-detail-tab-reason-${member.route.replace(/\//g, '-')}`;
      return {
        route: member.route,
        label: stringFor(member.tab?.labelKey ?? ''),
        active: member.route === screen.route,
        gated: !verdict.allowed,
        reason: formatRequires(STRINGS.privilegeRequiresResource, verdict.failedPair),
        reasonId,
        describedBy: verdict.allowed ? null : reasonId,
      };
    });
  });

  constructor() {
    const stopNavigation = this.navigation.subscribe(() => this.bump());
    const stopRouter = this.router.events.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      stopNavigation();
      stopRouter.unsubscribe();
    });
    const host = inject<ElementRef<HTMLElement>>(ElementRef).nativeElement;
    afterNextRender(() => {
      const request = focusOnArrival;
      focusOnArrival = null;
      const active = document.activeElement;
      if (request === null || (active !== null && active !== document.body && active.isConnected)) return;
      const tabs = Array.from(host.querySelectorAll<HTMLElement>('.ocu-detail-tab'));
      tabs.find((tab) => tab.getAttribute('data-route') === request.route)?.focus();
    });
  }

  protected get hasTabs(): boolean {
    return this.resolved().length > 0;
  }

  protected get tabs(): readonly DetailTab[] {
    return this.resolved();
  }

  /** The strip's accessible name: the group's first tab's own title. */
  protected get tabsLabel(): string {
    const first = this.navigation.screenForUrl(this.router.url);
    const members = first === null ? [] : tabMembersFor(first);
    return members.length === 0 ? '' : stringFor(members[0].labelKey);
  }

  /** Open a tab. A gated tab does nothing, and the current tab is already open. */
  protected open(tab: DetailTab): void {
    if (tab.gated || tab.active) return;
    const request: ArrivalRequest = { route: tab.route };
    focusOnArrival = request;
    const forget = (): void => {
      if (focusOnArrival === request) focusOnArrival = null;
    };
    void this.router.navigateByUrl(withQuery(this.targetRoute(tab.route), this.router.url)).then(
      (opened) => {
        if (!opened) forget();
      },
      forget
    );
  }

  /**
   * The route a tab opens: its own, plus the current route id segment where the current screen is a
   * parent-scoped tab rendered with one, which every member of its group reads as its criterion.
   */
  private targetRoute(route: string): string {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.tab === null || screen.parentScope === '') return route;
    const path = routeFromUrl(this.router.url);
    const prefix = `${screen.route}/`;
    if (!path.startsWith(prefix)) return route;
    const segment = path.slice(prefix.length);
    return segment === '' || segment.includes('/') ? route : `${route}/${segment}`;
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}

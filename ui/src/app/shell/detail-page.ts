import { ChangeDetectionStrategy, Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { MatTabLink, MatTabNav, MatTabNavPanel } from '@angular/material/tabs';
import { Router } from '@angular/router';

import { NavigationService, formatRequires, tabMembersFor, withQuery } from '../core/navigation';
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

/**
 * The page every `detail` archetype renders (AD-5): the current screen's declared read through
 * `ListPage`, under a tab strip when the screen is one tab of a group.
 *
 * **A tabbed screen is one descriptor per tab** (AD-5), so the strip is the group's built members in
 * position order (`tabMembersFor`), each labelled by its `tab.labelKey`, and choosing one navigates
 * to that member's own route, carrying the namespace (AD-44). Each tab's page is its own route, so
 * the read below is always the current tab's, issued once.
 *
 * **Keyboard.** The strip is Material's tab nav bar: one Tab stop, Left and Right move between tabs,
 * Enter or Space opens the focused one (EXPERIENCE.md tabs, DESIGN.md tabs). A strip wider than the
 * content column pages, and the focused tab is scrolled into view.
 *
 * **A gated tab stays listed and focusable** with `aria-disabled` and its failed pair inline as
 * "Requires <pair>", the side bar's own shape, and does not navigate: the refusal is here, not in
 * the DOM (AD-8).
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
        <app-list-page />
      </mat-tab-nav-panel>
    } @else {
      <app-list-page />
    }
  </section>`,
})
export class DetailPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);

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
    void this.router.navigateByUrl(withQuery(tab.route, this.router.url));
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}

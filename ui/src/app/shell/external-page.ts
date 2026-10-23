import { ChangeDetectionStrategy, Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { NavigationService, areaByKey, formatExternalArea } from '../core/navigation';
import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS, stringFor } from '../core/strings';
import { ClassicLinkCard, type ClassicLink } from './classic-link-card';

/**
 * The page every `external` archetype renders (AD-5, AD-44, AD-47, Story 20.32): the route of a screen
 * whose side-bar entry and command-box result open a vendor page in a new tab. It is reached by a deep
 * link or by the agent's `shell.screen.open`, and it shows what the entry would open.
 *
 * It resolves its screen from the URL, as `ListPage` does, and is headed by the screen's title. Where
 * the navigation map answered an address for the screen (`NavigationService.screenHref`, composed on
 * the instance and answered only while the screen's area applies in the namespace), it shows the
 * classic-link card with that address, whose anchor opens a new tab. Where the map answered none, it
 * says the area is not enabled in this namespace and draws no link. Until the map read under the
 * namespace the shell is scoped to has answered (`NavigationService.appliesAnswered`: a cold sign-in, a
 * namespace switch in flight, a failed read), it shows its title alone, because it does not yet know
 * which. The client composes no address and OcuPilot loads, frames and draws nothing of the vendor page.
 *
 * The page issues no request: it reads the map the shell already holds, and re-reads it as the map
 * changes (a namespace switch). Styling uses tokens only.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-external-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ClassicLinkCard],
  template: `<section class="ocu-external-page">
    <h3 class="ocu-external-page-title">{{ title }}</h3>
    @if (linked; as card) {
      <app-classic-link-card [link]="card" />
    }
    @if (explained) {
      <p class="ocu-external-page-sentence">{{ sentence }}</p>
    }
  </section>`,
})
export class ExternalPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);

  private readonly screen: ScreenDeclaration | null = this.navigation.screenForUrl(this.router.url);

  /** Bumped when the map changes, so the signal below re-reads the address under `OnPush`. */
  private readonly generation = signal(0);

  /** The title of the screen, or `''` when the URL names none. */
  protected readonly title: string = stringFor(this.screen?.labelKey ?? '');

  /** The card's link while the map carries an address for the screen, else `null`. */
  private readonly link = computed<ClassicLink | null>(() => {
    this.generation();
    const href = this.screen === null ? '' : this.navigation.screenHref(this.screen.route);
    return href === '' ? null : { href, label: this.title };
  });

  constructor() {
    const stop = this.navigation.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(stop);
  }

  protected get linked(): ClassicLink | null {
    return this.link();
  }

  /**
   * Whether the page says why it draws no link: the map read under the current namespace has answered and carries no
   * address for the screen. Before that answer a missing address means nothing yet.
   */
  private readonly unlinked = computed(() => {
    this.generation();
    return this.navigation.appliesAnswered() && this.link() === null;
  });

  protected get explained(): boolean {
    return this.unlinked();
  }

  /** `<area> is not enabled in this namespace.` with the screen's area named. */
  protected get sentence(): string {
    const area = this.screen === null ? null : areaByKey(this.screen.area);
    return formatExternalArea(STRINGS.externalAreaNotEnabled, area === null ? '' : stringFor(area.labelKey));
  }
}

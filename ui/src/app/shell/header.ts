import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  computed,
  inject,
  signal,
} from '@angular/core';
import { Location } from '@angular/common';
import { Router } from '@angular/router';

import { withQuery } from '../core/navigation';
import { STRINGS } from '../core/strings';
import { CommandBox } from './command-box';

/**
 * The header: the 48px `banner` band across the top of the shell (DESIGN.md `:1007-1017`,
 * EXPERIENCE.md `:47`, `:315`).
 *
 * Three things and nothing else, left to right: the reversed lockup linking Home, the command
 * box centred in the header's own width, and the namespace slot at the right. Server,
 * instance, user, licensed-to and the server flag are the status bar's -- the badge never
 * appears here (DESIGN.md `:1025`).
 *
 * **No text in the header is drawn below 100%** (DESIGN.md `:1007`). The namespace eyebrow
 * sits on the gradient's `shell-edge` end, where full-strength `on-shell` is 5.35:1 and the
 * 72% the rail uses for icons at rest would be 3.60:1 -- which is why the rule is absolute
 * rather than per-element, and why the command box's placeholder is drawn at 100% too.
 *
 * **The lockup is the reversed file, vendored** (`ui/src/assets/lockup/`, AD-47, NFR-10): the
 * navy-wordmark file is 1.02:1 on the chrome and is the sign-in card's, never this band's. It
 * is drawn as a CSS background for the reason the fonts are -- a `url()` reference is what
 * makes the application builder treat the file as a build input, hash it and copy it into the
 * bundle, so `angular.json`'s `assets` array stays empty. No plate, no ground, no hover
 * state; its accessible name says both the product and where the link goes.
 *
 * **The namespace slot is a slot, not a control.** Story 1.11 owns the list, the selection and
 * the re-fetch; this story places the eyebrow and the route's current `ns` so 1.11 wires a
 * control rather than inventing a band. The value renders only when the route carries one --
 * an eyebrow over nothing would claim a namespace the shell has not been told about.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-header',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [CommandBox],
  template: `<header class="ocu-header" role="banner">
    <a
      class="ocu-header-lockup"
      [attr.href]="homeHref()"
      aria-label="{{ STRINGS.headerHomeLink }}"
      (click)="goHome($event)"
    ></a>
    <app-command-box />
    <div class="ocu-header-namespace">
      <span class="ocu-header-namespace-eyebrow">{{ STRINGS.headerNamespaceLabel }}</span>
      @if (hasNamespace) {
        <span class="ocu-header-namespace-value">{{ namespace() }}</span>
      }
    </div>
  </header>`,
})
export class Header {
  private readonly router = inject(Router);
  private readonly location = inject(Location);

  protected readonly STRINGS = STRINGS;

  /** Bumped on every router event, so the slot follows `?ns=`. */
  private readonly generation = signal(0);

  protected readonly namespace = computed(() => {
    this.generation();
    const cut = this.router.url.indexOf('?');
    if (cut < 0) return '';
    const query = new URLSearchParams(this.router.url.slice(cut + 1).split('#')[0]);
    return query.get('ns') ?? '';
  });

  constructor() {
    const stop = this.router.events.subscribe(() => this.generation.set(this.generation() + 1));
    inject(DestroyRef).onDestroy(() => stop.unsubscribe());
  }

  protected get hasNamespace(): boolean {
    return this.namespace() !== '';
  }

  /**
   * The address the anchor actually carries: Home, scoped to the route's namespace (AD-44,
   * DW-134), resolved through `<base href="/ocupilot/">`.
   *
   * `withQuery` produces an *in-application* URL (`/?ns=USER`), and a root-relative `href`
   * ignores `<base>` -- so writing it raw pointed the product's primary Home affordance at
   * the IRIS instance root, outside OcuPilot entirely, for every activation the click
   * handler does not intercept: middle-click, "open in new tab", "copy link address".
   * `Location.prepareExternalUrl` applies the base href, which is what `RouterLink` does
   * with the same URL tree. `withQuery` stays the one place that decides what travels.
   */
  protected readonly homeHref = computed(() => {
    this.generation();
    return this.location.prepareExternalUrl(withQuery('', this.router.url));
  });

  /**
   * Home, carrying the namespace the route is scoped to (AD-44, DW-134) -- the same target
   * the rail's own Home item navigates to. A bare `routerLink="/"` dropped `?ns=`, which made
   * the header's Home and the rail's Home two different destinations from the same URL.
   *
   * It stays an `<a href>` so it reads and behaves as a link, which means honouring the
   * modifier gestures a link owes the user: `RouterLink`'s own guard, verbatim in effect --
   * anything but an unmodified primary click is left to the browser, so open-in-new-tab and
   * open-in-new-window reach `homeHref()` instead of being cancelled into an in-place
   * navigation.
   */
  protected goHome(event: MouseEvent): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) {
      return;
    }
    event.preventDefault();
    void this.router.navigateByUrl(withQuery('', this.router.url));
  }
}

import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  computed,
  inject,
  signal,
} from '@angular/core';
import { Router } from '@angular/router';

import { decodeEntityId } from '../core/entity-id';
import { NavigationService, areaByKey, withQuery } from '../core/navigation';
import { STRINGS, stringFor } from '../core/strings';

/** One locator segment, resolved for rendering. */
interface LocatorSegment {
  readonly key: string;
  readonly label: string;
  /** Every segment but the first is preceded by a separator. */
  readonly separated: boolean;
  readonly navigates: boolean;
  readonly route: string;
  readonly ariaCurrent: string | null;
  readonly entity: boolean;
}

/**
 * The locator bar: area, screen and the selected entity, the `nav` named "Breadcrumb"
 * (EXPERIENCE.md `:320`, `:580`; DESIGN.md `:1033`).
 *
 * **Three segments, and only the first navigates.** The screen title is the current segment:
 * `display`-sized, `aria-current="page"`, and not a link, because it names where you already
 * are. The selected entity follows it in `code` type and appears only when the route carries
 * an id, dropping when the selection clears.
 *
 * **The area segment is suppressed when it would repeat the screen's own name.** Home is the
 * one such case in the product -- it is both an area and its own screen -- and
 * a locator reading the area name and then the same name again says it twice.
 *
 * **The namespace is never a segment** (EXPERIENCE.md `:320`): it lives in the header, and
 * putting it here would give the shell two places that claim to say which namespace you are
 * in. It is still carried across a locator navigation, because `?ns=` is data scope (AD-44).
 *
 * **The separators are `aria-hidden`**, so a screen reader reads three names rather than
 * three names and two punctuation marks.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-locator-bar',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<nav class="ocu-locator-bar" [attr.aria-label]="landmark">
    @for (segment of segments; track segment.key) {
      @if (segment.separated) {
        <span class="ocu-locator-separator" aria-hidden="true">{{ separatorGlyph }}</span>
      }
      @if (segment.navigates) {
        <button type="button" class="ocu-locator-link" (click)="open(segment)">
          {{ segment.label }}
        </button>
      } @else {
        <span
          class="ocu-locator-segment"
          [class.ocu-locator-current]="segment.ariaCurrent"
          [class.ocu-locator-entity]="segment.entity"
          [attr.aria-current]="segment.ariaCurrent"
          >{{ segment.label }}</span
        >
      }
    }
  </nav>`,
})
export class LocatorBar {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);

  protected readonly landmark = STRINGS.navLocatorLandmark;

  /**
   * The single right-angle-quote separator, produced in TypeScript so no non-ASCII byte
   * enters a template (Rule 14). It is `aria-hidden` where it is rendered, which is
   * EXPERIENCE.md's rule for every decorative glyph in the shell.
   */
  protected readonly separatorGlyph = '\u203a';

  /** Bumped on every router event, so the segments follow the route. */
  private readonly generation = signal(0);

  private readonly screen = computed(() => {
    this.generation();
    return this.navigation.screenForUrl(this.router.url);
  });

  /**
   * The selected entity, decoded once (AD-13's encode-twice, decode-once). The id is read
   * from the deepest activated route because this bar sits outside the routed outlet, and it
   * is this component's own copy of the parameter -- never a second decode chained onto
   * `screen-outlet.ts`'s.
   */
  private readonly entityId = computed(() => {
    this.generation();
    let route = this.router.routerState.root;
    while (route.firstChild !== null) route = route.firstChild;
    const raw = route.snapshot.paramMap.get('id');
    return raw === null ? '' : decodeEntityId(raw);
  });

  private readonly resolved = computed<readonly LocatorSegment[]>(() => {
    const screen = this.screen();
    if (screen === null) return [];
    const screenLabel = stringFor(screen.labelKey);
    const area = areaByKey(screen.area);
    const areaLabel = area === null ? '' : stringFor(area.labelKey);
    const entity = this.entityId();

    const segments: LocatorSegment[] = [];
    // Suppressed when it would only repeat the screen's own name -- Home is both an area and
    // its own screen, and a locator that read "Home > Home" would be saying it twice.
    if (areaLabel !== '' && areaLabel !== screenLabel) {
      segments.push({
        key: 'area',
        label: areaLabel,
        separated: false,
        navigates: this.areaHasSomewhereToGo(screen.area),
        route: this.firstRouteOf(screen.area),
        ariaCurrent: null,
        entity: false,
      });
    }
    segments.push({
      key: 'screen',
      label: screenLabel,
      separated: segments.length > 0,
      navigates: false,
      route: screen.route,
      ariaCurrent: 'page',
      entity: false,
    });
    if (entity !== '') {
      segments.push({
        key: 'entity',
        label: entity,
        separated: true,
        navigates: false,
        route: '',
        ariaCurrent: null,
        entity: true,
      });
    }
    return segments;
  });

  constructor() {
    const stopRouter = this.router.events.subscribe(() => this.bump());
    const stopNavigation = this.navigation.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      stopRouter.unsubscribe();
      stopNavigation();
    });
  }

  protected get segments(): readonly LocatorSegment[] {
    return this.resolved();
  }

  /**
   * Open the area's first built screen. The side bar follows through `ScreenOutlet`'s
   * `setActiveArea`, the same path a rail navigation takes, so this component owns only the
   * routing half and no second copy of the shell's open/collapse rules.
   */
  protected open(segment: LocatorSegment): void {
    if (!segment.navigates) return;
    void this.router.navigateByUrl(withQuery(segment.route, this.router.url));
  }

  private areaHasSomewhereToGo(areaKey: string): boolean {
    return this.navigation.screensForArea(areaKey).length > 0;
  }

  private firstRouteOf(areaKey: string): string {
    const first = this.navigation.screensForArea(areaKey)[0];
    return first === undefined ? '' : first.route;
  }

  private bump(): void {
    this.generation.set(this.generation() + 1);
  }
}

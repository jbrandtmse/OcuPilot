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
 * **The deepest segment is current; every earlier one navigates.** With no entity selected the
 * screen title is that segment: `display`-sized, `aria-current="page"`, and not a link, because
 * it names where you already are. Once an entity follows it, the entity segment (in `code`
 * type) takes that role instead, and the screen segment becomes a link back to the list --
 * **DW-142**: leaving the screen unlinked once an entity followed it gave an entity view no
 * route back to its own list.
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
    const hasEntity = entity !== '';
    segments.push({
      key: 'screen',
      label: screenLabel,
      separated: segments.length > 0,
      // A link back to the list once the entity segment follows it (DW-142); otherwise the
      // current segment, so it is not a link.
      navigates: hasEntity,
      route: screen.route,
      ariaCurrent: hasEntity ? null : 'page',
      entity: false,
    });
    if (hasEntity) {
      segments.push({
        key: 'entity',
        label: entity,
        separated: true,
        navigates: false,
        route: '',
        ariaCurrent: 'page',
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
   * Open the area's first built screen, carrying the namespace (AD-44).
   *
   * It navigates and nothing else. `ScreenOutlet`'s `setActiveArea` then follows the route,
   * but that method deliberately leaves the side bar alone -- it neither opens the bar nor
   * moves the listed area while the bar is open on another one, which is what lets a user
   * read one area's screens while another area's screen is on screen. So a locator area
   * click does not open the side bar, where EXPERIENCE.md `:320` says it should, and where a
   * rail click does (through `ShellState.activateArea`). Closing that needs public surface
   * `ShellState` does not have -- "show this area's list" without `activateArea`'s
   * click-to-collapse -- so it is filed rather than a second copy of the shell's
   * open/collapse rules kept here.
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

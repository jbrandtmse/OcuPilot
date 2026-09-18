import {
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  Component,
  DestroyRef,
  ElementRef,
  Injector,
  afterNextRender,
  computed,
  inject,
  signal,
} from '@angular/core';
import { Router } from '@angular/router';

import { decodeEntityId } from '../core/entity-id';
import {
  NavigationService,
  areaByKey,
  firstAllowedScreen,
  formatRequires,
  listForDocumentScreen,
  parentListFor,
  tabGroupFor,
  withQuery,
} from '../core/navigation';
import { textOf } from '../core/screen-read';
import { ScreenStores } from '../core/screen-store';
import { fieldOf, rowKey } from '../core/table-model';
import { ShellState } from '../core/shell-state';
import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS, stringFor } from '../core/strings';

/** One locator segment, resolved for rendering. */
interface LocatorSegment {
  readonly key: string;
  readonly label: string;
  /** Every segment but the first is preceded by a separator. */
  readonly separated: boolean;
  /** Whether the segment is drawn as a link. A gated one still is -- it is refused, not hidden. */
  readonly navigates: boolean;
  readonly route: string;
  readonly ariaCurrent: string | null;
  readonly entity: boolean;
  readonly gated: boolean;
  readonly ariaDisabled: string | null;
  readonly reason: string;
  readonly reasonId: string;
  /** The reason element's id, but only when one is rendered -- a gated segment alone has one. */
  readonly describedBy: string | null;
}

/**
 * The gating half of a segment this story does not gate. Only the area segment consults a
 * verdict (DW-143), which is the half the rail also refuses on. The screen segment names the
 * screen the user is already on -- and the locator is chrome drawn above `router-outlet`, so it
 * is drawn *over* a refusal rather than in place of one; a denied screen therefore still shows
 * its segment, and once an entity is selected that segment is a link back to the list (DW-142).
 * Gating that segment is deferred, not decided here.
 */
const UNGATED_SEGMENT = {
  gated: false,
  ariaDisabled: null,
  reason: '',
  reasonId: '',
  describedBy: null,
} as const;

/**
 * The locator bar: area, screen and the selected entity, the `nav` named "Breadcrumb"
 * (EXPERIENCE.md "The entity segment appears when a row is selected and drops when the selection clears", "link is the first Tab stop"; DESIGN.md `:1033`).
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
 * **The namespace is never a segment** (EXPERIENCE.md "The entity segment appears when a row is selected and drops when the selection clears"): it lives in the header, and
 * putting it here would give the shell two places that claim to say which namespace you are
 * in. It is still carried across a locator navigation, because `?ns=` is data scope (AD-44).
 *
 * **The separators are `aria-hidden`**, so a screen reader reads three names rather than
 * three names and two punctuation marks.
 *
 * **A gated area segment stays listed and refuses (DW-143).** The area's verdict is the rail's
 * own, so the two surfaces pointing at the same place agree: the segment keeps its place and
 * its focus, takes `aria-disabled="true"` -- never the `disabled` attribute, never hidden --
 * carries the failed `(resource, permission)` pair on hover and focus, and does not navigate.
 * **DW-161 adds the second way that happens:** an area the user may enter, all of whose built
 * screens their own `screenVerdict` refuses, is gated here too rather than navigating into a
 * refusal page.
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
      @if (segment.key === 'screen') {
        <h2
          id="ocu-locator-screen"
          class="ocu-locator-heading"
          tabindex="-1"
          [attr.aria-label]="screenHeadingLabel"
        >
          @if (segment.navigates) {
            <button
              type="button"
              class="ocu-locator-link"
              [attr.aria-disabled]="segment.ariaDisabled"
              [attr.aria-describedby]="segment.describedBy"
              (click)="open(segment)"
            >
              {{ segment.label }}
            </button>
          } @else {
            <span
              class="ocu-locator-segment ocu-locator-current"
              [class.ocu-locator-entity]="segment.entity"
              [attr.aria-current]="segment.ariaCurrent"
              >{{ segment.label }}</span
            >
          }
        </h2>
      } @else {
        @if (segment.navigates) {
          <span class="ocu-locator-link-slot">
            <button
              type="button"
              class="ocu-locator-link"
              [attr.aria-disabled]="segment.ariaDisabled"
              [attr.aria-describedby]="segment.describedBy"
              (click)="open(segment)"
            >
              {{ segment.label }}
            </button>
            @if (segment.gated) {
              <span class="ocu-locator-reason" role="tooltip" [id]="segment.reasonId">{{
                segment.reason
              }}</span>
            }
          </span>
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
    }
  </nav>`,
})
export class LocatorBar {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly shell = inject(ShellState);
  private readonly host: ElementRef<HTMLElement> = inject(ElementRef);
  private readonly injector = inject(Injector);
  private readonly changeDetector = inject(ChangeDetectorRef);

  /** The arrival token last focused (Story 4.7, AC5), so a re-render for an unrelated reason --
   * a navigation-map verdict changing, a router event on the same route -- does not steal focus
   * again. `ShellState.arrivalToken` changes on every fresh arrival even when the announcement
   * text repeats, which a text comparison here could not tell apart from "already focused". */
  private lastFocusedToken: number | null = null;
  private readonly stores = inject(ScreenStores);

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
    // Read directly, not only through `screen`/`entityId`: a store tick that leaves the route (and
    // so their own computed values) unchanged still has to invalidate this computed, because
    // `entityLabel` below reads the store fresh every time this runs (Story 6.7). `screen` and
    // `entityId` computeds absorbing a same-value bump is exactly what would otherwise leave this
    // memoized forever after the first render on a detail route.
    this.generation();
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
      // The area's own verdict, the same one the rail refuses on (DW-143). Not the first built
      // screen's: the rail gates the area, and a locator that consulted a different verdict
      // from the rail item pointing at the same place would disagree with it on screen.
      const verdict = this.navigation.areaVerdict(screen.area);
      const screens = this.navigation.screensForArea(screen.area);
      // **DW-161**, the same amendment Home's tile carries: the segment opens the area's first
      // built screen *whose own verdict allows*, and is gated in place when none of them does.
      // The two surfaces point at the same place, so they resolve it the same way.
      const openable = firstAllowedScreen(screens, (route) =>
        this.navigation.screenVerdict(route)
      );
      const gated = !verdict.allowed || (screens.length > 0 && openable === null);
      const failedPair = verdict.allowed
        ? this.navigation.screenVerdict(screens[0]?.route ?? '').failedPair
        : verdict.failedPair;
      const reasonId = 'ocu-locator-reason-area';
      segments.push({
        key: 'area',
        label: areaLabel,
        separated: false,
        // Still a link when the area has screens at all: a refused one keeps its place, its
        // focus and its shape, and refuses on activation (AD-8) rather than vanishing.
        navigates: screens.length > 0,
        route: openable === null ? '' : openable.route,
        ariaCurrent: null,
        entity: false,
        gated,
        ariaDisabled: gated ? 'true' : null,
        reason: formatRequires(STRINGS.privilegeRequiresResource, failedPair),
        reasonId,
        describedBy: gated ? reasonId : null,
      });
    }
    const hasEntity = entity !== '';
    segments.push({
      key: 'screen',
      label: screenLabel,
      separated: segments.length > 0,
      // A link back to the list once the entity segment follows it (DW-142); otherwise the
      // current segment, so it is not a link. A document viewer's list is the one it is paired
      // with, because its own route with no id reads no document, and a sub-resource list's is
      // its parent, for the same reason. A tab's is its group's first tab, the screen the side bar
      // lists (AD-5).
      navigates: hasEntity,
      route:
        parentListFor(screen)?.route ?? listForDocumentScreen(screen)?.route ?? tabGroupFor(screen)?.route ?? screen.route,
      ariaCurrent: hasEntity ? null : 'page',
      entity: false,
      ...UNGATED_SEGMENT,
    });
    if (hasEntity) {
      segments.push({
        key: 'entity',
        label: this.entityLabel(screen, entity),
        separated: true,
        navigates: false,
        route: '',
        ariaCurrent: 'page',
        entity: true,
        ...UNGATED_SEGMENT,
      });
    }
    return segments;
  });

  constructor() {
    // A parent-scoped detail screen's entity label reads the store once its row has loaded
    // (`entityLabel`), so this bar re-renders on that store's own tick too -- not only on a
    // router event -- and follows the screen from one detail route to the next (Story 6.7).
    //
    // Kept a plain RxJS subscription rather than an `effect()`: `effect()`'s first run is
    // scheduled, not synchronous, so a read fast enough to land before that first flush notified
    // a listener that was not registered yet -- the store held the row, nothing had told this bar
    // to look again, and the segment was stuck on the id (observed in the browser spec, never in
    // a component test whose stub read is a resolved promise already). `router.events` fires this
    // callback synchronously the moment the URL changes, before any read starts, so the
    // subscription below is always in place first.
    let stopStore: (() => void) | null = null;
    let subscribedDescriptor = '';
    const syncStoreSubscription = (): void => {
      const screen = this.screen();
      const descriptor = screen === null ? '' : screen.descriptor;
      if (descriptor === subscribedDescriptor) return;
      subscribedDescriptor = descriptor;
      stopStore?.();
      stopStore = null;
      if (screen === null || screen.archetype !== 'detail' || screen.parentScope === '') return;
      const store = this.stores.for(screen.descriptor, screen.refreshRates);
      stopStore = store.subscribe(() => this.bump());
    };

    const stopRouter = this.router.events.subscribe(() => {
      this.bump();
      syncStoreSubscription();
    });
    const stopNavigation = this.navigation.subscribe(() => this.bump());
    const stopShell = this.shell.subscribe(() => this.bump());
    syncStoreSubscription();

    inject(DestroyRef).onDestroy(() => {
      stopRouter.unsubscribe();
      stopNavigation();
      stopShell();
      stopStore?.();
    });
  }

  protected get segments(): readonly LocatorSegment[] {
    return this.resolved();
  }

  /**
   * The screen heading's `aria-label` (Story 4.7, AC5): the standing arrival announcement for
   * the screen currently on display, or `null` when none is standing -- an ordinary,
   * user-initiated arrival names no `aria-label` at all, so the heading's accessible name falls
   * back to its own text content.
   */
  protected get screenHeadingLabel(): string | null {
    const screen = this.screen();
    return screen === null ? null : this.shell.arrivalAnnouncement(screen.route);
  }

  /**
   * The entity segment's label: on a parent-scoped `detail` screen, once its one row has loaded,
   * the value of its `name` column (Story 6.7) -- Task details names the task rather than its id --
   * and otherwise the decoded id every other entity view already showed.
   *
   * Matched by `rowKey` rather than taken as `store.data()[0]` unconditionally, so a store still
   * holding the previous id's row mid-navigation falls back to the id instead of naming the wrong
   * task for one tick.
   */
  private entityLabel(screen: ScreenDeclaration, entity: string): string {
    if (screen.archetype !== 'detail' || screen.parentScope === '') return entity;
    const nameColumn = screen.table?.columns.find((column) => column.kind === 'name');
    if (nameColumn === undefined) return entity;
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    const row = store.data().find((candidate) => rowKey(candidate, screen) === entity);
    if (row === undefined) return entity;
    const text = textOf(fieldOf(row, nameColumn.field));
    return text === '' ? entity : text;
  }

  /**
   * Open a segment's route, carrying the namespace (AD-44).
   *
   * A gated segment does nothing (**DW-143**): it is `aria-disabled`, which carries no
   * behaviour of its own, so the refusal has to be here -- the same shape `rail.ts` and
   * `side-bar.ts` use for the same verdict. It is a client affordance, not the enforcement: the
   * server refuses the request either way (AD-8).
   *
   * The area segment opens the area's first screen **and its side bar** (EXPERIENCE.md's
   * locator-bar row): the bar is shown open on that area before the navigation, through
   * `ShellState.showArea`, because `ScreenOutlet`'s `setActiveArea` deliberately leaves an open
   * bar where it is. The screen segment, a link back to the list, navigates and nothing else.
   */
  protected open(segment: LocatorSegment): void {
    if (!segment.navigates || segment.gated) return;
    const screen = this.screen();
    if (segment.key === 'area' && screen !== null) this.shell.showArea(screen.area);
    void this.router.navigateByUrl(withQuery(segment.route, this.router.url));
  }

  private bump(): void {
    this.generation.set(this.generation() + 1);
    this.changeDetector.markForCheck();
    this.syncHeadingFocus();
  }

  /**
   * Focus `#ocu-locator-screen` once per fresh arrival (Story 4.7, AC5), and never for any other
   * reason a re-render fires this component -- a navigation-map verdict changing, a router event
   * that leaves the screen and its arrival token unchanged. Deferred with `afterNextRender`
   * (`app.ts`'s own convention for the same problem): the token just changed in the same tick
   * that the heading's new `aria-label` did, before Angular has painted it.
   */
  private syncHeadingFocus(): void {
    const screen = this.screen();
    const token = screen === null ? null : this.shell.arrivalToken(screen.route);
    if (token === null || token === this.lastFocusedToken) return;
    this.lastFocusedToken = token;
    afterNextRender(
      () => this.host.nativeElement.querySelector<HTMLElement>('#ocu-locator-screen')?.focus(),
      { injector: this.injector }
    );
  }
}

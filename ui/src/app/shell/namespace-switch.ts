import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  computed,
  effect,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { NAMESPACE_PARAM, formatRequires } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import {
  ScopeService,
  withNamespace,
  writableNamespaces,
  type NamespaceEntry,
} from '../core/scope';
import { STRINGS } from '../core/strings';

/** The switch's name on the overlay stack (DW-137). */
export const NAMESPACE_SWITCH_OVERLAY_ID = 'namespace-switch';

/** The `ns` a router URL carries, or `''`. */
export function namespaceFromUrl(url: string): string {
  const cut = url.indexOf('?');
  if (cut < 0) return '';
  const query = new URLSearchParams(url.slice(cut + 1).split('#')[0]);
  return query.get(NAMESPACE_PARAM) ?? '';
}

/**
 * The namespace switch: the control in the header's right slot
 * (EXPERIENCE.md `:315`, DESIGN.md `:1007`).
 *
 * **The namespace is data scope, not decoration** (AD-44). The trigger names the namespace every
 * read on this screen executes against; choosing another one changes the route's `ns` and
 * nothing else, so the screen re-fetches in place and no URL leaves `/ocupilot`.
 *
 * **It offers the namespaces the user can read *and* write** (`epics.md:1397`,
 * EXPERIENCE.md `:315`). A namespace the user can only read is still reported by the endpoint,
 * is still honoured when a route is already scoped to it, and still scopes every read made there
 * (DW-7) -- it is simply not somewhere the switch sends anyone.
 *
 * **A listbox behind a trigger, not a native `<select>`.** DESIGN.md `:1007` draws an eyebrow
 * over a value with a dotted 1px underline and a down-triangle glyph, which no native select
 * produces, and EXPERIENCE.md's privilege rule rejects natively-disabled options. Built as the
 * pattern `command-box.ts` established, on the same overlay stack, so Escape closes it without
 * also collapsing the side bar underneath. Nothing modal opens: "no dialog" holds
 * (EXPERIENCE.md `:552`).
 *
 * **The trigger's accessible name says what it controls, not only its value.** `aria-labelledby`
 * pairs the header's `Namespace` eyebrow (`header.ts`) with the value span, so a screen reader
 * announces "Namespace, HSCUSTOM" rather than the bare namespace -- the same `id`-plus-
 * `aria-labelledby` wiring `account-menu.ts` uses for its own trigger and panel. Neither string
 * is new; only the two elements' `id`s are.
 *
 * **A namespace the route asks for and the instance refuses is replaced, not obeyed.** The
 * resolved scope takes its place with `replaceUrl`, so Back is not polluted with a URL that never
 * worked; where the instance named a missing privilege the switch says so with the published
 * `Requires <resource>`, and where the namespace simply does not exist it is silent -- no Fixed
 * strings row spells that sentence, and this story invents none.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-namespace-switch',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: {
    '(document:pointerdown)': 'onOutside($event)',
    '(document:focusin)': 'onOutside($event)',
  },
  template: `<div class="ocu-namespace-switch">
    @if (hasScope) {
      <button
        #trigger
        type="button"
        class="ocu-namespace-switch-trigger"
        aria-haspopup="listbox"
        aria-labelledby="ocu-header-namespace-eyebrow ocu-namespace-switch-value"
        [attr.aria-expanded]="expanded"
        [attr.title]="note() || null"
        (click)="toggle()"
      >
        <span class="ocu-namespace-switch-value" id="ocu-namespace-switch-value">{{ currentScope() }}</span>
        <span class="ocu-namespace-switch-caret" aria-hidden="true">{{ caretGlyph }}</span>
      </button>
    }
    @if (expanded) {
      <div
        #list
        class="ocu-namespace-switch-list"
        role="listbox"
        tabindex="-1"
        [attr.aria-label]="STRINGS.headerNamespaceLabel"
        [attr.aria-activedescendant]="activeDescendant()"
        (keydown)="onKeydown($event)"
      >
        @for (option of optionRows; track option.name) {
          <div
            class="ocu-namespace-switch-option"
            role="option"
            [id]="optionId($index)"
            [class.ocu-namespace-switch-option-active]="$index === activeIndex()"
            [attr.aria-selected]="option.name === currentScope()"
            (click)="choose(option)"
          >
            {{ option.name }}
          </div>
        }
      </div>
    }
    <p class="ocu-namespace-switch-note" role="status">{{ note() }}</p>
  </div>`,
})
export class NamespaceSwitch {
  private readonly scope = inject(ScopeService);
  private readonly overlays = inject(OverlayStack);
  private readonly router = inject(Router);
  private readonly host: ElementRef<HTMLElement> = inject(ElementRef);

  protected readonly STRINGS = STRINGS;

  /**
   * The disclosure glyph DESIGN.md `:1007` draws, written as its escape so no non-ASCII byte
   * enters a source file (Rule 14).
   */
  protected readonly caretGlyph = '\u25BE';

  private readonly triggerEl = viewChild<ElementRef<HTMLButtonElement>>('trigger');

  private readonly listEl = viewChild<ElementRef<HTMLElement>>('list');

  private readonly openFlag = signal(false);

  protected readonly activeIndex = signal(0);

  /** Mirrors the framework-free scope service and the router into the reactive graph. */
  private readonly generation = signal(0);

  /**
   * The value the trigger carries: the resolved scope, or -- until the list has arrived and the
   * instance has had its say -- whatever the route asked for. Showing the route's own value first
   * is what keeps the band from flashing empty on every cold load.
   */
  protected readonly currentScope = computed(() => {
    this.generation();
    const resolved = this.scope.namespace();
    return resolved !== '' ? resolved : this.scope.requested();
  });

  protected readonly options = computed<readonly NamespaceEntry[]>(() => {
    this.generation();
    return writableNamespaces(this.scope.namespaces());
  });

  /**
   * `Requires <resource>` for a route namespace the instance refused over a privilege, or `''`.
   * It survives the replacement it explains -- the refusal arrives after the URL has already been
   * corrected -- and a namespace that does not exist refuses with no pair, which no published
   * sentence covers.
   *
   * Its `role="status"` region is mounted unconditionally and empty rather than created with its
   * text, for the reason `command-bar.ts` records: a live region announces content that changes
   * inside it, not a region that appears already full.
   */
  protected readonly note = computed(() => {
    this.generation();
    const refusal = this.scope.refusal();
    if (refusal === null || refusal.failedPair === '') return '';
    return formatRequires(STRINGS.privilegeRequiresResource, refusal.failedPair);
  });

  protected readonly activeDescendant = computed(() => {
    if (!this.openFlag()) return null;
    const options = this.options();
    if (options.length === 0) return null;
    return this.optionId(Math.min(this.activeIndex(), options.length - 1));
  });

  constructor() {
    const stopScope = this.scope.subscribe(() => {
      this.bump();
      this.replaceUnresolved();
    });
    // Every event bumps the generation, so the trigger follows the URL; only a settled
    // navigation moves the scope. `router.url` is the URL being left until `NavigationEnd`, and
    // starting a navigation from inside another one is what a `replaceUrl` must not do.
    const stopRouter = this.router.events.subscribe((event) => {
      this.bump();
      if (event instanceof NavigationEnd) this.syncFromRoute();
    });
    inject(DestroyRef).onDestroy(() => {
      stopScope();
      stopRouter.unsubscribe();
      this.overlays.remove(NAMESPACE_SWITCH_OVERLAY_ID);
    });

    // The route is already resolved when this component is constructed on a cold deep link, so
    // the first read is taken here rather than waited for from the subscription above.
    this.syncFromRoute();
    void this.scope.load();

    // A list that never takes focus is a listbox only in name. The element does not exist until
    // the `@if` has rendered, which under zoneless change detection is after the click handler
    // has returned -- so the move is made from an effect, once the view query has been updated.
    effect(() => {
      if (!this.openFlag()) return;
      this.listEl()?.nativeElement.focus();
    });
  }

  protected get expanded(): boolean {
    return this.openFlag();
  }

  /**
   * The options, as a paren-free member reference: `ui/tools/client-lint.mjs`'s blanker matches
   * a control-flow block plus one parenthesised group, so a call expression inside `@for` leaves
   * a stray `)` the literal-text-node rule reports and `npm run build` fails on.
   */
  protected get optionRows(): readonly NamespaceEntry[] {
    return this.options();
  }

  protected get hasScope(): boolean {
    return this.currentScope() !== '';
  }

  protected optionId(index: number): string {
    return 'ocu-namespace-option-' + index;
  }

  protected toggle(): void {
    if (this.openFlag()) {
      this.closeAndRefocus();
      return;
    }
    const options = this.options();
    const current = options.findIndex((option) => option.name === this.currentScope());
    this.activeIndex.set(current < 0 ? 0 : current);
    this.overlays.push(NAMESPACE_SWITCH_OVERLAY_ID, () => this.closeAndRefocus());
    this.openFlag.set(true);
  }

  /**
   * Arrows move the active option, Enter and Space choose it. Escape is deliberately absent: the
   * shell's one handler asks the overlay stack, so a key press here cannot close two things.
   */
  protected onKeydown(event: KeyboardEvent): void {
    const count = this.options().length;
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      if (count > 0) this.choose(this.options()[Math.min(this.activeIndex(), count - 1)]);
      return;
    }
    if (count === 0) return;
    const current = Math.min(this.activeIndex(), count - 1);
    let next = current;
    if (event.key === 'ArrowDown') next = (current + 1) % count;
    else if (event.key === 'ArrowUp') next = (current - 1 + count) % count;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = count - 1;
    else return;
    event.preventDefault();
    this.activeIndex.set(next);
  }

  /**
   * Take a namespace. The service refuses anything the instance did not offer for writing, so the
   * selection cannot be a value the client invented (AD-21, AD-48); the navigation carries the
   * query alone, so the path, the fragment and every other parameter are untouched and
   * `ScreenOutlet` is re-parameterised rather than re-created.
   */
  protected choose(option: NamespaceEntry): void {
    this.closeAndRefocus();
    if (option.name === this.currentScope()) return;
    if (!this.scope.select(option.name)) return;
    void this.router.navigateByUrl(withNamespace(this.router.url, option.name));
  }

  /**
   * A pointer press or a focus move outside the switch closes it, the dismissal DW-109 gave the
   * account menu. Focus is deliberately not taken back: the gesture is already moving it.
   */
  protected onOutside(event: Event): void {
    if (!this.openFlag()) return;
    const target = event.target;
    if (target instanceof Node && this.host.nativeElement.contains(target)) return;
    this.openFlag.set(false);
    this.overlays.remove(NAMESPACE_SWITCH_OVERLAY_ID);
  }

  /**
   * Close, unregister and give focus back. The trigger is focused *before* the list is removed,
   * because removing a control while it holds focus is banned outright (EXPERIENCE.md `:552`).
   */
  private closeAndRefocus(): void {
    if (!this.openFlag()) return;
    this.triggerEl()?.nativeElement.focus();
    this.openFlag.set(false);
    this.overlays.remove(NAMESPACE_SWITCH_OVERLAY_ID);
  }

  private syncFromRoute(): void {
    this.scope.setRequested(namespaceFromUrl(this.router.url));
    this.bump();
    this.replaceUnresolved();
  }

  /**
   * Put the resolved scope where the route named one the instance will not admit. `replaceUrl`
   * keeps a URL that never worked out of the history stack, and the guard against navigating to
   * the URL already in force is what stops a fallback the instance cannot satisfy either --
   * an echoed scope that is not itself in the list -- from navigating in a circle.
   */
  private replaceUnresolved(): void {
    const unresolved = this.scope.unresolved();
    if (unresolved === null) return;
    const resolved = this.scope.namespace();
    if (resolved === '' || resolved === unresolved.name) return;
    const target = withNamespace(this.router.url, resolved);
    if (target === this.router.url) return;
    void this.router.navigateByUrl(target, { replaceUrl: true });
  }

  private bump(): void {
    this.generation.set(this.generation() + 1);
  }
}

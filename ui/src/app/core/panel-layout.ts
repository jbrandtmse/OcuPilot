/**
 * The shell's width budget and the agent co-pilot panel's own state (Story 4.3).
 *
 * `resolveLayout` is the one computation of DESIGN.md's Yield order: when rail, side bar, content
 * minimum and panel do not fit the viewport, (1) the side bar collapses, (2) the panel shrinks from
 * its target -- the remembered width, or `panelHomeTarget` on Home -- toward its minimum, (3) the
 * content column holds its minimum and scrolls inside itself. No media query stands in for it;
 * every consumer reads the same answer, and Home's wider panel is an input to it rather than a
 * second CSS path (AD-19).
 *
 * `PanelState` holds what the panel remembers and what the user is doing to it: the remembered
 * width (through `PreferenceStore`, the only module that touches persistent storage), the draft,
 * full screen, a drag in progress, and whether the user reopened a side bar the yield collapsed.
 * The viewport width is fed in by a shell component; nothing here reads the DOM (AD-19).
 */

// The `.ts` extensions are what let `node --test` resolve these at runtime.
import { HOME_AREA_KEY, areaByKey } from './navigation.ts';
import { PreferenceStore } from './preferences.ts';
import { ShellState } from './shell-state.ts';

/** DESIGN.md `spacing.rail-width`. */
export const RAIL_WIDTH = 48;

/** DESIGN.md `spacing.side-bar-width`. */
export const SIDE_BAR_WIDTH = 240;

/** DESIGN.md `spacing.content-min-width`. */
export const CONTENT_MIN_WIDTH = 640;

/** DESIGN.md `spacing.panel-min`. */
export const PANEL_MIN_WIDTH = 320;

/** DESIGN.md `spacing.panel-default`. */
export const PANEL_DEFAULT_WIDTH = 400;

/** EXPERIENCE.md panel-resize-handle: "Left/Right arrows change the width by 16 px". */
export const PANEL_KEYBOARD_STEP = 16;

/** The `50vw` half of DESIGN.md `spacing.panel-home`, as a fraction of the viewport. */
export const HOME_PANEL_FRACTION = 0.5;

/**
 * DESIGN.md `spacing.panel-home`: `min(50vw, viewport - rail - content minimum)` -- the width the
 * panel targets on Home, so the content column always keeps its minimum (DESIGN.md `:898`).
 *
 * `0` for an unmeasured viewport, which is this module's "not on Home" value as well: a target of
 * `0` leaves `resolveLayout` on the remembered width. The three operands are the same three
 * `--ocu-panel-home` is built from, and `tools/panel-layout.test.mjs` asserts that equality, which
 * is the token's one consumer (DW-379). There is no runtime CSS consumer: the inline
 * `[style.width.px]` binding already wins, and CSS cannot see the side bar, so a CSS width cannot
 * express the yield order.
 */
export function panelHomeTarget(viewport: number): number {
  if (!(viewport > 0)) return 0;
  // Floored at 0, not just at an unmeasured viewport: below 688px the rail and the content minimum
  // already fill the row, and a negative result would be a third meaning for a field that has two.
  return Math.max(
    0,
    Math.min(Math.floor(viewport * HOME_PANEL_FRACTION), viewport - RAIL_WIDTH - CONTENT_MIN_WIDTH)
  );
}

export interface LayoutInput {
  /** The viewport's CSS width in px; `0` or less means not yet measured, and nothing yields. */
  readonly viewport: number;
  /** Whether the side bar would show if width allowed: open by preference, on an area with a list. */
  readonly sideBarPreferred: boolean;
  /** Whether the user reopened the side bar while the yield had collapsed it. */
  readonly sideBarReopened: boolean;
  /** The remembered panel width. */
  readonly remembered: number;
  /**
   * The width the panel targets instead of the remembered one, or `0` for "not on Home"
   * (`panelHomeTarget`). Required rather than optional: a silently-defaulting layout input is the
   * class of bug this module exists to prevent, and the compiler names every call site.
   */
  readonly homeTarget: number;
  readonly fullScreen: boolean;
}

export interface Layout {
  readonly sideBarShown: boolean;
  /** The docked panel's rendered width. */
  readonly panelWidth: number;
  /** The widest the panel may be dragged: the width that leaves the content at its minimum. */
  readonly panelMax: number;
  /** The content column's width; below `CONTENT_MIN_WIDTH` when it scrolls. */
  readonly contentWidth: number;
  readonly contentScrolls: boolean;
  readonly fullScreen: boolean;
}

/**
 * The yield order over one viewport width. Undone in reverse as width returns, because it is a
 * function of the width rather than a history of concessions.
 */
export function resolveLayout(input: LayoutInput): Layout {
  const target = Math.max(
    PANEL_MIN_WIDTH,
    input.homeTarget > 0 ? input.homeTarget : input.remembered
  );
  if (!(input.viewport > 0)) {
    return {
      sideBarShown: input.sideBarPreferred,
      panelWidth: target,
      panelMax: Math.max(PANEL_MIN_WIDTH, target),
      contentWidth: CONTENT_MIN_WIDTH,
      contentScrolls: false,
      fullScreen: input.fullScreen,
    };
  }
  const row = input.viewport - RAIL_WIDTH;
  const sideBarFits = SIDE_BAR_WIDTH + CONTENT_MIN_WIDTH + target <= row;
  const sideBarShown = input.sideBarPreferred && (input.sideBarReopened || sideBarFits);
  const available = row - (sideBarShown ? SIDE_BAR_WIDTH : 0);
  const panelMax = Math.max(PANEL_MIN_WIDTH, available - CONTENT_MIN_WIDTH);
  const panelWidth = Math.min(target, panelMax);
  const contentWidth = available - panelWidth;
  return {
    sideBarShown,
    panelWidth,
    panelMax,
    contentWidth,
    contentScrolls: contentWidth < CONTENT_MIN_WIDTH,
    fullScreen: input.fullScreen,
  };
}

/** Whether an area's side bar has a screen list to show: Home navigates and has none. */
export function areaHasSideBar(areaKey: string): boolean {
  if (areaKey === '') return false;
  const area = areaByKey(areaKey);
  return !(area !== null && area.navigates);
}

export interface PanelStateOptions {
  readonly preferences: PreferenceStore;
  readonly shell: ShellState;
}

export class PanelState {
  private readonly preferences: PreferenceStore;
  private readonly shell: ShellState;

  private viewportWidth = 0;
  private rememberedWidth: number;
  private draftText = '';
  private full = false;
  private reopened = false;

  /** The pointer x and panel width a drag started from, or `null` when no drag is in progress. */
  private drag: { readonly x: number; readonly width: number } | null = null;

  /**
   * Whether a width gesture on this visit to Home has released the Home target. With the target
   * unconditional the resize handle would be dead on Home and its `aria-valuenow` would lie, so a
   * drag or an arrow step takes effect and is stored as the remembered width.
   */
  private homeWidthReleased = false;

  /** The active area as of the last `ShellState` notification, so a change can reset the release. */
  private lastActiveArea = '';

  private readonly listeners = new Set<() => void>();

  constructor(options: PanelStateOptions) {
    this.preferences = options.preferences;
    this.shell = options.shell;
    this.rememberedWidth = this.preferences.panelWidth(PANEL_DEFAULT_WIDTH, PANEL_MIN_WIDTH);
    this.lastActiveArea = this.shell.activeArea();
    // A side bar the user closed is no longer reopened; the next open meets the yield afresh.
    // A route that left the area ends the Home release: the target is per visit.
    this.shell.subscribe(() => {
      if (!this.shell.open()) this.reopened = false;
      const area = this.shell.activeArea();
      if (area !== this.lastActiveArea) {
        this.lastActiveArea = area;
        this.homeWidthReleased = false;
      }
      this.notify();
    });
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  layout(): Layout {
    return resolveLayout({
      viewport: this.viewportWidth,
      sideBarPreferred: this.sideBarPreferred(),
      sideBarReopened: this.reopened,
      remembered: this.rememberedWidth,
      homeTarget: this.homeTargetWidth(),
      fullScreen: this.full,
    });
  }

  /** The remembered width, which a yield never changes. */
  remembered(): number {
    return this.rememberedWidth;
  }

  viewport(): number {
    return this.viewportWidth;
  }

  /** The viewport width, from the shell component that listens for `resize`. */
  setViewport(width: number): void {
    const next = Math.max(0, Math.round(width));
    if (next === this.viewportWidth) return;
    this.viewportWidth = next;
    // Width returned: a reopen is no longer a concession, so it stops being remembered as one.
    if (this.reopened && this.sideBarFitsUnaided()) this.reopened = false;
    this.notify();
  }

  draft(): string {
    return this.draftText;
  }

  setDraft(text: string): void {
    if (text === this.draftText) return;
    this.draftText = text;
    this.notify();
  }

  fullScreen(): boolean {
    return this.full;
  }

  /** Full screen is not persisted; leaving it restores the width it left, which it never changed. */
  toggleFullScreen(): void {
    this.endDrag();
    this.full = !this.full;
    this.notify();
  }

  /**
   * The session left `signed-in`. The draft and full screen belong to the user who made them, so the
   * next sign-in in this tab starts without either; the remembered width is per browser and stays.
   */
  endSession(): void {
    this.endDrag();
    // The Home release is per visit to Home, and the next principal's first Home paint is a new
    // visit: signing out does not change the area, so `ShellState` notifies nothing and without
    // this the next sign-in would open Home on the departed principal's dragged width.
    if (this.draftText === '' && !this.full && !this.homeWidthReleased) return;
    this.draftText = '';
    this.full = false;
    this.homeWidthReleased = false;
    this.notify();
  }

  /** Whether the side bar is collapsed by the yield rather than by the user. */
  sideBarYielded(): boolean {
    return this.sideBarPreferred() && !this.layout().sideBarShown;
  }

  /** Whether the side bar is showing only because the user reopened it over the yield. */
  sideBarReopened(): boolean {
    return this.reopened && this.layout().sideBarShown;
  }

  /** The user reopened a yielded side bar: it takes the next concession, and no preference moves. */
  reopenSideBar(): void {
    if (this.reopened) return;
    this.reopened = true;
    this.notify();
  }

  /** The user closed a side bar they had reopened over the yield; the stored preference is unchanged. */
  releaseSideBar(): void {
    if (!this.reopened) return;
    this.reopened = false;
    this.notify();
  }

  dragging(): boolean {
    return this.drag !== null;
  }

  /** A pointer went down on the handle at `x`. */
  beginDrag(x: number): void {
    this.drag = { x, width: this.layout().panelWidth };
    this.notify();
  }

  /** The pointer moved to `x`. The panel is docked right, so moving left widens it. */
  dragTo(x: number): void {
    if (this.drag === null) return;
    this.applyWidth(this.drag.width + (this.drag.x - x), false);
  }

  /** The drag ended, by release, cancel or Escape, at the width it had reached; that width is stored. */
  endDrag(): void {
    if (this.drag === null) return;
    this.drag = null;
    this.preferences.setPanelWidth(this.rememberedWidth);
    this.notify();
  }

  /** Change the width by `delta` px from its rendered width, within the bounds, and store it. */
  resizeBy(delta: number): void {
    this.applyWidth(this.layout().panelWidth + delta, true);
  }

  /** A result equal to the rendered width changes nothing, so a step at a stop keeps the remembered width. */
  private applyWidth(width: number, persist: boolean): void {
    // The width on screen before the gesture. Captured first because the release below changes
    // what `layout()` answers, so "equal to the rendered width" has to mean the width the user
    // can see, not the one the release has already moved to.
    const rendered = this.layout().panelWidth;
    // Released BEFORE the layout is read, so the bounds and the early return are computed against
    // the width this gesture is about to land on rather than against the Home target it replaces.
    this.homeWidthReleased = true;
    const layout = this.layout();
    const bounded = Math.round(Math.min(Math.max(width, PANEL_MIN_WIDTH), layout.panelMax));
    if (bounded === layout.panelWidth) {
      // Nothing to store, but releasing the Home target moved the panel, so consumers are told.
      if (bounded !== rendered) this.notify();
      return;
    }
    const changed = bounded !== this.rememberedWidth;
    this.rememberedWidth = bounded;
    if (persist) this.preferences.setPanelWidth(bounded);
    if (changed || persist) this.notify();
  }

  private sideBarPreferred(): boolean {
    return this.shell.open() && areaHasSideBar(this.shell.visibleArea());
  }

  private sideBarFitsUnaided(): boolean {
    return resolveLayout({
      viewport: this.viewportWidth,
      sideBarPreferred: true,
      sideBarReopened: false,
      remembered: this.rememberedWidth,
      homeTarget: this.homeTargetWidth(),
      fullScreen: false,
    }).sideBarShown;
  }

  /**
   * The Home target for this render, or `0` on any other area and once a width gesture on this
   * visit has released it (`applyWidth`). The remembered width is never written from here, so
   * leaving Home restores it.
   */
  private homeTargetWidth(): number {
    if (this.shell.activeArea() !== HOME_AREA_KEY || this.homeWidthReleased) return 0;
    return panelHomeTarget(this.viewportWidth);
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}

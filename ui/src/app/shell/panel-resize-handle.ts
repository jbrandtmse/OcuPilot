import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { PANEL_KEYBOARD_STEP, PANEL_MIN_WIDTH, PanelState } from '../core/panel-layout';
import { STRINGS } from '../core/strings';

/**
 * The panel's left edge: the only sash in the shell (EXPERIENCE.md panel-resize-handle).
 *
 * A focusable `role="separator"` whose value is the panel width in px, bounded by the panel
 * minimum and the width that leaves the content at its minimum. Pointer drag uses pointer capture and
 * ends when the capture is lost; Left and Right move 16px; Escape ends a drag at the width it reached.
 * The grip reads restrained at either stop. Every width, and the drag itself, is `PanelState`'s; this component holds none.
 */
@Component({
  selector: 'app-panel-resize-handle',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<div
    class="ocu-panel-resize-handle"
    role="separator"
    aria-orientation="vertical"
    tabindex="0"
    [attr.aria-label]="label"
    [attr.aria-valuenow]="now"
    [attr.aria-valuemin]="min"
    [attr.aria-valuemax]="max"
    [class.ocu-panel-resize-handle-dragging]="dragging"
    [class.ocu-panel-resize-handle-at-stop]="atStop"
    (pointerdown)="onPointerDown($event)"
    (pointermove)="onPointerMove($event)"
    (pointerup)="onPointerEnd($event)"
    (pointercancel)="onPointerEnd($event)"
    (lostpointercapture)="onPointerEnd($event)"
    (keydown)="onKeydown($event)"
  >
    <span class="ocu-panel-resize-grip" aria-hidden="true"></span>
  </div>`,
})
export class PanelResizeHandle {
  private readonly panel = inject(PanelState);

  protected readonly label = STRINGS.agentPanelResizeHandle;

  protected readonly min = PANEL_MIN_WIDTH;

  private readonly generation = signal(0);

  constructor() {
    const stop = this.panel.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.panel.endDrag();
    });
  }

  protected get now(): number {
    this.generation();
    return this.panel.layout().panelWidth;
  }

  protected get max(): number {
    this.generation();
    return this.panel.layout().panelMax;
  }

  protected get dragging(): boolean {
    this.generation();
    return this.panel.dragging();
  }

  /** At the minimum, or at the width that leaves the content at its minimum. */
  protected get atStop(): boolean {
    this.generation();
    const layout = this.panel.layout();
    return layout.panelWidth <= PANEL_MIN_WIDTH || layout.panelWidth >= layout.panelMax;
  }

  protected onPointerDown(event: PointerEvent): void {
    if (event.button !== 0) return;
    event.preventDefault();
    const target = event.currentTarget as HTMLElement;
    target.setPointerCapture?.(event.pointerId);
    target.focus();
    this.panel.beginDrag(event.clientX);
  }

  protected onPointerMove(event: PointerEvent): void {
    if (!this.panel.dragging()) return;
    this.panel.dragTo(event.clientX);
  }

  protected onPointerEnd(event: PointerEvent): void {
    if (!this.panel.dragging()) return;
    const target = event.currentTarget as HTMLElement;
    if (target.hasPointerCapture?.(event.pointerId)) target.releasePointerCapture(event.pointerId);
    this.panel.endDrag();
  }

  protected onKeydown(event: KeyboardEvent): void {
    if (event.key === 'ArrowLeft') {
      event.preventDefault();
      this.panel.resizeBy(PANEL_KEYBOARD_STEP);
      return;
    }
    if (event.key === 'ArrowRight') {
      event.preventDefault();
      this.panel.resizeBy(-PANEL_KEYBOARD_STEP);
      return;
    }
    if (event.key === 'Escape' && this.panel.dragging()) {
      // The drag ends where it is; the shell's own Escape handler has nothing to close for it.
      event.stopPropagation();
      this.panel.endDrag();
    }
  }
}

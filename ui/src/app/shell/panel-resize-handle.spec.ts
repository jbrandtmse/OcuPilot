import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { PanelState } from '../core/panel-layout';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { PanelResizeHandle } from './panel-resize-handle';
import {
  SHELL_PANEL_WIDTH,
  type StubbedAccountPreferences,
  lastRemembered,
  stubAccountPreferences,
} from '../testing/account-preferences';

/**
 * The panel's resize handle: its separator semantics, keyboard and pointer resize, and the grip's
 * stops, over a real `PanelState` at a 1,280px viewport with the side bar yielded (panel 400,
 * maximum 592). Geometry is the browser suite's; this pins the attributes and the store calls.
 *
 * The remembered width is the instance's (Story 15.5, AD-50), so "stored" here is what the handle
 * sent to `/account/preferences`, read off the stub's own request log rather than off a browser
 * storage map.
 */
describe('the panel resize handle', () => {
  let fixture: ComponentFixture<PanelResizeHandle>;
  let panel: PanelState;
  let account: StubbedAccountPreferences;

  const handle = (): HTMLElement => fixture.nativeElement.querySelector('[role="separator"]');

  beforeEach(() => {
    TestBed.resetTestingModule();
    account = stubAccountPreferences();
    const shell = new ShellState({ account });
    shell.setActiveArea('permissions');
    panel = new PanelState({ account, shell });
    panel.setViewport(1280);
    TestBed.configureTestingModule({ providers: [{ provide: PanelState, useValue: panel }] });
    fixture = TestBed.createComponent(PanelResizeHandle);
    document.body.appendChild(fixture.nativeElement);
    fixture.detectChanges();
  });

  afterEach(() => {
    (fixture.nativeElement as HTMLElement).remove();
  });

  const key = (name: string) => {
    handle().dispatchEvent(new KeyboardEvent('keydown', { key: name, bubbles: true, cancelable: true }));
    fixture.detectChanges();
  };

  it('is a focusable vertical separator named from the string source, valued in px', () => {
    const node = handle();
    expect(node.getAttribute('aria-orientation')).toBe('vertical');
    expect(node.getAttribute('tabindex')).toBe('0');
    expect(node.getAttribute('aria-label')).toBe(STRINGS.agentPanelResizeHandle);
    expect(node.getAttribute('aria-valuenow')).toBe('400');
    expect(node.getAttribute('aria-valuemin')).toBe('320');
    expect(node.getAttribute('aria-valuemax')).toBe('592');
  });

  it('AC3: Left widens and Right narrows by 16px, storing each step, and the grip is restrained at either stop', () => {
    // Mutation (Rule 19): drop the `atStop` class binding -> the restrained assertions go red.
    key('ArrowLeft');
    expect(handle().getAttribute('aria-valuenow')).toBe('416');
    expect(lastRemembered(account.calls, SHELL_PANEL_WIDTH)).toBe('416');
    expect(handle().classList).not.toContain('ocu-panel-resize-handle-at-stop');

    for (let step = 0; step < 20; step += 1) key('ArrowLeft');
    expect(handle().getAttribute('aria-valuenow')).toBe('592');
    expect(handle().classList).toContain('ocu-panel-resize-handle-at-stop');

    for (let step = 0; step < 30; step += 1) key('ArrowRight');
    expect(handle().getAttribute('aria-valuenow')).toBe('320');
    expect(handle().classList).toContain('ocu-panel-resize-handle-at-stop');
  });

  it('AC3: a pointer drag follows the pointer within the bounds, and Escape ends it where it is', () => {
    const pointer = (type: string, clientX: number) => {
      const event = new PointerEvent(type, { clientX, button: 0, pointerId: 1, bubbles: true, cancelable: true });
      handle().dispatchEvent(event);
      fixture.detectChanges();
    };
    pointer('pointerdown', 880);
    expect(handle().classList).toContain('ocu-panel-resize-handle-dragging');
    pointer('pointermove', 850);
    expect(handle().getAttribute('aria-valuenow')).toBe('430');
    expect(lastRemembered(account.calls, SHELL_PANEL_WIDTH)).toBeUndefined();

    let reachedDocument = false;
    const listener = () => {
      reachedDocument = true;
    };
    document.addEventListener('keydown', listener);
    key('Escape');
    document.removeEventListener('keydown', listener);
    expect(reachedDocument).toBe(false);
    expect(handle().classList).not.toContain('ocu-panel-resize-handle-dragging');
    expect(lastRemembered(account.calls, SHELL_PANEL_WIDTH)).toBe('430');

    // After Escape the pointer no longer drives the width.
    pointer('pointermove', 600);
    expect(handle().getAttribute('aria-valuenow')).toBe('430');
  });

  it('AC3: a drag whose pointer capture is lost ends there, so a later hover does not resize', () => {
    // Mutation (Rule 19): drop the `(lostpointercapture)` binding -> the last move resizes and this goes red.
    const pointer = (type: string, clientX: number) => {
      handle().dispatchEvent(new PointerEvent(type, { clientX, button: 0, pointerId: 1, bubbles: true, cancelable: true }));
      fixture.detectChanges();
    };
    pointer('pointerdown', 880);
    pointer('pointermove', 850);
    pointer('lostpointercapture', 850);
    expect(handle().classList).not.toContain('ocu-panel-resize-handle-dragging');
    pointer('pointermove', 600);
    expect(handle().getAttribute('aria-valuenow')).toBe('430');
  });
});

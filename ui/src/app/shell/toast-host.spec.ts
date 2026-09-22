import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { ChangeBus, type ChangeAction } from '../core/change-bus';
import { encodeEntityId } from '../core/entity-id';
import { ownIdSegment, screenForRoute } from '../core/navigation';
import { PanelState } from '../core/panel-layout';
import { ScopeService } from '../core/scope';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { ToastHost } from './toast-host';

/**
 * The change toast region's rendered contract (Story 5.7, AD-14, EXPERIENCE.md's toast row).
 *
 * **jsdom computes no layout**, so nothing here measures where the stack sits or how it is
 * elevated -- that is the browser tier's. What it pins is the region and its role, how many
 * toasts render out of how many raised, what each one offers, what the action does, and the two
 * cases where nothing is raised at all.
 *
 * Mutations (Rule 19):
 * - drop `role="status"` from the region -> the region test goes red, and an off-screen change
 *   would reach a screen-reader user not at all.
 * - render the whole stack instead of what the store hands over -> the three-from-four test goes
 *   red.
 * - navigate without `withQuery` in `open()` -> the namespace assertion goes red, and the toast
 *   would move the user's work to another namespace (AD-44).
 * - delete the four `(pointerenter)`/`(pointerleave)`/`(focusin)`/`(focusout)` bindings -> the hold
 *   test goes red, and a toast would expire under whoever was reading it.
 * - drop the `panel.fullScreen()` guard from `visible` -> the full-screen test goes red, and a
 *   toast would sit over the panel, which the published invariant forbids (DW-1412).
 */

class StubShell {
  readonly shown: string[] = [];

  showArea(areaKey: string): void {
    this.shown.push(areaKey);
  }
}

class StubScope {
  namespace(): string {
    return 'HSCUSTOM';
  }
}

/**
 * The two things this region asks of `PanelState`: whether the panel is full screen, and a
 * subscription so the answer re-reads under `OnPush`. A stub rather than the real store for the
 * reason `StubShell` and `StubScope` are stubs -- what the real store resolves is `panel.spec.ts`'s
 * and `ui/tools/panel-layout.test.mjs`'s, and jsdom computes no width for it to resolve from.
 */
class StubPanel {
  private full = false;
  private readonly listeners = new Set<() => void>();

  fullScreen(): boolean {
    return this.full;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  setFullScreen(value: boolean): void {
    this.full = value;
    for (const listener of this.listeners) listener();
  }
}

describe('the change toast region', () => {
  let fixture: ComponentFixture<ToastHost>;
  let bus: ChangeBus;
  let router: Router;
  let shell: StubShell;
  let panel: StubPanel;

  const region = (): HTMLElement | null => fixture.nativeElement.querySelector('.ocu-toast-region');
  const toasts = (): HTMLElement[] => Array.from(fixture.nativeElement.querySelectorAll('.ocu-toast'));
  const messages = (): string[] =>
    toasts().map((toast) => toast.querySelector('.ocu-toast-message')?.textContent?.trim() ?? '');

  function change(id: string, action: ChangeAction = 'updated', type = 'web-application', scope = 'instance') {
    bus.publish({ kind: 'changed', type, scope, id, action });
    fixture.detectChanges();
  }

  async function standOn(url: string): Promise<void> {
    await router.navigateByUrl(url);
    fixture.detectChanges();
  }

  beforeEach(() => {
    bus = new ChangeBus();
    shell = new StubShell();
    panel = new StubPanel();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: '', children: [] },
          { path: 'web-applications/list', children: [] },
          { path: 'web-applications/list/:id', children: [] },
        ]),
        { provide: ChangeBus, useValue: bus },
        { provide: ShellState, useValue: shell as unknown as ShellState },
        { provide: ScopeService, useValue: new StubScope() as unknown as ScopeService },
        { provide: PanelState, useValue: panel as unknown as PanelState },
      ],
    });
    fixture = TestBed.createComponent(ToastHost);
    router = TestBed.inject(Router);
    fixture.detectChanges();
  });

  it('draws nothing at all until a change is raised', () => {
    expect(region()).toBeNull();
  });

  it('renders one polite region naming itself, with the change sentence and the Open action', () => {
    change('/csp/myapp');

    const host = region();
    expect(host).not.toBeNull();
    expect(host?.getAttribute('role')).toBe('status');
    expect(host?.getAttribute('aria-label')).toBe(STRINGS.tableChangeToastRegion);
    expect(messages()).toEqual(['/csp/myapp was updated']);

    const action = toasts()[0].querySelector('.ocu-toast-action') as HTMLButtonElement;
    expect(action.textContent?.trim()).toBe('Open in Web applications');
    const dismiss = toasts()[0].querySelector('.ocu-toast-dismiss') as HTMLButtonElement;
    expect(dismiss.getAttribute('aria-label')).toBe(STRINGS.tableChangeToastDismiss);
  });

  it('each action has its own published sentence', () => {
    change('/csp/one', 'created');
    change('/csp/two', 'deleted');
    expect(messages()).toEqual(['/csp/two was deleted', '/csp/one was created']);
  });

  it('four raised render three, newest first, and the oldest is gone', () => {
    for (const id of ['/csp/one', '/csp/two', '/csp/three', '/csp/four']) change(id);
    expect(messages()).toEqual([
      '/csp/four was updated',
      '/csp/three was updated',
      '/csp/two was updated',
    ]);
  });

  it('the dismiss control takes its own toast and leaves the others', () => {
    change('/csp/one');
    change('/csp/two');
    (toasts()[0].querySelector('.ocu-toast-dismiss') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(messages()).toEqual(['/csp/one was updated']);
  });

  it('Integration AC: the action opens that screen with the entity named, carrying the namespace', async () => {
    await standOn('/?ns=HSCUSTOM');
    change('/csp/myapp');

    (toasts()[0].querySelector('.ocu-toast-action') as HTMLButtonElement).click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(router.url).toBe(`/web-applications/list/${encodeEntityId('/csp/myapp')}?ns=HSCUSTOM`);
    // DW-1419: the URL alone said nothing about the row. The list selects the id it carries
    // through `ownIdSegment`, so what the action produces is asserted in the spelling the list
    // reads rather than as a string only this spec knows how to build.
    expect(ownIdSegment(screenForRoute('web-applications/list')!, router.url)).toBe('/csp/myapp');
    expect(shell.shown).toEqual(['web-applications']);
    // A toast that has been acted on is noise over the row it pointed at.
    expect(toasts()).toEqual([]);
  });

  it('a change the open screen shows raises no toast -- the row highlight is the confirmation', async () => {
    await standOn('/web-applications/list?ns=HSCUSTOM');
    change('/csp/myapp');
    expect(region()).toBeNull();

    // The same screen and the same type in a scope it does not show is off-screen again, which is
    // what makes the guard the scoped predicate rather than a type test.
    change('/csp/myapp', 'updated', 'web-application', 'HSCUSTOM');
    expect(messages()).toEqual(['/csp/myapp was updated']);
  });

  it('nothing but a change reaches the region: a proposal opening raises no toast, and no fault can', () => {
    bus.publish({ kind: 'proposal-open', type: 'web-application', scope: 'instance', id: '/csp/myapp', proposalId: 'p1' });
    bus.publish({ kind: 'proposal-closed', type: 'web-application', scope: 'instance', id: '/csp/myapp', proposalId: 'p1' });
    fixture.detectChanges();
    expect(region()).toBeNull();

    // A fault has no route to this component at all: its one input is the change bus, and
    // `ChangeBus.publish` refuses anything that is not a reference triple. A toast for an error
    // would need a second input, which is what DESIGN.md's "toasts are never used for errors"
    // means mechanically.
    expect(bus.publish({ kind: 'changed', type: 'not-an-entity-type', scope: 'instance', id: 'x', action: 'updated' })).toBe(false);
    fixture.detectChanges();
    expect(region()).toBeNull();
  });

  it('places no toast while the panel is full screen, and places a standing one when it ends', () => {
    // DW-1412: the published rule offsets the stack by the panel's live width so no toast ever
    // overlays the panel. In full screen the panel covers the whole content area, so there is no
    // offset that satisfies it and the decision is to place nothing. jsdom computes no layout, so
    // this tier asserts the decision; the geometry is `ui/browser/toast.browser-spec.mjs`'s.
    panel.setFullScreen(true);
    change('/csp/myapp');
    expect(region()).toBeNull();

    // The toast was raised and is still standing, so leaving full screen places it -- suppression
    // is about placement, never about dropping the change.
    panel.setFullScreen(false);
    fixture.detectChanges();
    expect(messages()).toEqual(['/csp/myapp was updated']);
  });

  it('hovering or focusing the stack holds every countdown, and both partners must let go', () => {
    // The clocks themselves are the store's and `ui/tools/toasts.test.mjs` drives them by hand.
    // What this asserts is the wiring: that each of the two sources reaches the store on its own,
    // and that a release from one while the other still holds is not a release. With real 30 s
    // timers in a synchronous jsdom test, nothing about what is still rendered can say that.
    change('/csp/one');
    const held = () => (region() as HTMLElement).getAttribute('data-ocu-holding');
    const send = (type: string) => {
      (region() as HTMLElement).dispatchEvent(new Event(type));
      fixture.detectChanges();
    };
    expect(held()).toBeNull();

    send('pointerenter');
    expect(held()).toBe('true');
    send('pointerleave');
    expect(held()).toBeNull();

    send('focusin');
    expect(held()).toBe('true');
    send('focusout');
    expect(held()).toBeNull();

    send('pointerenter');
    send('focusin');
    expect(held()).toBe('true');
    // One source letting go while the other still holds is not a release: a `pointerleave` while
    // the dismiss control holds focus must not start the clocks under the reader.
    send('pointerleave');
    expect(held()).toBe('true');
    send('focusout');
    expect(held()).toBeNull();

    expect(messages()).toEqual(['/csp/one was updated']);
  });
});

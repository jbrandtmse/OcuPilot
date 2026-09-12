import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import type { ApiService } from '../core/api';
import { OverlayStack } from '../core/overlay-stack';
import { ScopeService } from '../core/scope';
import { STRINGS } from '../core/strings';
import { NamespaceSwitch } from './namespace-switch';

/**
 * The switch's rendered contract (EXPERIENCE.md `:315`, DESIGN.md `:1007`).
 *
 * The service under it is the real one, over a stub API, because the rules being asserted --
 * which namespaces are offered, which scope is in force, what happens to one the instance
 * refuses -- are the service's and the component's together. The appearance is CSS and jsdom
 * computes none of it; the dotted underline, the gradient end and the popup's surface are
 * asserted against the shipped stylesheet in `ui/tools/design-tokens.test.mjs` and measured in
 * the browser under Manual checks.
 */

interface StubCall {
  readonly path: string;
  readonly scope: string | null | undefined;
}

function stubApi(answers: readonly unknown[]) {
  const calls: StubCall[] = [];
  const api = {
    calls,
    requestJson: async (path: string, init: { scope?: string | null } = {}) => {
      calls.push({ path, scope: init.scope });
      return answers[Math.min(calls.length - 1, answers.length - 1)];
    },
  };
  return api;
}

function listAnswer(scope: string, namespaces: readonly unknown[]) {
  return { kind: 'ok', status: 200, body: { scope, namespaces } };
}

const DENIED = {
  kind: 'error',
  status: 403,
  code: 'NS.DENIED',
  reason: 'This account may not enter that namespace',
  detail: { failedPair: '%DB_USER:READ' },
};

const THREE = [
  { name: 'HSCUSTOM', writable: true },
  { name: 'USER', writable: true },
  { name: 'HSLIB', writable: false },
];

const SETTLE = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('the namespace switch', () => {
  let fixture: ComponentFixture<NamespaceSwitch>;
  let router: Router;
  let overlays: OverlayStack;
  const planted: HTMLElement[] = [];

  function mount(answers: readonly unknown[]): ReturnType<typeof stubApi> {
    const api = stubApi(answers);
    overlays = new OverlayStack();
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: '', children: [] },
          { path: 'logs', children: [] },
          { path: 'permissions/users', children: [] },
        ]),
        {
          provide: ScopeService,
          useValue: new ScopeService({ api: api as unknown as ApiService }),
        },
        { provide: OverlayStack, useValue: overlays },
      ],
    });
    fixture = TestBed.createComponent(NamespaceSwitch);
    router = TestBed.inject(Router);
    fixture.detectChanges();
    return api;
  }

  beforeEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  const trigger = (): HTMLButtonElement =>
    fixture.nativeElement.querySelector('.ocu-namespace-switch-trigger');

  const listbox = (): HTMLElement => fixture.nativeElement.querySelector('[role="listbox"]');

  const optionNames = (): string[] =>
    Array.from(fixture.nativeElement.querySelectorAll('[role="option"]')).map((option) =>
      (option as HTMLElement).textContent!.trim()
    );

  it('AC1: the list is named Namespace and offers exactly the namespaces the user may write in', async () => {
    mount([listAnswer('HSCUSTOM', THREE)]);
    await SETTLE();
    fixture.detectChanges();

    expect(trigger().getAttribute('aria-haspopup')).toBe('listbox');
    expect(trigger().getAttribute('aria-expanded')).toBe('false');
    expect(listbox()).toBeNull();

    trigger().click();
    fixture.detectChanges();

    expect(trigger().getAttribute('aria-expanded')).toBe('true');
    expect(listbox().getAttribute('aria-label')).toBe(STRINGS.headerNamespaceLabel);
    // DW-7: HSLIB is readable and not writable, so it is reported by the endpoint and is not
    // somewhere the switch sends anyone.
    expect(optionNames()).toEqual(['HSCUSTOM', 'USER']);
  });

  it('AC1: the current scope is the trigger\'s value and is the option marked selected', async () => {
    mount([listAnswer('HSCUSTOM', THREE)]);
    await router.navigateByUrl('/logs?ns=USER');
    await SETTLE();
    fixture.detectChanges();

    expect(trigger().textContent!.trim().startsWith('USER')).toBe(true);

    trigger().click();
    fixture.detectChanges();

    const selected = Array.from(
      fixture.nativeElement.querySelectorAll('[role="option"]')
    ).filter((option) => (option as HTMLElement).getAttribute('aria-selected') === 'true');
    expect(selected).toHaveLength(1);
    expect((selected[0] as HTMLElement).textContent!.trim()).toBe('USER');
  });

  it('AC2: a selection replaces ns and touches nothing else on the URL', async () => {
    mount([listAnswer('HSCUSTOM', THREE)]);
    await router.navigateByUrl('/permissions/users?page=3&ns=HSCUSTOM#row-7');
    await SETTLE();
    fixture.detectChanges();

    trigger().click();
    fixture.detectChanges();
    const options = fixture.nativeElement.querySelectorAll('[role="option"]');
    (options[1] as HTMLElement).click();
    await fixture.whenStable();

    // The path, the fragment and the other parameter are the same URL; only `ns` moved, which
    // is what makes the screen re-fetch in place rather than re-route (AD-44).
    expect(router.url).toBe('/permissions/users?page=3&ns=USER#row-7');
  });

  it('AC3: the scope the route names is what the shell is scoped to, and it is published', async () => {
    const api = mount([listAnswer('HSCUSTOM', THREE)]);
    const scope = TestBed.inject(ScopeService);
    await router.navigateByUrl('/logs?ns=USER');
    await SETTLE();
    fixture.detectChanges();

    expect(scope.namespace()).toBe('USER');
    // The list itself is the one read that carries no namespace, so a bad `ns` cannot close it.
    expect(api.calls[0].path).toBe('/api/ocupilot/namespaces');
    expect(api.calls[0].scope).toBeNull();
  });

  it('DW-8: an unresolvable ns is replaced with replaceUrl and the missing pair is named', async () => {
    mount([listAnswer('HSCUSTOM', [{ name: 'HSCUSTOM', writable: true }]), DENIED]);
    await router.navigateByUrl('/logs?ns=USER');
    await SETTLE();
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(router.url).toBe('/logs?ns=HSCUSTOM');
    expect(trigger().textContent!.trim().startsWith('HSCUSTOM')).toBe(true);

    const note = fixture.nativeElement.querySelector('.ocu-namespace-switch-note');
    expect(note).not.toBeNull();
    expect(note.getAttribute('role')).toBe('status');
    expect(note.textContent.trim()).toBe('Requires %DB_USER:READ');
  });

  it('DW-8: a namespace the instance cannot name a pair for falls back silently', async () => {
    mount([
      listAnswer('HSCUSTOM', [{ name: 'HSCUSTOM', writable: true }]),
      { kind: 'error', status: 400, code: 'NS.UNKNOWN', reason: 'Unknown namespace', detail: null },
    ]);
    await router.navigateByUrl('/logs?ns=NOPE');
    await SETTLE();
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(router.url).toBe('/logs?ns=HSCUSTOM');
    // No Fixed strings row spells "that namespace does not exist", and this story invents none.
    // The live region is mounted either way -- a `role="status"` announces content that changes
    // inside it, not a region that appears already full -- so what says nothing is its emptiness.
    const note = fixture.nativeElement.querySelector('.ocu-namespace-switch-note');
    expect(note).not.toBeNull();
    expect(note.textContent.trim()).toBe('');
  });

  it('nothing is claimed before the list has answered and the route names no namespace', () => {
    mount([listAnswer('HSCUSTOM', THREE)]);
    expect(trigger()).toBeNull();
  });

  it('the keyboard opens, moves and chooses, and Escape belongs to the overlay stack', async () => {
    mount([listAnswer('HSCUSTOM', THREE)]);
    planted.push(fixture.nativeElement);
    document.body.appendChild(fixture.nativeElement);
    await router.navigateByUrl('/logs?ns=HSCUSTOM');
    await SETTLE();
    fixture.detectChanges();

    trigger().click();
    fixture.detectChanges();
    await fixture.whenStable();

    const list = listbox();
    expect(document.activeElement).toBe(list);
    expect(list.getAttribute('aria-activedescendant')).toBe(
      fixture.nativeElement.querySelectorAll('[role="option"]')[0].id
    );

    list.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    fixture.detectChanges();
    expect(list.getAttribute('aria-activedescendant')).toBe(
      fixture.nativeElement.querySelectorAll('[role="option"]')[1].id
    );

    list.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await fixture.whenStable();
    fixture.detectChanges();
    expect(router.url).toBe('/logs?ns=USER');
    expect(document.activeElement).toBe(trigger());

    // The component binds no Escape of its own: the shell's one handler asks the stack, which is
    // what lets one key press close one thing (DW-137).
    trigger().click();
    fixture.detectChanges();
    expect(overlays.top()).toBe('namespace-switch');
    expect(overlays.closeTop()).toBe(true);
    fixture.detectChanges();
    expect(trigger().getAttribute('aria-expanded')).toBe('false');
  });

  it('a pointer gesture outside closes it without taking focus back', async () => {
    mount([listAnswer('HSCUSTOM', THREE)]);
    planted.push(fixture.nativeElement);
    document.body.appendChild(fixture.nativeElement);
    const outside = document.createElement('button');
    document.body.appendChild(outside);
    planted.push(outside);

    await router.navigateByUrl('/logs?ns=HSCUSTOM');
    await SETTLE();
    fixture.detectChanges();
    trigger().click();
    fixture.detectChanges();
    expect(listbox()).not.toBeNull();

    outside.focus();
    outside.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
    fixture.detectChanges();

    expect(listbox()).toBeNull();
    expect(trigger().getAttribute('aria-expanded')).toBe('false');
    expect(document.activeElement).toBe(outside);
  });

  it('no dialog is ever opened, and no URL leaves the application', async () => {
    mount([listAnswer('HSCUSTOM', THREE)]);
    await router.navigateByUrl('/logs?ns=HSCUSTOM');
    await SETTLE();
    fixture.detectChanges();
    trigger().click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[role="dialog"]')).toBeNull();
    expect(fixture.nativeElement.querySelector('dialog')).toBeNull();
    expect(fixture.nativeElement.querySelector('a[href]')).toBeNull();
  });
});

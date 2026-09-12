import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { NavigationService, type Verdict } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { COMMAND_BOX_OVERLAY_ID, CommandBox } from './command-box';

/**
 * The command box's rendered contract (EXPERIENCE.md `:317`, `:356-360`; DESIGN.md `:1017`),
 * and the Integration AC's Escape order.
 *
 * The screen roster and the verdicts come from a stubbed `NavigationService`, for the reason
 * the service carries those seams at all: the shipped mirror holds one screen with no declared
 * actions, so grouping, gating and alias matching would have nothing to act on.
 */

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

function screen(
  route: string,
  labelKey: string,
  area: string,
  extra: Partial<ScreenDeclaration> = {}
): ScreenDeclaration {
  return {
    descriptor: `OcuPilot.Screen.Descriptor.Stub`,
    route,
    area,
    labelKey,
    sideBarPosition: 1,
    archetype: 'list',
    built: true,
    privileges: [],
    entityType: 'user',
    secondaryEntityTypes: [],
    scope: 'instance',
    parentScope: '',
    id: { kind: 'single', parts: [] },
    context: { fields: [], secretFields: [] },
    primaryAction: { id: '', selfProtection: '' },
    rowActions: [],
    emptyStateKey: '',
    commandAliases: [],
    classicPage: '',
    classicLinkExemption: { exempt: false, reason: '' },
    toolIdentifier: 'stub',
    ...extra,
  };
}

const USERS = screen('permissions/users', 'navAreaPermissions', 'permissions', {
  commandAliases: ['accounts'],
  primaryAction: { id: 'create', selfProtection: '' },
  rowActions: [{ id: 'delete', selfProtection: 'current-user' }],
});
const LOGS = screen('logs/messages', 'navAreaLogs', 'logs', { commandAliases: ['tail'] });

class StubNavigation {
  readonly verdicts = new Map<string, Verdict>();
  current: ScreenDeclaration | null = USERS;
  private readonly listeners = new Set<() => void>();

  builtScreens(): readonly ScreenDeclaration[] {
    return [USERS, LOGS];
  }

  screenForUrl(): ScreenDeclaration | null {
    return this.current;
  }

  screenVerdict(route: string): Verdict {
    return this.verdicts.get(route) ?? ALLOWED;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(): void {
    for (const listener of this.listeners) listener();
  }
}

describe('the command box', () => {
  let fixture: ComponentFixture<CommandBox>;
  let navigation: StubNavigation;
  let overlays: OverlayStack;
  const planted: HTMLElement[] = [];

  const field = (): HTMLInputElement => fixture.nativeElement.querySelector('[role="combobox"]');
  const listbox = (): HTMLElement | null => fixture.nativeElement.querySelector('[role="listbox"]');
  const options = (): HTMLElement[] =>
    Array.from(fixture.nativeElement.querySelectorAll('[role="option"]'));
  const count = (): string =>
    fixture.nativeElement.querySelector('[role="status"]')?.textContent?.trim() ?? '';

  const type = (value: string) => {
    field().value = value;
    field().dispatchEvent(new Event('input', { bubbles: true }));
    fixture.detectChanges();
  };

  const chord = () => {
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'k', ctrlKey: true, bubbles: true }));
    fixture.detectChanges();
  };

  beforeEach(() => {
    navigation = new StubNavigation();
    overlays = new OverlayStack();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: '', children: [] },
          { path: 'permissions/users', children: [] },
          { path: 'logs/messages', children: [] },
        ]),
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: OverlayStack, useValue: overlays },
      ],
    });
    fixture = TestBed.createComponent(CommandBox);
    fixture.detectChanges();
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
  });

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('is a closed combobox until the chord opens it, and the chord is shown once as a chip', () => {
    expect(field().getAttribute('aria-expanded')).toBe('false');
    expect(field().getAttribute('aria-controls')).toBe('ocu-command-box-list');
    expect(field().getAttribute('aria-activedescendant')).toBeNull();
    expect(listbox()).toBeNull();

    // The chord is the chip's, and only the chip's: the placeholder is the Fixed strings
    // table's own sentence and says nothing about keys.
    expect(field().getAttribute('placeholder')).toBe(STRINGS.commandBoxPlaceholder);
    const chips = fixture.nativeElement.querySelectorAll('.ocu-command-box-kbd');
    expect(chips).toHaveLength(1);
    expect(chips[0].textContent?.trim()).toContain('K');
    expect(chips[0].getAttribute('aria-hidden')).toBe('true');

    chord();
    expect(field().getAttribute('aria-expanded')).toBe('true');
    expect(document.activeElement).toBe(field());
    expect(listbox()).not.toBeNull();
  });

  it('groups its results as Screens and Actions and reports a polite count', () => {
    chord();
    const groups = fixture.nativeElement.querySelectorAll('[role="group"]');
    expect(groups).toHaveLength(2);
    expect(groups[0].querySelectorAll('[role="option"]')).toHaveLength(2);
    // The current screen's declared actions: its primary action and its row actions.
    expect(groups[1].querySelectorAll('[role="option"]')).toHaveLength(2);

    const status = fixture.nativeElement.querySelector('[role="status"]');
    expect(status.textContent.trim()).toBe('2 screens, 2 actions');
  });

  it('filters screens by their declared aliases, not by a list of its own', () => {
    chord();
    type('accounts');
    expect(options().map((option) => option.textContent?.trim())).toEqual([
      `${STRINGS.navAreaPermissions}${STRINGS.navAreaPermissions}`,
    ]);
    expect(count()).toBe('1 screens, 0 actions');

    type('tail');
    expect(options()).toHaveLength(1);
    expect(options()[0].textContent).toContain(STRINGS.navAreaLogs);
  });

  it('a filter that matches nothing says so as a polite status, over an empty listbox', () => {
    chord();
    type('nothing matches this');
    expect(options()).toHaveLength(0);
    expect(count()).toBe(STRINGS.commandBoxNoMatch);
    expect(listbox()).not.toBeNull();
  });

  it('a gated screen stays listed and non-selectable, with the failed pair in its own content', async () => {
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/');
    navigation.verdicts.set('permissions/users', {
      allowed: false,
      failedPair: '%Admin_Secure:USE',
    });
    navigation.notify();
    chord();

    const gated = options()[0];
    expect(gated.getAttribute('aria-disabled')).toBe('true');
    expect(gated.hasAttribute('disabled')).toBe(false);
    expect(gated.textContent).toContain('Requires %Admin_Secure:USE');
    // No tooltip: the input keeps DOM focus while the list is open, so one could never show.
    expect(fixture.nativeElement.querySelectorAll('[role="tooltip"]')).toHaveLength(0);

    gated.click();
    await fixture.whenStable();
    expect(router.url).toBe('/');
    expect(field().getAttribute('aria-expanded')).toBe('true');
  });

  it('arrow keys move the active descendant and Enter opens the highlighted screen', async () => {
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/');
    chord();
    expect(field().getAttribute('aria-activedescendant')).toBe(options()[0].id);

    field().dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    fixture.detectChanges();
    expect(field().getAttribute('aria-activedescendant')).toBe(options()[1].id);
    expect(options()[1].getAttribute('aria-selected')).toBe('true');

    field().dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await fixture.whenStable();
    fixture.detectChanges();
    expect(router.url).toBe('/logs/messages');
    expect(field().getAttribute('aria-expanded')).toBe('false');
  });

  it('DW-134: opening a screen from the box keeps the namespace the route is scoped to', async () => {
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users?ns=USER');
    chord();

    field().dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    fixture.detectChanges();
    field().dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await fixture.whenStable();
    fixture.detectChanges();

    // The box reaches every screen in the product, so it is the surface that would drop the
    // scope everywhere rather than on one band.
    expect(router.url).toBe('/logs/messages?ns=USER');
  });

  it('choosing a screen leaves focus forward, and reopening starts from an empty filter', async () => {
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/');
    const elsewhere = document.createElement('button');
    document.body.appendChild(elsewhere);
    planted.push(elsewhere);
    elsewhere.focus();

    chord();
    type('tail');
    expect(options()).toHaveLength(1);
    field().dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await fixture.whenStable();
    fixture.detectChanges();

    // Escape returns focus to where it was; a choice does not -- the element it came from
    // belongs to the screen the user just left.
    expect(document.activeElement).not.toBe(elsewhere);

    chord();
    expect(field().value).toBe('');
    expect(count()).toBe('2 screens, 2 actions');
  });

  it("a row action is listed and unavailable, the same as the command bar draws it", () => {
    chord();
    const actions = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-command-box-group-actions [role="option"]')
    ) as HTMLElement[];
    const label = (option: HTMLElement) =>
      option.querySelector('.ocu-command-box-option-label')?.textContent?.trim();

    const primary = actions.find((option) => label(option) === 'create');
    const rowAction = actions.find((option) => label(option) === 'delete');
    expect(primary?.getAttribute('aria-disabled')).toBeNull();
    expect(rowAction?.getAttribute('aria-disabled')).toBe('true');
    expect(rowAction?.textContent).toContain(STRINGS.privilegeSelectRowFirst);
    expect(rowAction?.hasAttribute('disabled')).toBe(false);

    // And choosing it does nothing rather than closing the box on a silent no-op.
    rowAction?.click();
    fixture.detectChanges();
    expect(field().getAttribute('aria-expanded')).toBe('true');
  });

  it('Integration AC: Escape closes the box, restores focus, and leaves the side bar alone', () => {
    // The side bar is the stack's bottom-most member; the shell's one Escape handler is what
    // calls `closeTop`, and this is the order it gets.
    let sideBarClosed = 0;
    overlays.push('side-bar', () => (sideBarClosed += 1), 'bottom');

    const elsewhere = document.createElement('button');
    document.body.appendChild(elsewhere);
    planted.push(elsewhere);
    elsewhere.focus();

    chord();
    expect(overlays.top()).toBe(COMMAND_BOX_OVERLAY_ID);
    expect(document.activeElement).toBe(field());

    expect(overlays.closeTop()).toBe(true);
    fixture.detectChanges();
    expect(field().getAttribute('aria-expanded')).toBe('false');
    expect(document.activeElement).toBe(elsewhere);
    expect(sideBarClosed).toBe(0);

    // A second Escape reaches the bar, and a third has nothing left.
    expect(overlays.closeTop()).toBe(true);
    expect(sideBarClosed).toBe(1);
    expect(overlays.closeTop()).toBe(false);
  });

  it('the chord is inert while a dialog is open', () => {
    const dialog = document.createElement('div');
    dialog.setAttribute('role', 'dialog');
    document.body.appendChild(dialog);
    planted.push(dialog);

    chord();
    expect(field().getAttribute('aria-expanded')).toBe('false');
    expect(overlays.ids()).toEqual([]);
  });

  it('Ctrl+Shift+K is a different chord and does not open it', () => {
    document.dispatchEvent(
      new KeyboardEvent('keydown', { key: 'K', ctrlKey: true, shiftKey: true, bubbles: true })
    );
    fixture.detectChanges();
    expect(field().getAttribute('aria-expanded')).toBe('false');
  });

  it('is not a channel to the agent: no composer, no avatar, no turn', () => {
    chord();
    type('please restart the instance');
    expect(fixture.nativeElement.querySelector('textarea')).toBeNull();
    expect(fixture.nativeElement.querySelector('[class*="avatar"]')).toBeNull();
    expect(fixture.nativeElement.querySelectorAll('input')).toHaveLength(1);
  });
});

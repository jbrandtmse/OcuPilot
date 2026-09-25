import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { NavigationService, type Verdict } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { Session } from '../core/session';
import type { ScreenDeclaration } from '../core/screens.generated';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { screenDeclaration } from '../testing/screen-declaration';
import { tableDeclaration } from '../testing/table-declaration';
import { COMMAND_BOX_OVERLAY_ID, CommandBox } from './command-box';
import { AccountPreferences } from '../core/account-preferences';
import {
  SHELL_SIDE_BAR_OPEN,
  type StubbedAccountPreferences,
  lastRemembered,
  stubAccountPreferences,
} from '../testing/account-preferences';

/**
 * The command box's rendered contract (EXPERIENCE.md "Opens on click or Ctrl/Cmd+K; typing", "*Header, center.* Opens on click"; DESIGN.md `:1017`),
 * and the Integration AC's Escape order.
 *
 * The screen roster and the verdicts come from a stubbed `NavigationService`, for the reason
 * the service carries those seams at all: no screen in the shipped mirror declares an action, so
 * action grouping and row-scoped gating would have nothing to act on.
 */

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

function screen(
  route: string,
  labelKey: string,
  area: string,
  extra: Partial<ScreenDeclaration> = {}
): ScreenDeclaration {
  return screenDeclaration({ route, labelKey, area, ...extra });
}

const USERS = screen('permissions/users', 'navAreaPermissions', 'permissions', {
  commandAliases: ['accounts'],
  primaryAction: { id: 'create', selfProtection: '' },
  rowActions: [{ id: 'delete', selfProtection: 'current-user' }],
});
const LOGS = screen('logs/messages', 'navAreaLogs', 'logs', { commandAliases: ['tail'] });
const HOME = screen('', 'navAreaHome', 'home', { commandAliases: ['start'] });

class StubNavigation {
  readonly verdicts = new Map<string, Verdict>();
  current: ScreenDeclaration | null = USERS;
  roster: readonly ScreenDeclaration[] = [USERS, LOGS];
  private readonly listeners = new Set<() => void>();

  builtScreens(): readonly ScreenDeclaration[] {
    return this.roster;
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

function memoryStorage() {
  const map = new Map<string, string>();
  return {
    getItem: (key: string) => map.get(key) ?? null,
    setItem: (key: string, value: string) => {
      map.set(key, value);
    },
    removeItem: (key: string) => {
      map.delete(key);
    },
  };
}

describe('the command box', () => {
  let fixture: ComponentFixture<CommandBox>;
  let navigation: StubNavigation;
  let shell: ShellState;
  let accountPreferences: StubbedAccountPreferences;
  let overlays: OverlayStack;
  let actions: ScreenActions;
  let creates: number;
  let signOuts: number;
  let unregisterCreate: () => void;
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
    accountPreferences = stubAccountPreferences();
    shell = new ShellState({ account: accountPreferences });
    overlays = new OverlayStack();
    // USERS' primary action has a registered handler, as it would once a screen runs it.
    actions = new ScreenActions();
    creates = 0;
    signOuts = 0;
    unregisterCreate = actions.register(USERS.descriptor, 'create', () => (creates += 1));
    // DW-389: a declared row action with no registered handler is offered on no surface, so the
    // stub screen's own `delete` needs one for the box to list it at all.
    actions.register(USERS.descriptor, 'delete', () => {});
    actions.register('OcuPilot.Screen.Descriptor.AgentSwitches', 'delete', () => {});
    TestBed.configureTestingModule({
      providers: [
        { provide: AccountPreferences, useValue: accountPreferences },
        // The box reads the current screen's selection to decide whether a row action is offered
        // or explained (AD-53), so the stores are real here as they are on the command bar.
        { provide: ScreenStores, useValue: new ScreenStores({ account: accountPreferences }) },
        provideRouter([
          { path: '', children: [] },
          { path: 'permissions/users', children: [] },
          { path: 'logs/messages', children: [] },
        ]),
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: OverlayStack, useValue: overlays },
        { provide: ScreenActions, useValue: actions },
        { provide: ShellState, useValue: shell },
        {
          provide: Session,
          useValue: {
            userName: () => 'Dana',
            signOut: async () => {
              signOuts += 1;
            },
          } as unknown as Session,
        },
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
    // Each group carries its published name (EXPERIENCE.md's command-box result-group labels).
    expect(groups[0].getAttribute('aria-label')).toBe(STRINGS.commandBoxGroupScreens);
    expect(groups[1].getAttribute('aria-label')).toBe(STRINGS.commandBoxGroupActions);
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

  it("choosing a screen moves an open side bar to that screen's area and leaves a collapsed one collapsed", async () => {
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users');
    // The bar is open on another area, the way the rail leaves it; the route's own area change
    // alone would not move an open bar.
    shell.activateArea('permissions', false);
    expect(shell.visibleArea()).toBe('permissions');

    chord();
    type('tail');
    field().dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await fixture.whenStable();
    fixture.detectChanges();

    expect(router.url).toBe('/logs/messages');
    expect(shell.open()).toBe(true);
    expect(shell.visibleArea()).toBe('logs');

    // A bar the user collapsed with Ctrl/Cmd+B stays collapsed, and so does the stored choice.
    shell.toggleOpen();
    chord();
    type('accounts');
    field().dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await fixture.whenStable();
    fixture.detectChanges();

    expect(router.url).toBe('/permissions/users');
    expect(shell.open()).toBe(false);
    expect(lastRemembered(accountPreferences.calls, SHELL_SIDE_BAR_OPEN)).toBe('0');
  });

  it('choosing a screen whose area navigates (Home) leaves the side bar where it was', async () => {
    navigation.roster = [USERS, LOGS, HOME];
    navigation.notify();
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users');
    shell.activateArea('permissions', false);

    chord();
    type('start');
    field().dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await fixture.whenStable();
    fixture.detectChanges();

    expect(router.url).toBe('/');
    expect(shell.open()).toBe(true);
    expect(shell.visibleArea()).toBe('permissions');
  });

  it('a gated screen row moves no side bar', async () => {
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/');
    navigation.verdicts.set('logs/messages', { allowed: false, failedPair: '%Admin_Operate:USE' });
    navigation.notify();
    shell.collapse();
    chord();
    type('tail');
    options()[0].click();
    await fixture.whenStable();
    expect(shell.open()).toBe(false);
    expect(shell.visibleArea()).toBe('');
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

    // `create` carries published copy in `ACTION_LABELS`, so both surfaces draw it as "Create"
    // -- the same resolution `disable` already goes through.
    const primary = actions.find((option) => label(option) === STRINGS.actionCreate);
    const rowAction = actions.find((option) => label(option) === STRINGS.actionDelete);
    expect(primary?.getAttribute('aria-disabled')).toBeNull();
    expect(rowAction?.getAttribute('aria-disabled')).toBe('true');
    expect(rowAction?.textContent).toContain(STRINGS.privilegeSelectRowFirst);
    expect(rowAction?.hasAttribute('disabled')).toBe(false);

    // And choosing it does nothing rather than closing the box on a silent no-op.
    rowAction?.click();
    fixture.detectChanges();
    expect(field().getAttribute('aria-expanded')).toBe('true');
  });

  it("AD-53: with a row selected, a self-protected action is listed with the instance's own sentence", () => {
    // The box says what the bar and the row menu say about the same action on the same row: the
    // reason is the published one, inline after the label, and the entry stays `aria-disabled`
    // rather than `disabled`.
    //
    // Mutation (Rule 19): drop the `selected` lookup from `actionCandidates` -> the box falls back
    // to "Select a row first" while a row is selected, and this goes red.
    navigation.current = screen('web-applications/list', 'navAreaWebApps', 'web-applications', {
      descriptor: 'OcuPilot.Screen.Descriptor.WebAppList',
      primaryAction: { id: '', selfProtection: '' },
      rowActions: [{ id: 'delete', selfProtection: 'serves-ocupilot' }],
    });
    TestBed.inject(ScreenActions).register('OcuPilot.Screen.Descriptor.WebAppList', 'delete', () => {});
    TestBed.inject(ScreenStores)
      .for('OcuPilot.Screen.Descriptor.WebAppList', [])
      .setSelection(['/api/ocupilot']);
    chord();

    const entry = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-command-box-group-actions [role="option"]')
    ).find(
      (option) =>
        (option as HTMLElement).querySelector('.ocu-command-box-option-label')?.textContent?.trim() ===
        STRINGS.actionDelete
    ) as HTMLElement | undefined;
    expect(entry).toBeDefined();
    expect(entry?.textContent).toContain(STRINGS.webAppServesOcuPilotRefusal);
    expect(entry?.getAttribute('aria-disabled')).toBe('true');
    expect(entry?.hasAttribute('disabled')).toBe(false);
  });

  it("Story 7.2: with the signed-in account selected, the box lists its protected-account action with the published sentence", () => {
    // Mutation (Rule 19): drop `this.signedIn()` from `actionCandidates`' call -> no reason, red.
    navigation.current = screen('permissions/users', 'navAreaPermissions', 'permissions', {
      descriptor: 'OcuPilot.Screen.Descriptor.UserList',
      primaryAction: { id: '', selfProtection: '' },
      rowActions: [{ id: 'delete', selfProtection: 'protected-account' }],
    });
    TestBed.inject(ScreenActions).register('OcuPilot.Screen.Descriptor.UserList', 'delete', () => {});
    TestBed.inject(ScreenStores).for('OcuPilot.Screen.Descriptor.UserList', []).setSelection(['dana']);
    chord();
    const entry = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-command-box-group-actions [role="option"]')
    ).find(
      (option) =>
        (option as HTMLElement).querySelector('.ocu-command-box-option-label')?.textContent?.trim() ===
        STRINGS.actionDelete
    ) as HTMLElement | undefined;
    expect(entry?.textContent).toContain(STRINGS.userRefusalCurrentUser);
    expect(entry?.getAttribute('aria-disabled')).toBe('true');
  });

  it("Story 9.3: with a not-deletable row selected, the box lists its system-resource action with the published sentence", () => {
    // Mutation (Rule 19): drop `row` from `actionCandidates`' call -> no reason, red.
    const base = tableDeclaration();
    navigation.current = tableDeclaration({
      route: 'permissions/resources',
      labelKey: 'navAreaPermissions',
      area: 'permissions',
      descriptor: 'OcuPilot.Screen.Descriptor.ResourceList',
      primaryAction: { id: '', selfProtection: '' },
      rowActions: [{ id: 'delete', selfProtection: 'system-resource' }],
      read: base.read === null ? null : { ...base.read, fields: [...base.read.fields, 'AllowDelete'] },
    });
    TestBed.inject(ScreenActions).register('OcuPilot.Screen.Descriptor.ResourceList', 'delete', () => {});
    const store = TestBed.inject(ScreenStores).for('OcuPilot.Screen.Descriptor.ResourceList', navigation.current.refreshRates);
    store.applyTick([{ Name: 'alpha', NameSpace: 'USER', Count: 0, Enabled: true, Note: 'n', AllowDelete: false }], false, '', new Date());
    store.setSelection(['alpha']);
    chord();
    const entry = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-command-box-group-actions [role="option"]')
    ).find(
      (option) =>
        (option as HTMLElement).querySelector('.ocu-command-box-option-label')?.textContent?.trim() ===
        STRINGS.actionDelete
    ) as HTMLElement | undefined;
    expect(entry?.textContent).toContain(STRINGS.resourceRefusalSystem);
    expect(entry?.getAttribute('aria-disabled')).toBe('true');
  });

  it('DW-389: a declared row action with no registered handler is not listed, beside one that is registered', () => {
    // Per action, not all-or-nothing: the stub screen registers `delete` (beforeEach) and nothing
    // for `enable`, which it declares beside it.
    //
    // Mutation (Rule 19): drop `&& this.actions.has(screen.descriptor, action.id)` from the row-action
    // loop in `command-box.ts` -> `enable` is listed beside `delete`, red.
    navigation.current = screen('permissions/users', 'navAreaPermissions', 'permissions', {
      primaryAction: { id: '', selfProtection: '' },
      rowActions: [
        { id: 'enable', selfProtection: '' },
        { id: 'delete', selfProtection: 'current-user' },
      ],
    });
    chord();
    const labels = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-command-box-group-actions [role="option"]')
    ).map((option) => (option as HTMLElement).querySelector('.ocu-command-box-option-label')?.textContent?.trim());
    expect(labels).toEqual([STRINGS.actionDelete]);
    expect(count()).toBe('2 screens, 1 actions');
  });

  it("DW-370: a screen's own published words for an action reach the box's option, not only the bar's button", () => {
    // `command-bar.spec.ts` pins the bar; this is the other surface `actionLabel` was given a
    // descriptor for. Every other case here uses the stub descriptor, which publishes nothing of
    // its own, so they resolve identically with or without descriptor scoping -- and the box's two
    // call sites could be reverted with the whole suite green.
    //
    // Mutation (Rule 19): change `actionLabel(screen.descriptor, action.id)` in `command-box.ts`
    // to `actionLabel('', action.id)` -> this goes red, the option drawing the bare id.
    navigation.current = screen('agent/switches', 'navAreaAgent', 'agent', {
      descriptor: 'OcuPilot.Screen.Descriptor.AgentSwitches',
      primaryAction: { id: '', selfProtection: '' },
      rowActions: [{ id: 'delete', selfProtection: '' }],
    });
    chord();
    const labels = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-command-box-group-actions [role="option"]')
    ).map((option) =>
      (option as HTMLElement).querySelector('.ocu-command-box-option-label')?.textContent?.trim()
    );
    expect(labels).toEqual([STRINGS.agentSwitchesHoldRemove]);
    // The same id on a screen that publishes nothing for it still draws the bare id, so the
    // assertion above is about the descriptor rather than about the id.
    expect(STRINGS.agentSwitchesHoldRemove).not.toBe('delete');
  });

  it('a primary action with no registered handler is not listed', () => {
    unregisterCreate();
    chord();
    const labels = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-command-box-group-actions [role="option"]')
    ).map((option) => (option as HTMLElement).querySelector('.ocu-command-box-option-label')?.textContent?.trim());
    expect(labels).toEqual([STRINGS.actionDelete]);
    expect(count()).toBe('2 screens, 1 actions');
  });

  it('choosing a registered primary action runs it once and closes the box, and unregistering removes the row', () => {
    const create = (): HTMLElement | null =>
      fixture.nativeElement.querySelector('#ocu-command-box-action-create');

    chord();
    create()?.click();
    fixture.detectChanges();
    expect(creates).toBe(1);
    expect(field().getAttribute('aria-expanded')).toBe('false');

    chord();
    expect(create()).not.toBeNull();
    unregisterCreate();
    fixture.detectChanges();
    expect(create()).toBeNull();
    expect(creates).toBe(1);
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

  it('a pointerdown outside closes it, without taking focus back', () => {
    const opener = document.createElement('button');
    const target = document.createElement('button');
    document.body.append(opener, target);
    planted.push(opener, target);
    opener.focus();

    chord();
    expect(field().getAttribute('aria-expanded')).toBe('true');
    expect(overlays.top()).toBe(COMMAND_BOX_OVERLAY_ID);

    // The gesture lands on a THIRD element, not on the one the box was opened from -- that
    // separation is what makes the focus claim falsifiable. Escape restores focus to the
    // opener and should; a dismissal must not, because the user has already chosen where
    // focus goes (DW-109's rule). Dropping `returnFocus = null` from `onOutside` yanks focus
    // back to `opener` and turns the last assertion red.
    target.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
    fixture.detectChanges();

    expect(field().getAttribute('aria-expanded')).toBe('false');
    expect(listbox()).toBeNull();
    expect(overlays.ids()).toEqual([]);
    expect(document.activeElement).not.toBe(opener);
  });

  it('focus moving outside closes it too, and a pointerdown inside it does not', () => {
    const elsewhere = document.createElement('button');
    document.body.appendChild(elsewhere);
    planted.push(elsewhere);

    chord();
    // Inside the box first: the field's own click opens it, so an inside gesture that closed
    // it would make the box impossible to use with a pointer.
    field().dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
    fixture.detectChanges();
    expect(field().getAttribute('aria-expanded')).toBe('true');

    elsewhere.dispatchEvent(new FocusEvent('focusin', { bubbles: true }));
    fixture.detectChanges();
    expect(field().getAttribute('aria-expanded')).toBe('false');
    expect(overlays.ids()).toEqual([]);
  });

  it('Enter in the collapsed field navigates nowhere: nothing is bound while the sheet is shut', async () => {
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/logs/messages');
    fixture.detectChanges();

    // Tab reaches the field without opening the box -- it opens on click and on the chord,
    // not on focus -- and the candidate list at an empty query is the whole roster, so an
    // unguarded Enter would have opened whichever screen happens to be first.
    expect(field().getAttribute('aria-expanded')).toBe('false');
    field().focus();
    field().dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await fixture.whenStable();
    fixture.detectChanges();

    expect(router.url).toBe('/logs/messages');
    expect(field().getAttribute('aria-expanded')).toBe('false');
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

  // --- Story 15.2: menu search is this box, and only its ranking moves ------------------------

  it('Story 15.2: a favorited screen is listed first within Screens, and nothing else about the box moves', async () => {
    // Declaration order is USERS then LOGS; pinning the second puts it first.
    await accountPreferences.add('favorite', 'logs/messages');
    fixture.detectChanges();
    chord();

    const groups = fixture.nativeElement.querySelectorAll('[role="group"]');
    expect(groups).toHaveLength(2);
    const screens: HTMLElement[] = Array.from(groups[0].querySelectorAll('[role="option"]'));
    expect(screens).toHaveLength(2);
    expect(screens[0].textContent).toContain(STRINGS.navAreaLogs);
    expect(screens[1].textContent).toContain(STRINGS.navAreaPermissions);

    // One input, two groups, the same count sentence: the ranking is the only change.
    expect(fixture.nativeElement.querySelectorAll('input')).toHaveLength(1);
    expect(count()).toBe('2 screens, 2 actions');
  });

  it('Story 15.2: with nothing pinned, the Screens group keeps the declaration order', () => {
    chord();
    const screens: HTMLElement[] = Array.from(
      fixture.nativeElement.querySelectorAll('[role="group"]')[0].querySelectorAll('[role="option"]')
    );
    expect(screens[0].textContent).toContain(STRINGS.navAreaPermissions);
    expect(screens[1].textContent).toContain(STRINGS.navAreaLogs);
  });

  it('Story 15.2 (AD-37): a favorite naming no built screen adds no row here, and the count is unchanged', async () => {
    // The stored row survives on the instance; what it cannot do is put an option in this box.
    // Rows come from the navigation roster alone -- a favorite only partitions them -- so a route
    // the roster does not hold has nothing to rank.
    await accountPreferences.add('favorite', 'no-such-area/no-such-screen');
    fixture.detectChanges();
    chord();

    expect(accountPreferences.favorites()).toEqual(['no-such-area/no-such-screen']);
    const screens: HTMLElement[] = Array.from(
      fixture.nativeElement.querySelectorAll('[role="group"]')[0].querySelectorAll('[role="option"]')
    );
    expect(screens).toHaveLength(2);
    expect(screens[0].textContent).toContain(STRINGS.navAreaPermissions);
    expect(count()).toBe('2 screens, 2 actions');
  });

  // Story 15.9 (AD-28, AD-31). Mutation (Rule 19): drop the Sign out row -> the typed-needle leg and
  // the choose leg go red.
  it('Story 15.9: a typed needle lists Sign out last among the actions; an empty query does not', () => {
    chord();
    expect(fixture.nativeElement.querySelector('#ocu-command-box-account-sign-out')).toBeNull();
    expect(count()).toBe('2 screens, 2 actions');

    type('sign out');
    const actionRows: HTMLElement[] = Array.from(
      fixture.nativeElement.querySelectorAll('[role="group"]')[1].querySelectorAll('[role="option"]')
    );
    expect(actionRows[actionRows.length - 1].id).toBe('ocu-command-box-account-sign-out');
    expect(actionRows[actionRows.length - 1].textContent?.trim()).toBe(STRINGS.actionSignOut);

    type('');
    expect(fixture.nativeElement.querySelector('#ocu-command-box-account-sign-out')).toBeNull();
    expect(count()).toBe('2 screens, 2 actions');
  });

  // Mutation (Rule 19): list the account row before the actions -> red.
  it('Story 15.9: a needle that also matches the screen\'s actions lists Sign out after them', () => {
    chord();
    type('t');
    const actionRows: HTMLElement[] = Array.from(
      fixture.nativeElement.querySelectorAll('[role="group"]')[1].querySelectorAll('[role="option"]')
    );
    expect(actionRows.length).toBeGreaterThan(1);
    expect(actionRows[actionRows.length - 1].id).toBe('ocu-command-box-account-sign-out');
  });

  // Mutation (Rule 19): drop the `this.session === null` guard -> red.
  it('Story 15.9: with no Session injected there is no Sign out row', () => {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: AccountPreferences, useValue: accountPreferences },
        { provide: ScreenStores, useValue: new ScreenStores({ account: accountPreferences }) },
        provideRouter([{ path: '', children: [] }]),
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: OverlayStack, useValue: overlays },
        { provide: ScreenActions, useValue: actions },
        { provide: ShellState, useValue: shell },
      ],
    });
    fixture = TestBed.createComponent(CommandBox);
    fixture.detectChanges();
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    chord();
    type('sign out');
    expect(fixture.nativeElement.querySelector('#ocu-command-box-account-sign-out')).toBeNull();
  });

  it('Story 15.9: choosing Sign out closes the box and calls Session.signOut once', () => {
    chord();
    type('sign out');
    const row = fixture.nativeElement.querySelector('#ocu-command-box-account-sign-out') as HTMLElement;
    expect(field().getAttribute('aria-activedescendant')).toBe(row.id);
    field().dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    fixture.detectChanges();

    expect(signOuts).toBe(1);
    expect(field().getAttribute('aria-expanded')).toBe('false');
    expect(listbox()).toBeNull();
  });

  it('Story 15.2: the ranking survives a filter, and the count still reports what is listed', async () => {
    await accountPreferences.add('favorite', 'logs/messages');
    fixture.detectChanges();
    chord();
    type('a');

    expect(count()).toBe('2 screens, 1 actions');
    expect(options()[0].textContent).toContain(STRINGS.navAreaLogs);
  });
});

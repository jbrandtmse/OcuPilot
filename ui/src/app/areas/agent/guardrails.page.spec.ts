import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { describe, expect, it } from 'vitest';

import type { ApiService } from '../../core/api';
import { ConnectivityService } from '../../core/connectivity';
import { Guardrails } from '../../core/guardrails';
import { NavigationService, screenForDescriptor } from '../../core/navigation';
import { ShellState } from '../../core/shell-state';
import { STRINGS, stringFor } from '../../core/strings';
import { guardrailsBody, stubGuardrails, type StubbedGuardrails } from '../../testing/guardrails';
import { GuardrailsPage } from './guardrails.page';

/**
 * The Guardrails screen over a stubbed `GET /ui/guardrails` and the real store: the five sections in
 * page order, the refused rows exactly as answered, the Confirm groups under their screens' labels,
 * the three kill-switch lines, and no section when the read fails. A transport fault or a 5xx adds no
 * alert, since the shell's banner says it; any other failure is `FaultBanner`'s in-place alert with
 * Retry.
 */

/** The members the in-place banner reads from the shell; none of them is about this page. */
class StubNavigation {
  builtScreens(): readonly never[] {
    return [];
  }

  screenVerdict(): { allowed: boolean; failedPair: string } {
    return { allowed: true, failedPair: '' };
  }

  subscribe(): () => void {
    return () => {};
  }
}

class StubShell {
  showArea(): void {}
}

/** The real connectivity service with no probe timer, so a parked read runs when a spec says an answer arrived. */
function quietConnectivity(): ConnectivityService {
  return new ConnectivityService({ api: () => ({}) as unknown as ApiService, schedule: () => {} });
}

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(
  store: StubbedGuardrails,
  connectivity: ConnectivityService = quietConnectivity()
): Promise<{ fixture: ComponentFixture<GuardrailsPage>; root: HTMLElement }> {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([]),
      { provide: Guardrails, useValue: store },
      { provide: ConnectivityService, useValue: connectivity },
      { provide: NavigationService, useValue: new StubNavigation() as unknown as NavigationService },
      { provide: ShellState, useValue: new StubShell() as unknown as ShellState },
    ],
  });
  const fixture = TestBed.createComponent(GuardrailsPage);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, root: fixture.nativeElement as HTMLElement };
}

const texts = (root: HTMLElement, selector: string): string[] =>
  [...root.querySelectorAll(selector)].map((element) => (element.textContent ?? '').replace(/\s+/g, ' ').trim());

describe('GuardrailsPage', () => {
  it('reads its answer on open and lists the five sections in page order', async () => {
    const store = stubGuardrails();
    const { root } = await mount(store);
    expect(store.calls.map((call) => call.path)).toEqual(['/api/ocupilot/ui/guardrails']);
    expect(texts(root, '.ocu-guardrails-intro')).toEqual([STRINGS.agentGuardrailsIntro]);
    expect(texts(root, 'h2')).toEqual([
      STRINGS.agentGuardrailsRefusedHeading,
      STRINGS.agentSwitchesLabel,
      STRINGS.agentGuardrailsConfirmHeading,
      STRINGS.agentGuardrailsNeverHeading,
      STRINGS.agentGuardrailsLimitsHeading,
    ]);
    expect(root.querySelector('[role="alert"]')).toBeNull();
    expect(root.querySelector('.ocu-guardrails')?.getAttribute('aria-busy')).toBe('false');
  });

  it('is busy while its read is pending, and not once it lands', async () => {
    // Mutation (Rule 19): `busy` answers false whatever the store's `loading()` reads -> this goes red.
    let release: (value: unknown) => void = () => undefined;
    const pending = new Promise((resolve) => {
      release = resolve;
    });
    const store = new Guardrails({ api: { requestJson: () => pending } as unknown as ApiService });
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({ providers: [{ provide: Guardrails, useValue: store }] });
    const fixture = TestBed.createComponent(GuardrailsPage);
    fixture.detectChanges();
    const root = fixture.nativeElement as HTMLElement;
    expect(root.querySelector('.ocu-guardrails')?.getAttribute('aria-busy')).toBe('true');
    expect(root.querySelector('[role="alert"]')).toBeNull();
    expect(root.querySelectorAll('h2').length).toBe(0);
    release({ kind: 'ok', status: 200, body: guardrailsBody() });
    await settle(fixture);
    expect(root.querySelector('.ocu-guardrails')?.getAttribute('aria-busy')).toBe('false');
    expect(root.querySelectorAll('h2').length).toBe(5);
  });

  it('renders each refused row as the answer gives it, in its order, and holds no sentence of its own', async () => {
    // Mutation (Rule 19): render a constant list in place of `prohibited` -> this goes red.
    const body = guardrailsBody();
    body['prohibited'] = [
      { code: 'PROBE.B', reason: 'Answered second-first.' },
      { code: 'PROBE.A', reason: 'Answered <b>as text</b>.' },
    ];
    const { root } = await mount(stubGuardrails({ body }));
    expect(texts(root, '.ocu-guardrails-refused .ocu-guardrails-reason')).toEqual(['Answered second-first.', 'Answered <b>as text</b>.']);
    expect(texts(root, '.ocu-guardrails-refused .ocu-guardrails-code')).toEqual(['PROBE.B', 'PROBE.A']);
    expect(root.querySelector('.ocu-guardrails-refused b')).toBeNull();
  });

  it('groups the Confirm tools under their screens\' labels, with an unmirrored descriptor last and unheaded', async () => {
    const body = guardrailsBody();
    body['confirmTools'] = [
      { name: 'permissions.users.delete', descriptor: 'OcuPilot.Screen.Descriptor.UserList' },
      { name: 'probe.unknown.write', descriptor: 'OcuPilot.Screen.Descriptor.NoSuchScreen' },
      { name: 'permissions.users.password', descriptor: 'OcuPilot.Screen.Descriptor.UserList' },
    ];
    const { root } = await mount(stubGuardrails({ body }));
    const users = screenForDescriptor('OcuPilot.Screen.Descriptor.UserList');
    expect(users).not.toBeNull();
    expect(texts(root, '.ocu-guardrails-group-heading')).toEqual([stringFor(users?.labelKey ?? '')]);
    const groups = [...root.querySelectorAll('.ocu-guardrails-group')].map((group) => texts(group as HTMLElement, 'code'));
    expect(groups).toEqual([['permissions.users.delete', 'permissions.users.password'], ['probe.unknown.write']]);
    expect(texts(root, '.ocu-guardrails-secrets .ocu-guardrails-item')).toEqual(['permissions.users.password: Password']);
  });

  it('lists every secret field of a tool, in order', async () => {
    // Mutation (Rule 19): render only each tool's first field -> this goes red.
    const body = guardrailsBody();
    body['secrets'] = [
      { tool: 'permissions.users.password', fields: ['Password'] },
      { tool: 'probe.multi', fields: ['First', 'Second', 'Third'] },
    ];
    const { root } = await mount(stubGuardrails({ body }));
    expect(texts(root, '.ocu-guardrails-secrets .ocu-guardrails-item')).toEqual([
      'permissions.users.password: Password',
      'probe.multi: First, Second, Third',
    ]);
  });

  it('draws the three kill-switch lines and the read-only line from the caller\'s verdict', async () => {
    const cases: [Record<string, unknown>, string, string][] = [
      [{ killSwitch: false, killSwitchAudience: '', enforcedReadOnly: false }, STRINGS.agentGuardrailsKillSwitchOff, STRINGS.agentGuardrailsReadOnlyOff],
      [{ killSwitch: true, killSwitchAudience: 'everyone', enforcedReadOnly: false }, STRINGS.agentGuardrailsKillSwitchEveryone, STRINGS.agentGuardrailsReadOnlyOff],
      [{ killSwitch: true, killSwitchAudience: 'you', enforcedReadOnly: true }, STRINGS.agentGuardrailsKillSwitchYou, STRINGS.agentGuardrailsReadOnlyOn],
    ];
    for (const [switches, killLine, readOnly] of cases) {
      const body = guardrailsBody();
      body['switches'] = switches;
      const { root } = await mount(stubGuardrails({ body }));
      expect(texts(root, '.ocu-guardrails-kill-switch')).toEqual([killLine]);
      expect(texts(root, '.ocu-guardrails-read-only')).toEqual([readOnly]);
    }
  });

  it('prints the limits line with each number grouped', async () => {
    const body = guardrailsBody();
    body['limits'] = { contextRowCap: 150, totalMaxLength: 65536, fieldMaxLength: 1000, turnsPerHour: 0 };
    const { root } = await mount(stubGuardrails({ body }));
    const [line] = texts(root, '.ocu-guardrails-limits');
    expect(line).toContain('150');
    expect(line).toContain('65,536');
    expect(line).toContain('1,000');
  });

  it('reads one row of the screen in the singular when the context cap is one', async () => {
    // Mutation (Rule 19): fill `STRINGS.agentGuardrailsContextLimits` alone in `limitsLine` -> this goes red.
    const body = guardrailsBody();
    body['limits'] = { contextRowCap: 1, totalMaxLength: 65536, fieldMaxLength: 1000, turnsPerHour: 0 };
    const { root } = await mount(stubGuardrails({ body }));
    const [line] = texts(root, '.ocu-guardrails-limits');
    expect(line).toContain('at most 1 row of the screen');
  });

  it('names the turns an hour in force below the limits line, and no limit at 0', async () => {
    // Mutation (Rule 19): remove the page's `.ocu-guardrails-turns` line -> both legs go red.
    for (const [turnsPerHour, line] of [
      [0, STRINGS.agentGuardrailsTurnsNone],
      [1, STRINGS.agentGuardrailsTurnsLimitOne],
      [7, STRINGS.agentGuardrailsTurnsLimit.replace('<n>', '7')],
      [1200, STRINGS.agentGuardrailsTurnsLimit.replace('<n>', '1,200')],
    ] as const) {
      const body = guardrailsBody();
      body['limits'] = { contextRowCap: 200, totalMaxLength: 65536, fieldMaxLength: 1000, turnsPerHour };
      const { root } = await mount(stubGuardrails({ body }));
      expect(texts(root, '.ocu-guardrails-turns')).toEqual([line]);
      const section = root.querySelector('.ocu-guardrails-limits')?.parentElement;
      expect(section?.querySelector('.ocu-guardrails-limits + .ocu-guardrails-turns') ?? null).not.toBeNull();
    }
  });

  // Mutation (Rule 19): make `inPlaceFault` answer the banner fault too -> the status 0 and 503 legs go
  // red, the page drawing an alert of its own beside the shell's banner.
  it('draws no alert and no section when the instance is unreachable or answers a 5xx, and reads again once it answers', async () => {
    for (const status of [0, 503]) {
      const connectivity = quietConnectivity();
      const store = stubGuardrails({ connectivity });
      store.setStatus(status);
      const { fixture, root } = await mount(store, connectivity);
      expect(store.fault()?.kind, `status ${status}`).toBe(status === 0 ? 'unreachable' : 'server-fault');
      expect(root.querySelector('[role="alert"]'), `status ${status} adds no alert of its own`).toBeNull();
      expect(root.querySelector('app-fault-banner .ocu-fault-banner')).toBeNull();
      expect(root.querySelectorAll('h2').length).toBe(0);
      expect(root.querySelector('.ocu-guardrails-refused')).toBeNull();

      // The instance answers again: the shell's drain runs the parked read and the sections replace the empty page.
      store.setStatus(null);
      connectivity.note(null);
      await settle(fixture);
      expect(store.calls.length, `status ${status} is read again`).toBe(2);
      expect(root.querySelectorAll('h2').length).toBe(5);
      expect(root.querySelector('[role="alert"]')).toBeNull();
    }
  });

  // Mutation (Rule 19): record an unreadable answer as `server-fault` in `Guardrails.load` -> the unreadable leg
  // goes red, the page drawing nothing; make `inPlaceFault` answer `null` for every fault -> the 404 leg goes red.
  it('draws the in-place banner with Retry for a 403, a 404 and an unreadable answer, and Retry reads again', async () => {
    const cases: [string, (store: StubbedGuardrails) => void][] = [
      ['403', (store) => store.setStatus(403)],
      ['404', (store) => store.setStatus(404)],
      ['unreadable', (store) => store.setBody({ prohibited: 'not a list' })],
    ];
    for (const [name, arm] of cases) {
      const store = stubGuardrails();
      arm(store);
      const { fixture, root } = await mount(store);
      const alerts = [...root.querySelectorAll('[role="alert"]')];
      expect(alerts.length, `${name}: one alert, the banner's own`).toBe(1);
      expect(alerts[0].querySelector('.ocu-fault-banner-message')?.textContent?.trim(), name).toBe(STRINGS.connectivityServerFault);
      const actions = [...alerts[0].querySelectorAll('button')].map((button) => button.textContent?.trim());
      expect(actions, name).toEqual([STRINGS.actionRetry, STRINGS.actionOpenMessagesLog]);
      expect(root.querySelectorAll('h2').length, `${name}: no section beside it`).toBe(0);

      // The instance answers again; Retry reads again and the sections replace the alert.
      store.setStatus(null);
      store.setBody(guardrailsBody());
      (alerts[0].querySelector('button') as HTMLButtonElement).click();
      await settle(fixture);
      expect(store.calls.length, `${name}: Retry reads again`).toBe(2);
      expect(root.querySelector('[role="alert"]'), name).toBeNull();
      expect(root.querySelectorAll('h2').length, name).toBe(5);
    }
  });
});

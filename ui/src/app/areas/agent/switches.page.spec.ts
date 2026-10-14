import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { SwitchesPage } from './switches.page';

/**
 * The Switches screen over a stub of the one thing an instance supplies -- the HTTP answers. The
 * real store, the real `FormDirty`, the real dialog and the real template run, so the assertions
 * are about rendered DOM rather than about store state (AC6, AC7).
 */

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** One answer per request; the stub is the only transport in the fixture. */
type Answer = (path: string, init: { method?: string; body?: string }) => JsonResult<unknown>;

const ok = (body: unknown): JsonResult<unknown> => ({ kind: 'ok', status: 200, body });

const created = (body: unknown): JsonResult<unknown> => ({ kind: 'ok', status: 201, body });

const refused = (violations: unknown[]): JsonResult<unknown> => ({
  kind: 'error',
  status: 422,
  code: 'AGENT.VALIDATION',
  reason: 'The agent switches were refused',
  detail: { violations },
});

const forbidden = (): JsonResult<unknown> => ({
  kind: 'error',
  status: 403,
  code: 'AUTH.NOPRIVILEGE',
  reason: 'This account does not hold the privilege this request requires.',
  detail: { failedPair: 'OcuPilotAdmin:USE' },
});

/** The server-authored reason `STATE.CONFLICT` carries, which this screen must never render. */
const CONFLICT_ENVELOPE_REASON =
  'This record changed on the instance after it was read, so the save was refused.';

const conflicted = (): JsonResult<unknown> => ({
  kind: 'error',
  status: 409,
  code: 'STATE.CONFLICT',
  reason: CONFLICT_ENVELOPE_REASON,
  detail: null,
});

const EGRESS_PATH = '/api/ocupilot/agent/switches/egress';

/** The provider connection as `GET /agent/switches/egress` answers it (Story 18.40). */
const connection = (overrides: Record<string, unknown> = {}) => ({
  proxyServer: '',
  proxyPort: 0,
  sslConfiguration: '',
  rowVersion: 0,
  ...overrides,
});

const switches = (overrides: Record<string, unknown> = {}) => ({
  killSwitch: false,
  killSwitchReason: '',
  enforcedReadOnly: false,
  shareContextByDefault: true,
  contextRowCap: 200,
  turnsPerHour: 0,
  concurrentTurns: 1,
  updatedAt: '',
  holds: [],
  ...overrides,
});

async function mount(answer: Answer) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(
      path: string,
      init: { method?: string; body?: string } = {}
    ): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return answer(path, init) as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/agent/switches');
  const fixture = TestBed.createComponent(SwitchesPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, events, formDirty, host: fixture.nativeElement as HTMLElement };
}

function input(host: HTMLElement, id: string): HTMLInputElement {
  return host.querySelector(`#${id}`) as HTMLInputElement;
}

function tick(element: HTMLInputElement, checked: boolean): void {
  element.checked = checked;
  element.dispatchEvent(new Event('change'));
}

function type(element: HTMLInputElement, value: string): void {
  element.value = value;
  element.dispatchEvent(new Event('input'));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('the Switches screen', () => {
  it('AC7: renders the published copy for every control it draws, from the stored switches', async () => {
    // Mutation (Rule 19): render the request's own values rather than the answer's -> the flags
    // below still pass, but the save assertion further down goes red.
    const { host } = await mount(() =>
      ok(switches({ killSwitch: true, killSwitchReason: 'Paused for the change freeze' }))
    );

    expect(host.textContent).toContain(STRINGS.agentSwitchesKillSwitch);
    expect(host.textContent).toContain(STRINGS.agentSwitchesEnforcedReadOnly);
    expect(host.textContent).toContain(STRINGS.agentSwitchesShareContext);
    expect(host.textContent).toContain(STRINGS.agentSwitchesHoldsHeading);
    expect(host.textContent).toContain(STRINGS.agentSwitchesHoldsEmpty);
    expect(host.textContent).toContain(STRINGS.agentSwitchesHoldAdd);
    expect(host.textContent).toContain(STRINGS.formRequiredFieldsLegend);

    expect(input(host, 'ocu-switches-kill').checked).toBe(true);
    expect(input(host, 'ocu-switches-read-only').checked).toBe(false);
    expect(input(host, 'ocu-switches-share-context').checked).toBe(true);
    expect(input(host, 'ocu-switches-killSwitchReason').value).toBe('Paused for the change freeze');
    // The reason is required only while the switch is on, which is the rule the server applies.
    expect(input(host, 'ocu-switches-killSwitchReason').getAttribute('aria-required')).toBe('true');
  });

  it('AC7: Save sends the whole writable set, renders the answer, and publishes the change event', async () => {
    // Mutation (Rule 19): drop `publishChange()` from `save()` -> the event assertion goes red,
    // and the panel's banners keep standing over a switch that has been turned off (AD-14).
    const { fixture, host, calls, events } = await mount((path, init) => {
      if (init.method === 'PUT') {
        return ok(switches({ enforcedReadOnly: true, shareContextByDefault: false }));
      }
      return ok(switches());
    });

    tick(input(host, 'ocu-switches-read-only'), true);
    tick(input(host, 'ocu-switches-share-context'), false);
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);

    const put = calls.find((call) => call.method === 'PUT');
    expect(put?.path).toBe('/api/ocupilot/agent/switches');
    const body = JSON.parse(put?.body ?? '{}');
    // Every writable field, always -- a partial body would leave the server merging over values
    // the operator can see on screen (AD-4).
    expect(Object.keys(body).sort()).toEqual([
      'contextRowCap',
      'enforcedReadOnly',
      'killSwitch',
      'killSwitchReason',
      'shareContextByDefault',
      'turnsPerHour',
    ]);
    expect(body.enforcedReadOnly).toBe(true);
    expect(body.shareContextByDefault).toBe(false);

    expect(events.map((event) => `${event.kind}:${event.type}`)).toContain('changed:agent-switch');
  });

  it('Story 4.4: the context row cap renders the stored value and round-trips as a number', async () => {
    const { fixture, host, calls } = await mount((path, init) => {
      if (init.method === 'PUT') {
        return ok(switches({ contextRowCap: 500 }));
      }
      return ok(switches({ contextRowCap: 200 }));
    });

    // The stored value renders on load.
    expect(input(host, 'ocu-switches-contextRowCap').value).toBe('200');

    type(input(host, 'ocu-switches-contextRowCap'), '500');
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);

    const put = calls.find((call) => call.method === 'PUT');
    const body = JSON.parse(put?.body ?? '{}');
    // Sent as a JSON number, not the string the input control holds (AD-4).
    expect(body.contextRowCap).toBe(500);
    expect(typeof body.contextRowCap).toBe('number');
    expect(input(host, 'ocu-switches-contextRowCap').value).toBe('500');
  });

  it('Story 14.6: turns an hour renders the stored value, is described by its hint, and round-trips as a number', async () => {
    const { fixture, host, calls } = await mount((path, init) => {
      if (init.method === 'PUT') {
        return ok(switches({ turnsPerHour: 3 }));
      }
      return ok(switches());
    });
    const field = input(host, 'ocu-switches-turnsPerHour');
    expect(field.value).toBe('0');
    expect(field.getAttribute('min')).toBe('0');
    expect(field.getAttribute('max')).toBe('10000');
    expect(host.querySelector(`label[for="ocu-switches-turnsPerHour"]`)?.textContent?.trim()).toBe(
      STRINGS.agentSwitchesTurnsPerHour
    );
    const hint = host.querySelector('#ocu-switches-turnsPerHour-hint') as HTMLElement;
    expect(hint.textContent?.trim()).toBe(STRINGS.agentSwitchesTurnsPerHourHint);
    expect(field.getAttribute('aria-describedby')).toBe('ocu-switches-turnsPerHour-hint');

    type(field, '3');
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);

    const body = JSON.parse(calls.find((call) => call.method === 'PUT')?.body ?? '{}');
    expect(body.turnsPerHour).toBe(3);
    expect(typeof body.turnsPerHour).toBe('number');
    expect(input(host, 'ocu-switches-turnsPerHour').value).toBe('3');
  });

  it('Story 14.6: a turns-an-hour refusal renders on its own field, after its hint', async () => {
    const { fixture, host } = await mount((path, init) => {
      if (init.method === 'PUT') {
        return refused([
          {
            field: 'turnsPerHour',
            code: 'AGENT.SWITCH.TURNSPERHOUR',
            reason: 'Agent turns per user an hour is a whole number from 0 to 10,000, where 0 means no limit.',
          },
        ]);
      }
      return ok(switches());
    });
    type(input(host, 'ocu-switches-turnsPerHour'), '10001');
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    const field = input(host, 'ocu-switches-turnsPerHour');
    expect(field.getAttribute('aria-invalid')).toBe('true');
    expect(field.getAttribute('aria-describedby')).toBe(
      'ocu-switches-turnsPerHour-hint ocu-switches-turnsPerHour-reason'
    );
  });

  it('Story 14.6: the concurrent bound is a read-only control showing the stored value, described by its reason, and never sent', async () => {
    // Mutation (Rule 19): drop `readonly` from the concurrent input -> the first assertion goes red.
    const { fixture, host, calls } = await mount((path, init) => {
      if (init.method === 'PUT') return ok(switches());
      return ok(switches());
    });
    const field = input(host, 'ocu-switches-concurrentTurns');
    expect(field.readOnly).toBe(true);
    expect(field.value).toBe('1');
    expect(host.querySelector(`label[for="ocu-switches-concurrentTurns"]`)?.textContent?.trim()).toBe(
      STRINGS.agentSwitchesConcurrentTurns
    );
    expect(field.getAttribute('aria-describedby')).toBe('ocu-switches-concurrentTurns-reason');
    expect(
      (host.querySelector('#ocu-switches-concurrentTurns-reason') as HTMLElement).textContent?.trim()
    ).toBe(STRINGS.agentSwitchesConcurrentTurnsReason);

    type(input(host, 'ocu-switches-turnsPerHour'), '2');
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    const put = calls.find((call) => call.method === 'PUT');
    expect(put).toBeDefined();
    expect('concurrentTurns' in JSON.parse(put?.body ?? '{}')).toBe(false);
  });

  it('Story 4.4: a row-cap refusal renders on its own field, not the reason field', async () => {
    // Mutation (Rule 19): render every violation on the same field id -> this goes red, since the
    // row-cap sentence would then appear beside killSwitchReason instead of contextRowCap.
    const { fixture, host } = await mount((path, init) => {
      if (init.method === 'PUT') {
        return refused([
          {
            field: 'contextRowCap',
            code: 'AGENT.SWITCH.CONTEXTROWCAP',
            reason: 'Context rows sent with a turn is a whole number from 1 to 1,000.',
          },
        ]);
      }
      return ok(switches());
    });

    type(input(host, 'ocu-switches-contextRowCap'), '5000');
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);

    const field = input(host, 'ocu-switches-contextRowCap');
    expect(field.getAttribute('aria-invalid')).toBe('true');
    expect(
      (host.querySelector('#ocu-switches-contextRowCap-reason') as HTMLElement).textContent
    ).toContain('Context rows sent with a turn is a whole number from 1 to 1,000.');
  });

  it('AC7: a refused save renders the violation on the field the server named, in the summary and beside the control', async () => {
    // Mutation (Rule 19): render a client-composed sentence instead of the violation's own ->
    // this goes red, because the text asserted is the server's (AD-39).
    const { fixture, host } = await mount((path, init) => {
      if (init.method === 'PUT') {
        return refused([
          {
            field: 'killSwitchReason',
            code: 'AGENT.SWITCH.REASONREQUIRED',
            reason: 'Give a reason for switching the agent off. Everyone it affects is shown it.',
          },
        ]);
      }
      return ok(switches());
    });

    tick(input(host, 'ocu-switches-kill'), true);
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);

    const summary = host.querySelector('.ocu-form-summary') as HTMLElement;
    expect(summary).not.toBeNull();
    expect(summary.getAttribute('role')).toBe('alert');
    expect(summary.textContent).toContain('Give a reason for switching the agent off.');

    const field = input(host, 'ocu-switches-killSwitchReason');
    expect(field.getAttribute('aria-invalid')).toBe('true');
    expect(field.getAttribute('aria-describedby')).toBe('ocu-switches-killSwitchReason-reason');
    expect(
      (host.querySelector('#ocu-switches-killSwitchReason-reason') as HTMLElement).textContent
    ).toContain('Give a reason for switching the agent off.');
  });

  it('AC6: a privilege refusal renders the published denied-action sentence with this screen\'s own phrase', async () => {
    // Mutation (Rule 19): render the envelope's reason unconditionally -> this goes red on the
    // resource and on the action phrase.
    const { host } = await mount(() => forbidden());
    const banner = host.querySelector('.ocu-banner-warning') as HTMLElement;
    expect(banner).not.toBeNull();
    expect(banner.getAttribute('role')).toBe('alert');
    expect(banner.textContent).toContain('OcuPilotAdmin:USE');
    expect(banner.textContent).toContain(STRINGS.agentSwitchesRefusedAction);
  });

  it("DW-388: a save whose row moved renders the published conflict sentence, not the envelope's reason", async () => {
    // Mutation (Rule 19): drop the `conflicted()` test from `reason` in `switches.page.ts`, or
    // make `SwitchesStore.conflicted()` answer false -> this goes red, and the screen states the
    // server's mechanism where the published sentence names the reload the person has to make.
    const { fixture, host } = await mount((path, init) => {
      if (init.method === 'PUT') return conflicted();
      return ok(switches());
    });

    tick(input(host, 'ocu-switches-read-only'), true);
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);

    const banner = host.querySelector('.ocu-banner-warning') as HTMLElement;
    expect(banner).not.toBeNull();
    expect(banner.getAttribute('role')).toBe('alert');
    expect(banner.textContent?.trim()).toBe(STRINGS.formStaleSave);
    expect(banner.textContent).not.toContain(CONFLICT_ENVELOPE_REASON);
  });

  it('DW-425: a save sends the row version the screen read, takes the one each answer carries, and keeps it after a stale refusal', async () => {
    // Mutation (Rule 19): drop `rowVersion` from `SwitchesStore.body()` -> the first expectation
    // goes red; take the version from a refusal as well as from an answer -> the last goes red.
    let puts = 0;
    const { fixture, host, calls } = await mount((path, init) => {
      if (init.method === 'PUT') {
        puts += 1;
        return puts === 1 ? ok(switches({ enforcedReadOnly: true, rowVersion: 4 })) : conflicted();
      }
      return ok(switches({ rowVersion: 3 }));
    });
    const sentVersions = () =>
      calls.filter((call) => call.method === 'PUT').map((call) => JSON.parse(call.body)['rowVersion']);

    tick(input(host, 'ocu-switches-read-only'), true);
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(sentVersions()).toEqual([3]);

    tick(input(host, 'ocu-switches-share-context'), false);
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(sentVersions()).toEqual([3, 4, 4]);
  });

  it('AD-37: a hold naming a user the instance no longer holds renders the published absent sentence, and the screen loads', async () => {
    // Mutation (Rule 19): ignore `present` and render every row the same -> this goes red, and a
    // reference that no longer resolves reads as one that does.
    const { host } = await mount(() =>
      ok(
        switches({
          holds: [
            { id: '1', userName: 'Gone', reason: 'under review', present: false },
            { id: '2', userName: 'Here', reason: 'on leave', present: true },
          ],
        })
      )
    );

    const rows = Array.from(host.querySelectorAll('.ocu-switches-hold'));
    expect(rows).toHaveLength(2);
    expect(rows[0].textContent).toContain('Gone');
    expect(rows[0].querySelector('.ocu-switches-hold-absent')?.textContent).toContain(
      'is no longer present on this instance'
    );
    // DW-391: Switches has no list of users to return to, so the row reads the list-less sentence,
    // exactly. Mutation (Rule 19): revert `absentSentence` to `faultAbsentEntity` -> this goes red.
    expect(rows[0].querySelector('.ocu-switches-hold-absent')?.textContent?.trim()).toBe(
      STRINGS.faultAbsentEntityNoList.split('<name>').join('Gone')
    );
    expect(rows[1].querySelector('.ocu-switches-hold-absent')).toBeNull();
    // Both rows carry the published row action, whatever the user's state.
    for (const row of rows) {
      expect(row.textContent).toContain(STRINGS.agentSwitchesHoldRemove);
    }
    // The empty state is not also on screen.
    expect(host.querySelector('.ocu-switches-holds-empty')).toBeNull();
  });

  it('AC7: adding a hold posts the two fields and re-reads, and removing one deletes by id', async () => {
    // Mutation (Rule 19): patch the list client-side instead of re-reading -> the second GET
    // disappears and this goes red (AD-14: screens re-fetch, they never patch).
    let holds: unknown[] = [];
    const { fixture, host, calls, events } = await mount((path, init) => {
      if (init.method === 'POST') {
        holds = [{ id: '9', userName: 'Someone', reason: 'on leave', present: true }];
        return created({ id: '9', userName: 'Someone', reason: 'on leave', present: true });
      }
      if (init.method === 'DELETE') {
        holds = [];
        return ok({ id: '9', deleted: true });
      }
      return ok(switches({ holds }));
    });

    type(input(host, 'ocu-switches-userName'), 'Someone');
    type(input(host, 'ocu-switches-reason'), 'on leave');
    (host.querySelector('.ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);

    const post = calls.find((call) => call.method === 'POST');
    expect(post?.path).toBe('/api/ocupilot/agent/switches/holds');
    expect(JSON.parse(post?.body ?? '{}')).toEqual({ userName: 'Someone', reason: 'on leave' });
    // The list is re-read rather than patched: the open read the switches once, the re-read once more. The provider
    // connection, read once on open, is not re-read, since a hold changes none of it.
    expect(
      calls.filter((call) => call.method === 'GET' && call.path === '/api/ocupilot/agent/switches')
    ).toHaveLength(2);
    expect(events.map((event) => `${event.kind}:${event.type}`)).toContain('changed:agent-switch');

    const remove = host.querySelector('.ocu-switches-hold .ocu-button-text') as HTMLButtonElement;
    expect(remove).not.toBeNull();
    remove.click();
    await settle(fixture);
    const del = calls.find((call) => call.method === 'DELETE');
    expect(del?.path).toBe('/api/ocupilot/agent/switches/holds/9');
  });

  it('adding a hold refreshes the list without discarding an unsaved switch edit', async () => {
    // A hold travels on its own route and changes no switch, so the re-read that follows it must
    // refresh the list and leave the edit buffer alone. Absorbing the whole body here threw away
    // a reason the operator had typed and not yet saved -- while `FormDirty` still said there
    // were edits to discard, so the guard would ask about edits that no longer existed.
    //
    // Mutation (Rule 19): put `this.absorb(result.body)` back in `reload()` -> the typed reason
    // assertion goes red.
    let holds: unknown[] = [];
    const { fixture, host, formDirty } = await mount((path, init) => {
      if (init.method === 'POST') {
        holds = [{ id: '9', userName: 'Someone', reason: 'on leave', present: true }];
        return created({ id: '9', userName: 'Someone', reason: 'on leave', present: true });
      }
      return ok(switches({ holds }));
    });

    type(input(host, 'ocu-switches-killSwitchReason'), 'Paused for the change freeze');
    await settle(fixture);
    expect(formDirty.dirty()).toBe(true);

    type(input(host, 'ocu-switches-userName'), 'Someone');
    type(input(host, 'ocu-switches-reason'), 'on leave');
    (host.querySelector('.ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);

    // The list followed the write...
    expect(host.querySelectorAll('.ocu-switches-hold')).toHaveLength(1);
    // ...and the unsaved edit is still on screen, with the guard still saying so.
    expect(input(host, 'ocu-switches-killSwitchReason').value).toBe('Paused for the change freeze');
    expect(formDirty.dirty()).toBe(true);
  });

  it("each hold's remove button is named for the account it releases, from text already on screen", async () => {
    // N rows would otherwise present N buttons whose whole accessible name is "Switch the agent
    // back on". `aria-labelledby` composes the name from the button's own label and the row's
    // user-name element, so nothing is written here that EXPERIENCE.md has not published.
    //
    // Mutation (Rule 19): drop the `aria-labelledby` binding -> the two names below become equal
    // and this goes red.
    const { host } = await mount(() =>
      ok(
        switches({
          holds: [
            { id: '1', userName: 'Alice', reason: 'under review', present: true },
            { id: '2', userName: 'Bob', reason: 'on leave', present: true },
          ],
        })
      )
    );

    const names = Array.from(host.querySelectorAll('.ocu-switches-hold')).map((row) => {
      const button = row.querySelector('.ocu-button-text') as HTMLElement;
      const ids = (button.getAttribute('aria-labelledby') ?? '').split(' ');
      return ids
        .map((id) => (host.querySelector(`#${id}`) as HTMLElement | null)?.textContent?.trim() ?? '')
        .join(' ');
    });
    expect(names[0]).toContain(STRINGS.agentSwitchesHoldRemove);
    expect(names[0]).toContain('Alice');
    expect(names[1]).toContain('Bob');
    expect(names[0]).not.toBe(names[1]);
  });

  it('the unsaved-changes guard raises the published question, and the screen answers it', async () => {
    // The guard is the route's, not a click handler's, so every caller of `navigateByUrl` gets
    // the same answer -- including an agent navigation (AD-11).
    const { host, fixture, formDirty } = await mount(() => ok(switches()));
    tick(input(host, 'ocu-switches-read-only'), true);
    await settle(fixture);
    expect(formDirty.dirty()).toBe(true);

    const leaving = formDirty.requestLeave();
    await settle(fixture);
    expect(host.textContent).toContain(STRINGS.formLeaveWithoutSaving);
    (host.querySelector('.ocu-button-primary[dialogAction]') as HTMLButtonElement)?.click();
    await settle(fixture);
    expect(await leaving).toBe(true);
  });
});

describe('the Switches screen, Provider connection section (Story 18.40)', () => {
  it('C6: renders the published copy and the stored connection, an empty port for no proxy', async () => {
    // Mutation (Rule 19): bind the configuration field to another violation field (`this.field('sslConfigurationX')`) ->
    // this, the Save leg and the refusal leg go red.
    const { host } = await mount((path) =>
      path === EGRESS_PATH
        ? ok(connection({ proxyServer: '192.0.2.10', proxyPort: 3128, sslConfiguration: 'MyCa', rowVersion: 7 }))
        : ok(switches())
    );

    expect(host.textContent).toContain(STRINGS.agentSwitchesConnectionHeading);
    expect(host.textContent).toContain(STRINGS.agentSwitchesProxyServer);
    expect(host.textContent).toContain(STRINGS.agentSwitchesProxyPort);
    expect(host.textContent).toContain(STRINGS.sslFormLabel);
    expect(host.textContent).toContain(STRINGS.agentSwitchesProxyHint);
    expect(host.textContent).toContain(STRINGS.agentSwitchesSslConfigurationHint);
    expect(host.textContent).toContain(STRINGS.agentSwitchesSaveConnection);
    expect(input(host, 'ocu-switches-proxyServer').value).toBe('192.0.2.10');
    expect(input(host, 'ocu-switches-proxyPort').value).toBe('3128');
    expect(input(host, 'ocu-switches-sslConfiguration').value).toBe('MyCa');
    expect(input(host, 'ocu-switches-proxyServer').getAttribute('aria-describedby')).toBe(
      'ocu-switches-proxyServer-hint'
    );
  });

  it('C1: Save connection sends the three keys and the row version, renders the answer and publishes the change', async () => {
    // Mutation (Rule 19): drop `proxyPort` from `connectionBody()` in the store -> the body assertion goes red; show a
    // stored port 0 as `0` rather than empty in `absorbConnection()` -> the empty-port assertion goes red.
    const { fixture, host, calls, events, formDirty } = await mount((path, init) => {
      if (path === EGRESS_PATH && init.method === 'PUT') {
        return ok(connection({ proxyServer: 'proxy.example.net', proxyPort: 8080, sslConfiguration: 'MyCa', rowVersion: 8 }));
      }
      return path === EGRESS_PATH ? ok(connection({ rowVersion: 7 })) : ok(switches());
    });

    expect(input(host, 'ocu-switches-proxyPort').value).toBe('');
    type(input(host, 'ocu-switches-proxyServer'), 'proxy.example.net');
    type(input(host, 'ocu-switches-proxyPort'), '8080');
    type(input(host, 'ocu-switches-sslConfiguration'), 'MyCa');
    await settle(fixture);
    expect(formDirty.dirty()).toBe(true);

    const save = Array.from(host.querySelectorAll('button')).find(
      (button) => button.textContent?.trim() === STRINGS.agentSwitchesSaveConnection
    ) as HTMLButtonElement;
    save.click();
    await settle(fixture);

    const put = calls.find((call) => call.method === 'PUT');
    expect(put?.path).toBe(EGRESS_PATH);
    expect(JSON.parse(put?.body ?? '{}')).toEqual({
      proxyServer: 'proxy.example.net',
      proxyPort: 8080,
      sslConfiguration: 'MyCa',
      rowVersion: 7,
    });
    expect(events.map((event) => `${event.kind}:${event.type}`)).toContain('changed:agent-switch');
    expect(input(host, 'ocu-switches-proxyServer').value).toBe('proxy.example.net');
    expect(host.querySelector('.ocu-switches-connection [role="status"]')?.textContent).toContain(STRINGS.formSaved);
    expect(formDirty.dirty()).toBe(false);
  });

  it('C2, C6: an EGRESS.SSLABSENT reason lands on its field, and the form says nothing was saved', async () => {
    // Mutation (Rule 19): bind the configuration field to another violation field (`this.field('sslConfigurationX')`) ->
    // the field assertions go red.
    const { fixture, host } = await mount((path, init) => {
      if (path === EGRESS_PATH && init.method === 'PUT') {
        return refused([
          { field: 'sslConfiguration', code: 'EGRESS.SSLABSENT', reason: STRINGS.egressRefusalSslAbsent },
        ]);
      }
      return path === EGRESS_PATH ? ok(connection()) : ok(switches());
    });

    type(input(host, 'ocu-switches-sslConfiguration'), 'NoSuchConfiguration');
    (Array.from(host.querySelectorAll('button')).find(
      (button) => button.textContent?.trim() === STRINGS.agentSwitchesSaveConnection
    ) as HTMLButtonElement).click();
    await settle(fixture);

    const field = input(host, 'ocu-switches-sslConfiguration');
    expect(field.getAttribute('aria-invalid')).toBe('true');
    expect(host.querySelector('#ocu-switches-sslConfiguration-reason')?.textContent).toContain(
      STRINGS.egressRefusalSslAbsent
    );
    expect(field.getAttribute('aria-describedby')).toContain('ocu-switches-sslConfiguration-reason');
    expect(host.querySelector('.ocu-switches-connection [role="status"]')).toBeNull();
    expect(field.value).toBe('NoSuchConfiguration');
  });

  it('C6: proxy host and port refusals land on their own fields, each described by its reason', async () => {
    // Mutation (Rule 19): delete the `@if (proxyPortField.invalid)` reason paragraph from the page template -> the port
    // assertions go red.
    const { fixture, host } = await mount((path, init) => {
      if (path === EGRESS_PATH && init.method === 'PUT') {
        return refused([
          { field: 'proxyServer', code: 'EGRESS.PROXYHOST', reason: STRINGS.egressRefusalProxyHost },
          { field: 'proxyPort', code: 'EGRESS.PROXYPORT', reason: STRINGS.egressRefusalProxyPort },
        ]);
      }
      return path === EGRESS_PATH ? ok(connection()) : ok(switches());
    });

    type(input(host, 'ocu-switches-proxyServer'), 'proxy.example:3128');
    type(input(host, 'ocu-switches-proxyPort'), '0');
    (Array.from(host.querySelectorAll('button')).find(
      (button) => button.textContent?.trim() === STRINGS.agentSwitchesSaveConnection
    ) as HTMLButtonElement).click();
    await settle(fixture);

    for (const [id, text] of [
      ['ocu-switches-proxyServer', STRINGS.egressRefusalProxyHost],
      ['ocu-switches-proxyPort', STRINGS.egressRefusalProxyPort],
    ] as const) {
      const field = input(host, id);
      expect(field.getAttribute('aria-invalid')).toBe('true');
      expect(host.querySelector(`#${id}-reason`)?.textContent).toContain(text);
      expect(field.getAttribute('aria-describedby')).toContain(`${id}-reason`);
    }
    expect(input(host, 'ocu-switches-sslConfiguration').getAttribute('aria-invalid')).not.toBe('true');
  });

  it('a connection that cannot be read draws no section and offers no Save connection, while the switches still load', async () => {
    // Mutation (Rule 19): mark the connection loaded when its read is refused (`connectionLoadedValue = true` in the
    // store's `open` failure branch) -> the section assertions go red.
    const { host } = await mount((path) => (path === EGRESS_PATH ? forbidden() : ok(switches())));

    expect(host.querySelector('.ocu-switches-connection')).toBeNull();
    expect(host.textContent).not.toContain(STRINGS.agentSwitchesSaveConnection);
    expect(host.textContent).toContain(STRINGS.agentSwitchesKillSwitch);
    const banner = host.querySelector('.ocu-banner-warning') as HTMLElement;
    expect(banner.textContent).toContain(STRINGS.agentSwitchesConnectionRefusedAction);
  });

  it('a refused connection save names its own action, and a stale one reads the published reload sentence', async () => {
    // Mutation (Rule 19): resolve the action from the switches phrase alone -> the first assertion goes red.
    let answer: JsonResult<unknown> = forbidden();
    const { fixture, host } = await mount((path, init) => {
      if (path === EGRESS_PATH && init.method === 'PUT') return answer;
      return path === EGRESS_PATH ? ok(connection()) : ok(switches());
    });
    const save = () =>
      (Array.from(host.querySelectorAll('button')).find(
        (button) => button.textContent?.trim() === STRINGS.agentSwitchesSaveConnection
      ) as HTMLButtonElement).click();

    save();
    await settle(fixture);
    const banner = host.querySelector('.ocu-banner-warning')?.textContent ?? '';
    expect(banner).toContain(STRINGS.agentSwitchesConnectionRefusedAction);
    expect(banner).not.toContain(STRINGS.agentSwitchesRefusedAction);

    answer = conflicted();
    save();
    await settle(fixture);
    expect(host.querySelector('.ocu-banner-warning')?.textContent).toContain(STRINGS.formStaleSave);
    expect(host.textContent).not.toContain(CONFLICT_ENVELOPE_REASON);
  });

  it('one unsaved-changes flag stands for both sections: saving the switches does not clear an unsaved connection edit', async () => {
    // Mutation (Rule 19): make a switches save call `formDirty.setDirty(false)` directly -> the last assertion goes red.
    const { fixture, host, formDirty } = await mount((path, init) => {
      if (init.method === 'PUT') return ok(switches({ enforcedReadOnly: true, rowVersion: 2 }));
      return path === EGRESS_PATH ? ok(connection()) : ok(switches());
    });

    type(input(host, 'ocu-switches-proxyServer'), 'proxy.example.net');
    tick(input(host, 'ocu-switches-read-only'), true);
    await settle(fixture);
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(formDirty.dirty()).toBe(true);
  });
});

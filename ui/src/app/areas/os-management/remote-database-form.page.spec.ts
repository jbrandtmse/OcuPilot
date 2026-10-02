import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { SCREENS } from '../../core/screens.generated';
import { readBackOf, savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import { RemoteDatabaseFormPage } from './remote-database-form.page';
import { REMOTE_DATABASE_DIRECTORIES_PATH, REMOTE_DATABASE_FORM_PATH } from './remote-database-form.store';

/**
 * The remote database form over stubs of the two things an instance supplies -- the URL's screen
 * and the HTTP answers. The real store, the real `FormDirty` and the real template run, so the
 * assertions are about rendered DOM (Story 18.16, AC5, AD-21's seventh case). A listing answer is
 * held until the test releases it, so the running line and the gated select are observed while it
 * is in flight.
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.RemoteDatabaseForm');

const UNREACHABLE = 'The data server could not be reached in time. Check that it is running and that this instance\'s license includes ECP.';

const RULES = {
  requiredFields: ['Name', 'Server', 'Directory'],
  rules: [],
  listSeconds: 7,
  servers: [{ Name: 'DATASRV', Status: 'Not Connected' }],
};

const CONFIGURATION = { Server: 'DATASRV', Directory: '/data/one/', StreamLocation: '/streams/', MountAtStartup: false, MountRequired: false, ClusterMountMode: false };

const LISTED = { server: 'DATASRV', rows: [{ Name: 'ONE', Directory: '/data/one/' }, { Name: 'TWO', Directory: '/data/two/' }], truncated: false };

const REFUSED_LISTING = {
  kind: 'error',
  status: 422,
  code: 'DATABASE.SERVER.UNREACHABLE',
  reason: UNREACHABLE,
  detail: { violations: [{ field: 'Server', code: 'DATABASE.SERVER.UNREACHABLE', reason: UNREACHABLE }] },
};

const REFUSED_SAVE = {
  kind: 'error',
  status: 422,
  code: 'DATABASE.VALIDATION',
  reason: 'The database was refused.',
  detail: {
    violations: [
      { field: 'Name', code: 'DATABASE.NAME.SHAPE', reason: 'A database name starts with a letter.' },
      { field: 'Directory', code: 'DATABASE.REMOTEDIRECTORY.NONE', reason: 'Choose the database\'s directory on the data server.' },
    ],
  },
};

const NO_WRITE_PAIR = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'Forbidden', detail: { failedPair: '%DB_IRISSYS:WRITE' } };

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(url = '/os-management/remote-databases/edit', saveAnswer: unknown = REFUSED_SAVE) {
  TestBed.resetTestingModule();
  const listings: Array<(answer: unknown) => void> = [];
  const calls: Array<{ path: string; method: string; body: string }> = [];
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if ((init.method ?? 'GET') !== 'GET') return saveAnswer as JsonResult<T>;
      if (path.startsWith(REMOTE_DATABASE_DIRECTORIES_PATH)) {
        return new Promise<JsonResult<T>>((resolve) => listings.push((answer) => resolve(answer as JsonResult<T>)));
      }
      const body = path === REMOTE_DATABASE_FORM_PATH ? RULES : { ...RULES, Name: 'PROBEREMOTE', configuration: CONFIGURATION };
      return { kind: 'ok', status: 200, body } as unknown as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => FORM_SCREEN ?? null } as unknown as NavigationService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(RemoteDatabaseFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, formDirty, listings, calls, host: fixture.nativeElement as HTMLElement };
}

// The form read's bound, not the client's fallback of 20, so the hint shows what the instance answered.
const hint = () => STRINGS.remoteDatabaseListHint.replace('<n>', '7');

function serverSelect(host: HTMLElement): HTMLSelectElement {
  return host.querySelector('#ocu-remote-database-Server') as HTMLSelectElement;
}

function directoryOptions(host: HTMLElement): Array<[string, string]> {
  return [...host.querySelectorAll('#ocu-remote-database-Directory option')].map((option) => [
    (option as HTMLOptionElement).value,
    option.textContent?.trim() ?? '',
  ]);
}

function choose(fixture: ComponentFixture<unknown>, select: HTMLSelectElement, value: string): void {
  select.value = value;
  select.dispatchEvent(new Event('change'));
  fixture.detectChanges();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the remote database form', () => {
  it('AC5: the Data server hint states the bound before anything is chosen and describes the select', async () => {
    const { host } = await mount();
    // Mutation (Rule 19): drop the hint paragraph from the template -> red.
    const shown = host.querySelector('[data-listing="hint"]') as HTMLElement;
    expect(shown?.textContent?.trim()).toBe(hint());
    const select = serverSelect(host);
    expect(select.getAttribute('aria-describedby')?.split(' ')).toContain(shown.id);
    expect(select.getAttribute('aria-disabled')).toBeNull();
    expect(host.querySelector('[data-listing="status"]')?.textContent?.trim()).toBe('');
    expect([...host.querySelectorAll('.ocu-form-fields .ocu-field-label')].map((label) => label.textContent?.trim())).toEqual([
      STRINGS.tableColumnName,
      STRINGS.remoteDatabaseServer,
      STRINGS.lockColumnDirectory,
    ]);
    expect(directoryOptions(host)).toEqual([['', '']]);
  });

  it('AC5: while the listing runs the select is aria-disabled, focusable, and the running line names the server and the time it was sent', async () => {
    const { fixture, host, listings } = await mount();
    const select = serverSelect(host);
    choose(fixture, select, 'DATASRV');
    await settle(fixture);
    expect(listings.length).toBe(1);
    // Mutation (Rule 19): drop `[attr.aria-disabled]="serverBlocked"` from the select -> red.
    expect(select.getAttribute('aria-disabled')).toBe('true');
    expect(select.disabled).toBe(false);
    const status = host.querySelector('[data-listing="status"]') as HTMLElement;
    expect(status.getAttribute('role')).toBe('status');
    const prefix = STRINGS.remoteDatabaseListRunning.replace('<server>', 'DATASRV').replace('<time>', '');
    expect(status.textContent?.trim().startsWith(prefix)).toBe(true);
    expect(status.textContent?.trim().slice(prefix.length)).toMatch(/^\d{2}:\d{2}:\d{2}$/);
    expect(select.getAttribute('aria-describedby')?.split(' ')).toEqual([host.querySelector('[data-listing="hint"]')?.id, status.id]);
    expect((host.querySelector('.ocu-form-bar-actions .ocu-button-primary') as HTMLElement).getAttribute('aria-disabled')).toBe('true');

    // A choice while it runs is refused, and the select shows the server still being listed.
    choose(fixture, select, '');
    await settle(fixture);
    expect(listings.length).toBe(1);
    expect(select.value).toBe('DATASRV');

    listings[0]?.({ kind: 'ok', status: 200, body: LISTED });
    await settle(fixture);
    expect(select.getAttribute('aria-disabled')).toBeNull();
    expect(status.textContent?.trim()).toBe('');
  });

  it('AC5: a refused listing renders its reason on Data server and offers no directory', async () => {
    const { fixture, host, listings } = await mount();
    choose(fixture, serverSelect(host), 'DATASRV');
    await settle(fixture);
    listings[0]?.(REFUSED_LISTING);
    await settle(fixture);
    const select = serverSelect(host);
    expect(select.getAttribute('aria-invalid')).toBe('true');
    const reason = host.querySelector('#ocu-remote-database-Server-reason') as HTMLElement;
    expect(reason.classList.contains('ocu-form-error')).toBe(true);
    expect(reason.textContent?.trim()).toBe(UNREACHABLE);
    expect(select.getAttribute('aria-describedby')?.split(' ')).toContain(reason.id);
    expect(directoryOptions(host)).toEqual([['', '']]);
  });

  it('a listing that answers offers its rows as the directory choices, each valued by its directory', async () => {
    const { fixture, host, listings } = await mount();
    choose(fixture, serverSelect(host), 'DATASRV');
    await settle(fixture);
    listings[0]?.({ kind: 'ok', status: 200, body: LISTED });
    await settle(fixture);
    expect(directoryOptions(host)).toEqual([
      ['', ''],
      ['/data/one/', 'ONE \u00b7 /data/one/'],
      ['/data/two/', 'TWO \u00b7 /data/two/'],
    ]);
    choose(fixture, host.querySelector('#ocu-remote-database-Directory') as HTMLSelectElement, '/data/two/');
    await settle(fixture);
    expect(directoryOptions(host).map(([value]) => value)).toEqual(['/data/one/', '/data/two/']);
  });

  it('an empty listing says the server lists no databases', async () => {
    const { fixture, host, listings } = await mount();
    choose(fixture, serverSelect(host), 'DATASRV');
    await settle(fixture);
    listings[0]?.({ kind: 'ok', status: 200, body: { server: 'DATASRV', rows: [], truncated: false } });
    await settle(fixture);
    expect(host.querySelector('[data-listing="status"]')?.textContent?.trim()).toBe(STRINGS.remoteDatabaseListNone.replace('<server>', 'DATASRV'));
  });

  it('AD-39: a refused Save renders each reason on its field and in the summary', async () => {
    const { fixture, host } = await mount();
    const name = host.querySelector('#ocu-remote-database-Name') as HTMLInputElement;
    name.value = '1AB';
    name.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('.ocu-form-bar-actions .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('#ocu-remote-database-Name-reason')?.textContent?.trim()).toBe('A database name starts with a letter.');
    expect(host.querySelector('#ocu-remote-database-Directory-reason')?.textContent?.trim()).toBe('Choose the database\'s directory on the data server.');
    expect(name.getAttribute('aria-invalid')).toBe('true');
    expect((host.querySelector('#ocu-remote-database-Directory') as HTMLElement).getAttribute('aria-invalid')).toBe('true');
    expect(host.querySelectorAll('.ocu-form-summary-list li').length).toBe(2);
  });

  it('an edit shows the name and stream location read-only and offers just the stored directory', async () => {
    const { host } = await mount('/os-management/remote-databases/edit/PROBEREMOTE');
    const name = host.querySelector('#ocu-remote-database-Name') as HTMLInputElement;
    expect([name.readOnly, name.value]).toEqual([true, 'PROBEREMOTE']);
    const stream = host.querySelector('#ocu-remote-database-StreamLocation') as HTMLInputElement;
    expect([stream.readOnly, stream.value]).toEqual([true, '/streams/']);
    expect(serverSelect(host).value).toBe('DATASRV');
    expect(directoryOptions(host)).toEqual([['/data/one/', '/data/one/']]);
    expect([...host.querySelectorAll('.ocu-form-fields .ocu-field-label')].map((label) => label.textContent?.trim())).toEqual([
      STRINGS.tableColumnName,
      STRINGS.remoteDatabaseServer,
      STRINGS.lockColumnDirectory,
      STRINGS.remoteDatabaseStreamLocation,
    ]);
  });

  it('AC3: on an edit, List databases lists the stored server, and a re-point puts only the directory', async () => {
    const { fixture, host, listings, calls } = await mount('/os-management/remote-databases/edit/PROBEREMOTE', {
      kind: 'ok',
      status: 200,
      body: { name: 'PROBEREMOTE' },
    });
    // Mutation (Rule 19): drop the List databases button from the template -> red.
    const again = host.querySelector('[data-action="list-databases"]') as HTMLButtonElement;
    expect(again?.textContent?.trim()).toBe(STRINGS.remoteDatabaseListAgain);
    again.click();
    await settle(fixture);
    expect(listings.length).toBe(1);
    expect(again.getAttribute('aria-disabled')).toBe('true');
    listings[0]?.({ kind: 'ok', status: 200, body: LISTED });
    await settle(fixture);
    expect(directoryOptions(host)).toEqual([
      ['/data/one/', 'ONE \u00b7 /data/one/'],
      ['/data/two/', 'TWO \u00b7 /data/two/'],
    ]);
    choose(fixture, host.querySelector('#ocu-remote-database-Directory') as HTMLSelectElement, '/data/two/');
    await settle(fixture);
    (host.querySelector('.ocu-form-bar-actions .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    const put = calls.find((call) => call.method === 'PUT');
    expect(JSON.parse(put?.body ?? '{}')).toEqual({ Directory: '/data/two/' });
  });

  it('AC2, AD-58: an accepted create replaces the route with the new database and keeps Saved with its read-back', async () => {
    const readBack = { verdict: 'matches', fields: ['Server', 'Directory'], written: [] };
    const { fixture, host, listings } = await mount('/os-management/remote-databases/edit', {
      kind: 'ok',
      status: 201,
      body: { name: 'PROBEREMOTE', readBack },
    });
    const name = host.querySelector('#ocu-remote-database-Name') as HTMLInputElement;
    name.value = 'PROBEREMOTE';
    name.dispatchEvent(new Event('input'));
    choose(fixture, serverSelect(host), 'DATASRV');
    await settle(fixture);
    listings[0]?.({ kind: 'ok', status: 200, body: LISTED });
    await settle(fixture);
    choose(fixture, host.querySelector('#ocu-remote-database-Directory') as HTMLSelectElement, '/data/two/');
    await settle(fixture);
    (host.querySelector('.ocu-form-bar-actions .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    // Mutation (Rule 19): drop `retainAcrossRouteReplacement()` from `onSave`, or drop the read-back the
    // store keeps across the arrival -> red.
    expect(TestBed.inject(Router).url).toBe('/os-management/remote-databases/edit/PROBEREMOTE');
    expect(host.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim()).toBe(savedLine(readBackOf(readBack)));
  });

  it('a change raises the dirty flag, and leaving asks the shared question first', async () => {
    const { fixture, host, formDirty } = await mount();
    expect(formDirty.dirty()).toBe(false);
    const name = host.querySelector('#ocu-remote-database-Name') as HTMLInputElement;
    name.value = 'PROBEREMOTE';
    name.dispatchEvent(new Event('input'));
    await settle(fixture);
    expect(formDirty.dirty()).toBe(true);
    const asked = formDirty.requestLeave();
    await settle(fixture);
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement;
    expect(dialog.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.formLeaveWithoutSaving);
    (dialog.querySelectorAll('.ocu-dialog-actions button')[0] as HTMLButtonElement).click();
    await settle(fixture);
    expect(await asked).toBe(false);
  });

  it('a Save refused for the write pair names the pair and the action, in both modes (AD-8)', async () => {
    for (const [url, action] of [
      ['/os-management/remote-databases/edit', STRINGS.remoteDatabaseListEmptyAgent],
      ['/os-management/remote-databases/edit/PROBEREMOTE', STRINGS.remoteDatabaseFormRefusedAction],
    ] as const) {
      const { fixture, host, listings } = await mount(url, NO_WRITE_PAIR);
      if (url.endsWith('PROBEREMOTE')) {
        const directory = host.querySelector('#ocu-remote-database-Directory') as HTMLSelectElement;
        const option = document.createElement('option');
        option.value = '/data/two/';
        directory.appendChild(option);
        choose(fixture, directory, '/data/two/');
      } else {
        const name = host.querySelector('#ocu-remote-database-Name') as HTMLInputElement;
        name.value = 'PROBEREMOTE';
        name.dispatchEvent(new Event('input'));
      }
      fixture.detectChanges();
      expect(listings.length).toBe(0);
      (host.querySelector('.ocu-form-bar-actions button.ocu-button-primary') as HTMLButtonElement).click();
      await settle(fixture);
      expect(host.querySelector('.ocu-banner[role="alert"]')?.textContent?.trim()).toBe(`You need %DB_IRISSYS:WRITE to ${action}.`);
      for (const node of planted.splice(0)) node.remove();
    }
  });
});

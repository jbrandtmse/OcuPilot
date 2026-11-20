import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { ListingGroupCopyDialog } from './listing-group-copy-dialog';
import { ListingGroupDialog } from './listing-group-dialog';

/**
 * The listing group editor's dialogs (Story 24.11): New listing group posts the typed members to its route, Edit opens on the form the instance answers and sends the row action
 * `update`, Add listing posts to the listing route with its group, Change listing opens on its row and sends `set`, and Copy sends `copy` with its three values. Every refusal is
 * drawn as the server sent it, a rule on its field and any other sentence above the fields.
 */

@Component({
  imports: [ListingGroupDialog, ListingGroupCopyDialog],
  template: `@if (mode === 'add-group') {
      <app-listing-group-dialog kind="group" [namespace]="'USER'" (done)="done.push('done')" />
    }
    @if (mode === 'edit-group') {
      <app-listing-group-dialog kind="group" [namespace]="'USER'" [target]="'Probe.Group'" (done)="done.push('done')" />
    }
    @if (mode === 'add-listing') {
      <app-listing-group-dialog kind="listing" [namespace]="'USER'" [group]="'Probe.Group'" (done)="done.push('done')" />
    }
    @if (mode === 'change-listing') {
      <app-listing-group-dialog kind="listing" [namespace]="'USER'" [group]="'Probe.Group'" [target]="'Probe.Group|Probe.Listing'" [initial]="row" (done)="done.push('done')" />
    }
    @if (mode === 'copy') {
      <app-listing-group-copy-dialog [namespace]="'USER'" [source]="'Probe.Group'" (done)="done.push('done')" />
    }`,
})
class Host {
  mode = 'add-group';

  readonly done: string[] = [];

  readonly row = { Name: 'Probe.Listing', DisplayName: 'Shown', Type: 'table', Fields: 'Amount', OrderBy: '', Formats: '', Source: '', Resource: '', SelectMode: '2', Description: '', SQL: '', Disabled: 'false' };
}

interface Sent {
  readonly path: string;
  readonly method: string;
  readonly body: Record<string, unknown>;
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(mode: string, answer: JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push({ path, method: init.method ?? 'GET', body: typeof init.body === 'string' ? (JSON.parse(init.body) as Record<string, unknown>) : {} });
      if (path.includes('/form')) {
        return { kind: 'ok', status: 200, body: { Name: 'Probe.Group', Class: 'Probe.Class', Caption: 'Shown', Description: 'About', TargetCubes: 'Probe', Resource: '', DefaultResource: '', Disabled: true } } as JsonResult<T>;
      }
      return answer as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: ScopeService, useValue: { namespace: () => 'USER' } as unknown as ScopeService },
    ],
  });
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.mode = mode;
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, sent };
}

function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, member: string, text: string, attribute = 'data-listing-group-field'): void {
  const input = host.querySelector(`[${attribute}="${member}"]`) as HTMLInputElement;
  input.value = text;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement, attribute = 'data-listing-group-confirm'): HTMLButtonElement {
  return host.querySelector(`[${attribute}]`) as HTMLButtonElement;
}

const CREATED = { kind: 'ok', status: 201, body: { id: 'Probe.Group', target: { type: 'listing-group', scope: 'USER', id: 'Probe.Group' }, readBack: null } } as JsonResult<unknown>;

const APPLIED = { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'listing-group', scope: 'USER', id: 'Probe.Group' } } } as JsonResult<unknown>;

describe('the listing group editor dialogs', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('New listing group sends nothing until a name is typed, then posts the typed members to the groups route', async () => {
    // Mutation (Rule 19): post the add to another route than `LISTING_GROUP_PATH` -> the path assertion goes red.
    const { fixture, host, sent } = await mount('add-group', CREATED);
    expect(host.textContent).toContain(STRINGS.analyticsListingGroupNewAction);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    typeInto(fixture, host, 'Name', 'Probe.Group');
    typeInto(fixture, host, 'Class', 'Probe.Class');
    typeInto(fixture, host, 'TargetCubes', 'Probe');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
    confirm(host).click();
    await settle(fixture);
    const posted = sent.filter((entry) => entry.method === 'POST');
    expect(posted.map((entry) => entry.path)).toEqual(['/api/ocupilot/analytics/listing-groups']);
    expect(posted[0].body).toEqual({ Name: 'Probe.Group', Class: 'Probe.Class', TargetCubes: 'Probe', Disabled: false });
    expect((fixture.componentInstance as Host).done).toEqual(['done']);
  });

  it('Edit opens on the form the instance answers, fixes the name, and sends the update action with its members as text', async () => {
    // Mutation (Rule 19): send `Disabled` as a boolean rather than `true` or `false` text -> the sent-values assertion goes red.
    const { fixture, host, sent } = await mount('edit-group', APPLIED);
    expect((host.querySelector('[data-listing-group-field="Name"]') as HTMLInputElement).readOnly).toBe(true);
    expect((host.querySelector('[data-listing-group-field="Caption"]') as HTMLInputElement).value).toBe('Shown');
    expect(host.querySelector('[data-listing-group-field="Class"]')).toBeNull();
    typeInto(fixture, host, 'Caption', 'Changed');
    confirm(host).click();
    await settle(fixture);
    const posted = sent.filter((entry) => entry.method === 'POST');
    expect(posted).toHaveLength(1);
    expect(posted[0].body).toEqual({
      action: 'update',
      id: 'Probe.Group',
      values: { Caption: 'Changed', Description: 'About', TargetCubes: 'Probe', Resource: '', DefaultResource: '', Disabled: 'true' },
    });
  });

  it('Add listing posts the typed members with the group to the listings route', async () => {
    const { fixture, host, sent } = await mount('add-listing', CREATED);
    typeInto(fixture, host, 'Name', 'Probe.Listing');
    typeInto(fixture, host, 'Fields', 'Amount');
    confirm(host).click();
    await settle(fixture);
    const posted = sent.filter((entry) => entry.method === 'POST');
    expect(posted.map((entry) => entry.path)).toEqual(['/api/ocupilot/analytics/listing-group-listings']);
    expect(posted[0].body).toEqual({ ListingGroup: 'Probe.Group', Name: 'Probe.Listing', Type: 'table', Fields: 'Amount', SelectMode: '2', Disabled: false });
  });

  it('Change listing opens on its row and sends the set action on its composite id', async () => {
    const { fixture, host, sent } = await mount('change-listing', APPLIED);
    expect((host.querySelector('[data-listing-group-field="Fields"]') as HTMLTextAreaElement).value).toBe('Amount');
    typeInto(fixture, host, 'Fields', 'Minutes');
    confirm(host).click();
    await settle(fixture);
    const posted = sent.filter((entry) => entry.method === 'POST');
    expect(posted).toHaveLength(1);
    expect(posted[0].body['action']).toBe('set');
    expect(posted[0].body['id']).toBe('Probe.Group|Probe.Listing');
    expect(posted[0].body['values']).toMatchObject({ Fields: 'Minutes', Type: 'table', SelectMode: '2', Disabled: 'false' });
  });

  it('Copy sends its two required values and the optional cubes only when typed, and draws a refusal as the server sent it', async () => {
    const applied = await mount('copy', APPLIED);
    expect(confirm(applied.host, 'data-listing-group-copy-confirm').getAttribute('aria-disabled')).toBe('true');
    typeInto(applied.fixture, applied.host, 'NewName', 'Probe.Copy', 'data-listing-group-copy-field');
    typeInto(applied.fixture, applied.host, 'NewClass', 'Probe.CopyClass', 'data-listing-group-copy-field');
    confirm(applied.host, 'data-listing-group-copy-confirm').click();
    await settle(applied.fixture);
    expect(applied.sent.filter((entry) => entry.method === 'POST')[0].body).toEqual({ action: 'copy', id: 'Probe.Group', values: { NewName: 'Probe.Copy', NewClass: 'Probe.CopyClass' } });
    const taken = await mount('copy', { kind: 'error', status: 409, code: 'ANALYTICS.LISTINGGROUP.TAKEN', reason: STRINGS.analyticsRefusalListingGroupTaken, detail: null } as JsonResult<unknown>);
    typeInto(taken.fixture, taken.host, 'NewName', 'Probe.Group', 'data-listing-group-copy-field');
    typeInto(taken.fixture, taken.host, 'NewClass', 'Probe.Class', 'data-listing-group-copy-field');
    typeInto(taken.fixture, taken.host, 'NewCubes', 'Other', 'data-listing-group-copy-field');
    confirm(taken.host, 'data-listing-group-copy-confirm').click();
    await settle(taken.fixture);
    expect(taken.sent.filter((entry) => entry.method === 'POST')[0].body['values']).toEqual({ NewName: 'Probe.Group', NewClass: 'Probe.Class', NewCubes: 'Other' });
    expect(taken.host.querySelector('[data-listing-group-copy-reason]')?.textContent).toContain(STRINGS.analyticsRefusalListingGroupTaken);
    expect((taken.fixture.componentInstance as Host).done).toEqual([]);
  });

  it('draws a rule on a field under it and any other refusal above the fields', async () => {
    const rule = await mount('add-group', {
      kind: 'error',
      status: 422,
      code: 'PORT.FIELD.SHAPE',
      reason: 'shape',
      detail: { violations: [{ field: 'Name', code: 'PORT.FIELD.SHAPE', reason: 'Name shape sentence' }] },
    } as JsonResult<unknown>);
    typeInto(rule.fixture, rule.host, 'Name', 'x');
    confirm(rule.host).click();
    await settle(rule.fixture);
    expect(rule.host.querySelector('[data-listing-group-violation="Name"]')?.textContent).toContain('Name shape sentence');
    expect(rule.host.querySelector('[data-listing-group-reason]')).toBeNull();
    const class_ = await mount('add-group', { kind: 'error', status: 422, code: 'ANALYTICS.LISTINGGROUP.CLASS', reason: STRINGS.analyticsRefusalListingGroupClass, detail: null } as JsonResult<unknown>);
    typeInto(class_.fixture, class_.host, 'Name', 'x');
    confirm(class_.host).click();
    await settle(class_.fixture);
    expect(class_.host.querySelector('[data-listing-group-reason]')?.textContent).toContain(STRINGS.analyticsRefusalListingGroupClass);
    expect((class_.fixture.componentInstance as Host).done).toEqual([]);
  });
});

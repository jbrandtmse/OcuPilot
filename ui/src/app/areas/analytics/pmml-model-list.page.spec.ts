import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { PMML_MODEL_ADD_ACTION, PMML_MODEL_LIST, PmmlModelListPage } from './pmml-model-list.page';

/**
 * The PMML models page's own wiring (Story 24.14 Batch 3): the shared list page is replaced by an empty stand-in, so only what the page registers and the dialog it opens run. New PMML
 * definition is registered on the screen; its dialog posts the typed class and the PMML text, as typed, to the definition route, loads a file's text into the text field, and draws a refusal
 * as the server sent it.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const SCREEN = SCREENS.find((screen) => screen.descriptor === PMML_MODEL_LIST)!;

const planted: HTMLElement[] = [];

interface Sent {
  readonly path: string;
  readonly method: string;
  readonly body: Record<string, unknown>;
}

const CREATED = { kind: 'ok', status: 201, body: { id: 'Probe.Pmml', target: { type: 'pmml-model', scope: 'USER', id: 'Probe.Pmml' }, readBack: null } } as JsonResult<unknown>;

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

function mount(answer: JsonResult<unknown> = CREATED) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push({ path, method: init.method ?? 'GET', body: typeof init.body === 'string' ? (JSON.parse(init.body) as Record<string, unknown>) : {} });
      return answer as JsonResult<T>;
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
      { provide: Router, useValue: { url: '/analytics/pmml-models', events: { subscribe: () => ({ unsubscribe: () => {} }) } } },
    ],
  });
  TestBed.overrideComponent(PmmlModelListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  stores.for(SCREEN.descriptor, SCREEN.refreshRates);
  const fixture = TestBed.createComponent(PmmlModelListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, sent, actions: TestBed.inject(ScreenActions) };
}

function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, selector: string, text: string): void {
  const field = host.querySelector(selector) as HTMLInputElement | HTMLTextAreaElement;
  field.value = text;
  field.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

const confirm = (host: HTMLElement): HTMLButtonElement => host.querySelector('[data-pmml-definition-confirm]') as HTMLButtonElement;

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the PMML models page', () => {
  it('declares New PMML definition as its primary action and registers it', () => {
    // Mutation (Rule 19): drop the registration from the page's constructor -> this goes red.
    const { actions } = mount();
    expect(SCREEN.primaryAction.id).toBe(PMML_MODEL_ADD_ACTION);
    expect(actions.has(PMML_MODEL_LIST, PMML_MODEL_ADD_ACTION)).toBe(true);
  });

  it('opens New PMML definition on a class and a PMML field, and sends nothing until both are typed', async () => {
    // Mutation (Rule 19): enable the action while a field is blank -> the disabled assertion goes red.
    const { fixture, host, actions } = mount();
    expect(host.querySelector('app-pmml-definition-dialog')).toBeNull();
    actions.run(PMML_MODEL_LIST, PMML_MODEL_ADD_ACTION);
    await settle(fixture);
    expect(host.textContent).toContain(STRINGS.analyticsPmmlNewAction);
    expect([host.querySelector('[data-pmml-definition-class]') !== null, host.querySelector('[data-pmml-definition-text]') !== null, host.querySelector('[data-pmml-definition-load]') !== null]).toEqual([true, true, true]);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    typeInto(fixture, host, '[data-pmml-definition-class]', 'Probe.Pmml');
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    typeInto(fixture, host, '[data-pmml-definition-text]', '<PMML/>');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
  });

  it('posts the typed class and the text exactly as typed to the definition route, and closes once the instance applied it', async () => {
    // Mutation (Rule 19): trim or reshape the text before the post -> the body assertion goes red; post to the listing groups' route -> the path assertion goes red.
    const { fixture, host, sent, actions } = mount();
    actions.run(PMML_MODEL_LIST, PMML_MODEL_ADD_ACTION);
    await settle(fixture);
    const text = '<PMML version="4.1">\n\t<Header/>\n</PMML>\n';
    typeInto(fixture, host, '[data-pmml-definition-class]', ' Probe.Pmml ');
    typeInto(fixture, host, '[data-pmml-definition-text]', text);
    confirm(host).click();
    await settle(fixture);
    const posted = sent.filter((entry) => entry.method === 'POST');
    expect(posted.map((entry) => entry.path)).toEqual(['/api/ocupilot/analytics/pmml-models']);
    expect(posted[0].body).toEqual({ Class: 'Probe.Pmml', PMML: text });
    expect(host.querySelector('app-pmml-definition-dialog')).toBeNull();
  });

  it('loads a file\'s text into the PMML field, in the browser', async () => {
    // Mutation (Rule 19): read the file into the class field -> the text assertions go red.
    const { fixture, host, sent, actions } = mount();
    actions.run(PMML_MODEL_LIST, PMML_MODEL_ADD_ACTION);
    await settle(fixture);
    const picker = host.querySelector('[data-pmml-definition-file]') as HTMLInputElement;
    expect(picker.getAttribute('accept')).toBe('.xml,.pmml');
    const file = new File(['<PMML version="4.1"/>'], 'model.pmml', { type: 'application/xml' });
    Object.defineProperty(picker, 'files', { value: [file], configurable: true });
    picker.dispatchEvent(new Event('change'));
    await settle(fixture);
    const field = host.querySelector('[data-pmml-definition-text]') as HTMLTextAreaElement;
    for (let wait = 0; wait < 100 && field.value === ''; wait += 1) {
      await new Promise((resolve) => setTimeout(resolve, 10));
      fixture.detectChanges();
    }
    expect(field.value).toBe('<PMML version="4.1"/>');
    expect((host.querySelector('[data-pmml-definition-class]') as HTMLInputElement).value).toBe('');
    expect(sent).toEqual([]);
  });

  it('draws a refusal as the server sent it, above the fields, and keeps the dialog open', async () => {
    // Mutation (Rule 19): replace the server's reason with a sentence of the dialog's own -> the reason assertion goes red.
    const refused = { kind: 'error', status: 409, code: 'ANALYTICS.PMML.TAKEN', reason: STRINGS.analyticsRefusalPmmlTaken, detail: null } as JsonResult<unknown>;
    const { fixture, host, actions } = mount(refused);
    actions.run(PMML_MODEL_LIST, PMML_MODEL_ADD_ACTION);
    await settle(fixture);
    typeInto(fixture, host, '[data-pmml-definition-class]', 'Probe.Pmml');
    typeInto(fixture, host, '[data-pmml-definition-text]', '<PMML/>');
    confirm(host).click();
    await settle(fixture);
    expect(host.querySelector('[data-pmml-definition-reason]')?.textContent).toContain(STRINGS.analyticsRefusalPmmlTaken);
    expect(host.querySelector('app-pmml-definition-dialog')).not.toBeNull();
  });
});

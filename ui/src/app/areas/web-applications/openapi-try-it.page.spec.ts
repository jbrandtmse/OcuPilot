import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter } from '@angular/router';
import { BehaviorSubject } from 'rxjs';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { encodeEntityId } from '../../core/entity-id';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { MASKED_VALUE } from '../../core/proposal-view';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { TokenStore } from '../../core/token-store';
import { OpenApiViewerPage } from './openapi-viewer.page';

/** The screen this page renders, resolved from the mirror as the shell's outlet resolves it. */
const VIEWER_SCREEN = SCREENS.find((screen) => screen.route === 'web-applications/rest-apis/document')!;

const TOKEN = 'access-token-probe';

interface Parameter {
  readonly name: string;
  readonly in: string;
}

function row(order: number, path: string, verb: string, parameters: readonly Parameter[] = []) {
  return {
    Order: order,
    Path: path,
    Verb: verb,
    Summary: '',
    OperationId: '',
    Parameters: parameters.map((parameter) => ({ ...parameter, required: false, type: 'string' })),
    Responses: [],
  };
}

/** A read answer for a document with `basePath`, one path holding `rows`. */
function answer(basePath: string, rows: readonly ReturnType<typeof row>[]) {
  return { fields: [], rows, truncated: false, banner: '', document: { swagger: '2.0', basePath, paths: { '/x': {} } } };
}

/** Answers every read with `body`. */
class StubApi {
  constructor(private readonly body: unknown) {}

  async requestJson<T>(): Promise<JsonResult<T>> {
    return { kind: 'ok', status: 200, body: this.body as T };
  }
}

class StubScope {
  loaded(): boolean {
    return true;
  }

  namespace(): string {
    return 'HSCUSTOM';
  }

  subscribe(): () => void {
    return () => {};
  }
}

/** A fetch that records each call and answers `reply`, or rejects when `reply` is `null`. */
function stubFetch(reply: { status: number; type: string; body: string } | null) {
  const calls: { url: string; init: RequestInit }[] = [];
  const fetch = vi.fn(async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    if (reply === null) throw new TypeError('Failed to fetch');
    return new Response(reply.body === '' ? null : reply.body, { status: reply.status, headers: { 'content-type': reply.type } });
  });
  vi.stubGlobal('fetch', fetch);
  return calls;
}

async function settle(fixture: ComponentFixture<OpenApiViewerPage>): Promise<void> {
  for (let i = 0; i < 5; i += 1) await Promise.resolve();
  await new Promise((resolve) => setTimeout(resolve, 0));
  fixture.detectChanges();
}

/**
 * The try-it console on the OpenAPI document viewer (Story 16.1, AD-57): the closed disclosure, one
 * labelled field per declared parameter, a GET sent with the tab's own token and its answer as text
 * on the code surface, a write held for its confirmation, the two refusals in place of Send, the
 * traversal refusal at its field, every secret masked in the record, a request that got no answer,
 * and a service listed by package name having no console. The live round trip is the browser
 * spec's.
 *
 * Mutations (Rule 19): bind the answer with `[innerHTML]` -> the markup-as-text case goes red; show
 * Send whatever `refusal` answers -> the two refusal cases go red; send a write without the dialog
 * -> the confirmation case goes red; bind a field with `[attr.value]` -> the secrets case goes red.
 */
describe('OpenApiViewerPage try-it console', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  /** The route parameters the last `mount` stubbed, so a case can open another document. */
  let routeParams = new BehaviorSubject(convertToParamMap({}));

  function mount(application: string, body: unknown) {
    const params = new BehaviorSubject(convertToParamMap({ id: decodeURIComponent(encodeEntityId(application)) }));
    routeParams = params;
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: ApiService, useValue: new StubApi(body) as unknown as ApiService },
        { provide: ScopeService, useValue: new StubScope() as unknown as ScopeService },
        { provide: NavigationService, useValue: { screenForUrl: () => VIEWER_SCREEN } as unknown as NavigationService },
        { provide: ScreenActions, useValue: new ScreenActions() },
        { provide: OverlayStack, useValue: new OverlayStack() },
        { provide: TokenStore, useValue: { accessToken: () => TOKEN } as unknown as TokenStore },
        {
          provide: ActivatedRoute,
          useValue: { paramMap: params.asObservable(), get snapshot() { return { paramMap: params.value }; } },
        },
      ],
    });
    const fixture = TestBed.createComponent(OpenApiViewerPage);
    fixture.detectChanges();
    return fixture;
  }

  const all = (fixture: ComponentFixture<OpenApiViewerPage>, marker: string): HTMLElement[] =>
    Array.from(fixture.nativeElement.querySelectorAll(`[data-ocu-try-it="${marker}"]`)) as HTMLElement[];
  const one = (fixture: ComponentFixture<OpenApiViewerPage>, marker: string): HTMLElement | null =>
    fixture.nativeElement.querySelector(`[data-ocu-try-it="${marker}"]`) as HTMLElement | null;
  const textOf = (node: Element | null): string => (node?.textContent ?? '').trim();

  /** Mount `application`'s document, open its one path and the first operation's console. */
  async function opened(application: string, body: unknown): Promise<ComponentFixture<OpenApiViewerPage>> {
    const fixture = mount(application, body);
    await settle(fixture);
    (fixture.nativeElement.querySelector('[data-ocu-openapi="path"]') as HTMLElement).click();
    fixture.detectChanges();
    all(fixture, 'toggle')[0].click();
    fixture.detectChanges();
    return fixture;
  }

  function type(fixture: ComponentFixture<OpenApiViewerPage>, field: HTMLInputElement | HTMLTextAreaElement, value: string): void {
    field.value = value;
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
  }

  it('each operation carries a closed Try it disclosure that opens to one labelled field per declared parameter', async () => {
    const fixture = mount('/api/probe', answer('/api/probe', [row(1, '/x/{id}', 'post', [{ name: 'id', in: 'path' }, { name: 'limit', in: 'query' }, { name: 'payload', in: 'body' }]), row(2, '/x/{id}', 'get')]));
    await settle(fixture);
    (fixture.nativeElement.querySelector('[data-ocu-openapi="path"]') as HTMLElement).click();
    fixture.detectChanges();
    const toggles = all(fixture, 'toggle');
    expect(toggles.map((toggle) => textOf(toggle))).toEqual([STRINGS.tryItToggle, STRINGS.tryItToggle]);
    expect(toggles.map((toggle) => toggle.getAttribute('aria-expanded'))).toEqual(['false', 'false']);
    expect(one(fixture, 'console')).toBeNull();

    toggles[0].click();
    fixture.detectChanges();
    expect(toggles[0].getAttribute('aria-expanded')).toBe('true');
    const fields = all(fixture, 'field') as HTMLInputElement[];
    const labels = fields.map((field) => textOf(fixture.nativeElement.querySelector(`label[for="${field.id}"]`)));
    expect(labels).toEqual(['id', 'limit']);
    const bodyField = one(fixture, 'body') as HTMLTextAreaElement;
    expect(textOf(fixture.nativeElement.querySelector(`label[for="${bodyField.id}"]`))).toBe(STRINGS.tryItBody);
    expect(textOf(one(fixture, 'send'))).toBe(STRINGS.actionSend);
  });

  it('a GET is sent with the tab\'s token and no cookie, and its answer renders as text: markup issues no request', async () => {
    const calls = stubFetch({ status: 200, type: 'application/json', body: '"<img src=x onerror=alert(1)>"' });
    const fixture = await opened('/api/probe', answer('/api/probe', [row(1, '/x', 'get')]));
    one(fixture, 'send')!.click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].url).toBe(`${document.location.origin}/api/probe/x`);
    expect(calls[0].init).toMatchObject({ method: 'GET', credentials: 'omit', redirect: 'manual', headers: { Authorization: `Bearer ${TOKEN}` } });
    const shown = one(fixture, 'answer')!;
    expect(shown.tagName).toBe('PRE');
    expect(shown.classList.contains('ocu-try-it-code')).toBe(true);
    expect(textOf(shown).startsWith('200')).toBe(true);
    expect(textOf(shown)).toContain('"<img src=x onerror=alert(1)>"');
    expect(fixture.nativeElement.querySelector('img')).toBeNull();
    expect(calls).toHaveLength(1);
    expect(textOf(one(fixture, 'record'))).toContain(`GET ${document.location.origin}/api/probe/x`);
    expect(fixture.nativeElement.outerHTML).not.toContain(TOKEN);
  });

  it('a write is held for a dialog naming its verb and URL: Cancel sends nothing, Send sends it once', async () => {
    const calls = stubFetch({ status: 204, type: '', body: '' });
    const fixture = await opened('/api/probe', answer('/api/probe', [row(1, '/x', 'delete')]));
    one(fixture, 'send')!.click();
    await settle(fixture);
    const heading = fixture.nativeElement.querySelector('[role="dialog"] .ocu-dialog-title') as HTMLElement;
    expect(textOf(heading)).toBe(`Send DELETE ${document.location.origin}/api/probe/x?`);
    expect(calls).toHaveLength(0);
    (fixture.nativeElement.querySelector('[role="dialog"] .ocu-dialog-actions button') as HTMLElement).click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('[role="dialog"]')).toBeNull();
    expect(calls).toHaveLength(0);

    one(fixture, 'send')!.click();
    fixture.detectChanges();
    one(fixture, 'confirm')!.click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].init.method).toBe('DELETE');
    expect(textOf(one(fixture, 'answer')).startsWith('204')).toBe(true);
  });

  it('a write to the admin API shows its refusal in place of Send, and a read there is offered', async () => {
    const fixture = await opened('/api/admin', answer('/api/admin', [row(1, '/v2/web-app', 'delete'), row(2, '/v2/web-app', 'get')]));
    expect(one(fixture, 'send')).toBeNull();
    expect(textOf(one(fixture, 'refusal'))).toBe(STRINGS.tryItAdminWrite);
    all(fixture, 'toggle')[1].click();
    fixture.detectChanges();
    expect(all(fixture, 'send')).toHaveLength(1);
  });

  it('OcuPilot\'s own application offers no Send on any operation, and a composed path under it is refused', async () => {
    const own = await opened('/api/ocupilot', answer('/api/ocupilot', [row(1, '/instance', 'get')]));
    expect(one(own, 'send')).toBeNull();
    expect(textOf(one(own, 'refusal'))).toBe(STRINGS.tryItOwnApplication);

    TestBed.resetTestingModule();
    const other = await opened('/api/probe', answer('/api/probe', [row(1, '/{a}/{b}', 'get', [{ name: 'a', in: 'path' }, { name: 'b', in: 'path' }])]));
    const fields = all(other, 'field') as HTMLInputElement[];
    type(other, fields[0], '%2e%2e%2F%2e%2e%2Focupilot');
    expect(one(other, 'send')).toBeNull();
    expect(textOf(one(other, 'refusal'))).toBe(STRINGS.tryItOwnApplication);
  });

  it('a path parameter of .. is refused at its field and Send sends nothing', async () => {
    const calls = stubFetch({ status: 200, type: 'text/plain', body: '' });
    const fixture = await opened('/api/probe', answer('/api/probe', [row(1, '/x/{id}', 'get', [{ name: 'id', in: 'path' }])]));
    const field = one(fixture, 'field') as HTMLInputElement;
    type(fixture, field, '..');
    expect(field.getAttribute('aria-invalid')).toBe('true');
    const error = one(fixture, 'traversal')!;
    expect(textOf(error)).toBe(STRINGS.tryItTraversal);
    expect(field.getAttribute('aria-describedby')).toBe(error.id);
    expect(one(fixture, 'send')!.getAttribute('aria-disabled')).toBe('true');
    one(fixture, 'send')!.click();
    await settle(fixture);
    expect(calls).toHaveLength(0);
  });

  it('every secret the request carries is masked in the record, and the DOM holds it only in its field', async () => {
    const calls = stubFetch({ status: 200, type: 'application/json', body: '{}' });
    const fixture = await opened(
      '/api/probe',
      answer('/api/probe', [row(1, '/x', 'post', [{ name: 'apiKey', in: 'query' }, { name: 'X-Token', in: 'header' }])])
    );
    const [apiKey, token] = all(fixture, 'field') as HTMLInputElement[];
    type(fixture, apiKey, 'secret-query-value');
    type(fixture, token, 'secret-header-value');
    type(fixture, one(fixture, 'body') as HTMLTextAreaElement, '{"Password":"secret-body-value","User":"me"}');
    one(fixture, 'send')!.click();
    fixture.detectChanges();
    one(fixture, 'confirm')!.click();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].url).toContain('apiKey=secret-query-value');
    const record = textOf(one(fixture, 'record'));
    expect(record).toContain(`apiKey=${MASKED_VALUE}`);
    expect(record).toContain('"User": "me"');
    const html = fixture.nativeElement.outerHTML as string;
    for (const secret of ['secret-query-value', 'secret-header-value', 'secret-body-value', TOKEN]) {
      expect(html).not.toContain(secret);
    }
    expect(apiKey.value).toBe('secret-query-value');
  });

  it('a request that gets no answer says so and invents no status', async () => {
    stubFetch(null);
    const fixture = await opened('/api/probe', answer('/api/probe', [row(1, '/x', 'get')]));
    one(fixture, 'send')!.click();
    await settle(fixture);
    expect(textOf(one(fixture, 'failed'))).toBe(STRINGS.tryItFailed);
    expect(one(fixture, 'answer')).toBeNull();
  });

  it('the answer shows a non-text body as its byte count and marks a text body cut at its cap', async () => {
    stubFetch({ status: 200, type: 'image/png', body: 'abc' });
    const binary = await opened('/api/probe', answer('/api/probe', [row(1, '/x', 'get')]));
    one(binary, 'send')!.click();
    await settle(binary);
    expect(textOf(one(binary, 'binary'))).toBe(STRINGS.tryItBinary.replace('<n>', '3'));
    expect(textOf(one(binary, 'answer'))).not.toContain('abc');
    expect(one(binary, 'cut')).toBeNull();

    TestBed.resetTestingModule();
    stubFetch({ status: 200, type: 'text/plain', body: 'A'.repeat(256 * 1024 + 1) });
    const long = await opened('/api/probe', answer('/api/probe', [row(1, '/x', 'get')]));
    one(long, 'send')!.click();
    await settle(long);
    expect(textOf(one(long, 'cut'))).toBe(STRINGS.tryItCut);
    expect(one(long, 'binary')).toBeNull();
  });

  it('a request is addressed under the document\'s own basePath, and under the application when it declares none', async () => {
    const declared = stubFetch({ status: 200, type: 'text/plain', body: '' });
    const fixture = await opened('/api/probe', answer('/api/declared', [row(1, '/x', 'get')]));
    one(fixture, 'send')!.click();
    await settle(fixture);
    expect(declared[0].url).toBe(`${document.location.origin}/api/declared/x`);

    TestBed.resetTestingModule();
    const fallback = stubFetch({ status: 200, type: 'text/plain', body: '' });
    const bare = { ...answer('/unused', [row(1, '/x', 'get')]), document: { swagger: '2.0', paths: { '/x': {} } } };
    const other = await opened('/api/probe', bare);
    one(other, 'send')!.click();
    await settle(other);
    expect(fallback[0].url).toBe(`${document.location.origin}/api/probe/x`);
  });

  it('opening another document forgets every console: nothing typed, sent or answered carries over', async () => {
    stubFetch({ status: 200, type: 'text/plain', body: 'first answer' });
    const rows = [row(1, '/x', 'get', [{ name: 'apiKey', in: 'query' }])];
    const fixture = await opened('/api/probe', answer('/api/probe', rows));
    type(fixture, one(fixture, 'field') as HTMLInputElement, 'typed-in-first');
    one(fixture, 'send')!.click();
    await settle(fixture);
    expect(one(fixture, 'answer')).not.toBeNull();

    routeParams.next(convertToParamMap({ id: decodeURIComponent(encodeEntityId('/api/second')) }));
    await settle(fixture);
    (fixture.nativeElement.querySelector('[data-ocu-openapi="path"]') as HTMLElement).click();
    fixture.detectChanges();
    expect(all(fixture, 'toggle').map((toggle) => toggle.getAttribute('aria-expanded'))).toEqual(['false']);
    all(fixture, 'toggle')[0].click();
    fixture.detectChanges();
    expect((one(fixture, 'field') as HTMLInputElement).value).toBe('');
    expect(one(fixture, 'record')).toBeNull();
    expect(one(fixture, 'answer')).toBeNull();
    expect(fixture.nativeElement.outerHTML).not.toContain('first answer');
  });

  it('a service listed by package name has no console, and says why once', async () => {
    const fixture = mount('HS.Probe.REST.v1', answer('/csp/probe/api', [row(1, '/x', 'get')]));
    await settle(fixture);
    (fixture.nativeElement.querySelector('[data-ocu-openapi="path"]') as HTMLElement).click();
    fixture.detectChanges();
    expect(all(fixture, 'toggle')).toHaveLength(0);
    expect(all(fixture, 'no-address').map((node) => textOf(node))).toEqual([STRINGS.tryItNoAddress]);
  });
});

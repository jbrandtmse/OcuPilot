import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { DefinitionFormPage } from './definition-form.page';

/**
 * The Definition form over stubs of the two things an instance supplies -- the URL's screen and
 * the HTTP answers. The real store, the real `FormDirty`, the real dialog and the real template
 * run, so the assertions are about rendered DOM rather than about store state (AC1, AC2, AC3).
 */

const PROVIDERS_BODY = {
  providers: [
    {
      key: 'anthropic',
      label: 'Anthropic',
      defaultModel: 'claude-opus-5',
      modelSuggestions: ['claude-opus-5', 'claude-sonnet-5'],
      // The one absolute URL `ui/tools/client-lint.mjs` admits: a fixture endpoint that is never
      // fetched, and which nothing in this spec asks a browser to reach (AD-47, NFR-10).
      defaultEndpoint: 'https://ocupilot.invalid/v1/messages',
      endpointRequired: false,
      canonicalMaxTokens: 32000,
      canonicalTemperature: 0,
      defaultEnvVarName: 'ANTHROPIC_API_KEY',
      defaultCredentialName: 'OcuPilotAnthropic',
      keyPrefix: 'sk-ant-',
      allowsLocal: false,
      keyShapeReason: 'That key is not shaped like a key for this provider: keys for this provider begin with sk-ant-.',
    },
  ],
};

const FORM_SCREEN = {
  descriptor: 'OcuPilot.Screen.Descriptor.AgentDefinitionForm',
  route: 'agent/definitions/edit',
  archetype: 'form-page',
  id: { kind: 'single', parts: [] },
  labelKey: 'agentDefinitionFormLabel',
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** One answer per path prefix; the last matching entry wins so a test can override a default. */
type Answer = (path: string, init: { method?: string; body?: string }) => JsonResult<unknown>;

async function mount(answer: Answer, url = '/agent/definitions/edit') {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return answer(path, init) as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => FORM_SCREEN } as unknown as NavigationService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(DefinitionFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, formDirty, host: fixture.nativeElement as HTMLElement };
}

const ok = (body: unknown): JsonResult<unknown> => ({ kind: 'ok', status: 200, body });

const created = (body: unknown): JsonResult<unknown> => ({ kind: 'ok', status: 201, body });

const refused = (violations: unknown[]): JsonResult<unknown> => ({
  kind: 'error',
  status: 422,
  code: 'AGENT.VALIDATION',
  reason: 'The agent definition was refused',
  detail: { violations },
});

const definition = (overrides: Record<string, unknown> = {}) => ({
  id: '7',
  name: 'Claude',
  provider: 'anthropic',
  model: 'claude-opus-5',
  endpointUrl: 'https://ocupilot.invalid/v1/messages',
  markedLocal: false,
  credType: 'creds',
  envVarName: '',
  credentialName: 'OcuPilotAnthropic',
  maxTokens: 32000,
  temperature: 0,
  maxIterationsPerTurn: 10,
  systemPromptOverride: '',
  readOnly: true,
  retentionDays: 30,
  enabled: false,
  connectionVerified: false,
  default: false,
  ...overrides,
});

const catalogOnly: Answer = (path) =>
  path.endsWith('/agent/providers') ? ok(PROVIDERS_BODY) : ok({ definitions: [] });

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('the Definition form', () => {
  it('AC1: the six fields above the fold precede the Advanced disclosure, which is closed on first render', async () => {
    const { host } = await mount(catalogOnly);

    const labels = [...host.querySelectorAll('.ocu-field-label')].map((label) => label.textContent?.trim());
    expect(labels).toEqual([
      STRINGS.tableColumnName,
      STRINGS.tableColumnProvider,
      STRINGS.tableColumnModel,
      STRINGS.agentDefinitionFieldEndpoint,
      STRINGS.agentDefinitionFieldApiKey,
    ]);

    const disclosure = host.querySelector('.ocu-form-disclosure');
    expect(disclosure?.textContent?.trim()).toBe(STRINGS.agentDefinitionAdvanced);
    expect(disclosure?.getAttribute('aria-expanded')).toBe('false');

    // Test connection is above the fold, and before the disclosure in the document.
    const order = [...host.querySelectorAll('.ocu-form-test button, .ocu-form-disclosure')];
    expect(order[0]?.textContent?.trim()).toBe(STRINGS.actionTestConnection);
    expect(order[1]?.classList.contains('ocu-form-disclosure')).toBe(true);

    // Mutation (Rule 19): set the disclosure's initial expanded state to true -> this goes red,
    // the five Advanced fields being in the document before anyone asked for them.
    expect(host.querySelector('#ocu-definition-retentionDays')).toBeNull();
  });

  it('AC1: the Advanced section holds the five tuning fields, and retention is aria-disabled under its caption', async () => {
    const { fixture, host } = await mount(catalogOnly);
    (host.querySelector('.ocu-form-disclosure') as HTMLButtonElement).click();
    await settle(fixture);

    const advanced = host.querySelector('#ocu-definition-advanced') as HTMLElement;
    const labels = [...advanced.querySelectorAll('.ocu-field-label')].map((label) => label.textContent?.trim());
    expect(labels).toEqual([
      STRINGS.agentDefinitionFieldMaxTokens,
      STRINGS.agentDefinitionFieldTemperature,
      STRINGS.agentDefinitionFieldMaxIterations,
      STRINGS.agentDefinitionFieldSystemPrompt,
      STRINGS.agentDefinitionFieldRetention,
    ]);

    const retention = host.querySelector('#ocu-definition-retentionDays') as HTMLInputElement;
    expect(retention.getAttribute('aria-disabled')).toBe('true');
    expect(retention.hasAttribute('disabled')).toBe(false);
    expect(host.querySelector('#ocu-definition-retentionDays-caption')?.textContent?.trim()).toBe(
      STRINGS.agentDefinitionRetentionCaption.replace('<n>', '30')
    );
  });

  it('DW-340: the key field is masked and empty, and its reveal toggle is labelled', async () => {
    const { fixture, host } = await mount(catalogOnly);
    const key = host.querySelector('#ocu-definition-apiKey') as HTMLInputElement;
    expect(key.getAttribute('type')).toBe('password');
    expect(key.value).toBe('');
    // The published "Stored." caption is the masked field's state AFTER save, and this is a create
    // route: nothing is stored, so there is nothing a new value would replace. Rendering it here
    // would state a falsehood on the one field where a false statement matters most, and it is
    // wired into `aria-describedby`, so it would be read out as well as shown. The edit route's
    // own case below is where the caption is asserted to appear.
    expect(host.querySelector('#ocu-definition-apiKey-caption')).toBeNull();
    expect(key.getAttribute('aria-describedby')).toBeNull();

    const toggle = host.querySelector('.ocu-reveal-toggle') as HTMLButtonElement;
    expect(toggle.getAttribute('aria-label')).toBe(STRINGS.agentDefinitionShowKey);
    expect(toggle.getAttribute('aria-pressed')).toBe('false');
    toggle.click();
    await settle(fixture);
    expect((host.querySelector('#ocu-definition-apiKey') as HTMLInputElement).getAttribute('type')).toBe('text');
    expect((host.querySelector('.ocu-reveal-toggle') as HTMLButtonElement).getAttribute('aria-label')).toBe(
      STRINGS.agentDefinitionHideKey
    );
  });

  it('AD-35: opening an existing definition never echoes a key, even one a response body carries', async () => {
    // DW-340's own test above mounts a create route, which never issues a `GET :id` at all --
    // `store.open('')` returns from `applyProviderDefaults` alone, so that test cannot tell "the
    // key is discarded" apart from "nothing was ever read to discard it from". This is the case
    // that can: a real `GET :id` answer, absorbed for every other field, that also happens to
    // carry `apiKey` -- the shape a server bug or a future field-list slip could produce. `apiKey`
    // is not in `WRITABLE_FIELDS` (`definition-form.store.ts`), so `absorb()` never reads it into
    // anything the key input renders.
    const answer: Answer = (path) =>
      path.endsWith('/agent/providers')
        ? ok(PROVIDERS_BODY)
        : ok(definition({ apiKey: 'sk-ant-hidden-leak-should-never-render' }));
    const { host } = await mount(answer, '/agent/definitions/edit/7');

    const key = host.querySelector('#ocu-definition-apiKey') as HTMLInputElement;
    expect(key.value).toBe('');
    expect(key.getAttribute('type')).toBe('password');
    expect(host.textContent).not.toContain('sk-ant-hidden-leak-should-never-render');

    // On an edit route a key IS stored, so the published caption is true here and describes the
    // field. Mutation (Rule 19): make `showStoredCaption` return `true` unconditionally -> the
    // create-route case above goes red instead, which is the pair that says the caption tracks
    // the form's mode rather than being absent or present everywhere.
    expect(host.querySelector('#ocu-definition-apiKey-caption')?.textContent?.trim()).toBe(
      STRINGS.formSecretStored
    );
    expect(key.getAttribute('aria-describedby')).toBe('ocu-definition-apiKey-caption');

    // Mutation (Rule 19): read `apiKey` off the loaded record into the key field in `absorb()`
    // (e.g. `this.keyValue = textAt(record, 'apiKey')`) -> this goes red, the stray value
    // rendering in the input DW-340 requires to stay write-only.
  });

  it('DW-339: the inline key-shape check renders the server\'s own sentence on the key field, on blur', async () => {
    const { fixture, host } = await mount(catalogOnly);
    const key = host.querySelector('#ocu-definition-apiKey') as HTMLInputElement;
    key.value = 'not-a-key';
    key.dispatchEvent(new Event('input'));
    await settle(fixture);
    expect(host.querySelector('#ocu-definition-apiKey-reason')).toBeNull();

    key.dispatchEvent(new Event('blur'));
    await settle(fixture);
    const reason = host.querySelector('#ocu-definition-apiKey-reason');
    expect(reason?.textContent?.trim()).toBe(PROVIDERS_BODY.providers[0].keyShapeReason);
    const field = host.querySelector('#ocu-definition-apiKey') as HTMLInputElement;
    expect(field.getAttribute('aria-invalid')).toBe('true');
    // A create route carries no "Stored." caption, so the refusal is the whole description.
    expect(field.getAttribute('aria-describedby')).toBe('ocu-definition-apiKey-reason');
  });

  it('AC2: a refused Save shows the error summary, names each field, and wires aria-invalid and aria-describedby', async () => {
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'POST') {
        return refused([
          { field: 'name', code: 'AGENT.NAME.REQUIRED', reason: 'Give the definition a name of 1 to 64 characters.' },
          { field: 'endpointUrl', code: 'AGENT.ENDPOINT.SCHEME', reason: 'The endpoint is an absolute https:// address with no user name in it.' },
        ]);
      }
      return ok({ definitions: [] });
    };
    const { fixture, host } = await mount(answer);
    const save = [...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement;
    save.click();
    await settle(fixture);

    const summary = host.querySelector('.ocu-form-summary') as HTMLElement;
    expect(summary).not.toBeNull();
    expect(summary.getAttribute('role')).toBe('alert');
    const links = [...summary.querySelectorAll('button')].map((link) => link.textContent?.trim());
    expect(links).toEqual([
      'Give the definition a name of 1 to 64 characters.',
      'The endpoint is an absolute https:// address with no user name in it.',
    ]);

    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    expect(name.getAttribute('aria-invalid')).toBe('true');
    expect(name.getAttribute('aria-describedby')).toBe('ocu-definition-name-reason');
    expect(host.querySelector('#ocu-definition-name-reason')?.textContent?.trim()).toBe(
      'Give the definition a name of 1 to 64 characters.'
    );
    const model = host.querySelector('#ocu-definition-model') as HTMLInputElement;
    expect(model.getAttribute('aria-invalid')).toBe('false');
    expect(model.getAttribute('aria-describedby')).toBeNull();
  });

  it('AC3: a create sends no `enabled`, and the sticky bar reads pending-test because the body does', async () => {
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'POST') return created(definition({ enabled: false }));
      return ok({ definitions: [] });
    };
    const { fixture, host, calls } = await mount(answer);
    const save = [...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement;
    expect(save.textContent?.trim()).toBe(STRINGS.actionCreate);
    save.click();
    await settle(fixture);

    const posted = calls.find((call) => call.method === 'POST');
    expect(posted).toBeDefined();
    expect(JSON.parse(posted!.body)).not.toHaveProperty('enabled');
    expect(host.querySelector('.ocu-form-bar-status')?.textContent?.trim()).toContain(STRINGS.formSavedPendingTest);
  });

  it('AC3: an edit whose answer reads enabled renders the saved sentence, and one that does not renders pending-test', async () => {
    const enabledAnswer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'PUT') return ok(definition({ enabled: true }));
      return ok(definition());
    };
    const enabled = await mount(enabledAnswer, '/agent/definitions/edit/7');
    const save = [...enabled.host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement;
    expect(save.textContent?.trim()).toBe(STRINGS.actionSave);
    save.click();
    await settle(enabled.fixture);
    expect(enabled.host.querySelector('.ocu-form-bar-status')?.textContent?.trim()).toContain(STRINGS.formSaved);

    // Mutation (Rule 19): render `formSaved` regardless of the response body's `enabled` -> this
    // leg goes red. The request carried `enabled: true`; the answer says otherwise, and the answer
    // is what is rendered (DW-359's sibling rule).
    const clearedAnswer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'PUT') return ok(definition({ enabled: false }));
      return ok(definition({ enabled: true }));
    };
    const cleared = await mount(clearedAnswer, '/agent/definitions/edit/7');
    const clearedSave = [...cleared.host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement;
    clearedSave.click();
    await settle(cleared.fixture);
    expect(cleared.host.querySelector('.ocu-form-bar-status')?.textContent?.trim()).toContain(
      STRINGS.formSavedPendingTest
    );
  });

  it('AC3: the first definition ever saved is offered Go to Home, and a later one is not', async () => {
    const firstAnswer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'POST') return created(definition());
      return ok({ definitions: [] });
    };
    const first = await mount(firstAnswer);
    ([...first.host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(first.fixture);
    expect(first.host.querySelector('.ocu-form-bar-status')?.textContent).toContain(STRINGS.formGoToHome);

    const laterAnswer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'POST') return created(definition());
      return ok({ definitions: [{ id: '1' }] });
    };
    const later = await mount(laterAnswer);
    ([...later.host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(later.fixture);
    expect(later.host.querySelector('.ocu-form-bar-status')?.textContent).not.toContain(STRINGS.formGoToHome);
  });

  it('DW-354: Test connection on a create route creates, stores the key and tests, in that order', async () => {
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (path.endsWith('/credential')) return ok({ stored: true });
      if (path.endsWith('/test')) {
        return ok({ connected: true, reply: 'Hello', replyTruncated: false, latencyMs: 12, connectionVerified: true, testedAsStored: true });
      }
      if (init.method === 'POST') return created(definition());
      return ok(definition());
    };
    const { fixture, host, calls } = await mount(answer);
    const key = host.querySelector('#ocu-definition-apiKey') as HTMLInputElement;
    key.value = 'sk-ant-probe';
    key.dispatchEvent(new Event('input'));
    await settle(fixture);
    (host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
    await settle(fixture);

    const writes = calls.filter((call) => call.method === 'POST').map((call) => call.path);
    expect(writes).toEqual([
      '/api/ocupilot/agent/definitions',
      '/api/ocupilot/agent/definitions/7/credential',
      '/api/ocupilot/agent/definitions/7/test',
    ]);
    expect(host.querySelector('.ocu-form-test-result')?.textContent?.trim()).toBe(
      STRINGS.formTestConnectionResult.replace("<the model's first words>", 'Hello')
    );
    expect((host.querySelector('#ocu-definition-apiKey') as HTMLInputElement).value).toBe('');
  });

  it('DW-340: a pasted key is stored on the credential route exactly as typed, stray whitespace included', async () => {
    // "A paste is not trimmed" (Boundaries & Constraints) means the value that reaches
    // `POST :id/credential` is the operator's own bytes -- a client that silently trimmed would
    // store a key the operator never saw and never agreed to (the store's own doc comment says
    // the same). A key the server then refuses by shape is a sentence the operator can act on;
    // one silently altered before it ever left the browser is not.
    const PASTED_WITH_STRAY_SPACE = ' sk-ant-probe-pasted ';
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (path.endsWith('/credential')) return ok({ stored: true });
      if (path.endsWith('/test')) {
        return ok({ connected: true, reply: 'Hello', replyTruncated: false, latencyMs: 12, connectionVerified: true, testedAsStored: true });
      }
      if (init.method === 'POST') return created(definition());
      return ok(definition());
    };
    const { fixture, host, calls } = await mount(answer);
    const key = host.querySelector('#ocu-definition-apiKey') as HTMLInputElement;
    key.value = PASTED_WITH_STRAY_SPACE;
    key.dispatchEvent(new Event('input'));
    await settle(fixture);
    (host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
    await settle(fixture);

    const credentialCall = calls.find((call) => call.path.endsWith('/credential'));
    expect(credentialCall, 'the key was stored on its own route').not.toBeUndefined();
    expect(JSON.parse(credentialCall!.body)).toEqual({ apiKey: PASTED_WITH_STRAY_SPACE });

    // Mutation (Rule 19): trim the value in `DefinitionForm.setKey()` -> this goes red, the
    // credential body carrying 'sk-ant-probe-pasted' with the operator's own spaces gone.
  });

  it("DW-355: PROVIDER.REFUSED with provider text takes the published sentence; every other code renders the envelope's reason", async () => {
    const withText: Answer = (path) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (path.endsWith('/test')) {
        return {
          kind: 'error',
          status: 502,
          code: 'PROVIDER.REFUSED',
          reason: 'The provider refused the request',
          detail: { providerText: 'invalid x-api-key' },
        };
      }
      return ok(definition());
    };
    const refusedByProvider = await mount(withText, '/agent/definitions/edit/7');
    (refusedByProvider.host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
    await settle(refusedByProvider.fixture);
    expect(refusedByProvider.host.querySelector('.ocu-form-test .ocu-form-error')?.textContent?.trim()).toBe(
      STRINGS.formTestConnectionFailure.replace('<text>', 'invalid x-api-key')
    );

    // Mutation (Rule 19): render `formTestConnectionFailure` for every PROVIDER.* code -> this leg
    // goes red on the empty "Provider said:" tail.
    const tlsAnswer: Answer = (path) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (path.endsWith('/test')) {
        return {
          kind: 'error',
          status: 503,
          code: 'PROVIDER.TLS',
          reason: "The TLS configuration this instance's provider calls are made through is not present",
          detail: null,
        };
      }
      return ok(definition());
    };
    const tls = await mount(tlsAnswer, '/agent/definitions/edit/7');
    (tls.host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
    await settle(tls.fixture);
    expect(tls.host.querySelector('.ocu-form-test .ocu-form-error')?.textContent?.trim()).toBe(
      "The TLS configuration this instance's provider calls are made through is not present"
    );
  });

  it('AC2: typing raises the dirty flag, and the leave confirmation renders with both actions', async () => {
    const { fixture, host, formDirty } = await mount(catalogOnly);
    expect(formDirty.dirty()).toBe(false);
    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    name.value = 'Claude';
    name.dispatchEvent(new Event('input'));
    await settle(fixture);
    expect(formDirty.dirty()).toBe(true);

    const asked = formDirty.requestLeave();
    await settle(fixture);
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement;
    expect(dialog).not.toBeNull();
    expect(dialog.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.formLeaveWithoutSaving);
    const actions = [...dialog.querySelectorAll('.ocu-dialog-actions button')].map((button) => button.textContent?.trim());
    expect(actions).toEqual([STRINGS.actionCancel, STRINGS.actionConfirm]);

    (dialog.querySelectorAll('.ocu-dialog-actions button')[0] as HTMLButtonElement).click();
    await settle(fixture);
    expect(await asked).toBe(false);
    expect(formDirty.dirty()).toBe(true);
    expect(host.querySelector('[role="dialog"]')).toBeNull();
  });

  it("DW-359: a test that passed against edited values renders the connect sentence and leaves the bar pending", async () => {
    // The definition is verified and enabled as stored, and the operator has since edited the
    // endpoint -- a security field. The port compares what it tested against what is stored, so it
    // answers `connectionVerified: true` (the stored row's flag) beside `testedAsStored: false`
    // (the values tested were not the stored ones). Read together those two read as "verified and
    // up to date", which the stored row is not.
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (path.endsWith('/test')) {
        return ok({
          connected: true,
          reply: 'Hello',
          replyTruncated: false,
          latencyMs: 12,
          connectionVerified: true,
          testedAsStored: false,
        });
      }
      // The PUT that carried the edited endpoint: the instance cleared both flags, so the body
      // that comes back reads disabled whatever was sent.
      if (init.method === 'PUT') return ok(definition({ enabled: false, connectionVerified: false }));
      return ok(definition({ enabled: false, connectionVerified: false }));
    };
    const { fixture, host } = await mount(answer, '/agent/definitions/edit/7');
    (([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1)) as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('.ocu-form-bar-status')?.textContent).toContain(STRINGS.formSavedPendingTest);

    (host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
    await settle(fixture);

    // The sentence describes the call just made, which is what `testedAsStored` is about.
    expect(host.querySelector('.ocu-form-test-result')?.textContent?.trim()).toBe(
      STRINGS.formTestConnectionResult.replace("<the model's first words>", 'Hello')
    );
    // Mutation (Rule 19): let a passing test set the outcome to `saved` from the test body's
    // `connectionVerified` -> this goes red, the bar reading the plain saved sentence.
    expect(host.querySelector('.ocu-form-bar-status')?.textContent?.trim()).toBe(STRINGS.formSavedPendingTest);
    // The flag is not a field and reaches no surface at all (DW-359's decision).
    expect(host.textContent).not.toContain('connectionVerified');
  });

  it('AC2: a Save that leaves a pasted key unstored keeps the form dirty', async () => {
    // Save posts `WRITABLE_FIELDS`, and the key is not one of them -- it travels on its own
    // route, spent only by Test connection. So a Save with a key in the field succeeds while the
    // key is still unstored work, and clearing the dirty flag over it would let the leave guard
    // wave the operator off the page and drop it without a word (DW-340).
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'POST') return created(definition());
      return ok({ definitions: [] });
    };
    const { fixture, host, formDirty } = await mount(answer);
    const key = host.querySelector('#ocu-definition-apiKey') as HTMLInputElement;
    key.value = 'sk-ant-pasted-and-never-stored';
    key.dispatchEvent(new Event('input'));
    await settle(fixture);

    ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(fixture);

    expect(host.querySelector('.ocu-form-bar-status')?.textContent).toContain(STRINGS.formSavedPendingTest);
    // Mutation (Rule 19): put back `this.formDirty.setDirty(false)` in `save()` -> this goes red,
    // and the pasted key leaves with the operator on the next navigation, unasked about.
    expect(formDirty.dirty()).toBe(true);
    expect((host.querySelector('#ocu-definition-apiKey') as HTMLInputElement).value).toBe(
      'sk-ant-pasted-and-never-stored'
    );
  });

  it('AC3: the first definition, created by Test connection rather than by Save, is offered Go to Home', async () => {
    // The published gate landing tells the administrator to paste a key and press Test connection,
    // with no Save between, so the first definition on an instance is created by that sequence.
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (path.endsWith('/test')) {
        return ok({ connected: true, reply: 'Hello', replyTruncated: false, latencyMs: 9, connectionVerified: true, testedAsStored: true });
      }
      if (init.method === 'POST') return created(definition());
      return ok({ definitions: [] });
    };
    const { fixture, host } = await mount(answer);
    (host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
    await settle(fixture);

    // Mutation (Rule 19): remove `this.firstSaveValue = this.instanceWasEmpty;` from
    // `testConnection()`'s create branch -> this goes red, and the offer never appears on the one
    // path the gate actually takes: by the time Save runs, the route is an editor and the store
    // is no longer creating.
    expect(host.querySelector('.ocu-form-bar-status')?.textContent).toContain(STRINGS.formGoToHome);
  });

  it('a Test connection refused after the definition was created still puts the new id in the route', async () => {
    // The first leg of the sequence creates the definition. Leaving the browser on the create
    // route over a definition that now exists means a reload opens an empty create form, and the
    // next Save writes a second one.
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (path.endsWith('/credential')) {
        return refused([
          { field: 'apiKey', code: 'AGENT.KEY.SHAPE', reason: 'That key is not shaped like a key for this provider.' },
        ]);
      }
      if (init.method === 'POST') return created(definition());
      return ok({ definitions: [] });
    };
    const { fixture, host } = await mount(answer);
    const key = host.querySelector('#ocu-definition-apiKey') as HTMLInputElement;
    key.value = 'nope';
    key.dispatchEvent(new Event('input'));
    await settle(fixture);
    (host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
    await settle(fixture);

    // Mutation (Rule 19): move the route replacement back behind `if (!passed) return;` in
    // `onTest` -> this goes red, the URL still naming the create route.
    expect(TestBed.inject(Router).url).toContain('agent/definitions/edit/7');
    // The refusal is still the one the operator has to act on, and it survives the replacement.
    expect(host.querySelector('.ocu-form-summary')?.textContent).toContain(
      'That key is not shaped like a key for this provider.'
    );
  });

  it('AC2: a refusal on an Advanced field opens the disclosure before focusing it', async () => {
    // The five tuning fields are behind the `@if` that keeps the disclosure closed on first
    // render (AC1), so a refusal on one of them has nothing in the document to focus or to read
    // the inline sentence from. EXPERIENCE.md's form-page rule is that the first invalid field is
    // focused "and its tab opened"; the disclosure is this form's version of that tab.
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'POST') {
        return refused([
          { field: 'maxTokens', code: 'AGENT.MAXTOKENS.RANGE', reason: 'Maximum tokens must be between 1 and 200000.' },
        ]);
      }
      return ok({ definitions: [] });
    };
    const { fixture, host } = await mount(answer);
    expect(host.querySelector('#ocu-definition-maxTokens')).toBeNull();

    ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(fixture);

    // Mutation (Rule 19): drop the `ADVANCED_FIELDS` branch from `focusField` -> these three go
    // red, the summary offering a link that focuses nothing and a sentence that is not rendered.
    expect(host.querySelector('.ocu-form-disclosure')?.getAttribute('aria-expanded')).toBe('true');
    const field = host.querySelector('#ocu-definition-maxTokens') as HTMLInputElement;
    expect(field).not.toBeNull();
    expect(document.activeElement).toBe(field);
    expect(host.querySelector('#ocu-definition-maxTokens-reason')?.textContent?.trim()).toBe(
      'Maximum tokens must be between 1 and 200000.'
    );
  });

  it('a definition that could not be read draws its refusal, and no editable form over it', async () => {
    // Before the read resolves, and after it fails, the buffer holds the class's own defaults --
    // an empty name, no provider, credType `creds`, readOnly true. Drawing the fields over them
    // offers an editable form for a definition nobody has seen, under the id in the URL, and its
    // Save sends those defaults to the instance.
    const answer: Answer = (path) =>
      path.endsWith('/agent/providers')
        ? ok(PROVIDERS_BODY)
        : {
            kind: 'error',
            status: 503,
            code: 'INTERNAL',
            reason: 'OcuPilot could not read that definition.',
            detail: null,
          };
    const { host } = await mount(answer, '/agent/definitions/edit/7');

    // Mutation (Rule 19): drop the `@if (loadedFlag)` around the fields and the sticky bar -> the
    // first two go red, a blank form and an enabled Save rendering over a definition that was
    // never read.
    expect(host.querySelector('#ocu-definition-name')).toBeNull();
    expect(host.querySelector('.ocu-form-bar')).toBeNull();
    expect(host.querySelector('.ocu-banner-warning')?.textContent?.trim()).toBe(
      'OcuPilot could not read that definition.'
    );
  });
});

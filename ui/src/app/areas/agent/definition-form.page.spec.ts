import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { AgentStatus } from '../../core/agent-status';
import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, UNGATED, type Verdict } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { stubAgentStatus } from '../../testing/agent-status';
import { DefinitionFormPage } from './definition-form.page';
import { DefinitionForm } from './definition-form.store';

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
      defaultModel: 'claude-opus-5-5',
      modelSuggestions: ['claude-opus-5-5', 'claude-sonnet-5'],
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

/** Two rows, so choosing a provider is a cascade rather than a no-op (`setProvider` early-returns). */
const TWO_PROVIDERS = {
  providers: [
    PROVIDERS_BODY.providers[0],
    {
      ...PROVIDERS_BODY.providers[0],
      key: 'openai',
      label: 'OpenAI',
      defaultModel: 'gpt-5',
      modelSuggestions: ['gpt-5'],
      defaultEndpoint: 'https://ocupilot.invalid/v1/chat',
      keyPrefix: 'sk-',
    },
  ],
};

/**
 * A plain-`http://` value for the endpoint field. The scheme alone, because the scheme is all
 * `showHttpAcknowledge` reads and `ui/tools/client-lint.mjs`'s off-origin rule holds a closed list
 * of absolute URLs `ui/src` may carry that a plain-http host is not on -- and assembling one past
 * that scanner is the trick this project refuses elsewhere. With no host it names no resource, and
 * nothing here fetches it: it is typed into an input and read back.
 */
const PLAIN_HTTP = 'http://';

/**
 * Two rows where the second licenses a local address and a keyless rung (Story 10.3's
 * `compatible` row). Every other fixture in this file sets `allowsLocal` false, so without this
 * one `localAllowed` is never true and the three controls it gates have no test host at all.
 */
const LOCAL_PROVIDERS = {
  providers: [
    PROVIDERS_BODY.providers[0],
    {
      ...PROVIDERS_BODY.providers[0],
      key: 'compatible',
      label: 'OpenAI-compatible',
      defaultModel: '',
      modelSuggestions: [],
      defaultEndpoint: '',
      endpointRequired: true,
      defaultEnvVarName: 'OPENAI_COMPATIBLE_API_KEY',
      defaultCredentialName: 'OcuPilotCompatible',
      keyPrefix: '',
      allowsLocal: true,
      keyShapeReason: '',
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

/**
 * The map, stubbed down to what this page reads: the screen a URL resolves to, the verdict for
 * `agent/definitions`, and a subscription so a 403's own re-read can reach the gate banner.
 */
function stubNavigation(verdict: Verdict, loaded = true) {
  return {
    screenForUrl: () => FORM_SCREEN,
    // `loaded` and `answered` are separate answers on the live service: a read that FAILED answers
    // `answered()` true with every verdict `UNGATED`, and the gate banner must not turn on that.
    loaded: () => loaded,
    answered: () => true,
    screenVerdict: () => verdict,
    subscribe: () => () => {},
  } as unknown as NavigationService;
}

async function mount(
  answer: Answer,
  url = '/agent/definitions/edit',
  options: { verdict?: Verdict; definitions?: { enabled: boolean }[]; mapLoaded?: boolean } = {}
) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return answer(path, init) as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  // Unanswered unless a test says otherwise, so the gate banner is absent from every assertion
  // in this file that predates it.
  const agentStatus = stubAgentStatus(options.definitions ?? []);
  if (options.definitions !== undefined) await agentStatus.load();
  // The real bus, with every event this form publishes captured: AD-14's action is what the
  // subscribers act on, and nothing else in this file observes a publish (DW-1404).
  const bus = new ChangeBus();
  const changes: { kind: string; action: string; id: string; type: string }[] = [];
  bus.subscribe((event) => {
    changes.push({ kind: event.kind, action: event.action, id: event.id, type: event.type });
  });
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: stubNavigation(options.verdict ?? UNGATED, options.mapLoaded ?? true) },
      { provide: AgentStatus, useValue: agentStatus },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(DefinitionFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, formDirty, agentStatus, changes, host: fixture.nativeElement as HTMLElement };
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

/** The server-authored reason `STATE.CONFLICT` carries, which this screen must never render. */
const CONFLICT_ENVELOPE_REASON =
  'This record changed on the instance after it was read, so the save was refused.';

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

  it('Story 11.10: a create posts readOnly false, and an edit of a read-only definition sends it back true', async () => {
    const createAnswer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'POST') return created(definition({ readOnly: false }));
      return ok({ definitions: [] });
    };
    const create = await mount(createAnswer);
    ([...create.host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(create.fixture);
    const posted = create.calls.find((call) => call.method === 'POST');
    expect(posted).toBeDefined();
    expect(JSON.parse(posted!.body).readOnly).toBe(false);

    const editAnswer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'PUT') return ok(definition({ readOnly: true }));
      return ok(definition({ readOnly: true }));
    };
    const edit = await mount(editAnswer, '/agent/definitions/edit/7');
    ([...edit.host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(edit.fixture);
    const put = edit.calls.find((call) => call.method === 'PUT');
    expect(put).toBeDefined();
    expect(JSON.parse(put!.body).readOnly).toBe(true);
  });

  it('DW-1404: a create publishes `created`, an edit publishes `updated`, and the gate path publishes `created`', async () => {
    // AD-14's action is a closed vocabulary that carries meaning: `created` is the only action
    // that asks the list to put the caret on the new row (`RefreshService.onBusEvent`), and it is
    // the word an off-screen toast reads back. One `publishChange()` served both routes and said
    // `updated` for all of them, so no shipped publisher could ever emit `created`.
    //
    // Mutation (Rule 19): hard-code `'updated'` in `publishChange` again -> the create and
    // gate-path legs go red; the edit leg stays green, which is what makes the three legs
    // together the pin rather than any one of them.
    const createAnswer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'POST') return created(definition({ enabled: false }));
      return ok({ definitions: [] });
    };
    const create = await mount(createAnswer);
    const createSave = [...create.host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement;
    createSave.click();
    await settle(create.fixture);
    expect(create.changes).toEqual([{ kind: 'changed', action: 'created', id: '7', type: 'agent-definition' }]);

    const editAnswer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'PUT') return ok(definition({ enabled: true }));
      return ok(definition());
    };
    const edit = await mount(editAnswer, '/agent/definitions/edit/7');
    const editSave = [...edit.host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement;
    editSave.click();
    await settle(edit.fixture);
    expect(edit.changes).toEqual([{ kind: 'changed', action: 'updated', id: '7', type: 'agent-definition' }]);

    // The gate's own path creates through Test connection, with no Save between (AC3 above), so
    // it is a second create publisher and not a variant of the first.
    const gateAnswer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (path.endsWith('/test')) {
        return ok({ connected: true, reply: 'Hello', replyTruncated: false, latencyMs: 9, connectionVerified: true, testedAsStored: true });
      }
      if (init.method === 'POST') return created(definition());
      return ok({ definitions: [] });
    };
    const gate = await mount(gateAnswer);
    (gate.host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
    await settle(gate.fixture);
    expect(gate.changes.map((change) => change.action)).toEqual(['created']);
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

  it('Story 10.5: a test that waited its bound reads the published sentence, resolved from the detail', async () => {
    const timedOut =
      (code: string, detail: Record<string, unknown> | null): Answer =>
      (path) => {
        if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
        if (path.endsWith('/test')) {
          return { kind: 'error', status: 504, code, reason: 'the envelope reason, not the published sentence', detail };
        }
        return ok(definition());
      };
    const failureAfterPress = async (answer: Answer): Promise<string | undefined> => {
      const mounted = await mount(answer, '/agent/definitions/edit/7');
      (mounted.host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
      await settle(mounted.fixture);
      return mounted.host.querySelector('.ocu-form-test .ocu-form-error')?.textContent?.trim();
    };

    // Mutation (Rule 19): render `reason` for PROVIDER.TESTTIMEOUTLOCAL in `absorbTestRefusal` ->
    // this goes red on the envelope's reason.
    expect(
      await failureAfterPress(
        timedOut('PROVIDER.TESTTIMEOUTLOCAL', { waitedSeconds: 50, providerLabel: 'OpenAI-compatible' })
      )
    ).toBe(STRINGS.agentDefinitionTestTimeoutLocal.replace('<n>', '50'));

    expect(
      await failureAfterPress(timedOut('PROVIDER.TESTTIMEOUT', { waitedSeconds: 50, providerLabel: 'Google Gemini' }))
    ).toBe(STRINGS.agentDefinitionTestTimeout.replace('<provider>', 'Google Gemini').replace('<n>', '50'));

    // Without the detail the sentence cannot be resolved, so the envelope's own reason renders.
    expect(await failureAfterPress(timedOut('PROVIDER.TESTTIMEOUT', null))).toBe(
      'the envelope reason, not the published sentence'
    );
    expect(await failureAfterPress(timedOut('PROVIDER.TESTTIMEOUTLOCAL', { providerLabel: 'x' }))).toBe(
      'the envelope reason, not the published sentence'
    );
    // Mutation (Rule 19): have `testTimeoutText` stringify the label unchecked -> this reads "(undefined)".
    expect(await failureAfterPress(timedOut('PROVIDER.TESTTIMEOUT', { waitedSeconds: 50 }))).toBe(
      'the envelope reason, not the published sentence'
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
    // an empty name, no provider, credType `creds`, readOnly false. Drawing the fields over them
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

  // --- Story 3.6: the gate banner, the legend and the two DW items -----------------------------

  it('AC7 (DW-372): a 403 naming a pair reads the published denied-action sentence, not the envelope\'s reason', async () => {
    // Mutation (Rule 19): return `envelopeReason` for `AUTH.NOPRIVILEGE` -> this goes red, and the
    // form says "Refused" where it could have said which privilege is missing and for what.
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'POST') {
        return {
          kind: 'error',
          status: 403,
          code: 'AUTH.NOPRIVILEGE',
          reason: 'The request was refused.',
          detail: { failedPair: 'OcuPilotAdmin:USE' },
        };
      }
      return ok({ definitions: [] });
    };
    const { fixture, host } = await mount(answer);
    ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(fixture);

    const banner = host.querySelector('.ocu-banner-warning') as HTMLElement;
    expect(banner.textContent?.trim()).toBe('You need OcuPilotAdmin:USE to change this definition.');
    expect(banner.textContent).not.toContain('The request was refused.');
    // Both slots resolved: a sentence still carrying a placeholder is the defect the resolver
    // exists to prevent.
    expect(banner.textContent).not.toContain('<resource>');
    expect(banner.textContent).not.toContain('<action>');
  });

  it("AC7: an AUTH.NOPRIVILEGE that named no pair keeps the server's own reason", async () => {
    // A resolved sentence with an empty resource slot says less than the one the server wrote.
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'POST') {
        return { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'The request was refused.', detail: null };
      }
      return ok({ definitions: [] });
    };
    const { fixture, host } = await mount(answer);
    ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('.ocu-banner-warning')?.textContent?.trim()).toBe('The request was refused.');
  });

  it("DW-388: a save whose row moved renders the published conflict sentence, not the envelope's reason", async () => {
    // Mutation (Rule 19): drop the `conflicted()` test from `reason` in `definition-form.page.ts`,
    // or make `DefinitionForm.conflicted()` answer false -> this goes red, and the form states the
    // server's mechanism where the published sentence names the reload the person has to make.
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'POST' || init.method === 'PUT') {
        return {
          kind: 'error',
          status: 409,
          code: 'STATE.CONFLICT',
          reason: CONFLICT_ENVELOPE_REASON,
          detail: null,
        };
      }
      return ok({ definitions: [] });
    };
    const { fixture, host } = await mount(answer);
    ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(fixture);

    const banner = host.querySelector('.ocu-banner-warning') as HTMLElement;
    expect(banner).not.toBeNull();
    expect(banner.textContent?.trim()).toBe(STRINGS.formStaleSave);
    expect(banner.textContent).not.toContain(CONFLICT_ENVELOPE_REASON);
  });

  it("DW-388: a Test connection whose row moved reads the published conflict sentence on the failure line", async () => {
    // The same code reaches this screen on a second path: `ConnectionOutcome` answers 409
    // STATE.CONFLICT when the definition moves during the provider call. Mutation (Rule 19): drop
    // the STATE_CONFLICT_CODE branch from `absorbTestRefusal` -> this goes red, and the failure
    // line reads "so the save was refused" where nobody pressed Save.
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (path.endsWith('/test')) {
        return {
          kind: 'error',
          status: 409,
          code: 'STATE.CONFLICT',
          reason: CONFLICT_ENVELOPE_REASON,
          detail: null,
        };
      }
      if (init.method === 'POST') return created(definition());
      return ok({ definitions: [] });
    };
    const { fixture, host } = await mount(answer);
    const key = host.querySelector('#ocu-definition-apiKey') as HTMLInputElement;
    key.value = 'sk-ant-probe';
    key.dispatchEvent(new Event('input'));
    await settle(fixture);
    (host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
    await settle(fixture);

    expect(host.textContent).toContain(STRINGS.formStaleSave);
    expect(host.textContent).not.toContain(CONFLICT_ENVELOPE_REASON);
  });

  it('DW-425: a save sends the row version the screen read, takes the one each answer carries, and keeps it after a stale refusal', async () => {
    // Mutation (Rule 19): drop `rowVersion` from `DefinitionForm.body()` -> the expectation goes
    // red; take the version from a refusal as well as from an answer -> its last entry goes red.
    let puts = 0;
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'PUT') {
        puts += 1;
        if (puts === 1) return ok(definition({ rowVersion: 4 }));
        return { kind: 'error', status: 409, code: 'STATE.CONFLICT', reason: CONFLICT_ENVELOPE_REASON, detail: null };
      }
      return ok(definition({ rowVersion: 3 }));
    };
    const { fixture, host, calls } = await mount(answer, '/agent/definitions/edit/7');
    const save = () => [...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement;
    for (let press = 0; press < 3; press += 1) {
      save().click();
      await settle(fixture);
    }
    const sent = calls.filter((call) => call.method === 'PUT').map((call) => JSON.parse(call.body)['rowVersion']);
    expect(sent).toEqual([3, 4, 4]);
  });

  it("DW-425: after this screen's own Test connection over unsaved edits, the version is re-taken only when nothing else about the row moved", async () => {
    // Mutation (Rule 19): take the re-read's version without comparing the fields in
    // `retakeVersion` -> the second leg goes red, sending the version of a row somebody else edited.
    const run = async (afterTest: Record<string, unknown>) => {
      let tested = false;
      const answer: Answer = (path, init) => {
        if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
        if (path.endsWith('/test')) {
          tested = true;
          return ok({ connected: true, reply: 'Hello', replyTruncated: false, latencyMs: 9, connectionVerified: true, testedAsStored: true });
        }
        if (init.method === 'PUT') return ok(definition({ rowVersion: 9 }));
        return ok(tested ? definition({ rowVersion: 5, connectionVerified: true, ...afterTest }) : definition({ rowVersion: 3 }));
      };
      const { fixture, host, calls } = await mount(answer, '/agent/definitions/edit/7');
      const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
      name.value = 'Claude edited';
      name.dispatchEvent(new Event('input'));
      await settle(fixture);
      (host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
      await settle(fixture);
      ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
      await settle(fixture);
      const put = JSON.parse(calls.filter((call) => call.method === 'PUT').at(-1)?.body ?? '{}');
      return { version: put['rowVersion'], name: put['name'] };
    };
    expect(await run({})).toEqual({ version: 5, name: 'Claude edited' });
    expect(await run({ model: 'claude-other-5' })).toEqual({ version: 3, name: 'Claude edited' });
    expect(await run({ enabled: true })).toEqual({ version: 3, name: 'Claude edited' });
  });

  it('DW-425: after a key store and a refused Test connection over unsaved edits, the version is re-taken when only the store moved the row', async () => {
    // Mutation (Rule 19): drop the re-take on the refused path of `testConnection` -> the first
    // leg goes red, sending the version from before the key store; leave the loaded `enabled` as
    // it was in `absorbKeyStore` -> the first leg goes red as well.
    const run = async (afterStore: Record<string, unknown>) => {
      let stored = false;
      const answer: Answer = (path, init) => {
        if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
        if (path.endsWith('/credential')) {
          stored = true;
          return ok({ stored: true });
        }
        if (path.endsWith('/test')) {
          return { kind: 'error', status: 502, code: 'PROVIDER.REFUSED', reason: 'The provider refused the request', detail: { providerText: 'invalid x-api-key' } };
        }
        if (init.method === 'PUT') return ok(definition({ rowVersion: 9 }));
        return ok(stored ? definition({ rowVersion: 6, enabled: false, ...afterStore }) : definition({ rowVersion: 3, enabled: true, connectionVerified: true }));
      };
      const { fixture, host, calls } = await mount(answer, '/agent/definitions/edit/7');
      const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
      name.value = 'Claude edited';
      name.dispatchEvent(new Event('input'));
      const key = host.querySelector('#ocu-definition-apiKey') as HTMLInputElement;
      key.value = 'sk-ant-probe';
      key.dispatchEvent(new Event('input'));
      await settle(fixture);
      (host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
      await settle(fixture);
      ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
      await settle(fixture);
      expect(calls.filter((call) => call.path.endsWith('/credential')).length).toBe(1);
      const put = JSON.parse(calls.filter((call) => call.method === 'PUT').at(-1)?.body ?? '{}');
      return { version: put['rowVersion'], name: put['name'], enabled: put['enabled'] };
    };
    expect(await run({})).toEqual({ version: 6, name: 'Claude edited', enabled: false });
    expect(await run({ model: 'claude-other-5' })).toEqual({ version: 3, name: 'Claude edited', enabled: false });
  });

  it("DW-425: a key store's disable is taken into the screen, so a Save after it never re-enables the definition, and every later Test connection re-takes the version", async () => {
    // Mutation (Rule 19): drop the buffer half of `absorbKeyStore` -> the Save sends `enabled: true`
    // over the stored row's disable (and over anybody else's); drop the loaded-record half -> both
    // re-takes are skipped and the Save sends version 3, which the row has moved past.
    let stored = false;
    let tests = 0;
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (path.endsWith('/credential')) {
        stored = true;
        return ok({ stored: true });
      }
      if (path.endsWith('/test')) {
        tests += 1;
        return ok({ connected: true, reply: 'Hello', replyTruncated: false, latencyMs: 9, connectionVerified: true, testedAsStored: true });
      }
      if (init.method === 'PUT') return ok(definition({ rowVersion: 20 }));
      return ok(
        stored
          ? definition({ rowVersion: 6 + tests, enabled: false, connectionVerified: tests > 0 })
          : definition({ rowVersion: 3, enabled: true, connectionVerified: true })
      );
    };
    const { fixture, host, calls } = await mount(answer, '/agent/definitions/edit/7');
    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    name.value = 'Claude edited';
    name.dispatchEvent(new Event('input'));
    const key = host.querySelector('#ocu-definition-apiKey') as HTMLInputElement;
    key.value = 'sk-ant-probe';
    key.dispatchEvent(new Event('input'));
    await settle(fixture);
    for (let press = 0; press < 2; press += 1) {
      (host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
      await settle(fixture);
    }
    ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls.filter((call) => call.path.endsWith('/credential')).length).toBe(1);
    expect(tests).toBe(2);
    const put = JSON.parse(calls.filter((call) => call.method === 'PUT').at(-1)?.body ?? '{}');
    expect({ version: put['rowVersion'], name: put['name'], enabled: put['enabled'] }).toEqual({ version: 8, name: 'Claude edited', enabled: false });
  });

  it('AC8 (DW-373): name and provider carry the asterisk, and the published legend appears once', async () => {
    // Mutation (Rule 19): drop the legend render -> this goes red.
    const { host } = await mount(catalogOnly);
    const legends = [...host.querySelectorAll('.ocu-form-legend')];
    expect(legends).toHaveLength(1);
    expect(legends[0].textContent?.trim()).toBe(STRINGS.formRequiredFieldsLegend);

    // The asterisk is a CSS glyph, so the marked fields are the ones carrying the class -- and
    // `aria-required` is still the semantics, which is why no star is in any accessible name.
    const marked = [...host.querySelectorAll('.ocu-field-label-required')].map((label) =>
      label.textContent?.trim()
    );
    expect(marked).toEqual([STRINGS.tableColumnName, STRINGS.tableColumnProvider]);
    for (const id of ['ocu-definition-name', 'ocu-definition-provider']) {
      expect(host.querySelector(`#${id}`)?.getAttribute('aria-required')).toBe('true');
    }
    expect(host.textContent).not.toContain('*');
  });

  it('AC8: a field whose value changed since a refusal drops its stale violation on blur', async () => {
    // The cascade is the case the blur closes: choosing a provider rewrites model, endpoint,
    // maximum tokens, temperature and both credential-naming fields, and clears only `provider`'s
    // own violation -- so a refusal on `model` would otherwise stand over a value the form itself
    // replaced.
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(TWO_PROVIDERS);
      if (init.method === 'POST') {
        return refused([
          { field: 'name', code: 'AGENT.NAME.REQUIRED', reason: 'Give the definition a name of 1 to 64 characters.' },
          { field: 'model', code: 'AGENT.MODEL.REQUIRED', reason: 'Name the model this definition calls.' },
        ]);
      }
      return ok({ definitions: [] });
    };
    const { fixture, host } = await mount(answer);
    ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(fixture);

    const model = host.querySelector('#ocu-definition-model') as HTMLInputElement;
    expect(model.getAttribute('aria-invalid')).toBe('true');

    const provider = host.querySelector('#ocu-definition-provider') as HTMLSelectElement;
    provider.value = 'openai';
    provider.dispatchEvent(new Event('change'));
    await settle(fixture);
    // Still standing: the cascade moved the value and nothing told the refusal about it.
    expect(model.getAttribute('aria-invalid')).toBe('true');

    model.dispatchEvent(new Event('blur'));
    await settle(fixture);
    expect(model.getAttribute('aria-invalid')).toBe('false');
    expect(host.querySelector('#ocu-definition-model-reason')).toBeNull();
    // And the refusal that still describes its field is untouched -- the cascade never touched
    // `name`, so nothing here is a "clear all".
    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    name.dispatchEvent(new Event('blur'));
    await settle(fixture);
    expect(name.getAttribute('aria-invalid')).toBe('true');
    const remaining = [...host.querySelectorAll('.ocu-form-summary button')].map((entry) =>
      entry.textContent?.trim()
    );
    expect(remaining).toEqual(['Give the definition a name of 1 to 64 characters.']);
  });

  it('AC8: a blur on a field whose value has not moved keeps its refusal', async () => {
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'POST') {
        return refused([
          { field: 'name', code: 'AGENT.NAME.REQUIRED', reason: 'Give the definition a name of 1 to 64 characters.' },
        ]);
      }
      return ok({ definitions: [] });
    };
    const { fixture, host } = await mount(answer);
    ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(fixture);

    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    expect(name.getAttribute('aria-invalid')).toBe('true');
    name.dispatchEvent(new Event('blur'));
    await settle(fixture);
    expect(name.getAttribute('aria-invalid')).toBe('true');
  });

  it('DW-380: a refusal describes the values the request carried, not an edit typed while it was out', async () => {
    // The operator types a name while the save is in flight. The refusal judged the empty name the
    // request carried, so the first blur after it arrives finds the field moved and drops it.
    //
    // Mutation (Rule 19): snapshot the refused values in `rememberRefusal` when the answer arrives
    // rather than taking the `sent` record -> this goes red, the violation standing over a name the
    // refusal never saw.
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (init.method === 'POST') {
        const typed = document.querySelector('#ocu-definition-name') as HTMLInputElement;
        typed.value = 'Typed while saving';
        typed.dispatchEvent(new Event('input'));
        return refused([
          { field: 'name', code: 'AGENT.NAME.REQUIRED', reason: 'Give the definition a name of 1 to 64 characters.' },
        ]);
      }
      return ok({ definitions: [] });
    };
    const { fixture, host } = await mount(answer);
    ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(fixture);

    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    expect(name.value).toBe('Typed while saving');
    expect(name.getAttribute('aria-invalid')).toBe('true');
    name.dispatchEvent(new Event('blur'));
    await settle(fixture);
    expect(name.getAttribute('aria-invalid')).toBe('false');
  });

  it('DW-380: a refused Test connection describes the values the request carried, not an edit typed while it was out', async () => {
    // Mutation (Rule 19): take `sentToTest` after the awaited `/test` post in `testConnection` rather
    // than before it -> this goes red, the violation standing over a name the refusal never saw.
    const answer: Answer = (path) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (path.endsWith('/test')) {
        const typed = document.querySelector('#ocu-definition-name') as HTMLInputElement;
        typed.value = 'Typed while testing';
        typed.dispatchEvent(new Event('input'));
        return refused([
          { field: 'name', code: 'AGENT.NAME.REQUIRED', reason: 'Give the definition a name of 1 to 64 characters.' },
        ]);
      }
      return ok(definition());
    };
    const { fixture, host } = await mount(answer, '/agent/definitions/edit/7');
    (host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
    await settle(fixture);

    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    expect(name.value).toBe('Typed while testing');
    expect(name.getAttribute('aria-invalid')).toBe('true');
    name.dispatchEvent(new Event('blur'));
    await settle(fixture);
    expect(name.getAttribute('aria-invalid')).toBe('false');
  });

  it("AC7: a Test connection refused for privilege does not raise the save's action sentence", async () => {
    // `POST /:id/test` refuses 403 AUTH.NOPRIVILEGE with a `failedPair` of its own
    // (`src/OcuPilot/Test/AgentWireSecurity.cls`). The published action phrase this screen
    // resolves is "change this definition", which is what a SAVE does -- so composing it over a
    // refused test would put a second banner on the screen naming an action nobody took, beside
    // the test-failure line that already says what happened.
    //
    // Mutation (Rule 19): call `rememberRefusal` instead of `rememberRefusedValues` in
    // `absorbTestRefusal` -> this goes red.
    const answer: Answer = (path) => {
      if (path.endsWith('/agent/providers')) return ok(PROVIDERS_BODY);
      if (path.endsWith('/test')) {
        return {
          kind: 'error',
          status: 403,
          code: 'AUTH.NOPRIVILEGE',
          reason: 'The request was refused.',
          detail: { failedPair: 'OcuPilotAdmin:USE' },
        };
      }
      return ok(definition());
    };
    const { fixture, host } = await mount(answer, '/agent/definitions/edit/7');
    (host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
    await settle(fixture);

    expect(host.querySelector('.ocu-banner-warning')).toBeNull();
    expect(host.textContent).not.toContain(STRINGS.agentDefinitionRefusedAction);
    // What the reader gets instead is the server's own sentence, where the test's own result goes.
    expect(host.querySelector('.ocu-form-test .ocu-form-error')?.textContent?.trim()).toBe(
      'The request was refused.'
    );
  });

  it('AC8: a violation on a field the cascade rewrites and no control can blur is cleared by the cascade', async () => {
    // `credentialName` and `envVarName` are sent in every body and refused by name on the server,
    // but the form renders no control for either -- so no blur can ever reach them, and a refusal
    // the provider cascade has just made untrue would stand in the summary with no way out but
    // another Save.
    //
    // Mutation (Rule 19): drop the `CASCADE_ONLY_FIELDS` loop from `setProvider` -> this goes red.
    const answer: Answer = (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(TWO_PROVIDERS);
      if (init.method === 'PUT' || init.method === 'POST') {
        return refused([
          { field: 'credentialName', code: 'AGENT.CREDNAME.REQUIRED', reason: 'Name the stored credential.' },
          { field: 'name', code: 'AGENT.NAME.REQUIRED', reason: 'Give the definition a name of 1 to 64 characters.' },
        ]);
      }
      return ok(definition());
    };
    const { fixture, host } = await mount(answer, '/agent/definitions/edit/7');
    ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(fixture);

    const summary = () =>
      [...host.querySelectorAll('.ocu-form-summary button')].map((entry) => entry.textContent?.trim());
    expect(summary()).toEqual(['Name the stored credential.', 'Give the definition a name of 1 to 64 characters.']);
    // No control carries it, which is exactly why the cascade has to clear it.
    expect(host.querySelector('#ocu-definition-credentialName')).toBeNull();

    const provider = host.querySelector('#ocu-definition-provider') as HTMLSelectElement;
    provider.value = 'openai';
    provider.dispatchEvent(new Event('change'));
    await settle(fixture);

    expect(summary()).toEqual(['Give the definition a name of 1 to 64 characters.']);
  });

  it('the gate landing banner is above the form while nothing is enabled and the caller is allowed', async () => {
    const { host } = await mount(catalogOnly, '/agent/definitions/edit', { definitions: [] });
    const banner = host.querySelector('.ocu-form-gate-banner') as HTMLElement;
    expect(banner).not.toBeNull();
    expect(banner.textContent).toContain(STRINGS.agentGateLandingBanner);
    // Above the fields, which is what "landing" means: it is the first thing read on arrival.
    const fields = host.querySelector('.ocu-form-fields') as HTMLElement;
    expect(banner.compareDocumentPosition(fields) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });

  it('the gate landing banner is absent once a definition is enabled, and for a caller the map refuses', async () => {
    const enabled = await mount(catalogOnly, '/agent/definitions/edit', { definitions: [{ enabled: true }] });
    expect(enabled.host.querySelector('.ocu-form-gate-banner')).toBeNull();

    const denied = await mount(catalogOnly, '/agent/definitions/edit', {
      definitions: [],
      verdict: { allowed: false, failedPair: 'OcuPilotAdmin:USE' },
    });
    expect(denied.host.querySelector('.ocu-form-gate-banner')).toBeNull();

    // And an unanswered read shows nothing either: the banner never guesses.
    const unanswered = await mount(catalogOnly);
    expect(unanswered.host.querySelector('.ocu-form-gate-banner')).toBeNull();

    // Nor does a map read that completed with a failure, where every verdict reads allowed.
    //
    // Mutation (Rule 19): drop the `loaded()` check from `showGateBanner` -> this goes red.
    const noMap = await mount(catalogOnly, '/agent/definitions/edit', {
      definitions: [],
      mapLoaded: false,
    });
    expect(noMap.host.querySelector('.ocu-form-gate-banner')).toBeNull();
  });

  it('Story 10.3 AC2: the local controls render only on a row that licenses them, and the acknowledgment only for a key crossing plain http', async () => {
    // The gap this closes: the three controls are gated on `allowsLocal`, which no other fixture
    // in this file sets, so inverting `showHttpAcknowledge` to `false` reddened nothing.
    const { fixture, host } = await mount((path) =>
      path.endsWith('/agent/providers') ? ok(LOCAL_PROVIDERS) : ok({ definitions: [] })
    );
    const provider = host.querySelector('#ocu-definition-provider') as HTMLSelectElement;
    const endpoint = host.querySelector('#ocu-definition-endpointUrl') as HTMLInputElement;

    // On the vendor row the row licenses nothing, so neither the declaration nor the keyless
    // choice is offered -- and a plain-http endpoint does not summon the acknowledgment either,
    // because the server refuses that endpoint on its own field there.
    endpoint.value = PLAIN_HTTP;
    endpoint.dispatchEvent(new Event('input'));
    await settle(fixture);
    expect(host.querySelector('#ocu-definition-markedLocal')).toBeNull();
    expect(host.querySelector('#ocu-definition-credType')).toBeNull();
    expect(host.querySelector('#ocu-definition-httpAcknowledged')).toBeNull();

    provider.value = 'compatible';
    provider.dispatchEvent(new Event('change'));
    await settle(fixture);
    expect(host.querySelector('#ocu-definition-markedLocal')).not.toBeNull();
    expect(host.querySelector('#ocu-definition-credType')).not.toBeNull();

    // The cascade emptied the endpoint with the row's own default, so type it again.
    endpoint.value = PLAIN_HTTP;
    endpoint.dispatchEvent(new Event('input'));
    await settle(fixture);

    // Still not offered: the row licenses a local address but the definition has not declared
    // itself one, and `AgentRules.SchemeAccepted` refuses plain http on `endpointUrl` itself
    // until both terms hold -- a refusal this control cannot clear.
    expect(host.querySelector('#ocu-definition-httpAcknowledged')).toBeNull();
    const markedLocal = host.querySelector('#ocu-definition-markedLocal') as HTMLInputElement;
    markedLocal.checked = true;
    markedLocal.dispatchEvent(new Event('change'));
    await settle(fixture);

    const acknowledge = host.querySelector('#ocu-definition-httpAcknowledged') as HTMLInputElement;
    expect(acknowledge).not.toBeNull();
    expect(acknowledge.closest('.ocu-field')?.classList.contains('ocu-field-egress')).toBe(true);
    expect(acknowledge.parentElement?.textContent?.trim()).toBe(STRINGS.agentDefinitionHttpAcknowledge);

    // An encrypted endpoint is never asked.
    endpoint.value = 'https://ocupilot.invalid/v1';
    endpoint.dispatchEvent(new Event('input'));
    await settle(fixture);
    expect(host.querySelector('#ocu-definition-httpAcknowledged')).toBeNull();

    // Neither is a keyless definition: there is no key to expose.
    endpoint.value = PLAIN_HTTP;
    endpoint.dispatchEvent(new Event('input'));
    await settle(fixture);
    const noKey = host.querySelector('#ocu-definition-credType') as HTMLInputElement;
    noKey.checked = true;
    noKey.dispatchEvent(new Event('change'));
    await settle(fixture);
    expect(host.querySelector('#ocu-definition-httpAcknowledged')).toBeNull();
  });

  it('Story 10.3 AC2: ticking the acknowledgment sends it, and unticking No API key restores the rung it displaced', async () => {
    const { fixture, host, calls } = await mount((path, init) => {
      if (path.endsWith('/agent/providers')) return ok(LOCAL_PROVIDERS);
      if (init.method === 'POST') return created(definition({ provider: 'compatible' }));
      return ok({ definitions: [] });
    });
    const provider = host.querySelector('#ocu-definition-provider') as HTMLSelectElement;
    provider.value = 'compatible';
    provider.dispatchEvent(new Event('change'));
    await settle(fixture);

    // Tick the keyless choice and untick it: the rung must come back as it was, not as `creds`
    // chosen for the operator.
    const noKey = host.querySelector('#ocu-definition-credType') as HTMLInputElement;
    noKey.checked = true;
    noKey.dispatchEvent(new Event('change'));
    await settle(fixture);
    noKey.checked = false;
    noKey.dispatchEvent(new Event('change'));
    await settle(fixture);

    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    name.value = 'Local';
    name.dispatchEvent(new Event('input'));
    const model = host.querySelector('#ocu-definition-model') as HTMLInputElement;
    model.value = 'llama-3.3-70b-instruct';
    model.dispatchEvent(new Event('input'));
    const endpoint = host.querySelector('#ocu-definition-endpointUrl') as HTMLInputElement;
    endpoint.value = PLAIN_HTTP;
    endpoint.dispatchEvent(new Event('input'));
    await settle(fixture);

    const markedLocal = host.querySelector('#ocu-definition-markedLocal') as HTMLInputElement;
    markedLocal.checked = true;
    markedLocal.dispatchEvent(new Event('change'));
    await settle(fixture);
    const acknowledge = host.querySelector('#ocu-definition-httpAcknowledged') as HTMLInputElement;
    acknowledge.checked = true;
    acknowledge.dispatchEvent(new Event('change'));
    await settle(fixture);

    ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(fixture);
    const posted = JSON.parse(calls.filter((call) => call.method === 'POST').at(-1)?.body ?? '{}');
    expect(posted.httpAcknowledged).toBe(true);
    expect(posted.markedLocal).toBe(true);
    expect(posted.credType).toBe('creds');
  });

  it('Story 10.3: cascading off the local row clears the two flags and the keyless rung, so no control leaves the screen holding a value', async () => {
    // Without the clear-down the buffer keeps `credType: none` and `markedLocal: true` after the
    // controls have gone, and Save is refused on two fields the form renders nothing for.
    const { fixture, host, calls } = await mount((path, init) => {
      if (path.endsWith('/agent/providers')) return ok(LOCAL_PROVIDERS);
      if (init.method === 'POST') return created(definition());
      return ok({ definitions: [] });
    });
    const provider = host.querySelector('#ocu-definition-provider') as HTMLSelectElement;
    provider.value = 'compatible';
    provider.dispatchEvent(new Event('change'));
    await settle(fixture);
    (host.querySelector('#ocu-definition-markedLocal') as HTMLInputElement).checked = true;
    (host.querySelector('#ocu-definition-markedLocal') as HTMLInputElement).dispatchEvent(new Event('change'));
    await settle(fixture);

    // The acknowledgment is ticked before the cascade, so the assertion below observes the
    // clear-down rather than the buffer's own initial `false`: without it, `httpAcknowledged`
    // is never true on this path and the POST would read `false` whether or not the row's
    // `allowsLocal` clause exists.
    const endpoint = host.querySelector('#ocu-definition-endpointUrl') as HTMLInputElement;
    endpoint.value = PLAIN_HTTP;
    endpoint.dispatchEvent(new Event('input'));
    await settle(fixture);
    const acknowledge = host.querySelector('#ocu-definition-httpAcknowledged') as HTMLInputElement;
    acknowledge.checked = true;
    acknowledge.dispatchEvent(new Event('change'));
    await settle(fixture);

    const noKey = host.querySelector('#ocu-definition-credType') as HTMLInputElement;
    noKey.checked = true;
    noKey.dispatchEvent(new Event('change'));
    await settle(fixture);

    provider.value = 'anthropic';
    provider.dispatchEvent(new Event('change'));
    await settle(fixture);
    expect(host.querySelector('#ocu-definition-markedLocal')).toBeNull();
    expect(host.querySelector('#ocu-definition-credType')).toBeNull();

    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    name.value = 'Claude';
    name.dispatchEvent(new Event('input'));
    await settle(fixture);
    ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(fixture);
    const posted = JSON.parse(calls.filter((call) => call.method === 'POST').at(-1)?.body ?? '{}');
    expect(posted.markedLocal).toBe(false);
    expect(posted.httpAcknowledged).toBe(false);
    expect(posted.credType).toBe('creds');
  });

  it('Story 10.3 AC2: unticking No API key restores an `env` rung rather than forcing `creds`', async () => {
    // The gap this closes: the only other observation of the restore starts from `creds`, which
    // is also what the behaviour it replaced produced, so it could not tell the two apart. A
    // stored `env` definition is the only state that can. `credType` is a security field
    // (`State/Agent.SecurityFields`), so a silent move would disable the definition until Test
    // connection passed again, against a rung the operator never chose.
    const stored = definition({
      name: 'Local',
      provider: 'compatible',
      model: 'llama-3.3-70b-instruct',
      endpointUrl: 'https://ocupilot.invalid/v1',
      credType: 'env',
      envVarName: 'OPENAI_COMPATIBLE_API_KEY',
      credentialName: '',
    });
    const { fixture, host, calls } = await mount(
      (path) => (path.endsWith('/agent/providers') ? ok(LOCAL_PROVIDERS) : ok(stored)),
      '/agent/definitions/edit/7'
    );

    const noKey = host.querySelector('#ocu-definition-credType') as HTMLInputElement;
    expect(noKey.checked).toBe(false);
    noKey.checked = true;
    noKey.dispatchEvent(new Event('change'));
    await settle(fixture);
    noKey.checked = false;
    noKey.dispatchEvent(new Event('change'));
    await settle(fixture);

    // A benign edit, so the save is issued whatever the dirty tracking makes of a value that
    // left and came back.
    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    name.value = 'Local model';
    name.dispatchEvent(new Event('input'));
    await settle(fixture);

    ([...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement).click();
    await settle(fixture);
    const posted = JSON.parse(calls.filter((call) => call.method === 'PUT').at(-1)?.body ?? '{}');
    expect(posted.credType).toBe('env');
    expect(posted.envVarName).toBe('OPENAI_COMPATIBLE_API_KEY');
  });

  // --- Story 8.9 AC2: env mode, where the namespace cannot reach the credentials rung ----------

  /** The providers answer with the rung flag the server publishes beside the rows. */
  const withRung = (body: { providers: unknown[] }, available: boolean | undefined) =>
    available === undefined ? body : { ...body, credentialsRungAvailable: available };

  /** Two vendor rows whose environment-variable defaults differ, so a cascade is observable. */
  const ENV_PROVIDERS = {
    providers: [
      PROVIDERS_BODY.providers[0],
      { ...TWO_PROVIDERS.providers[1], defaultEnvVarName: 'OPENAI_API_KEY' },
    ],
  };

  /**
   * Every route the form issues, answered the way the instance does: a create echoes the body it
   * was sent under a new id, an empty variable is refused on its own field, and Test connection
   * passes.
   */
  const envAnswer =
    (providers: unknown): Answer =>
    (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(providers);
      if (path.endsWith('/test')) return ok({ reply: 'Hello', connectionVerified: true, testedAsStored: true });
      if (init.method === 'POST' || init.method === 'PUT') {
        const sent = JSON.parse(init.body ?? '{}') as Record<string, unknown>;
        if (sent['envVarName'] === '') {
          return refused([{ field: 'envVarName', code: 'AGENT.ENVVAR.REQUIRED', reason: 'Name the environment variable the key is read from.' }]);
        }
        return init.method === 'POST' ? created(definition({ ...sent, id: '9' })) : ok(definition(sent));
      }
      return path.endsWith('/definitions') ? ok({ definitions: [] }) : ok(definition());
    };

  const saveButton = (host: HTMLElement) =>
    [...host.querySelectorAll('.ocu-form-bar-actions button')].at(-1) as HTMLButtonElement;

  const lastBody = (calls: { method: string; body: string }[], method: string) =>
    JSON.parse(calls.filter((call) => call.method === method).at(-1)?.body ?? '{}') as Record<string, unknown>;

  it('Story 8.9 AC2: in env mode a create offers the environment variable in the key field\'s place and sends `env`', async () => {
    // Mutation (Rule 19): render the API-key field whatever the flag says -> this goes red on the
    // key field being present.
    const { fixture, host, calls } = await mount(envAnswer(withRung(PROVIDERS_BODY, false)));

    expect(host.querySelector('#ocu-definition-apiKey')).toBeNull();
    expect(host.querySelector('.ocu-reveal-toggle')).toBeNull();
    expect(host.textContent).not.toContain(STRINGS.formSecretStored);

    const envVar = host.querySelector('#ocu-definition-envVarName') as HTMLInputElement;
    expect(envVar).not.toBeNull();
    expect(envVar.value).toBe('ANTHROPIC_API_KEY');
    const labels = [...host.querySelectorAll('.ocu-field-label')].map((label) => label.textContent?.trim());
    expect(labels).toEqual([
      STRINGS.tableColumnName,
      STRINGS.tableColumnProvider,
      STRINGS.tableColumnModel,
      STRINGS.agentDefinitionFieldEndpoint,
      STRINGS.agentDefinitionFieldEnvVar,
    ]);
    const caption = host.querySelector('#ocu-definition-envVarName-caption') as HTMLElement;
    expect(caption.textContent?.trim()).toBe(STRINGS.agentDefinitionEnvVarCaption);
    expect(envVar.getAttribute('aria-describedby')).toBe('ocu-definition-envVarName-caption');

    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    name.value = 'Claude';
    name.dispatchEvent(new Event('input'));
    envVar.value = '';
    envVar.dispatchEvent(new Event('input'));
    await settle(fixture);
    saveButton(host).click();
    await settle(fixture);
    expect(lastBody(calls, 'POST')['credType']).toBe('env');
    const reason = host.querySelector('#ocu-definition-envVarName-reason') as HTMLElement;
    expect(reason.textContent?.trim()).toBe('Name the environment variable the key is read from.');
    expect(document.activeElement?.id).toBe('ocu-definition-envVarName');

    const again = host.querySelector('#ocu-definition-envVarName') as HTMLInputElement;
    again.value = 'MY_ANTHROPIC_KEY';
    again.dispatchEvent(new Event('input'));
    await settle(fixture);
    saveButton(host).click();
    await settle(fixture);
    const posted = calls.filter((call) => call.method === 'POST');
    const body = JSON.parse(posted.at(-1)?.body ?? '{}') as Record<string, unknown>;
    expect(body['credType']).toBe('env');
    expect(body['envVarName']).toBe('MY_ANTHROPIC_KEY');
  });

  it('Story 8.9 AC2: in env mode a provider change and an unticked No API key restore `env`, never `creds`', async () => {
    const vendor = await mount(envAnswer(withRung(ENV_PROVIDERS, false)));
    const provider = vendor.host.querySelector('#ocu-definition-provider') as HTMLSelectElement;
    provider.value = 'openai';
    provider.dispatchEvent(new Event('change'));
    await settle(vendor.fixture);
    expect((vendor.host.querySelector('#ocu-definition-envVarName') as HTMLInputElement).value).toBe('OPENAI_API_KEY');
    const name = vendor.host.querySelector('#ocu-definition-name') as HTMLInputElement;
    name.value = 'GPT';
    name.dispatchEvent(new Event('input'));
    await settle(vendor.fixture);
    saveButton(vendor.host).click();
    await settle(vendor.fixture);
    expect(lastBody(vendor.calls, 'POST')['credType']).toBe('env');
    expect(lastBody(vendor.calls, 'POST')['envVarName']).toBe('OPENAI_API_KEY');

    const local = await mount(envAnswer(withRung(LOCAL_PROVIDERS, false)));
    const localProvider = local.host.querySelector('#ocu-definition-provider') as HTMLSelectElement;
    localProvider.value = 'compatible';
    localProvider.dispatchEvent(new Event('change'));
    await settle(local.fixture);
    const noKey = local.host.querySelector('#ocu-definition-credType') as HTMLInputElement;
    noKey.checked = true;
    noKey.dispatchEvent(new Event('change'));
    await settle(local.fixture);
    noKey.checked = false;
    noKey.dispatchEvent(new Event('change'));
    await settle(local.fixture);
    const localName = local.host.querySelector('#ocu-definition-name') as HTMLInputElement;
    localName.value = 'Local';
    localName.dispatchEvent(new Event('input'));
    await settle(local.fixture);
    saveButton(local.host).click();
    await settle(local.fixture);
    expect(lastBody(local.calls, 'POST')['credType']).toBe('env');

    // A stored keyless definition has no rung for the checkbox to have remembered, so unticking
    // falls back to the default rung -- which in env mode is `env`.
    const keyless = definition({
      provider: 'compatible',
      model: 'llama-3.3-70b-instruct',
      endpointUrl: 'https://ocupilot.invalid/v1',
      credType: 'none',
      envVarName: '',
      credentialName: '',
    });
    const stored = await mount(
      (path, init) => (init.method === undefined && /\/definitions\/7$/.test(path) ? ok(keyless) : envAnswer(withRung(LOCAL_PROVIDERS, false))(path, init)),
      '/agent/definitions/edit/7'
    );
    const storedNoKey = stored.host.querySelector('#ocu-definition-credType') as HTMLInputElement;
    expect(storedNoKey.checked).toBe(true);
    storedNoKey.checked = false;
    storedNoKey.dispatchEvent(new Event('change'));
    await settle(stored.fixture);
    const storedEnv = stored.host.querySelector('#ocu-definition-envVarName') as HTMLInputElement;
    storedEnv.value = 'OPENAI_COMPATIBLE_API_KEY';
    storedEnv.dispatchEvent(new Event('input'));
    await settle(stored.fixture);
    saveButton(stored.host).click();
    await settle(stored.fixture);
    expect(lastBody(stored.calls, 'PUT')['credType']).toBe('env');
  });

  it('Story 8.9 AC2: in env mode a stored `creds` definition opens on `env`, as an unsaved change', async () => {
    const { fixture, host, calls, formDirty } = await mount(
      envAnswer(withRung(PROVIDERS_BODY, false)),
      '/agent/definitions/edit/7'
    );
    expect(host.querySelector('#ocu-definition-apiKey')).toBeNull();
    // An edit is where the key field's "Stored." caption would render, so this is the leg that can
    // see it leak into env mode; the create leg cannot, since a create never shows it.
    expect(host.textContent).not.toContain(STRINGS.formSecretStored);
    expect((host.querySelector('#ocu-definition-envVarName') as HTMLInputElement).value).toBe('ANTHROPIC_API_KEY');
    // Nothing was written by opening it: the move is the operator's to save, and the leave guard
    // holds it until they do.
    expect(calls.filter((call) => call.method !== 'GET')).toEqual([]);
    expect(formDirty.dirty()).toBe(true);

    saveButton(host).click();
    await settle(fixture);
    const body = lastBody(calls, 'PUT');
    expect(body['credType']).toBe('env');
    expect(body['envVarName']).toBe('ANTHROPIC_API_KEY');
  });

  it('Story 8.9 AC2: in env mode Test connection posts no credential, even with a key held', async () => {
    // Mutation (Rule 19): drop `&& !this.envMode()` from testConnection's credential post -> this
    // goes red on the `/credential` POST.
    const { fixture, host, calls } = await mount(envAnswer(withRung(PROVIDERS_BODY, false)));
    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    name.value = 'Claude';
    name.dispatchEvent(new Event('input'));
    await settle(fixture);
    // No control can type a key in env mode; the store is handed one directly so the guard, not
    // the missing field, is what stands between it and the credential route.
    TestBed.inject(DefinitionForm).setKey('sk-ant-held-before-env-mode');
    (host.querySelector('.ocu-form-test button') as HTMLButtonElement).click();
    await settle(fixture);
    const posts = calls.filter((call) => call.method === 'POST').map((call) => call.path);
    expect(posts.some((path) => path.endsWith('/credential'))).toBe(false);
    expect(posts.some((path) => path.endsWith('/test'))).toBe(true);
    expect(JSON.parse(calls.find((call) => call.method === 'POST')?.body ?? '{}')['credType']).toBe('env');
  });

  it('Story 8.9 AC2: in env mode a refused variable keeps its reason across a provider change until blurred', async () => {
    const { fixture, host } = await mount(envAnswer(withRung(ENV_PROVIDERS, false)));
    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    name.value = 'Claude';
    name.dispatchEvent(new Event('input'));
    const envVar = host.querySelector('#ocu-definition-envVarName') as HTMLInputElement;
    envVar.value = '';
    envVar.dispatchEvent(new Event('input'));
    await settle(fixture);
    saveButton(host).click();
    await settle(fixture);
    expect(host.querySelector('#ocu-definition-envVarName-reason')).not.toBeNull();

    const provider = host.querySelector('#ocu-definition-provider') as HTMLSelectElement;
    provider.value = 'openai';
    provider.dispatchEvent(new Event('change'));
    await settle(fixture);
    const rewritten = host.querySelector('#ocu-definition-envVarName') as HTMLInputElement;
    expect(rewritten.value).toBe('OPENAI_API_KEY');
    expect(host.querySelector('#ocu-definition-envVarName-reason')).not.toBeNull();

    rewritten.dispatchEvent(new Event('blur'));
    await settle(fixture);
    expect(host.querySelector('#ocu-definition-envVarName-reason')).toBeNull();
  });

  it('Story 8.9 AC2: in env mode the gate landing banner asks for the variable, never for a key', async () => {
    // Mutation (Rule 19): render `agentGateLandingBanner` whatever `envMode` says -> this goes red.
    const { host } = await mount(envAnswer(withRung(PROVIDERS_BODY, false)), '/agent/definitions/edit', { definitions: [] });
    const banner = host.querySelector('.ocu-form-gate-banner') as HTMLElement;
    expect(banner.textContent).toContain(STRINGS.agentGateLandingBannerEnv);
    expect(banner.textContent).not.toContain(STRINGS.agentGateLandingBanner);
  });

  it('Story 8.9 AC2: where the rung is reachable, or the flag is absent, the form is unchanged', async () => {
    for (const available of [true, undefined]) {
      const { fixture, host, calls } = await mount(envAnswer(withRung(PROVIDERS_BODY, available)));
      expect(host.querySelector('#ocu-definition-apiKey')).not.toBeNull();
      expect(host.querySelector('#ocu-definition-envVarName')).toBeNull();
      const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
      name.value = 'Claude';
      name.dispatchEvent(new Event('input'));
      await settle(fixture);
      saveButton(host).click();
      await settle(fixture);
      expect(lastBody(calls, 'POST')['credType']).toBe('creds');
    }
  });

  /** Story 10.4's catalog shape: no row declares a canonical temperature, and the first takes none. */
  const SAMPLING_PROVIDERS = {
    providers: [
      { ...PROVIDERS_BODY.providers[0], canonicalTemperature: null, acceptsTemperature: false },
      { ...TWO_PROVIDERS.providers[1], canonicalTemperature: null, acceptsTemperature: true },
    ],
  };

  const samplingAnswer =
    (stored: Record<string, unknown> = {}): Answer =>
    (path, init) => {
      if (path.endsWith('/agent/providers')) return ok(SAMPLING_PROVIDERS);
      if (init.method === 'POST') return created(definition({ ...JSON.parse(init.body ?? '{}'), id: '9' }));
      if (init.method === 'PUT') return ok(definition({ ...stored, ...JSON.parse(init.body ?? '{}') }));
      return path.endsWith('/definitions') ? ok({ definitions: [] }) : ok(definition(stored));
    };

  const openAdvanced = async (fixture: ComponentFixture<unknown>, host: HTMLElement) => {
    (host.querySelector('.ocu-form-disclosure') as HTMLButtonElement).click();
    await settle(fixture);
  };

  const chooseProvider = async (fixture: ComponentFixture<unknown>, host: HTMLElement, key: string) => {
    const provider = host.querySelector('#ocu-definition-provider') as HTMLSelectElement;
    provider.value = key;
    provider.dispatchEvent(new Event('change'));
    await settle(fixture);
  };

  const temperatureInput = (host: HTMLElement) => host.querySelector('#ocu-definition-temperature') as HTMLInputElement;

  it('Story 10.4 AC1: a row that declares no canonical temperature cascades an empty field, and it saves unset', async () => {
    // Mutation (Rule 19): cascade `String(row.canonicalTemperature)` with no null check -> this goes
    // red, the field reading 'null'.
    const { fixture, host, calls } = await mount(samplingAnswer());
    await chooseProvider(fixture, host, 'openai');
    await openAdvanced(fixture, host);
    expect(temperatureInput(host).value).toBe('');
    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    name.value = 'GPT';
    name.dispatchEvent(new Event('input'));
    await settle(fixture);
    saveButton(host).click();
    await settle(fixture);
    expect(lastBody(calls, 'POST')['temperature']).toBe('');
  });

  it('Story 10.4 AC1: on a row that takes a temperature the empty field reads Provider default and stays editable', async () => {
    const { fixture, host } = await mount(samplingAnswer());
    await chooseProvider(fixture, host, 'openai');
    await openAdvanced(fixture, host);
    const input = temperatureInput(host);
    expect(input.getAttribute('placeholder')).toBe(STRINGS.agentDefinitionTemperatureProviderDefault);
    expect(input.hasAttribute('readonly')).toBe(false);
    expect(input.hasAttribute('aria-disabled')).toBe(false);
    expect(host.querySelector('#ocu-definition-temperature-caption')).toBeNull();
    expect(input.getAttribute('aria-describedby')).toBeNull();
  });

  it('Story 10.4 AC3: on a row that takes no temperature the field is readonly, aria-disabled and captioned', async () => {
    // Mutation (Rule 19): drop the not-applicable branch -- render the field as the applicable
    // one whatever the row says -> this goes red on every assertion below.
    const { fixture, host } = await mount(samplingAnswer());
    await openAdvanced(fixture, host);
    const input = temperatureInput(host);
    expect(input.getAttribute('placeholder')).toBe(STRINGS.agentDefinitionTemperatureNotApplicable);
    expect(input.hasAttribute('readonly')).toBe(true);
    expect(input.getAttribute('aria-disabled')).toBe('true');
    expect(input.hasAttribute('disabled')).toBe(false);
    expect(host.querySelector('#ocu-definition-temperature-caption')?.textContent?.trim()).toBe(
      STRINGS.agentDefinitionTemperatureNotApplicableCaption
    );
    expect(input.getAttribute('aria-describedby')).toBe('ocu-definition-temperature-caption');
  });

  it('Story 10.4: the field follows the acceptsTemperature column, never the provider name', async () => {
    // Mutation (Rule 19): `temperatureApplies()` keyed on the name
    // (`this.value('provider') !== 'anthropic'`) -> this goes red on both rows.
    const inverted = {
      providers: [
        { ...SAMPLING_PROVIDERS.providers[0], acceptsTemperature: true },
        { ...SAMPLING_PROVIDERS.providers[1], acceptsTemperature: false },
      ],
    };
    const base = samplingAnswer();
    const { fixture, host } = await mount((path, init) =>
      path.endsWith('/agent/providers') ? ok(inverted) : base(path, init)
    );
    await openAdvanced(fixture, host);
    expect(temperatureInput(host).hasAttribute('readonly')).toBe(false);
    expect(temperatureInput(host).getAttribute('placeholder')).toBe(STRINGS.agentDefinitionTemperatureProviderDefault);
    await chooseProvider(fixture, host, 'openai');
    const input = temperatureInput(host);
    expect(input.hasAttribute('readonly')).toBe(true);
    expect(input.getAttribute('aria-disabled')).toBe('true');
    expect(host.querySelector('#ocu-definition-temperature-caption')?.textContent?.trim()).toBe(
      STRINGS.agentDefinitionTemperatureNotApplicableCaption
    );
  });

  it('Story 10.4: a value stored on a row that takes no temperature is shown as held and survives a save', async () => {
    const { fixture, host, calls } = await mount(samplingAnswer({ temperature: 0.7 }), '/agent/definitions/edit/7');
    await openAdvanced(fixture, host);
    const input = temperatureInput(host);
    expect(input.value).toBe('0.7');
    expect(input.hasAttribute('readonly')).toBe(true);
    saveButton(host).click();
    await settle(fixture);
    expect(lastBody(calls, 'PUT')['temperature']).toBe(0.7);
    expect(temperatureInput(host).value).toBe('0.7');
  });

  it('Story 10.4: a definition stored unset loads its JSON null as an empty field and saves it unset', async () => {
    // Mutation (Rule 19): `absorb` reads the temperature through `numberAt` -> this goes red, the
    // field reading '0' and the next save storing 0.
    const { fixture, host, calls } = await mount(
      samplingAnswer({ provider: 'openai', temperature: null }),
      '/agent/definitions/edit/7'
    );
    await openAdvanced(fixture, host);
    const input = temperatureInput(host);
    expect(input.value).toBe('');
    expect(input.getAttribute('placeholder')).toBe(STRINGS.agentDefinitionTemperatureProviderDefault);
    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    name.value = 'Renamed';
    name.dispatchEvent(new Event('input'));
    await settle(fixture);
    saveButton(host).click();
    await settle(fixture);
    expect(lastBody(calls, 'PUT')['temperature']).toBe('');
  });
});

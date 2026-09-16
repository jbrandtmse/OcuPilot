import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, RouterOutlet, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { routes } from './app.routes';
import { AgentStatus } from './core/agent-status';
import { ApiService, type JsonResult } from './core/api';
import { ChangeBus } from './core/change-bus';
import { FormDirty } from './core/form-dirty';
import { NavigationService } from './core/navigation';
import { OverlayStack } from './core/overlay-stack';
import { ShellState } from './core/shell-state';
import { STRINGS } from './core/strings';
import { stubAgentStatus } from './testing/agent-status';

/**
 * The unsaved-changes guard (AC2, AD-11 rule 3), wired the way `app.routes.ts` actually ships it:
 * `canDeactivate: [leaveFormGuard]` on the real `form-page` route inside the real route table,
 * run by the real Angular `Router` inside a real `navigateByUrl` call.
 *
 * `form-dirty.test.mjs` pins `FormDirty` alone; `definition-form.page.spec.ts` raises the
 * confirmation by calling `formDirty.requestLeave()` directly. Neither drives the guard through
 * the route table `app.routes.ts` actually builds, so a route that lost its `canDeactivate` entry
 * -- a descriptor renamed, a merge that dropped the spread, a refactor of `buildRoutes` -- would
 * red no test. AD-11 rule 3 requires the refusal to reach "a navigation the user did not
 * initiate", which is what the agent's own navigation tool will issue once it lands (Design
 * Notes: "waits for the same answer" is `await router.navigateByUrl(...)`); the one thing worth
 * pinning before it exists is that a bare, unprompted `router.navigateByUrl(...)` -- no click, no
 * component method in the call stack -- is itself intercepted by the shipped route table.
 *
 * The host is a bare `<router-outlet>` over the real `routes`, not the full `App` shell:
 * `app.wire.spec.ts` already proves the shell composes around a routed screen, and the seam here
 * is narrower -- Router -> `canDeactivate` -> `FormDirty` -> `DefinitionFormPage`. The declined
 * and accepted attempts both target the wildcard route (`ScreenOutlet`'s own not-found branch),
 * which mounts no screen and so needs no dependency the guard itself does not already require.
 *
 * **Why this settles with `pump()`, not `whenStable()`, while a decision is outstanding.**
 * Angular's Router registers the in-flight navigation as a pending task while a `canDeactivate`
 * guard's promise is unresolved, so `ComponentFixture.whenStable()` does not resolve until the
 * guard has answered -- calling it before the confirmation is answered deadlocks the test against
 * its own assertion. `pump()` only calls `detectChanges()` on a timer, which is enough to render
 * the confirmation `leaveFormGuard` raised; `settle()` (with `whenStable()`) is used only when no
 * navigation is outstanding.
 *
 * Mutation (Rule 19): drop `canDeactivate: [leaveFormGuard]` from the form-page branch of
 * `buildRoutes` in `app.routes.ts` (the `...guarded` spread on the base route's push) -> the
 * first attempt below goes red, resolving `true` and moving `router.url` to `/not-a-screen`
 * with the name field's edit still unsaved.
 */

const PROVIDERS_BODY = {
  providers: [
    {
      key: 'anthropic',
      label: 'Anthropic',
      defaultModel: 'claude-opus-5',
      modelSuggestions: ['claude-opus-5', 'claude-sonnet-5'],
      defaultEndpoint: 'https://ocupilot.invalid/v1/messages',
      endpointRequired: false,
      canonicalMaxTokens: 32000,
      canonicalTemperature: 0,
      defaultEnvVarName: 'ANTHROPIC_API_KEY',
      defaultCredentialName: 'OcuPilotAnthropic',
      keyPrefix: 'sk-ant-',
      allowsLocal: false,
      keyShapeReason:
        'That key is not shaped like a key for this provider: keys for this provider begin with sk-ant-.',
    },
  ],
};

@Component({
  selector: 'app-guard-wire-host',
  template: '<router-outlet />',
  imports: [RouterOutlet],
})
class GuardWireHost {}

const planted: HTMLElement[] = [];

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

/** Used only when no navigation is outstanding: `whenStable()` waits out every pending task. */
async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/**
 * Used while a `canDeactivate` guard's promise is outstanding: the Router counts that promise as
 * a pending task, so `whenStable()` would wait for the very answer this helper is here to render
 * the means of giving. `detectChanges()` alone is enough to draw the confirmation.
 */
async function pump(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
  }
}

describe('the unsaved-changes guard, on the real route table (AC2, AD-11 rule 3)', () => {
  it('a bare Router.navigateByUrl is refused while the shipped Definition form is dirty, and a second bare call completes once accepted', async () => {
    TestBed.resetTestingModule();
    const api = {
      requestJson: async (path: string): Promise<JsonResult<unknown>> => {
        if (path.endsWith('/agent/providers')) {
          return { kind: 'ok', status: 200, body: PROVIDERS_BODY };
        }
        return { kind: 'ok', status: 200, body: { definitions: [] } };
      },
    };
    const navigation = new NavigationService({
      api: api as unknown as ApiService,
      namespace: () => 'HSCUSTOM',
    });
    // Resolved before the route table is exercised, exactly as `App`'s own constructor triggers
    // it before anything routed can mount: an unanswered map would deny every screen, including
    // the Definition form this test needs on screen at all.
    await navigation.load();

    TestBed.configureTestingModule({
      providers: [
        provideRouter(routes),
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: ChangeBus, useValue: new ChangeBus() },
        { provide: FormDirty, useValue: new FormDirty() },
        { provide: NavigationService, useValue: navigation },
        // The guard's crossing is not about the agent's configuration; the form injects the
        // status because it decides whether the gate banner is above it, and an unanswered one
        // renders no banner at all.
        { provide: AgentStatus, useValue: stubAgentStatus() },
        { provide: OverlayStack, useValue: new OverlayStack() },
        // Inert: this crossing is not about which area is active, and the real class needs a
        // preference store this test has no reason to construct.
        {
          provide: ShellState,
          useValue: {
            setActiveArea: () => {},
            screenHeld: () => false,
            subscribe: () => () => {},
          } as unknown as ShellState,
        },
      ],
    });

    const fixture = TestBed.createComponent(GuardWireHost);
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    fixture.detectChanges();
    const router = TestBed.inject(Router);

    await router.navigateByUrl('/agent/definitions/edit');
    await settle(fixture);

    const host = fixture.nativeElement as HTMLElement;
    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    expect(name, 'the real DefinitionFormPage mounted through the real routes and mirror').not.toBeNull();
    name.value = 'Claude';
    name.dispatchEvent(new Event('input'));
    await settle(fixture);
    expect(TestBed.inject(FormDirty).dirty()).toBe(true);

    // The call under test: bare, unprompted, exactly what an agent's navigation tool will issue
    // once it exists. No click and no component method precede it.
    const declined = router.navigateByUrl('/not-a-screen');
    await pump(fixture);

    const firstDialog = host.querySelector('[role="dialog"]') as HTMLElement | null;
    expect(firstDialog, 'the confirmation the guard raised, not one a click opened').not.toBeNull();
    expect(firstDialog!.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(
      STRINGS.formLeaveWithoutSaving
    );
    expect(router.url, 'the guard has not answered yet, so the route has not moved').toBe(
      '/agent/definitions/edit'
    );

    (firstDialog!.querySelectorAll('.ocu-dialog-actions button')[0] as HTMLButtonElement).click();
    await settle(fixture);

    expect(await declined, "the guard's answer is the promise navigateByUrl itself returned").toBe(
      false
    );
    expect(router.url).toBe('/agent/definitions/edit');
    expect(
      (host.querySelector('#ocu-definition-name') as HTMLInputElement).value,
      'the declined navigation left the unsaved edit exactly where it was'
    ).toBe('Claude');

    // A second bare call, on the same dirty form: accepting resolves the same call's promise
    // true and the route moves, proving the guard answers the call in front of it rather than
    // one particular click handler.
    const accepted = router.navigateByUrl('/not-a-screen');
    await pump(fixture);
    const secondDialog = host.querySelector('[role="dialog"]') as HTMLElement | null;
    expect(secondDialog).not.toBeNull();
    (secondDialog!.querySelectorAll('.ocu-dialog-actions button')[1] as HTMLButtonElement).click();
    await settle(fixture);

    expect(await accepted).toBe(true);
    expect(router.url).toBe('/not-a-screen');
  });

  it('the editor route with an id carries the guard too, which is the route most editing happens on', async () => {
    // `buildRoutes` pushes a `form-page` twice -- the bare route and `<route>/:id` -- and the
    // guard is spread onto each push separately. The case above occupies the bare create route;
    // an operator who opens an existing definition from the list's name cell, or who is moved to
    // the editor by a create, is on this one for every edit they make afterwards.
    //
    // Mutation (Rule 19): drop `...guarded` from the `:id` push alone in `app.routes.ts` -> this
    // goes red (the navigation resolving `true` and the route moving) while the case above stays
    // green, which is what says the two pushes are pinned separately.
    TestBed.resetTestingModule();
    const api = {
      requestJson: async (path: string): Promise<JsonResult<unknown>> => {
        if (path.endsWith('/agent/providers')) {
          return { kind: 'ok', status: 200, body: PROVIDERS_BODY };
        }
        if (path.endsWith('/agent/definitions/7')) {
          return {
            kind: 'ok',
            status: 200,
            body: {
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
            },
          };
        }
        return { kind: 'ok', status: 200, body: { definitions: [] } };
      },
    };
    const navigation = new NavigationService({
      api: api as unknown as ApiService,
      namespace: () => 'HSCUSTOM',
    });
    await navigation.load();

    TestBed.configureTestingModule({
      providers: [
        provideRouter(routes),
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: ChangeBus, useValue: new ChangeBus() },
        { provide: FormDirty, useValue: new FormDirty() },
        { provide: NavigationService, useValue: navigation },
        { provide: AgentStatus, useValue: stubAgentStatus() },
        { provide: OverlayStack, useValue: new OverlayStack() },
        {
          provide: ShellState,
          useValue: {
            setActiveArea: () => {},
            screenHeld: () => false,
            subscribe: () => () => {},
          } as unknown as ShellState,
        },
      ],
    });

    const fixture = TestBed.createComponent(GuardWireHost);
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    fixture.detectChanges();
    const router = TestBed.inject(Router);

    await router.navigateByUrl('/agent/definitions/edit/7');
    await settle(fixture);

    const host = fixture.nativeElement as HTMLElement;
    const name = host.querySelector('#ocu-definition-name') as HTMLInputElement;
    expect(name, 'the editor mounted on the id route').not.toBeNull();
    expect(name.value, 'over the definition the route names').toBe('Claude');
    name.value = 'Claude renamed';
    name.dispatchEvent(new Event('input'));
    await settle(fixture);
    expect(TestBed.inject(FormDirty).dirty()).toBe(true);

    const declined = router.navigateByUrl('/not-a-screen');
    await pump(fixture);
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement | null;
    expect(dialog, 'the guard raised its confirmation on the id route as well').not.toBeNull();
    (dialog!.querySelectorAll('.ocu-dialog-actions button')[0] as HTMLButtonElement).click();
    await settle(fixture);

    expect(await declined).toBe(false);
    expect(router.url).toBe('/agent/definitions/edit/7');
    expect((host.querySelector('#ocu-definition-name') as HTMLInputElement).value).toBe(
      'Claude renamed'
    );
  });
});

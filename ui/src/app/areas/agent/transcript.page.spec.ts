import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { STRINGS } from '../../core/strings';
import { TranscriptPage } from './transcript.page';

/**
 * The transcript page over a stub of the one request it makes: what the owner sees, what a
 * withheld answer leaves out, and the no-longer-present state (Story 14.4).
 */

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const ok = (body: unknown): JsonResult<unknown> => ({ kind: 'ok', status: 200, body });

const notFound = (): JsonResult<unknown> => ({
  kind: 'error',
  status: 404,
  code: 'TURN.CONVERSATION.NOTFOUND',
  reason: 'No conversation with that identifier exists.',
  detail: null,
});

const answer = (overrides: Record<string, unknown> = {}) => ({
  conversationId: 'c0ffee',
  user: 'alice',
  own: true,
  released: true,
  failedPair: '',
  turns: [
    {
      seq: 1,
      appendedAt: '2026-09-27T10:00:00Z',
      message: 'What runs tonight?',
      state: 'completed',
      reply: 'Two tasks run tonight.',
      error: null,
      steps: [{ seq: 1, kind: 'tool', name: 'tasks.schedule.read', status: 'ok', summary: '', text: '' }],
      context: { route: 'tasks/schedule', view: { rows: [] } },
    },
  ],
  ...overrides,
});

async function mount(result: JsonResult<unknown>, url = '/agent/transcripts/details/c0ffee') {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      return result as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [provideRouter([{ path: '**', children: [] }]), { provide: ApiService, useValue: api as unknown as ApiService }],
  });
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(TranscriptPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, paths, host: fixture.nativeElement as HTMLElement };
}

afterEach(() => {
  while (planted.length > 0) planted.pop()?.remove();
});

describe('TranscriptPage', () => {
  it('AC1: reads the route id and shows each turn with its message, reply, tool card and screen context', async () => {
    const { fixture, paths, host } = await mount(ok(answer()));
    expect(paths).toEqual(['/api/ocupilot/transcripts/c0ffee']);
    expect(host.querySelector('.ocu-panel-message-user')?.textContent?.trim()).toBe('What runs tonight?');
    expect(host.querySelector('app-reply')?.textContent).toContain('Two tasks run tonight.');
    expect(host.querySelectorAll('app-tool-call-card').length).toBe(1);

    // Mutation (Rule 19): drop the disclosure's context branch -> the route and payload never
    // render and this goes red.
    const toggle = host.querySelector('.ocu-transcript-context-toggle') as HTMLButtonElement;
    expect(toggle.textContent?.trim()).toBe(STRINGS.transcriptScreenContext);
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    toggle.click();
    await settle(fixture);
    expect(toggle.getAttribute('aria-expanded')).toBe('true');
    expect(host.querySelector('.ocu-transcript-context-route')?.textContent?.trim()).toBe('tasks/schedule');
    expect(host.querySelector('.ocu-transcript-context-payload')?.textContent).toContain('"view"');
    expect(host.querySelector('.ocu-transcript-withheld')).toBeNull();
  });

  it('a turn that carried no screen context says so inside the disclosure', async () => {
    const body = answer();
    (body.turns[0] as Record<string, unknown>)['context'] = null;
    const { fixture, host } = await mount(ok(body));
    (host.querySelector('.ocu-transcript-context-toggle') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('.ocu-transcript-context-none')?.textContent?.trim()).toBe(STRINGS.transcriptNoContext);
  });

  it('AC3: a withheld answer names the pair and shows no tool card and no screen context', async () => {
    const body = answer({ own: false, released: false, failedPair: '%Admin_Secure:USE' });
    (body.turns[0] as Record<string, unknown>)['steps'] = [];
    (body.turns[0] as Record<string, unknown>)['context'] = null;
    const { host } = await mount(ok(body));
    expect(host.querySelector('.ocu-transcript-withheld')?.textContent?.trim()).toBe(
      "You need %Admin_Secure:USE to see this transcript's tool results and screen context."
    );
    expect(host.querySelector('.ocu-panel-message-user')?.textContent?.trim()).toBe('What runs tonight?');
    expect(host.querySelector('app-reply')?.textContent).toContain('Two tasks run tonight.');
    expect(host.querySelectorAll('app-tool-call-card').length).toBe(0);
    expect(host.querySelector('.ocu-transcript-context-toggle')).toBeNull();
  });

  it('a 404 shows the no-longer-present sentence', async () => {
    const { host } = await mount(notFound());
    expect(host.querySelector('.ocu-data-table-empty-title')?.textContent?.trim()).toBe(
      STRINGS.faultAbsentEntity.replace('<name>', STRINGS.agentTranscriptLabel)
    );
    expect(host.querySelector('.ocu-panel-turn')).toBeNull();
  });
});

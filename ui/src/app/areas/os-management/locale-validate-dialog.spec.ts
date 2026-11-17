import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { LocaleValidateDialog } from './locale-validate-dialog';

/**
 * The Validate dialog (Story 21.14, AD-39): the one read it makes, the two verdict sentences, no line the instance wrote, the instance's own
 * sentence for a refusal, and one `closed` on every dismissal path. Only the server's answers are stubbed.
 */

@Component({
  imports: [LocaleValidateDialog],
  template: `<app-locale-validate-dialog [name]="name" (closed)="closed = closed + 1" />`,
})
class Host {
  name = 'enuw';
  closed = 0;
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 3; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(answer: JsonResult<unknown>, name = 'enuw') {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      paths.push(path);
      return answer as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.name = name;
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, paths };
}

const result = (host: HTMLElement): string | null => host.querySelector('[data-locale-validate-result]')?.textContent?.trim() ?? null;

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Validate dialog', () => {
  // Mutation (Rule 19): read `Valid` from another member -> a valid locale reads "has problems" and this goes red.
  it('reads the locale\u2019s validation once, titled Validate, and says it is valid', async () => {
    const { host, paths } = await mount({ kind: 'ok', status: 200, body: { Name: 'enuw', Valid: true, Installable: true, Errors: [], Warnings: [] } });
    expect(paths).toEqual(['/api/ocupilot/locales/enuw/validation']);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.licenseKeyValidate);
    expect(host.querySelector('[data-locale-validate-name]')?.textContent?.trim()).toBe('enuw');
    expect(result(host)).toBe(STRINGS.localeValidateValid);
    expect(STRINGS.localeValidateValid).toBe('This locale is valid.');
  });

  // Mutation (Rule 19): draw the answer's `Errors` lines in the dialog -> the line's text appears and this goes red.
  it('says a locale has problems in one sentence and draws none of the instance\u2019s lines', async () => {
    const { host } = await mount({
      kind: 'ok',
      status: 200,
      body: { Name: 'deuw', Valid: false, Installable: true, Errors: ['Table is not compiled'], Warnings: ['A warning line'], ErrorCount: 1, WarningCount: 1, Truncated: false },
    });
    expect(result(host)).toBe(STRINGS.localeValidateProblems);
    expect(STRINGS.localeValidateProblems).toBe('This locale has problems.');
    expect(host.textContent).not.toContain('Table is not compiled');
    expect(host.textContent).not.toContain('A warning line');
  });

  it('encodes the locale\u2019s name as an entity id in the route', async () => {
    const { paths } = await mount({ kind: 'ok', status: 200, body: { Valid: true } }, 'yzz w');
    expect(paths[0]).toMatch(/^\/api\/ocupilot\/locales\/[^/]+\/validation$/);
    expect(paths[0]).not.toContain(' ');
  });

  it('draws the instance\u2019s own sentence for a locale it does not list, and no verdict', async () => {
    const { host } = await mount({ kind: 'error', status: 404, code: 'LOCALE.NOTFOUND', reason: STRINGS.localeRefusalNotFound, detail: null });
    expect(host.querySelector('[data-locale-validate-refusal]')?.textContent?.trim()).toBe(STRINGS.localeRefusalNotFound);
    expect(result(host)).toBeNull();
  });

  it('emits closed once, however it is dismissed', async () => {
    const { fixture, host } = await mount({ kind: 'ok', status: 200, body: { Valid: true } });
    const close = host.querySelector('.ocu-dialog-actions button') as HTMLButtonElement;
    expect(close.textContent?.trim()).toBe(STRINGS.auditDialogClose);
    close.click();
    close.click();
    await settle(fixture);
    expect(fixture.componentInstance.closed).toBe(1);
  });
});

import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { AuditEventEditorDialog } from './audit-event-editor-dialog';
import { AUDIT_EVENTS_FORM_PATH, AuditEventEditor } from './audit-event-editor.store';

/**
 * The user audit event editor dialog (AC1, AC2): its fields in the classic dialog's order, Enabled
 * checked on a create and absent on an edit, the identity read-only over an existing event, the
 * server's bounds as `maxlength`, a refusal on the field it names, and every dismissal handed to its
 * host. jsdom computes no layout; nothing here asserts geometry.
 */

const FORM = { maxLengths: { Source: 64, Type: 64, Name: 64, Description: 256 } };

const REFUSAL = {
  kind: 'error',
  status: 422,
  code: 'AUDITEVENT.VALIDATION',
  reason: 'The audit event was refused.',
  detail: { violations: [{ field: 'Type', code: 'AUDITEVENT.PART.RESERVED', reason: STRINGS.auditEventRefusalPartReserved }] },
} as unknown as JsonResult<unknown>;

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

async function mount(mode: 'create' | 'edit') {
  const api = {
    requestJson: async <T,>(path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if (path === AUDIT_EVENTS_FORM_PATH) return { kind: 'ok', status: 200, body: FORM } as unknown as JsonResult<T>;
      if (path.startsWith(`${AUDIT_EVENTS_FORM_PATH}?`)) {
        return { kind: 'ok', status: 200, body: { ...FORM, event: { Source: 'App', Type: 'Kind', Name: 'One', Description: 'old', Enabled: true } } } as unknown as JsonResult<T>;
      }
      return REFUSAL as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    imports: [AuditEventEditorDialog],
    providers: [
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: FormDirty, useValue: new FormDirty() },
    ],
  });
  const store = TestBed.inject(AuditEventEditor);
  if (mode === 'create') await store.openCreate();
  else await store.openEdit('App/Kind/One');
  const fixture = TestBed.createComponent(AuditEventEditorDialog);
  let closeRequests = 0;
  fixture.componentInstance.closeRequested.subscribe(() => (closeRequests += 1));
  fixture.detectChanges();
  await settle();
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, closeRequests: () => closeRequests };
}

function input(host: HTMLElement, field: string): HTMLInputElement {
  return host.querySelector<HTMLInputElement>(`#ocu-audit-event-${field}`)!;
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the user audit event editor dialog', () => {
  it('AC1: create mode captures Source, Type, Name, Description and Enabled, in that order, Enabled checked', async () => {
    const { host } = await mount('create');
    expect([...host.querySelectorAll<HTMLInputElement>('input')].map((element) => element.id)).toEqual([
      'ocu-audit-event-Source',
      'ocu-audit-event-Type',
      'ocu-audit-event-Name',
      'ocu-audit-event-Description',
      'ocu-audit-event-Enabled',
    ]);
    expect([...host.querySelectorAll('.ocu-field-label, .ocu-field-checkbox span')].map((node) => node.textContent?.trim())).toEqual([
      STRINGS.auditEventFieldSource,
      STRINGS.tableColumnType,
      STRINGS.tableColumnName,
      STRINGS.tableColumnDescription,
      STRINGS.tableColumnEnabled,
    ]);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.auditUserEventEditorCreate);
    expect(input(host, 'Enabled').checked).toBe(true);
    expect(input(host, 'Source').readOnly).toBe(false);
    expect(input(host, 'Name').getAttribute('maxlength')).toBe('64');
    expect(input(host, 'Description').getAttribute('maxlength')).toBe('256');
  });

  it('AC2: edit mode shows the event with its identity read-only and no Enabled control', async () => {
    const { host } = await mount('edit');
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.auditUserEventEditorEdit.replace('<name>', 'App/Kind/One'));
    // Mutation (Rule 19): drop the identity fields' `readOnly` in edit mode -> this goes red.
    expect(['Source', 'Type', 'Name'].map((field) => [input(host, field).value, input(host, field).readOnly])).toEqual([
      ['App', true],
      ['Kind', true],
      ['One', true],
    ]);
    expect(input(host, 'Description').readOnly).toBe(false);
    expect(input(host, 'Description').value).toBe('old');
    expect(host.querySelector('#ocu-audit-event-Enabled')).toBeNull();
  });

  it('AD-39: a refused Save renders the server sentence at the field it names and in the summary', async () => {
    const { fixture, host } = await mount('create');
    const type = input(host, 'Type');
    type.value = '%T';
    type.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    host.querySelector<HTMLButtonElement>('button.ocu-button-primary')!.click();
    await settle();
    fixture.detectChanges();
    expect(host.querySelector('#ocu-audit-event-Type-reason')?.textContent?.trim()).toBe(STRINGS.auditEventRefusalPartReserved);
    expect(input(host, 'Type').getAttribute('aria-invalid')).toBe('true');
    expect(input(host, 'Type').getAttribute('aria-describedby')).toBe('ocu-audit-event-Type-reason');
    expect(host.querySelector('.ocu-form-summary')?.textContent).toContain(STRINGS.auditEventRefusalPartReserved);
  });

  it('every dismissal is handed to the host', async () => {
    const { host, closeRequests } = await mount('create');
    const cancel = [...host.querySelectorAll<HTMLButtonElement>('button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel);
    expect(cancel).toBeDefined();
    cancel!.click();
    expect(closeRequests()).toBe(1);
  });
});

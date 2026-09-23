import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { ResourceEditorDialog } from './resource-editor-dialog';
import { RESOURCES_FORM_PATH, RESOURCES_NAME_PATH, ResourceEditor } from './resource-editor.store';

/**
 * The resource editor dialog (AC1, AC6, AC7): its fields in the classic dialog's order, the name
 * read-only over an existing resource, one checkbox per letter the server's rule admits, the
 * privileged-grant consequence at the fieldset while a letter is checked on a privileged name, and
 * every dismissal handed to its host, which asks first. jsdom computes no layout; nothing here
 * asserts geometry.
 */

const RULES = {
  requiredFields: ['Name'],
  maxLengths: { Name: 64, Description: 256 },
  rules: [],
  letterRules: { letters: 'RWU', prefixes: [{ prefix: '%DB_', letters: 'RW' }, { prefix: '%Admin_', letters: 'U' }] },
};

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

async function mount(mode: 'create' | 'edit', resource: Record<string, unknown> = {}, privilegedName = false) {
  const api = {
    requestJson: async <T,>(path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if (path === RESOURCES_FORM_PATH) return { kind: 'ok', status: 200, body: RULES } as unknown as JsonResult<T>;
      if (path.startsWith(`${RESOURCES_FORM_PATH}?`)) {
        return { kind: 'ok', status: 200, body: { ...RULES, resource } } as unknown as JsonResult<T>;
      }
      if (path.startsWith(RESOURCES_NAME_PATH)) {
        return { kind: 'ok', status: 200, body: { taken: false, reason: '', privileged: privilegedName } } as unknown as JsonResult<T>;
      }
      return { kind: 'ok', status: 200, body: {} } as unknown as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    imports: [ResourceEditorDialog],
    providers: [
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: FormDirty, useValue: formDirty },
    ],
  });
  const store = TestBed.inject(ResourceEditor);
  if (mode === 'create') await store.openCreate();
  else await store.openEdit(String(resource['name'] ?? 'ProbeResource'));
  const fixture = TestBed.createComponent(ResourceEditorDialog);
  let closeRequests = 0;
  fixture.componentInstance.closeRequested.subscribe(() => (closeRequests += 1));
  fixture.detectChanges();
  await settle();
  fixture.detectChanges();
  const host = fixture.nativeElement as HTMLElement;
  return { fixture, host, store, formDirty, closeRequests: () => closeRequests };
}

function typeInto(input: HTMLInputElement, value: string): void {
  input.value = value;
  input.dispatchEvent(new Event('input'));
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the resource editor dialog', () => {
  it('AC1: create mode captures name, description and public permission, in that order', async () => {
    const { host } = await mount('create');
    const controls = [...host.querySelectorAll<HTMLElement>('input, fieldset')].map((element) => element.id);
    expect(controls.slice(0, 3)).toEqual(['ocu-resource-Name', 'ocu-resource-Description', 'ocu-resource-PublicPermission']);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.resourceEditorCreate);
    expect(host.querySelector<HTMLInputElement>('#ocu-resource-Name')!.readOnly).toBe(false);
    expect([...host.querySelectorAll('fieldset input[type="checkbox"]')].map((box) => box.id)).toEqual([
      'ocu-resource-PublicPermission-R',
      'ocu-resource-PublicPermission-W',
      'ocu-resource-PublicPermission-U',
    ]);
  });

  it('AC1: edit mode shows the resource with its name read-only, and only the letters it admits', async () => {
    // Mutation (Rule 19): drop `[readOnly]="editing"` from the name input -> this goes red.
    const { host } = await mount('edit', { name: '%DB_Probe', Description: 'old', PublicPermission: 'R', privileged: false });
    const name = host.querySelector<HTMLInputElement>('#ocu-resource-Name')!;
    expect(name.readOnly).toBe(true);
    expect(name.value).toBe('%DB_Probe');
    expect(host.querySelector<HTMLInputElement>('#ocu-resource-Description')!.value).toBe('old');
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.resourceEditorEdit.replace('<name>', '%DB_Probe'));
    expect(host.querySelector<HTMLInputElement>('#ocu-resource-PublicPermission-R')!.checked).toBe(true);
    expect(host.querySelector('#ocu-resource-PublicPermission-U')).toBeNull();
    // Mutation (Rule 19): treat every edited resource as privileged in `openEdit` -> this goes red.
    expect(host.querySelector('#ocu-resource-effect')).toBeNull();
  });

  it('a letter the resource holds outside the rule is still drawn, so it can be cleared', async () => {
    // Mutation (Rule 19): draw `admitted()` alone in `letterViews` -> the R checkbox is missing.
    const { host } = await mount('edit', { name: '%Admin_Probe', Description: '', PublicPermission: 'RU', privileged: true });
    expect(host.querySelector<HTMLInputElement>('#ocu-resource-PublicPermission-R')?.checked).toBe(true);
    expect(host.querySelector<HTMLInputElement>('#ocu-resource-PublicPermission-U')?.checked).toBe(true);
    expect(host.querySelector('#ocu-resource-PublicPermission-W')).toBeNull();
  });

  it('AC6: the consequence is stated at the fieldset while a letter is checked on a privileged name', async () => {
    // Mutation (Rule 19): make the dialog's `showEffect` answer false -> this goes red.
    const { fixture, host } = await mount('edit', { name: '%Admin_Probe', Description: '', PublicPermission: '', privileged: true });
    const fieldset = host.querySelector<HTMLElement>('#ocu-resource-PublicPermission')!;
    expect(host.querySelector('#ocu-resource-effect')).toBeNull();
    const use = host.querySelector<HTMLInputElement>('#ocu-resource-PublicPermission-U')!;
    use.checked = true;
    use.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    expect(host.querySelector('#ocu-resource-effect')?.textContent?.trim()).toBe(STRINGS.privilegedGrantEffect);
    expect(fieldset.getAttribute('aria-describedby')).toBe('ocu-resource-effect');
  });

  it('AC6: in create mode the name look-up decides whether the consequence is stated', async () => {
    const { fixture, host } = await mount('create', {}, true);
    typeInto(host.querySelector<HTMLInputElement>('#ocu-resource-Name')!, '%Admin_Probe');
    host.querySelector<HTMLInputElement>('#ocu-resource-Name')!.dispatchEvent(new Event('blur'));
    await settle();
    fixture.detectChanges();
    const use = host.querySelector<HTMLInputElement>('#ocu-resource-PublicPermission-U')!;
    use.checked = true;
    use.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    expect(host.querySelector('#ocu-resource-effect')).not.toBeNull();
  });

  it('Save is aria-disabled over a resource the instance does not hold', async () => {
    const api = {
      requestJson: async <T,>(path: string): Promise<JsonResult<T>> =>
        (path.startsWith(`${RESOURCES_FORM_PATH}?`)
          ? { kind: 'error', status: 404, code: 'RESOURCE.NAME.ABSENT', reason: 'This instance has no resource with that name.', detail: null }
          : { kind: 'ok', status: 200, body: RULES }) as unknown as JsonResult<T>,
    };
    TestBed.configureTestingModule({
      imports: [ResourceEditorDialog],
      providers: [
        { provide: OverlayStack, useValue: new OverlayStack() },
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: ChangeBus, useValue: new ChangeBus() },
        { provide: FormDirty, useValue: new FormDirty() },
      ],
    });
    await TestBed.inject(ResourceEditor).openEdit('Gone');
    const fixture = TestBed.createComponent(ResourceEditorDialog);
    fixture.detectChanges();
    const host = fixture.nativeElement as HTMLElement;
    const save = [...host.querySelectorAll<HTMLButtonElement>('button')].find((button) => button.textContent?.trim() === STRINGS.actionSave)!;
    // Mutation (Rule 19): make `saveBlocked` answer `busy()` alone -> this goes red.
    expect(save.getAttribute('aria-disabled')).toBe('true');
  });

  it('AC7: a change marks the form dirty, and Cancel hands the close to the host, which asks first', async () => {
    // Mutation (Rule 19): make `ResourceEditor.requestClose()` reset without asking -> the pending
    // assertion goes red.
    const { fixture, host, store, formDirty, closeRequests } = await mount('create');
    typeInto(host.querySelector<HTMLInputElement>('#ocu-resource-Description')!, 'typed');
    fixture.detectChanges();
    expect(formDirty.dirty()).toBe(true);
    const cancel = [...host.querySelectorAll<HTMLButtonElement>('button')].find(
      (button) => button.textContent?.trim() === STRINGS.actionCancel
    )!;
    cancel.click();
    expect(closeRequests()).toBe(1);
    const closing = store.requestClose();
    expect(formDirty.pending()).toBe(true);
    formDirty.answer(false);
    expect(await closing).toBe(false);
    expect(store.description()).toBe('typed');
  });
});

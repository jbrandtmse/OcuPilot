import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { DeviceFormPage } from './device-form.page';
import { DEVICE_FORM_PATH, DeviceForm } from './device-form.store';

/**
 * The device editor over stubs of the two things an instance supplies -- the URL's screen and the
 * HTTP answers. The real store, the real `FormDirty`, the real dialog and the real template run, so
 * the assertions are about rendered DOM (AC1, AC6).
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.DeviceForm');

const RULES = {
  requiredFields: ['Name', 'PhysicalDevice', 'Type', 'SubType'],
  maxLengths: { Name: 64, PhysicalDevice: 128, OpenParameters: 128, AlternateDevice: 128, Description: 256 },
  rules: [],
  typeValues: ['TRM', 'SPL', 'MT', 'BT', 'IPC', 'OTH'],
  subTypes: ['C-VT220', 'P-DEC'],
};

const DEVICE = {
  Name: 'ProbeDevice',
  PhysicalDevice: '/tmp/probe.txt',
  Type: 'TRM',
  SubType: 'C-VT220',
  OpenParameters: '',
  Description: 'probe',
  Alias: 9955,
  AlternateDevice: '',
  Prompt: 1,
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** The Save a reader without the device tools' write pair is refused with (AD-8). */
const WRITE_PAIR = '%DB_IRISSYS:WRITE';

const NO_WRITE_PAIR = {
  kind: 'error',
  status: 403,
  code: 'AUTH.NOPRIVILEGE',
  reason: 'Forbidden',
  detail: { failedPair: WRITE_PAIR },
};

async function mount(url = '/os-management/devices/edit', absent = false, refuseSave = false) {
  TestBed.resetTestingModule();
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string } = {}): Promise<JsonResult<T>> => {
      if ((init.method ?? 'GET') !== 'GET' && refuseSave) return NO_WRITE_PAIR as unknown as JsonResult<T>;
      if ((init.method ?? 'GET') !== 'GET') return { kind: 'ok', status: 201, body: { name: 'ProbeDevice' } } as JsonResult<T>;
      if (absent && path !== DEVICE_FORM_PATH) {
        return { kind: 'error', status: 404, code: 'DEVICE.NAME.ABSENT', reason: 'No such device.', detail: null } as unknown as JsonResult<T>;
      }
      const body = path === DEVICE_FORM_PATH ? RULES : { ...RULES, device: DEVICE };
      return { kind: 'ok', status: 200, body } as unknown as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => FORM_SCREEN ?? null } as unknown as NavigationService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(DeviceFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, formDirty, host: fixture.nativeElement as HTMLElement };
}

function labels(host: HTMLElement): string[] {
  return [...host.querySelectorAll('.ocu-form-fields .ocu-field-label')].map((label) => label.textContent?.trim() ?? '');
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, id: string, value: string): void {
  const control = host.querySelector(`#${id}`) as HTMLInputElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the device editor', () => {
  it("AC1: a create shows the classic device page's nine fields, in its order, the first four required", async () => {
    const { host } = await mount();
    // Mutation (Rule 19): move the Alias block above Description in the template -> red.
    expect(labels(host)).toEqual([
      STRINGS.tableColumnName,
      STRINGS.deviceColumnPhysical,
      STRINGS.tableColumnType,
      STRINGS.deviceColumnSubtype,
      STRINGS.deviceFieldOpenParameters,
      STRINGS.tableColumnDescription,
      STRINGS.x509ColumnAlias,
      STRINGS.deviceFieldAlternate,
      STRINGS.deviceFieldPrompt,
    ]);
    const required = [...host.querySelectorAll('.ocu-field-label-required')].map((label) => label.textContent?.trim());
    expect(required).toEqual([STRINGS.tableColumnName, STRINGS.deviceColumnPhysical, STRINGS.tableColumnType, STRINGS.deviceColumnSubtype]);
    const types = [...host.querySelectorAll('#ocu-device-Type option')] as HTMLOptionElement[];
    expect(types.map((option) => option.textContent?.trim())).toEqual([
      STRINGS.deviceTypeTerminal,
      STRINGS.deviceTypeSpool,
      STRINGS.deviceTypeMagTape,
      STRINGS.deviceTypeCartridge,
      STRINGS.deviceTypeIpc,
      STRINGS.deviceTypeOther,
    ]);
    expect(types.map((option) => option.value)).toEqual(['TRM', 'SPL', 'MT', 'BT', 'IPC', 'OTH']);
    expect((host.querySelector('#ocu-device-Type') as HTMLSelectElement).value).toBe('OTH');
    expect((host.querySelector('#ocu-device-SubType') as HTMLSelectElement).value).toBe('P-DEC');
    const prompts = [...host.querySelectorAll('input[name="ocu-device-Prompt"]')] as HTMLInputElement[];
    expect(prompts.map((radio) => radio.value)).toEqual(['', '1', '2']);
    expect(prompts.map((radio) => radio.checked)).toEqual([true, false, false]);
    expect([...host.querySelectorAll('.ocu-form-fields .ocu-field-checkbox span')].map((span) => span.textContent?.trim())).toEqual([
      STRINGS.devicePromptShow,
      STRINGS.devicePromptAuto,
      STRINGS.devicePromptPredefined,
    ]);
    expect((host.querySelector('#ocu-device-Alias') as HTMLInputElement).getAttribute('inputmode')).toBe('numeric');
  });

  it('an edit shows the name read-only and the fresh read in every field', async () => {
    const { host } = await mount('/os-management/devices/edit/ProbeDevice');
    const name = host.querySelector('#ocu-device-Name') as HTMLInputElement;
    expect(name.readOnly).toBe(true);
    expect(name.value).toBe('ProbeDevice');
    expect((host.querySelector('#ocu-device-Type') as HTMLSelectElement).value).toBe('TRM');
    expect((host.querySelector('#ocu-device-SubType') as HTMLSelectElement).value).toBe('C-VT220');
    expect((host.querySelector('#ocu-device-Alias') as HTMLInputElement).value).toBe('9955');
    const checked = [...host.querySelectorAll('input[name="ocu-device-Prompt"]')].find((radio) => (radio as HTMLInputElement).checked) as HTMLInputElement;
    expect(checked.value).toBe('1');
  });

  it('an alias that is not a whole number is kept as typed, for the server to refuse, never cleared', async () => {
    const { fixture, host } = await mount('/os-management/devices/edit/ProbeDevice');
    type(fixture, host, 'ocu-device-Alias', '12e');
    await settle(fixture);
    // Mutation (Rule 19): make the Alias input `type="number"` -> the browser reads unparsable text as
    // '', the edit would clear the stored alias, and this goes red.
    expect(TestBed.inject(DeviceForm).value('Alias')).toBe('12e');
  });

  it('AC6: a change raises the dirty flag, and leaving asks the shared question first', async () => {
    const { fixture, host, formDirty } = await mount();
    expect(formDirty.dirty()).toBe(false);
    type(fixture, host, 'ocu-device-Name', 'ProbeDevice');
    await settle(fixture);
    // Mutation (Rule 19): make the store's `change` clear `FormDirty` -> red, and every navigation
    // away, the agent's included, leaves without asking.
    expect(formDirty.dirty()).toBe(true);

    const asked = formDirty.requestLeave();
    await settle(fixture);
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement;
    expect(dialog).not.toBeNull();
    expect(dialog.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.formLeaveWithoutSaving);
    (dialog.querySelectorAll('.ocu-dialog-actions button')[0] as HTMLButtonElement).click();
    await settle(fixture);
    expect(await asked).toBe(false);
    expect(formDirty.dirty()).toBe(true);
    expect(host.querySelector('[role="dialog"]')).toBeNull();
  });

  it('a Save refused for the write pair names the pair and the action, in both modes (AD-8)', async () => {
    // Mutation (Rule 19): read `detail.missingPair` in the store's `rememberRefusal` -> both banners
    // fall back to the envelope's reason, red; resolve the create's action in both modes -> the
    // edit's banner red.
    for (const [url, action] of [
      ['/os-management/devices/edit', STRINGS.deviceListEmptyAgent],
      ['/os-management/devices/edit/ProbeDevice', STRINGS.deviceFormRefusedAction],
    ] as const) {
      const { fixture, host } = await mount(url, false, true);
      type(fixture, host, url.endsWith('ProbeDevice') ? 'ocu-device-Description' : 'ocu-device-Name', 'ProbeChanged');
      (host.querySelector('.ocu-form-bar-actions button.ocu-button-primary') as HTMLButtonElement).click();
      await settle(fixture);
      const banner = host.querySelector('.ocu-banner[role="alert"]');
      expect(banner?.textContent?.trim()).toBe(`You need ${WRITE_PAIR} to ${action}.`);
      for (const node of planted.splice(0)) node.remove();
    }
  });

  it('an edit of a device the instance does not hold renders Save aria-disabled', async () => {
    const { host } = await mount('/os-management/devices/edit/ProbeAbsent', true);
    const save = host.querySelector('.ocu-form-bar-actions button.ocu-button-primary') as HTMLButtonElement;
    expect(save).not.toBeNull();
    expect(save.getAttribute('aria-disabled')).toBe('true');
  });
});

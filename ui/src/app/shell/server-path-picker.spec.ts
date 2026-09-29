import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { AllowedDirectoriesStore } from '../core/allowed-directories';
import type { ApiService } from '../core/api';
import { STRINGS } from '../core/strings';
import { ServerPathPicker, type ServerPath } from './server-path-picker';

@Component({
  selector: 'app-path-picker-host',
  imports: [ServerPathPicker],
  template: `<app-server-path-picker
    [store]="store"
    [kind]="kind()"
    [root]="root()"
    [path]="path()"
    [rootReason]="rootReason()"
    [pathReason]="pathReason()"
    idPrefix="probe"
    (changed)="onChanged($event)"
  />`,
})
class Host {
  readonly store = new AllowedDirectoriesStore();
  readonly kind = signal<'directory' | 'file'>('directory');
  readonly root = signal('');
  readonly path = signal('');
  readonly rootReason = signal('');
  readonly pathReason = signal('');
  readonly changes: ServerPath[] = [];

  onChanged(change: ServerPath): void {
    this.changes.push(change);
    this.root.set(change.root);
    this.path.set(change.path);
  }
}

type Api = Pick<ApiService, 'requestJson'>;

/** An api whose every request answers `answer`. */
function fakeApi(answer: unknown): Api {
  return { requestJson: async () => answer } as unknown as Api;
}

/** A read answering `rows`, as the screen read route does. */
function answering(rows: readonly unknown[], truncated = false): Api {
  return fakeApi({ kind: 'ok', status: 200, body: { fields: ['Directory', 'Restricted'], rows, truncated, banner: '' } });
}

describe('the server-path picker (Story 18.1, AD-21)', () => {
  let fixture: ReturnType<typeof TestBed.createComponent<Host>>;
  let host: HTMLElement;

  beforeEach(() => {
    fixture = TestBed.createComponent(Host);
    host = fixture.nativeElement as HTMLElement;
    document.body.appendChild(host);
  });

  afterEach(() => {
    host.remove();
    TestBed.resetTestingModule();
  });

  async function settle(): Promise<void> {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  async function ready(rows: readonly unknown[], truncated = false): Promise<void> {
    await fixture.componentInstance.store.load(answering(rows, truncated));
    await settle();
  }

  function select(): HTMLSelectElement | null {
    return host.querySelector('select');
  }

  function input(): HTMLInputElement | null {
    return host.querySelector('input');
  }

  function slot(name: string): HTMLElement | null {
    return host.querySelector(`[data-slot="${name}"]`);
  }

  const TWO = [
    { Directory: '/tmp/', Restricted: true },
    { Directory: '/usr/irissys/', Restricted: true },
  ];

  it('draws only the loading line while the store is loading', async () => {
    void fixture.componentInstance.store.load({ requestJson: () => new Promise(() => undefined) } as unknown as Api);
    await settle();
    expect(slot('loading')?.textContent?.trim()).toBe(STRINGS.pathPickerLoading);
    expect(select()).toBeNull();
    expect(input()).toBeNull();
  });

  // Mutation (Rule 19): drop the picker's store subscription -> it stays on the loading line and
  // this goes red.
  it('follows the store from loading to ready after it has drawn', async () => {
    let open: () => void = () => undefined;
    const gate = new Promise<void>((resolve) => {
      open = resolve;
    });
    const answer = { kind: 'ok', status: 200, body: { fields: ['Directory', 'Restricted'], rows: [{ Directory: '/tmp/', Restricted: true }], truncated: false, banner: '' } };
    const held = { requestJson: async () => { await gate; return answer; } } as unknown as Api;
    const loaded = fixture.componentInstance.store.load(held);
    await settle();
    expect(slot('loading')).not.toBeNull();
    open();
    await loaded;
    await settle();
    expect(slot('loading')).toBeNull();
    expect(select()?.value).toBe('/tmp/');
    expect(fixture.componentInstance.changes).toEqual([{ root: '/tmp/', path: '', preselected: true }]);
  });

  // Mutation (Rule 19): render the select in the refused state -> this goes red.
  it("draws the store's reason and no control when the read was refused", async () => {
    const reason = 'This account does not hold the privilege this request requires.';
    await fixture.componentInstance.store.load(
      fakeApi({ kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason, detail: { failedPair: '%Admin_FileSystemAccess:USE' } })
    );
    await settle();
    expect(slot('refused')?.textContent?.trim()).toBe(reason);
    expect(select()).toBeNull();
    expect(input()).toBeNull();
  });

  it('draws the empty line and no control when the allow-list names no directory', async () => {
    await ready([]);
    expect(slot('empty')?.textContent?.trim()).toBe(STRINGS.allowedDirectoriesEmpty);
    expect(select()).toBeNull();
    expect(input()).toBeNull();
  });

  it('offers exactly the roots in read order, chooses none of several, and labels one relative-name field', async () => {
    await ready(TWO);
    const options = [...(select() as HTMLSelectElement).options].map((option) => option.value);
    expect(options).toEqual(['/tmp/', '/usr/irissys/']);
    expect(select()?.selectedIndex).toBe(-1);
    expect(host.querySelector(`label[for="${select()?.id}"]`)?.textContent?.trim()).toBe(STRINGS.pathPickerRootLabel);
    expect(host.querySelectorAll('input')).toHaveLength(1);
    expect(host.querySelector(`label[for="${input()?.id}"]`)?.textContent?.trim()).toBe(STRINGS.pathPickerSubdirectoryLabel);
    expect(slot('resolved')).toBeNull();
    expect(slot('truncated')).toBeNull();
    expect(fixture.componentInstance.changes).toEqual([]);
  });

  // Mutation (Rule 19): render the consumer's root as an option when the store did not read it ->
  // the options assertion goes red.
  it('does not select, or offer, a root the store did not read', async () => {
    fixture.componentInstance.root.set('/etc/');
    await ready(TWO);
    expect([...(select() as HTMLSelectElement).options].map((option) => option.value)).toEqual(['/tmp/', '/usr/irissys/']);
    expect(select()?.selectedIndex).toBe(-1);
    expect(slot('resolved')).toBeNull();
  });

  // Mutation (Rule 19): drop `preselected` from the preselection's report -> the first assertion
  // goes red; mark a user's input `preselected` -> the last one does.
  it('preselects a single root and reports it once, marked preselected, so the consumer holds it and can tell it from a user change', async () => {
    await ready([{ Directory: '/tmp/', Restricted: true }]);
    expect(select()?.value).toBe('/tmp/');
    expect(fixture.componentInstance.changes).toEqual([{ root: '/tmp/', path: '', preselected: true }]);
    await settle();
    expect(fixture.componentInstance.changes).toHaveLength(1);
    expect(slot('resolved')?.textContent).toBe(STRINGS.pathPickerResolvesTo.replace('<path>', '/tmp/'));
    const name = input() as HTMLInputElement;
    name.value = 'dbs';
    name.dispatchEvent(new Event('input'));
    await settle();
    expect(fixture.componentInstance.changes.at(-1)).toStrictEqual({ root: '/tmp/', path: 'dbs' });
  });

  it('reports every change as {root, path} and shows the composed path, display only', async () => {
    await ready(TWO);
    const chosen = select() as HTMLSelectElement;
    chosen.value = '/usr/irissys/';
    chosen.dispatchEvent(new Event('change'));
    await settle();
    expect(fixture.componentInstance.changes).toEqual([{ root: '/usr/irissys/', path: '' }]);
    expect(select()?.value).toBe('/usr/irissys/');

    const name = input() as HTMLInputElement;
    name.value = 'exports/2026';
    name.dispatchEvent(new Event('input'));
    await settle();
    expect(fixture.componentInstance.changes.at(-1)).toEqual({ root: '/usr/irissys/', path: 'exports/2026' });
    expect(slot('resolved')?.querySelector('code')?.textContent).toBe('/usr/irissys/exports/2026/');
    expect((input() as HTMLInputElement).getAttribute('aria-describedby')).toBe(slot('resolved')?.id);
  });

  it('labels the relative name a file name for a file, and composes no trailing separator', async () => {
    fixture.componentInstance.kind.set('file');
    fixture.componentInstance.path.set('exports/t.xml');
    await ready([{ Directory: '/tmp/', Restricted: true }]);
    expect(host.querySelector(`label[for="${input()?.id}"]`)?.textContent?.trim()).toBe(STRINGS.pathPickerFileLabel);
    expect(slot('resolved')?.querySelector('code')?.textContent).toBe('/tmp/exports/t.xml');
  });

  it("draws the instance's reasons on the field each names, read with it", async () => {
    await ready(TWO);
    fixture.componentInstance.root.set('/tmp/');
    fixture.componentInstance.rootReason.set("That directory is not one of the instance's allowed directories.");
    fixture.componentInstance.pathReason.set('Name a directory or file under it.');
    await settle();
    const rootControl = select() as HTMLSelectElement;
    const nameControl = input() as HTMLInputElement;
    expect(rootControl.getAttribute('aria-invalid')).toBe('true');
    const rootReason = host.querySelector(`#${rootControl.getAttribute('aria-describedby')}`);
    expect(rootReason?.textContent?.trim()).toBe("That directory is not one of the instance's allowed directories.");
    expect(nameControl.getAttribute('aria-invalid')).toBe('true');
    const described = (nameControl.getAttribute('aria-describedby') ?? '').split(' ');
    expect(described).toContain('probe-path-reason');
    expect(host.querySelector('#probe-path-reason')?.textContent?.trim()).toBe('Name a directory or file under it.');

    fixture.componentInstance.rootReason.set('');
    fixture.componentInstance.pathReason.set('');
    await settle();
    expect(select()?.getAttribute('aria-invalid')).toBeNull();
    expect(input()?.getAttribute('aria-invalid')).toBeNull();
  });

  it('says so when the read was cut at its cap, read with the select', async () => {
    await ready(TWO, true);
    expect(slot('truncated')?.textContent?.trim()).toBe(STRINGS.pathPickerTruncated.replace('<n>', '2'));
    expect(select()?.getAttribute('aria-describedby')).toBe(slot('truncated')?.id);
  });
});

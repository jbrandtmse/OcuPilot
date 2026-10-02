import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { ScopeService } from '../../core/scope';
import { STRINGS } from '../../core/strings';
import { CodeComparePage } from './code-compare.page';

/**
 * System Explorer's Compare (Story 19.4, AC4): the first document prefilled from `?left=` and both
 * sides on the route's namespace; Compare issuing the class or routine viewer's declared read once
 * per side, each in its own namespace; the diff drawn with signs, announced directions and collapsed
 * runs; the identical and too-large sentences; a refused side named with the instance's reason and
 * nothing drawn; and a re-compare when either document changes.
 */

/** Each document's text, keyed by `<namespace>|<name>`. */
type Texts = Record<string, readonly string[]>;

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

const lines = (count: number, prefix: string): string[] => Array.from({ length: count }, (_, index) => `${prefix}${index}`);

async function mount(texts: Texts, left = 'Demo.Left.cls') {
  TestBed.resetTestingModule();
  const reads: string[] = [];
  const bus = new ChangeBus();
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const name = new URLSearchParams(path.split('?')[1] ?? '').get('name') ?? '';
      const scope = init.scope ?? '';
      reads.push(`${scope} ${path}`);
      const text = texts[`${scope}|${name}`];
      if (text === undefined) {
        return { kind: 'error', status: 404, code: 'PORT.NOTFOUND', reason: 'This namespace holds no document by that name.', detail: null };
      }
      const document = { name, form: 'udl', available: true, content: text, modified: '', database: scope, generates: [] };
      return { kind: 'ok', status: 200, body: { fields: [], rows: [], truncated: false, banner: '', document } as T };
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: ActivatedRoute, useValue: { snapshot: { queryParamMap: convertToParamMap({ left }) } } as unknown as ActivatedRoute },
      {
        provide: ScopeService,
        useValue: {
          loaded: () => true,
          namespace: () => 'HSCUSTOM',
          namespaces: () => [
            { name: 'HSCUSTOM', writable: true, failedPair: '' },
            { name: 'USER', writable: true, failedPair: '' },
          ],
          subscribe: () => () => undefined,
        } as unknown as ScopeService,
      },
    ],
  });
  const fixture = TestBed.createComponent(CodeComparePage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  const host = fixture.nativeElement as HTMLElement;
  const side = (key: string) => host.querySelector(`[data-ocu-compare-side="${key}"]`) as HTMLElement;
  return {
    host,
    reads,
    bus,
    side,
    compare: async (right: string, rightNamespace = '') => {
      const name = side('right').querySelector('[data-ocu-compare="name"]') as HTMLInputElement;
      name.value = right;
      name.dispatchEvent(new Event('input'));
      if (rightNamespace !== '') {
        const select = side('right').querySelector('[data-ocu-compare="namespace"]') as HTMLSelectElement;
        select.value = rightNamespace;
        select.dispatchEvent(new Event('change'));
      }
      (host.querySelector('[data-ocu-compare="submit"]') as HTMLButtonElement).click();
      await settle(fixture);
    },
    settle: () => settle(fixture),
  };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('System Explorer Compare', () => {
  it('prefills the first document from ?left= and opens both sides on the route namespace', async () => {
    const { side, reads } = await mount({});
    expect((side('left').querySelector('[data-ocu-compare="name"]') as HTMLInputElement).value).toBe('Demo.Left.cls');
    expect((side('left').querySelector('[data-ocu-compare="namespace"]') as HTMLSelectElement).value).toBe('HSCUSTOM');
    expect((side('right').querySelector('[data-ocu-compare="namespace"]') as HTMLSelectElement).value).toBe('HSCUSTOM');
    const options = Array.from(side('right').querySelectorAll('option')).map((option) => option.textContent?.trim());
    expect(options).toEqual(['HSCUSTOM', 'USER']);
    expect(reads).toEqual([]);
  });

  it("reads each side through its viewer's declared read in its own namespace and draws the diff", async () => {
    const left = [...lines(8, 'a'), 'old <b>x</b>', ...lines(8, 'b')];
    const right = [...lines(8, 'a'), 'new', ...lines(8, 'b')];
    const { host, reads, compare } = await mount({ 'HSCUSTOM|Demo.Left.cls': left, 'USER|DemoRight.mac': right });
    await compare('DemoRight.mac', 'USER');
    expect(reads).toEqual([
      'HSCUSTOM /api/ocupilot/screens/explorer.class/read?maxRows=1&name=Demo.Left.cls&form=udl',
      'USER /api/ocupilot/screens/explorer.routine/read?maxRows=1&name=DemoRight.mac&form=udl',
    ]);
    expect(host.querySelector('[data-ocu-compare="status"]')?.textContent?.trim()).toBe('1 lines removed \u00b7 1 lines added');
    const diff = host.querySelector('[data-ocu-compare="diff"]') as HTMLElement;
    expect(diff.getAttribute('tabindex')).toBe('0');
    expect(Array.from(diff.querySelectorAll('[data-ocu-diff="collapsed"]')).map((node) => node.textContent?.trim())).toEqual(['5 unchanged lines', '5 unchanged lines']);
    const removed = diff.querySelector('[data-ocu-diff="removed"]') as HTMLElement;
    expect(removed.querySelector('.ocu-line-diff-sign')?.textContent).toBe('\u2212');
    expect(removed.querySelector('.ocu-diff-direction')?.textContent).toBe(STRINGS.proposalDiffRemoved);
    expect(removed.querySelector('.ocu-line-diff-text')?.textContent).toBe('old <b>x</b>');
    expect(removed.querySelector('b')).toBeNull();
    const added = diff.querySelector('[data-ocu-diff="added"]') as HTMLElement;
    expect(added.querySelector('.ocu-line-diff-sign')?.textContent).toBe('+');
    expect(added.querySelector('.ocu-diff-direction')?.textContent).toBe(STRINGS.explorerDiffAdded);
    expect(diff.querySelectorAll('[data-ocu-diff="same"]')).toHaveLength(6);
  });

  it('says two identical documents are identical and draws nothing', async () => {
    const { host, compare } = await mount({ 'HSCUSTOM|Demo.Left.cls': ['a', 'b'], 'HSCUSTOM|Demo.Right.cls': ['a', 'b'] });
    await compare('Demo.Right.cls');
    expect(host.querySelector('[data-ocu-compare="status"]')?.textContent?.trim()).toBe(STRINGS.explorerCompareIdentical);
    expect(host.querySelector('[data-ocu-compare="diff"]')).toBeNull();
  });

  it('says two documents too far apart are not compared line by line', async () => {
    const { host, compare } = await mount({ 'HSCUSTOM|Demo.Left.cls': lines(600, 'l'), 'HSCUSTOM|Demo.Right.cls': lines(600, 'r') });
    await compare('Demo.Right.cls');
    expect(host.querySelector('[data-ocu-compare="status"]')?.textContent?.trim()).toBe(STRINGS.explorerCompareTooLarge);
    expect(host.querySelector('[data-ocu-compare="diff"]')).toBeNull();
  });

  it("names a refused side with the instance's reason and draws nothing", async () => {
    const { host, compare } = await mount({ 'HSCUSTOM|Demo.Left.cls': ['a'] });
    await compare('Demo.Gone.cls');
    expect(host.querySelector('[data-ocu-compare="refusal"]')?.textContent?.trim()).toBe('Demo.Gone.cls: This namespace holds no document by that name.');
    expect(host.querySelector('[data-ocu-compare="diff"]')).toBeNull();
  });

  it('compares again when either document changes', async () => {
    const { reads, compare, bus, settle: wait } = await mount({ 'HSCUSTOM|Demo.Left.cls': ['a'], 'HSCUSTOM|Demo.Right.cls': ['b'] });
    await compare('Demo.Right.cls');
    expect(reads).toHaveLength(2);
    bus.publish({ kind: 'changed', type: 'class', scope: 'HSCUSTOM', id: 'Demo.Other.cls,Demo.Right.cls', action: 'updated' });
    await wait();
    expect(reads).toHaveLength(4);
    bus.publish({ kind: 'changed', type: 'class', scope: 'USER', id: 'Demo.Right.cls', action: 'updated' });
    await wait();
    expect(reads).toHaveLength(4);
    bus.publish({ kind: 'changed', type: 'class', scope: 'HSCUSTOM', id: 'Demo.Other.cls', action: 'updated' });
    await wait();
    expect(reads).toHaveLength(4);
    bus.publish({ kind: 'changed', type: 'class', scope: 'HSCUSTOM', id: 'Demo.Left.cls', action: 'updated' });
    await wait();
    expect(reads).toHaveLength(6);
  });

  it('re-compares the documents it compared and keeps what the person is typing', async () => {
    const { host, side, reads, compare, bus, settle: wait } = await mount({ 'HSCUSTOM|Demo.Left.cls': ['a'], 'HSCUSTOM|Demo.Right.cls': ['b'] });
    await compare('Demo.Right.cls');
    const name = side('right').querySelector('[data-ocu-compare="name"]') as HTMLInputElement;
    name.value = 'Demo.Typed.cls';
    name.dispatchEvent(new Event('input'));
    await wait();
    bus.publish({ kind: 'changed', type: 'class', scope: 'HSCUSTOM', id: 'Demo.Right.cls', action: 'updated' });
    await wait();
    expect(reads.slice(2)).toEqual([
      'HSCUSTOM /api/ocupilot/screens/explorer.class/read?maxRows=1&name=Demo.Left.cls&form=udl',
      'HSCUSTOM /api/ocupilot/screens/explorer.class/read?maxRows=1&name=Demo.Right.cls&form=udl',
    ]);
    expect((side('right').querySelector('[data-ocu-compare="name"]') as HTMLInputElement).value).toBe('Demo.Typed.cls');
    (host.querySelector('[data-ocu-compare="submit"]') as HTMLButtonElement).click();
    await wait();
    expect(reads.at(-1)).toBe('HSCUSTOM /api/ocupilot/screens/explorer.class/read?maxRows=1&name=Demo.Typed.cls&form=udl');
  });
});

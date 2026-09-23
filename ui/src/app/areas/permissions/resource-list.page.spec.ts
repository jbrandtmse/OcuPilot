import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { RESOURCES_FORM_PATH, ResourceEditor } from './resource-editor.store';
import { ResourceListPage } from './resource-list.page';

/**
 * The Resources list page's route wiring (AC1): the editor opens over the resource the route names,
 * and follows the id when one id route moves to another, which Angular answers by reusing the
 * page. The page's template is emptied, so only its own wiring runs; the router, the editor store
 * and `FormDirty` are real and only the server's answers are stubbed.
 */

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the Resources list page', () => {
  it('AC1: a move from one resource id route to another re-opens the editor over the new resource', async () => {
    const api = {
      requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
        const name = path.startsWith(`${RESOURCES_FORM_PATH}?name=`) ? decodeURIComponent(path.split('name=')[1]!) : '';
        return {
          kind: 'ok',
          status: 200,
          body: { rules: [], letterRules: { letters: 'RWU', prefixes: [] }, resource: { name, Description: `about ${name}`, PublicPermission: '', privileged: false } },
        } as unknown as JsonResult<T>;
      },
    };
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '**', children: [] }]),
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: ChangeBus, useValue: new ChangeBus() },
        { provide: FormDirty, useValue: new FormDirty() },
      ],
    });
    TestBed.overrideComponent(ResourceListPage, { set: { imports: [], template: '' } });
    const router = TestBed.inject(Router);
    const store = TestBed.inject(ResourceEditor);
    await router.navigateByUrl('/permissions/resources/ProbeA');
    const fixture = TestBed.createComponent(ResourceListPage);
    fixture.detectChanges();
    await settle();
    expect(store.editedName()).toBe('ProbeA');

    await router.navigateByUrl('/permissions/resources/ProbeB');
    await settle();
    // Mutation (Rule 19): drop the page's `NavigationEnd` subscription -> the editor stays on ProbeA.
    expect(store.editedName()).toBe('ProbeB');
    expect(store.description()).toBe('about ProbeB');
    fixture.destroy();
  });
});

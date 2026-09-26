import { Injectable, inject } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ResourceEditor } from './resource-editor.store';

/** The descriptor whose command bar this action appears on. */
export const RESOURCE_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.ResourceList';

/** The declared primary action id: the command bar's Create, which opens the resource editor. */
export const CREATE_ACTION = 'create';

/**
 * The handler behind the Resources list's declared Create (AD-5, AD-19).
 *
 * The Resources list is served by the generic `ListPage`, so its action is registered here, once,
 * against the descriptor's class name, and tab-scoped from the application root for the reason
 * `role-actions.ts` gives (DW-246). Unlike the Roles list's, it navigates nowhere: the resource
 * editor is a dialog over the list, so Create opens `ResourceEditor` in create mode and the list's
 * page draws it.
 */
@Injectable({ providedIn: 'root' })
export class ResourceActions {
  private readonly actions = inject(ScreenActions);

  private readonly editor = inject(ResourceEditor);

  constructor() {
    this.actions.register(RESOURCE_LIST_DESCRIPTOR, CREATE_ACTION, () => void this.editor.openCreate());
  }
}

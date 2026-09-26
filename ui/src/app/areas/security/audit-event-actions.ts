import { Injectable, inject } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { AuditEventEditor } from './audit-event-editor.store';

/** The descriptor whose command bar this action appears on. */
export const AUDIT_USER_EVENT_LIST_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.AuditUserEventList';

/** The declared primary action id: the command bar's Create, which opens the editor. */
export const CREATE_ACTION = 'create';

/**
 * The handler behind the User events list's declared Create (AD-5, AD-19): registered once,
 * against the descriptor's class name, from the application root for the reason `role-actions.ts`
 * gives (DW-246). The editor is a dialog over the list, so Create opens `AuditEventEditor` in create
 * mode and the list's page draws it.
 */
@Injectable({ providedIn: 'root' })
export class AuditEventActions {
  private readonly actions = inject(ScreenActions);

  private readonly editor = inject(AuditEventEditor);

  constructor() {
    this.actions.register(AUDIT_USER_EVENT_LIST_DESCRIPTOR, CREATE_ACTION, () => void this.editor.openCreate());
  }
}

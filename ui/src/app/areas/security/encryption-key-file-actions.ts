import { Injectable, Injector, inject } from '@angular/core';
import { Router } from '@angular/router';

import { screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';

/** The descriptor whose command bar Create key file appears on (Story 18.7). */
export const ENCRYPTION_KEY_FILE_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.EncryptionKeyFile';

/** The create form's own route, read from the mirror rather than navigated to by name. */
export const ENCRYPTION_KEY_FILE_FORM_ROUTE = 'security/encryption-key-file/create';

/** The declared primary action id: the command bar's Create key file. */
export const ENCRYPTION_CREATE_ACTION = 'create';

/**
 * The handler behind Encryption key files' declared Create key file (Story 18.7, AD-5, AD-19), on the
 * `license-server-actions.ts` model: registered once against the descriptor's class name and
 * tab-scoped from the application root. It opens the create form, whose route the mirror resolves;
 * the key file page's Add and Remove are the page's own.
 */
@Injectable({ providedIn: 'root' })
export class EncryptionKeyFileActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  constructor() {
    this.actions.register(ENCRYPTION_KEY_FILE_DESCRIPTOR, ENCRYPTION_CREATE_ACTION, () => this.openCreate());
  }

  private openCreate(): void {
    const form = screenForRoute(ENCRYPTION_KEY_FILE_FORM_ROUTE);
    if (form === null || !form.built) return;
    const router = this.injector.get(Router);
    void router.navigateByUrl(withQuery(form.route, router.url));
  }
}

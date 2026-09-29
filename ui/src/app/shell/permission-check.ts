import { Injectable, Injector, inject, signal } from '@angular/core';

import { ApiService, type JsonResult } from '../core/api';
import { formatRequires } from '../core/navigation';
import { type CheckAnswer, type CheckKind, type CheckPermission, checkAnswerOf } from '../core/privileges';
import { STRINGS } from '../core/strings';

/** The route the check reads (AD-20): `GET <path>?kind=&name=&resource=&permission=`. */
export const PERMISSION_CHECK_PATH = '/api/ocupilot/permissions/check';

/** The machine code a privilege denial carries (AD-39). */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The dialog a screen's Check permission has opened: where it renders, and what it is prefilled with. */
export interface PendingCheck {
  /** The descriptor whose `app-screen-action-dialogs` renders the dialog. */
  readonly descriptor: string;
  readonly kind: CheckKind;
  readonly name: string;
}

/**
 * The permission check's state (Story 16.3, FR-74): the dialog one screen has open, and the
 * instance's answer to the last check it sent.
 *
 * **The instance answers; this store asks and keeps the answer.** `check` issues
 * `GET /api/ocupilot/permissions/check` with every value encoded, the same operation the agent's
 * `permissions.privileges.check` answers, and keeps either the answer or the refusal's own reason;
 * the dialog stays open on either. A privilege refusal reads "Requires <pair>" where the envelope
 * names the pair. A check still in flight when the dialog closes, or a later one is sent, is
 * discarded when it lands. Reset at sign-out.
 */
@Injectable({ providedIn: 'root' })
export class PermissionCheck {
  private readonly injector = inject(Injector);

  private readonly pendingValue = signal<PendingCheck | null>(null);

  private readonly answerValue = signal<CheckAnswer | null>(null);

  private readonly errorValue = signal('');

  private readonly busyValue = signal(false);

  private generation = 0;

  /** The open dialog, or `null`. */
  pending(): PendingCheck | null {
    return this.pendingValue();
  }

  /** The last check's answer, or `null`. */
  answer(): CheckAnswer | null {
    return this.answerValue();
  }

  /** The last check's refusal, as the sentence the dialog shows, or `''`. */
  error(): string {
    return this.errorValue();
  }

  busy(): boolean {
    return this.busyValue();
  }

  /** Open the dialog on `descriptor`'s screen, prefilled with `kind` and `name`. */
  open(descriptor: string, kind: CheckKind, name: string): void {
    this.generation += 1;
    this.answerValue.set(null);
    this.errorValue.set('');
    this.busyValue.set(false);
    this.pendingValue.set({ descriptor, kind, name });
  }

  /**
   * Ask the instance whether `name` holds `permission` on `resource`. Sends nothing unless a dialog
   * is open and both the name and the resource hold text.
   */
  async check(kind: CheckKind, name: string, resource: string, permission: CheckPermission): Promise<void> {
    if (this.pendingValue() === null || name.trim() === '' || resource.trim() === '') return;
    this.generation += 1;
    const generation = this.generation;
    this.answerValue.set(null);
    this.errorValue.set('');
    this.busyValue.set(true);
    const query = [
      `kind=${encodeURIComponent(kind)}`,
      `name=${encodeURIComponent(name)}`,
      `resource=${encodeURIComponent(resource)}`,
      `permission=${encodeURIComponent(permission)}`,
    ].join('&');
    const result = await this.injector.get(ApiService).requestJson<unknown>(`${PERMISSION_CHECK_PATH}?${query}`);
    if (generation !== this.generation) return;
    this.busyValue.set(false);
    const answer = result.kind === 'ok' ? checkAnswerOf(result.body) : null;
    if (answer !== null) {
      this.answerValue.set(answer);
      return;
    }
    this.errorValue.set(refusalOf(result));
  }

  /** Close the dialog, dropping its answer and any check still in flight. */
  close(): void {
    this.generation += 1;
    this.pendingValue.set(null);
    this.answerValue.set(null);
    this.errorValue.set('');
    this.busyValue.set(false);
  }

  /** Forget everything, at sign-out. */
  reset(): void {
    this.close();
  }
}

/** The sentence a refused or unreadable answer shows: its pair, its own reason, or "request refused". */
function refusalOf(result: JsonResult<unknown>): string {
  if (result.kind !== 'error') return STRINGS.connectivityRequestRefused;
  const pair = result.detail === null ? undefined : result.detail['failedPair'];
  if (result.code === NO_PRIVILEGE_CODE && typeof pair === 'string' && pair !== '') return formatRequires(STRINGS.privilegeRequiresResource, pair);
  return result.reason !== null && result.reason !== '' ? result.reason : STRINGS.connectivityRequestRefused;
}

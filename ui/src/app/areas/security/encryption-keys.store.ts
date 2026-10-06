import { Injectable } from '@angular/core';

import type { ApiService, JsonResult } from '../../core/api';
import { screenForDescriptor } from '../../core/navigation';
import { screenReadPath } from '../../core/screen-read';
import { STRINGS } from '../../core/strings';

/** Database encryption's descriptor: the instance's active database encryption keys (Story 18.22). */
export const DATABASE_ENCRYPTION = 'OcuPilot.Screen.Descriptor.DatabaseEncryption';

/** Data element encryption's descriptor: the instance's active data-element encryption keys. */
export const DATA_ELEMENT_ENCRYPTION = 'OcuPilot.Screen.Descriptor.DataElementEncryption';

/** The cap each read asks under: the vendor keeps at most 256 data-element keys. */
export const ENCRYPTION_KEYS_MAX_ROWS = 300;

/** Where one screen's read stands. */
export type EncryptionKeysStatus = 'idle' | 'loading' | 'ready' | 'refused';

/** One active key, as the read answers it; no read answers key material. */
export interface ActiveKeyRow {
  readonly Id: string;
  readonly KeyLen: number | string;
  readonly IsDefault: boolean;
}

interface KeysView {
  readonly status: EncryptionKeysStatus;
  readonly rows: readonly ActiveKeyRow[];
  readonly reason: string;
}

const EMPTY_VIEW: KeysView = { status: 'idle', rows: [], reason: '' };

function rowsOf(result: JsonResult<unknown>): readonly unknown[] {
  if (result.kind !== 'ok' || result.body === null || typeof result.body !== 'object') return [];
  const rows = (result.body as Record<string, unknown>)['rows'];
  return Array.isArray(rows) ? rows : [];
}

function keyRow(row: unknown): ActiveKeyRow | null {
  if (row === null || typeof row !== 'object') return null;
  const fields = row as Record<string, unknown>;
  const id = fields['Id'];
  if (typeof id !== 'string' || id === '') return null;
  const length = fields['KeyLen'];
  return { Id: id, KeyLen: typeof length === 'number' || typeof length === 'string' ? length : '', IsDefault: fields['IsDefault'] === true };
}

/**
 * Database encryption's and Data element encryption's store (Story 18.22, AD-19): each screen's active
 * keys, read through its own declared read (AD-5, AD-36), so the screen and its
 * `security.databaseencryption.read` or `security.dataelementencryption.read` tool answer the same rows.
 *
 * **It holds no secret.** The Activate dialog's administrator password is the page's own signal, never
 * this store's (AD-35); what is here is the instance's answer.
 *
 * **A refusal is the instance's own sentence** (AD-39). Only the newest read of a screen settles.
 */
@Injectable({ providedIn: 'root' })
export class EncryptionKeysStore {
  private readonly listeners = new Set<() => void>();

  private readonly views = new Map<string, KeysView>();

  private readonly requests = new Map<string, number>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  status(descriptor: string): EncryptionKeysStatus {
    return this.view(descriptor).status;
  }

  rows(descriptor: string): readonly ActiveKeyRow[] {
    return this.view(descriptor).rows;
  }

  /** A refused read's sentence, or `''`. */
  reason(descriptor: string): string {
    return this.view(descriptor).reason;
  }

  /** Forget every screen's rows: from the sign-out teardown. */
  reset(): void {
    for (const descriptor of this.requests.keys()) this.requests.set(descriptor, (this.requests.get(descriptor) ?? 0) + 1);
    this.views.clear();
    this.notify();
  }

  /** Read `descriptor`'s active keys, as the screen opens and again after a write or a change event (AD-14). */
  async read(api: Pick<ApiService, 'requestJson'>, descriptor: string): Promise<void> {
    const screen = screenForDescriptor(descriptor);
    if (screen === null || screen.read === null) return;
    const request = (this.requests.get(descriptor) ?? 0) + 1;
    this.requests.set(descriptor, request);
    this.views.set(descriptor, { ...this.view(descriptor), status: 'loading', reason: '' });
    this.notify();
    const result = await api.requestJson<unknown>(screenReadPath(screen, ENCRYPTION_KEYS_MAX_ROWS));
    if (request !== this.requests.get(descriptor)) return;
    if (result.kind !== 'ok') {
      // An answer with no sentence, such as a request that never reached the instance, reads "request refused".
      this.views.set(descriptor, { status: 'refused', rows: [], reason: (result.kind === 'error' && result.reason) || STRINGS.connectivityRequestRefused });
      this.notify();
      return;
    }
    const rows = rowsOf(result)
      .map(keyRow)
      .filter((row): row is ActiveKeyRow => row !== null);
    this.views.set(descriptor, { status: 'ready', rows, reason: '' });
    this.notify();
  }

  private view(descriptor: string): KeysView {
    return this.views.get(descriptor) ?? EMPTY_VIEW;
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

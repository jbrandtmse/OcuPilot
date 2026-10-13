import { Injectable, Injector, inject, signal } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { ALLOWED_DIRECTORY_FALLBACK_RULE, selfProtectionReason } from '../../core/self-protection';
import { STRINGS } from '../../core/strings';
import { rowFor } from '../../core/table-model';
import { ALLOWED_DIRECTORIES_PATH, ALLOWED_DIRECTORY_LIST, ScreenActionHandler } from '../../shell/screen-action-handler';

/** The Allowed directories screen's three actions, as its descriptor declares them. */
export type AllowedDirectoryAction = 'add' | 'change' | 'remove';

/** Every action the screen carries, in the order its surfaces draw them. */
export const ALLOWED_DIRECTORY_ACTIONS: readonly AllowedDirectoryAction[] = ['add', 'change', 'remove'];

/** The dialog an action has opened, and what it needs to word itself. */
export interface PendingAllowedDirectory {
  readonly action: AllowedDirectoryAction;
  /** The selected row's directory for a change or a remove, `''` for an add. */
  readonly directory: string;
  /** Add only: whether the list is unrestricted, so that the add restricts it. */
  readonly unrestricted: boolean;
}

/** What `GET /allowed-directories` answers (Story 18.46): the write's governance verdict. */
interface Verdict {
  readonly enabled?: boolean;
  readonly reason?: string;
}

/**
 * The Allowed directories screen's Add, Change and Remove (Story 18.46, AD-19, AD-21, AD-53): the instance's verdict on the
 * write's governance key, the dialog an action has opened, and the sends.
 *
 * **The instance decides; this service keeps its answer.** `load` clears the verdict, asks `GET /allowed-directories`, and
 * keeps the sentence of a disabled key or of a refused read as the reason every action is drawn off with -- the server's
 * own words (AD-39) -- closing any dialog that stands. An action drawn off runs nothing (`ScreenActions.run`). The verdict
 * is read when the screen is entered and after each of its writes, and the route asks the key again at every write, so a
 * key disabled since the read refuses the write on the list's banner. Only the newest `load` settles.
 *
 * **One dialog at a time, never over another's.** `open('add')` notes whether the list reads unrestricted, which words its
 * consequence, and words it as restricting until the list has answered; `open('change')` and `open('remove')` take the
 * list store's selection, and a row the fallback rule refuses puts its sentence on the store's refusal, as
 * `ScreenActionHandler.startFor` does. `confirm` closes the dialog, sends
 * through `ScreenActionHandler.sendFor` -- whose answer becomes the one change event that re-reads the list (AD-14) -- and
 * then reads the verdict again.
 */
@Injectable({ providedIn: 'root' })
export class AllowedDirectoryActions {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  private readonly stores = inject(ScreenStores);

  private readonly handler = inject(ScreenActionHandler);

  private readonly reasonValue = signal('');

  private readonly waiting = signal<PendingAllowedDirectory | null>(null);

  private asked = 0;

  /** Why every action is drawn off now -- the key's sentence or a refused read's -- or `''` while they can be taken. */
  reason(): string {
    return this.reasonValue();
  }

  /** The dialog an action has opened, or `null`. */
  pending(): PendingAllowedDirectory | null {
    return this.waiting();
  }

  /**
   * Clear the verdict, read it, and tell the surfaces. A disabled key reads as the sentence the instance wrote, or the
   * published one for `ALLOWLIST.OFF` where the answer carried none; a refused read reads as its envelope's `reason`; a
   * read that did not answer leaves the actions drawn on, because the route refuses what the instance refuses. A verdict
   * that holds the actions off closes a dialog opened while it was being read, so that dialog sends nothing.
   */
  async load(): Promise<void> {
    const ask = (this.asked += 1);
    this.reasonValue.set('');
    this.actions.changed();
    const result = await this.injector.get(ApiService).requestJson<Verdict>(ALLOWED_DIRECTORIES_PATH);
    if (ask !== this.asked) return;
    const reason = reasonOf(result);
    this.reasonValue.set(reason);
    if (reason !== '') this.waiting.set(null);
    this.actions.changed();
  }

  /**
   * Open the dialog for `action`. Nothing opens while another dialog stands, a change or a remove has no selected row, or
   * the fallback rule refuses the selected row -- whose sentence goes to the list's banner.
   */
  open(action: AllowedDirectoryAction): void {
    if (this.waiting() !== null || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === ALLOWED_DIRECTORY_LIST);
    if (screen === undefined) return;
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    if (action === 'add') {
      this.waiting.set({ action, directory: '', unrestricted: store.lastUpdate() === null || store.data().some((row) => isFallback(row)) });
      return;
    }
    const directory = store.selection()[0] ?? '';
    if (directory === '') return;
    const refusal = selfProtectionReason(ALLOWED_DIRECTORY_FALLBACK_RULE, directory, '', rowFor(store.data(), screen, directory));
    if (refusal !== '') {
      store.setRefusal(refusal);
      return;
    }
    this.waiting.set({ action, directory, unrestricted: false });
  }

  /**
   * The dialog was confirmed with `value`: the directory an add names, or the new directory a change names (a remove carries
   * none). The dialog closes first; the write goes through the shell's one send, and the verdict is read again after it.
   */
  async confirm(value = ''): Promise<void> {
    const pending = this.waiting();
    this.waiting.set(null);
    if (pending === null) return;
    if (pending.action !== 'remove' && value === '') return;
    if (pending.action === 'add') {
      await this.handler.sendFor(ALLOWED_DIRECTORY_LIST, 'add', value);
    } else if (pending.action === 'change') {
      await this.handler.sendFor(ALLOWED_DIRECTORY_LIST, 'change', pending.directory, { NewDirectory: value });
    } else {
      await this.handler.sendFor(ALLOWED_DIRECTORY_LIST, 'remove', pending.directory);
    }
    await this.load();
  }

  /** Escape, Cancel or the scrim: nothing was sent. */
  cancel(): void {
    this.waiting.set(null);
  }
}

/** Whether `row` is the allow-list's unrestricted fallback row, by the same predicate the fallback rule explains. */
function isFallback(row: unknown): boolean {
  if (row === null || typeof row !== 'object') return false;
  const fields = row as Readonly<Record<string, unknown>>;
  const directory = fields['Directory'];
  return typeof directory === 'string' && directory !== '' && selfProtectionReason(ALLOWED_DIRECTORY_FALLBACK_RULE, directory, '', fields) !== '';
}

/** The sentence a verdict reads as, or `''` while the key is enabled or the read gave no answer. A disabled key without one is `ALLOWLIST.OFF`'s published sentence. */
function reasonOf(result: JsonResult<Verdict>): string {
  if (result.kind === 'ok') {
    if (result.body?.enabled !== false) return '';
    const reason = result.body.reason;
    return typeof reason === 'string' && reason !== '' ? reason : STRINGS.allowListRefusalOff;
  }
  return result.kind === 'error' ? (result.reason ?? '') : '';
}

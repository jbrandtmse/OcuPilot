import { Injectable, Injector, inject, signal } from '@angular/core';

import { ApiService } from '../core/api';
import { ChangeBus, type ChangeAction } from '../core/change-bus';
import { ScreenActions, actionLabel } from '../core/screen-actions';
import { SCREEN_READ_PATH_PREFIX } from '../core/screen-read';
import { ScreenStores } from '../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../core/screens.generated';
import { selfProtectionReason } from '../core/self-protection';
import { STRINGS } from '../core/strings';

/** The absolute path a screen's own row action is issued under (AD-20, AD-53). */
export const SCREEN_ACTION_PATH_SUFFIX = '/action';

/**
 * The descriptors whose declared row actions this handler carries out.
 *
 * **A roster rather than "every write-capable screen"**, because two screens register their own:
 * the Definitions list (`areas/agent/definition-actions.ts`) writes OcuPilot's own state through
 * its own routes, and the Switches screen's `create`/`delete` add and remove a per-user hold.
 * Neither is an instance write and neither goes through `POST /screens/:screen/action`, so
 * registering generically for them would replace a handler that does something else. It grows one
 * entry per story, beside the consequence copy below: the Web applications list (Story 7.1), and
 * the OAuth 2.0 screen's Client configurations and Server client descriptions tabs (Story 7.3),
 * whose detail pages render the same `ListPage`.
 */
export const SCREEN_ACTION_DESCRIPTORS: readonly string[] = [
  'OcuPilot.Screen.Descriptor.WebAppList',
  'OcuPilot.Screen.Descriptor.OAuthClientTab',
  'OcuPilot.Screen.Descriptor.OAuthServerClientTab',
];

/**
 * The row actions this handler confirms with the typed-name dialog before it sends anything.
 *
 * **It decides which dialog a person sees, never what may happen.** Whether a write is refused is
 * the instance's (AD-10); whether a card draws the destructive treatment is the tool's own
 * `DESTRUCTIVE` declaration. This is EXPERIENCE.md's `confirm-dialog` rule -- a delete carries the
 * typed-name field and a `button-destructive` -- applied to the verb that deletes.
 */
const DESTRUCTIVE_ACTIONS: readonly string[] = ['delete'];

/**
 * The consequence sentence a destructive action states above its typed-name field, keyed by
 * descriptor and then by action id -- the shape `DESCRIPTOR_ACTION_LABELS` already uses, and for
 * the same reason: one verb means a different consequence on each screen, and the sentence is
 * published per screen in EXPERIENCE.md's Fixed strings table.
 *
 * **A destructive action whose screen publishes no consequence is not registered at all**, so no
 * surface draws it (DW-389) and nothing here invents copy.
 */
const DESTRUCTIVE_CONSEQUENCES: Readonly<Record<string, Readonly<Record<string, string>>>> = {
  'OcuPilot.Screen.Descriptor.WebAppList': { delete: STRINGS.webAppDeleteConsequence },
  'OcuPilot.Screen.Descriptor.OAuthClientTab': { delete: STRINGS.oauthClientDeleteConsequence },
  'OcuPilot.Screen.Descriptor.OAuthServerClientTab': { delete: STRINGS.oauthServerClientDeleteConsequence },
};

/** What the screen-action route answers (AD-14): the verb, and the triple the write was made against. */
interface ScreenActionAnswer {
  readonly action?: string;
  readonly target?: { readonly type?: string; readonly scope?: string; readonly id?: string };
}

/** The dialog a destructive row action is waiting on, or `null`. */
export interface PendingConfirm {
  readonly descriptor: string;
  readonly actionId: string;
  readonly verb: string;
  readonly target: string;
  readonly consequence: string;
}

/**
 * The handler behind every declared row action this client runs through
 * `POST /api/ocupilot/screens/:screen/action` (AD-5, AD-53).
 *
 * **It is generic and it lives in the shell, not in an area.** A list archetype is served entirely
 * by `ListPage` over its descriptor, so a row action has no area page to be registered from; and
 * AD-5 makes a row action a declaration, so the thing that runs it is declaration-driven too. One
 * registration loop serves every screen on the roster above, and every later story in this epic
 * adds a descriptor rather than a service.
 *
 * **The target is the selected row's key**, which is what the row menu selects on open and what
 * the command bar acts on. A run with no selection does nothing: both surfaces already draw the
 * action `aria-disabled` with "Select a row first" in that state.
 *
 * **A destructive action opens the typed-name dialog first** and sends nothing until it is
 * confirmed. `ListPage` renders the dialog from `pending()`, because the list is the surface the
 * action belongs to and the shell has one modal surface (`dialog.ts`).
 *
 * **Nothing is patched from the write's own answer** (AD-14). A confirmed write publishes the
 * triple and verb the instance answered on the change bus; the refresh framework re-fetches the
 * screen in place and marks the row. A refusal publishes nothing and puts the envelope's own
 * sentence on the screen's store, which `ListPage` renders (AD-39).
 */
@Injectable({ providedIn: 'root' })
export class ScreenActionHandler {
  private readonly injector = inject(Injector);

  private readonly actions = inject(ScreenActions);

  private readonly stores = inject(ScreenStores);

  private readonly waiting = signal<PendingConfirm | null>(null);

  constructor() {
    for (const screen of SCREENS) {
      if (!SCREEN_ACTION_DESCRIPTORS.includes(screen.descriptor)) continue;
      for (const action of screen.rowActions) {
        if (action.id === '') continue;
        // No inert control: a destructive action with no published consequence has no dialog to
        // open, so it registers no handler and no surface draws it (DW-389).
        if (this.isDestructive(action.id) && this.consequence(screen.descriptor, action.id) === '') {
          continue;
        }
        this.actions.register(screen.descriptor, action.id, () => this.start(screen, action.id));
      }
    }
  }

  /** The dialog waiting on a typed name, or `null`. `ListPage` renders it. */
  pending(): PendingConfirm | null {
    return this.waiting();
  }

  /** The typed name matched: send the write the dialog was standing in front of. */
  confirmPending(): void {
    const pending = this.waiting();
    this.waiting.set(null);
    if (pending === null) return;
    void this.send(pending.descriptor, pending.actionId, pending.target);
  }

  /** Escape, Cancel or the scrim: nothing was sent and nothing is. */
  cancelPending(): void {
    this.waiting.set(null);
  }

  /** Open the dialog, or send at once where the action is not destructive. */
  private start(screen: ScreenDeclaration, actionId: string): void {
    const target = this.selected(screen);
    if (target === '') return;
    // The surfaces already list a self-protected action as refused rather than selectable, so this
    // is the second half of the same explanation and not a second predicate: the instance refuses
    // it either way, with this same sentence (AD-10, AD-53).
    const rule = screen.rowActions.find((action) => action.id === actionId)?.selfProtection ?? '';
    const refusal = selfProtectionReason(rule, target);
    if (refusal !== '') {
      this.store(screen.descriptor, screen.refreshRates).setRefusal(refusal);
      return;
    }
    if (!this.isDestructive(actionId)) {
      void this.send(screen.descriptor, actionId, target);
      return;
    }
    this.waiting.set({
      descriptor: screen.descriptor,
      actionId,
      verb: actionLabel(screen.descriptor, actionId),
      target,
      consequence: this.consequence(screen.descriptor, actionId),
    });
  }

  /** The one request, and what its answer publishes. */
  private async send(descriptor: string, actionId: string, target: string): Promise<void> {
    const screen = SCREENS.find((entry) => entry.descriptor === descriptor);
    if (screen === undefined) return;
    const store = this.store(descriptor, screen.refreshRates);
    store.setRefusal('');
    const result = await this.injector.get(ApiService).requestJson<ScreenActionAnswer>(
      `${SCREEN_READ_PATH_PREFIX}${encodeURIComponent(screen.toolIdentifier)}${SCREEN_ACTION_PATH_SUFFIX}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: actionId, id: target }),
      }
    );
    if (result.kind !== 'ok') {
      // The envelope's own sentence (AD-39). A refused write changed nothing, so nothing is
      // published and no row is marked.
      store.setRefusal(result.kind === 'error' ? (result.reason ?? '') : '');
      return;
    }
    const answer = result.body;
    const targetRef = answer?.target;
    if (targetRef === undefined) return;
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: targetRef.type ?? '',
      scope: targetRef.scope ?? '',
      id: targetRef.id ?? '',
      // The verb is the instance's, never inferred here: the vocabulary is the kernel's closed set
      // and a screen routes on it (AD-14).
      action: (answer?.action ?? '') as ChangeAction,
    });
  }

  /** The key of the row the screen has selected, or `''`. */
  private selected(screen: ScreenDeclaration): string {
    return this.store(screen.descriptor, screen.refreshRates).selection()[0] ?? '';
  }

  /**
   * The screen's own store. The rates are the declaration's, always: `ScreenStores.for` takes them
   * on the call that first creates the store, so a caller passing an empty list could be the one
   * that decides a refreshing screen has no rates.
   */
  private store(descriptor: string, rates: readonly number[]): ReturnType<ScreenStores['for']> {
    return this.stores.for(descriptor, rates);
  }

  private isDestructive(actionId: string): boolean {
    return DESTRUCTIVE_ACTIONS.includes(actionId);
  }

  private consequence(descriptor: string, actionId: string): string {
    const own = DESTRUCTIVE_CONSEQUENCES[descriptor];
    if (own === undefined) return '';
    return Object.hasOwn(own, actionId) ? own[actionId] : '';
  }
}

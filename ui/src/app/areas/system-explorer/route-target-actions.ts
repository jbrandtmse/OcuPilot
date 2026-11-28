import { DestroyRef, inject } from '@angular/core';
import { Router } from '@angular/router';

import { parentCriteria } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { ScreenActionHandler } from '../../shell/screen-action-handler';

/**
 * Register the page actions `actionIds` of the tab `descriptor`, none of which names a row (AD-5), for the page whose constructor calls this. It
 * injects the shell's handler before it registers anything, so the row actions the handler registers come first. Each action starts the handler's
 * own flow on the target the route's `criterion` names, reporting to the tab's store, and never while another of the handler's dialogs is open; the
 * handler warns first, sends it, and publishes the change event the tab re-reads on (AD-14). The registrations end with the page.
 */
export function registerRouteTargetActions(descriptor: string, criterion: string, actionIds: readonly string[]): void {
  const stores = inject(ScreenStores);
  const router = inject(Router);
  const handler = inject(ScreenActionHandler);
  const actions = inject(ScreenActions);
  const screen = SCREENS.find((entry) => entry.descriptor === descriptor) ?? null;
  const store = screen === null ? null : stores.for(screen.descriptor, screen.refreshRates);
  const start = (actionId: string): void => {
    const target = screen === null ? '' : (parentCriteria(screen, router.url)[criterion] ?? '');
    if (store === null || target === '' || handler.pending() !== null) return;
    handler.startFor(descriptor, actionId, target, {}, store);
  };
  const stops = actionIds.map((actionId) => actions.register(descriptor, actionId, () => start(actionId)));
  inject(DestroyRef).onDestroy(() => {
    for (const stop of stops) stop();
  });
}

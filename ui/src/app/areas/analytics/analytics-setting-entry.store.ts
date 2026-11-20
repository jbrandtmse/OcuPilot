import { Injectable } from '@angular/core';

import { ListingGroupStore, type ListingGroupOutcome } from './listing-group.store';

/** The routes the Add run-time variable and Add icon dialogs post to (AD-55): the same tools the agent's adds resolve. */
export const RUNTIME_VARIABLE_PATH = '/api/ocupilot/analytics/runtime-variables';

export const USER_ICON_PATH = '/api/ocupilot/analytics/user-icons';

/** The entity types and the tools a create's change event names (AD-13, AD-14). */
export const RUNTIME_VARIABLE_ENTITY = 'analytics-runtime-variable';

export const USER_ICON_ENTITY = 'analytics-user-icon';

export const RUNTIME_VARIABLE_ADD_TOOL = 'analytics.runtimevariables.add';

export const USER_ICON_ADD_TOOL = 'analytics.usericons.add';

/**
 * The run-time variable and user-defined icon creates (Story 24.13, Batch 3, AD-19, AD-55): the listing group store with the two create routes. It composes no rule of its own; every sentence a dialog
 * shows is the server's (AD-39).
 */
@Injectable({ providedIn: 'root' })
export class AnalyticsSettingEntryStore extends ListingGroupStore {
  /** Post a new run-time variable, as typed, to `namespace`. */
  createVariable(namespace: string, body: Readonly<Record<string, unknown>>): Promise<ListingGroupOutcome> {
    return this.post(RUNTIME_VARIABLE_PATH, namespace, body, RUNTIME_VARIABLE_ENTITY, RUNTIME_VARIABLE_ADD_TOOL);
  }

  /** Post a new user-defined icon, as typed, to `namespace`. */
  createIcon(namespace: string, body: Readonly<Record<string, unknown>>): Promise<ListingGroupOutcome> {
    return this.post(USER_ICON_PATH, namespace, body, USER_ICON_ENTITY, USER_ICON_ADD_TOOL);
  }
}

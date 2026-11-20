import { Injectable } from '@angular/core';

import { ListingGroupStore, type ListingGroupOutcome } from './listing-group.store';

/** The route the New PMML definition dialog posts to (AD-55): the same tool the agent's add resolves. */
export const PMML_DEFINITION_PATH = '/api/ocupilot/analytics/pmml-models';

/** The entity type and the tool a create's change event names (AD-13, AD-14). */
export const PMML_DEFINITION_ENTITY = 'pmml-definition';

export const PMML_DEFINITION_ADD_TOOL = 'analytics.pmmlmodels.add';

/**
 * The PMML definition create's own request (Story 24.14 Batch 3, AD-19, AD-55): the listing group store's post with the definition's route. It composes no rule of its
 * own; every sentence a dialog shows is the server's (AD-39).
 */
@Injectable({ providedIn: 'root' })
export class PmmlModelStore extends ListingGroupStore {
  /** Post a new definition, as typed, to `namespace`: the body holds `Class` and `PMML`. */
  createDefinition(namespace: string, body: Readonly<Record<string, unknown>>): Promise<ListingGroupOutcome> {
    return this.post(PMML_DEFINITION_PATH, namespace, body, PMML_DEFINITION_ENTITY, PMML_DEFINITION_ADD_TOOL);
  }
}

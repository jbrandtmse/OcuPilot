import { Injectable } from '@angular/core';

import { ListingGroupStore, type ListingGroupForm, type ListingGroupOutcome } from './listing-group.store';

/** The route the New quality measure dialog posts to (AD-55): the same tool the agent's add resolves. */
export const QUALITY_MEASURE_PATH = '/api/ocupilot/analytics/quality-measures';

/** The route that answers one quality measure, for the Edit and Copy dialogs. */
export const QUALITY_MEASURE_FORM_PATH = '/api/ocupilot/analytics/quality-measures/form';

/** The entity type and the tool a create's change event names (AD-13, AD-14). */
export const QUALITY_MEASURE_ENTITY = 'quality-measure';

export const QUALITY_MEASURE_ADD_TOOL = 'analytics.qualitymeasures.add';

/**
 * The quality measure editor's own requests (Story 24.12, AD-19, AD-55): the listing group store with the measure's form route and create route.
 * It composes no rule of its own; every sentence a dialog shows is the server's (AD-39).
 */
@Injectable({ providedIn: 'root' })
export class QualityMeasureStore extends ListingGroupStore {
  /** The measure named `name` in `namespace` as the form route answers it, or `null` when the instance does not answer one. */
  measureForm(namespace: string, name: string): Promise<ListingGroupForm | null> {
    return this.form(namespace, name, QUALITY_MEASURE_FORM_PATH);
  }

  /** Post a new quality measure, as typed, to `namespace`. */
  createMeasure(namespace: string, body: Readonly<Record<string, unknown>>): Promise<ListingGroupOutcome> {
    return this.post(QUALITY_MEASURE_PATH, namespace, body, QUALITY_MEASURE_ENTITY, QUALITY_MEASURE_ADD_TOOL);
  }
}

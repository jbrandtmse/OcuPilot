/**
 * System Explorer's Code metrics and Document hashes state (AD-19, Story 24.1): what the form holds,
 * over the search last sent and the one `RefreshRead` the page binds, which `SentSearchState` holds.
 *
 * **Framework-free.** It imports nothing from Angular; `dev-tool.page.ts` holds one per screen store,
 * so a return to the screen finds the last search.
 *
 * **No read until there is a search.** The bound read answers no rows, and sends nothing, until Search
 * has been pressed with a pattern or an agent's arrival has named one; from then on every read -- the
 * framework's re-read on a change to a class or routine, a namespace switch, Refresh -- runs that same
 * search again (AD-14).
 */

import type { ScreenArrival } from '../../core/screen-arrival';
import { SentSearchState } from './code-search.store';

/** The two criteria both screens declare. */
export const SPEC_PARAM = 'spec';
export const GENERATED_PARAM = 'generated';

/** The generated choice's two values. */
export const GENERATED_NO = 'no';
export const GENERATED_YES = 'yes';

/** The form's pattern and generated choice, over Search's sent search, refusal and read (`code-search.store.ts`). */
export class DevToolState extends SentSearchState {
  private specValue = '';

  private generatedValue = GENERATED_NO;

  spec(): string {
    return this.specValue;
  }

  includeGenerated(): boolean {
    return this.generatedValue === GENERATED_YES;
  }

  setSpec(value: string): void {
    this.specValue = value;
    this.notify();
  }

  setIncludeGenerated(on: boolean): void {
    this.generatedValue = on ? GENERATED_YES : GENERATED_NO;
    this.notify();
  }

  /** Send the form as shown from the next read on: answers false, sending nothing, with no pattern. */
  search(): boolean {
    if (this.specValue.trim() === '') return false;
    this.send({ [SPEC_PARAM]: this.specValue, [GENERATED_PARAM]: this.generatedValue });
    return true;
  }

  /**
   * Run an agent arrival's search: the declared criteria it carries, shown in the form. An arrival with no
   * pattern sends nothing and drops the search it replaces.
   */
  useArrival(arrival: ScreenArrival): boolean {
    const criteria = arrival.criteria;
    this.specValue = typeof criteria[SPEC_PARAM] === 'string' ? criteria[SPEC_PARAM] : '';
    this.generatedValue = criteria[GENERATED_PARAM] === GENERATED_YES ? GENERATED_YES : GENERATED_NO;
    if (this.search()) return true;
    this.send(null);
    return false;
  }
}

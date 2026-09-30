import type { ActionProgress } from '../../shell/screen-action-handler';
import { STRINGS } from '../../core/strings';

/** The time a running line names: the local clock time the request was sent, as `HH:MM:SS`. */
export function clockTime(date: Date): string {
  return date.toTimeString().slice(0, 8);
}

/**
 * A disk operation's status line (Story 18.4): "<operation> running on the instance since <time>"
 * while its request is in flight, "<operation> finished." once the instance answered it done, and the
 * still-running sentence where it answered that the operation continues past the port's wait
 * (AD-26). `''` for a refusal, which is the page's own banner, and before anything is sent.
 * `operation` is the operation's published label; each value is inserted through a replacer, so a
 * label holding a placeholder is shown as written.
 */
export function operationLine(operation: string, state: ActionProgress['state'] | 'none', since: Date | null): string {
  if (state === 'running') {
    return STRINGS.databaseOperationRunning
      .replace('<operation>', () => operation)
      .replace('<time>', () => (since === null ? '' : clockTime(since)));
  }
  if (state === 'finished') return STRINGS.databaseOperationFinished.replace('<operation>', () => operation);
  if (state === 'continues') return STRINGS.auditDatabaseStillRunning;
  return '';
}

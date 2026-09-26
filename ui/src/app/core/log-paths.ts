/**
 * The application error log's read paths, declared once (DW-1149).
 *
 * `ERROR_LOG_DATES_PATH` is one level under `ERROR_LOG_PATH_PREFIX`, and Home's suggested view
 * reached it through its own copy of the whole path while the error-log screen built every level
 * from the prefix. Both now derive from the one prefix here, so the relationship is a fact about
 * the module rather than something a test has to assert.
 *
 * Absolute from the origin root (AD-20). Framework-free, so `node --test` can import it.
 */

/** The absolute prefix every level of the error-log read is issued under. */
export const ERROR_LOG_PATH_PREFIX = '/api/ocupilot/logs/errors/';

/** The application-errors line's own read: the dates level of the prefix above. */
export const ERROR_LOG_DATES_PATH = ERROR_LOG_PATH_PREFIX + 'dates';

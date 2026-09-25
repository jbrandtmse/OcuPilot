import type { Type } from '@angular/core';
import { describe, expect, it } from 'vitest';

import { SCREENS } from '../../core/screens.generated';
import { ARCHETYPE_PAGES, DESCRIPTOR_PAGES } from '../../shell/screen-outlet';
import { AuditPage } from './audit.page';
import { ErrorLogPage } from './error-log.page';
import { LogViewerPage } from './log-viewer.page';

/**
 * "Every log viewer and the audit database viewer" (Story 11.2, FR-70), read from the registry
 * rather than sampled: every built logs-area screen resolves, the way the outlet resolves it, to
 * one of the three pages that carry "Explain this entry". A logs screen added with a page of its
 * own fails here until that page carries the control and joins this list.
 *
 * Mutation (Rule 19): resolve one logs screen to `ListPage` -> this goes red naming it.
 */
const EXPLAINING_PAGES: readonly Type<unknown>[] = [LogViewerPage, ErrorLogPage, AuditPage];

describe('Story 11.2: the explain-entry roster', () => {
  it('every built logs-area screen resolves to a page that carries "Explain this entry"', () => {
    const logs = SCREENS.filter((screen) => screen.area === 'logs' && screen.built);
    expect(logs.length).toBeGreaterThanOrEqual(4);
    for (const screen of logs) {
      const page =
        DESCRIPTOR_PAGES[screen.descriptor] ?? (ARCHETYPE_PAGES as Readonly<Record<string, Type<unknown>>>)[screen.archetype];
      expect(EXPLAINING_PAGES.includes(page), `${screen.descriptor} (${screen.route})`).toBe(true);
    }
  });
});

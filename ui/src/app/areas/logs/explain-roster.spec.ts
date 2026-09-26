import type { Type } from '@angular/core';
import { describe, expect, it } from 'vitest';

import { SCREENS } from '../../core/screens.generated';
import {
  ARCHETYPE_PAGES,
  DESCRIPTOR_EDIT_PAGES,
  DESCRIPTOR_PAGES,
  resolveArchetypePage,
  resolveScreenPage,
} from '../../shell/screen-outlet';
import { AuditPage } from './audit.page';
import { ErrorLogPage } from './error-log.page';
import { LogViewerPage } from './log-viewer.page';

/**
 * "Every log viewer and the audit database viewer" (Story 11.2, FR-70), read from the registry
 * rather than sampled: every built logs-area screen resolves, through the outlet's own resolver, to
 * one of the three pages that carry "Explain this entry", on its bare route and on its id route
 * (where the audit record's dialog lives), since no id-route editor takes it over. A logs screen
 * added with a page of its own fails here until that page carries the control and joins this list.
 *
 * Mutation (Rule 19): resolve one logs screen to `ListPage` -> this goes red naming it.
 */
const EXPLAINING_PAGES: readonly (Type<unknown> | null)[] = [LogViewerPage, ErrorLogPage, AuditPage];

describe('Story 11.2: the explain-entry roster', () => {
  it('every built logs-area screen resolves to a page that carries "Explain this entry"', () => {
    const logs = SCREENS.filter((screen) => screen.area === 'logs' && screen.built);
    expect(logs.length).toBeGreaterThanOrEqual(4);
    for (const screen of logs) {
      const label = `${screen.descriptor} (${screen.route})`;
      const page = resolveScreenPage(
        DESCRIPTOR_PAGES,
        ARCHETYPE_PAGES as Readonly<Record<string, Type<unknown>>>,
        screen.descriptor,
        screen.archetype
      );
      expect(EXPLAINING_PAGES.includes(page), label).toBe(true);
      expect(resolveArchetypePage(DESCRIPTOR_EDIT_PAGES, screen.descriptor), `${label}: its id route`).toBeNull();
    }
  });
});

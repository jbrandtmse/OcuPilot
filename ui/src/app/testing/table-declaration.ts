import type { ScreenDeclaration } from '../core/screens.generated';
import { DETAIL_DIALOG_LISTS } from '../core/navigation';
import { screenDeclaration } from './screen-declaration';

/** The fixture's own descriptor, which sits in no dialog set: its name cell is text. */
export const TABLE_PROBE_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.TableProbe';

/**
 * A list declaration that declares a read and a table, for the data table's specs and its browser
 * harness: five fields -- a name, an identifier, a number, a status and free text -- filtered on the
 * name and sorted by it, a `namespace` scope and a single id. `overrides` apply over it.
 *
 * Its default descriptor is a member of `DETAIL_DIALOG_LISTS`, so its name cell links to its own id
 * route; `TABLE_PROBE_DESCRIPTOR` is the descriptor under which the name is text.
 *
 * Its string keys are existing keys chosen for their shape, not their words; no production
 * descriptor declares a table before Story 2.5.
 */
export function tableDeclaration(overrides: Partial<ScreenDeclaration> = {}): ScreenDeclaration {
  return screenDeclaration({
    descriptor: [...DETAIL_DIALOG_LISTS][0],
    route: 'web-applications/probe',
    area: 'web-applications',
    labelKey: 'navAreaWebApplications',
    archetype: 'list',
    entityType: 'web-application',
    scope: 'namespace',
    id: { kind: 'single', parts: [] },
    emptyStateKey: 'commandBoxNoMatch',
    read: {
      source: { port: 'admin', endpoint: 'WebApp.App', type: 'LIST' },
      fields: ['Name', 'NameSpace', 'Count', 'Enabled', 'Note'],
      filter: ['Name'],
      sort: { fields: ['Name', 'Count'], default: 'Name', direction: 'asc' },
      paging: 'cap',
    },
    table: {
      columns: [
        { field: 'Name', labelKey: 'fieldUserName', kind: 'name' },
        { field: 'NameSpace', labelKey: 'headerNamespaceLabel', kind: 'identifier' },
        { field: 'Count', labelKey: 'statusSegmentInstance', kind: 'number' },
        { field: 'Enabled', labelKey: 'serverFlagLive', kind: 'status' },
        { field: 'Note', labelKey: 'statusSegmentServer', kind: 'text' },
      ],
      emptyNextKey: 'classicLinkCardCaption',
      emptyAgentKey: '',
    },
    ...overrides,
  });
}

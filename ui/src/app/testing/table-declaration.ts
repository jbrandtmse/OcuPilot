import type { ScreenDeclaration } from '../core/screens.generated';
import { screenDeclaration } from './screen-declaration';

/**
 * A list declaration that declares a read and a table, for the data table's specs and its browser
 * harness: five fields -- a name, an identifier, a number, a status and free text -- filtered on the
 * name and sorted by it, a `namespace` scope and a single id. `overrides` apply over it.
 *
 * Its string keys are existing keys chosen for their shape, not their words; no production
 * descriptor declares a table before Story 2.5.
 */
export function tableDeclaration(overrides: Partial<ScreenDeclaration> = {}): ScreenDeclaration {
  return screenDeclaration({
    descriptor: 'OcuPilot.Screen.Descriptor.TableProbe',
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

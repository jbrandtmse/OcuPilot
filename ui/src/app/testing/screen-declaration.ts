import type { ScreenDeclaration } from '../core/screens.generated';

/**
 * A complete `ScreenDeclaration` for a test: neutral defaults for every field the generated
 * mirror declares, with `overrides` applied over them.
 *
 * This is the one place a test spells out the whole declaration, so a field added to
 * `ScreenDeclaration` is added here and nowhere else. `ui/tools/screen-fixture.test.mjs` fails
 * when this field list and the mirror's differ, and when a spec or tool test builds a
 * declaration by hand. It imports types only, so both the component runner and `node --test`
 * load it.
 */
export function screenDeclaration(overrides: Partial<ScreenDeclaration> = {}): ScreenDeclaration {
  return {
    descriptor: 'OcuPilot.Screen.Descriptor.Stub',
    route: 'permissions/users',
    area: 'permissions',
    labelKey: 'navAreaPermissions',
    sideBarPosition: 1,
    archetype: 'list',
    built: true,
    refreshes: false,
    refreshRates: [],
    privileges: [],
    entityType: 'user',
    entityLabelKey: '',
    secondaryEntityTypes: [],
    scope: 'instance',
    parentScope: '',
    id: { kind: 'single', parts: [] },
    context: { fields: [], secretFields: [] },
    secretArguments: [],
    fingerprintExcludes: [],
    primaryAction: { id: '', selfProtection: '' },
    rowActions: [],
    emptyStateKey: '',
    commandAliases: [],
    classicPage: '',
    classicLinkExemption: { exempt: false, reason: '', label: '', href: '' },
    read: null,
    table: null,
    banner: null,
    tab: null,
    toolIdentifier: 'stub',
    rowTarget: null,
    ...overrides,
  };
}

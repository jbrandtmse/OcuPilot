import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins what a built list's name cell opens, through `nameLinkTarget`, the one chain the shared table
// draws its link from (AD-5): a built list never links a name back to its own list, except where a
// reason is declared here. A name cell that links to its own list changes the address and the
// breadcrumb and opens no screen, which is how the SQL schemas list shipped.
//
// `NON_DEFECTS` holds every list that links to itself, each with its reason: the five lists whose page
// opens a dialog at their own id route. A new self-link, or a set member with no reason here, turns
// this red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { DETAIL_DIALOG_LISTS, DIALOG_EDITORS, hasIdRoute, nameLinkTarget, screenForRoute } = await import(corePath('navigation.ts'));
const { SCREENS } = await import(corePath('screens.generated.ts'));

const PACKAGE = 'OcuPilot.Screen.Descriptor.';

/**
 * The lists whose own id route is the right target for their name cell, each with the reason: the
 * page opens the row's dialog there. They are the members of `DIALOG_EDITORS` and
 * `DETAIL_DIALOG_LISTS`, declared here by hand so that a member added to either set needs a reason.
 */
const NON_DEFECTS = new Map([
  [`${PACKAGE}ResourceList`, 'its editor is a dialog over the list itself'],
  [`${PACKAGE}AuditUserEventList`, 'its editor is a dialog over the list itself'],
  [`${PACKAGE}AuditList`, "its name cell opens the row's detail dialog on its id"],
  [`${PACKAGE}JournalRecordList`, "its name cell opens the row's detail dialog on its id"],
  [`${PACKAGE}TaskHistoryList`, "its name cell opens the row's detail dialog on its id"],
]);

const SQL_SCHEMAS = `${PACKAGE}ExplorerSqlSchemas`;

/** Every built screen that draws a `name` column. */
const namedScreens = SCREENS.filter((screen) => screen.built && (screen.table?.columns ?? []).some((column) => column.kind === 'name'));

/** The screens whose name cell links, and links back to the screen itself. A target with no id route leaves the cell as text. */
const selfLinking = () =>
  namedScreens
    .filter((screen) => {
      const target = nameLinkTarget(screen);
      return target !== null && hasIdRoute(target) && target.route === screen.route;
    })
    .map((screen) => screen.descriptor)
    .sort();

// Mutation (Rule 19): restore the old last arm of `nameLinkTarget` (`screen.parentScope === '' ? screen : null`)
// -> every unpaired top-level list links to itself and this goes red naming them. Add a descriptor to
// `DETAIL_DIALOG_LISTS` -> the set-equality assertion goes red until a reason is added to `NON_DEFECTS`.
test('Story 20.39 AC2: the lists whose name cell links back to themselves are exactly the declared dialog lists', () => {
  assert.ok(namedScreens.length > 100, `the mirror carries the built screens that draw a name column (${namedScreens.length})`);
  assert.deepEqual(selfLinking(), [...NON_DEFECTS.keys()].sort(), 'a list that links its name to itself is declared, and a declared one still does');
  assert.deepEqual(
    [...DIALOG_EDITORS, ...DETAIL_DIALOG_LISTS].sort(),
    [...NON_DEFECTS.keys()].sort(),
    'every member of a client dialog set has a reason here, and every reason names a set member'
  );
});

/** The descriptors among `screens` whose name cell links to a screen that is not built. */
const unbuiltLinkTargets = (screens) =>
  screens
    .filter((screen) => {
      const target = nameLinkTarget(screen);
      return target !== null && hasIdRoute(target) && target.built !== true;
    })
    .map((screen) => screen.descriptor);

// Mutation (Rule 19): make `unbuiltLinkTargets` never flag a target (`target.built !== true` becomes
// `false`) -> the control test below goes red.
test('Story 20.38 AC4: a name cell never links to a screen that is not built', () => {
  assert.deepEqual(unbuiltLinkTargets(namedScreens), [], 'no built list links its name to a screen that is not built');
});

test('Story 20.38 AC4: the unbuilt-target check flags a name cell that links to a screen that is not built', () => {
  const real = namedScreens.find((screen) => screen.descriptor === [...DETAIL_DIALOG_LISTS][0]);
  assert.ok(real !== undefined, 'the control starts from a built list that links its name to itself');
  const unbuilt = { ...real, route: 'security/unbuilt-probe', built: false, parentScope: '', rowTarget: null, classicLinkExemption: { exempt: false } };
  assert.equal(nameLinkTarget(unbuilt), unbuilt, 'a dialog list links to itself');
  assert.deepEqual(unbuiltLinkTargets([unbuilt]), [real.descriptor], 'the unbuilt copy is flagged');
  assert.deepEqual(unbuiltLinkTargets([real]), [], 'and the built original is not');
});

test('Story 20.39 AC2: the declared dialog lists are built lists that draw a name column, and SQL schemas is not one', () => {
  const nonDefects = [...NON_DEFECTS.keys()];
  assert.equal(nonDefects.includes(SQL_SCHEMAS), false, 'SQL schemas is not a dialog list');
  const named = new Set(namedScreens.map((screen) => screen.descriptor));
  for (const descriptor of nonDefects) {
    assert.ok(named.has(descriptor), `${descriptor} is a built screen that draws a name column`);
  }
});

// Mutation (Rule 19): drop `documentScreenFor` from `nameLinkTarget`, or the `ExplorerSqlSchema`
// head's route, and SQL schemas links to its own route again -> the first assertion goes red.
test('Story 20.38 AC1: the SQL schemas list opens the schema screen, and each of its three tabs opens its own kind\'s screen through its row field', () => {
  const schemas = screenForRoute('system-explorer/sql-schemas');
  assert.ok(schemas !== null && schemas.descriptor === SQL_SCHEMAS, 'the SQL schemas list is declared');
  assert.equal(nameLinkTarget(schemas)?.route, 'system-explorer/sql-schemas/document', 'its name cell opens the schema screen');
  const tabs = [
    ['system-explorer/sql-schemas/document', 'system-explorer/sql-tables/document', 'Table'],
    ['system-explorer/sql-schemas/views', 'system-explorer/sql-views/document', 'View'],
    ['system-explorer/sql-schemas/procedures', 'system-explorer/sql-procedures/document', 'Procedure'],
  ];
  for (const [route, target, field] of tabs) {
    const tab = screenForRoute(route);
    assert.ok(tab !== null, `${route} is declared`);
    assert.equal(nameLinkTarget(tab)?.route, target, `${route}'s name cell opens ${target}`);
    assert.deepEqual(tab.rowTarget, { route: target, field }, `${route} carries ${field} to it`);
  }
});

/**
 * What a name cell opens for the lists that once linked to themselves: the route `nameLinkTarget`
 * answers, or `null` where the cell is text. A target with no id route also draws text.
 */
const FORMER_SELF_LINKS = [
  ['system-explorer/classes/document', null],
  ['system-explorer/routines/document', null],
  ['permissions/sql-privileges', null],
  ['permissions/sql-column-privileges', null],
  ['permissions/sql-admin-privileges', null],
  ['web-applications/list/class-access', null],
  ['security/auditing/system-events', null],
  ['security/allowed-directories', null],
  ['os-management/database-free-space', 'os-management/databases/details'],
  ['os-management/ecp-application-servers/ssl', null],
  ['tasks/on-demand', 'tasks/schedule/details'],
  ['tasks/upcoming', 'tasks/schedule/details'],
  ['tasks/background', null],
  ['system-explorer/docdb', null],
  ['interoperability/business-partners', null],
  ['analytics/folder-items', null],
  ['agent/screenpermissions', null],
];

// Mutation (Rule 19): delete `TaskOnDemandList`'s or `DatabaseFreeSpace`'s `rowTarget`, regenerate the
// mirror -> its row below goes red.
test('Story 20.39 AC1: each list that linked to itself opens the screen of its own entity, or draws text', () => {
  for (const [route, expected] of FORMER_SELF_LINKS) {
    const screen = screenForRoute(route);
    assert.ok(screen !== null && screen.built, `${route} is a built screen`);
    const target = nameLinkTarget(screen);
    const opened = target !== null && hasIdRoute(target) ? target.route : null;
    assert.equal(opened, expected, `${route}'s name cell ${expected === null ? 'is text' : `opens ${expected}`}`);
  }
});

// Mutation (Rule 19): admit every top-level list in the last arm of `nameLinkTarget` -> this goes red.
test('Story 20.39 AC2: a top-level list that pairs nothing and sits in neither dialog set draws its name as text', () => {
  const real = namedScreens.find((screen) => screen.descriptor === `${PACKAGE}AllowedDirectoryList`);
  assert.ok(real !== undefined, 'the control starts from a built list that pairs nothing');
  const probe = { ...real, descriptor: `${PACKAGE}NameLinkProbe`, route: 'security/name-link-probe', parentScope: '', rowTarget: null, classicLinkExemption: { exempt: false } };
  assert.equal(nameLinkTarget(probe), null, 'a list in no set answers no target');
  const dialog = { ...probe, descriptor: [...DETAIL_DIALOG_LISTS][0] };
  assert.equal(nameLinkTarget(dialog), dialog, 'and the same list declared in a dialog set links to itself');
});

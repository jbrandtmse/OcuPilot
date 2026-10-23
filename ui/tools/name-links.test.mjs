import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins what a built list's name cell opens, through `nameLinkTarget`, the one chain the shared table
// draws its link from (AD-5): a built list never links a name back to its own list, except where a
// reason is declared here. A name cell that links to its own list changes the address and the
// breadcrumb and opens no screen, which is how the SQL schemas list shipped.
//
// Two declared sets hold every list that links to itself. `NON_DEFECTS` are the lists whose own id
// route is the right target. `STORY_20_39_ALLOW_LIST` is the lists Story 20.39 fixes, and it empties
// there: a fix that leaves its row in place, or a new self-link, turns this red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { DIALOG_EDITORS, hasIdRoute, nameLinkTarget, screenForRoute } = await import(corePath('navigation.ts'));
const { SCREENS } = await import(corePath('screens.generated.ts'));

const PACKAGE = 'OcuPilot.Screen.Descriptor.';
const qualified = (names) => names.map((name) => `${PACKAGE}${name}`);

/**
 * The lists whose own id route is the right target for their name cell, each with the reason.
 * The two dialog editors are `DIALOG_EDITORS`: their editor is a dialog over the list itself.
 */
const NON_DEFECTS = new Map([
  ...[...DIALOG_EDITORS].map((descriptor) => [descriptor, 'its editor is a dialog over the list itself']),
  [`${PACKAGE}AuditList`, "its name cell opens the row's detail dialog on its id"],
  [`${PACKAGE}JournalRecordList`, "its name cell opens the row's detail dialog on its id"],
  [`${PACKAGE}TaskHistoryList`, "its name cell opens the row's detail dialog on its id"],
  [`${PACKAGE}LicenseKey`, 'its page never draws the shared table'],
  [`${PACKAGE}OpenApiViewer`, 'its page never draws the shared table'],
]);

/**
 * The lists Story 20.39 fixes, by descriptor, in the order of the table in Story 20.38's spec
 * (rows 2 to 18; row 1, SQL schemas, is fixed by Story 20.38 and is in neither set).
 */
const STORY_20_39_ALLOW_LIST = qualified([
  'ExplorerClassDocument', // system-explorer/classes/document
  'ExplorerRoutineDocument', // system-explorer/routines/document
  'SqlPrivilegeList', // permissions/sql-privileges
  'SqlColumnPrivilegeList', // permissions/sql-column-privileges
  'SqlAdminPrivilegeList', // permissions/sql-admin-privileges
  'WebAppPctAccessList', // web-applications/list/class-access
  'AuditSystemEventList', // security/auditing/system-events
  'AllowedDirectoryList', // security/allowed-directories
  'DatabaseFreeSpace', // os-management/database-free-space
  'EcpSslConnectionTab', // os-management/ecp-application-servers/ssl
  'TaskOnDemandList', // tasks/on-demand
  'TaskUpcomingList', // tasks/upcoming
  'BackgroundTaskList', // tasks/background
  'ExplorerDocDbList', // system-explorer/docdb
  'InteropBusinessPartnerList', // interoperability/business-partners
  'AnalyticsFolderItemList', // analytics/folder-items
  'AgentScreenPermissions', // agent/screenpermissions
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

// Mutation (Rule 19): drop the `documentScreenFor` arm from `nameLinkTarget` -> SQL schemas, and
// every other list that pairs a document viewer, link to themselves, and the exact-set assertion
// goes red naming them. Delete one row of `STORY_20_39_ALLOW_LIST` -> the same assertion goes red
// naming that list.
test('Story 20.38 AC4: the lists whose name cell links back to themselves are exactly the declared non-defects and Story 20.39\'s allow-list', () => {
  assert.ok(namedScreens.length > 100, `the mirror carries the built screens that draw a name column (${namedScreens.length})`);
  const declared = [...NON_DEFECTS.keys(), ...STORY_20_39_ALLOW_LIST].sort();
  assert.deepEqual(selfLinking(), declared, 'a list that links its name to itself is declared, and a declared one still does');
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
  const real = namedScreens.find((screen) => screen.descriptor === `${PACKAGE}AllowedDirectoryList`);
  assert.ok(real !== undefined, 'the control starts from a built list that pairs nothing');
  const unbuilt = { ...real, route: 'security/unbuilt-probe', built: false, parentScope: '', rowTarget: null, classicLinkExemption: { exempt: false } };
  assert.equal(nameLinkTarget(unbuilt), unbuilt, 'a list that pairs nothing links to itself');
  assert.deepEqual(unbuiltLinkTargets([unbuilt]), [real.descriptor], 'the unbuilt copy is flagged');
  assert.deepEqual(unbuiltLinkTargets([real]), [], 'and the built original is not');
});

test('Story 20.38 AC4: the declared sets are disjoint, name only built lists that draw a name column, and leave SQL schemas in neither', () => {
  const nonDefects = [...NON_DEFECTS.keys()];
  assert.equal(new Set(STORY_20_39_ALLOW_LIST).size, STORY_20_39_ALLOW_LIST.length, 'the allow-list names no list twice');
  assert.deepEqual(
    nonDefects.filter((descriptor) => STORY_20_39_ALLOW_LIST.includes(descriptor)),
    [],
    'no list is both a non-defect and on the allow-list'
  );
  assert.equal(nonDefects.includes(SQL_SCHEMAS) || STORY_20_39_ALLOW_LIST.includes(SQL_SCHEMAS), false, 'SQL schemas is in neither set');
  const named = new Set(namedScreens.map((screen) => screen.descriptor));
  for (const descriptor of [...nonDefects, ...STORY_20_39_ALLOW_LIST]) {
    assert.ok(named.has(descriptor), `${descriptor} is a built screen that draws a name column`);
  }
  // Temporary: Story 20.39 empties the allow-list and deletes this count in the same pass.
  assert.equal(STORY_20_39_ALLOW_LIST.length, 17, "the allow-list is rows 2 to 18 of Story 20.38's table");
  for (const descriptor of DIALOG_EDITORS) {
    assert.ok(NON_DEFECTS.has(descriptor), `${descriptor} is a dialog editor, so a declared non-defect`);
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

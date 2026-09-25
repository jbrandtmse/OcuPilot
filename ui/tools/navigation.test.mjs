import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the client half of the descriptor registry and of the navigation map (AD-5, AD-8):
// what the route table is built from, what the rail and the side bar list, and what happens to
// the map when a call is refused.
//
// Mutations (Rule 19):
// - the `built` filter in builtScreensForArea has NO subject here and no mutation to name: the
//   shipped mirror carries only built screens, so dropping the filter leaves every test
//   in this file green. The rule is pinned server-side instead, by
//   OcuPilot.Test.Descriptor:TestOnlyBuiltScreensReachASideBar over the Test.Screen.Unbuilt
//   fixture. Giving the client half a subject needs an unbuilt screen in a roster the mirror
//   does not carry -- filed, not fixed here.
// - fill load()'s in-flight slot after the fetch resolves instead of before it starts -> the
//   "a 403 on the map's own call re-reads nothing" test goes red with an unbounded fetch count,
//   because the refusal the call itself reports finds the slot empty and starts another load.
// - drop the `namespace` key so every caller joins -> the DW-157 re-run row goes red, and the map
//   stays computed against the namespace the shell has left.
// - make an un-answered map read as denied -> the "nothing is gated until the map arrives"
//   test goes red, and an administrator would see a fully gated rail for one round trip.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const {
  NavigationService,
  NAVIGATION_PATH,
  UNGATED,
  orderedAreas,
  areaByKey,
  builtScreens,
  builtScreensForArea,
  childListFor,
  detailScreenFor,
  documentScreenFor,
  createFormFor,
  CREATE_ONLY_FORMS,
  DIALOG_EDITORS,
  editorScreenFor,
  isListedScreen,
  listedScreensForArea,
  ownIdSegment,
  parentCriteria,
  parentListFor,
  routeEntityType,
  screenForRoute,
  screenForUrl,
  tabGroupFor,
  tabMembersFor,
  areaForUrl,
  hasIdRoute,
  routeFromUrl,
  formatArea,
  formatDeniedAction,
  formatDeniedScreen,
  formatRequires,
  firstAllowedScreen,
  screenForChange,
  screenForEntityType,
  screenForToolName,
  screenShowsEntity,
  withQuery,
} = await import(corePath('navigation.ts'));
const { AREAS, SCREENS } = await import(corePath('screens.generated.ts'));
const { ApiService } = await import(corePath('api.ts'));
const { STRINGS, stringFor } = await import(corePath('strings.ts'));
const { encodeEntityId } = await import(corePath('entity-id.ts'));

/** A map answer shaped the way `GET /api/ocupilot/navigation` shapes one. */
function mapBody(areas) {
  return { areas };
}

/** The smallest thing `NavigationService` needs: something that answers `requestJson`. */
function stubApi(answers) {
  const calls = [];
  return {
    calls,
    requestJson: async (path) => {
      calls.push(path);
      const next = answers[Math.min(calls.length - 1, answers.length - 1)];
      return next;
    },
  };
}

function ok(body) {
  return { kind: 'ok', status: 200, body };
}

// --- The registry over the mirror ---------------------------------------------------------

test('the mirror carries the eight areas in rail order, with Agent co-pilot pinned bottom', () => {
  const areas = orderedAreas();
  assert.equal(areas.length, 8);
  assert.deepEqual(
    areas.map((area) => area.key),
    ['home', 'logs', 'os-management', 'tasks', 'permissions', 'web-applications', 'security', 'agent']
  );
  areas.forEach((area, index) => assert.equal(area.railPosition, index + 1));
  assert.equal(areas.filter((area) => area.pinBottom).length, 1);
  assert.equal(areas[areas.length - 1].pinBottom, true, 'and it is the last one');
  assert.equal(areas.filter((area) => area.navigates).length, 1, 'exactly one area navigates');
  assert.equal(areas[0].navigates, true, 'and it is Home');
});

test("every area's and every screen's label key exists in the one string source", () => {
  for (const area of AREAS) {
    assert.notEqual(stringFor(area.labelKey), '', `area ${area.key} names a missing string key`);
  }
  for (const screen of SCREENS) {
    assert.notEqual(
      stringFor(screen.labelKey),
      '',
      `screen ${screen.route} names a missing string key`
    );
  }
});

test('a side bar lists only built screens, in side-bar order', () => {
  for (const area of AREAS) {
    const listed = builtScreensForArea(area.key);
    for (const screen of listed) {
      assert.equal(screen.area, area.key);
      assert.equal(screen.built, true, 'an unbuilt screen never appears in a side bar');
    }
    const positions = listed.map((screen) => screen.sideBarPosition);
    assert.deepEqual(positions, [...positions].sort((a, b) => a - b), 'in side-bar order');
  }
  assert.deepEqual(
    builtScreens().map((screen) => screen.route),
    [
      '',
      'logs/alerts',
      'logs/messages',
      'logs/errors',
      'logs/audit',
      'os-management/databases/details',
      'os-management/database-free-space',
      'os-management/databases/volumes',
      'os-management/devices/edit',
      'os-management/processes/details',
      'os-management/processes',
      'os-management/locks',
      'os-management/system-usage',
      'os-management/databases',
      'os-management/devices',
      'tasks/schedule/details',
      // Story 9.7: the unlisted New Task wizard, reached from the Task schedule's Create.
      'tasks/schedule/edit',
      'tasks/schedule/history',
      'tasks/schedule',
      'tasks/on-demand',
      'tasks/upcoming',
      'tasks/history',
      'permissions/roles/edit',
      // Story 9.9: the unlisted reduced service form, reached from the Services list's name cell.
      'permissions/services/edit',
      'permissions/users/edit',
      'permissions/users',
      'permissions/roles',
      'permissions/resources',
      'permissions/services',
      'web-applications/rest-apis/document',
      'web-applications/list/edit',
      'web-applications/list',
      'web-applications/rest-apis',
      // Story 7.4: the two unlisted audit event lists, then Auditing configuration at position 6.
      'security/auditing/system-events',
      'security/auditing/user-events',
      // Story 9.9: the unlisted reduced LDAP configuration form, reached from the LDAP / Kerberos list.
      'security/ldap/edit',
      'security/oauth/clients',
      'security/oauth/resource-servers',
      'security/oauth/server-clients',
      'security/oauth/server',
      // Story 9.5: the unlisted SSL/TLS configuration form, reached from the SSL/TLS list.
      'security/ssl/edit',
      'security/wallet/secrets/edit',
      'security/wallet/secrets',
      'security/x509/edit',
      'security/ssl',
      'security/x509',
      'security/ldap',
      'security/wallet',
      'security/oauth',
      'security/auditing',
      'agent/definitions/edit',
      'agent/definitions',
      'agent/switches',
    ],
    'the built screens are Home, at the application root, then the alerts.log viewer, the application error log and the audit database, the unlisted Database details, Free-space view, Volume files and device editor, process details, processes, Locks, System usage, Databases, the unlisted task details, New Task wizard and per-task history, task schedule, on-demand tasks, upcoming tasks, task history, the unlisted user form and service form, users, roles, resources, services, OpenAPI document viewer, the unlisted web-application form, web applications, REST API explorer, the unlisted LDAP configuration form, the four unlisted OAuth 2.0 tabs, the unlisted SSL/TLS configuration form, the unlisted wallet secret form, Secrets, the unlisted X.509 credential form, SSL/TLS, X.509, LDAP / Kerberos, Wallet and OAuth 2.0 screens, and the Agent co-pilot area\'s Definition form, Definitions list and Switches, in area rail order'
  );
});

// Story 3.5. `sideBarPosition` 0 is the sentinel for routable-but-unlisted: the route table reads
// every built screen, and the five navigation surfaces read an area's listed ones.
//
// Mutation (Rule 19): change the Definition form descriptor's `sideBarPosition` from 0 to 2 ->
// the listed-roster assertion below goes red at two entries where one is expected, and the
// `builtScreens()` roster leg above stays green -- which is what proves the filter is on listing
// and not on routing.
test('an unlisted screen is routable and never advertised: the agent area lists two screens and builds three', () => {
  const built = builtScreensForArea('agent');
  assert.deepEqual(
    built.map((screen) => screen.route),
    ['agent/definitions/edit', 'agent/definitions', 'agent/switches'],
    'all three agent screens are built, the form first because it takes position 0'
  );
  assert.deepEqual(
    listedScreensForArea('agent').map((screen) => screen.route),
    ['agent/definitions', 'agent/switches'],
    'the side bar lists Definitions then Switches -- the form takes no position'
  );
  assert.equal(
    isListedScreen(built.find((screen) => screen.route === 'agent/definitions/edit')),
    false,
    'the form is the unlisted one'
  );
  assert.equal(
    screenForRoute('agent/definitions/edit')?.sideBarPosition,
    0,
    'and 0 is the sentinel it declares, not an absent key read as 0'
  );
  // The service seam the five surfaces reach it through answers the listed set, so a component
  // test that substitutes a roster substitutes the same thing the shipped mirror answers.
  const service = new NavigationService({ api: stubApi([ok(mapBody([]))]) });
  assert.deepEqual(service.screensForArea('agent'), listedScreensForArea('agent'));
});

// Story 3.5: a list paired with a form is what the name cell opens, by the `<list route>/edit`
// convention rather than by a declaration key.
//
// Mutation (Rule 19): make `editorScreenFor` ignore `isListedScreen` -> nothing reddens today,
// because no listed screen sits at a `<route>/edit`; make it ignore `hasIdRoute` and the
// negative assertions below go red, because Home would resolve one.
test('editorScreenFor resolves a list to its unlisted, id-keyed editor and to nothing else', () => {
  const list = screenForRoute('agent/definitions');
  assert.ok(list, 'the Definitions list is declared');
  assert.equal(editorScreenFor(list).route, 'agent/definitions/edit');
  const home = screenForRoute('');
  assert.ok(home, 'Home is declared');
  assert.equal(editorScreenFor(home), null, 'a screen with no paired editor resolves none');
  // Story 9.5: the SSL/TLS list pairs with its one form -- built, unlisted and keyed by an id -- so
  // its Create opens the form and a row's name opens the same form at its id route.
  // Mutation (Rule 19): give SslForm a side-bar position -> the unlisted assertion goes red; drop its
  // descriptor -> every assertion below goes red.
  const ssl = screenForRoute('security/ssl');
  assert.equal(createFormFor(ssl)?.route, 'security/ssl/edit', 'the SSL/TLS list\'s Create opens its own form');
  assert.equal(isListedScreen(screenForRoute('security/ssl/edit')), false, 'which takes no side-bar position');
  assert.equal(editorScreenFor(ssl)?.route, 'security/ssl/edit', 'and a row name opens the SSL/TLS editor at its id route');
  // Story 9.7: the Task schedule's Create opens the New Task wizard -- built, unlisted and keyed by
  // an id. Story 9.8's Edit task reads the id at the same form's id route, so the form is no longer
  // create-only and the list pairs an editor as well as its detail screen; the name cell still opens
  // the details (`data-table.ts`), where Edit is.
  // Mutation (Rule 19): put TaskForm back in `CREATE_ONLY_FORMS` -> the editor assertion goes red.
  const schedule = screenForRoute('tasks/schedule');
  assert.equal(createFormFor(schedule)?.route, 'tasks/schedule/edit', 'the Task schedule\'s Create opens the New Task wizard');
  assert.equal(isListedScreen(screenForRoute('tasks/schedule/edit')), false, 'which takes no side-bar position');
  assert.deepEqual([...CREATE_ONLY_FORMS], [], 'no form is create-only');
  assert.equal(editorScreenFor(schedule)?.route, 'tasks/schedule/edit', 'so a task opens Edit task at the form\'s id route');
  assert.equal(detailScreenFor(schedule)?.route, 'tasks/schedule/details', 'beside the task\'s details');
  // Story 9.9: the two reduced forms are the editors their lists' name cells open.
  assert.equal(editorScreenFor(screenForRoute('security/ldap'))?.route, 'security/ldap/edit', 'the LDAP / Kerberos list opens its reduced form');
  assert.equal(editorScreenFor(screenForRoute('permissions/services'))?.route, 'permissions/services/edit', 'and the Services list its own');
  assert.equal(
    editorScreenFor(screenForRoute('os-management/locks')),
    null,
    'and a list with no editor resolves none'
  );
});

// Story 6.1: a list paired with a document viewer is what the name cell opens, by the
// `<list route>/document` convention, with the same three halves as `editorScreenFor`.
//
// Mutation (Rule 19): give the viewer descriptor a side-bar position -> the listed-roster assertion
// below goes red. The built, unlisted and id-keyed guards themselves are unpinned today: no shipped
// `<list>/document` screen fails one of them.
test('documentScreenFor resolves the REST API explorer to its unlisted, id-keyed document viewer and to nothing else', () => {
  const explorer = screenForRoute('web-applications/rest-apis');
  assert.ok(explorer, 'the REST API explorer is declared');
  assert.equal(documentScreenFor(explorer).route, 'web-applications/rest-apis/document');
  assert.equal(editorScreenFor(explorer), null, 'and it pairs with no editor');
  assert.equal(documentScreenFor(screenForRoute('')), null, 'Home resolves no viewer');
  assert.equal(documentScreenFor(screenForRoute('web-applications/list')), null, 'and neither does a list with none');
  // Story 8.1: the Web applications list's Create opens its own form -- built, unlisted and keyed
  // by an id -- and Story 9.2's editor reads the id, so a row's name opens it.
  // Mutation (Rule 19): put WebAppForm back in `CREATE_ONLY_FORMS` -> the editor assertion below
  // goes red.
  const webApps = screenForRoute('web-applications/list');
  assert.equal(createFormFor(webApps).route, 'web-applications/list/edit', 'the Web applications list\'s Create opens its own form');
  assert.equal(isListedScreen(screenForRoute('web-applications/list/edit')), false, 'which takes no side-bar position');
  assert.equal(editorScreenFor(webApps)?.route, 'web-applications/list/edit', 'and a row name opens the web application editor at its id route');
  assert.equal(createFormFor(screenForRoute('agent/definitions')).route, 'agent/definitions/edit', 'and a form that reads its id is both');
  // Story 8.2: the Users list pairs with its create form the same way; Story 9.1's user editor reads
  // the id, so a row's name opens it.
  // Mutation (Rule 19): put UserForm back in `CREATE_ONLY_FORMS` -> the editor assertion below goes red.
  const users = screenForRoute('permissions/users');
  assert.equal(createFormFor(users).route, 'permissions/users/edit', 'the Users list\'s Create opens its own form');
  assert.equal(isListedScreen(screenForRoute('permissions/users/edit')), false, 'which takes no side-bar position');
  assert.equal(editorScreenFor(users)?.route, 'permissions/users/edit', 'and a row name opens the user editor at its id route');
  // Story 8.3: the Roles list pairs with its create form the same way; Story 9.3's role editor reads
  // the id, so a row's name opens it.
  // Mutation (Rule 19): put RoleForm back in `CREATE_ONLY_FORMS` -> the editor assertion below goes red.
  // Story 8.4: the Resources list's editor is a dialog over the list, not a paired form, so it
  // resolves no form and no editor screen, and it is the one dialog-editor screen, id-keyed so a
  // row's name cell opens its own id route.
  // Mutation (Rule 19): drop ResourceList from `DIALOG_EDITORS` -> the dialog-editor assertion goes red.
  const resources = screenForRoute('permissions/resources');
  assert.deepEqual([...DIALOG_EDITORS], [resources.descriptor], 'the Resources list is the one screen whose editor is a dialog');
  assert.equal(createFormFor(resources), null, 'so its Create opens no form page');
  assert.equal(editorScreenFor(resources), null, 'and a row name opens the list\'s own id route');
  assert.equal(hasIdRoute(resources), true, 'which it declares');
  const roles = screenForRoute('permissions/roles');
  assert.equal(createFormFor(roles).route, 'permissions/roles/edit', 'the Roles list\'s Create opens its own form');
  assert.equal(isListedScreen(screenForRoute('permissions/roles/edit')), false, 'which takes no side-bar position');
  assert.equal(editorScreenFor(roles)?.route, 'permissions/roles/edit', 'and a row name opens the role editor at its id route');
  assert.deepEqual(
    listedScreensForArea('web-applications').map((screen) => screen.route),
    ['web-applications/list', 'web-applications/rest-apis'],
    'the side bar lists Web applications then the REST API explorer -- the viewer takes no position'
  );
  assert.equal(isListedScreen(screenForRoute('web-applications/rest-apis/document')), false, 'the viewer is the unlisted one');
});

// Story 6.3: a sub-resource list is paired with its parent by its own `parentScope` declaration, not
// by a route suffix, and the name cell and the locator bar both read the pairing.
//
// Mutation (Rule 19): match any non-empty `parentScope` in `childListFor` instead of the list's own
// route -> "a list with no child resolves none" goes red. Drop the inverse check from `parentListFor`
// -> "a screen naming a parent it is not the child of resolves none" goes red.
test('childListFor pairs the Wallet list with its Secrets list, parentListFor inverts it, and a secrets URL resolves to Secrets', () => {
  const wallet = screenForRoute('security/wallet');
  const secrets = screenForRoute('security/wallet/secrets');
  assert.ok(wallet && secrets, 'both lists are declared');
  assert.equal(childListFor(wallet)?.route, 'security/wallet/secrets', 'the Wallet list opens its Secrets list');
  assert.equal(parentListFor(secrets)?.route, 'security/wallet', 'and the Secrets list names the Wallet list as its parent');
  assert.equal(editorScreenFor(wallet), null, 'the Wallet list pairs no editor');
  assert.equal(documentScreenFor(wallet), null, 'and no viewer');
  assert.equal(childListFor(screenForRoute('security/ssl')), null, 'a list with no child resolves none');
  assert.equal(childListFor(screenForRoute('')), null, 'and neither does Home');
  assert.equal(childListFor(secrets), null, 'the Secrets list has no child of its own');
  assert.equal(parentListFor(wallet), null, 'and the Wallet list has no parent');
  assert.equal(
    parentListFor({ ...secrets, route: 'security/wallet/other' }),
    null,
    'a screen naming a parent it is not the child of resolves none'
  );
  assert.equal(isListedScreen(secrets), false, 'the Secrets list is never listed');
  assert.deepEqual(
    listedScreensForArea('security').map((screen) => screen.route),
    ['security/ssl', 'security/x509', 'security/ldap', 'security/wallet', 'security/oauth', 'security/auditing'],
    'the Security side bar lists SSL/TLS, X.509, LDAP / Kerberos, Wallet, OAuth 2.0 and Auditing configuration'
  );

  assert.equal(screenForUrl('/security/wallet/secrets/OcuPilotDemo?ns=HSCUSTOM')?.route, 'security/wallet/secrets', 'a secrets URL with a collection id resolves to the Secrets list');
  assert.equal(screenForUrl('/security/wallet/secrets?ns=HSCUSTOM')?.route, 'security/wallet/secrets', 'and so does the route with no id, never the Wallet list with an id of "secrets"');
  assert.equal(screenForUrl('/security/wallet/OcuPilotDemo')?.route, 'security/wallet', 'while a Wallet URL with an id is the Wallet list');
});

// Story 6.6, DW-1020: a sub-resource screen's route id names an entity of its parent's own
// primary entity type, resolved through parentScope, while its rows keep their own type.
//
// Mutation (Rule 19): make routeEntityType return `screen.entityType` unconditionally -> the two
// parented assertions go red, reading `task-history-entry` and `wallet-secret`, while the
// unparented assertion stays green by coincidence.
test('routeEntityType resolves through parentScope for a sub-resource screen, and answers its own type otherwise', () => {
  const taskRun = screenForRoute('tasks/schedule/history');
  const secrets = screenForRoute('security/wallet/secrets');
  const history = screenForRoute('tasks/history');
  assert.ok(taskRun && secrets && history, 'all three screens are declared');
  assert.equal(routeEntityType(taskRun), 'task', "History (one task)'s route id names the task it is scoped to");
  assert.equal(routeEntityType(secrets), 'wallet-collection', 'and the Secrets list\'s names the wallet collection');
  assert.equal(routeEntityType(history), 'task-history-entry', 'a screen with no parent answers its own primary type');
  assert.equal(taskRun.entityType, 'task-history-entry', "its rows keep their own type regardless");
  assert.equal(secrets.entityType, 'wallet-secret', "and so do the Secrets list's");
});

// Story 6.6: Task schedule keys its rows on the vendor's numeric `Id`, so History (one task) --
// reached from Task details' own History link since Story 6.7 re-pointed the name cell there --
// renders the same columns Task history does (AC2, AC3). `childListFor` still resolves Task
// schedule's child list to History; only the name cell's own target moved (`detailScreenFor`,
// pinned separately below).
//
// Mutation (Rule 19): Task schedule's id kind `single` in the mirror -> the key assertion goes red;
// History's `Result` column renamed in the mirror -> the column assertion goes red.
test("Task schedule keys on Id and its child list is History, whose columns are Task history's", () => {
  const schedule = screenForRoute('tasks/schedule');
  const taskRun = screenForRoute('tasks/schedule/history');
  const history = screenForRoute('tasks/history');
  assert.ok(schedule && taskRun && history, 'all three screens are declared');
  assert.deepEqual(schedule.id, { kind: 'composite', parts: ['Id'] }, "Task schedule's row key is the vendor's numeric Id");
  assert.equal(childListFor(schedule)?.route, 'tasks/schedule/history', "its child list is History");
  assert.equal(parentListFor(taskRun)?.route, 'tasks/schedule', 'which names Task schedule as its parent');
  assert.deepEqual(
    taskRun.table?.columns.map((column) => [column.field, column.labelKey]),
    [
      ['LastStart', 'taskHistoryColumnStarted'],
      ['Completed', 'taskHistoryColumnCompleted'],
      ['Name', 'tableColumnName'],
      ['Status', 'taskHistoryColumnStatus'],
      ['Result', 'taskHistoryColumnResult'],
      ['Username', 'processColumnUser'],
      ['Namespace', 'headerNamespaceLabel'],
    ],
    'History shows Started, Completed, Name, Status, Result, User and Namespace'
  );
  assert.deepEqual(taskRun.table?.columns, history.table?.columns, "the same columns as Task history's");
});

// Story 6.7: Task schedule's name cell opens Task details rather than the one-task History, which
// stays reachable only from Task details' own History link. `detailScreenFor` is the pairing a
// `detail`-class parentScope screen takes; `childListFor` skips it, so the two screens that both
// declare `parentScope` `tasks/schedule` resolve through their own functions rather than one
// picking whichever sorts first.
//
// Mutation (Rule 19): drop `child.archetype !== 'detail'` from `childListFor` -> this test's first
// assertion goes red, reading `tasks/schedule/details` instead of `tasks/schedule/history`.
test('detailScreenFor pairs Task schedule with Task details, childListFor still finds History, and both invert through parentListFor', () => {
  const schedule = screenForRoute('tasks/schedule');
  const details = screenForRoute('tasks/schedule/details');
  const taskRun = screenForRoute('tasks/schedule/history');
  assert.ok(schedule && details && taskRun, 'all three screens are declared');
  assert.equal(detailScreenFor(schedule)?.route, 'tasks/schedule/details', "Task schedule's detail screen is Task details");
  assert.equal(childListFor(schedule)?.route, 'tasks/schedule/history', 'and its child list is still History, not Task details');
  assert.equal(parentListFor(details)?.route, 'tasks/schedule', 'Task details names Task schedule as its parent');
  assert.equal(parentListFor(taskRun)?.route, 'tasks/schedule', 'and so does History, through the same inverse');
  assert.equal(detailScreenFor(taskRun), null, 'History is not itself a detail screen');
  assert.equal(details.archetype, 'detail', 'Task details is the detail archetype');
  assert.equal(details.tab, null, 'and declares no tab');
});

// Story 6.8: the same pairing for the processes list and Process details.
test('detailScreenFor pairs Processes with Process details', () => {
  const processes = screenForRoute('os-management/processes');
  const details = screenForRoute('os-management/processes/details');
  assert.ok(processes && details, 'both screens are declared');
  assert.equal(detailScreenFor(processes)?.route, 'os-management/processes/details', "Processes' detail screen is Process details");
  assert.equal(parentListFor(details)?.route, 'os-management/processes', 'Process details names Processes as its parent');
  assert.equal(details.archetype, 'detail', 'Process details is the detail archetype');
});

// Story 6.4, AD-5: a tabbed screen is one descriptor per tab. `tabMembersFor` reads the group's built
// members in position order, and `tabGroupFor` names the group's first tab for every member.
//
// Mutation (Rule 19): swap `tab.position` of the resource servers and authorization server tabs ->
// the member order below goes red.
test('tabMembersFor lists the OAuth 2.0 tabs in position order, and tabGroupFor names the group for each', () => {
  const group = screenForRoute('security/oauth');
  const routes = ['security/oauth', 'security/oauth/clients', 'security/oauth/resource-servers', 'security/oauth/server', 'security/oauth/server-clients'];
  for (const route of routes) {
    const member = screenForRoute(route);
    assert.deepEqual(
      tabMembersFor(member).map((tab) => tab.route),
      routes,
      `${route}'s strip is the five tabs in position order`
    );
    assert.equal(tabGroupFor(member)?.route, 'security/oauth', `${route}'s group is the OAuth 2.0 screen`);
    assert.equal(member.archetype, 'detail', `${route} is a detail view`);
  }
  assert.deepEqual(
    tabMembersFor(group).map((tab) => stringFor(tab.tab.labelKey)),
    ['Client server descriptions', 'Client configurations', 'Resource servers', 'Authorization server', 'Server client descriptions'],
    'labelled by each tab.labelKey'
  );
  assert.equal(isListedScreen(group), true, 'the group\'s first tab is its side-bar entry');
  for (const route of routes.slice(1)) assert.equal(isListedScreen(screenForRoute(route)), false, `${route} is unlisted`);
  assert.deepEqual(tabMembersFor(screenForRoute('security/ssl')), [], 'a screen that is no tab has no strip');
  assert.equal(tabGroupFor(screenForRoute('security/ssl')), null, 'and no group');
  assert.equal(screenForUrl('/security/oauth/server-clients?ns=HSCUSTOM')?.route, 'security/oauth/server-clients', 'a tab URL resolves to its own tab');
  assert.equal(
    tabGroupFor({ ...screenForRoute('security/oauth/clients'), tab: { group: 'security/nosuch', position: 2, labelKey: 'oauthTabClients' } }),
    null,
    'a group no built first tab declares resolves none'
  );
});

// Story 5.11, DW-1419: a list opened on its own route id names the row to select. One helper
// serves both callers that produce such a URL -- the agent's `shell.screen.open` with an
// `entityId`, and a change toast's "Open in <screen>" -- so the selection cannot be right for one
// and wrong for the other.
//
// Mutation (Rule 19): drop the second `decodeEntityId` -> the `%Demo_1` round trip goes red; drop
// the `segment.includes('/')` guard -> the sub-resource row goes red, because a task details URL
// would read as the schedule's own id; drop the `parentScope !== ''` guard -> the parent-scoped
// rows go red, because a sub-resource list would select whichever row shares its parent's key.
test('ownIdSegment reads a list screen\'s own route id, and nothing else', () => {
  const tasks = screenForRoute('tasks/schedule');
  assert.equal(ownIdSegment(tasks, '/tasks/schedule/7?ns=HSCUSTOM'), '7');
  for (const id of ['%Demo_1', 'a.b', 'a-b_c', '/csp/myapp']) {
    const url = `/tasks/schedule/${encodeEntityId(id)}?ns=HSCUSTOM`;
    assert.equal(ownIdSegment(tasks, url), id, `the id ${id} round-trips`);
  }
  assert.equal(ownIdSegment(tasks, '/tasks/schedule?ns=HSCUSTOM'), '', 'the bare route names no row');
  assert.equal(ownIdSegment(tasks, '/tasks/schedule/details/7'), '', 'and a sub-resource route is not this screen\'s id');
  assert.equal(ownIdSegment(tasks, '/tasks/history?ns=HSCUSTOM'), '', 'nor is another route');
  assert.equal(ownIdSegment(screenForRoute(''), '/7'), '', 'the root screen administers no entity, so it takes no id');
  const noId = screenForRoute('agent/switches');
  assert.equal(hasIdRoute(noId), false, 'a screen whose id kind is none has no id route');
  assert.equal(ownIdSegment(noId, '/agent/switches/7'), '', 'and reads no id from a segment the route table does not hold');

  // A parent-scoped list's trailing segment is its PARENT's id -- what `parentCriteria` reads it
  // as -- and none of its rows is keyed by it: a run of task history is keyed by its run id, not
  // by the task the route names. Both kinds are covered, a composite parent and a single one.
  for (const route of ['tasks/schedule/history', 'security/wallet/secrets']) {
    const child = screenForRoute(route);
    assert.notEqual(child.parentScope, '', `${route} is parent-scoped`);
    assert.equal(hasIdRoute(child), true, `${route} still takes an id route, so the guard is the thing answering`);
    assert.equal(ownIdSegment(child, `/${route}/7?ns=HSCUSTOM`), '', `${route} reads its parent's id as no row of its own`);
    assert.deepEqual(parentCriteria(child, `/${route}/7?ns=HSCUSTOM`), { [child.read.criteria.fields[0].param]: '7' }, 'while parentCriteria reads that same segment as the parent it is');
  }
});

// Story 6.3: a parent-scoped list's one criterion comes from the URL's id, decoded once past the
// router's own decode (AD-13).
//
// Mutation (Rule 19): decode the segment once instead of twice -> the `%Demo_1` round trip goes red.
// Drop the `parentScope === ''` guard -> "a list with no parent fills no criterion, whatever it
// declares" goes red.
test('parentCriteria fills the Secrets list\'s one criterion with the decoded route id, and nothing else', () => {
  const secrets = screenForRoute('security/wallet/secrets');
  assert.deepEqual(parentCriteria(secrets, '/security/wallet/secrets/OcuPilotDemo?ns=HSCUSTOM'), { collection: 'OcuPilotDemo' });
  for (const id of ['%Demo_1', 'a.b', 'a-b_c']) {
    const url = `/security/wallet/secrets/${encodeEntityId(id)}?ns=HSCUSTOM`;
    assert.deepEqual(parentCriteria(secrets, url), { collection: id }, `the id ${id} round-trips`);
  }
  assert.deepEqual(parentCriteria(secrets, '/security/wallet/secrets?ns=HSCUSTOM'), {}, 'no id fills nothing');
  assert.deepEqual(parentCriteria(secrets, '/security/wallet?ns=HSCUSTOM'), {}, 'nor does another route');
  assert.deepEqual(parentCriteria(screenForRoute('security/wallet'), '/security/wallet/OcuPilotDemo'), {}, 'and a list with no parent fills no criterion');
  assert.deepEqual(
    parentCriteria({ ...secrets, parentScope: '' }, '/security/wallet/secrets/OcuPilotDemo?ns=HSCUSTOM'),
    {},
    'a list with no parent fills no criterion, whatever it declares'
  );
});

test('a route resolves to the descriptor that declared it, and a detail URL to its parent', () => {
  assert.equal(screenForRoute('')?.area, 'home', "Home's route is the empty string");
  assert.equal(screenForRoute('no/such/route'), null);
  assert.equal(screenForUrl('/')?.route, '');
  assert.equal(areaForUrl('/'), 'home');
  assert.equal(areaForUrl('/nope/nope'), '', 'an unknown URL belongs to no area');
  assert.equal(routeFromUrl('/security/oauth?ns=HSCUSTOM#x'), 'security/oauth');

  // A detail URL is its screen's route plus one id segment (AD-13), and only for a screen
  // whose id accessor says it has one -- Home's does not, so `/anything` is not Home.
  assert.equal(screenForUrl('/anything'), null, "the root screen takes no id, so /anything is unknown");
  assert.equal(hasIdRoute(screenForRoute('')), false);
});

// --- The placeholders the canonical strings leave ------------------------------------------

test('the area and resource placeholders resolve, and every occurrence of each', () => {
  assert.equal(
    formatArea(STRINGS.navRailItemTooltip, 'Logs'),
    'Logs \u00B7 Ctrl+B toggles the side bar'
  );
  assert.equal(formatArea(STRINGS.navSideBarLandmark, 'Tasks'), 'Tasks screens');
  assert.equal(
    formatRequires(STRINGS.privilegeRequiresResource, '%Admin_Secure:USE'),
    'Requires %Admin_Secure:USE'
  );
  assert.equal(
    formatDeniedScreen(STRINGS.privilegeDeniedScreen, '%Admin_Secure:USE', 'Users'),
    'You need %Admin_Secure:USE to open Users.'
  );
  // The same pattern with its second slot resolved to an action instead of a screen title: the
  // inline sentence a 403 carrying a pair renders (AD-8). Pinned here beside its two siblings
  // rather than only through the one screen that calls it, so a `<resource>`/`<action>` drift
  // between `navigation.ts` and `strings.ts` goes red where the family is gated.
  //
  // Mutation (Rule 19): give ACTION_PLACEHOLDER any other spelling -> this assertion goes red
  // with the unresolved `<action>` still in the string, while formatRequires and
  // formatDeniedScreen stay green.
  assert.equal(
    formatDeniedAction(STRINGS.privilegeDeniedAction, '%DB_IRISSYS:READ', STRINGS.errorLogRefusedAction),
    'You need %DB_IRISSYS:READ to read this log.'
  );
  assert.equal(formatArea('<Area> and <Area>', 'X'), 'X and X', 'every occurrence, not the first');
  assert.equal(
    formatDeniedAction('<resource> <action> <resource> <action>', 'R', 'A'),
    'R A R A',
    'both slots, every occurrence, not the first of each'
  );
  assert.ok(
    !formatArea(STRINGS.navSideBarLandmark, 'Tasks').includes('<Area>'),
    'a resolved string never ships its placeholder'
  );
  // No `includes('<')` check for formatDeniedAction: the literal assertion above already pins the
  // resolved string exactly, with the same three arguments, and throws first -- so such a check
  // could never be the assertion that fails. `formatArea`'s above has no literal pin beside it.
});

// --- The map -------------------------------------------------------------------------------

test('nothing is gated until the map arrives', () => {
  const service = new NavigationService({ api: stubApi([ok(mapBody([]))]) });
  assert.equal(service.loaded(), false);
  assert.deepEqual(service.areaVerdict('permissions'), UNGATED);
  assert.deepEqual(service.screenVerdict('permissions/users'), UNGATED);
});

test('the map is read into per-area and per-screen verdicts, with the failed pair kept', async () => {
  const api = stubApi([
    ok(
      mapBody([
        { key: 'home', allowed: true, screens: [{ route: '', allowed: true }] },
        {
          key: 'permissions',
          allowed: false,
          failedPair: '%Admin_Secure:USE',
          screens: [{ route: 'permissions/users', allowed: false, failedPair: '%Admin_Secure:USE' }],
        },
      ])
    ),
  ]);
  const service = new NavigationService({ api });
  await service.load();

  assert.equal(api.calls[0], NAVIGATION_PATH, 'through the one absolute API path');
  assert.equal(service.loaded(), true);
  assert.deepEqual(service.areaVerdict('home'), { allowed: true, failedPair: '' });
  assert.deepEqual(service.areaVerdict('permissions'), {
    allowed: false,
    failedPair: '%Admin_Secure:USE',
  });
  assert.deepEqual(service.screenVerdict('permissions/users'), {
    allowed: false,
    failedPair: '%Admin_Secure:USE',
  });
  assert.deepEqual(service.areaVerdict('logs'), UNGATED, 'an area the map did not mention is not gated');
});

test('one request however many callers', async () => {
  const api = stubApi([ok(mapBody([]))]);
  const service = new NavigationService({ api });
  await Promise.all([service.load(), service.load(), service.load()]);
  assert.equal(api.calls.length, 1);
});

test('a failed map read settles nothing, so a later load can still answer', async () => {
  const api = stubApi([
    { kind: 'error', status: 500, code: 'INTERNAL', reason: null },
    ok(mapBody([{ key: 'logs', allowed: false, failedPair: '%Admin_Operate:USE', screens: [] }])),
  ]);
  const service = new NavigationService({ api });
  await service.load();
  assert.equal(service.loaded(), false, 'a failure is not an answer about privilege');
  assert.deepEqual(service.areaVerdict('logs'), UNGATED);

  await service.load();
  assert.equal(service.loaded(), true);
  assert.equal(service.areaVerdict('logs').allowed, false);
});

test('the map has answered once a read completes, with a map or with a failure, and a reset forgets it', async () => {
  const failing = new NavigationService({ api: stubApi([{ kind: 'error', status: 500, code: 'INTERNAL', reason: null }]) });
  let failingNotified = 0;
  failing.subscribe(() => (failingNotified += 1));
  assert.equal(failing.answered(), false, 'nothing has answered before a read');
  await failing.load();
  assert.equal(failing.answered(), true, 'a failed read has answered, so a page still mounts over UNGATED verdicts');
  assert.equal(failingNotified, 1, 'and says so once, since an OnPush outlet mounts the page only when told');
  assert.equal(failing.loaded(), false);

  const service = new NavigationService({ api: stubApi([ok(mapBody([]))]) });
  let notified = 0;
  service.subscribe(() => (notified += 1));
  await service.load();
  assert.equal(service.answered(), true);
  assert.ok(notified > 0, 'and says so to its subscribers');
  service.reset();
  assert.equal(service.answered(), false, 'a second principal waits for its own answer (AD-8)');
});

test('DW-9: a 403 re-reads the map, so a privilege revoked after load corrects itself', async () => {
  const api = stubApi([
    ok(mapBody([{ key: 'logs', allowed: true, screens: [] }])),
    ok(mapBody([{ key: 'logs', allowed: false, failedPair: '%Admin_Operate:USE', screens: [] }])),
  ]);
  const service = new NavigationService({ api });
  await service.load();
  assert.equal(service.areaVerdict('logs').allowed, true);

  // What `ApiService.onForbidden` calls on any 403 from any call.
  service.noteForbidden();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(api.calls.length, 2, 'the map was read again');
  assert.equal(service.areaVerdict('logs').allowed, false, 'without a reload');
  assert.equal(service.areaVerdict('logs').failedPair, '%Admin_Operate:USE');
});

test('the map is re-read when the scope moves, through the same single-flight load (AD-44)', async () => {
  const api = stubApi([
    ok(mapBody([{ key: 'logs', allowed: true, screens: [] }])),
    ok(mapBody([{ key: 'logs', allowed: false, failedPair: '%Admin_Operate:USE', screens: [] }])),
  ]);
  const service = new NavigationService({ api });
  await service.load();
  assert.equal(api.calls.length, 1);

  // What `onScopeChange` calls when the resolved namespace moves. `noteForbidden` is the same
  // read named for a refusal; `reload` is it named for the general case, and this is the case.
  service.reload();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(api.calls.length, 2, 'the map is read again against the namespace now in force');
  assert.equal(service.areaVerdict('logs').allowed, false, 'without a reload and without re-routing');
});

// --- DW-157: join on an unchanged namespace, re-run once on a changed one --------------------
//
// The three rows below are one rule read three ways, and each needs the other two: a read that
// only ever joins installs a verdict computed against a namespace the shell has left, and one
// that always queues loops against the DW-9 stub. The rule lives in `core/single-flight.ts`,
// whose own suite pins it as a primitive; these exercise it through the real `NavigationService`
// (Integration AC, Rule 1) rather than through a mock of it.

test('DW-157: a scope change mid-flight re-runs the map read once, against the new namespace', async () => {
  // read #1 is held open until the test releases it, standing in for a fetch still in flight when
  // the scope moves. read #2 is the one the change is owed, and it must carry the new namespace.
  let releaseFirst = () => {};
  const held = new Promise((resolve) => {
    releaseFirst = resolve;
  });
  const api = {
    calls: [],
    requestJson: async (path, init) => {
      api.calls.push({ path, scope: init?.scope });
      if (api.calls.length === 1) {
        await held;
        return ok(mapBody([{ key: 'logs', allowed: true, screens: [] }]));
      }
      return ok(mapBody([{ key: 'logs', allowed: false, failedPair: '%Admin_Operate:USE', screens: [] }]));
    },
  };
  let namespace = 'HSCUSTOM';
  const service = new NavigationService({ api, namespace: () => namespace });

  const pending = service.load(); // read #1 starts, against the namespace in force right now
  namespace = 'USER';
  service.reload(); // `onScopeChange`'s call, before #1 settles
  namespace = 'SAMPLES'; // and the user keeps switching while #1 is still out
  service.reload();
  releaseFirst();
  await pending;
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(api.calls.length, 2, 'one re-run, however many times the namespace moved');
  assert.equal(api.calls[0].scope, 'HSCUSTOM', "read #1 carried the namespace it started under");
  assert.equal(api.calls[1].scope, 'SAMPLES', 'and the re-run carries the latest, not the first change');
  assert.equal(
    service.areaVerdict('logs').allowed,
    false,
    "the verdict installed is the re-run's, computed against the namespace now in force"
  );
});

test('DW-157: two reloads with the namespace unchanged are one read', async () => {
  let releaseFirst = () => {};
  const held = new Promise((resolve) => {
    releaseFirst = resolve;
  });
  const api = {
    calls: [],
    requestJson: async (path) => {
      api.calls.push(path);
      await held;
      return ok(mapBody([{ key: 'logs', allowed: true, screens: [] }]));
    },
  };
  const service = new NavigationService({ api, namespace: () => 'HSCUSTOM' });

  const pending = service.load();
  service.reload();
  service.reload();
  releaseFirst();
  await pending;
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(api.calls.length, 1, 'a repeat joins rather than queueing behind itself');
});

test("DW-9: a 403 on the map's own call re-reads nothing, so the shell cannot loop", async () => {
  const api = {
    calls: [],
    requestJson: async (path) => {
      api.calls.push(path);
      // The navigation call itself is refused, and the caller reports it the way `ApiService`
      // does -- while the fetch is still in flight.
      service.noteForbidden();
      return { kind: 'error', status: 403, code: 'AUTH.NOADMIN', reason: null };
    },
  };
  // With the namespace source wired, exactly as `src/main.ts` wires it: the refusal the call
  // reports about itself reads the same namespace, so it joins. A queue keyed on anything other
  // than the input would loop here, which is why the mark is keyed on the input.
  const service = new NavigationService({ api, namespace: () => 'HSCUSTOM' });
  await service.load();
  assert.equal(api.calls.length, 1, 'a refusal arriving during the fetch arms no second one');

  // And a refusal arriving later still re-reads exactly once.
  service.noteForbidden();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(api.calls.length, 2);
});

test('reset forgets the map, so the next principal in this tab is asked about afresh', async () => {
  const api = stubApi([ok(mapBody([{ key: 'logs', allowed: false, failedPair: 'x:USE', screens: [] }]))]);
  const service = new NavigationService({ api });
  await service.load();
  assert.equal(service.areaVerdict('logs').allowed, false);

  let notified = 0;
  const stop = service.subscribe(() => {
    notified += 1;
  });
  service.reset();
  stop();

  assert.equal(service.loaded(), false, 'a second principal inherits no verdict (AD-8)');
  assert.deepEqual(service.areaVerdict('logs'), UNGATED);
  assert.equal(notified, 1, 'and the shell is told, so the rail stops showing the old gating');
});

test('the listing seams delegate to the mirror, so a component test can substitute a roster', () => {
  const service = new NavigationService({ api: stubApi([ok(mapBody([]))]) });
  assert.deepEqual(service.areas(), orderedAreas());
  assert.deepEqual(service.screensForArea('home'), builtScreensForArea('home'));
  assert.equal(areaByKey('security')?.labelKey, 'navAreaSecurity');
  assert.equal(areaByKey('no-such-area'), null);
});

// --- The wiring: a 403 from any call tells the map ----------------------------------------

test('ApiService calls onForbidden on a 403, and on nothing else', async () => {
  const statuses = [403, 500, 404, 200];
  const seen = [];
  const api = new ApiService({
    fetch: async () => ({ status: statuses.shift(), text: async () => '{"code":"AUTH.NOPRIVILEGE"}' }),
    tokens: { read: () => null, accessToken: () => '' },
    session: {
      remainingMs: () => 1,
      refresh: async () => false,
      noteInstallInFlight: () => false,
    },
    onForbidden: () => seen.push('told'),
  });

  await api.requestJson('/api/ocupilot/navigation');
  assert.deepEqual(seen, ['told'], 'a 403 is news');
  await api.requestJson('/api/ocupilot/instance');
  await api.requestJson('/api/ocupilot/instance');
  await api.requestJson('/api/ocupilot/instance');
  assert.deepEqual(seen, ['told'], 'a 500, a 404 and a 200 are not');
});

test('an install-in-flight refusal never reaches onForbidden', async () => {
  const seen = [];
  const api = new ApiService({
    fetch: async () => ({ status: 403, text: async () => '{"code":"INSTALL.INSTALLING"}' }),
    tokens: { read: () => null, accessToken: () => '' },
    session: {
      remainingMs: () => 1,
      refresh: async () => false,
      // The classification is Session's; this stands in for it saying yes.
      noteInstallInFlight: () => true,
    },
    onForbidden: () => seen.push('told'),
  });

  const result = await api.requestJson('/api/ocupilot/navigation');
  assert.equal(result.kind, 'installing');
  assert.deepEqual(seen, [], 'an instance that is coming up has revoked nobody');
});

// --- AD-44 / DW-134: the one query parameter that survives a navigation ---------------------
//
// Every navigating surface in the shell -- rail, side bar, locator, command box -- routes
// through `withQuery`, so this is the single place the rule is decided.
//
// Mutations (Rule 19):
// - return `'/' + route` unconditionally -> the carry row goes red, and every rail, side-bar,
//   locator and command-box click silently moves the user's work to another namespace.
// - carry the whole query string instead of `ns` -> the "nothing else travels" row goes red,
//   and one screen's page/filter/sort would be applied to an unrelated screen.

test('withQuery carries the namespace across a navigation, and nothing else', () => {
  assert.equal(withQuery('logs/messages', '/permissions/users?ns=USER'), '/logs/messages?ns=USER');
  // Home's declared route is the empty string, which is still a rooted URL.
  assert.equal(withQuery('', '/permissions/users?ns=USER'), '/?ns=USER');

  // Screen state stays with the screen it belongs to.
  assert.equal(
    withQuery('logs/messages', '/permissions/users?page=3&ns=USER&sort=name'),
    '/logs/messages?ns=USER'
  );
  assert.equal(withQuery('logs/messages', '/permissions/users?page=3'), '/logs/messages');

  // No query, and a fragment that addresses a position inside the screen being left.
  assert.equal(withQuery('logs/messages', '/permissions/users'), '/logs/messages');
  assert.equal(withQuery('logs/messages', '/permissions/users?ns=USER#row-4'), '/logs/messages?ns=USER');

  // A namespace whose name needs escaping survives as one parameter rather than two.
  assert.equal(
    withQuery('logs/messages', '/x?ns=' + encodeURIComponent('A&B')),
    '/logs/messages?ns=A%26B'
  );
});

// --- DW-161: "the area's first screen" is the first one the user may actually open ----------
//
// Mutation (Rule 19): return `screens[0] ?? null` from `firstAllowedScreen` -> the skip row goes
// red, and a tile or a locator segment would navigate straight into a refusal page.

test('firstAllowedScreen skips the screens the verdict refuses, and answers null when all are', () => {
  const roster = [{ route: 'a' }, { route: 'b' }, { route: 'c' }];
  const allow = (allowed) => (route) => ({ allowed: allowed.includes(route), failedPair: 'R:USE' });

  assert.equal(firstAllowedScreen(roster, allow(['a', 'b', 'c']))?.route, 'a');
  assert.equal(firstAllowedScreen(roster, allow(['b', 'c']))?.route, 'b', 'the refused first is skipped');
  assert.equal(firstAllowedScreen(roster, allow(['c']))?.route, 'c');
  assert.equal(firstAllowedScreen(roster, allow([])), null, 'none allowed is null, not the first');

  // Declaration order decides, never verdict order: the roster is already in side-bar order and
  // re-sorting it here would move which screen an area opens on.
  assert.equal(firstAllowedScreen(roster, allow(['c', 'b']))?.route, 'b');

  // An empty roster is null as well -- the same answer for a different reason, which is why
  // callers that must tell "nowhere to go" from "somewhere, but refused" read the roster length.
  assert.equal(firstAllowedScreen([], allow(['a'])), null);
});

test("firstAllowedScreen over the shipped mirror: Home's own area opens Home", () => {
  // The real roster, not a fixture: at the end of Epic 1 one screen is built and it is allowed,
  // so the amended rule and the old one agree -- which is what makes the fixtures above the
  // subject rather than this.
  const home = builtScreensForArea('home');
  assert.equal(firstAllowedScreen(home, () => UNGATED)?.route, home[0]?.route);
  assert.equal(firstAllowedScreen(home, () => ({ allowed: false, failedPair: 'R:USE' })), null);
});

// AD-13, AD-14: the one predicate `RefreshService` and the toast store both call. Two inline
// copies would be two answers, and a change that both highlighted a row and raised a toast -- or
// did neither -- is the divergence AD-14's last sentence is about.
//
// Mutation (Rule 19): drop the scope test from `screenShowsEntity` -> the two scope rows below go
// red, and a change in `USER` would re-fetch a list scoped to `HSCUSTOM`.
test('screenShowsEntity answers the type half and the scope half, and both have to hold', () => {
  const list = screenForRoute('web-applications/list');
  assert.ok(list !== null && list.entityType === 'web-application');
  assert.equal(list.scope, 'instance', 'a web application has no namespace, so its scope is the literal');

  assert.equal(screenShowsEntity(list, { type: 'web-application', scope: 'instance' }, 'HSCUSTOM'), true);
  assert.equal(
    screenShowsEntity(list, { type: 'task', scope: 'instance' }, 'HSCUSTOM'),
    false,
    'a type the screen does not show'
  );
  assert.equal(
    screenShowsEntity(list, { type: 'web-application', scope: 'HSCUSTOM' }, 'HSCUSTOM'),
    false,
    'the right type in the wrong scope is a different entity (AD-13)'
  );

  // A namespace-scoped screen resolves its scope from the namespace the shell is in, which is
  // what makes the same event mine in one namespace and not in another.
  const restApis = screenForRoute('web-applications/rest-apis');
  assert.ok(restApis !== null && restApis.scope === 'namespace');
  assert.equal(screenShowsEntity(restApis, { type: 'rest-service', scope: 'HSCUSTOM' }, 'HSCUSTOM'), true);
  assert.equal(
    screenShowsEntity(restApis, { type: 'rest-service', scope: 'HSCUSTOM' }, 'USER'),
    false,
    'the shell has moved, so the event is about another namespace'
  );

  // A secondary type counts: the OAuth 2.0 tab shows three, and a change to any of them is its.
  const oauth = screenForRoute('security/oauth');
  assert.ok(oauth !== null && oauth.secondaryEntityTypes.length > 0);
  assert.equal(
    screenShowsEntity(oauth, { type: oauth.secondaryEntityTypes[0], scope: 'instance' }, 'HSCUSTOM'),
    true
  );
});

// The toast's action. Mutation (Rule 19): build the route without `encodeEntityId` -> the
// encoded-segment assertion goes red for the id carrying a slash, and the toast would open a URL
// the route table does not hold.
test('screenForChange resolves the screen a change opens and the route that names the entity', () => {
  const target = screenForChange({ type: 'web-application', id: '/csp/myapp' });
  assert.ok(target !== null);
  assert.equal(target.screen.route, 'web-applications/list');
  assert.equal(target.screen, screenForEntityType('web-application'), 'the same lookup, not a second one');
  assert.equal(target.route, `web-applications/list/${encodeEntityId('/csp/myapp')}`);
  // DW-1546, PRD UJ-6: a change opens the entity's list with the entity selected -- the listed list
  // earliest in its side bar -- so a task's toast opens the Task schedule, not the task's details.
  // Mutation (Rule 19): answer the first built screen of the type -> the task and definition legs go red.
  assert.equal(screenForEntityType('task').route, 'tasks/schedule', 'a task change opens the Task schedule');
  assert.equal(screenForChange({ type: 'task', id: '12' })?.route, 'tasks/schedule/12', 'with the task as the route id');
  assert.equal(screenForEntityType('agent-definition').route, 'agent/definitions', 'a definition change opens the Definitions list');
  assert.equal(screenForEntityType('user').route, 'permissions/users', 'a user change opens the Users list, not its editor');
  assert.equal(screenForEntityType('role').route, 'permissions/roles', 'a role change opens the Roles list, not its editor');
  assert.equal(screenForEntityType('database').route, 'os-management/databases', 'and of two database lists, the listed one');
  assert.ok(!target.route.includes('/csp/myapp'), 'the id is one encoded segment, never raw path (AD-13)');

  // A type no built screen shows is not a fault: the toast still says what changed, with nothing
  // to open. Every declared type now has a built screen, so an undeclared type stands in for one.
  // DW-1529: a system event and a user event are two types, so each change opens its own list.
  assert.equal(screenForEntityType('audit-event')?.route, 'security/auditing/system-events', 'a system audit event opens the System events list');
  assert.equal(screenForEntityType('audit-user-event')?.route, 'security/auditing/user-events', 'a user audit event opens the User events list');
  assert.equal(
    screenForChange({ type: 'audit-user-event', id: 'ocupilot/security/agentwrite' })?.screen.route,
    'security/auditing/user-events',
    "a user event's change toast opens the User events list"
  );
  assert.equal(screenForEntityType('not-an-entity-type'), null, 'no built screen shows an undeclared type');
  assert.equal(screenForChange({ type: 'not-an-entity-type', id: 'x' }), null);

  // A screen whose descriptor declares no id route takes the bare route: there is no segment for
  // the entity, and appending one would be a URL the route table does not hold.
  const switches = SCREENS.find((screen) => screen.entityType === 'agent-switch' && screen.built);
  assert.ok(switches !== undefined && !hasIdRoute(switches));
  assert.equal(screenForChange({ type: 'agent-switch', id: 'instance' })?.route, switches.route);
});

// DW-1227: a proposal card's masked-field lookup is keyed on the proposal's own tool, not on its
// entity type. A tool name is claimed by exactly one screen, while two screens may declare one
// entity type. Since Story 7.4 every write tool's screen is built, so the auditing row reads the
// same screen through both lookups.
//
// Mutation (Rule 19): key `screenForToolName` on the first name segment alone -> the auditing and
// web-application rows go red.
test('screenForToolName resolves a write tool to its own screen', () => {
  const auditing = screenForToolName('security.auditing.update');
  assert.ok(auditing !== null, 'the auditing write resolves');
  assert.equal(auditing.toolIdentifier, 'security.auditing', "to the screen whose identifier its name opens with");
  assert.equal(auditing.built, true, 'which Story 7.4 built');
  assert.equal(screenForEntityType(auditing.entityType), auditing, 'and which the entity-type lookup reaches too');

  const webApp = screenForToolName('webapp.list.update');
  assert.ok(webApp !== null && webApp.toolIdentifier === 'webapp.list', 'a built screen resolves the same way');
  assert.equal(screenForToolName('nosuch.screen.update'), null, 'a tool no screen owns resolves to nothing');
  assert.equal(screenForToolName('single'), null, 'and so does a name with no screen segment');
});

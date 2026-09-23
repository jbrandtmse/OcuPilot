/**
 * The client's screen registry and the navigation map it gates on (AD-5, AD-8).
 *
 * Two halves, both framework-free so `node --test` executes them:
 *
 * - **The registry** -- ordered areas, each area's built screens, and the route-to-descriptor
 *   lookup -- reads `screens.generated.ts`, which is the mirror of the same XData the server
 *   reads. There is no second hand-written list of screens anywhere in the client, and the
 *   route table is built from this rather than typed out.
 * - **`NavigationService`** holds the map `GET /api/ocupilot/navigation` answered with: one
 *   `allowed` per area and per built screen and, when denied, the `(resource, permission)`
 *   pair that failed. The server recomputes every verdict from live state on every call
 *   (AD-8), so the map is a snapshot of an answer, never an authority in its own right.
 *
 * **A 403 re-reads the map.** Privileges can change after the map was fetched -- a role
 * revoked mid-session -- and the shell learns about it the moment any call is refused:
 * `ApiService` calls `noteForbidden()` on every 403 and the map is fetched again. The re-read
 * joins a fetch already running **in the same namespace**, which is what keeps the navigation
 * call's own 403 (a caller who holds no administrative resource at all) from looping; a fetch
 * running against a namespace the shell has since left is re-run once instead (**DW-157**,
 * `single-flight.ts`).
 *
 * **Before the map arrives nothing is gated.** An unanswered question is not a denial: marking
 * every entry gated until the first response would show an administrator a fully gated rail
 * for the length of one round trip. Entries become gated when the map says so. What waits for
 * the map is a screen's page: `ScreenOutlet` mounts none until `answered()`, so a screen the map
 * then refuses issues no read of its own.
 */

import type { ApiService } from './api';
import type { ConnectivityService } from './connectivity';
import { decodeEntityId, encodeEntityId } from './entity-id.ts';
import { scopeFor } from './entity-ref.ts';
import { AREAS, SCREENS, type AreaDeclaration, type ScreenDeclaration } from './screens.generated.ts';
import { createSingleFlight } from './single-flight.ts';

/** Absolute from the origin root, through the one API service (AD-20). */
export const NAVIGATION_PATH = '/api/ocupilot/navigation';

/** One verdict: whether the calling process may reach a thing, and why not when it may not. */
export interface Verdict {
  readonly allowed: boolean;
  readonly failedPair: string;
}

/** The verdict a screen or an area carries before the map has answered. */
export const UNGATED: Verdict = { allowed: true, failedPair: '' };

interface ScreenVerdictWire {
  route?: unknown;
  allowed?: unknown;
  failedPair?: unknown;
}

interface AreaVerdictWire {
  key?: unknown;
  allowed?: unknown;
  failedPair?: unknown;
  screens?: unknown;
}

interface NavigationWire {
  areas?: unknown;
}

export interface NavigationOptions {
  readonly api: ApiService;
  /**
   * Where a failed map read is parked (DW-135). Optional so a test that is not about the
   * re-read can leave it out.
   */
  readonly connectivity?: ConnectivityService;
  /**
   * The resolved namespace the map is computed against (AD-44), read at call time rather than
   * held -- the same lazy shape `ApiOptions.scope` uses, and for the same reason: `src/main.ts`
   * builds this service before the one that answers it.
   *
   * It is the **single-flight key** (**DW-157**): a map read already in flight is the right
   * answer for a second caller in the same namespace and the wrong one after a switch, and the
   * key is what tells those apart. Defaults to `() => ''`, which makes every read join -- the
   * behaviour of a shell that is not namespace-scoped at all.
   */
  readonly namespace?: () => string;
}

/** The areas in rail order. Agent co-pilot is pinned to the bottom by `pinBottom`. */
export function orderedAreas(): readonly AreaDeclaration[] {
  return AREAS;
}

/** The area declared under `key`, or `null`. */
export function areaByKey(key: string): AreaDeclaration | null {
  return AREAS.find((area) => area.key === key) ?? null;
}

/**
 * The screens an area's side bar lists: its own, built, in side-bar order. An area with no
 * built screens lists nothing, which is the correct rendering of "a screen that is not yet
 * built does not appear in the side-bar" (EXPERIENCE.md "Entries in daily-use order.") and not a missing empty state.
 */
export function builtScreensForArea(areaKey: string): readonly ScreenDeclaration[] {
  return SCREENS.filter((screen) => screen.area === areaKey && screen.built).sort(
    (a, b) => a.sideBarPosition - b.sideBarPosition
  );
}

/** Every built screen, in area rail order then side-bar order. The route table reads this. */
export function builtScreens(): readonly ScreenDeclaration[] {
  return AREAS.flatMap((area) => builtScreensForArea(area.key));
}

/**
 * Whether a built screen is **listed** as a navigation target.
 *
 * `sideBarPosition` 0 is the sentinel for routable-but-unlisted: a screen reached from its own
 * list -- the name cell, or that list's Create -- and named by no navigation surface. The
 * Definition form is the first of them, and every later editor paired with a list takes the same
 * shape.
 *
 * **The rule is on listing, never on routing.** `builtScreens` and `builtScreensForArea` keep
 * every built screen, because `app.routes.ts` builds the route table from `builtScreens()` and an
 * unlisted screen still has to be reachable.
 */
export function isListedScreen(screen: ScreenDeclaration): boolean {
  return screen.sideBarPosition > 0;
}

/**
 * The screens an area lists as navigation targets: `builtScreensForArea` less the ones that take
 * no side-bar position. The side bar, the command box, Home's tile caption, the locator bar's area
 * segment and the rail's landing all read this; the route table does not.
 */
export function listedScreensForArea(areaKey: string): readonly ScreenDeclaration[] {
  return builtScreensForArea(areaKey).filter(isListedScreen);
}

/**
 * The first screen in `screens` the caller may actually open, or `null` when none of them is
 * (**DW-161**).
 *
 * Every surface that opens "the area's first screen" -- Home's tile, the locator's area segment
 * -- has to answer the same question, and answering it as `screens[0]` navigates a user with the
 * area but not its first screen straight into a refusal. The verdict is passed in rather than
 * read here so this stays a pure function over a roster and a lookup: the same shape
 * `formatRequires` and `withQuery` take, and executable under `node --test`.
 *
 * An empty roster answers `null` as well, which is the same answer for a different reason -- an
 * area with nothing built has nowhere to go either. Callers that must tell "nowhere to go" from
 * "somewhere, but refused" compare the roster's own length.
 */
export function firstAllowedScreen(
  screens: readonly ScreenDeclaration[],
  verdictFor: (route: string) => Verdict
): ScreenDeclaration | null {
  return screens.find((screen) => verdictFor(screen.route).allowed) ?? null;
}

/**
 * The route segment a list's own editor is declared under, appended to the list's route.
 *
 * The convention, not a declaration key: a `form-page` paired with a list lives at
 * `<list route>/edit`, declares `sideBarPosition` 0, and is reached from that list's name cell and
 * its Create. Expressing it as a key would have touched the declaration vocabulary, both engines'
 * key lists, the mirror's own interface and every hardcoded roster in the wire tests, for a fact
 * two routes already state between them.
 */
export const EDITOR_ROUTE_SUFFIX = 'edit';

/**
 * The editor a list's rows open, or `null` when the list has none.
 *
 * A row's name cell is a link to the entity's own surface (EXPERIENCE.md's `data-table`), and for
 * a list paired with a form that surface is the form, not the list's own route with an id on the
 * end. It is `createFormFor`'s form less the `CREATE_ONLY_FORMS`, which read no id and so cannot
 * open the row's entity.
 */
export function editorScreenFor(screen: ScreenDeclaration): ScreenDeclaration | null {
  const editor = createFormFor(screen);
  if (editor === null || CREATE_ONLY_FORMS.has(editor.descriptor)) return null;
  return editor;
}

/**
 * The form a list's Create opens, or `null` when the list has none. Both halves are required: the
 * form is built, it is unlisted (so this cannot resolve to an ordinary sibling screen that merely
 * sorts after the list), and it is keyed by an id.
 */
export function createFormFor(screen: ScreenDeclaration): ScreenDeclaration | null {
  const editor = screenForRoute(`${screen.route}/${EDITOR_ROUTE_SUFFIX}`);
  if (editor === null || !editor.built || isListedScreen(editor) || !hasIdRoute(editor)) return null;
  return editor;
}

/**
 * Paired forms that create and never open an existing entity: their `:id` route exists so a Save
 * can replace the URL with the new entity's, but the page reads no id, so neither a row's name cell
 * nor a change toast may open one. The Web application form (Story 8.1) and the create-a-user form
 * (Story 8.2) are the create halves of their lists' editors; Epic 9's editors read the id, and
 * their stories remove the entries.
 */
export const CREATE_ONLY_FORMS: ReadonlySet<string> = new Set([
  'OcuPilot.Screen.Descriptor.WebAppForm',
  'OcuPilot.Screen.Descriptor.UserForm',
]);

/**
 * The route segment a list's own document viewer is declared under, appended to the list's route.
 *
 * The same convention as `EDITOR_ROUTE_SUFFIX`: a viewer paired with a list lives at
 * `<list route>/document`, declares `sideBarPosition` 0, and is reached from that list's name cell.
 */
export const DOCUMENT_ROUTE_SUFFIX = 'document';

/**
 * The document viewer a list's rows open, or `null` when the list has none. The same three halves
 * as `editorScreenFor`: built, unlisted, and keyed by an id.
 */
export function documentScreenFor(screen: ScreenDeclaration): ScreenDeclaration | null {
  const viewer = screenForRoute(`${screen.route}/${DOCUMENT_ROUTE_SUFFIX}`);
  if (viewer === null || !viewer.built || isListedScreen(viewer) || !hasIdRoute(viewer)) return null;
  return viewer;
}

/** The list `screen` is the document viewer of (`documentScreenFor`'s inverse), or `null`. */
export function listForDocumentScreen(screen: ScreenDeclaration): ScreenDeclaration | null {
  const suffix = `/${DOCUMENT_ROUTE_SUFFIX}`;
  if (!screen.route.endsWith(suffix)) return null;
  const list = screenForRoute(screen.route.slice(0, -suffix.length));
  return list !== null && documentScreenFor(list)?.route === screen.route ? list : null;
}

/**
 * The sub-resource list a list's rows open, or `null` when the list has none (AD-5).
 *
 * The pairing is the child's own declaration rather than a route convention: the child declares
 * the list's route as its `parentScope`. The same three halves as `editorScreenFor` hold -- built,
 * unlisted and keyed by an id -- because the child is reached from the name cell with the row's id
 * and never from a navigation surface. The Wallet list's Secrets list is the first.
 *
 * **Skips a `detail`-class screen** (Story 6.7): `detailScreenFor` is the pairing for one, so a
 * parent naming both a per-row detail screen and a sub-resource list -- Task schedule's Task
 * details and its per-task History both declare `parentScope` `tasks/schedule` -- resolves each
 * through its own function rather than this one picking whichever sorts first.
 */
export function childListFor(screen: ScreenDeclaration): ScreenDeclaration | null {
  if (screen.route === '') return null;
  return (
    SCREENS.find(
      (child) =>
        child.parentScope === screen.route &&
        child.built &&
        !isListedScreen(child) &&
        hasIdRoute(child) &&
        child.archetype !== 'detail'
    ) ?? null
  );
}

/**
 * The built, unlisted, id-keyed `detail`-archetype screen a list's rows open, or `null` when the
 * list has none (Story 6.7). The same pairing `childListFor` is, narrowed to the one archetype a
 * per-row detail screen takes: no `tab`, since a tabbed screen's own group is a different pairing
 * (`tabGroupFor`), and one entity is a field list rather than a table of rows.
 */
export function detailScreenFor(screen: ScreenDeclaration): ScreenDeclaration | null {
  if (screen.route === '') return null;
  return (
    SCREENS.find(
      (child) =>
        child.parentScope === screen.route &&
        child.built &&
        !isListedScreen(child) &&
        hasIdRoute(child) &&
        child.archetype === 'detail' &&
        child.tab === null
    ) ?? null
  );
}

/**
 * The list `screen` is the sub-resource list or per-row detail screen of (`childListFor`'s and
 * `detailScreenFor`'s shared inverse), or `null`.
 */
export function parentListFor(screen: ScreenDeclaration): ScreenDeclaration | null {
  if (screen.parentScope === '') return null;
  const parent = screenForRoute(screen.parentScope);
  if (parent === null) return null;
  if (childListFor(parent)?.route === screen.route) return parent;
  if (detailScreenFor(parent)?.route === screen.route) return parent;
  return null;
}

/**
 * The built tabs of the tab group `screen` is one tab of, in position order, or `[]` for a screen
 * that is no tab (AD-5).
 *
 * A tabbed screen is one descriptor per tab, grouped by a declared `tab`, so the strip is read off
 * the mirror rather than typed out: every built screen whose `tab.group` is this screen's group.
 */
export function tabMembersFor(screen: ScreenDeclaration): readonly ScreenDeclaration[] {
  const group = screen.tab?.group;
  if (group === undefined) return [];
  return SCREENS.filter((member) => member.built && member.tab?.group === group).sort(
    (a, b) => (a.tab?.position ?? 0) - (b.tab?.position ?? 0)
  );
}

/**
 * The first tab of the group `screen` is one tab of -- the built screen at the group's route that
 * declares that group -- or `null` for a screen that is no tab (AD-5). The side bar lists this one
 * member, and the locator names it for every tab.
 */
export function tabGroupFor(screen: ScreenDeclaration): ScreenDeclaration | null {
  const group = screen.tab?.group;
  if (group === undefined) return null;
  const head = screenForRoute(group);
  return head !== null && head.built && head.tab?.group === group ? head : null;
}

/**
 * The criteria a parent-scoped list's read carries, from the router URL it renders at: its one
 * declared criterion set to the URL's id segment, decoded (AD-13), or `{}` for a screen that
 * declares no parent, does not declare exactly one criterion, or is rendered with no id.
 *
 * The id arrives as the router serialises it -- percent-encoded as the address bar carries it -- so
 * the segment is decoded once for the router's own pass and once by `decodeEntityId`, which is the
 * encode-twice, decode-once contract read off a URL rather than off a route parameter.
 */
export function parentCriteria(screen: ScreenDeclaration, url: string): Readonly<Record<string, string>> {
  const fields = screen.read?.criteria?.fields ?? [];
  if (screen.parentScope === '' || fields.length !== 1) return {};
  const path = routeFromUrl(url);
  const prefix = `${screen.route}/`;
  if (!path.startsWith(prefix)) return {};
  const segment = path.slice(prefix.length);
  if (segment === '' || segment.includes('/')) return {};
  const id = decodeEntityId(decodeEntityId(segment));
  return id === '' ? {} : { [fields[0].param]: id };
}

/**
 * The id a screen's **own** route segment carries, decoded (AD-13), or `''` when the URL is the
 * screen's bare route, when the screen takes no id route, or when what follows the route is not
 * one segment.
 *
 * The companion to `parentCriteria`, which reads a **parent's** id into a sub-resource's one
 * criterion: this reads the screen's own id, which is what a list selects a row by. One helper
 * serves both callers that produce such a URL -- the agent's `shell.screen.open` with an
 * `entityId`, and a change toast's "Open in <screen>" -- so the row is selected on arrival
 * whichever of them moved the browser (DW-1419).
 *
 * **A parent-scoped screen answers `''`.** Its trailing segment is the *parent's* id, which is
 * what `parentCriteria` reads it as, and no row of such a list is keyed by it -- a run of task
 * history is keyed by its run id, not by the task the route names. Reading it here would select
 * whichever row happened to share the parent's key.
 *
 * The segment is decoded twice for the reason `parentCriteria` decodes twice: the router hands
 * over the URL as the address bar carries it, and `encodeEntityId` encodes twice because the web
 * server consumes one decoding in transit.
 */
export function ownIdSegment(screen: ScreenDeclaration, url: string): string {
  if (screen.route === '' || screen.parentScope !== '' || !hasIdRoute(screen)) return '';
  const path = routeFromUrl(url);
  const prefix = `${screen.route}/`;
  if (!path.startsWith(prefix)) return '';
  const segment = path.slice(prefix.length);
  if (segment === '' || segment.includes('/')) return '';
  return decodeEntityId(decodeEntityId(segment));
}

/** The screen declared at `route`, or `null`. Home's route is the empty string. */
export function screenForRoute(route: string): ScreenDeclaration | null {
  return SCREENS.find((screen) => screen.route === route) ?? null;
}

/**
 * The screen declared by `descriptor`, or `null`. The companion to `screenForRoute` for a caller
 * that holds a descriptor's class name rather than its route -- which is the identity AD-5 makes
 * stable, so a screen whose route moves keeps its reference.
 */
export function screenForDescriptor(descriptor: string): ScreenDeclaration | null {
  return SCREENS.find((screen) => screen.descriptor === descriptor) ?? null;
}

/**
 * The built screen whose own primary `entityType` is `type`, or `null` (AD-5, AD-14).
 *
 * The entity-type vocabulary is the kernel's closed enum and a screen selects from it, so this is
 * the one way a caller holding a reference triple -- a proposal's target, a change event -- reaches
 * the declaration that publishes that type's singular noun and its secret argument names. Unbuilt
 * screens are skipped: they declare no surface, so nothing they publish is renderable yet.
 *
 * The first match wins where two screens declare the same primary type (a list and its detail),
 * which is sound because what this is read for -- `entityLabelKey`, `secretArguments` -- is a
 * property of the entity rather than of the surface. `CREATE_ONLY_FORMS` are skipped, because
 * `screenForChange` reads this for the route a change toast opens and such a form opens nothing.
 */
export function screenForEntityType(type: string): ScreenDeclaration | null {
  if (type === '') return null;
  return (
    SCREENS.find((screen) => screen.built && screen.entityType === type && !CREATE_ONLY_FORMS.has(screen.descriptor)) ??
    null
  );
}

/**
 * The screen whose declared `toolIdentifier` owns the tool named `tool`, or `null` (AD-5).
 *
 * A tool's canonical name is `<area>.<screen>.<verb>` and its screen's identifier is the first two
 * segments, which is how `OcuPilot.Screen.Tool.Registry` resolves a tool to its descriptor and how
 * `OcuPilot.Screen.Registry.ConfirmChannelProblem` finds a tool's field list. A tool name is
 * claimed by exactly one source -- the registry refuses a second claimant -- so this answers one
 * screen or none, which `screenForEntityType` cannot: two screens may declare one entity type.
 *
 * **Unbuilt screens are included, and that is the point.** A write tool's declarations -- its
 * screen's singular noun and its secret argument names -- are properties of the operation, not of
 * a rendered surface, and an operation may ship before its screen does
 * (`OcuPilot.Screen.Descriptor.AuditingConfig`). Keying the card's lookup on the entity type
 * instead would answer `null` for such a proposal and silently ask for no secret at all.
 */
export function screenForToolName(tool: string): ScreenDeclaration | null {
  const parts = tool.split('.');
  if (parts.length < 2) return null;
  const identifier = parts.slice(0, 2).join('.');
  return SCREENS.find((screen) => screen.toolIdentifier === identifier) ?? null;
}

/**
 * The two halves of a reference a caller tests a screen against: the entity type and the resolved
 * scope (AD-13). Structural, so a `ChangeEvent` and a toast entry both satisfy it without either
 * module importing the other.
 */
export interface EntityReference {
  readonly type: string;
  readonly scope: string;
}

/**
 * Whether `screen` shows the entity `event` names, in the namespace the shell is scoped to
 * (AD-13, AD-14): the type is the screen's primary or one of its secondaries, and the scope is
 * the one the screen's declared `scope` resolves to.
 *
 * **One predicate, two callers, and that is the point.** `RefreshService` asks it to decide
 * whether to re-fetch and highlight; the toast store asks it to decide whether to raise a toast
 * at all, which is the same question with the opposite answer. Two inline copies would be two
 * answers, and a screen that re-fetched *and* raised a toast -- or did neither -- is exactly the
 * divergence AD-14's last sentence is about.
 */
export function screenShowsEntity(
  screen: ScreenDeclaration,
  event: EntityReference,
  namespace: string
): boolean {
  const types = [screen.entityType, ...screen.secondaryEntityTypes].filter((type) => type !== '');
  if (!types.includes(event.type)) return false;
  return event.scope === scopeFor(screen.scope, namespace);
}

/** The screen a change can be opened in, and the route that opens it with the entity named. */
export interface ChangeTarget {
  readonly screen: ScreenDeclaration;
  readonly route: string;
}

/**
 * The built screen that shows `type`, with the route that opens it on `id`, or `null` when no
 * built screen shows that entity type (AD-5, AD-13).
 *
 * The route is the screen's own plus the entity as one percent-encoded segment, through the one
 * shared encoder -- never a second grammar -- so the locator bar reads the entity the toast
 * named. A screen whose descriptor declares no id route takes the bare route: there is no segment
 * for the entity to occupy, and appending one would be a URL the route table does not hold.
 *
 * `null` is not a fault. It is the "a type no built screen shows" row of this story's matrix: the
 * toast still says what changed, with no action to offer.
 */
export function screenForChange(event: { readonly type: string; readonly id: string }): ChangeTarget | null {
  const screen = screenForEntityType(event.type);
  if (screen === null) return null;
  const route =
    hasIdRoute(screen) && event.id !== '' ? `${screen.route}/${encodeEntityId(event.id)}` : screen.route;
  return { screen, route };
}

/** Whether a screen is keyed by an id, and therefore carries an `/:id` route. */
export function hasIdRoute(screen: ScreenDeclaration): boolean {
  return screen.id.kind !== 'none';
}

/**
 * Home's own area key, as `OcuPilot.Screen.Descriptor.Home` declares it and the generated mirror
 * carries it. Named here so a reader of the shell's own state -- `PanelState`, which learns where
 * it is from `ShellState.activeArea()` -- tests against one constant rather than a literal.
 */
export const HOME_AREA_KEY = 'home';

/**
 * The entity type `screen`'s route id identifies (DW-1020, AD-5, AD-13): the parent screen's own
 * `entityType` for a sub-resource screen, resolved through `parentScope` and never declared a
 * second time -- task history is not a task, and its route id names the task `parentListFor`
 * resolves to, while its rows keep their own `entityType`. A screen with no parent answers its own
 * `entityType`, which is also what a stale or unresolved `parentScope` falls back to, since this
 * function has no refusal of its own to raise (`OcuPilot.Screen.Registry.RouteEntityType`'s
 * server-side twin, and `OcuPilot.Screen.Registry.ParentScopeResolutionProblem` is what keeps the
 * production roster from ever needing that fallback).
 */
export function routeEntityType(screen: ScreenDeclaration): string {
  if (screen.parentScope !== '') {
    const parent = screenForRoute(screen.parentScope);
    if (parent !== null) return parent.entityType;
  }
  return screen.entityType;
}

/** The placeholder the Fixed strings table leaves for an area's own name. */
export const AREA_PLACEHOLDER = '<Area>';

/** The placeholder the Fixed strings table leaves for the privilege a control requires. */
export const RESOURCE_PLACEHOLDER = '<resource>';

/**
 * A canonical string with `<Area>` resolved to one area's name -- the rail item's tooltip and
 * the side bar's landmark both take it. A function rather than a `replace` inside a component,
 * for the reason `formatVersionMismatch` is one: renaming the placeholder on one side only
 * would ship the placeholder to the user, and a source-text pin cannot see that.
 */
export function formatArea(template: string, areaName: string): string {
  return template.split(AREA_PLACEHOLDER).join(areaName);
}

/**
 * `Requires <resource>` resolved to the `(resource, permission)` pair that failed, spelled
 * `resource:permission` -- which is what "a denial names the pair that failed" means at the
 * surface of a gated control.
 */
export function formatRequires(template: string, failedPair: string): string {
  return template.split(RESOURCE_PLACEHOLDER).join(failedPair);
}

/** The placeholder the Fixed strings table leaves for a screen's own title. */
export const SCREEN_PLACEHOLDER = '<screen>';

/**
 * `You need <resource> to open <screen>.` resolved to the failed `resource:permission` pair and
 * the screen's title -- the permission-denied screen's sentence. A function for the reason
 * `formatRequires` is one.
 */
export function formatDeniedScreen(template: string, failedPair: string, screenTitle: string): string {
  return template.split(RESOURCE_PLACEHOLDER).join(failedPair).split(SCREEN_PLACEHOLDER).join(screenTitle);
}

/** The placeholder the Fixed strings table leaves for the action a refusal was about. */
export const ACTION_PLACEHOLDER = '<action>';

/**
 * `You need <resource> to <action>.` resolved to the failed `resource:permission` pair and the
 * action the refused request was -- the inline request-refused sentence a 403 carrying a pair
 * renders (AD-8). A function for the reason `formatRequires` is one; the caller supplies the
 * action as a published string, never as prose of its own.
 */
export function formatDeniedAction(template: string, failedPair: string, action: string): string {
  return template.split(RESOURCE_PLACEHOLDER).join(failedPair).split(ACTION_PLACEHOLDER).join(action);
}

/** The placeholder the Fixed strings table leaves for the entity a navigation opened. */
export const ENTITY_PLACEHOLDER = '<entity>';

/**
 * The agent's navigation announcement -- EXPERIENCE.md's Fixed strings row for
 * "I'm opening <screen> for <entity> -- use Back to return." -- resolved to the target screen's
 * title and, when a row was selected, its entity id -- both model-supplied and therefore
 * untrusted (AD-33): the caller renders the result as `textContent`, never as markup. An empty
 * `entityId` selects the no-entity form, the same words minus the clause with nothing to fill.
 */
export function formatNavigationAnnouncement(
  entityTemplate: string,
  noEntityTemplate: string,
  screenTitle: string,
  entityId: string
): string {
  if (entityId === '') return noEntityTemplate.split(SCREEN_PLACEHOLDER).join(screenTitle);
  return entityTemplate.split(SCREEN_PLACEHOLDER).join(screenTitle).split(ENTITY_PLACEHOLDER).join(entityId);
}

/** The placeholder the Fixed strings table leaves for the arrived screen's own title. */
export const TITLE_PLACEHOLDER = '<title>';

/**
 * The arrival heading announcement -- EXPERIENCE.md's Fixed strings row for
 * "<title> -- opened by the agent; Back returns" -- resolved to the arrived screen's own title.
 * `locator-bar.ts`'s `#ocu-locator-screen` takes it as its `aria-label` once per arrival.
 */
export function formatNavigationHeading(template: string, screenTitle: string): string {
  return template.split(TITLE_PLACEHOLDER).join(screenTitle);
}

/** The one query parameter that is data scope rather than screen state (AD-44). */
export const NAMESPACE_PARAM = 'ns';

/**
 * A target URL for `route` carrying the namespace `currentUrl` is scoped to (AD-44,
 * **DW-134**).
 *
 * `?ns=` is data scope, not decoration: it selects the namespace every read and write on the
 * screen executes against, so dropping it on a rail, side-bar, locator or command-box click
 * would silently move the user's work to another namespace. Navigating with a bare
 * `'/' + route` is exactly that drop, which is why the join lives here rather than being
 * spelled at each call site.
 *
 * **Only `ns` travels.** Every other parameter is the leaving screen's own state -- a page, a
 * filter, a sort -- and applying it to an unrelated screen would be a different bug from the
 * one this fixes. The fragment is not carried either: it addresses a position inside the
 * screen being left.
 */
export function withQuery(route: string, currentUrl: string): string {
  const cut = currentUrl.indexOf('?');
  if (cut < 0) return '/' + route;
  const namespace = new URLSearchParams(currentUrl.slice(cut + 1).split('#')[0]).get(
    NAMESPACE_PARAM
  );
  if (namespace === null) return '/' + route;
  return '/' + route + '?' + NAMESPACE_PARAM + '=' + encodeURIComponent(namespace);
}

/** The declared route a router URL names: no leading slash, no query, no fragment. */
export function routeFromUrl(url: string): string {
  const path = url.split('?')[0].split('#')[0];
  return path.replace(/^\/+/, '').replace(/\/+$/, '');
}

/**
 * The screen a router URL resolves to, or `null`.
 *
 * A detail route carries the entity id as its last segment (AD-13: one segment, always), so a
 * URL that matches no declared route is tried once more without it. Nothing deeper is
 * attempted: an id is one segment by construction, so a second cut would only ever match a
 * shorter screen's route by accident.
 *
 * **Only built screens resolve.** An unbuilt screen is declared but has no route in the table
 * and no page behind it, so a URL naming one is a URL the client cannot render: it must reach
 * the not-found screen, not a screen that resolves and then draws nothing.
 */
export function screenForUrl(url: string): ScreenDeclaration | null {
  const path = routeFromUrl(url);
  const built = (screen: ScreenDeclaration | null): ScreenDeclaration | null =>
    screen !== null && screen.built ? screen : null;
  const exact = built(screenForRoute(path));
  if (exact !== null) return exact;
  const cut = path.lastIndexOf('/');
  if (cut < 0) return null;
  const parent = built(screenForRoute(path.slice(0, cut)));
  return parent !== null && hasIdRoute(parent) ? parent : null;
}

/** The area a router URL belongs to, or `''` when it names no declared screen. */
export function areaForUrl(url: string): string {
  return screenForUrl(url)?.area ?? '';
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function verdictFrom(entry: { allowed?: unknown; failedPair?: unknown }): Verdict {
  return { allowed: entry.allowed === true, failedPair: asString(entry.failedPair) };
}

export class NavigationService {
  private readonly api: ApiService;
  private readonly connectivity: ConnectivityService | null;
  private readonly namespace: () => string;

  private areaVerdicts = new Map<string, Verdict>();
  private screenVerdicts = new Map<string, Verdict>();
  private loadedOnce = false;
  private answeredOnce = false;

  /**
   * The map read, on the shared primitive (**DW-157**). Join on an unchanged namespace,
   * mark-dirty-and-re-run-once on a changed one; the slot is filled before the fetch starts, which
   * is what the DW-9 stub's own refusal depends on.
   */
  private readonly flight = createSingleFlight(
    (key) => this.runLoad(key),
    () => this.namespace()
  );

  /**
   * Bumped by `reset()`, read by `runLoad()` across its await. A map requested by one principal
   * must never be installed after another has taken the tab: the answer is about whoever asked
   * (AD-8). `InstanceService` carries the same counter for the same reason.
   */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: NavigationOptions) {
    this.api = options.api;
    this.connectivity = options.connectivity ?? null;
    this.namespace = options.namespace ?? (() => '');
  }

  /** Whether a map has been received at all. Nothing is gated until it has. */
  loaded(): boolean {
    return this.loadedOnce;
  }

  /**
   * Whether a map read has completed for this principal, with a map or with a failure. A screen's
   * page is not mounted before it has (`ScreenOutlet`), so a screen the map is about to refuse
   * issues no read of its own. A failed read counts as completed: every verdict then stays
   * `UNGATED` and the page mounts, because the server is the gate (AD-8).
   */
  answered(): boolean {
    return this.answeredOnce;
  }

  /**
   * The areas the rail renders, and the screens an area's side bar lists.
   *
   * They delegate to the mirror and add nothing -- they exist on the service so a component
   * test can hand the rail and the side bar a roster the shipped mirror does not carry. At the
   * end of Epic 1 that mirror holds one screen, Home, whose area has no side bar, so without
   * this seam the side bar's own listing rules would have nothing to render and nothing to
   * assert. Production never overrides them.
   */
  areas(): readonly AreaDeclaration[] {
    return orderedAreas();
  }

  /**
   * The screens an area's side bar, command box, tile caption, locator segment and rail landing
   * offer: its **listed** ones (`listedScreensForArea`), which is what this seam has always meant
   * and what its own comment above says. A screen declaring `sideBarPosition` 0 is routable and
   * unlisted, so it is absent here and present in `builtScreens()`.
   */
  screensForArea(areaKey: string): readonly ScreenDeclaration[] {
    return listedScreensForArea(areaKey);
  }

  /**
   * Every built screen, and the screen a router URL resolves to. Seams for the same reason
   * `areas()` is one: the command box lists every screen the user may open and the command
   * bar reads the current screen's declared actions, and no screen in the shipped mirror
   * declares an action, so neither rule would have a subject in a component test.
   * Production never overrides them.
   */
  builtScreens(): readonly ScreenDeclaration[] {
    return builtScreens();
  }

  screenForUrl(url: string): ScreenDeclaration | null {
    return screenForUrl(url);
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** The verdict for an area's rail item and tile. */
  areaVerdict(key: string): Verdict {
    return this.areaVerdicts.get(key) ?? UNGATED;
  }

  /** The verdict for one screen, by its declared route. */
  screenVerdict(route: string): Verdict {
    return this.screenVerdicts.get(route) ?? UNGATED;
  }

  /**
   * Fetch the map. One request however many callers in the same namespace, for the reason
   * `Session.refresh()` is single-flight: the rail, the side bar and the routed screen all want
   * it as the shell paints.
   *
   * A caller arriving after the namespace has moved is a different question, not a repeat of
   * this one, and `createSingleFlight` answers it with one re-run rather than a join
   * (**DW-157**).
   */
  load(): Promise<void> {
    return this.flight.request();
  }

  /**
   * A call was refused: re-read the map, because the privileges it was computed from may have
   * moved.
   *
   * It carries no guard of its own. `createSingleFlight` fills its slot **before** the fetch
   * starts, so a refusal reported by the navigation call itself -- a caller holding no
   * administrative resource at all, whose every request is a 403 -- finds that slot filled, and
   * finds the namespace unchanged, so it joins rather than queueing. A second guard here would be
   * a second copy of that rule, and nothing could tell it from a correct one.
   */
  noteForbidden(): void {
    this.reload();
  }

  /**
   * Read the map again, because something it was computed against has moved -- a refusal above,
   * or the namespace every call is now scoped to (AD-44). The same single-flight `load()`, named
   * for the general case so a caller that is not reacting to a 403 does not have to call one.
   *
   * **What it does about a read already in flight depends on the namespace, and only on that.**
   * The same namespace joins, which is what keeps the shell from issuing a map read per router
   * event while one is outstanding. A namespace that has moved marks the flight and re-runs once
   * against the new one, because the verdict a read started under the old namespace installs is
   * an answer to a question nobody is asking any more (**DW-157**).
   */
  reload(): void {
    void this.load();
  }

  /**
   * Forget the map, so the next `load()` asks again. The verdicts are about **this user**
   * (AD-8), and sign-out clears the tab in place without a reload, so a second principal
   * signing in must not inherit the first one's gating.
   */
  reset(): void {
    this.generation += 1;
    this.areaVerdicts = new Map();
    this.screenVerdicts = new Map();
    this.loadedOnce = false;
    this.answeredOnce = false;
    this.flight.reset();
    this.notify();
  }

  /**
   * `key` is the namespace the flight was issued against, and it is sent as this call's own scope
   * rather than left to `ApiService`'s live source. The two agree in production -- nothing can
   * change the namespace between `keyOf()` and this line, both being synchronous -- and pinning it
   * is what makes "the re-run carries the new namespace" a property of the request rather than of
   * a service the request happens to consult.
   *
   * An empty key is a service with no namespace source configured, not a namespace of `''`: it
   * sends no scope of its own and `ApiService` attaches whatever the shell is scoped to, which is
   * what this read did before it was keyed.
   */
  private async runLoad(key: string): Promise<void> {
    const generation = this.generation;
    const result = await this.api.requestJson<NavigationWire>(
      NAVIGATION_PATH,
      key === '' ? {} : { scope: key }
    );
    // Asked for by a principal who has since left the tab: discard it rather than reinstate
    // their gating over the one who replaced them. Checked **before** the failure branch, and
    // for the same reason the success branch checks it: a failed read belonging to a departed
    // principal must not park a re-run either. `scope.ts` orders the two the same way.
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') {
      if (!this.answeredOnce) {
        this.answeredOnce = true;
        this.notify();
      }
      // **DW-135: fail open, but never silently.** Every verdict stays `UNGATED`, because AD-8
      // makes the server the gate and closing the client over an unanswered question would lock
      // a user out of screens they hold. What was missing was the other half: an unreachable
      // instance left the rail fully open and said nothing, so it read as an instance the user
      // has no rights on. The failure is now published -- `ApiService` has already classified
      // it -- and the read is parked for one re-run when the instance answers again.
      this.connectivity?.retryWhenReachable(NAVIGATION_PATH, () => this.reload());
      return;
    }
    const body = result.body ?? {};
    const areas = Array.isArray(body.areas) ? body.areas : [];

    const nextAreas = new Map<string, Verdict>();
    const nextScreens = new Map<string, Verdict>();
    for (const raw of areas) {
      if (typeof raw !== 'object' || raw === null) continue;
      const area = raw as AreaVerdictWire;
      const key = asString(area.key);
      if (key !== '') nextAreas.set(key, verdictFrom(area));
      const screens = Array.isArray(area.screens) ? area.screens : [];
      for (const rawScreen of screens) {
        if (typeof rawScreen !== 'object' || rawScreen === null) continue;
        const screen = rawScreen as ScreenVerdictWire;
        // Guarded the way the area key above is. Home's route legitimately IS '', so an entry
        // that carries no route at all would otherwise take Home's slot and gate Home.
        if (typeof screen.route !== 'string') continue;
        nextScreens.set(screen.route, verdictFrom(screen));
      }
    }

    this.areaVerdicts = nextAreas;
    this.screenVerdicts = nextScreens;
    this.loadedOnce = true;
    this.answeredOnce = true;
    this.notify();
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}

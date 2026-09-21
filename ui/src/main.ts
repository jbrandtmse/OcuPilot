import { provideZonelessChangeDetection } from '@angular/core';
import { bootstrapApplication } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';

import { App } from './app/app';
import { routes } from './app/app.routes';
import { About } from './app/core/about';
import { AccountPreferences } from './app/core/account-preferences';
import { AgentContext } from './app/core/agent-context';
import { AgentStatus } from './app/core/agent-status';
import { ApiService } from './app/core/api';
import { ChangeBus } from './app/core/change-bus';
import { ConnectivityService } from './app/core/connectivity';
import { FormDirty } from './app/core/form-dirty';
import { HelpLinks } from './app/core/help';
import { transportFault } from './app/core/fault';
import { InstanceService } from './app/core/instance';
import { NavigationService } from './app/core/navigation';
import { OverlayStack } from './app/core/overlay-stack';
import { PanelState } from './app/core/panel-layout';
import { RefreshService } from './app/core/refresh';
import { ScopeService, onScopeChange } from './app/core/scope';
import { ScreenActions } from './app/core/screen-actions';
import { ScreenStores } from './app/core/screen-store';
import { Session } from './app/core/session';
import { ShellState } from './app/core/shell-state';
import { SuggestedView } from './app/core/suggested-view';
import { SystemInfo } from './app/core/system-info';
import { TokenStore, readNavigationKind, readSessionStorage } from './app/core/token-store';
import { TurnStore } from './app/core/turn';
import { ViewOptions } from './app/core/view-options';

// Zoneless, standalone bootstrap (AD-19), with the transport layer constructed over the
// real browser and provided as values.
//
// `provideHttpClient` is deliberately absent. The core modules use `fetch` directly, which
// is what keeps them importable by `node --test`. The component suite (`ng test`, Story 1.9,
// DW-93) renders the shell components against these same classes provided as values, so the
// two test hosts exercise one set of objects rather than two.
//
// The silent probe starts here rather than in a component, so the request is already in
// flight while Angular is still painting the shell: on a browser that is signed in to the
// classic portal, the skeleton is often gone before it has been seen.
//
// `readSessionStorage()` rather than `sessionStorage`: in a browser with site data blocked
// the property access itself throws, and at module scope that would abort the bootstrap
// before anything painted. The store's own try/catch cannot help -- it never gets the
// object. A sign-in screen that cannot remember is better than one that cannot render.
const tokens = new TokenStore({
  storage: readSessionStorage(),
  navigationType: readNavigationKind,
});

// The connectivity verdict and its probe (Story 1.13). Built BEFORE the API service and the
// session, because both report to it; it reaches back through `api: () => api`, an arrow that
// is called only when a probe is actually issued, long after every binding here is initialised.
// That is the same mutual-dependency shape `onForbidden` and `scope` already use below.
const connectivity = new ConnectivityService({ api: () => api });

const session = new Session({
  fetch: (path, init) => fetch(path, init),
  tokens,
  // DW-104. The three token endpoints are posted with `fetch` directly, so they never reach
  // `requestJson`'s classifier -- and a cold start against an unreachable instance makes
  // exactly one request, this one. Reporting it here is what puts the banner over the sign-in
  // card, and parking the re-send is what makes Retry (and the probe's own recovery) send again
  // what the user typed. A tab with nothing unanswered ignores the second half.
  //
  // `survivesReset` is load-bearing, not decoration: `formLogin` settles on `form`, which
  // notifies `App`, which calls `connectivity.reset()` for every not-signed-in state -- so an
  // ordinary park registered here was deleted in the same turn it was made, and nothing was
  // ever re-sent. This park belongs to the sign-in attempt, not to a signed-in principal.
  onUnreachable: (path) => {
    connectivity.note(transportFault(path));
    connectivity.retryWhenReachable(
      path,
      () => {
        void session.retrySubmit();
      },
      true
    );
  },
});

// `onForbidden`, `onFault` and `scope` all reach services constructed around this one --
// deliberately. No arrow is called during construction, only on a 403, an answered call or a
// request that arrives later, by which time the bindings are initialised. Writing them the
// other way round is impossible: those services need the API service to fetch what they hold.
const api: ApiService = new ApiService({
  fetch: (path, init) => fetch(path, init),
  tokens,
  session,
  onForbidden: () => navigation.noteForbidden(),
  onFault: (fault) => connectivity.note(fault),
  scope: () => scope.namespace(),
});

// The instance check, the navigation map and the namespace list are not started here: all three
// need a Bearer, and there is none until the probe above has settled. `App` and the namespace
// switch make the calls once the session reaches `signed-in`.
//
// All three take the connectivity service as well, and for one reason: each has a branch where
// its read failed and nothing was scheduled to ask again (DW-119, DW-135). The re-ask is parked
// there, and the probe's next response is what runs it -- once per reader, not once per tick.
const instance = new InstanceService({ api, connectivity });
// `namespace` is the map read's single-flight key (DW-157): a read already in flight answers a
// second caller in the same namespace and answers nobody after a switch. Lazy for the reason
// `api: () => api` above is -- `scope` is declared two lines down and the arrow is not called
// until a map read is actually issued.
const navigation = new NavigationService({
  api,
  connectivity,
  namespace: () => scope.namespace(),
});
const scope: ScopeService = new ScopeService({ api, connectivity });

// AD-44's "switching re-fetches rather than re-routing", wired once: the scope's consumer in
// this story is the navigation map, which is computed per call and must be re-read against the
// namespace the shell is now scoped to. `onScopeChange` fires only when the RESOLVED scope
// moves, so a route event that changes nothing costs no request.
//
// The `loaded()` guard is for the one move that is not a switch: sign-out resets the scope, which
// drops the resolved namespace to `''` and would otherwise wake the map read that the same
// sign-out has just dropped (AD-8).
// The refresh framework is this channel's second subscriber, as `scope.ts` says it is: a bound
// screen's rows and its `Last update` stamp are answers about the namespace the shell has left,
// and the switch re-fetches them rather than re-routing. It is declared below this line and read
// only when the handler fires.
onScopeChange(scope, () => {
  if (!scope.loaded()) return;
  navigation.reload();
  refresh.noteScopeChanged();
});

// Everything this user's account remembers (Stories 15.2 and 15.5, AD-50): favorites, recent
// items, each screen's table view and refresh rate, and the two pieces of shell chrome the user
// can move. Built here, before the three stores that read it, so the locator bar's toggle, Home's
// blocks, the command box's ranking, the side bar and the panel all read one answer -- and so that
// nothing of it is in browser storage (AD-28, AD-47).
const accountPreferences = new AccountPreferences({ api });
const shell = new ShellState({ account: accountPreferences });

// The row's width budget and the panel's own state (Story 4.3): the remembered width, the draft,
// full screen and the yield order, over the same account store and the same shell. `App` feeds it
// the viewport width; the side bar, the rail and the panel read the layout it resolves.
const panel = new PanelState({ account: accountPreferences, shell });

// The turn store (Story 4.5): send, poll, stop, restore and New conversation, over the same API
// service and the same per-tab `sessionStorage` the token pair uses (a second, independent read
// of it for the conversation id's own key). `restore()` is fired here, not awaited -- the same
// "already in flight while Angular is still painting" shape the silent probe above uses -- so a
// reload's transcript is often there by the time the panel first renders.
const turn = new TurnStore({
  api,
  storage: readSessionStorage(),
  navigationType: readNavigationKind,
});
void turn.restore();

// Story 1.14's three (AD-43, AD-19, AD-14): the one client bus, the one store per descriptor, and
// the one refresh framework over both. Built here like every other core service so the command
// bar's chip, the status bar's stamp and whatever screen binds all reach the same instance --
// three of any of them would be three timers.
const bus = new ChangeBus();
const screenStores = new ScreenStores({ account: accountPreferences });
const refresh = new RefreshService({
  stores: screenStores,
  connectivity,
  bus,
  namespace: () => scope.namespace(),
});

// Whether this instance holds an enabled agent definition (Story 3.6). Built here so the panel,
// the rail's dot and the Definition form all read one answer, and given the bus so an Enable on
// the Definitions list re-reads it once rather than once per consumer (AD-14).
const agentStatus = new AgentStatus({ api, bus, connectivity });

// Home's suggested view (Story 4.10): the attention lines above the transcript and the starter
// prompts that stand in for them. Built here beside `agentStatus` and over the same `api`, `scope`
// and `connectivity`, so its agent-status line is the same verdict the panel's banners render and
// its application-errors read is scoped to the namespace every other call carries.
const suggested = new SuggestedView({ api, agentStatus, scope, connectivity });

// The context chip's one source (Story 4.11): the caller's sharing choice, the resolved row cap,
// and where a turn's provider call goes. Built here beside `agentStatus` for the same reason --
// the chip and the Send path both read one answer, and the bus is what keeps a changed row cap
// or default definition from going stale.
const agentContext = new AgentContext({ api, bus, connectivity });

// The instance overview (Story 15.3): the About dialog and Home's links panel both read it, so one
// store means one request and one answer rather than two that can disagree about where this
// instance's documentation is. Alongside it, the per-screen help addresses the locator bar
// resolves -- held per screen, so a screen visited twice is asked for once.
const about = new About({ api });
const helpLinks = new HelpLinks({ api });

// Home's System Information panel (Story 15.4). Built here like every other core service, and
// scoped like every other call: its production member is per namespace, so it rides the shell's
// own `?ns=` rather than naming one of its own (AD-44). It runs no timer -- Home is not on AD-43's
// auto-refresh roster.
const systemInfo = new SystemInfo({ api });

// The one authority over Escape (DW-137). Built here like every other core service so the
// command box, the account menu and the side bar all register with the same instance --
// three stacks would be three independent Escape handlers again.
const overlays = new OverlayStack();

// The handlers that run a screen's declared actions. One instance, so a handler a screen
// registers is the one the command bar and the command box both see.
const screenActions = new ScreenActions();

// The command bar's View control (Story 6.11). One instance, so the binding a page registers is
// the one the command bar reads.
const viewOptions = new ViewOptions();

// The open form's unsaved-changes state (Story 3.5). One instance, because the route guard on
// every `form-page` route and the form that answers it have to be asking and answering the same
// question -- two would let a guard refuse a navigation nothing on screen could resolve.
const formDirty = new FormDirty();

session.start();

bootstrapApplication(App, {
  providers: [
    provideZonelessChangeDetection(),
    provideRouter(routes),
    { provide: TokenStore, useValue: tokens },
    { provide: Session, useValue: session },
    { provide: ApiService, useValue: api },
    { provide: ConnectivityService, useValue: connectivity },
    { provide: InstanceService, useValue: instance },
    { provide: NavigationService, useValue: navigation },
    { provide: ScopeService, useValue: scope },
    { provide: ShellState, useValue: shell },
    { provide: PanelState, useValue: panel },
    { provide: TurnStore, useValue: turn },
    { provide: OverlayStack, useValue: overlays },
    { provide: ChangeBus, useValue: bus },
    { provide: ScreenStores, useValue: screenStores },
    { provide: RefreshService, useValue: refresh },
    { provide: ScreenActions, useValue: screenActions },
    { provide: ViewOptions, useValue: viewOptions },
    { provide: FormDirty, useValue: formDirty },
    { provide: AgentStatus, useValue: agentStatus },
    { provide: AgentContext, useValue: agentContext },
    { provide: AccountPreferences, useValue: accountPreferences },
    { provide: About, useValue: about },
    { provide: HelpLinks, useValue: helpLinks },
    { provide: SystemInfo, useValue: systemInfo },
    { provide: SuggestedView, useValue: suggested },
  ],
}).catch((err) => console.error(err));

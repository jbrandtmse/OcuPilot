/// <p>The single HTTP entry point for the OcuPilot REST API. Stateless (no CSP session),
/// JSON-first.</p>
/// <p>The <code>UrlMap</code> below holds the five agent-switch routes under
/// <code>/agent/switches</code> and <code>/agent/restraint</code>, the eight agent-definition
/// routes under <code>/agent/definitions</code>, the provider catalog the Definition form cascades
/// from, the generic screen read, <code>GET /screens/:screen/read</code>, the four
/// application-error-log levels <code>GET /logs/errors/{namespaces,dates,list,detail}</code>, the
/// console-log page <code>GET /logs/messages</code>, the three turn routes under
/// <code>/turn</code>, and the three shell routes, <code>GET /instance</code>,
/// <code>GET /namespaces</code> and <code>GET /navigation</code>; every other request that clears
/// <method>OnPreDispatch</method> is answered by the framework 404 override. The three
/// ordering invariants below are load-bearing from the first route on; the first two are each
/// asserted by their own routing test in <class>OcuPilot.Test.Routing</class> against
/// <class>OcuPilot.Test.RouterFixture</class>, which inherits this class's real
/// <method>OnPreDispatch</method>, <method>ReportHttpStatusCode</method> and
/// <method>Http405</method> unchanged.</p>
Class OcuPilot.Api.Router Extends %CSP.REST
{

/// <p>Stateless REST: no CSP session per request.</p>
Parameter UseSession = 0;

/// <p>Every OcuPilot response is JSON.</p>
Parameter CONTENTTYPE = "application/json";

/// <p>CORS processing is off unconditionally (AD-47). Left unspecified — the inherited
/// <code>%CSP.REST</code> default — the decision is delegated to a route's own
/// <code>Cors</code> attribute, so "no CORS allowance exists" would be a property of the
/// route table rather than of this class. <code>0</code> is the falsifiable form: no route
/// added later can opt back in without changing this line.</p>
/// <p>Same-origin is the design in development as well as production: the dev loop proxies
/// through the IRIS origin (<file>ui/proxy.conf.json</file>), so no allowance has to exist
/// for <code>ng serve</code> either.</p>
Parameter HandleCorsRequest = 0;

/// <p>The closed list of IRIS administrative resources <method>HoldsAdminResource</method>
/// tests, comma-separated. Holding <b>any one</b> of them at <code>USE</code> is what the
/// FR-65 gate requires of a caller; holding none of them is a 403, whatever else the caller
/// holds.</p>
/// <p>Read from the instance on 2026-09-11 (<code>Security.Resources:List</code> over
/// <code>%Admin*</code>) -- all thirteen it defines. A closed list, not a wildcard scan:
/// what OcuPilot admits must not silently widen because a later IRIS release adds a
/// resource, and a list is what a reviewer can check.</p>
Parameter ADMINRESOURCES = "%Admin_ExternalLanguageServerEdit,%Admin_FileSystemAccess,%Admin_Journal,%Admin_Manage,%Admin_OAuth2_Client,%Admin_OAuth2_Registration,%Admin_OAuth2_Server,%Admin_Operate,%Admin_RoleEdit,%Admin_Secure,%Admin_Task,%Admin_UserEdit,%Admin_Wallet";

/// <p><code>%CSP.REST</code> tries routes in file order and dispatches to the first one
/// whose URL pattern and HTTP method both match. A <code>:param</code> segment becomes the capture
/// group <code>([^/]+)</code> (<code>%CSP.REST.GetRegexForUrl</code>) and the match must be whole,
/// so a parameter never spans a <code>/</code>; what an earlier route can still swallow is a later
/// route of the same length, such as a literal sibling of a <code>:param</code>. Three ordering
/// invariants therefore apply to every route added to this map (Consistency Conventions: REST
/// route ordering), all checked over every <code>UrlMap</code> by
/// <file>scripts/check-objectscript.py</file>. The first two are also demonstrated behaviourally
/// against <class>OcuPilot.Test.RouterFixture</class>'s own routes; the third cannot be observed by
/// routing, because a <code>:param</code> never spans a <code>/</code>, so the checker is what
/// enforces it:</p>
/// <ol>
/// <li>Explicit method-guard (405) routes before the catch-all for the same path.</li>
/// <li>Sub-resource routes before single-segment <code>:param</code> routes.</li>
/// <li>N-segment routes before (N-1)-segment routes.</li>
/// </ol>
/// <p><code>Call=</code> targets are thin wrappers with no business logic — dispatch to a
/// slice's own handler class.</p>
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/agent/switches/holds/:id" Method="DELETE" Call="AgentSwitchHoldDelete"/>
  <Route Url="/agent/switches/holds" Method="POST" Call="AgentSwitchHoldCreate"/>
  <Route Url="/agent/switches" Method="GET" Call="AgentSwitchesRead"/>
  <Route Url="/agent/switches" Method="PUT" Call="AgentSwitchesUpdate"/>
  <Route Url="/agent/restraint" Method="GET" Call="AgentRestraint"/>
  <Route Url="/agent/context" Method="GET" Call="AgentContextRead"/>
  <Route Url="/agent/context" Method="PUT" Call="AgentContextUpdate"/>
  <Route Url="/agent/definitions/:id/default" Method="POST" Call="AgentDefinitionSetDefault"/>
  <Route Url="/agent/definitions/:id/credential" Method="POST" Call="AgentDefinitionStoreCredential"/>
  <Route Url="/agent/definitions/:id/test" Method="POST" Call="AgentDefinitionTest"/>
  <Route Url="/agent/definitions/:id" Method="GET" Call="AgentDefinitionRead"/>
  <Route Url="/agent/definitions/:id" Method="PUT" Call="AgentDefinitionUpdate"/>
  <Route Url="/agent/definitions/:id" Method="DELETE" Call="AgentDefinitionDelete"/>
  <Route Url="/agent/definitions" Method="GET" Call="AgentDefinitionList"/>
  <Route Url="/agent/definitions" Method="POST" Call="AgentDefinitionCreate"/>
  <Route Url="/agent/providers" Method="GET" Call="AgentProviders"/>
  <Route Url="/screens/:screen/read" Method="GET" Call="ScreenRead"/>
  <Route Url="/logs/errors/namespaces" Method="GET" Call="LogErrorNamespaces"/>
  <Route Url="/logs/errors/dates" Method="GET" Call="LogErrorDates"/>
  <Route Url="/logs/errors/list" Method="GET" Call="LogErrorList"/>
  <Route Url="/logs/errors/detail" Method="GET" Call="LogErrorDetail"/>
  <Route Url="/logs/messages" Method="GET" Call="LogMessages"/>
  <Route Url="/turn/:id/progress" Method="GET" Call="TurnProgress"/>
  <Route Url="/turn/:id/stop" Method="POST" Call="TurnStop"/>
  <Route Url="/turn/:id/navigation" Method="POST" Call="TurnNavigation"/>
  <Route Url="/turn/abandon" Method="POST" Call="TurnAbandon"/>
  <Route Url="/turn" Method="POST" Call="TurnStart"/>
  <Route Url="/conversation/:id" Method="GET" Call="ConversationRead"/>
  <Route Url="/conversation" Method="POST" Call="ConversationCreate"/>
  <Route Url="/instance" Method="GET" Call="Instance"/>
  <Route Url="/namespaces" Method="GET" Call="Namespaces"/>
  <Route Url="/navigation" Method="GET" Call="Navigation"/>
</Routes>
}

/// <p>Thin <code>Call=</code> target for <code>DELETE /agent/switches/holds/:id</code>: delegates to
/// <class>OcuPilot.Api.Switches</class> and carries no logic of its own.</p>
/// <p>The five switch routes are declared <b>first</b> in the map above, longest first, and the
/// definition routes follow them the same way. The third ordering invariant is on a shorter route
/// that matches a longer one's leading segments, which is why the two groups may sit side by side:
/// <code>/agent/switches</code> matches no prefix of <code>/agent/definitions/:id/default</code>.</p>
ClassMethod AgentSwitchHoldDelete(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Switches).HandleHoldDelete(pId)
}

/// <p>Thin <code>Call=</code> target for <code>POST /agent/switches/holds</code> -- see
/// <method>AgentSwitchHoldDelete</method>.</p>
ClassMethod AgentSwitchHoldCreate() As %Status
{
    Quit ##class(OcuPilot.Api.Switches).HandleHoldCreate()
}

/// <p>Thin <code>Call=</code> target for <code>GET /agent/switches</code> -- see
/// <method>AgentSwitchHoldDelete</method>.</p>
ClassMethod AgentSwitchesRead() As %Status
{
    Quit ##class(OcuPilot.Api.Switches).HandleRead()
}

/// <p>Thin <code>Call=</code> target for <code>PUT /agent/switches</code> -- see
/// <method>AgentSwitchHoldDelete</method>.</p>
ClassMethod AgentSwitchesUpdate() As %Status
{
    Quit ##class(OcuPilot.Api.Switches).HandleUpdate()
}

/// <p>Thin <code>Call=</code> target for <code>GET /agent/restraint</code> -- see
/// <method>AgentSwitchHoldDelete</method>. The one switch route that gates on nothing beyond this
/// class: it answers the calling user their own verdict, which is what the panel's banners and its
/// footer line are rendered from.</p>
ClassMethod AgentRestraint() As %Status
{
    Quit ##class(OcuPilot.Api.Switches).HandleRestraint()
}

/// <p>Thin <code>Call=</code> target for <code>GET /agent/context</code>: delegates to
/// <class>OcuPilot.Api.Context</class> and carries no logic of its own.</p>
ClassMethod AgentContextRead() As %Status
{
    Quit ##class(OcuPilot.Api.Context).HandleRead()
}

/// <p>Thin <code>Call=</code> target for <code>PUT /agent/context</code> -- see
/// <method>AgentContextRead</method>.</p>
ClassMethod AgentContextUpdate() As %Status
{
    Quit ##class(OcuPilot.Api.Context).HandleUpdate()
}

/// <p>Thin <code>Call=</code> target for <code>POST /agent/definitions/:id/default</code>:
/// delegates to <class>OcuPilot.Api.Definitions</class> and carries no logic of its own.</p>
/// <p>The eight definition routes are declared longest first in the map above, for the third
/// ordering invariant: an N-segment route goes before an (N-1)-segment one.</p>
ClassMethod AgentDefinitionSetDefault(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Definitions).HandleSetDefault(pId)
}

/// <p>Thin <code>Call=</code> target for <code>POST /agent/definitions/:id/credential</code> -- see
/// <method>AgentDefinitionSetDefault</method>. The one route that carries a credential value, and
/// it carries it in one direction only.</p>
ClassMethod AgentDefinitionStoreCredential(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Definitions).HandleStoreCredential(pId)
}

/// <p>Thin <code>Call=</code> target for <code>POST /agent/definitions/:id/test</code> -- see
/// <method>AgentDefinitionSetDefault</method>. The one route that makes an outbound call.</p>
ClassMethod AgentDefinitionTest(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Definitions).HandleTest(pId)
}

/// <p>Thin <code>Call=</code> target for <code>GET /agent/definitions/:id</code> -- see
/// <method>AgentDefinitionSetDefault</method>.</p>
ClassMethod AgentDefinitionRead(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Definitions).HandleRead(pId)
}

/// <p>Thin <code>Call=</code> target for <code>PUT /agent/definitions/:id</code> -- see
/// <method>AgentDefinitionSetDefault</method>.</p>
ClassMethod AgentDefinitionUpdate(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Definitions).HandleUpdate(pId)
}

/// <p>Thin <code>Call=</code> target for <code>DELETE /agent/definitions/:id</code> -- see
/// <method>AgentDefinitionSetDefault</method>.</p>
ClassMethod AgentDefinitionDelete(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Definitions).HandleDelete(pId)
}

/// <p>Thin <code>Call=</code> target for <code>GET /agent/definitions</code> -- see
/// <method>AgentDefinitionSetDefault</method>.</p>
ClassMethod AgentDefinitionList() As %Status
{
    Quit ##class(OcuPilot.Api.Definitions).HandleList()
}

/// <p>Thin <code>Call=</code> target for <code>POST /agent/definitions</code> -- see
/// <method>AgentDefinitionSetDefault</method>.</p>
ClassMethod AgentDefinitionCreate() As %Status
{
    Quit ##class(OcuPilot.Api.Definitions).HandleCreate()
}

/// <p>Thin <code>Call=</code> target for <code>GET /agent/providers</code> -- see
/// <method>AgentDefinitionSetDefault</method>.</p>
ClassMethod AgentProviders() As %Status
{
    Quit ##class(OcuPilot.Api.Definitions).HandleProviders()
}

/// <p>Thin <code>Call=</code> target for <code>GET /screens/:screen/read</code>: delegates to
/// <class>OcuPilot.Api.ScreenRead</class> and carries no logic of its own.</p>
ClassMethod ScreenRead(pScreen As %String) As %Status
{
    Quit ##class(OcuPilot.Api.ScreenRead).Handle(pScreen)
}

/// <p>Thin <code>Call=</code> target for <code>GET /logs/errors/namespaces</code>: delegates to
/// <class>OcuPilot.Api.ErrorLog</class> and carries no logic of its own.</p>
/// <p>The route is literal and <b>binds the drill level here</b>, from the port's own enum, so no
/// caller names a level (AD-21) -- and none of the four reads the request's <code>?ns=</code>: the
/// namespace an application error read acts on travels under this endpoint's own parameter and has
/// exactly one source, the level the user drilled to (AD-48).</p>
ClassMethod LogErrorNamespaces() As %Status
{
    Quit ##class(OcuPilot.Api.ErrorLog).Handle(##class(OcuPilot.Port.LogSourcePort).#LEVELNAMESPACES)
}

/// <p>Thin <code>Call=</code> target for <code>GET /logs/errors/dates</code> -- see
/// <method>LogErrorNamespaces</method>.</p>
ClassMethod LogErrorDates() As %Status
{
    Quit ##class(OcuPilot.Api.ErrorLog).Handle(##class(OcuPilot.Port.LogSourcePort).#LEVELDATES)
}

/// <p>Thin <code>Call=</code> target for <code>GET /logs/errors/list</code> -- see
/// <method>LogErrorNamespaces</method>.</p>
ClassMethod LogErrorList() As %Status
{
    Quit ##class(OcuPilot.Api.ErrorLog).Handle(##class(OcuPilot.Port.LogSourcePort).#LEVELLIST)
}

/// <p>Thin <code>Call=</code> target for <code>GET /logs/errors/detail</code> -- see
/// <method>LogErrorNamespaces</method>. This is the one route the captured variable table is
/// reachable from (AD-48).</p>
ClassMethod LogErrorDetail() As %Status
{
    Quit ##class(OcuPilot.Api.ErrorLog).Handle(##class(OcuPilot.Port.LogSourcePort).#LEVELDETAIL)
}

/// <p>Thin <code>Call=</code> target for <code>GET /logs/messages</code>: delegates to
/// <class>OcuPilot.Api.LogPage</class> and carries no logic of its own.</p>
/// <p>The route is literal and <b>binds the source key here</b>, from the port's own enum, so no
/// caller supplies a file name, a path or any part of one (AD-21).</p>
ClassMethod LogMessages() As %Status
{
    Quit ##class(OcuPilot.Api.LogPage).Handle(##class(OcuPilot.Port.LogSourcePort).#MESSAGESKEY)
}

/// <p>Thin <code>Call=</code> target for <code>GET /turn/:id/progress</code>: delegates to
/// <class>OcuPilot.Api.Turn</class> and carries no logic of its own. The three turn routes are
/// declared longest first, for the third ordering invariant.</p>
ClassMethod TurnProgress(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Turn).HandleProgress(pId)
}

/// <p>Thin <code>Call=</code> target for <code>POST /turn/:id/stop</code> -- see
/// <method>TurnProgress</method>.</p>
ClassMethod TurnStop(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Turn).HandleStop(pId)
}

/// <p>Thin <code>Call=</code> target for <code>POST /turn/:id/navigation</code> (Story 4.7) -- see
/// <method>TurnProgress</method>.</p>
ClassMethod TurnNavigation(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Turn).HandleNavigation(pId)
}

/// <p>Thin <code>Call=</code> target for <code>POST /turn/abandon</code> -- see
/// <method>TurnProgress</method>.</p>
ClassMethod TurnAbandon() As %Status
{
    Quit ##class(OcuPilot.Api.Turn).HandleAbandon()
}

/// <p>Thin <code>Call=</code> target for <code>POST /turn</code> -- see
/// <method>TurnProgress</method>.</p>
ClassMethod TurnStart() As %Status
{
    Quit ##class(OcuPilot.Api.Turn).HandleStart()
}

/// <p>Thin <code>Call=</code> target for <code>GET /conversation/:id</code>: delegates to
/// <class>OcuPilot.Api.Conversation</class> and carries no logic of its own. Declared before
/// <code>POST /conversation</code>, for the third ordering invariant.</p>
ClassMethod ConversationRead(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Conversation).HandleRead(pId)
}

/// <p>Thin <code>Call=</code> target for <code>POST /conversation</code> -- see
/// <method>ConversationRead</method>.</p>
ClassMethod ConversationCreate() As %Status
{
    Quit ##class(OcuPilot.Api.Conversation).HandleCreate()
}

/// <p>Thin <code>Call=</code> target for <code>GET /instance</code>: delegates to
/// <class>OcuPilot.Api.Instance</class> and carries no logic of its own.</p>
ClassMethod Instance() As %Status
{
    Quit ##class(OcuPilot.Api.Instance).Handle()
}

/// <p>Thin <code>Call=</code> target for <code>GET /navigation</code>: delegates to
/// <class>OcuPilot.Api.Navigation</class> and carries no logic of its own.</p>
ClassMethod Navigation() As %Status
{
    Quit ##class(OcuPilot.Api.Navigation).Handle()
}

/// <p>Thin <code>Call=</code> target for <code>GET /namespaces</code>: delegates to
/// <class>OcuPilot.Api.Namespaces</class> and carries no logic of its own.</p>
ClassMethod Namespaces() As %Status
{
    Quit ##class(OcuPilot.Api.Namespaces).Handle()
}

/// <p>Resolves the authenticated caller for this request. Returns <code>$Username</code> —
/// the identity the CSP/web-application login has already established by the time
/// dispatch begins — by default.</p>
/// <p>Overridable so <class>OcuPilot.Test.RouterFixture</class> can inject a fixture
/// identity for <method>OnPreDispatch</method>'s pre-dispatch-denial tests without a real
/// authenticated HTTP session; production code never overrides this.</p>
ClassMethod ResolvedUsername() As %String
{
    Quit $Username
}

/// <p>Resolves the install gate's current status: <code>installed</code> when traffic
/// may proceed, otherwise <code>installing</code>, <code>failed</code>,
/// <code>upgraderequired</code> or <code>unreadable</code> (AD-38). Delegates to
/// <class>OcuPilot.Install.Installer</class>, which owns the version-stamp read and its
/// fail-closed discipline.</p>
/// <p>Overridable so <class>OcuPilot.Test.GateFixture</class> can force each phase
/// through a fixture query parameter without weakening this real dispatch path or the
/// real installer read; production code never overrides this.</p>
ClassMethod GateStatus() As %String
{
    Quit ##class(OcuPilot.Install.Installer).GateStatus()
}

/// <p>Whether the calling process holds at least one of
/// <parameter>ADMINRESOURCES</parameter> at <code>USE</code>, evaluated in that process at
/// the moment of the call and never cached (AD-8). <code>$System.Security.Check</code> is a
/// <code>%SYSTEM</code> call and needs no namespace switch.</p>
/// <p>The list it reads is what <class>OcuPilot.Test.Wire</class> checks against the
/// instance's own resource set, so a name that no longer exists cannot sit in it unnoticed.</p>
ClassMethod HoldsAdminResource() As %Boolean
{
    Set tHolds = 0
    Set tList = ..#ADMINRESOURCES
    For tI = 1:1:$Length(tList, ",") {
        Set tResource = $Piece(tList, ",", tI)
        If (tResource '= "") && ($System.Security.Check(tResource, "USE")) {
            Set tHolds = 1
            Quit
        }
    }
    Quit tHolds
}

/// <p>Whether the calling process may make a request scoped to <var>pNamespace</var>, and the
/// <code>(resource, permission)</code> pair that failed when it may not (AD-8, AD-21).
/// Delegates to <class>OcuPilot.Api.Namespaces</class>, which owns the derivation of a
/// namespace's global-database resource and is the same class that lists what a caller may
/// enter -- so the gate and the list cannot disagree.</p>
/// <p>Overridable so <class>OcuPilot.Test.RouterFixture</class> can drive the denial branch
/// without a second principal: <code>%UnitTest</code> runs as an account holding
/// <code>%All</code>, for which the real check answers yes to every namespace. The real check
/// is exercised over the wire by <class>OcuPilot.Test.Wire</class>. Production never overrides
/// it.</p>
ClassMethod MayEnterNamespace(pNamespace As %String, Output pFailedPair As %String) As %Boolean
{
    Quit ##class(OcuPilot.Api.Namespaces).MayEnter(pNamespace, .pFailedPair)
}

/// <p><var>pNamespace</var> in the spelling the instance itself uses, so one namespace is one
/// scope.</p>
/// <p><method>%SYS.Namespace.Exists</method> answers yes to <code>user</code>,
/// <code>USER</code> and <code>UsEr</code> alike, and an uncanonicalised value would be stashed
/// and echoed verbatim: the roster the shell holds carries <code>USER</code>, so a route
/// spelled any other way reads as a namespace the caller may not enter and its scope is
/// silently replaced. It would also make two reference keys for one entity (AD-13), since the
/// scope half is this value.</p>
/// <p>An explicit namespace name starts with a letter or <code>%</code> and continues with
/// letters, digits, dashes or underscores, and IRIS stores and returns it uppercase whatever
/// case it was input in (System Administration Guide, <i>Rules for Namespace Names</i>;
/// <class>Config.Namespaces</class> carries <parameter>CAPITALNAME</parameter> = 1). The
/// pattern therefore admits <code>-</code> and <code>_</code>: a name they appear in is as
/// legal as <code>USER</code>, and leaving it uncanonicalised reopens the divergence above for
/// exactly the names this instance happens not to have.</p>
/// <p>An implicit namespace is a directory path, whose case is the file system's and which no
/// route is scoped to -- <class>OcuPilot.Api.Namespaces</class> drops those from the roster --
/// so it does not match and is returned untouched.</p>
ClassMethod CanonicalNamespace(pNamespace As %String) As %String
{
    If $Match(pNamespace, "^[A-Za-z%][A-Za-z0-9%_-]*$") Quit $ZConvert(pNamespace, "U")
    Quit pNamespace
}

/// <p>Runs once per request, before any route is dispatched (AD-16's single resolution
/// point). Four concerns, each resolved exactly once, the install gate <b>first</b> and
/// <b>before authentication</b> (AD-38 — a request must not learn anything about the
/// instance, not even whether the caller is who they say, while install has not
/// finished):</p>
/// <ol>
/// <li><b>Install gate.</b> <method>GateStatus</method> resolves to <code>installed</code>
/// only when the version stamp's phase is <code>installed</code> <i>and</i> its stored
/// schema version equals the deployed one; any other value refuses with a single 503
/// envelope naming the matching <code>INSTALL.*</code> code (AC7).</li>
/// <li><b>Caller identity.</b> Rejects the unauthenticated placeholders
/// <code>UnknownUser</code> and <code>_PUBLIC</code> explicitly (AD-21) — anonymous does
/// not mean unprivileged, so this never infers authorization from <code>$Roles</code>
/// alone.</li>
/// <li><b>Administrative privilege (FR-65).</b> The caller must hold at least one
/// <code>%Admin_*</code> resource at <code>USE</code>
/// (<method>HoldsAdminResource</method>, against the closed
/// <parameter>ADMINRESOURCES</parameter> list); otherwise 403 with the machine code
/// <code>AUTH.NOADMIN</code>. <b>A caller who lacks read on the install namespace's
/// database never reaches this method at all</b> — IRIS cannot load this class for that
/// request, and the framework answers a bare 403 with no envelope, which is why README.md
/// states the read requirement rather than leaving it to be discovered from a
/// response.</li>
/// <li><b>Namespace.</b> The <code>?ns=</code> query parameter, defaulting to the
/// namespace already in effect when the request begins (the web application's configured,
/// installed namespace) and validated with <code>##class(%SYS.Namespace).Exists()</code> —
/// the value is never concatenated into anything. A namespace that exists but that the
/// caller may not enter is a 403 naming the failed pair
/// (<method>MayEnterNamespace</method>, AD-21, AD-48); the check is skipped when the
/// request's namespace is the one already in effect, because refusing entry to the namespace
/// the web application is configured in would leave no request this class could answer, and
/// IRIS's own protection on that namespace's globals applies to the request either way. (The
/// privilege note above is about the <i>code</i> database IRIS loads this class from; the
/// entry check tests the <i>global</i> database's resource, which is a different grant.) The
/// name is canonicalised first (<method>CanonicalNamespace</method>), so one namespace is one
/// scope. <b>The survivor is stashed in <class>OcuPilot.Kernel.Scope</class></b>, which is
/// what makes the route's scope a value the request carries rather than something each
/// handler re-derives (AD-44).</li>
/// </ol>
/// <p>None of the four reaches <code>%SYS</code> or any other namespace from here — the
/// gate's own namespace switching lives entirely inside
/// <class>OcuPilot.Install.Installer</class> — so this method never switches
/// <code>$NAMESPACE</code> and there is nothing to restore on the error path. A future
/// story whose resolution needs a <code>%SYS</code>-only call must bracket it with
/// <class>OcuPilot.Kernel.Utils</class>'s <method>SwitchNamespace</method> /
/// <method>RestoreNamespace</method> pair, restoring first in its <code>Catch</code>
/// (AD-16) — the pair is harvested and ready for exactly that.</p>
/// <p>A denial never <code>Write</code>s directly: it sets <var>pContinue</var> to 0 and
/// renders through <class>OcuPilot.Api.Error</class>, the tree's one error writer.</p>
ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set pContinue = 1
    Try {
        ; Nothing from an earlier request on this process may be readable as this request's
        ; scope, including by a request refused before the namespace gate below is reached.
        Do ##class(OcuPilot.Kernel.Scope).Clear()

        Set tGate = ..GateStatus()
        If tGate '= "installed" {
            Set pContinue = 0
            If tGate = "failed" {
                Set tCode = ##class(OcuPilot.Api.Error).#INSTALLFAILED
                Set tReason = "Install failed; the API is not serving requests"
            } ElseIf tGate = "upgraderequired" {
                Set tCode = ##class(OcuPilot.Api.Error).#INSTALLUPGRADEREQUIRED
                Set tReason = "A schema upgrade has not finished; the API is not serving requests"
            } ElseIf tGate = "unreadable" {
                Set tCode = ##class(OcuPilot.Api.Error).#INSTALLUNREADABLE
                Set tReason = "OcuPilot cannot read its own install state; waiting will not help, and an administrator needs to run install again"
            } Else {
                Set tCode = ##class(OcuPilot.Api.Error).#INSTALLINSTALLING
                Set tReason = "Install is still running; the API is not serving requests"
            }
            Do ##class(OcuPilot.Api.Error).Render(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, tReason, tCode)
            Quit
        }

        ; The placeholder test lives on OcuPilot.Screen.Gate, not here: OcuPilot.Port.ProviderPort
        ; makes the same test (AD-21), and two copies of the list is two things to keep equal.
        Set tUser = ..ResolvedUsername()
        If '##class(OcuPilot.Screen.Gate).IsAuthenticatedPrincipal(tUser) {
            Set pContinue = 0
            Do ##class(OcuPilot.Api.Error).Render(401, ##class(OcuPilot.Api.Error).#UNAUTHORIZED, "Authentication required", ##class(OcuPilot.Api.Error).#AUTHANONYMOUS)
            Quit
        }

        If '..HoldsAdminResource() {
            Set pContinue = 0
            Do ##class(OcuPilot.Api.Error).Render(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, "This account holds no InterSystems IRIS administrative privilege; OcuPilot requires USE on at least one %Admin_ resource", ##class(OcuPilot.Api.Error).#AUTHNOADMIN)
            Quit
        }

        Set tNs = ..CanonicalNamespace(%request.Get("ns", $Namespace))
        If tNs '= $Namespace {
            If '##class(%SYS.Namespace).Exists(tNs) {
                Set pContinue = 0
                Do ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, "Unknown namespace", ##class(OcuPilot.Api.Error).#NSUNKNOWN)
                Quit
            }
            Set tFailedPair = ""
            If '..MayEnterNamespace(tNs, .tFailedPair) {
                Set pContinue = 0
                ; The key is omitted, never sent empty: a denial with a blank reason reads as
                ; "refused for nothing stated", which is a different thing from a namespace that
                ; reports no requirement to name at all.
                Set tDetail = ""
                If tFailedPair '= "" {
                    Set tDetail = {}
                    Do tDetail.%Set("failedPair", tFailedPair)
                }
                Do ##class(OcuPilot.Api.Error).Render(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, "This account may not enter that namespace", ##class(OcuPilot.Api.Error).#NSDENIED, tDetail)
                Quit
            }
        }
        Do ##class(OcuPilot.Kernel.Scope).Set(tNs)
    } Catch ex {
        Set pContinue = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Framework-error override: renders every status this class did not otherwise handle
/// through <class>OcuPilot.Api.Error</class> instead of the superclass's own
/// <code>{status, ...}</code> shape. <code>%CSP.REST.DispatchRequest</code> calls this with
/// <code>HTTP404NOTFOUND</code> when no route matches at all.</p>
ClassMethod ReportHttpStatusCode(pHttpStatus, pSC As %Status = {$$$OK}) As %Status
{
    Set tStatus = +pHttpStatus
    If $$$ISERR(pSC) {
        Do ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    } ElseIf tStatus = 404 {
        Do ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, "The requested route does not exist", ##class(OcuPilot.Api.Error).#ROUTENOTFOUND)
    } Else {
        ; The code is derived from the slug, not from the number, and the derivation itself
        ; lives in OcuPilot.Api.Error so this file and OcuPilot.Api.StaticHandler cannot spell
        ; it two ways. This branch is reachable in production: %CSP.REST.Page() calls
        ; ..Http403() at irislib/%CSP/REST.cls:169 when the security application is undefined.
        Set tSlug = ##class(OcuPilot.Api.Error).GetSlugForStatus(tStatus)
        Do ##class(OcuPilot.Api.Error).Render(tStatus, tSlug, "Request failed", ##class(OcuPilot.Api.Error).CodeForStatus(tStatus))
    }
    Quit $$$OK
}

/// <p>Framework-error override for a mapped route with no matching verb.
/// <code>DispatchRequest</code> calls this with the comma-separated list of verbs that
/// <b>are</b> supported at the matched path; delegates to
/// <method>OcuPilot.Api.Error.Render405</method>, which sets the <code>Allow</code>
/// header.</p>
ClassMethod Http405(pSupportedVerbs As %String = "") As %Status
{
    Do ##class(OcuPilot.Api.Error).Render405(pSupportedVerbs)
    Quit $$$OK
}

}

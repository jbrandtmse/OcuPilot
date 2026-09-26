/// <p>The endpoint coverage floor (Story 13.2): every route OcuPilot's dispatch classes declare
/// is probed by this class, and every probe this class declares names a route that exists.</p>
/// <p><b>The route set is derived from the compiled <code>UrlMap</code></b> of every OcuPilot
/// dispatch class outside <package>OcuPilot.Test</package>, so a route added by a later epic is
/// carried here with no edit to the derivation, and a probe left behind by a deleted route is a
/// failure rather than a line nobody reads.</p>
/// <p><b>A source scan would not do.</b> The suite's own path literals are overwhelmingly indirect
/// (<code>..#APIBASE _ pSuffix</code>, <code>tPath</code>), so matching them to routes would
/// attribute coverage it cannot see and miss coverage that exists. Issuing each probe from here
/// makes "at least one test per endpoint" literally true.</p>
/// <p><b>Every write a probe makes is declared.</b> A probe on a write verb sends a body chosen
/// to draw a refusal and is asserted to answer 4xx, which is the handler declining before the
/// write it would have made. The two write routes that cannot be made to refuse declare
/// <code>why</code>: one creates a conversation row, declares <code>cleanup</code> and is undone
/// inside the probe loop; the other abandons the calling account's own in-flight turns, and
/// <code>expect</code> holds the precondition that there were none.</p>
/// <p>Needs an installed instance reachable over HTTP as the suite's own account
/// (<class>OcuPilot.Test.Http</class>). No arming variable applies: nothing here mutates a
/// principal, a log or the install.</p>
Class OcuPilot.Test.EndpointCoverage Extends %UnitTest.TestCase
{

/// <p>The literal every <code>:param</code> probe puts in the path, so a probe can never name a
/// row anything else created. <method>ExpectedPath</method> rebuilds each row's declared
/// <code>path</code> from its <code>url</code> with this in every <code>:param</code> segment, so
/// a row whose path was left stale by a copy-paste does not agree with its own key.</p>
Parameter PROBEID = "ocupilot-coverage-probe";

/// <p>The prefix <method>WebAppPath</method> answers when the install roster could not be read at
/// all, so a failed lookup is a named value rather than the same <code>""</code> a roster with no
/// declaration answers -- the <class>OcuPilot.Test.AdminInventory</class> idiom.</p>
Parameter UNREADABLE = "unreadable:";

/// <p>The request body every write-verb probe sends: not JSON, so a handler that reads a body
/// refuses before it does anything.</p>
Parameter BADBODY = "{";

/// <p>The package dispatch classes are discovered in, and the one excluded from it.</p>
Parameter DISPATCHPACKAGE = "OcuPilot.";

/// <p>See <parameter>DISPATCHPACKAGE</parameter>.</p>
Parameter EXCLUDEDPACKAGE = "OcuPilot.Test.";

/// <p>The XData block a <class>%CSP.REST</class> subclass declares its routes in.</p>
Parameter URLMAPNAME = "UrlMap";

/// <p>The superclass that makes a class a dispatch class.</p>
Parameter DISPATCHBASE = "%CSP.REST";

/// <p>The machine code the router answers when no route matched at all -- which is exactly what a
/// probe must never draw (<class>OcuPilot.Api.Error</class>).</p>
Parameter ROUTENOTFOUND = "ROUTE.NOTFOUND";

/// <p>One probe per declared route. <var>class</var> is the dispatch class with the
/// <code>OcuPilot.</code> prefix removed, <var>method</var> and <var>url</var> are the route as the
/// <code>UrlMap</code> declares it, and <var>path</var> is the concrete absolute path the probe
/// requests.</p>
/// <p><var>disposition</var> is <code>envelope</code> for an AD-12 JSON envelope, or
/// <code>bytes</code> for the static handler, whose success path streams file bytes under AD-12's
/// one carve-out. <var>refusal</var> is <code>1</code> on a write-verb probe asserted to answer
/// 4xx; a write-verb probe without it declares <var>why</var>. <var>cleanup</var> names the state
/// a probe creates and the probe loop then removes. <var>expect</var> is one
/// <code>member=value</code> pair the probe loop asserts against the answered envelope, so a
/// precondition a <var>why</var> rests on is measured rather than assumed.</p>
/// <p><var>substitute</var> is the identifier a <code>:param</code> segment carries instead of
/// <parameter>PROBEID</parameter>, and <var>substitutewhy</var> is why. One row needs it:
/// <method>OcuPilot.Api.ScreenRead.Handle</method> answers <code>ROUTE.NOTFOUND</code> for a
/// screen identifier that resolves to nothing, which is indistinguishable from the router's own
/// route-not-found -- so a probe carrying <parameter>PROBEID</parameter> there would assert
/// exactly what this class exists to refute. Declaring it keeps that row derived rather than
/// silently different.</p>
XData Probes
{
<probes>
<probe class="Api.Router" method="POST" url="/account/password" path="/api/ocupilot/account/password" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/account/preferences" path="/api/ocupilot/account/preferences" disposition="envelope"/>
<probe class="Api.Router" method="POST" url="/account/preferences" path="/api/ocupilot/account/preferences" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="DELETE" url="/agent/switches/holds/:id" path="/api/ocupilot/agent/switches/holds/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/agent/switches/holds" path="/api/ocupilot/agent/switches/holds" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/agent/switches" path="/api/ocupilot/agent/switches" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/agent/switches" path="/api/ocupilot/agent/switches" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/agent/restraint" path="/api/ocupilot/agent/restraint" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/agent/ledger" path="/api/ocupilot/agent/ledger" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/agent/context" path="/api/ocupilot/agent/context" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/agent/context" path="/api/ocupilot/agent/context" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/agent/definitions/:id/default" path="/api/ocupilot/agent/definitions/ocupilot-coverage-probe/default" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/agent/definitions/:id/credential" path="/api/ocupilot/agent/definitions/ocupilot-coverage-probe/credential" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/agent/definitions/:id/test" path="/api/ocupilot/agent/definitions/ocupilot-coverage-probe/test" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/agent/definitions/:id" path="/api/ocupilot/agent/definitions/ocupilot-coverage-probe" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/agent/definitions/:id" path="/api/ocupilot/agent/definitions/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="DELETE" url="/agent/definitions/:id" path="/api/ocupilot/agent/definitions/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/agent/definitions" path="/api/ocupilot/agent/definitions" disposition="envelope"/>
<probe class="Api.Router" method="POST" url="/agent/definitions" path="/api/ocupilot/agent/definitions" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/agent/providers" path="/api/ocupilot/agent/providers" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/web-applications/form" path="/api/ocupilot/web-applications/form" disposition="envelope"/>
<!-- /web-applications/name carries no query string here: path is rebuilt from url and a
     query string would not survive that, so this row draws the documented 422
     WEBAPP.NAME.REQUIRED envelope instead of a 200. It is still a dispatch, which is what
     this class asserts; the route's own answers are OcuPilot.Test.WebAppWire's. -->
<probe class="Api.Router" method="GET" url="/web-applications/name" path="/api/ocupilot/web-applications/name" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/web-applications/:id" path="/api/ocupilot/web-applications/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/web-applications" path="/api/ocupilot/web-applications" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/screens/:screen/action" path="/api/ocupilot/screens/osmgmt.locks/action" disposition="envelope" refusal="1" substitute="osmgmt.locks" substitutewhy="a screen identifier that resolves to nothing answers ROUTE.NOTFOUND, indistinguishable from the router's own, so this route probes a real screen; the body is the unreadable one every write-verb probe sends, and the screen declares no row action, so the handler refuses before any write"/>
<probe class="Api.Router" method="GET" url="/screens/:screen/read" path="/api/ocupilot/screens/osmgmt.locks/read" disposition="envelope" substitute="osmgmt.locks" substitutewhy="a screen identifier that resolves to nothing answers ROUTE.NOTFOUND, indistinguishable from the router's own, so this one route probes a real screen"/>
<probe class="Api.Router" method="GET" url="/logs/errors/namespaces" path="/api/ocupilot/logs/errors/namespaces" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/logs/errors/dates" path="/api/ocupilot/logs/errors/dates" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/logs/errors/list" path="/api/ocupilot/logs/errors/list" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/logs/errors/detail" path="/api/ocupilot/logs/errors/detail" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/logs/alerts" path="/api/ocupilot/logs/alerts" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/logs/messages" path="/api/ocupilot/logs/messages" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/turn/:id/progress" path="/api/ocupilot/turn/ocupilot-coverage-probe/progress" disposition="envelope"/>
<probe class="Api.Router" method="POST" url="/turn/:id/stop" path="/api/ocupilot/turn/ocupilot-coverage-probe/stop" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/turn/:id/navigation" path="/api/ocupilot/turn/ocupilot-coverage-probe/navigation" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/turn/abandon" path="/api/ocupilot/turn/abandon" disposition="envelope" expect="abandoned=0" why="it abandons this account's own turns and reads no body, so no body refuses it; with none in flight it answers abandoned=0 and writes nothing, which expect asserts"/>
<probe class="Api.Router" method="POST" url="/turn" path="/api/ocupilot/turn" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/proposal/:id/confirm" path="/api/ocupilot/proposal/ocupilot-coverage-probe/confirm" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/proposal/:id/cancel" path="/api/ocupilot/proposal/ocupilot-coverage-probe/cancel" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/conversation/:id" path="/api/ocupilot/conversation/ocupilot-coverage-probe" disposition="envelope"/>
<probe class="Api.Router" method="POST" url="/conversation" path="/api/ocupilot/conversation" disposition="envelope" why="it reads no body and always creates, so no body refuses it" cleanup="conversation"/>
<probe class="Api.Router" method="GET" url="/instance" path="/api/ocupilot/instance" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/namespaces" path="/api/ocupilot/namespaces" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/navigation" path="/api/ocupilot/navigation" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/ui/about" path="/api/ocupilot/ui/about" disposition="envelope"/>
<!-- /ui/help carries no route here: path is rebuilt from url and a query string would not
     survive that, so this row draws the documented 422 HELP.ROUTE envelope instead of a 200.
     It is still a dispatch, which is what this class asserts; the route's own answers are
     OcuPilot.Test.UiAboutWire's. -->
<probe class="Api.Router" method="GET" url="/ui/help" path="/api/ocupilot/ui/help" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/ui/system" path="/api/ocupilot/ui/system" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/ui/performance" path="/api/ocupilot/ui/performance" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/users/form" path="/api/ocupilot/users/form" disposition="envelope"/>
<!-- /users/name carries no query string here, for /web-applications/name's reason: it draws the
     documented 422 USER.NAME.REQUIRED envelope. Its own answers are OcuPilot.Test.UserCreateWire's. -->
<probe class="Api.Router" method="GET" url="/users/name" path="/api/ocupilot/users/name" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/users/:id" path="/api/ocupilot/users/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/users" path="/api/ocupilot/users" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/roles/form" path="/api/ocupilot/roles/form" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/roles/name" path="/api/ocupilot/roles/name" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/roles/:id" path="/api/ocupilot/roles/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/roles" path="/api/ocupilot/roles" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/resources/form" path="/api/ocupilot/resources/form" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/resources/name" path="/api/ocupilot/resources/name" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/resources/:id" path="/api/ocupilot/resources/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/resources" path="/api/ocupilot/resources" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/x509/form" path="/api/ocupilot/x509/form" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/x509/name" path="/api/ocupilot/x509/name" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/x509/:id" path="/api/ocupilot/x509/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/x509" path="/api/ocupilot/x509" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/oauth/server-description/form" path="/api/ocupilot/oauth/server-description/form" disposition="envelope"/>
<probe class="Api.Router" method="POST" url="/oauth/server-description/discover" path="/api/ocupilot/oauth/server-description/discover" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="PUT" url="/oauth/server-description/:id" path="/api/ocupilot/oauth/server-description/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/oauth/server-description" path="/api/ocupilot/oauth/server-description" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/oauth/client-configuration/form" path="/api/ocupilot/oauth/client-configuration/form" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/oauth/client-configuration/:id" path="/api/ocupilot/oauth/client-configuration/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/oauth/client-configuration" path="/api/ocupilot/oauth/client-configuration" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/oauth/resource-server/form" path="/api/ocupilot/oauth/resource-server/form" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/oauth/resource-server/:id" path="/api/ocupilot/oauth/resource-server/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/oauth/resource-server" path="/api/ocupilot/oauth/resource-server" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/oauth/authorization-server/form" path="/api/ocupilot/oauth/authorization-server/form" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/oauth/authorization-server" path="/api/ocupilot/oauth/authorization-server" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/oauth/authorization-server" path="/api/ocupilot/oauth/authorization-server" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/oauth/server-client/form" path="/api/ocupilot/oauth/server-client/form" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/oauth/server-client/:id" path="/api/ocupilot/oauth/server-client/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/oauth/server-client" path="/api/ocupilot/oauth/server-client" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/wallet/secret/form" path="/api/ocupilot/wallet/secret/form" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/wallet/secret/name" path="/api/ocupilot/wallet/secret/name" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/wallet/secret/:id" path="/api/ocupilot/wallet/secret/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/wallet/secret" path="/api/ocupilot/wallet/secret" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/device/form" path="/api/ocupilot/device/form" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/device/name" path="/api/ocupilot/device/name" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/device/:id" path="/api/ocupilot/device/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/device" path="/api/ocupilot/device" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/ssl/form" path="/api/ocupilot/ssl/form" disposition="envelope"/>
<probe class="Api.Router" method="GET" url="/ssl/name" path="/api/ocupilot/ssl/name" disposition="envelope"/>
<probe class="Api.Router" method="POST" url="/ssl/:id/test" path="/api/ocupilot/ssl/ocupilot-coverage-probe/test" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="PUT" url="/ssl/:id" path="/api/ocupilot/ssl/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/ssl" path="/api/ocupilot/ssl" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/tasks/form" path="/api/ocupilot/tasks/form" disposition="envelope"/>
<probe class="Api.Router" method="POST" url="/tasks/check" path="/api/ocupilot/tasks/check" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="PUT" url="/tasks/:id" path="/api/ocupilot/tasks/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/tasks" path="/api/ocupilot/tasks" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/services/form" path="/api/ocupilot/services/form" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/services/:id" path="/api/ocupilot/services/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/ldap/form" path="/api/ocupilot/ldap/form" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/ldap/:id" path="/api/ocupilot/ldap/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="GET" url="/audit-events/form" path="/api/ocupilot/audit-events/form" disposition="envelope"/>
<probe class="Api.Router" method="PUT" url="/audit-events/:id" path="/api/ocupilot/audit-events/ocupilot-coverage-probe" disposition="envelope" refusal="1"/>
<probe class="Api.Router" method="POST" url="/audit-events" path="/api/ocupilot/audit-events" disposition="envelope" refusal="1"/>
<probe class="Api.Readiness" method="GET" url="/" path="/api/ocupilot/readiness/" disposition="envelope"/>
<probe class="Api.StaticHandler" method="GET" url="/(.*)" path="/ocupilot/index.html" disposition="bytes"/>
<probe class="Api.StaticHandler" method="HEAD" url="/(.*)" path="/ocupilot/index.html" disposition="bytes"/>
</probes>
}

/// <p>Every OcuPilot dispatch class outside <parameter>EXCLUDEDPACKAGE</parameter>, by name, in
/// class-name order. A class is a dispatch class when it declares a compiled
/// <parameter>URLMAPNAME</parameter> block <b>and</b> extends
/// <parameter>DISPATCHBASE</parameter>, so an unrelated XData block of that name cannot widen the
/// population.</p>
ClassMethod DispatchClasses(Output pList As %List) As %Status
{
    Set tSC = $$$OK
    Set pList = ""
    Try {
        Set tStmt = ##class(%SQL.Statement).%New()
        Set tSC = tStmt.%Prepare("SELECT parent AS Cls FROM %Dictionary.CompiledXData WHERE Name = ? AND parent %STARTSWITH ? ORDER BY parent")
        If $$$ISERR(tSC) Quit
        Set tRs = tStmt.%Execute(..#URLMAPNAME, ..#DISPATCHPACKAGE)
        ; A query that did not run is not a package with no dispatch classes in it: an unchecked
        ; %Execute returns $$$OK with zero rows, and every declared probe would then read as an
        ; orphan -- a failed lookup scored as a negative result.
        If '$IsObject(tRs) || (tRs.%SQLCODE < 0) {
            Set tSC = $$$ERROR($$$GeneralError, "the dispatch-class query did not run: SQLCODE " _ $Select($IsObject(tRs): tRs.%SQLCODE, 1: "no result set"))
            Quit
        }
        While tRs.%Next() {
            Set tName = tRs.%Get("Cls")
            If $Extract(tName, 1, $Length(..#EXCLUDEDPACKAGE)) = ..#EXCLUDEDPACKAGE Continue
            Set tIsDispatch = 0
            Try {
                Set tIsDispatch = $ClassMethod(tName, "%Extends", ..#DISPATCHBASE)
            } Catch ex {
                Set tIsDispatch = 0
            }
            If 'tIsDispatch Continue
            Set pList = pList _ $ListBuild(tName)
        }
        ; %Next() answers 0 both at the end of the rows and on a fetch error, so a failure
        ; part-way through would read as a shorter population.
        If tRs.%SQLCODE < 0 {
            Set pList = ""
            Set tSC = $$$ERROR($$$GeneralError, "the dispatch-class fetch stopped early: SQLCODE " _ tRs.%SQLCODE)
        }
    } Catch ex {
        Set pList = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every declared route, subscripted by
/// <code>&lt;class&gt;|&lt;method&gt;|&lt;url&gt;</code> with the <code>OcuPilot.</code> prefix
/// removed from the class, read from the compiled <parameter>URLMAPNAME</parameter> blocks.</p>
ClassMethod Derive(Output pRows) As %Status
{
    Set tSC = $$$OK
    Kill pRows
    Try {
        Set tSC = ..DispatchClasses(.tClasses)
        If $$$ISERR(tSC) Quit
        If $ListLength(tClasses) = 0 {
            Set tSC = $$$ERROR($$$GeneralError, "no OcuPilot dispatch class was found outside " _ ..#EXCLUDEDPACKAGE)
            Quit
        }
        For tI = 1:1:$ListLength(tClasses) {
            Set tClass = $List(tClasses, tI)
            Set tXData = ##class(%Dictionary.CompiledXData).IDKEYOpen(tClass, ..#URLMAPNAME, , .tOpenSC)
            If '$IsObject(tXData) {
                Set tSC = $$$ERROR($$$GeneralError, tClass _ ": its compiled " _ ..#URLMAPNAME _ " block could not be opened")
                Quit
            }
            Set tShort = $Extract(tClass, $Length(..#DISPATCHPACKAGE) + 1, *)
            Set tRoutes = 0
            Do tXData.Data.Rewind()
            While 'tXData.Data.AtEnd {
                Set tLine = tXData.Data.ReadLine()
                ; A <Map/> forwards a whole prefix to another dispatch class, whose routes this
                ; derivation does not read. Covering a quarter of a surface silently is worse than
                ; refusing: a forwarded sub-dispatch is handled deliberately or not at all.
                If tLine [ "<Map " {
                    Set tSC = $$$ERROR($$$GeneralError, tClass _ ": its " _ ..#URLMAPNAME _ " forwards a prefix with <Map/>, whose routes this derivation does not read -- handle the forwarded dispatch class here before adding one")
                    Quit
                }
                If tLine '[ "<Route " Continue
                Set tUrl = ..Attribute(tLine, "Url")
                Set tMethod = ..Attribute(tLine, "Method")
                If (tUrl = "") || (tMethod = "") Continue
                Set pRows(tShort _ "|" _ tMethod _ "|" _ tUrl) = ""
                Set tRoutes = tRoutes + 1
            }
            Set tXData = ""
            If $$$ISERR(tSC) Quit
            If tRoutes = 0 {
                Set tSC = $$$ERROR($$$GeneralError, tClass _ ": its " _ ..#URLMAPNAME _ " block declares no route, which is a failed read rather than a dispatch class with no routes")
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The declared probe table, in <method>Derive</method>'s key shape, each node
/// <code>&lt;path&gt;|&lt;disposition&gt;|&lt;refusal&gt;|&lt;why&gt;|&lt;cleanup&gt;|&lt;expect&gt;|&lt;substitute&gt;|&lt;substitutewhy&gt;</code>.</p>
ClassMethod Stored(Output pRows) As %Status
{
    Set tSC = $$$OK
    Kill pRows
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Probes", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the Probes XData block could not be opened")
            Quit
        }
        Do tXData.Data.Rewind()
        While 'tXData.Data.AtEnd {
            Set tLine = tXData.Data.ReadLine()
            If tLine '[ "<probe " Continue
            Set tKey = ..Attribute(tLine, "class") _ "|" _ ..Attribute(tLine, "method") _ "|" _ ..Attribute(tLine, "url")
            Set pRows(tKey) = ..Attribute(tLine, "path") _ "|" _ ..Attribute(tLine, "disposition") _ "|" _ ..Attribute(tLine, "refusal") _ "|" _ ..Attribute(tLine, "why") _ "|" _ ..Attribute(tLine, "cleanup") _ "|" _ ..Attribute(tLine, "expect") _ "|" _ ..Attribute(tLine, "substitute") _ "|" _ ..Attribute(tLine, "substitutewhy")
        }
        Set tXData = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One double-quoted attribute value out of a <code>&lt;probe/&gt;</code> or
/// <code>&lt;Route/&gt;</code> line.</p>
/// <p>The name is matched with the space that precedes it, so only a whole attribute name
/// matches: an unanchored search for <code>why</code> would answer <code>substitutewhy</code>'s
/// value on the one row that carries both.</p>
ClassMethod Attribute(pLine As %String, pName As %String) As %String [ Private ]
{
    Set tNeedle = " " _ pName _ "="""
    If pLine '[ tNeedle Quit ""
    Quit $Piece($Piece(pLine, tNeedle, 2), """", 1)
}

/// <p>The web application path the install roster declares for dispatch class <var>pClass</var>
/// (with <parameter>DISPATCHPACKAGE</parameter> removed), or <code>""</code> where the roster
/// declares none. Read from <class>OcuPilot.Install.Roster</class>, which is what install itself
/// asserts the instance against, so a prefix here is never a second declaration of one.</p>
ClassMethod WebAppPath(pClass As %String) As %String
{
    Set tPath = ""
    Try {
        Set tFull = ..#DISPATCHPACKAGE _ pClass
        Set tKeys = ##class(OcuPilot.Install.Roster).Keys()
        For tI = 1:1:$Length(tKeys, ",") {
            Set tKey = $Piece(tKeys, ",", tI)
            If tKey = "" Continue
            ; A roster entry that will not open is UNREADABLE, never "declares no application":
            ; scoring a failed lookup as a negative result is what makes a broken roster read as
            ; a missing declaration, and the caller's message would then name the wrong cause.
            If $$$ISERR(##class(OcuPilot.Install.Roster).Application(tKey, .tApp)) {
                Set tPath = ..#UNREADABLE _ tKey
                Quit
            }
            If '$IsObject(tApp) || '$IsObject(tApp.manifest) {
                Set tPath = ..#UNREADABLE _ tKey
                Quit
            }
            If tApp.manifest.DispatchClass '= tFull Continue
            Set tPath = tApp.path
            Quit
        }
    } Catch ex {
        Set tPath = ..#UNREADABLE _ $Piece(ex.DisplayString(), " ", 1)
    }
    Quit tPath
}

/// <p>The absolute path a probe on route <var>pUrl</var> of <var>pClass</var> must request: the
/// web application the roster declares for that class, plus <var>pUrl</var> with every
/// <code>:param</code> segment replaced by <parameter>PROBEID</parameter>, or by
/// <var>pSubstitute</var> where the row declares one. <code>""</code> where the roster declares
/// no application for the class, and a <parameter>UNREADABLE</parameter>-prefixed value where the
/// roster could not be read -- which the caller asserts on separately, so a broken roster is
/// never reported as a missing declaration.</p>
ClassMethod ExpectedPath(pClass As %String, pUrl As %String, pSubstitute As %String = "") As %String
{
    Set tBase = ..WebAppPath(pClass)
    If tBase = "" Quit ""
    Set tId = $Select(pSubstitute = "": ..#PROBEID, 1: pSubstitute)
    Set tOut = ""
    For tI = 2:1:$Length(pUrl, "/") {
        Set tSegment = $Piece(pUrl, "/", tI)
        Set tOut = tOut _ "/" _ $Select($Extract(tSegment, 1) = ":": tId, 1: tSegment)
    }
    Quit tBase _ tOut
}

/// <p>AC2 -- the derived route set and the declared probe table are equal in both directions, so a
/// route added with no probe and a probe left behind by a deleted route each fail naming the
/// member; and each row's <code>path</code> is rebuilt from its own <code>url</code>, so a row
/// copied from a neighbour with its key corrected and its path left stale is a failure rather
/// than a probe that reaches some other route and satisfies every assertion there.</p>
/// <p>The two <class>OcuPilot.Api.StaticHandler</class> rows are exempt from the path rebuild by
/// shape: their <code>url</code> is a regex, from which no single concrete path follows.</p>
/// <p>Mutation: delete one <code>&lt;probe/&gt;</code> row -> red naming the uncovered route;
/// delete <code>GET /namespaces</code> from <class>OcuPilot.Api.Router</class> and recompile the
/// package -> red naming the orphan probe; change one row's <code>path</code> to another row's ->
/// red naming the row and the path its url implies.</p>
Method TestEveryRouteHasAProbeAndEveryProbeHasARoute()
{
    Set tSC = ..Derive(.tRoutes)
    Do $$$AssertStatusOK(tSC, "the route set derives from the compiled UrlMaps")
    Set tStoredSC = ..Stored(.tProbes)
    Do $$$AssertStatusOK(tStoredSC, "the declared probe table parses")

    Set tDrift = ""
    Set tRoute = ""
    Set tRouteCount = 0
    For {
        Set tRoute = $Order(tRoutes(tRoute))
        Quit:tRoute=""
        Set tRouteCount = tRouteCount + 1
        If '$Data(tProbes(tRoute)) {
            Set tDrift = tDrift _ $Select(tDrift = "": "", 1: "; ") _ tRoute _ " is declared by a UrlMap and has no probe row -- add one"
        }
    }
    Set tProbe = ""
    Set tProbeCount = 0
    For {
        Set tProbe = $Order(tProbes(tProbe))
        Quit:tProbe=""
        Set tProbeCount = tProbeCount + 1
        If '$Data(tRoutes(tProbe)) {
            Set tDrift = tDrift _ $Select(tDrift = "": "", 1: "; ") _ tProbe _ " has a probe row and is declared by no UrlMap -- remove it"
        }
    }
    Do $$$AssertEquals(tDrift, "", "the declared probes and the compiled routes agree")
    Do $$$AssertTrue(tRouteCount > 0, "the derivation found routes at all; a run over none would pass having checked nothing")
    Do $$$AssertEquals(tProbeCount, tRouteCount, "and the two tables are the same size (" _ tProbeCount _ " probe(s), " _ tRouteCount _ " route(s))")

    Set tProbe = "", tRebuilt = 0
    For {
        Set tProbe = $Order(tProbes(tProbe))
        Quit:tProbe=""
        Set tUrl = $Piece(tProbe, "|", 3)
        ; A regex route names no one concrete path, so the two static-handler rows are exempt.
        If tUrl [ "(" Continue
        Set tRow = tProbes(tProbe)
        Set tSubstitute = $Piece(tRow, "|", 7)
        If tSubstitute '= "" {
            Do $$$AssertNotEquals($Piece(tRow, "|", 8), "", tProbe _ ": a row substituting an identifier for PROBEID declares substitutewhy")
        }
        Set tExpected = ..ExpectedPath($Piece(tProbe, "|", 1), tUrl, tSubstitute)
        Do $$$AssertEquals($Extract(tExpected, 1, $Length(..#UNREADABLE)) = ..#UNREADABLE, 0, tProbe _ ": the install roster reads (" _ tExpected _ ")")
        Do $$$AssertNotEquals(tExpected, "", tProbe _ ": the install roster declares a web application for its dispatch class")
        If (tExpected = "") || ($Extract(tExpected, 1, $Length(..#UNREADABLE)) = ..#UNREADABLE) Continue
        Set tRebuilt = tRebuilt + 1
        Do $$$AssertEquals($Piece(tRow, "|", 1), tExpected, tProbe _ ": its path is its web application plus its url with every :param substituted")
    }
    Do $$$AssertTrue(tRebuilt > 0, "paths were rebuilt at all (" _ tRebuilt _ " of " _ tProbeCount _ " row(s); the rest declare a regex url)")
}

/// <p>AC2 -- every declared probe is issued and dispatches: the response carries its declared
/// disposition, and never the router's route-not-found. A route the dispatcher shadows answers
/// here even though it is still in the UrlMap, which the equality above cannot see.</p>
/// <p>Every write-verb probe either declares <code>refusal</code> and is asserted to answer 4xx,
/// or declares <code>why</code> it cannot be made to refuse -- so nothing writes silently. A row
/// declaring <code>expect</code> has that <code>member=value</code> pair asserted against the
/// answered envelope, which is what turns a <code>why</code>'s precondition into a measurement.
/// The one probe that creates a row removes it here.</p>
/// <p>A <code>bytes</code> row is asserted to answer 2xx, and to carry a body on every verb but
/// HEAD, which carries headers and no body by definition -- so the AD-12 carve-out is measured
/// rather than restated.</p>
/// <p>Mutation: reorder <class>OcuPilot.Api.Router</class>'s routes so a literal one falls below
/// the pattern that swallows it, and recompile the package -> the shadowed probe answers
/// ROUTE.NOTFOUND and this goes red naming it.</p>
Method TestEveryProbeDispatchesToItsRoute()
{
    Set tSC = ..Stored(.tProbes)
    Do $$$AssertStatusOK(tSC, "the declared probe table parses")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()

    Set tIssued = 0, tRefusals = 0, tExempt = 0, tExpectations = 0
    Set tKey = ""
    For {
        Set tKey = $Order(tProbes(tKey))
        Quit:tKey=""
        Set tRow = tProbes(tKey)
        Set tMethod = $Piece(tKey, "|", 2)
        Set tPath = $Piece(tRow, "|", 1)
        Set tDisposition = $Piece(tRow, "|", 2)
        Set tRefusal = $Piece(tRow, "|", 3)
        Set tWhy = $Piece(tRow, "|", 4)
        Set tCleanup = $Piece(tRow, "|", 5)
        Set tExpect = $Piece(tRow, "|", 6)
        Set tWrites = ((tMethod = "POST") || (tMethod = "PUT") || (tMethod = "DELETE"))
        Set tBody = $Select(tWrites: ..#BADBODY, 1: "")

        Set tReqSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(tMethod, tPath, tUser, tPassword, .tStatus, .tAnswer, .tHeaders, tBody, $Select(tBody = "": "", 1: "application/json"))
        Do $$$AssertStatusOK(tReqSC, tKey _ ": the request completes")
        If $$$ISERR(tReqSC) Continue
        Set tIssued = tIssued + 1
        Do $$$AssertTrue(+tStatus > 0, tKey _ ": the instance answered with a status")

        Set tCode = ..CodeOf(tAnswer)
        Do $$$AssertNotEquals(tCode, ..#ROUTENOTFOUND, tKey _ ": " _ tMethod _ " " _ tPath _ " dispatched, rather than falling to the router's route-not-found")
        If tDisposition = "envelope" {
            Do $$$AssertTrue(..IsJson(tAnswer), tKey _ ": answered an AD-12 JSON envelope (" _ $Extract(tAnswer, 1, 120) _ ")")
        } Else {
            Do $$$AssertEquals(tDisposition, "bytes", tKey _ ": declares one of the two dispositions")
            Do $$$AssertTrue((+tStatus >= 200) && (+tStatus < 300), tKey _ ": the byte-streaming carve-out answered a success status (" _ tStatus _ ")")
            If tMethod '= "HEAD" {
                Do $$$AssertTrue($Length(tAnswer) > 0, tKey _ ": and streamed a body")
            }
        }

        If tExpect '= "" {
            Set tMember = $Piece(tExpect, "=", 1)
            Set tWanted = $Piece(tExpect, "=", 2)
            Set tRead = ..MemberOf(tAnswer, tMember)
            Do $$$AssertEquals($Get(tRead), tWanted, tKey _ ": " _ tMember _ " reads " _ tWanted _ ", the precondition its why rests on (" _ $Extract(tAnswer, 1, 120) _ ")")
            Set tExpectations = tExpectations + 1
        }

        If tWrites {
            If tRefusal = 1 {
                Do $$$AssertTrue((+tStatus >= 400) && (+tStatus < 500), tKey _ ": the body it was sent is refused at 4xx, which is the handler declining before any write it would have made (status " _ tStatus _ ")")
                Set tRefusals = tRefusals + 1
            } Else {
                Do $$$AssertNotEquals(tWhy, "", tKey _ ": a write-verb probe that is not asserted to refuse declares why it cannot be made to")
                Set tExempt = tExempt + 1
            }
        }

        If tCleanup = "conversation" {
            Set tCreated = ..MemberOf(tAnswer, "conversationId")
            Do $$$AssertNotEquals(tCreated, "", tKey _ ": the conversation it created is named in the answer, so it can be removed")
            If tCreated '= "" {
                Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tCreated), tKey _ ": and it is removed again, so the probe leaves no row behind")
            }
        }
    }
    Do $$$AssertTrue(tIssued > 0, "probes were issued at all")
    Do $$$AssertTrue(tRefusals > 0, "and write-verb probes were asserted to refuse (" _ tRefusals _ " refused, " _ tExempt _ " declared why they cannot)")
    Do $$$AssertTrue(tExpectations > 0, "and the declared expectations were read back (" _ tExpectations _ ")")
}

/// <p>Whether <var>pBody</var> is a JSON object or array.</p>
ClassMethod IsJson(pBody As %String) As %Boolean
{
    Set tFirst = $Extract($ZStrip(pBody, "<W"), 1)
    Quit (tFirst = "{") || (tFirst = "[")
}

/// <p>The <var>pMember</var> member of a JSON answer, or <code>""</code> where the answer is not
/// JSON or does not parse. <method>IsJson</method> reads only the first character, so a truncated
/// or malformed body that begins with <code>{</code> reaches the parser and throws; the parse is
/// guarded here, once, so every caller reads a value rather than losing the rest of its loop to
/// an exception raised from the middle of it.</p>
ClassMethod MemberOf(pBody As %String, pMember As %String) As %String
{
    Set tValue = ""
    Try {
        If ..IsJson(pBody) Set tValue = ##class(%DynamicAbstractObject).%FromJSON(pBody).%Get(pMember)
    } Catch ex {
        Set tValue = ""
    }
    Quit $Get(tValue)
}

/// <p>The <code>code</code> member of an AD-12 error envelope, or <code>""</code> where the answer
/// is not one. A body that cannot be parsed answers <code>""</code>, never the caller's code.</p>
ClassMethod CodeOf(pBody As %String) As %String
{
    Quit ..MemberOf(pBody, "code")
}

}

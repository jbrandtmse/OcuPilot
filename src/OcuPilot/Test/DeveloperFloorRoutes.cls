/// <p>Story 19.12's route sweep (AD-8, AD-44): every route the shipped <code>UrlMap</code> declares,
/// sent as a real <code>%Developer</code> principal, is refused 403 unless
/// <method>Roster</method> names it, and every <code>GET</code> the roster names answers neither 403
/// nor a server error. The roster's other routes are writes the principal makes on its own
/// account, conversation or turn, SQL query's run and plan routes, whose run route
/// <class>OcuPilot.Test.DeveloperFloor</class> sends, and its background start, which
/// <class>OcuPilot.Test.SqlBackgroundRoutes</class> sends as a <code>%Developer</code>, and cancel, and
/// are not sent.</p>
/// <p>Placeholders reach each route's gate rather than a 404 before it: <code>:screen</code> is
/// <parameter>SCREENKEY</parameter>, a screen the principal may not read, and its action and impact
/// routes name that screen's <parameter>SCREENACTION</parameter>; <code>:kind</code> is
/// <parameter>MAPPINGKIND</parameter>; every other id is <parameter>ABSENTID</parameter>, which no
/// row holds.</p>
/// <p>It needs <parameter>ARMINGVARIABLE</parameter> armed: <class>OcuPilot.Test.DeveloperFloorFixture</class>
/// creates the principal in <method>OnBeforeAllTests</method> and removes it in
/// <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.DeveloperFloorRoutes Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.DeveloperFloorFixture";

/// <p>What fills <code>:screen</code>.</p>
Parameter SCREENKEY = "webapp.list";

/// <p>What fills <code>:kind</code>.</p>
Parameter MAPPINGKIND = "global";

/// <p>What fills every other <code>:param</code>.</p>
Parameter ABSENTID = "OcuPilotProbeAbsent";

/// <p>The row action <parameter>SCREENKEY</parameter>'s action and impact routes name, so each
/// resolves a declared action and reaches the screen's pair gate.</p>
Parameter SCREENACTION = "enable";

/// <p>The principal's password for this run.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read the principal's grant back.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DeveloperFloorRoutes creates IRIS users and a role, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", ..PreparedPassword, "", .tUser)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#FIXTURE, "Composed", tUser, .tComposed)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSetupOk = $ClassMethod(..#FIXTURE, "Holds", tComposed, "%Development", "USE") && '$ClassMethod(..#FIXTURE, "HoldsAdministrative", tComposed)
    If '..PreparedSetupOk Quit $$$ERROR($$$GeneralError, "Setup could not read back that the principal holds %Development:USE and no administrative resource")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DeveloperFloorRoutes teardown left:" _ tLeft)
    Quit $$$OK
}

/// <p>The routes the principal passes, as <code>$ListBuild(method, url)</code> spelled as the map
/// declares them: the caller-own agent reads and choices, its turns, proposals, conversations and
/// transcripts, the shell reads, its own account, Home's reads and the analytics log (Story 19.12's
/// audit), SQL query's two routes (Story 19.6), its three background routes (Story 19.15) and Data
/// browser's route (Story 19.7). Each is
/// owner-scoped, or its classic page carries no <code>RESOURCE</code> or one the principal holds (the
/// analytics log's public <code>%DeepSee_Portal</code>, the classic SQL page's
/// <code>%Development</code>).</p>
ClassMethod Roster() As %List
{
    Set tGets = "/agent/definitions,/agent/restraint,/agent/context,/agent/ledger,/turn/:id/progress,/conversation/:id,/transcripts/:id,/instance,/namespaces,/navigation,/account/preferences,/ui/about,/ui/help,/ui/system,/ui/findings,/ui/guardrails,/logs/analytics,/explorer/sql/background/:id"
    Set tOthers = "PUT /agent/restraint,PUT /agent/context,POST /turn,POST /turn/:id/stop,POST /turn/:id/navigation,POST /turn/abandon,POST /proposal/:id/confirm,POST /proposal/:id/cancel,POST /proposal/:id/draft,POST /conversation,POST /account/password,POST /account/preferences,POST /explorer/sql/run,POST /explorer/sql/plan,POST /explorer/sql/background,POST /explorer/sql/background/:id/cancel,POST /explorer/sql/data"
    Set tRoster = ""
    For tI = 1:1:$Length(tGets, ",") Set tRoster = tRoster _ $ListBuild($ListBuild("GET", $Piece(tGets, ",", tI)))
    For tI = 1:1:$Length(tOthers, ",") Set tRoster = tRoster _ $ListBuild($ListBuild($Piece($Piece(tOthers, ",", tI), " ", 1), $Piece($Piece(tOthers, ",", tI), " ", 2)))
    Quit tRoster
}

/// <p><var>pUrl</var> with each <code>:param</code> segment filled, and the query and body that
/// reach its gate (this class's header).</p>
ClassMethod ConcretePath(pMethod As %String, pUrl As %String, Output pBody As %String) As %String
{
    Set tOut = ""
    For tI = 2:1:$Length(pUrl, "/") {
        Set tSegment = $Piece(pUrl, "/", tI)
        If $Extract(tSegment) = ":" {
            Set tSegment = $Case(tSegment, ":screen": ..#SCREENKEY, ":kind": ..#MAPPINGKIND, : ..#ABSENTID)
        }
        Set tOut = tOut _ "/" _ tSegment
    }
    Set pBody = $Select($ListFind($ListBuild("POST", "PUT"), pMethod): "{}", 1: "")
    If pUrl = "/screens/:screen/impact" Set tOut = tOut _ "?action=" _ ..#SCREENACTION _ "&id=" _ ..#ABSENTID
    If pUrl = "/screens/:screen/action" {
        Set tAction = {}
        Do tAction.%Set("action", ..#SCREENACTION, "string")
        Do tAction.%Set("id", ..#ABSENTID, "string")
        Set pBody = tAction.%ToJSON()
    }
    Quit tOut
}

/// <p><b>The sweep (AC2).</b> Every declared route outside <method>Roster</method> refuses the
/// developer principal 403 <code>AUTH.NOPRIVILEGE</code> naming its failed pair, and every roster
/// <code>GET</code> answers it with neither 403 nor a
/// server error. A roster entry the map does not declare fails, so the roster cannot name what is no
/// longer served.</p>
/// <p>Mutation: delete the <code>Gate()</code> call from
/// <class>OcuPilot.Area.WebApp.FormRules</class> -> <code>GET /web-applications/form</code> answers
/// the principal and this goes red naming it.</p>
Method TestEveryRouteOutsideTheRosterRefusesTheDeveloper()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principal's grant")
    Set tUser = $Parameter(..#FIXTURE, "DEVELOPERUSER")
    Set tSC = ##class(OcuPilot.Test.ConfigGate).Routes(.tRoutes)
    Do $$$AssertStatusOK(tSC, "the shipped UrlMap is readable")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(tRoutes > 0, "the map declares routes to sweep: " _ tRoutes)

    Set tRoster = ..Roster()
    Kill tDeclared
    For tI = 1:1:tRoutes Set tDeclared(tRoutes(tI, "method"), tRoutes(tI, "url")) = ""
    For tR = 1:1:$ListLength(tRoster) {
        Set tEntry = $List(tRoster, tR)
        Do $$$AssertTrue($Data(tDeclared($List(tEntry, 1), $List(tEntry, 2))), "the roster names a declared route: " _ $List(tEntry, 1) _ " " _ $List(tEntry, 2))
    }

    Set tRefused = 0
    Set tOpen = 0
    For tI = 1:1:tRoutes {
        Set tMethod = tRoutes(tI, "method")
        Set tUrl = tRoutes(tI, "url")
        Set tInRoster = $ListFind(tRoster, $ListBuild(tMethod, tUrl))
        If tInRoster && (tMethod '= "GET") Continue
        Set tPath = ..ConcretePath(tMethod, tUrl, .tBody)
        Set tSC = $ClassMethod(..#FIXTURE, "Call", tMethod, tPath, tUser, ..PreparedPassword, .tStatus, .tText, .tHeaders, tBody)
        Do $$$AssertStatusOK(tSC, tMethod _ " " _ tUrl _ ": the request completes")
        If tInRoster {
            Set tOpen = tOpen + 1
            Do $$$AssertTrue((tStatus '= 403) && (tStatus < 500), tMethod _ " " _ tUrl _ ": answers the developer (" _ tStatus _ ": " _ $Extract(tText, 1, 200) _ ")")
            Continue
        }
        Set tRefused = tRefused + 1
        Do $$$AssertEquals(tStatus, 403, tMethod _ " " _ tUrl _ ": is refused (" _ $Extract(tText, 1, 200) _ ")")
        Set tRefusal = ""
        Try {
            Set tRefusal = ##class(%DynamicObject).%FromJSON(tText)
        } Catch {
            Set tRefusal = ""
        }
        Set tCode = $Select($IsObject(tRefusal): tRefusal.%Get("code"), 1: "")
        Set tPair = $Select($IsObject(tRefusal) && $IsObject(tRefusal.%Get("detail")): tRefusal.detail.%Get("failedPair"), 1: "")
        Do $$$AssertTrue((tCode = "AUTH.NOPRIVILEGE") && (tPair '= ""), tMethod _ " " _ tUrl _ ": naming the failed pair (" _ tCode _ " " _ tPair _ ")")
    }
    Do $$$AssertTrue((tRefused > 0) && (tOpen > 0), "the sweep refused " _ tRefused _ " routes and opened " _ tOpen)
}

}

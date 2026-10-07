/// <p>Story 20.14's route sweep (AD-8, AD-44): every route the shipped <code>UrlMap</code> declares,
/// sent as a real <code>%Ens_Portal</code> holder and as a real Operator, is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming a pair unless <method>Roster</method> names it, and every
/// <code>GET</code> the roster names answers neither 403 nor a server error. The roster's other routes
/// are writes the principal makes on its own account, conversation or turn, and are not sent. The
/// <code>explorer/sql</code> routes are not in the roster, so each is sent and must name
/// <parameter>EXPLORERPAIR</parameter>.</p>
/// <p>Placeholders are <class>OcuPilot.Test.DeveloperFloorRoutes</class>'s
/// (<method>OcuPilot.Test.DeveloperFloorRoutes.ConcretePath</method>).</p>
/// <p>It needs <parameter>ARMINGVARIABLE</parameter> armed: <class>OcuPilot.Test.InteropFloorFixture</class>
/// creates the two principals in <method>OnBeforeAllTests</method> and removes them in
/// <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.InteropFloorRoutes Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropFloorFixture";

/// <p>The pair every <code>explorer/sql</code> route names for these principals.</p>
Parameter EXPLORERPAIR = "%Development:USE";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read the principals' grants back.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropFloorRoutes creates IRIS users and roles, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tOk = 1
    For tKind = "portal", "operator" {
        Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", ..PreparedPassword, tKind, .tUser)
        If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "Composed", tUser, .tComposed)
        If $$$ISERR(tSC) Quit
        If '($ClassMethod(..#FIXTURE, "Holds", tComposed, "%Ens_Portal", "USE") && '$ClassMethod(..#FIXTURE, "Holds", tComposed, "%Development", "USE") && '$ClassMethod(..#FIXTURE, "HoldsAdministrative", tComposed)) Set tOk = 0
    }
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSetupOk = tOk
    If 'tOk Quit $$$ERROR($$$GeneralError, "Setup could not read back that each principal holds %Ens_Portal:USE, no %Development:USE and no administrative resource")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropFloorRoutes teardown left:" _ tLeft)
    Quit $$$OK
}

/// <p>The routes principal kind <var>pKind</var> (<code>portal</code> or <code>operator</code>) passes,
/// as <code>$ListBuild(method, url)</code> spelled as the map declares them: the caller-own agent
/// reads and choices, its turns, proposals, conversations and transcripts, the shell reads, its own
/// account, Home's reads and the analytics log, and for the Operator the interoperability event log.
/// Each is owner-scoped, or its classic page carries no <code>RESOURCE</code>, the public
/// <code>%DeepSee_Portal</code> or a resource the principal holds.</p>
ClassMethod Roster(pKind As %String) As %List
{
    Set tGets = "/agent/definitions,/agent/restraint,/agent/context,/agent/ledger,/turn/:id/progress,/conversation/:id,/transcripts/:id,/instance,/namespaces,/navigation,/account/preferences,/ui/about,/ui/help,/ui/system,/ui/findings,/ui/guardrails,/logs/analytics"
    If pKind = "operator" Set tGets = tGets _ ",/logs/eventlog"
    Set tOthers = "PUT /agent/restraint,PUT /agent/context,POST /turn,POST /turn/:id/stop,POST /turn/:id/navigation,POST /turn/abandon,POST /proposal/:id/confirm,POST /proposal/:id/cancel,POST /proposal/:id/draft,POST /conversation,POST /account/password,POST /account/preferences"
    Set tRoster = ""
    For tI = 1:1:$Length(tGets, ",") Set tRoster = tRoster _ $ListBuild($ListBuild("GET", $Piece(tGets, ",", tI)))
    For tI = 1:1:$Length(tOthers, ",") Set tRoster = tRoster _ $ListBuild($ListBuild($Piece($Piece(tOthers, ",", tI), " ", 1), $Piece($Piece(tOthers, ",", tI), " ", 2)))
    Quit tRoster
}

/// <p><b>The sweep (AC2).</b> For each of the <code>%Ens_Portal</code> holder and the Operator, every
/// declared route outside <method>Roster</method> refuses 403 <code>AUTH.NOPRIVILEGE</code> naming its
/// failed pair, every <code>explorer/sql</code> route naming <parameter>EXPLORERPAIR</parameter>, and
/// every roster <code>GET</code> answers with neither 403 nor a server error. A roster entry the map
/// does not declare fails, so the roster cannot name what is no longer served.</p>
/// <p>Mutations: <method>OcuPilot.Screen.Gate.FloorResources</method> without
/// <parameter>OcuPilot.Screen.Gate.INTEROPRESOURCE</parameter> -> every request answers
/// <code>AUTH.NOADMIN</code> and this goes red; delete the <code>Gate()</code> call from
/// <class>OcuPilot.Area.WebApp.FormRules</class> -> <code>GET /web-applications/form</code> answers
/// the principal and this goes red naming it.</p>
Method TestEveryRouteOutsideTheRosterRefusesTheInteroperabilityHolders()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tSC = ##class(OcuPilot.Test.ConfigGate).Routes(.tRoutes)
    Do $$$AssertStatusOK(tSC, "the shipped UrlMap is readable")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(tRoutes > 0, "the map declares routes to sweep: " _ tRoutes)
    Kill tDeclared
    For tI = 1:1:tRoutes Set tDeclared(tRoutes(tI, "method"), tRoutes(tI, "url")) = ""

    For tKind = "portal", "operator" {
        Set tUser = $ClassMethod(..#FIXTURE, "UserOf", tKind)
        Set tRoster = ..Roster(tKind)
        For tR = 1:1:$ListLength(tRoster) {
            Set tEntry = $List(tRoster, tR)
            Do $$$AssertTrue($Data(tDeclared($List(tEntry, 1), $List(tEntry, 2))), tKind _ ": the roster names a declared route: " _ $List(tEntry, 1) _ " " _ $List(tEntry, 2))
        }
        Set tRefused = 0
        Set tOpen = 0
        For tI = 1:1:tRoutes {
            Set tMethod = tRoutes(tI, "method")
            Set tUrl = tRoutes(tI, "url")
            Set tInRoster = $ListFind(tRoster, $ListBuild(tMethod, tUrl))
            If tInRoster && (tMethod '= "GET") Continue
            Set tPath = ##class(OcuPilot.Test.DeveloperFloorRoutes).ConcretePath(tMethod, tUrl, .tBody)
            Set tSC = $ClassMethod(..#FIXTURE, "Call", tMethod, tPath, tUser, ..PreparedPassword, .tStatus, .tText, .tHeaders, tBody)
            Do $$$AssertStatusOK(tSC, tKind _ " " _ tMethod _ " " _ tUrl _ ": the request completes")
            If tInRoster {
                Set tOpen = tOpen + 1
                Do $$$AssertTrue((tStatus '= 403) && (tStatus < 500), tKind _ " " _ tMethod _ " " _ tUrl _ ": answers the principal (" _ tStatus _ ": " _ $Extract(tText, 1, 200) _ ")")
                Continue
            }
            Set tRefused = tRefused + 1
            Do $$$AssertEquals(tStatus, 403, tKind _ " " _ tMethod _ " " _ tUrl _ ": is refused (" _ $Extract(tText, 1, 200) _ ")")
            Set tRefusal = ""
            Try {
                Set tRefusal = ##class(%DynamicObject).%FromJSON(tText)
            } Catch {
                Set tRefusal = ""
            }
            Set tCode = $Select($IsObject(tRefusal): tRefusal.%Get("code"), 1: "")
            Set tPair = $Select($IsObject(tRefusal) && $IsObject(tRefusal.%Get("detail")): tRefusal.detail.%Get("failedPair"), 1: "")
            Do $$$AssertTrue((tCode = "AUTH.NOPRIVILEGE") && (tPair '= ""), tKind _ " " _ tMethod _ " " _ tUrl _ ": naming the failed pair (" _ tCode _ " " _ tPair _ ")")
            If tUrl [ "/explorer/sql" Do $$$AssertEquals(tPair, ..#EXPLORERPAIR, tKind _ " " _ tMethod _ " " _ tUrl _ ": naming " _ ..#EXPLORERPAIR)
        }
        Do $$$AssertTrue((tRefused > 0) && (tOpen > 0), tKind _ ": the sweep refused " _ tRefused _ " routes and opened " _ tOpen)
    }
}

}

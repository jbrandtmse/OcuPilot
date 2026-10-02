/// <p>Story 19.12's widened floor, as a real <code>%Developer</code> principal meets it over HTTP
/// (AD-8, AD-29, AD-44, DW-1903, DW-1853): it signs in, opens exactly the declared areas and
/// screens, reads System Explorer in the install namespace and in <code>USER</code>, is refused an
/// administrative screen naming its pair, opens Logs on the analytics log alone, and reads Home's
/// system information with the dashboard members empty and nothing logged. A principal below the
/// floor is refused naming both halves of it, and an administrator without <code>%All</code> is
/// still answered the dashboard. Two derived legs hold the rosters: every screen the
/// map opens to the principal is a declared one whose classic page's compiled <code>RESOURCE</code>
/// admits it, and the tools whose required pairs it holds are exactly the declared ten, none a
/// write.</p>
/// <p>It needs <parameter>ARMINGVARIABLE</parameter> armed: <class>OcuPilot.Test.DeveloperFloorFixture</class>
/// creates the three principals in <method>OnBeforeAllTests</method>, which reads their grants back
/// through <class>OcuPilot.Kernel.Shell.Effective</class>, and removes them in
/// <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.DeveloperFloor Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.DeveloperFloorFixture";

/// <p>The areas the navigation map opens to the developer principal.</p>
Parameter AREAS = "home,logs,system-explorer,agent";

/// <p>The package the screens below are declared in.</p>
Parameter DESCRIPTORPACKAGE = "OcuPilot.Screen.Descriptor.";

/// <p>The screens the map opens to it: Home, the agent's own-data screens, System Explorer's four
/// and the analytics log (Story 19.12's audit).</p>
Parameter SCREENS = "AgentGuardrails,AgentLedger,AgentTranscript,AgentTranscripts,ExplorerClassDocument,ExplorerClassList,ExplorerRoutineDocument,ExplorerRoutineList,Home,LogAnalyticsViewer";

/// <p>The tools whose required pairs it holds.</p>
Parameter TOOLS = "agent.transcripts.read,explorer.class.read,explorer.classes.read,explorer.routine.read,explorer.routines.read,logs.analytics.read,shell.instance.read,shell.namespaces.read,shell.privileges.read,shell.screen.open";

/// <p>The second namespace System Explorer is read in, whose code database
/// <code>%Developer</code> grants.</p>
Parameter OTHERNAMESPACE = "USER";

/// <p>A class and a routine each namespace's viewer reads; both live in the public library
/// database.</p>
Parameter CLASSDOCUMENT = "%Library.Persistent.cls";

/// <p>See <parameter>CLASSDOCUMENT</parameter>.</p>
Parameter ROUTINEDOCUMENT = "%occStatus.inc";

/// <p>Classic pages that compile no <code>RESOURCE</code> parameter and check a resource at
/// <code>USE</code> inside the page instead, as <code>page:resource</code>, comma-separated:
/// <code>%CSP.UI.System.ViewCode</code>'s <code>OnPreHTTP</code> checks
/// <code>$$$DevelopmentResourceName</code>, which <file>%sySecurity.inc</file> defines as
/// <code>%Development</code>.</p>
Parameter INTERNALCHECKS = "%CSP.UI.System.ViewCode:%Development";

/// <p>The five members Home's system information samples from the dashboard.</p>
Parameter DASHBOARDMEMBERS = "uptime,databaseSpace,journalSpace,lockTable,writeDaemon";

/// <p>What a <code>uisystem</code> log line carries in <code>messages.log</code>.</p>
Parameter SYSTEMINFOLOGMARK = """subsystem"":""uisystem""";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back the principals' grants.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

/// <p>The developer principal's grants, composed (<method>OcuPilot.Test.DeveloperFloorFixture.Composed</method>).</p>
Property PreparedComposed As %DynamicObject;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Set ..PreparedComposed = ""
    Quit $$$OK
}

/// <p>Refuse unless armed, create the three principals and read their grants back: the developer
/// principal holds <code>%Development:USE</code>, the public <code>%DeepSee_Portal:USE</code> and
/// the code database's READ, and no administrative resource; the one below the floor holds the
/// READ and neither <code>%Development:USE</code> nor an administrative resource; the
/// administrator holds <code>%DB_IRISSYS:READ</code> and <code>%Admin_Operate:USE</code>.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DeveloperFloor creates IRIS users and roles, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", ..PreparedPassword, "", .tUser)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", ..PreparedPassword, "neither", .tNeither)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", ..PreparedPassword, "administrator", .tAdministrator)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#FIXTURE, "Composed", tUser, .tComposed)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "Composed", tNeither, .tBelow)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "Composed", tAdministrator, .tAdmin)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedComposed = tComposed
    Set tCode = $ClassMethod(..#FIXTURE, "CodeResource")
    Set tDev = ..Held(tComposed, "%Development", "USE") && ..Held(tComposed, "%DeepSee_Portal", "USE") && ..Held(tComposed, tCode, "READ") && '$ClassMethod(..#FIXTURE, "HoldsAdministrative", tComposed)
    Set tFloor = ..Held(tBelow, tCode, "READ") && '..Held(tBelow, "%Development", "USE") && '$ClassMethod(..#FIXTURE, "HoldsAdministrative", tBelow)
    Set tAdminOk = ..Held(tAdmin, "%DB_IRISSYS", "READ") && ..Held(tAdmin, "%Admin_Operate", "USE")
    Set ..PreparedSetupOk = tDev && tFloor && tAdminOk
    If '..PreparedSetupOk Quit $$$ERROR($$$GeneralError, "Setup could not read back the principals' grants: developer " _ tDev _ ", below the floor " _ tFloor _ ", administrator " _ tAdminOk)
    Quit $$$OK
}

/// <p>Remove the three principals and both roles, and return a failing status if any survives.</p>
Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DeveloperFloor teardown left:" _ tLeft)
    Quit $$$OK
}

/// <p>Whether <var>pComposed</var> holds <var>pPermission</var> on <var>pResource</var>.</p>
ClassMethod Held(pComposed As %DynamicObject, pResource As %String, pPermission As %String) As %Boolean
{
    Quit ''$ClassMethod(..#FIXTURE, "Holds", pComposed, pResource, pPermission)
}

/// <p>One request as <var>pUser</var>; <var>pObject</var> is the parsed body, or <code>""</code>.</p>
Method Request(pMethod As %String, pPath As %String, pUser As %String, Output pStatus As %Integer, Output pObject, Output pText As %String) As %Status
{
    Set pObject = ""
    Set tSC = $ClassMethod(..#FIXTURE, "Call", pMethod, pPath, pUser, ..PreparedPassword, .pStatus, .pText, .tHeaders)
    Try {
        If $Get(pText) '= "" Set pObject = ##class(%DynamicAbstractObject).%FromJSON(pText)
    } Catch {
        Set pObject = ""
    }
    Quit tSC
}

/// <p>The developer principal's navigation map: <var>pAreas</var>(key) and
/// <var>pScreens</var>(descriptor short name) each <code>$ListBuild(allowed, failedPair)</code>, the
/// screen's area as a third element. A route no descriptor declares is subscripted by the route.</p>
Method Navigation(Output pAreas, Output pScreens) As %Status
{
    Kill pAreas, pScreens
    Set tSC = ..Request("GET", "/navigation", $Parameter(..#FIXTURE, "DEVELOPERUSER"), .tStatus, .tMap, .tText)
    If $$$ISERR(tSC) Quit tSC
    If (tStatus '= 200) || '$IsObject(tMap) Quit $$$ERROR($$$GeneralError, "the navigation map answered " _ tStatus _ ": " _ $Extract(tText, 1, 300))
    Set tAreas = tMap.areas.%GetIterator()
    While tAreas.%GetNext(.tIndex, .tArea) {
        Set pAreas(tArea.key) = $ListBuild(''tArea.allowed, tArea.%Get("failedPair"))
        Set tScreens = tArea.screens.%GetIterator()
        While tScreens.%GetNext(.tScreenIndex, .tScreen) {
            Set tClass = ##class(OcuPilot.Screen.Registry).DescriptorForRoute(tScreen.route)
            Set tName = $Select(tClass = "": tScreen.route, 1: $Piece(tClass, ..#DESCRIPTORPACKAGE, 2))
            Set pScreens(tName) = $ListBuild(''tScreen.allowed, tScreen.%Get("failedPair"), tArea.key)
        }
    }
    Quit $$$OK
}

/// <p>The comma-separated, sorted subscripts of <var>pEntries</var> whose first element is
/// true.</p>
ClassMethod AllowedOf(ByRef pEntries) As %String
{
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(pEntries(tKey))
        If tKey = "" Quit
        If $List(pEntries(tKey), 1) Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

/// <p><var>pList</var>, comma-separated, sorted.</p>
ClassMethod Sorted(pList As %String) As %String
{
    Kill tSorted
    For tI = 1:1:$Length(pList, ",") {
        If $Piece(pList, ",", tI) '= "" Set tSorted($Piece(pList, ",", tI)) = ""
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

/// <p><b>Sign-in (DW-1903).</b> The developer principal clears the floor: the identity call answers
/// 200 and the navigation map opens exactly <parameter>AREAS</parameter> and
/// <parameter>SCREENS</parameter>, every other area and screen reading unavailable with its failed
/// pair.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Gate.FloorResources</method> answers
/// <parameter>OcuPilot.Screen.Gate.ADMINRESOURCES</parameter> alone -> the identity call and the map
/// answer 403 <code>AUTH.NOADMIN</code> and this goes red.</p>
Method TestTheDeveloperSignsInAndOpensExactlyTheDeclaredScreens()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Do ..Request("GET", "/instance", $Parameter(..#FIXTURE, "DEVELOPERUSER"), .tStatus, .tObject, .tText)
    Do $$$AssertEquals(tStatus, 200, "the identity call clears the floor: " _ $Extract(tText, 1, 300))
    Set tSC = ..Navigation(.tAreas, .tScreens)
    Do $$$AssertStatusOK(tSC, "the navigation map answers")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(..AllowedOf(.tAreas), ..Sorted(..#AREAS), "exactly the declared areas open")
    Do $$$AssertEquals(..AllowedOf(.tScreens), ..Sorted(..#SCREENS), "exactly the declared screens open")
    For tKind = "area", "screen" {
        Set tKey = ""
        For {
            If tKind = "area" { Set tKey = $Order(tAreas(tKey), 1, tEntry) } Else { Set tKey = $Order(tScreens(tKey), 1, tEntry) }
            If tKey = "" Quit
            If $List(tEntry, 1) Continue
            Do $$$AssertNotEquals($List(tEntry, 2), "", tKind _ " " _ tKey _ ": unavailable, naming its failed pair")
        }
    }
}

/// <p><b>System Explorer.</b> Both lists and both viewers answer the developer principal 200 with
/// rows in the install namespace and in <parameter>OTHERNAMESPACE</parameter>, where the Routines
/// list carries rows from that namespace's own database, which <code>%Developer</code>'s
/// <code>%DB_USER</code> grants.</p>
/// <p>Mutation: as <method>TestTheDeveloperSignsInAndOpensExactlyTheDeclaredScreens</method>'s ->
/// every read answers 403 and this goes red.</p>
Method TestSystemExplorerReadsInBothNamespaces()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tUser = $Parameter(..#FIXTURE, "DEVELOPERUSER")
    For tNs = "", ..#OTHERNAMESPACE {
        Set tQuery = $Select(tNs = "": "", 1: "&ns=" _ tNs)
        Set tWhere = $Select(tNs = "": $Namespace, 1: tNs)
        For tRead = "explorer.classes/read?maxRows=1000", "explorer.routines/read?maxRows=1000", "explorer.class/read?name=" _ $ZConvert(..#CLASSDOCUMENT, "O", "URL"), "explorer.routine/read?name=" _ $ZConvert(..#ROUTINEDOCUMENT, "O", "URL") {
            Do ..Request("GET", "/screens/" _ tRead _ tQuery, tUser, .tStatus, .tObject, .tText)
            Do $$$AssertEquals(tStatus, 200, tWhere _ " " _ tRead _ ": answered (" _ $Extract(tText, 1, 200) _ ")")
            Set tRows = $Select($IsObject(tObject) && $IsObject(tObject.%Get("rows")): tObject.rows, 1: [])
            Do $$$AssertTrue(tRows.%Size() > 0, tWhere _ " " _ tRead _ ": with rows")
            If (tNs '= "") && (tRead [ "explorer.routines/") {
                Set tOwn = 0
                Set tIterator = tRows.%GetIterator()
                While tIterator.%GetNext(.tIndex, .tRow) {
                    If tRow.%Get("Database") = tNs Set tOwn = 1
                }
                Do $$$AssertTrue(tOwn, tNs _ "'s Routines list carries rows from its own database")
            }
        }
    }
}

/// <p><b>An administrative screen</b> is refused 403 <code>AUTH.NOPRIVILEGE</code>, naming
/// <code>%Admin_Secure:USE</code>.</p>
/// <p>Mutation: give <class>OcuPilot.Screen.Descriptor.WebAppList</class> an empty pair set -> the
/// read answers 200 and this goes red.</p>
Method TestAnAdministrativeScreenIsRefusedNamingItsPair()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Do ..Request("GET", "/screens/webapp.list/read", $Parameter(..#FIXTURE, "DEVELOPERUSER"), .tStatus, .tObject, .tText)
    Do $$$AssertEquals(tStatus, 403, "the Web applications read is refused: " _ $Extract(tText, 1, 200))
    Set tCode = $Select($IsObject(tObject): tObject.%Get("code"), 1: "")
    Set tPair = $Select($IsObject(tObject) && $IsObject(tObject.%Get("detail")): tObject.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tCode _ "|" _ tPair, "AUTH.NOPRIVILEGE|%Admin_Secure:USE", "on the screen-privilege code, naming the pair")
}

/// <p><b>Logs (DW-1853)</b> opens on the analytics log alone: the area is available, the analytics
/// log is the one Logs screen the map opens and its read answers 200, and the messages.log read is
/// refused naming <code>%Admin_Operate:USE</code>.</p>
/// <p>Mutation: give <class>OcuPilot.Screen.Descriptor.LogMessageViewer</class> the pair set
/// <code>%DeepSee_Portal:USE</code> -> the messages.log read answers 200 and this goes red.</p>
Method TestLogsOpensOnTheAnalyticsLogAlone()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tUser = $Parameter(..#FIXTURE, "DEVELOPERUSER")
    Set tSC = ..Navigation(.tAreas, .tScreens)
    Do $$$AssertStatusOK(tSC, "the navigation map answers")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals($ListGet($Get(tAreas("logs")), 1), 1, "Logs is available")
    Set tOpen = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tScreens(tKey), 1, tEntry)
        If tKey = "" Quit
        If ($List(tEntry, 3) = "logs") && $List(tEntry, 1) Set tOpen = tOpen _ $Select(tOpen = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tOpen, "LogAnalyticsViewer", "on the analytics log alone")
    Do ..Request("GET", "/screens/logs.analytics/read", tUser, .tStatus, .tObject, .tText)
    Do $$$AssertEquals(tStatus, 200, "the analytics log reads: " _ $Extract(tText, 1, 200))
    Do ..Request("GET", "/screens/logs.messages/read", tUser, .tStatus, .tObject, .tText)
    Do $$$AssertEquals(tStatus, 403, "the messages.log read is refused: " _ $Extract(tText, 1, 200))
    Set tPair = $Select($IsObject(tObject) && $IsObject(tObject.%Get("detail")): tObject.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tPair, "%Admin_Operate:USE", "naming %Admin_Operate:USE")
}

/// <p><b>Below the floor</b>: a principal holding only the code database's READ is refused 403
/// <code>AUTH.NOADMIN</code>, and the reason names both halves of the floor. Every route is swept by
/// <class>OcuPilot.Test.ConfigGate</class>.</p>
/// <p>Mutation: restore the router's former reason -> the <code>%Development</code> assertion goes
/// red.</p>
Method TestBelowTheFloorIsRefusedNamingBothHalves()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Do ..Request("GET", "/instance", $Parameter(..#FIXTURE, "NEITHERUSER"), .tStatus, .tObject, .tText)
    Do $$$AssertEquals(tStatus, 403, "the identity call is refused: " _ $Extract(tText, 1, 200))
    Set tReason = $Select($IsObject(tObject): tObject.%Get("reason"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tObject): tObject.%Get("code"), 1: ""), "AUTH.NOADMIN", "on the no-administrative-privilege code")
    Do $$$AssertTrue((tReason [ "%Admin_") && (tReason [ "%Development"), "naming both halves of the floor: " _ tReason)
}

/// <p><b>Home's system information</b> answers the developer principal 200 with the five dashboard
/// members empty and mirror and production answered, and writes no <code>uisystem</code> line to
/// <code>messages.log</code>: the caller lacks <code>%DB_IRISSYS:READ</code>, so the sample is never
/// attempted (AD-8, AD-9).</p>
/// <p>Mutation: remove the <code>%DB_IRISSYS</code> guard from
/// <method>OcuPilot.Kernel.Shell.SystemInfo.Dashboard</method> -> a <code>uisystem</code> line is
/// written and this goes red.</p>
Method TestHomeSystemInformationLogsNothingForTheDeveloper()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tBefore = ..ConsoleLinesNaming(..#SYSTEMINFOLOGMARK)
    Do $$$AssertTrue(tBefore >= 0, "messages.log is readable")
    Do ..Request("GET", "/ui/system", $Parameter(..#FIXTURE, "DEVELOPERUSER"), .tStatus, .tObject, .tText)
    Do $$$AssertEquals(tStatus, 200, "System information answers: " _ $Extract(tText, 1, 200))
    Do $$$AssertTrue($IsObject(tObject), "its body parses")
    If '$IsObject(tObject) Quit
    For tI = 1:1:$Length(..#DASHBOARDMEMBERS, ",") {
        Set tMember = $Piece(..#DASHBOARDMEMBERS, ",", tI)
        Do $$$AssertEquals(tObject.%Get(tMember), "", tMember _ " reads not reported")
    }
    Do $$$AssertNotEquals(tObject.%Get("mirror"), "", "mirror state answers")
    Do $$$AssertNotEquals(tObject.%Get("production"), "", "production status answers")
    Do $$$AssertEquals(..ConsoleLinesNaming(..#SYSTEMINFOLOGMARK), tBefore, "and messages.log gained no uisystem line")
}

/// <p><b>Home's system information, admitted side.</b> An administrator holding
/// <code>%DB_IRISSYS:READ</code> without <code>%All</code> -- which passes every resource check,
/// misspelled ones included -- is answered the dashboard members, and nothing is logged.</p>
/// <p>Mutation: check a misspelled resource in
/// <method>OcuPilot.Kernel.Shell.SystemInfo.Dashboard</method>'s guard -> the members read empty and
/// this goes red.</p>
Method TestHomeSystemInformationAnswersAnAdministratorWithoutAll()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tBefore = ..ConsoleLinesNaming(..#SYSTEMINFOLOGMARK)
    Do $$$AssertTrue(tBefore >= 0, "messages.log is readable")
    Do ..Request("GET", "/ui/system", $Parameter(..#FIXTURE, "ADMINISTRATORUSER"), .tStatus, .tObject, .tText)
    Do $$$AssertEquals(tStatus, 200, "System information answers: " _ $Extract(tText, 1, 200))
    Do $$$AssertTrue($IsObject(tObject), "its body parses")
    If '$IsObject(tObject) Quit
    Do $$$AssertNotEquals(tObject.%Get("uptime"), "", "uptime is reported")
    Do $$$AssertTrue($ListFind($ListBuild("Normal", "Troubled"), tObject.%Get("writeDaemon")), "the write daemon is reported: " _ tObject.%Get("writeDaemon"))
    Do $$$AssertEquals(..ConsoleLinesNaming(..#SYSTEMINFOLOGMARK), tBefore, "and messages.log gained no uisystem line")
}

/// <p><b>Classic parity (AC2).</b> Every screen the map opens to the developer principal is one of
/// <parameter>SCREENS</parameter>, and each one replacing a classic page has that page's compiled
/// <code>RESOURCE</code> empty, or holding a member the principal holds and the screen declares as
/// its own pair (AD-8, AD-44), so nothing past the floor opens what the classic portal would refuse
/// it, whichever floor member let the caller in. A member is read as the classic portal reads it:
/// <code>resource[:permission]</code>, <code>USE</code> when no permission is given. A page that
/// compiles no <code>RESOURCE</code> is judged by its <parameter>INTERNALCHECKS</parameter> entry,
/// and fails without one.</p>
/// <p>Mutations: give <class>OcuPilot.Screen.Descriptor.WebAppList</class> an empty pair set -> it
/// opens, outside the roster, its page's <code>%Admin_Secure</code> unheld; give
/// <class>OcuPilot.Screen.Descriptor.ExplorerClassList</class> an empty pair set -> it still opens,
/// declaring no pair from its page's <code>%Development</code>; either way this goes red.</p>
Method TestEveryOpenScreenMatchesItsClassicPage()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tSC = ..Navigation(.tAreas, .tScreens)
    Do $$$AssertStatusOK(tSC, "the navigation map answers")
    If $$$ISERR(tSC) Quit
    Set tDeclared = $ListFromString(..#SCREENS)
    Set tChecked = 0
    Set tKey = ""
    For {
        Set tKey = $Order(tScreens(tKey), 1, tEntry)
        If tKey = "" Quit
        If '$List(tEntry, 1) Continue
        Do $$$AssertTrue($ListFind(tDeclared, tKey), tKey _ ": an open screen is a declared one")
        Set tClass = ..#DESCRIPTORPACKAGE _ tKey
        If '##class(%Dictionary.CompiledClass).%ExistsId(tClass) Continue
        Set tPage = $ClassMethod(tClass, "ClassicPage")
        If tPage = "" Continue
        Set tChecked = tChecked + 1
        Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId(tPage), tKey _ ": its classic page " _ tPage _ " is compiled")
        Set tResource = ..ClassicResource(tPage, .tHasResource)
        Do $$$AssertTrue(tHasResource || (tResource '= ""), tKey _ ": " _ tPage _ " declares no RESOURCE, and no check of its own is recorded in INTERNALCHECKS")
        Set tAdmitted = tHasResource && (tResource = "")
        Set tDeclares = (tResource = "")
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs")
        For tI = 1:1:$Length(tResource, ",") {
            Set tMember = $Piece($Piece(tResource, ",", tI), ":", 1)
            Set tPermission = $Piece($Piece(tResource, ",", tI), ":", 2)
            If tPermission = "" Set tPermission = "USE"
            If tMember = "" Continue
            If ..Held(..PreparedComposed, tMember, tPermission) Set tAdmitted = 1
            If $ListFind(tPairs, $ListBuild(tMember, tPermission)) Set tDeclares = 1
        }
        Do $$$AssertTrue(tAdmitted, tKey _ ": " _ tPage _ "'s RESOURCE '" _ tResource _ "' admits the developer")
        Do $$$AssertTrue(tDeclares, tKey _ ": declares its own pair from " _ tPage _ "'s RESOURCE '" _ tResource _ "', not the floor alone")
    }
    Do $$$AssertTrue(tChecked > 0, "at least one open screen replaces a classic page: " _ tChecked)
}

/// <p><b>Tools (AC2).</b> Of every tool the registry lists, the ones whose required pairs the
/// developer principal holds are exactly <parameter>TOOLS</parameter>, and none of them is a
/// write.</p>
/// <p>Mutation: give <class>OcuPilot.Screen.Descriptor.WebAppList</class> an empty pair set ->
/// <code>webapp.list.read</code> joins the held set and this goes red.</p>
Method TestTheToolsTheDeveloperHoldsAreTheDeclaredTen()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tool registry lists")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(tTools.%Size() > 0, "it lists tools: " _ tTools.%Size())
    Set tHeld = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)
        Do $$$AssertTrue(tResolved, tTool.name _ ": its required pairs resolve")
        If 'tResolved Continue
        Set tHolds = 1
        For tI = 1:1:$ListLength(tPairs) {
            Set tPair = $List(tPairs, tI)
            If '..Held(..PreparedComposed, $List(tPair, 1), $List(tPair, 2)) Set tHolds = 0
        }
        If 'tHolds Continue
        Set tHeld = tHeld _ $Select(tHeld = "": "", 1: ",") _ tTool.name
        Do $$$AssertNotEquals(tTool.kind, "write", tTool.name _ ": a tool the developer holds is not a write")
    }
    Do $$$AssertEquals(..Sorted(tHeld), ..Sorted(..#TOOLS), "the tools the developer holds are the declared ten")
}

/// <p>The compiled <code>RESOURCE</code> of the classic page <var>pPage</var>, with
/// <var>pDeclared</var> 1. A page that compiles no <code>RESOURCE</code> parameter answers its
/// <parameter>INTERNALCHECKS</parameter> entry, or <code>""</code>, with <var>pDeclared</var> 0.</p>
ClassMethod ClassicResource(pPage As %String, Output pDeclared As %Boolean) As %String
{
    Set tParameter = ##class(%Dictionary.CompiledParameter).%OpenId(pPage _ "||RESOURCE")
    Set pDeclared = $IsObject(tParameter)
    If pDeclared Quit tParameter.Default
    Set tFound = ""
    For tI = 1:1:$Length(..#INTERNALCHECKS, ",") {
        Set tEntry = $Piece(..#INTERNALCHECKS, ",", tI)
        If $Piece(tEntry, ":", 1) = pPage Set tFound = $Piece(tEntry, ":", 2)
    }
    Quit tFound
}

/// <p>How many lines of the instance's <code>messages.log</code> contain <var>pText</var>, -1 when
/// the file cannot be read.</p>
ClassMethod ConsoleLinesNaming(pText As %String) As %Integer
{
    Set tFound = -1
    Try {
        Set tStream = ##class(%Stream.FileCharacter).%New()
        If $$$ISERR(tStream.LinkToFile(##class(%File).ManagerDirectory() _ "messages.log")) Quit
        Set tFound = 0
        While 'tStream.AtEnd {
            If tStream.ReadLine() [ pText Set tFound = tFound + 1
        }
    } Catch {
        Set tFound = -1
    }
    Quit tFound
}

}

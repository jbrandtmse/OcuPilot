/// <p>Story 20.14's widened floor (DW-2140), as real principals holding <code>%Ens_Portal:USE</code>
/// meet it over HTTP (AD-8, AD-29, AD-44, AD-62): each of <parameter>KINDS</parameter> signs in,
/// opens exactly the areas, screens and tools <method>Areas</method>, <method>Screens</method> and
/// <method>Tools</method> declare for it, and is refused every other surface naming the pair it
/// lacks. Derived legs hold the rosters: every screen opened replaces a classic page whose compiled
/// <code>RESOURCE</code> the principal holds a declared pair of, and no principal holds a write
/// tool. The routes are <class>OcuPilot.Test.InteropFloorRoutes</class>', the turn
/// <class>OcuPilot.Test.InteropFloorTurn</class>'s, and the pair every surface declares
/// <class>OcuPilot.Test.InteropFloorOwnPairs</class>'.</p>
/// <p>It needs <parameter>ARMINGVARIABLE</parameter> armed: <class>OcuPilot.Test.InteropFloorFixture</class>
/// creates the principals in <method>OnBeforeAllTests</method>, which reads their grants back, and
/// removes them in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.InteropFloor Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropFloorFixture";

/// <p>The principal kinds, in roster order: the <code>%Ens_Portal</code> holder, then the stock
/// Monitor, Operator and Administrator roles.</p>
Parameter KINDS = "portal,monitor,operator,administrator";

/// <p>The package the screens below are declared in.</p>
Parameter DESCRIPTORPACKAGE = "OcuPilot.Screen.Descriptor.";

/// <p>What the <code>%Ens_Portal</code> holder and the Monitor role open on the floor alone: the
/// agent's owner-scoped screens, Home (an empty classic <code>RESOURCE</code>) and the analytics log
/// (the public <code>%DeepSee_Portal</code>).</p>
Parameter BASESCREENS = "AgentGuardrails,AgentLedger,AgentTranscript,AgentTranscripts,Home,LogAnalyticsViewer";

/// <p>See <parameter>BASESCREENS</parameter>.</p>
Parameter BASEAREAS = "agent,analytics,home,logs";

/// <p>See <parameter>BASESCREENS</parameter>.</p>
Parameter BASETOOLS = "agent.transcripts.read,logs.analytics.read,shell.instance.read,shell.namespaces.read,shell.privileges.read,shell.screen.open";

/// <p>What the Operator role adds: Productions through <code>%Ens_ProductionConfig:READ</code> and the
/// event log through <code>%Ens_EventLog:USE</code>.</p>
Parameter OPERATORSCREENS = "InteropProductionList,LogEventViewer";

/// <p>See <parameter>OPERATORSCREENS</parameter>.</p>
Parameter OPERATORTOOLS = "interop.productions.read,logs.eventlog.read";

/// <p>What the Administrator role adds beside the Operator's: the three code lists, each through its
/// own <code>%Ens_Code:READ</code>.</p>
Parameter ADMINISTRATORSCREENS = "InteropProcessList,InteropRuleList,InteropTransformList";

/// <p>See <parameter>ADMINISTRATORSCREENS</parameter>.</p>
Parameter ADMINISTRATORTOOLS = "interop.processes.read,interop.rules.read,interop.transforms.read";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back the principals' grants.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

/// <p>Each kind's composed grants (<method>OcuPilot.Test.InteropFloorFixture.Composed</method>), by kind.</p>
Property PreparedComposed As %DynamicObject;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Set ..PreparedComposed = {}
    Quit $$$OK
}

/// <p>Refuse unless armed, create the four principals and read their grants back: each holds
/// <code>%Ens_Portal:USE</code> and the code database's READ, and none holds an administrative
/// resource or <code>%Development:USE</code>.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropFloor creates IRIS users and roles, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tCode = $ClassMethod("OcuPilot.Test.DeveloperFloorFixture", "CodeResource")
    Set tOk = 1
    Set tProblem = ""
    For tI = 1:1:$Length(..#KINDS, ",") {
        Set tKind = $Piece(..#KINDS, ",", tI)
        Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", ..PreparedPassword, tKind, .tUser)
        If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "Composed", tUser, .tComposed)
        If $$$ISERR(tSC) Quit
        Do ..PreparedComposed.%Set(tKind, tComposed)
        Set tHolds = ..Held(tComposed, "%Ens_Portal", "USE") && ..Held(tComposed, tCode, "READ") && '..Held(tComposed, "%Development", "USE") && '$ClassMethod(..#FIXTURE, "HoldsAdministrative", tComposed)
        If 'tHolds Set tOk = 0, tProblem = tProblem _ " " _ tKind
    }
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSetupOk = tOk
    If 'tOk Quit $$$ERROR($$$GeneralError, "Setup could not read back the grants of:" _ tProblem)
    Quit $$$OK
}

/// <p>Remove the principals and both roles, and return a failing status if any survives.</p>
Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropFloor teardown left:" _ tLeft)
    Quit $$$OK
}

/// <p>The areas the map opens to kind <var>pKind</var>.</p>
ClassMethod Areas(pKind As %String) As %String
{
    Quit ..#BASEAREAS _ $Select($ListFind($ListBuild("operator", "administrator"), pKind): ",interoperability", 1: "")
}

/// <p>The screens the map opens to kind <var>pKind</var>.</p>
ClassMethod Screens(pKind As %String) As %String
{
    Set tList = ..#BASESCREENS
    If $ListFind($ListBuild("operator", "administrator"), pKind) Set tList = tList _ "," _ ..#OPERATORSCREENS
    If pKind = "administrator" Set tList = tList _ "," _ ..#ADMINISTRATORSCREENS
    Quit tList
}

/// <p>The tools whose required pairs kind <var>pKind</var> holds.</p>
ClassMethod Tools(pKind As %String) As %String
{
    Set tList = ..#BASETOOLS
    If $ListFind($ListBuild("operator", "administrator"), pKind) Set tList = tList _ "," _ ..#OPERATORTOOLS
    If pKind = "administrator" Set tList = tList _ "," _ ..#ADMINISTRATORTOOLS
    Quit tList
}

/// <p>Whether <var>pComposed</var> holds <var>pPermission</var> on <var>pResource</var>.</p>
ClassMethod Held(pComposed As %DynamicObject, pResource As %String, pPermission As %String) As %Boolean
{
    Quit ''$ClassMethod(..#FIXTURE, "Holds", pComposed, pResource, pPermission)
}

/// <p>One request as kind <var>pKind</var>; <var>pObject</var> is the parsed body, or <code>""</code>.</p>
Method Request(pMethod As %String, pPath As %String, pKind As %String, Output pStatus As %Integer, Output pObject, Output pText As %String) As %Status
{
    Set pObject = ""
    Set tSC = $ClassMethod(..#FIXTURE, "Call", pMethod, pPath, $ClassMethod(..#FIXTURE, "UserOf", pKind), ..PreparedPassword, .pStatus, .pText, .tHeaders)
    Try {
        If $Get(pText) '= "" Set pObject = ##class(%DynamicAbstractObject).%FromJSON(pText)
    } Catch {
        Set pObject = ""
    }
    Quit tSC
}

/// <p>Kind <var>pKind</var>'s navigation map: <var>pAreas</var>(key) and <var>pScreens</var>(descriptor
/// short name) each <code>$ListBuild(allowed, failedPair, area)</code>.</p>
Method Navigation(pKind As %String, Output pAreas, Output pScreens) As %Status
{
    Kill pAreas, pScreens
    Set tSC = ..Request("GET", "/navigation", pKind, .tStatus, .tMap, .tText)
    If $$$ISERR(tSC) Quit tSC
    If (tStatus '= 200) || '$IsObject(tMap) Quit $$$ERROR($$$GeneralError, pKind _ ": the navigation map answered " _ tStatus _ ": " _ $Extract(tText, 1, 300))
    Set tAreas = tMap.areas.%GetIterator()
    While tAreas.%GetNext(.tIndex, .tArea) {
        Set pAreas(tArea.key) = $ListBuild(''tArea.allowed, tArea.%Get("failedPair"), tArea.key)
        Set tScreens = tArea.screens.%GetIterator()
        While tScreens.%GetNext(.tScreenIndex, .tScreen) {
            Set tClass = ##class(OcuPilot.Screen.Registry).DescriptorForRoute(tScreen.route)
            Set tName = $Select(tClass = "": tScreen.route, 1: $Piece(tClass, ..#DESCRIPTORPACKAGE, 2))
            Set pScreens(tName) = $ListBuild(''tScreen.allowed, tScreen.%Get("failedPair"), tArea.key)
        }
    }
    Quit $$$OK
}

/// <p>The failed pair of a refused read: <code>code|pair</code>.</p>
ClassMethod Refusal(pObject, pStatus As %Integer) As %String
{
    Set tCode = $Select($IsObject(pObject): pObject.%Get("code"), 1: "")
    Set tPair = $Select($IsObject(pObject) && $IsObject(pObject.%Get("detail")): pObject.detail.%Get("failedPair"), 1: "")
    Quit pStatus _ "|" _ tCode _ "|" _ tPair
}

/// <p><b>Sign-in (DW-2140).</b> Each principal clears the floor: the identity call answers 200 and the
/// navigation map opens exactly its areas and screens, every other area and screen reading
/// unavailable with its failed pair.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Gate.FloorResources</method> without
/// <parameter>OcuPilot.Screen.Gate.INTEROPRESOURCE</parameter> -> the identity call answers 403
/// <code>AUTH.NOADMIN</code> and this goes red. Dropping <code>%Ens_EventLog:USE</code> from
/// <class>OcuPilot.Screen.Descriptor.LogEventViewer</class> -> the <code>%Ens_Portal</code> holder
/// opens the event log and this goes red.</p>
Method TestEachPrincipalSignsInAndOpensExactlyItsRoster()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    For tI = 1:1:$Length(..#KINDS, ",") {
        Set tKind = $Piece(..#KINDS, ",", tI)
        Do ..Request("GET", "/instance", tKind, .tStatus, .tObject, .tText)
        Do $$$AssertEquals(tStatus, 200, tKind _ ": the identity call clears the floor: " _ $Extract(tText, 1, 300))
        Set tSC = ..Navigation(tKind, .tAreas, .tScreens)
        Do $$$AssertStatusOK(tSC, tKind _ ": the navigation map answers")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Test.DeveloperFloor).AllowedOf(.tAreas), ##class(OcuPilot.Test.DeveloperFloor).Sorted(..Areas(tKind)), tKind _ ": exactly the declared areas open")
        Do $$$AssertEquals(##class(OcuPilot.Test.DeveloperFloor).AllowedOf(.tScreens), ##class(OcuPilot.Test.DeveloperFloor).Sorted(..Screens(tKind)), tKind _ ": exactly the declared screens open")
        For tScope = "area", "screen" {
            Set tKey = ""
            For {
                If tScope = "area" { Set tKey = $Order(tAreas(tKey), 1, tEntry) } Else { Set tKey = $Order(tScreens(tKey), 1, tEntry) }
                If tKey = "" Quit
                If $List(tEntry, 1) Continue
                Do $$$AssertNotEquals($List(tEntry, 2), "", tKind _ " " _ tScope _ " " _ tKey _ ": unavailable, naming its failed pair")
            }
        }
    }
}

/// <p><b>Interoperability reads.</b> Productions answers the Operator and Administrator roles and
/// refuses the <code>%Ens_Portal</code> holder naming <code>%Ens_ProductionConfig:READ</code>;
/// Business processes answers the Administrator with rows and refuses the Operator naming
/// <code>%Ens_Code:READ</code>.</p>
/// <p>Mutation: give <class>OcuPilot.Screen.Descriptor.InteropProductionList</class> and
/// <parameter>OcuPilot.Port.InteropPort.PRODUCTIONPAIRS</parameter>, the two gates the read meets, the
/// pair set <code>%Ens_Portal:USE</code> alone -> the <code>%Ens_Portal</code> holder reads
/// Productions and this goes red.</p>
Method TestTheInteroperabilityReadsFollowTheirOwnPairs()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Do ..Request("GET", "/screens/interop.productions/read?ns=" _ tNs, "portal", .tStatus, .tObject, .tText)
    Do $$$AssertEquals(..Refusal(tObject, tStatus), "403|AUTH.NOPRIVILEGE|%Ens_ProductionConfig:READ", "the %Ens_Portal holder is refused Productions: " _ $Extract(tText, 1, 200))
    Do ..Request("GET", "/screens/interop.productions/read?ns=" _ tNs, "operator", .tStatus, .tObject, .tText)
    Do $$$AssertEquals(tStatus, 200, "the Operator reads Productions: " _ $Extract(tText, 1, 200))
    Do ..Request("GET", "/screens/interop.processes/read?ns=" _ tNs, "operator", .tStatus, .tObject, .tText)
    Do $$$AssertEquals(..Refusal(tObject, tStatus), "403|AUTH.NOPRIVILEGE|%Ens_Code:READ", "the Operator is refused Business processes: " _ $Extract(tText, 1, 200))
    Do ..Request("GET", "/screens/interop.processes/read?ns=" _ tNs, "administrator", .tStatus, .tObject, .tText)
    Do $$$AssertEquals(tStatus, 200, "the Administrator reads Business processes: " _ $Extract(tText, 1, 200))
    Set tRows = $Select($IsObject(tObject) && $IsObject(tObject.%Get("rows")): tObject.rows, 1: [])
    Do $$$AssertTrue(tRows.%Size() > 0, "with rows")
}

/// <p><b>Event log.</b> The Operator reads it; the <code>%Ens_Portal</code> holder is refused naming
/// <code>%Ens_EventLog:USE</code>.</p>
/// <p>Mutation: drop <code>%Ens_EventLog:USE</code> from both
/// <class>OcuPilot.Screen.Descriptor.LogEventViewer</class> and
/// <parameter>OcuPilot.Port.LogSourcePort.EVENTLOGPAIRS</parameter>, the two gates the read meets ->
/// the <code>%Ens_Portal</code> holder reads the log and this goes red.</p>
Method TestTheEventLogOpensForTheOperatorAlone()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Do ..Request("GET", "/screens/logs.eventlog/read", "portal", .tStatus, .tObject, .tText)
    Do $$$AssertEquals(..Refusal(tObject, tStatus), "403|AUTH.NOPRIVILEGE|%Ens_EventLog:USE", "the %Ens_Portal holder is refused the event log: " _ $Extract(tText, 1, 200))
    Do ..Request("GET", "/screens/logs.eventlog/read", "operator", .tStatus, .tObject, .tText)
    Do $$$AssertEquals(tStatus, 200, "the Operator reads the event log: " _ $Extract(tText, 1, 200))
}

/// <p><b>An administrative screen</b> is refused the <code>%Ens_Portal</code> holder 403
/// <code>AUTH.NOPRIVILEGE</code>, naming <code>%Admin_Secure:USE</code>.</p>
/// <p>Mutation: give <class>OcuPilot.Screen.Descriptor.WebAppList</class> an empty pair set -> the
/// read answers 200 and this goes red.</p>
Method TestAnAdministrativeScreenIsRefusedNamingItsPair()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Do ..Request("GET", "/screens/webapp.list/read", "portal", .tStatus, .tObject, .tText)
    Do $$$AssertEquals(..Refusal(tObject, tStatus), "403|AUTH.NOPRIVILEGE|%Admin_Secure:USE", "the Web applications read is refused, naming the pair: " _ $Extract(tText, 1, 200))
}

/// <p><b>Another namespace.</b> The stock roles grant no <code>%DB_USER</code>, so each principal's
/// map for <code>USER</code> is refused 403 <code>NS.DENIED</code> naming <code>%DB_USER:READ</code>.</p>
/// <p>Mutation: grant <parameter>OcuPilot.Test.InteropFloorFixture.CODEROLE</parameter>
/// <code>%DB_USER:R</code> -> the map answers 200 and this goes red.</p>
Method TestAnotherNamespaceIsDeniedUnchanged()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    For tI = 1:1:$Length(..#KINDS, ",") {
        Set tKind = $Piece(..#KINDS, ",", tI)
        Do ..Request("GET", "/navigation?ns=USER", tKind, .tStatus, .tObject, .tText)
        Do $$$AssertEquals(..Refusal(tObject, tStatus), "403|NS.DENIED|%DB_USER:READ", tKind _ ": USER is denied, naming the pair: " _ $Extract(tText, 1, 200))
    }
}

/// <p><b>Classic parity (AC1).</b> Every screen the map opens to each principal is one of its
/// declared screens, and each one replacing a classic page has that page's compiled
/// <code>RESOURCE</code> empty, or holding a member the principal holds and the screen declares as its
/// own pair (AD-8, AD-44), so nothing opens that the classic portal would refuse. A member is read as
/// the classic portal reads it: <code>resource[:permission]</code>, <code>USE</code> when no
/// permission is given.</p>
/// <p>Mutation: give <class>OcuPilot.Screen.Descriptor.InteropProductionList</class> the pair set
/// <code>%Ens_Portal:USE</code> alone -> the Operator opens it declaring no pair from its page's
/// <code>RESOURCE</code>, and this goes red.</p>
Method TestEveryOpenScreenMatchesItsClassicPage()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tChecked = 0
    For tI = 1:1:$Length(..#KINDS, ",") {
        Set tKind = $Piece(..#KINDS, ",", tI)
        Set tComposed = ..PreparedComposed.%Get(tKind)
        Set tSC = ..Navigation(tKind, .tAreas, .tScreens)
        Do $$$AssertStatusOK(tSC, tKind _ ": the navigation map answers")
        If $$$ISERR(tSC) Continue
        Set tDeclared = $ListFromString(..Screens(tKind))
        Set tKey = ""
        For {
            Set tKey = $Order(tScreens(tKey), 1, tEntry)
            If tKey = "" Quit
            If '$List(tEntry, 1) Continue
            Do $$$AssertTrue($ListFind(tDeclared, tKey), tKind _ " " _ tKey _ ": an open screen is a declared one")
            Set tClass = ..#DESCRIPTORPACKAGE _ tKey
            If '##class(%Dictionary.CompiledClass).%ExistsId(tClass) Continue
            Set tPage = $ClassMethod(tClass, "ClassicPage")
            If tPage = "" Continue
            Set tChecked = tChecked + 1
            Do $$$AssertTrue(##class(OcuPilot.Test.DeveloperFloor).Compiled(tPage), tKind _ " " _ tKey _ ": its classic page " _ tPage _ " is compiled")
            Set tResource = ##class(OcuPilot.Test.DeveloperFloor).ClassicResource(tPage, .tHasResource)
            Do $$$AssertTrue(tHasResource || (tResource '= ""), tKind _ " " _ tKey _ ": " _ tPage _ " compiles a RESOURCE or records its check")
            Set tOk = tHasResource && (tResource = "")
            Set tPairs = $ClassMethod(tClass, "PrivilegePairs")
            For tJ = 1:1:$Length(tResource, ",") {
                Set tMember = $Piece($Piece(tResource, ",", tJ), ":", 1)
                Set tPermission = $Piece($Piece(tResource, ",", tJ), ":", 2)
                If tPermission = "" Set tPermission = "USE"
                If tMember = "" Continue
                If ..Held(tComposed, tMember, tPermission) && $ListFind(tPairs, $ListBuild(tMember, tPermission)) Set tOk = 1
            }
            Do $$$AssertTrue(tOk, tKind _ " " _ tKey _ ": declares a pair from " _ tPage _ "'s RESOURCE '" _ tResource _ "' that the principal holds")
        }
    }
    Do $$$AssertTrue(tChecked > 0, "at least one open screen replaces a classic page: " _ tChecked)
}

/// <p><b>Tools.</b> Of every tool the registry lists, the ones whose required pairs each principal
/// holds are exactly its <method>Tools</method> roster, and none of them is a write tool: a write
/// also needs WRITE on a database no stock role grants.</p>
/// <p>Mutation: give <class>OcuPilot.Screen.Descriptor.WebAppList</class> an empty pair set ->
/// <code>webapp.list.read</code> joins every principal's held set and this goes red.</p>
Method TestTheToolsEachPrincipalHoldsAreItsRoster()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tool registry lists")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(tTools.%Size() > 0, "it lists tools: " _ tTools.%Size())
    For tI = 1:1:$Length(..#KINDS, ",") {
        Set tKind = $Piece(..#KINDS, ",", tI)
        Set tComposed = ..PreparedComposed.%Get(tKind)
        Set tHeld = ""
        Set tWrites = ""
        Set tIterator = tTools.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tTool) {
            Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)
            Do $$$AssertTrue(tResolved, tTool.name _ ": its required pairs resolve")
            If 'tResolved Continue
            Set tHolds = 1
            For tJ = 1:1:$ListLength(tPairs) {
                Set tPair = $List(tPairs, tJ)
                If '..Held(tComposed, $List(tPair, 1), $List(tPair, 2)) Set tHolds = 0
            }
            If 'tHolds Continue
            Set tHeld = tHeld _ $Select(tHeld = "": "", 1: ",") _ tTool.name
            If tTool.kind = "write" Set tWrites = tWrites _ $Select(tWrites = "": "", 1: ",") _ tTool.name
        }
        Do $$$AssertEquals(##class(OcuPilot.Test.DeveloperFloor).Sorted(tHeld), ##class(OcuPilot.Test.DeveloperFloor).Sorted(..Tools(tKind)), tKind _ ": the tools it holds are its roster")
        Do $$$AssertEquals(tWrites, "", tKind _ ": and it holds no write tool")
    }
}

}

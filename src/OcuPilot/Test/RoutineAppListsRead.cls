/// <p>Pins Story 18.12's two privileged routine application reads: the roles list
/// (<code>webapp.routineapproles</code>) and the routines list (<code>webapp.routineapproutines</code>) each answer one row
/// per entry of the vendor's own <code>GET</code> arrays, by the screen's route and by the agent's read tool; an empty
/// list and an absent name answer no rows, a name a web application holds is 404 <code>PRIVROUTINE.TYPE</code>, and no
/// name is 400 <code>READ.CRITERION</code>. The integration leg reads the routines through the tool, mints
/// <code>webapp.routineapps.update</code> with those rows less one and the roles as read, and confirms: the proposal
/// changes <code>Routines</code> alone and the instance keeps the other entry and the roles.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates probe privileged routine
/// applications (<class>OcuPilot.Test.RoutineAppProbe</class>), changes one and sets the governance policy. Every probe
/// application is removed by exact name, and after each test the application list reads as that test found it.</p>
Class OcuPilot.Test.RoutineAppListsRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.RoutineAppProbe";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RoutineAppUpdate";

Parameter PORT = "OcuPilot.Port.AdminPort";

Parameter APP = "OcuProbe1831A";

Parameter EMPTYAPP = "OcuProbe1831E";

Parameter ABSENTAPP = "OcuProbe1831Z";

Parameter ROLES = "webapp.routineapproles";

Parameter ROUTINES = "webapp.routineapproutines";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RoutineAppListsRead creates probe privileged routine applications on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts")
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Kill tSettings
    Set tSettings("webapp.routineapps.update") = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe application is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the application list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedFacts, "the application list reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
}

/// <p>With two entries in each list, the screen's route and the read tool each answer one row per entry, equal to the
/// vendor's own array and carrying that list's fields alone; an application with empty lists and one the instance does
/// not hold answer no rows; a name a web application holds is 404 <code>PRIVROUTINE.TYPE</code>; no name is 400
/// <code>READ.CRITERION</code>; and the name in another case reads the same application.</p>
/// <p>Mutation (Rule 19): point the roles read's <code>rows</code> at <code>Routines</code> in
/// <class>OcuPilot.Screen.Descriptor.RoutineAppRoleList</class> -- the roles legs go red; drop <code>%Admin_Secure</code>
/// from its pairs -- <method>OcuPilot.Test.RoutineAppGate.TestWithoutTheAreasResourceBothListReadsAreRefusedByName</method>
/// goes red.</p>
Method TestBothListsAnswerOneRowPerEntryByRouteAndTool()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, ..Both()), "a probe application holding two entries in each list")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#EMPTYAPP, {"Description": "empty", "Enabled": true, "Resource": "", "MatchRoles": [], "Routines": []}), "and one holding neither list")
    Set tStored = $ClassMethod(..#PROBE, "Stored", "", ..#APP)
    Do $$$AssertTrue($IsObject(tStored), "the vendor's GET reads the application")
    If '$IsObject(tStored) Quit
    For tCase = $ListBuild(..#ROLES, "MatchRoles", "MatchRole,TargetRoles"), $ListBuild(..#ROUTINES, "Routines", "Db,RoutineOrClass,Type") {
        Set tScreen = $List(tCase, 1)
        Set tMember = $List(tCase, 2)
        Set tVendor = tStored.%Get(tMember)
        Do $$$AssertEquals(tVendor.%Size(), 2, tScreen _ ": the vendor holds two entries")
        Set tRouteRows = ..RouteRows(tScreen, ..#APP)
        Do $$$AssertEquals(tRouteRows.%Size(), 2, tScreen _ ": the route answers one row per entry")
        Do $$$AssertEquals(..Canonical(tRouteRows), ..Canonical(tVendor), tScreen _ ": the route's rows are the vendor's array")
        Set tToolRows = ..ToolRows(tScreen, {"name": (..#APP)}, .tHttp, .tCode)
        Do $$$AssertEquals(tToolRows.%Size(), 2, tScreen _ ": the tool answers one row per entry")
        Do $$$AssertEquals(..Canonical(tToolRows), ..Canonical(tVendor), tScreen _ ": the tool's rows are the vendor's array")
        Set tIterator = tToolRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tRow), $List(tCase, 3), tScreen _ ": row " _ tIndex _ " carries the list's fields and nothing else")
        }
        Do $$$AssertEquals(..RouteRows(tScreen, $ZConvert(..#APP, "L")).%Size(), 2, tScreen _ ": the name in another case reads the same application")
        Set tRouteEmpty = ..RouteRows(tScreen, ..#EMPTYAPP, .tStatus, .tCode)
        Set tToolEmpty = ..ToolRows(tScreen, {"name": (..#EMPTYAPP)}, .tHttp, .tCode)
        Do $$$AssertEquals(tStatus _ " " _ tHttp _ " " _ tRouteEmpty.%Size() _ " " _ tToolEmpty.%Size(), "200 200 0 0", tScreen _ ": empty lists are answered, with no rows, by the route and the tool")
        Set tRouteAbsent = ..RouteRows(tScreen, ..#ABSENTAPP, .tStatus, .tCode)
        Set tToolAbsent = ..ToolRows(tScreen, {"name": (..#ABSENTAPP)}, .tHttp, .tCode)
        Do $$$AssertEquals(tStatus _ " " _ tHttp _ " " _ tRouteAbsent.%Size() _ " " _ tToolAbsent.%Size(), "200 200 0 0", tScreen _ ": an application the instance does not hold is answered, with no rows, by the route and the tool")
        Do ..RouteRows(tScreen, "/csp/user", .tStatus, .tCode)
        Do $$$AssertEquals(tStatus _ " " _ tCode, "404 " _ ##class(OcuPilot.Api.RoutineAppError).#TYPE, tScreen _ ": a web application's name is refused by the route")
        Do ..ToolRows(tScreen, {"name": "/csp/user"}, .tHttp, .tCode)
        Do $$$AssertEquals(tHttp _ " " _ tCode, "404 " _ ##class(OcuPilot.Api.RoutineAppError).#TYPE, tScreen _ ": and by the tool")
        Do ..RouteRows(tScreen, "", .tStatus, .tCode)
        Do $$$AssertEquals(tStatus _ " " _ tCode, "400 " _ ##class(OcuPilot.Api.Error).#READCRITERION, tScreen _ ": no name is refused by the route")
        Do ..ToolRows(tScreen, {}, .tHttp, .tCode)
        Do $$$AssertEquals(tHttp _ " " _ tCode, "400 " _ ##class(OcuPilot.Api.Error).#READCRITERION, tScreen _ ": and by the tool")
    }
}

/// <p>Integration: the routines read through the tool, sent back less one entry with the roles as read, change
/// <code>Routines</code> alone. The proposal's changed fields name it alone, the confirm is accepted, and the instance
/// keeps the entry that was not removed and the roles it held.</p>
/// <p>Mutation (Rule 19): drop <code>Routines</code> from
/// <method>OcuPilot.Screen.Tool.RoutineAppUpdate.SettableFields</method> -- the mint refuses the routines and this goes
/// red.</p>
Method TestAnAgentSendsTheRoutinesItReadLessOneEntry()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, ..Both(1)), "a probe application holding two routines and one role entry")
    Set tTargets = $ClassMethod(..#PROBE, "Targets", ..#APP, "")
    Set tRoutineRows = ..ToolRows(..#ROUTINES, {"name": (..#APP)})
    Set tRoleRows = ..ToolRows(..#ROLES, {"name": (..#APP)})
    Do $$$AssertEquals(tRoutineRows.%Size() _ " " _ tRoleRows.%Size(), "2 1", "the tools answer both routines and the one role entry")
    If tRoutineRows.%Size() '= 2 Quit
    Set tKept = tRoutineRows.%Get(0)
    Set tRemoved = tRoutineRows.%Get(1)
    Set tSent = ##class(%DynamicArray).%FromJSON("[" _ tKept.%ToJSON() _ "]")
    Set tArgs = {"Name": (..#APP)}
    Do tArgs.%Set("Routines", tSent)
    Do tArgs.%Set("MatchRoles", ##class(%DynamicArray).%FromJSON(tRoleRows.%ToJSON()))
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, ..#APP, tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the update is minted (" _ tProblem _ ")")
    If '$IsObject($Get(tProposal)) Quit
    Set tChanged = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tChange) {
        Set tChanged = tChanged _ $Select(tChanged = "": "", 1: ",") _ tChange.%Get("field")
    }
    Do $$$AssertEquals(tChanged, "Routines", "the proposal changes Routines alone")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and is confirmed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Entries", ..#APP), tKept.%Get("RoutineOrClass") _ ":" _ tKept.%Get("Db") _ ":" _ tKept.%Get("Type"), "the instance keeps the entry that was sent, and " _ tRemoved.%Get("RoutineOrClass") _ " is gone")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Targets", ..#APP, ""), tTargets, "and the roles are as they were")
}

/// <p>A body for a probe application: two entries in each list, or, with <var>pOneRole</var>, one role entry holding two
/// target roles. The roles are ones every instance defines.</p>
ClassMethod Both(pOneRole As %Boolean = 0) As %DynamicObject
{
    Set tRoles = [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM", "%Developer"]}]
    If 'pOneRole Set tRoles = [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}, {"MatchRole": "%Developer", "TargetRoles": ["%Manager", "%Operator"]}]
    Quit {"Description": "lists", "Enabled": true, "Resource": "", "MatchRoles": (tRoles), "Routines": [{"RoutineOrClass": "OcuProbe1831.First", "Db": "HSCUSTOM", "Type": "Class"}, {"RoutineOrClass": "OcuProbe1831Second", "Db": "HSCUSTOM", "Type": "Routine"}]}
}

/// <p>The rows <code>GET /screens/&lt;pScreen&gt;/read?name=</code> answers for <var>pName</var>, or an empty array.
/// <var>pStatus</var> and <var>pCode</var> are the answer's status and envelope code.</p>
ClassMethod RouteRows(pScreen As %String, pName As %String, Output pStatus As %Integer, Output pCode As %String) As %DynamicArray
{
    Set pCode = ""
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/screens/" _ pScreen _ "/read?name=" _ $ZConvert(pName, "O", "URL"), .pStatus, .tBody)
    If $$$ISERR(tSC) || '$IsObject(tBody) Quit []
    Set pCode = tBody.%Get("code")
    If pStatus '= 200 Quit []
    Quit tBody.%Get("rows")
}

/// <p>The rows the read tool <var>pTool</var>'s view answers for <var>pArgs</var>, or an empty array.
/// <var>pHttp</var> and <var>pCode</var> are the view's status and fault code.</p>
ClassMethod ToolRows(pTool As %String, pArgs As %DynamicObject, Output pHttp As %Integer, Output pCode As %String) As %DynamicArray
{
    Set pCode = ""
    Set pHttp = 0
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(pTool _ ".read", .tTool)
    If $$$ISERR(tSC) || '$IsObject(tTool) Quit []
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, pArgs, 100, .tResult, .pHttp, .tFault)
    If $IsObject($Get(tFault)) Set pCode = tFault.%Get("code")
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Quit []
    Quit tResult.%Get("rows")
}

/// <p>The entries of <var>pRows</var> as their JSON texts, sorted and joined by a newline, so two arrays holding the same
/// entries compare equal whatever their order.</p>
ClassMethod Canonical(pRows As %DynamicArray) As %String
{
    Kill tSorted
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSorted(tRow.%ToJSON()) = ""
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: $Char(10)) _ tKey
    }
    Quit tOut
}

}

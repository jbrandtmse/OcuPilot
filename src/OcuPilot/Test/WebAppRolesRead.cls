/// <p>Pins Story 18.47's web application roles read (<code>webapp.webapproles</code>): the screen's route and the agent's
/// read tool each answer one row per entry of the vendor's own <code>MatchRoles</code> array; an empty list and an absent
/// name answer no rows, and no name is 400 <code>READ.CRITERION</code>. The integration leg reads the rows through the
/// tool, mints <code>webapp.list.update</code> with those rows less one, and confirms: the instance keeps the other entry
/// and removes the one left out alone.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates probe web applications and sets
/// the governance policy. Every probe application is removed by exact name, and after each test the instance holds none.</p>
Class OcuPilot.Test.WebAppRolesRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter PROBE = "OcuPilot.Test.DocDbAppProbe";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.WebAppUpdate";

Parameter PORT = "OcuPilot.Port.AdminPort";

Parameter APP = "/csp/ocuprobe1847a";

Parameter EMPTYAPP = "/csp/ocuprobe1847e";

Parameter ABSENTAPP = "/csp/ocuprobe1847z";

/// <p>The description every probe application carries, which is how each is recognised as this class's own.</p>
Parameter MARKER = "OcuPilot web roles probe";

Parameter ROLES = "webapp.webapproles";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WebAppRolesRead creates probe web applications on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit ..RemoveProbes()
}

Method OnBeforeOneTest() As %Status
{
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Kill tSettings
    Set tSettings("webapp.list.update") = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK(..RemoveProbes(), "every probe application is removed by exact name")
    Do $$$AssertEquals(##class(OcuPilot.Test.WebAppWire).Exists(..#APP) + ##class(OcuPilot.Test.WebAppWire).Exists(..#EMPTYAPP), 0, "and none is left")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>On an instance the class is not armed for, <method>OnBeforeAllTests</method> created nothing, so nothing is removed.</p>
Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, ..RemoveProbes())
}

/// <p>With two entries in its list, the screen's route and the read tool each answer one row per entry, equal to the
/// vendor's own array and carrying the list's fields alone; an application with an empty list and one the instance does not
/// hold answer no rows; no name is 400 <code>READ.CRITERION</code>.</p>
/// <p>Mutation (Rule 19): point the read's <code>rows</code> at <code>Roles</code> in
/// <class>OcuPilot.Screen.Descriptor.WebAppRoleList</class> -- the route and tool legs go red.</p>
Method TestTheRolesListAnswersOneRowPerEntryByRouteAndTool()
{
    Do $$$AssertStatusOK(..Seed(..#APP, ..Roles()), "a probe web application holding two entries")
    Do $$$AssertStatusOK(..Seed(..#EMPTYAPP, []), "and one holding none")
    Set tVendor = ..Stored(..#APP)
    Do $$$AssertTrue($IsObject(tVendor), "the vendor's GET reads the application")
    If '$IsObject(tVendor) Quit
    Set tEntries = tVendor.%Get("MatchRoles")
    Do $$$AssertEquals(tEntries.%Size(), 2, "the vendor holds two entries")
    Set tRouteRows = ##class(OcuPilot.Test.RoutineAppListsRead).RouteRows(..#ROLES, ..#APP)
    Do $$$AssertEquals(tRouteRows.%Size(), 2, "the route answers one row per entry")
    Do $$$AssertEquals(##class(OcuPilot.Test.RoutineAppListsRead).Canonical(tRouteRows), ##class(OcuPilot.Test.RoutineAppListsRead).Canonical(tEntries), "the route's rows are the vendor's array")
    Set tToolRows = ##class(OcuPilot.Test.RoutineAppListsRead).ToolRows(..#ROLES, {"name": (..#APP)}, .tHttp, .tCode)
    Do $$$AssertEquals(tToolRows.%Size(), 2, "the tool answers one row per entry")
    Do $$$AssertEquals(##class(OcuPilot.Test.RoutineAppListsRead).Canonical(tToolRows), ##class(OcuPilot.Test.RoutineAppListsRead).Canonical(tEntries), "the tool's rows are the vendor's array")
    Set tIterator = tToolRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tRow), "MatchRole,TargetRoles", "row " _ tIndex _ " carries the list's fields and nothing else")
    }
    Set tRouteEmpty = ##class(OcuPilot.Test.RoutineAppListsRead).RouteRows(..#ROLES, ..#EMPTYAPP, .tStatus, .tCode)
    Set tToolEmpty = ##class(OcuPilot.Test.RoutineAppListsRead).ToolRows(..#ROLES, {"name": (..#EMPTYAPP)}, .tHttp, .tCode)
    Do $$$AssertEquals(tStatus _ " " _ tHttp _ " " _ tRouteEmpty.%Size() _ " " _ tToolEmpty.%Size(), "200 200 0 0", "an empty list is answered, with no rows, by the route and the tool")
    Set tRouteAbsent = ##class(OcuPilot.Test.RoutineAppListsRead).RouteRows(..#ROLES, ..#ABSENTAPP, .tStatus, .tCode)
    Set tToolAbsent = ##class(OcuPilot.Test.RoutineAppListsRead).ToolRows(..#ROLES, {"name": (..#ABSENTAPP)}, .tHttp, .tCode)
    Do $$$AssertEquals(tStatus _ " " _ tHttp _ " " _ tRouteAbsent.%Size() _ " " _ tToolAbsent.%Size(), "200 200 0 0", "an application the instance does not hold is answered, with no rows, by the route and the tool")
    Do ##class(OcuPilot.Test.RoutineAppListsRead).RouteRows(..#ROLES, "", .tStatus, .tCode)
    Do $$$AssertEquals(tStatus _ " " _ tCode, "400 " _ ##class(OcuPilot.Api.Error).#READCRITERION, "no name is refused by the route")
    Do ##class(OcuPilot.Test.RoutineAppListsRead).ToolRows(..#ROLES, {}, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "400 " _ ##class(OcuPilot.Api.Error).#READCRITERION, "and by the tool")
}

/// <p>Integration: the roles read through the tool, sent back less one entry through <code>webapp.list.update</code>, remove
/// that entry alone. The proposal's changed fields name <code>MatchRoles</code> alone, the confirm is accepted, and the
/// instance keeps the entry that was sent.</p>
/// <p>Mutation (Rule 19): point the read's <code>rows</code> at <code>Roles</code> in
/// <class>OcuPilot.Screen.Descriptor.WebAppRoleList</class> -- the read answers no rows and this goes red.</p>
Method TestAnAgentSendsTheRolesItReadLessOneEntry()
{
    Do $$$AssertStatusOK(..Seed(..#APP, ..Roles()), "a probe web application holding two entries")
    Set tRoleRows = ##class(OcuPilot.Test.RoutineAppListsRead).ToolRows(..#ROLES, {"name": (..#APP)})
    Do $$$AssertEquals(tRoleRows.%Size(), 2, "the tool answers both entries")
    If tRoleRows.%Size() '= 2 Quit
    Set tKept = ""
    Set tRemoved = ""
    Set tIterator = tRoleRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("MatchRole") = "" {
            Set tKept = tRow
        } Else {
            Set tRemoved = tRow
        }
    }
    Do $$$AssertTrue($IsObject(tKept) && $IsObject(tRemoved), "one entry is the application roles and the other a matching role's")
    If '($IsObject(tKept) && $IsObject(tRemoved)) Quit
    Set tArgs = {"Name": (..#APP)}
    Do tArgs.%Set("MatchRoles", ##class(%DynamicArray).%FromJSON("[" _ tKept.%ToJSON() _ "]"))
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, ..#APP, tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the update is minted (" _ tProblem _ ")")
    If '$IsObject($Get(tProposal)) Quit
    Set tChanged = ""
    Set tChanges = tProposal.%Get("changed").%GetIterator()
    While tChanges.%GetNext(.tChangeIndex, .tChange) {
        Set tChanged = tChanged _ $Select(tChanged = "": "", 1: ",") _ tChange.%Get("field")
    }
    Do $$$AssertEquals(tChanged, "MatchRoles", "the proposal changes MatchRoles alone")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and is confirmed")
    Set tAfter = ..Stored(..#APP)
    Do $$$AssertTrue($IsObject(tAfter), "the instance still holds the application")
    If '$IsObject(tAfter) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.RoutineAppListsRead).Canonical(tAfter.%Get("MatchRoles")), tKept.%ToJSON(), "and only the entry that was sent: " _ tRemoved.%Get("MatchRole") _ " is gone")
}

/// <p>The roles of a probe application: the application roles and one matching role's. The roles are ones every instance
/// defines.</p>
ClassMethod Roles() As %DynamicArray
{
    Quit [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}, {"MatchRole": "%Developer", "TargetRoles": ["%Manager", "%Operator"]}]
}

/// <p>Create the probe web application <var>pName</var> afresh, holding <var>pRoles</var>.</p>
ClassMethod Seed(pName As %String, pRoles As %DynamicArray) As %Status
{
    Quit ##class(OcuPilot.Test.WebAppSave).EnsureApp(pName, ..#MARKER, {"NameSpace": ($Namespace), "Description": (..#MARKER), "AutheEnabled": 32, "Resource": "%Development", "Enabled": true, "MatchRoles": (pRoles)})
}

/// <p>Remove each probe web application by exact name, when its description is this class's marker.</p>
ClassMethod RemoveProbes() As %Status
{
    Set tSC = ##class(OcuPilot.Test.WebAppSave).RemoveApp(..#APP, ..#MARKER)
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Test.WebAppSave).RemoveApp(..#EMPTYAPP, ..#MARKER))
    Quit tSC
}

/// <p>The probe application <var>pName</var> as the vendor's <code>GET</code> reads it, or <code>""</code>.</p>
ClassMethod Stored(pName As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", "WebApp.App", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRead)) Quit ""
    Quit tRead
}

}

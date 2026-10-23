/// <p>Pins DW-2252 through the web application callers (Story 18.31): a write naming a privileged routine application
/// that arrives through the web application editor's Save, the Web applications list's Delete or the agent's
/// <code>webapp.list.update</code> and <code>webapp.list.delete</code> never reaches the vendor, which would answer a
/// <code>PUT</code> 500 and delete the application on a <code>DELETE</code>. A change is refused 409
/// <code>PRIVROUTINE.WEBAPP</code> by the port; a delete is refused 400 at the delete tool's own precondition, which a
/// routine application's empty record fails, or 409 by the port if it passes. The port-level guard is
/// <class>OcuPilot.Test.RoutineAppWrite</class>'s; this class asks what each caller shows.</p>
/// <p>Every write is real for an application named <code>OcuProbe1831...</code> and the class touches no other, removing
/// each by exact name. <b>It never names <code>OcuPilotState</code>, <code>OcuPilotIdentity</code> or <code>OcuPilotSslRead</code>.</b></p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates, and (under a broken guard)
/// changes or deletes, a probe privileged routine application and sets the governance policy. After each test the
/// application list reads as that test found it.</p>
Class OcuPilot.Test.RoutineAppWebAppGuard Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.RoutineAppProbe";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.WebAppUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.WebAppDelete";

Parameter PORT = "OcuPilot.Port.AdminPort";

Parameter ERRORS = "OcuPilot.Api.RoutineAppError";

/// <p>The probe application every test seeds.</p>
Parameter APPLICATION = "OcuProbe1831G";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RoutineAppWebAppGuard creates probe privileged routine applications on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    Set tSettings("webapp.list.update") = "enabled"
    Set tSettings("webapp.list.delete") = "enabled"
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

/// <p>DW-2252: the web application editor's Save naming a routine application answers 409
/// <code>PRIVROUTINE.WEBAPP</code> with the published sentence, and the Web applications list's Delete is refused;
/// the application keeps its settings, role and routine and is still there.</p>
/// <p>Mutation (Rule 19): drop the <code>pWebApp</code> branch from <method>OcuPilot.Port.AdminPort.PrivilegedRoutineGuard</method>
/// -- the Save leg answers the vendor's refusal and goes red; with the delete tool's own precondition removed as well
/// (<method>OcuPilot.Screen.Tool.WebAppDelete.StateDiff</method> accepting an empty record) the Delete deletes the probe
/// and its leg goes red.</p>
Method TestTheEditorSaveAndTheListDeleteAreRefusedForARoutineApplication()
{
    Set tName = ..#APPLICATION
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", tName, $ClassMethod(..#PROBE, "WithLists", "guard")), "a probe application holding a role and a routine")
    Set tBefore = $ClassMethod(..#PROBE, "Lists", tName) _ "|" _ $ClassMethod(..#PROBE, "Summary", "", tName)
    Do $$$AssertNotEquals($ClassMethod(..#PROBE, "Lists", tName), "absent", "which the instance holds")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/web-applications/" _ $ClassMethod(..#PROBE, "PathId", tName), .tStatus, .tAnswer, {"Description": "web"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..Fault(tAnswer), "409 " _ ..Published(), "the editor's Save is refused 409 with the published code and sentence: " _ ..Text(tAnswer))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Lists", tName) _ "|" _ $ClassMethod(..#PROBE, "Summary", "", tName), tBefore, "and the application reads as it did")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/webapp.list/action", .tStatus, .tAnswer, {"action": "delete", "id": (tName)}.%ToJSON(), "application/json")
    Do $$$AssertTrue($ListFind(..Refusals(), tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: "")), "the list's Delete is refused, by the tool's precondition or by the port: " _ ..Text(tAnswer))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Lists", tName) _ "|" _ $ClassMethod(..#PROBE, "Summary", "", tName), tBefore, "and the application is still there, as it was")
}

/// <p>DW-2252: the agent's <code>webapp.list.update</code> naming a routine application is refused 409
/// <code>PRIVROUTINE.WEBAPP</code> at the confirm and its <code>webapp.list.delete</code> is refused, the application
/// keeping its settings, role and routine and staying.</p>
/// <p>Mutation (Rule 19): drop the <code>pWebApp</code> branch from <method>OcuPilot.Port.AdminPort.PrivilegedRoutineGuard</method>
/// -- the update confirm answers the vendor's refusal and goes red; with the delete tool's own precondition removed as
/// well (<method>OcuPilot.Screen.Tool.WebAppDelete.StateDiff</method> accepting an empty record) the delete confirm
/// deletes the probe and its leg goes red.</p>
Method TestTheAgentsConfirmedUpdateAndDeleteAreRefusedForARoutineApplication()
{
    Set tName = ..#APPLICATION
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", tName, $ClassMethod(..#PROBE, "WithLists", "guard")), "a probe application holding a role and a routine")
    Set tBefore = $ClassMethod(..#PROBE, "Lists", tName) _ "|" _ $ClassMethod(..#PROBE, "Summary", "", tName)
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, tName, {"Name": (tName), "Description": "agent"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's web application change naming it is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ $Parameter(..#ERRORS, "WEBAPP"), "and its confirm is refused 409 with the published code")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Lists", tName) _ "|" _ $ClassMethod(..#PROBE, "Summary", "", tName), tBefore, "the application reads as it did")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, tName, {"Name": (tName)}, .tProposal, .tHttp, .tProblem)
    Set tDeleteAnswer = $Select($$$ISOK(tSC): $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), 1: "mint " _ tHttp)
    Do $$$AssertTrue($ListFind(..Refusals(), tDeleteAnswer), "the agent's web application delete naming it is refused at the mint or at the confirm: " _ tDeleteAnswer _ " " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Lists", tName) _ "|" _ $ClassMethod(..#PROBE, "Summary", "", tName), tBefore, "and the application is still there, as it was")
}

/// <p>The answers that refuse a web application delete naming a routine application: the delete tool's precondition,
/// as a route's <code>400 TOOL.ARGUMENTS</code> or the agent's <code>mint 400</code>, and the port's guard,
/// <code>409 PRIVROUTINE.WEBAPP</code>.</p>
ClassMethod Refusals() As %List
{
    Quit $ListBuild("400 TOOL.ARGUMENTS", "mint 400", "409 " _ $Parameter(..#ERRORS, "WEBAPP"))
}

/// <p>The code and the sentence a refusal of a web application write naming a routine application carries.</p>
ClassMethod Published() As %String
{
    Quit $Parameter(..#ERRORS, "WEBAPP") _ "|" _ $Parameter(..#ERRORS, "REASONWEBAPP")
}

/// <p><code>code|reason</code> of the envelope <var>pAnswer</var>, or <code>""</code>.</p>
ClassMethod Fault(pAnswer) As %String
{
    If '$IsObject(pAnswer) Quit ""
    Quit pAnswer.%Get("code") _ "|" _ pAnswer.%Get("reason")
}

/// <p>The start of <var>pAnswer</var> as text, for an assertion message.</p>
ClassMethod Text(pAnswer) As %String
{
    Quit $Extract($Select($IsObject(pAnswer): pAnswer.%ToJSON(), 1: pAnswer), 1, 300)
}

}

/// <p>Pins Story 18.33's privilege grants through a privileged routine application (C5, AD-10): a role added to
/// <code>MatchRoles</code> that is <code>%All</code> or carries an <code>%Admin_*</code> resource, and a routine added
/// while a target role in <code>MatchRoles</code> does, are proposed at the destructive treatment with
/// <code>GRANT.PRIVILEGED</code>, through the update tool's mint and through
/// <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method> asked directly; a remove, and an add under
/// unprivileged roles, are not.</p>
/// <p>Every write is real for an application named <code>OcuProbe1831...</code> and a role named
/// <code>OcuProbe1833Role...</code>; the mint stores a proposal and writes nothing, and no proposal is confirmed.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates probe applications and roles
/// and sets the governance policy. After each test the application list reads as that test found it.</p>
Class OcuPilot.Test.RoutineAppGrant Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.RoutineAppProbe";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RoutineAppUpdate";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter TYPE = "routine-application";

Parameter APP = "OcuProbe1831A";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RoutineAppGrant creates probe privileged routine applications and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts")
    Kill tSettings
    Set tSettings("webapp.routineapps.update") = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe application, role and resource is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the application list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedFacts, "the application list reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
}

/// <p>C5: through the agent's mint, adding a role to <code>MatchRoles</code> is destructive with
/// <code>GRANT.PRIVILEGED</code> when the role is <code>%All</code> or carries an <code>%Admin_*</code> resource -- as an
/// application role and as a matching role's target -- and is not when the role is unprivileged; removing a privileged
/// role is not.</p>
/// <p>Mutation (Rule 19): make the routine application branch of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method> delegate nothing to the web application's
/// -- the roles legs go red.</p>
Method TestARolePrivilegedByItsNameOrItsResourceIsAGrant()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureRole", "Admin", "%Admin_Secure:U"), "a probe role carrying an administrative resource")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureRole", "Plain", "%DB_HSCUSTOM:R"), "and one carrying a database resource alone")
    Set tAdmin = $ClassMethod(..#PROBE, "RoleName", "Admin")
    Set tPlain = $ClassMethod(..#PROBE, "RoleName", "Plain")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, $ClassMethod(..#PROBE, "WithLists")), "a probe application holding an unprivileged role and a routine")
    Do ..AssertMint({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM", "%All"]}]}, 1, "an application role of %All")
    Do ..AssertMint({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM", (tAdmin)]}]}, 1, "an application role carrying an administrative resource")
    Do ..AssertMint({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}, {"MatchRole": "%Developer", "TargetRoles": [(tAdmin)]}]}, 1, "a matching role's target carrying one")
    Do ..AssertMint({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM", (tPlain)]}]}, 0, "an application role carrying a database resource alone")
    Do ..AssertMint({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}, {"MatchRole": (tAdmin), "TargetRoles": [(tPlain)]}]}, 0, "an unprivileged target for a privileged matching role")
    Do ..AssertMint({"MatchRoles": []}, 0, "removing the application's only role")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, {"Description": "probe", "Enabled": true, "Resource": "", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM", (tAdmin)]}], "Routines": []}), "the application now holding the privileged role")
    Do ..AssertMint({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}]}, 0, "removing the privileged role")
    Do ..AssertMint({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM", (tAdmin), (tPlain)]}]}, 0, "adding an unprivileged role beside the privileged one it held")
}

/// <p>C5: a routine added while a target role in <code>MatchRoles</code> is privileged is a grant, with
/// <code>GRANT.PRIVILEGED</code>, whether the role was held or is added by the same change; a routine added under
/// unprivileged roles, a routine removed under privileged roles and an unchanged list are not.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Kernel.Proposal.Prohibited.AddsRoutineUnderPrivilege</method> from the
/// routine application branch -- the routine legs go red.</p>
Method TestARoutineAddedUnderAPrivilegedRoleIsAGrant()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureRole", "Admin", "%Admin_Secure:U"), "a probe role carrying an administrative resource")
    Set tAdmin = $ClassMethod(..#PROBE, "RoleName", "Admin")
    Set tRoutine = {"RoutineOrClass": "OcuProbe1833.New", "Db": "HSCUSTOM", "Type": "Class"}
    Set tHeld = {"RoutineOrClass": "OcuProbe1831.Routine", "Db": "HSCUSTOM", "Type": "Class"}
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, {"Description": "probe", "Enabled": true, "Resource": "", "MatchRoles": [{"MatchRole": "", "TargetRoles": [(tAdmin)]}], "Routines": [(tHeld)]}), "a probe application granting a privileged role and listing a routine")
    Do ..AssertMint({"Routines": [(tHeld), (tRoutine)]}, 1, "a routine added under the privileged role")
    Do ..AssertMint({"Routines": [(tRoutine)]}, 1, "a routine added in place of the one held")
    Do ..AssertMint({"Routines": []}, 0, "the routine removed under it")
    Do ..AssertMint({"Description": "again"}, 0, "a change to a setting with the lists as read")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, {"Description": "probe", "Enabled": true, "Resource": "", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}], "Routines": [(tHeld)]}), "the application now granting an unprivileged role")
    Do ..AssertMint({"Routines": [(tHeld), (tRoutine)]}, 0, "a routine added under it")
    Do ..AssertMint({"MatchRoles": [{"MatchRole": "", "TargetRoles": [(tAdmin)]}], "Routines": [(tHeld), (tRoutine)]}, 1, "a routine and a privileged role added together")
    Do ..AssertMint({"MatchRoles": [{"MatchRole": "", "TargetRoles": [(tAdmin)]}]}, 1, "the privileged role added alone")
}

/// <p>C5: the one classifier answers the same question when asked directly with a payload and the target it changes:
/// <code>%All</code> and an <code>%Admin_*</code> name by their names, a routine by the roles that stay, a remove and an
/// absent <code>Routines</code> never, and a payload that is not an object nothing.</p>
/// <p>Mutation (Rule 19): drop the <code>%Admin_</code> prefix test from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.IsPrivilegedRole</method> -- the administrative-name and administrative-resource
/// legs go red.</p>
Method TestTheClassifierAnswersTheSameWhenAskedDirectly()
{
    Set tTarget = {"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}], "Routines": []}
    Set tRoutine = {"RoutineOrClass": "OcuProbe1833.New", "Db": "HSCUSTOM", "Type": "Class"}
    Do ..AssertGrants({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}], "Routines": []}, tTarget, 1, "%All added")
    Do ..AssertGrants({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%Admin_Secure"]}], "Routines": []}, tTarget, 1, "a name beginning %Admin_ added")
    Do ..AssertGrants({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}], "Routines": [(tRoutine)]}, tTarget, 0, "a routine under the roles that stay")
    Do ..AssertGrants({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}], "Routines": [(tRoutine)]}, {"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}], "Routines": []}, 1, "a routine added under %All the application already grants")
    Do ..AssertGrants({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}], "Routines": []}, {"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}], "Routines": [(tRoutine)]}, 0, "that routine removed again")
    Do ..AssertGrants({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}], "Routines": [(tRoutine)]}, {"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}], "Routines": [{"RoutineOrClass": "OcuProbe1833.New", "Db": "hscustom", "Type": "Class"}]}, 0, "a routine the target lists with its database in other case")
    Do ..AssertGrants({"Description": "x"}, tTarget, 0, "a payload without lists")
    Do ..AssertGrants({"Routines": [(tRoutine)]}, {"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}], "Routines": []}, 1, "a routine in a payload without roles, under the roles the target holds")
    Set tSC = $ClassMethod(..#SET, "GrantsPrivilegeByEffect", ..#TYPE, "x", tTarget, .tGrants, ..#APP)
    Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tGrants, "1 0", "a payload that is not an object grants nothing")
}

/// <p>Mint the update of <parameter>APP</parameter> over <var>pChange</var> and assert it is destructive with
/// <code>GRANT.PRIVILEGED</code> when <var>pGrant</var> is 1, and carries neither when it is 0.</p>
Method AssertMint(pChange As %DynamicObject, pGrant As %Boolean, pLabel As %String)
{
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pChange.%ToJSON())
    Do tArgs.%Set("Name", ..#APP)
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, ..#APP, tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, pLabel _ ": minted (" _ tProblem _ ")")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals(+$Get(tValues("destructive")) _ " " _ $Get(tValues("consequence")), pGrant _ " " _ $Select(pGrant: ##class(OcuPilot.Kernel.Proposal.Mint).#CONSEQUENCEPRIVILEGED, 1: ""), pLabel _ ": " _ $Select(pGrant: "destructive, naming the privilege", 1: "neither destructive nor a privilege"))
}

/// <p>Assert that <code>GrantsPrivilegeByEffect</code> answers <var>pGrant</var> for <var>pPayload</var> against
/// <var>pTarget</var>.</p>
Method AssertGrants(pPayload As %DynamicObject, pTarget As %DynamicObject, pGrant As %Boolean, pLabel As %String)
{
    Set tSC = $ClassMethod(..#SET, "GrantsPrivilegeByEffect", ..#TYPE, pPayload, pTarget, .tGrants, ..#APP)
    Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tGrants, "1 " _ pGrant, pLabel _ ": " _ $Select(pGrant: "a grant", 1: "no grant"))
}

}

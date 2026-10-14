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

/// <p>The web application guard's test class, whose probe resources carry a public permission.</p>
Parameter WEAKENING = "OcuPilot.Test.WebAppWeakening";

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
    Do $$$AssertStatusOK($ClassMethod(..#WEAKENING, "RemoveResources"), "and every public-permission probe resource")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the application list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedFacts, "the application list reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>On an instance the class is not armed for, <method>OnBeforeAllTests</method> created nothing, so nothing is removed.</p>
Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#WEAKENING, "RemoveResources"))
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
/// <code>GRANT.PRIVILEGED</code>, whether the role was held or is added by the same change, and whether it is an
/// application role or a matching role's target; a routine added under unprivileged roles, a routine removed under
/// privileged roles and an unchanged list are not.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Kernel.Proposal.Prohibited.AddsRoutineUnderPrivilege</method> from the
/// routine application branch -- the routine legs go red; let it collect only the entries whose <code>MatchRole</code>
/// is empty -- the matching-role leg goes red.</p>
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
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, {"Description": "probe", "Enabled": true, "Resource": "", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}, {"MatchRole": "%Developer", "TargetRoles": [(tAdmin)]}], "Routines": [(tHeld)]}), "the application now granting the privileged role to a matching role's holders alone")
    Do ..AssertMint({"Routines": [(tHeld), (tRoutine)]}, 1, "a routine added under a matching role's privileged target")
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
    Do ..AssertGrants({"Routines": [(tRoutine)]}, {"MatchRoles": [{"MatchRole": "%Developer", "TargetRoles": ["%All"]}], "Routines": []}, 1, "a routine added under a matching role's privileged target")
    Set tSC = $ClassMethod(..#SET, "GrantsPrivilegeByEffect", ..#TYPE, "x", tTarget, .tGrants, ..#APP)
    Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tGrants, "1 0", "a payload that is not an object grants nothing")
}

/// <p>DW-2320 (AD-10): the grant is judged per (matching role, target role) pair. A held privileged target moved to another
/// matching role -- to every caller through an empty one, or to one matching role alone -- is a grant, through the direct
/// question and through the agent's mint; the same pairs re-sent, in any case, are not.</p>
/// <p>Mutation (Rule 19): key <method>OcuPilot.Kernel.Proposal.Prohibited.ApplicationRoleNames</method> by the target alone
/// -- the moved legs go red.</p>
Method TestAHeldPrivilegedTargetMovedToAnotherMatchingRoleIsAGrant()
{
    Set tHeld = {"MatchRoles": [{"MatchRole": "%Developer", "TargetRoles": ["%All"]}]}
    Do ..AssertGrants({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}, tHeld, 1, "moved to every caller")
    Do ..AssertGrants({"MatchRoles": [{"MatchRole": "%Manager", "TargetRoles": ["%All"]}]}, tHeld, 1, "moved to another matching role")
    Do ..AssertGrants({"MatchRoles": [{"MatchRole": "%Developer", "TargetRoles": ["%All"]}]}, tHeld, 0, "the same pair re-sent")
    Do ..AssertGrants({"MatchRoles": [{"MatchRole": "%DEVELOPER", "TargetRoles": ["%all"]}]}, tHeld, 0, "the same pair in another case")
    Do ..AssertGrants({"MatchRoles": [{"MatchRole": "%Developer", "TargetRoles": ["%All"]}]}, {"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}, 1, "every caller narrowed to one matching role")
    Do ..AssertGrants({"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}, {"MatchRoles": "%Developer:%All"}, 1, "the stored text form moved to every caller")
    Do ..AssertGrants({"MatchRoles": [{"MatchRole": "%Developer", "TargetRoles": ["%All"]}]}, {"MatchRoles": "%Developer:%All"}, 0, "the stored text form re-sent")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureRole", "Admin", "%Admin_Secure:U"), "a probe role carrying an administrative resource")
    Set tAdmin = $ClassMethod(..#PROBE, "RoleName", "Admin")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, {"Description": "probe", "Enabled": true, "Resource": "", "MatchRoles": [{"MatchRole": "%Developer", "TargetRoles": [(tAdmin)]}], "Routines": []}), "a probe application granting the privileged role to a matching role's holders")
    Do ..AssertMint({"MatchRoles": [{"MatchRole": "", "TargetRoles": [(tAdmin)]}]}, 1, "the role moved to every caller")
}

/// <p>DW-2322 (AD-10): clearing a privileged routine application's <code>Resource</code>, or turning <code>Enabled</code>
/// on, while a role it grants is privileged is a grant -- through the direct question, in each form
/// the routine application rules admit, and through the agent's mint; the
/// same change under unprivileged roles, on an application that is already enabled or holds no resource, and turning it off
/// are not.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Kernel.Proposal.Prohibited.WidensPrivilegedReach</method> call from the
/// routine application branch of <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method> -- the
/// cleared-resource and enabled legs go red.</p>
Method TestClearingTheResourceOrEnablingUnderAPrivilegedRoleIsAGrant()
{
    Set tTarget = {"Enabled": false, "Resource": "OcuProbe1831Res", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}
    Do ..AssertGrants({"Resource": ""}, tTarget, 1, "the resource cleared under %All")
    Do ..AssertGrants({"Enabled": true}, tTarget, 1, "enabled as a boolean")
    Do ..AssertGrants({"Enabled": 1}, tTarget, 1, "enabled as the number 1")
    Do ..AssertGrants({"Enabled": "1"}, tTarget, 1, "enabled as the text 1")
    Do ..AssertGrants({"Enabled": "yes"}, tTarget, 0, "a value no enabled form admits")
    Do ..AssertGrants({"Enabled": false}, tTarget, 0, "turned off again")
    Do ..AssertGrants({"Resource": "OcuProbe1831Res"}, tTarget, 0, "the resource kept")
    Do ..AssertGrants({"Resource": ""}, {"Enabled": true, "Resource": "", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}, 0, "the resource cleared where none is held")
    Do ..AssertGrants({"Enabled": true}, {"Enabled": true, "Resource": "OcuProbe1831Res", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}, 0, "enabled where it is already")
    Do ..AssertGrants({"Resource": "", "Enabled": true}, {"Enabled": false, "Resource": "OcuProbe1831Res", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}]}, 0, "both under unprivileged roles")
    Do ..AssertGrants({"Resource": "", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}, {"Enabled": true, "Resource": "OcuProbe1831Res", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}]}, 1, "the resource cleared in the change that sends the privileged role")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureResource"), "the probe resource")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureRole", "Admin", "%Admin_Secure:U"), "a probe role carrying an administrative resource")
    Set tAdmin = $ClassMethod(..#PROBE, "RoleName", "Admin")
    Set tResource = $Parameter(..#PROBE, "RESOURCE")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, {"Description": "probe", "Enabled": false, "Resource": (tResource), "MatchRoles": [{"MatchRole": "", "TargetRoles": [(tAdmin)]}], "Routines": []}), "a disabled probe application holding a resource and granting a privileged role")
    Do ..AssertMint({"Resource": ""}, 1, "the resource cleared")
    Do ..AssertMint({"Enabled": true}, 1, "the application enabled")
    Do ..AssertMint({"Description": "again"}, 0, "another setting changed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, {"Description": "probe", "Enabled": true, "Resource": (tResource), "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}], "Routines": []}), "an enabled probe application granting an unprivileged role")
    Do ..AssertMint({"Resource": ""}, 0, "the resource cleared under it")
}

/// <p>DW-2425: pointing a privileged routine application's resource at one whose public permission holds USE is a grant
/// -- asked directly and through the agent's mint -- and is not when the public permission only reads or holds nothing; a
/// resource the instance cannot read counts as public.</p>
/// <p>Mutation (Rule 19): drop the <code>RepointsToPublicResource</code> clause from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WidensPrivilegedReach</method> -- the public-use legs go red.</p>
Method TestAResourceTheBroadPublicMayUseIsAGrantUnderAPrivilegedRole()
{
    Set tUse = $Parameter(..#WEAKENING, "PUBLICUSE")
    Set tRead = $Parameter(..#WEAKENING, "PUBLICREAD")
    Set tNone = $Parameter(..#WEAKENING, "PUBLICNONE")
    Do $$$AssertStatusOK($ClassMethod(..#WEAKENING, "AddResource", tUse, "U"), "a resource whose public permission holds USE")
    Do $$$AssertStatusOK($ClassMethod(..#WEAKENING, "AddResource", tRead, "R"), "one that only reads")
    Do $$$AssertStatusOK($ClassMethod(..#WEAKENING, "AddResource", tNone, ""), "and one with none")
    Set tTarget = {"Enabled": true, "Resource": "OcuProbe1831Res", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}
    Do ..AssertGrants({"Resource": (tUse)}, tTarget, 1, "the resource moved to one the public may use")
    Do ..AssertGrants({"Resource": (tRead)}, tTarget, 0, "moved to one the public only reads")
    Do ..AssertGrants({"Resource": (tNone)}, tTarget, 0, "moved to one the public holds nothing of")
    Do ..AssertGrants({"Resource": "OcuProbeNoSuchResource1848"}, tTarget, 1, "moved to a resource the instance cannot read")
    Do ..AssertGrants({"Resource": (tUse)}, {"Enabled": true, "Resource": "OcuProbe1831Res", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}]}, 0, "the same move under an unprivileged role")
    Do ..AssertGrants({"Resource": (tUse)}, {"Enabled": true, "Resource": (tUse), "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}, 0, "kept on the public resource it already holds")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureResource"), "the probe resource")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureRole", "Admin", "%Admin_Secure:U"), "a probe role carrying an administrative resource")
    Set tAdmin = $ClassMethod(..#PROBE, "RoleName", "Admin")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, {"Description": "probe", "Enabled": true, "Resource": ($Parameter(..#PROBE, "RESOURCE")), "MatchRoles": [{"MatchRole": "", "TargetRoles": [(tAdmin)]}], "Routines": []}), "an enabled probe application granting a privileged role")
    Do ..AssertMint({"Resource": (tUse)}, 1, "the resource moved to one the public may use")
    Do ..AssertMint({"Resource": (tRead)}, 0, "the resource moved to one the public only reads")
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

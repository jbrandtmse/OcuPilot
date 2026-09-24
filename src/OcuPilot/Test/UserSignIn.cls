/// <p>Pins how a write may change the way an account signs in (Story 9.1).</p>
/// <p><b>DW-1520, AD-10 as amended:</b> a new password, or turning change-password-on-login on, for
/// one of the accounts the instance's own services run as is refused
/// <code>PROHIBITED.SERVICEACCOUNTSIGNIN</code> at the gate both callers share
/// (<method>OcuPilot.Kernel.Proposal.Operation.Gate</method>); <code>_SYSTEM</code>, the signed-in
/// account and turning the flag off stay permitted. These legs read an armed target
/// (<class>OcuPilot.Test.ProhibitedFixture</class>), so no service account is ever written.</p>
/// <p><b>DW-1516, AD-56 (i) as amended:</b> a flag proposal confirmed before the password proposal,
/// or after it, leaves the account required to change its password, and so does the screen's own
/// set-password action on an account whose flag is set. A re-apply that fails is the write's
/// failure, and the password it wrote stands.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%Admin_Secure</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because the DW-1516 legs create, change and delete one probe account by exact name.</p>
Class OcuPilot.Test.UserSignIn Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter FIXTURESET = "OcuPilot.Test.ProhibitedFixture";

Parameter FIXTURE = "OcuPilot.Test.ProposalFixture";

Parameter UPDATETOOL = "permissions.users.update";

Parameter PASSWORDTOOL = "permissions.users.password";

/// <p>The probe account the DW-1516 legs change, created and removed through
/// <class>OcuPilot.Test.ProposalFixture</class>.</p>
Parameter PROBEUSER = "OcuPilotProbeUserSignIn";

Parameter ACTIONPATH = "/screens/permissions.users/action";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UserSignIn creates and deletes a user account on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do $ClassMethod(..#FIXTURE, "RemoveUser", ..#PROBEUSER)
    Quit $ClassMethod(..#FIXTURE, "RemoveSeeded", .tRemaining)
}

/// <p>DW-1520: for every service account but the signed-in one, a password write and a write that
/// turns the flag on are refused with the new code at the shared gate; turning the flag off is
/// permitted; and <code>_SYSTEM</code> and the signed-in account are permitted both.</p>
/// <p>Mutation (Rule 19): remove the <method>OcuPilot.Kernel.Proposal.Prohibited.ChangesServiceSignIn</method>
/// call from <method>OcuPilot.Kernel.Proposal.Prohibited.User</method> -- every refused leg goes red.
/// Drop its signed-in exemption -- the signed-in legs go red.</p>
Method TestAServiceAccountsSignInCannotBeChangedAndOtherAccountsCan()
{
    Set tCode = $Parameter(..#SET, "SERVICEACCOUNTSIGNIN")
    Set tRefused = 0
    Set tAccounts = $ClassMethod(..#SET, "ServiceAccounts")
    For tI = 1:1:$ListLength(tAccounts) {
        Set tName = $List(tAccounts, tI)
        Set tSelf = ($ZConvert(tName, "L") = $ZConvert($Username, "L"))
        Set tExpected = $Select(tSelf: "0|", 1: "1|" _ tCode)
        Do $$$AssertEquals(..Password(tName), tExpected, tName _ ": a new password " _ $Select(tSelf: "is permitted, because it is the signed-in account", 1: "is refused"))
        Do $$$AssertEquals(..Flag(tName, 0, 1), tExpected, tName _ ": turning the flag on " _ $Select(tSelf: "is permitted", 1: "is refused"))
        Do $$$AssertEquals(..Flag(tName, 1, 0), "0|", tName _ ": turning the flag off is permitted")
        If 'tSelf Set tRefused = tRefused + 1
    }
    Do $$$AssertTrue(tRefused >= 2, "at least two service accounts were refused, so the arm was exercised: " _ tRefused)
    For tName = "_SYSTEM", $Username, "OcuPilotProbeSignInOrdinary" {
        Do $$$AssertEquals(..Password(tName), "0|", tName _ ": a new password is permitted")
        Do $$$AssertEquals(..Flag(tName, 0, 1), "0|", tName _ ": and so is turning the flag on")
    }
    Do $$$AssertEquals($ClassMethod(..#SET, "ReasonFor", tCode), $Parameter(..#SET, "SERVICEACCOUNTSIGNINREASON"), "the code answers its published sentence")
}

/// <p>DW-1516: the agent confirms the flag proposal and then the password proposal, and the account
/// ends required to change its password; confirmed the other way round it ends the same.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.UserPassword.AfterWrite</method> answer
/// at once -- the flag-first leg goes red.</p>
Method TestTheFlagEndsSetInEitherConfirmOrder()
{
    Set tName = ..#PROBEUSER
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureUser", tName, "%Developer", 1, .tCreated)
    Do $$$AssertStatusOK(tSC, "the probe account is created")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#FIXTURE, "SeedTurn", $Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded")
    If $$$ISERR(tSC) Quit

    Do $$$AssertStatusOK(..Confirm(tTurnKey, "OcuPilot.Screen.Tool.UserUpdate", {"Name": (tName), "ChangePassword": true}, ""), "flag first: the flag is confirmed")
    Do $$$AssertEquals(+$ClassMethod(..#FIXTURE, "UserField", tName, "ChangePassword"), 1, "flag first: the flag is set")
    Do $$$AssertStatusOK(..Confirm(tTurnKey, "OcuPilot.Screen.Tool.UserPassword", {"Name": (tName)}, {"Password": ("OcuPilotSignInPw" _ $Job _ "a")}), "flag first: the password is confirmed")
    Do $$$AssertEquals(+$ClassMethod(..#FIXTURE, "UserField", tName, "ChangePassword"), 1, "flag first: the account still has to change its password")

    Do ..ClearFlag(tName)
    Do $$$AssertStatusOK(..Confirm(tTurnKey, "OcuPilot.Screen.Tool.UserPassword", {"Name": (tName)}, {"Password": ("OcuPilotSignInPx" _ $Job _ "a")}), "password first: the password is confirmed")
    Do $$$AssertEquals(+$ClassMethod(..#FIXTURE, "UserField", tName, "ChangePassword"), 0, "password first: a flag that was not set stays clear")
    Do $$$AssertStatusOK(..Confirm(tTurnKey, "OcuPilot.Screen.Tool.UserUpdate", {"Name": (tName), "ChangePassword": true}, ""), "password first: the flag is confirmed")
    Do $$$AssertEquals(+$ClassMethod(..#FIXTURE, "UserField", tName, "ChangePassword"), 1, "password first: the flag is set")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows it wrote")
}

/// <p>DW-1516 on the screen's caller: the set-password action alone, on an account whose flag is
/// set, leaves the flag set, because the operation both callers reach re-applies it.</p>
Method TestTheScreensSetPasswordKeepsASetFlag()
{
    Set tName = ..#PROBEUSER
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureUser", tName, "%Developer", 1, .tCreated)
    Do $$$AssertStatusOK(tSC, "the probe account is created")
    If $$$ISERR(tSC) Quit
    Do ..SetFlag(tName)
    Set tRequest = {"action": "set-password", "id": (tName), "values": {"Password": ("OcuPilotSignInPy" _ $Job _ "a")}}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#ACTIONPATH, .tStatus, .tBody, tRequest.%ToJSON())
    Do $$$AssertStatusOK(tSC, "the action completes")
    Do $$$AssertEquals(tStatus, 200, "at 200")
    Do $$$AssertEquals(+$ClassMethod(..#FIXTURE, "UserField", tName, "ChangePassword"), 1, "and the account still has to change its password")
}

/// <p>DW-1516's failure path: when the flag's re-apply <code>PUT</code> fails,
/// <method>OcuPilot.Kernel.Proposal.Operation.ApplyAt</method> answers an error carrying that
/// port's status and fault, and the password it has already written stands.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Operation.ApplyAt</method> answer
/// the write's own status whatever <method>OcuPilot.Screen.Tool.UserPassword.AfterWrite</method>
/// answers -- the failure legs go red.</p>
Method TestAFailedFlagReapplyIsTheWritesFailureAndThePasswordStands()
{
    Set tName = ..#PROBEUSER
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureUser", tName, "%Developer", 1, .tCreated)
    Do $$$AssertStatusOK(tSC, "the probe account is created")
    If $$$ISERR(tSC) Quit
    Set tSalt = $ClassMethod(..#FIXTURE, "UserField", tName, "Salt")
    Set tPort = "OcuPilot.Test.HeldPutPort"
    Set tTool = "OcuPilot.Screen.Tool.UserPassword"
    Do $ClassMethod(tPort, "Clear")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).ApplyAt(tTool, tPort, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), tName, "", {"Password": ("OcuPilotSignInPz" _ $Job _ "a")}, .tWritten, .tHttp, .tFault, {"Enabled": true, "ChangePassword": true})
    Do $$$AssertStatusNotOK(tSC, "the call fails")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ $Parameter(tPort, "HELDREASON"), "on the re-apply's own status: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), $Parameter(tPort, "HELDSTATUS") _ " " _ ##class(OcuPilot.Api.Error).#PORTUNAVAILABLE, "with that port's HTTP status and fault")
    Do $$$AssertEquals($ClassMethod(tPort, "CallTypes"), "CHANGEPWD,GET,PUT", "after the password was sent and the account re-read")
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "UserField", tName, "Salt") '= tSalt, "and the password was set")
}

/// <p>The shared gate's verdict on a password write to <var>pName</var>, as
/// <code>&lt;refused&gt;|&lt;code&gt;</code>, against an armed target.</p>
Method Password(pName As %String) As %String
{
    Set tFresh = $ClassMethod(..#FIXTURESET, "UserObject", pName, 1, "%Developer")
    Set tDiff = [{"field": "Password", "before": "", "after": ""}]
    Set tPayload = {"Enabled": true}
    Quit ..Gate(..#PASSWORDTOOL, pName, tFresh, tPayload.%ToJSON(), tDiff.%ToJSON())
}

/// <p>The shared gate's verdict on an update to <var>pName</var> moving <code>ChangePassword</code>
/// from <var>pFrom</var> to <var>pTo</var>.</p>
Method Flag(pName As %String, pFrom As %Boolean, pTo As %Boolean) As %String
{
    Set tFresh = ##class(%DynamicObject).%FromJSON($ClassMethod(..#FIXTURESET, "UserObject", pName, 1, "%Developer"))
    Do tFresh.%Set("ChangePassword", pFrom, "boolean")
    Set tPayload = ##class(%DynamicObject).%FromJSON(tFresh.%ToJSON())
    Do tPayload.%Set("ChangePassword", pTo, "boolean")
    Set tDiff = [{"field": "ChangePassword", "before": ($Select(pFrom: "true", 1: "false")), "after": ($Select(pTo: "true", 1: "false"))}]
    Quit ..Gate(..#UPDATETOOL, pName, tFresh.%ToJSON(), tPayload.%ToJSON(), tDiff.%ToJSON())
}

/// <p><method>OcuPilot.Kernel.Proposal.Operation.Gate</method>'s verdict for tool <var>pTool</var>
/// on <var>pName</var>, with the target armed as <var>pFresh</var>.</p>
Method Gate(pTool As %String, pName As %String, pFresh As %String, pPayload As %String, pDiff As %String) As %String
{
    Do $ClassMethod(..#FIXTURE, "Arm", pFresh)
    Do $ClassMethod(..#FIXTURE, "ArmLastAllHolder", "")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(pTool, .tTool)
    Do $$$AssertStatusOK(tSC, pTool _ " resolves")
    Set tRef = $ClassMethod(..#FIXTURESET, "Reference", pName, "user")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, tRef, pPayload, pDiff, {"Name": (pName)}.%ToJSON(), $Username, ..#FIXTURESET, "", .tPairs, .tRefused, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the gate answers for " _ pName)
    Quit tRefused _ "|" _ tCode
}

/// <p>Mint <var>pArgs</var> through <var>pToolClass</var> inside turn <var>pTurnKey</var> and confirm
/// it with <var>pSecrets</var>, as the agent's caller does.</p>
Method Confirm(pTurnKey As %String, pToolClass As %String, pArgs As %DynamicObject, pSecrets As %DynamicObject) As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pTurnKey)
    Set tSC = $ClassMethod(pToolClass, "View", "", pArgs, 0, .tProposal, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), pSecrets, $Username, .tResult, .tHttp, .tCode, .tDetail)
}

/// <p>Set, or clear, <var>pName</var>'s change-on-login flag directly.</p>
Method SetFlag(pName As %String, pOn As %Boolean = 1)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProps("ChangePassword") = ''pOn
        Set tSC = ##class(Security.Users).Modify(pName, .tProps)
        Set $NAMESPACE = tOrigNS
        Do $$$AssertStatusOK(tSC, "the flag of " _ pName _ " is set to " _ ''pOn)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do $$$AssertStatusOK(ex.AsStatus(), "the flag of " _ pName _ " could be set")
    }
}

Method ClearFlag(pName As %String)
{
    Do ..SetFlag(pName, 0)
}

}

/// <p>Pins Story 24.16's proposals against the namespace they were read in (AD-6, AD-52): the agent's set of a purge setting and its purge, each minted in
/// <code>USER</code> and confirmed by a request scoped to <code>HSCUSTOM</code>, act in <code>USER</code> alone, where the proposal read. The setting node of
/// <code>HSCUSTOM</code>, which holds values of its own, and the probe records it holds, back-dated as <code>USER</code>'s are, are as they were. Every judgment at the
/// confirm, the fresh read, the lock test, the settings read and the value rules, runs in the proposal's namespace.</p>
/// <p>It borrows the helpers of <class>OcuPilot.Test.InteropPurgeControl</class>. <b>What it needs from the environment:</b> interoperability-enabled <code>USER</code>
/// and <code>HSCUSTOM</code> namespaces, the HTTP test account and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It removes every probe record and puts both
/// namespaces' setting nodes back exactly as it found them.</p>
Class OcuPilot.Test.InteropPurgeElsewhere Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropPurgeFixture";

Parameter CONTROL = "OcuPilot.Test.InteropPurgeControl";

Parameter ITEMCONTROL = "OcuPilot.Test.InteropItemControl";

Parameter OTHERNAMESPACE = "HSCUSTOM";

/// <p>What both namespaces' setting nodes held when the class started.</p>
Property PreparedSettings As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSettings = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropPurgeElsewhere deletes probe records and writes the purge settings of USER and HSCUSTOM on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedSettings = $ClassMethod(..#FIXTURE, "SaveSettings")
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    If ..PreparedSettings = "" Quit $$$OK
    Quit $ClassMethod(..#FIXTURE, "RestoreSettings", ..PreparedSettings)
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    For tNamespace = "USER", "HSCUSTOM" {
        For tNode = "BodiesToo", "KeepIntegrity", "NamespaceBitmapMaint", "Desc" {
            Do $ClassMethod(..#FIXTURE, "PutSetting", tNamespace, tNode, "<absent>")
        }
    }
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "DropProbes"), "the probe records are removed from both namespaces, and none survives")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "RestoreSettings", ..PreparedSettings), "both namespaces' setting nodes are put back")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SaveSettings"), ..PreparedSettings, "and read as they did before the test")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>AC4: the agent's set of a purge setting, minted in USER and confirmed from HSCUSTOM, stores the setting in USER; HSCUSTOM's node, which holds its own value, is as it
/// was.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropPurgeSettingSet.PortQuery</method> drop the payload's namespace -- the HSCUSTOM node changes and this goes
/// red.</p>
Method TestTheSettingSetIsConfirmedInTheNamespaceItWasReadIn()
{
    Do $ClassMethod(..#FIXTURE, "PutSetting", ..#OTHERNAMESPACE, "Desc", "hsc own")
    Do $ClassMethod(..#FIXTURE, "PutSetting", ..#OTHERNAMESPACE, "BodiesToo", "1")
    Set tArgs = {"Name": "Description", "Value": "usr agent"}
    Set tSC = $ClassMethod(..#ITEMCONTROL, "MintAs", "OcuPilot.Screen.Tool.InteropPurgeSettingSet", tArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the set mints in USER: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = $ClassMethod(..#ITEMCONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer, ..#OTHERNAMESPACE)
    Do $$$AssertEquals(tStatus, 200, "the proposal confirms from a request scoped to HSCUSTOM: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject($Get(tAnswer)) && $IsObject(tAnswer.%Get("readBack")): tAnswer.readBack.verdict, 1: ""), ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "whose read-back, taken in USER, matches")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", "USER"), "<absent>|<absent>|<absent>|usr agent", "USER holds the value")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#OTHERNAMESPACE), "1|<absent>|<absent>|hsc own", "and HSCUSTOM's settings are as they were")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC4: the agent's purge, minted in USER and confirmed from HSCUSTOM, purges USER alone: USER's back-dated probe records are gone and the one made now stays, and
/// HSCUSTOM, which holds probe records dated alike and settings of its own, is as it was.</p>
/// <p>Mutation (Rule 19): drop <code>Namespace</code> from <parameter>OcuPilot.Screen.Tool.InteropPurgeRun.FINGERPRINTSUBJECT</parameter> -- the purge reaches HSCUSTOM and this
/// goes red.</p>
Method TestThePurgeIsConfirmedInTheNamespaceItWasReadIn()
{
    ; The two namespaces differ on Include message bodies, so a purge that read the confirming namespace's settings would keep USER's old body.
    Do $ClassMethod(..#FIXTURE, "PutSetting", ..#OTHERNAMESPACE, "BodiesToo", "0")
    Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", "BodiesToo", "1")
    Do $$$AssertTrue($ClassMethod(..#CONTROL, "Arrange", "USER"), "USER's probe records are arranged")
    Do $$$AssertTrue($ClassMethod(..#CONTROL, "Arrange", ..#OTHERNAMESPACE), "and HSCUSTOM's")
    Set tBefore = $ClassMethod(..#FIXTURE, "Counts", ..#OTHERNAMESPACE)
    Set tSC = $ClassMethod(..#CONTROL, "EnableKey", .tPolicy)
    Do $$$AssertStatusOK(tSC, "the purge's governance key is turned on")
    Try {
        Do $$$AssertEquals($ClassMethod(..#CONTROL, "Mint", "3650", .tProposal, .tTurn, .tReason), "minted", "the purge mints in USER: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertEquals(tProposal.target.scope _ "|" _ tProposal.target.id, "USER|USER", "its target is USER")
        Set tSC = $ClassMethod(..#ITEMCONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer, ..#OTHERNAMESPACE)
        Do $$$AssertEquals(tStatus, 200, "the proposal confirms from a request scoped to HSCUSTOM: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), "header=1 body=1 log=0 io=0 alertClosed=0 alertOpen=1", "USER's old records are gone, its old body with them as USER's own setting says, and the one made now stays")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", ..#OTHERNAMESPACE), tBefore, "and HSCUSTOM's probe records are as they were")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#OTHERNAMESPACE), "0|<absent>|<absent>|<absent>", "as are its settings")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC4: the lock test at the confirm runs in the proposal's namespace: with USER's purge lock held by a child job, the agent's purge minted in USER and confirmed
/// from HSCUSTOM, whose lock is free, is refused and deletes nothing in either namespace.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PurgeFacts</method> and <method>OcuPilot.Port.InteropPort.PerformPurge</method> take the lock in the
/// request's namespace -- this goes red. Either alone stays green: the fingerprint and the write each refuse a held lock.</p>
Method TestThePurgeConfirmedElsewhereIsRefusedWhileItsOwnNamespaceIsPurging()
{
    Do $$$AssertTrue($ClassMethod(..#CONTROL, "Arrange", "USER"), "USER's probe records are arranged")
    Do $$$AssertTrue($ClassMethod(..#CONTROL, "Arrange", ..#OTHERNAMESPACE), "and HSCUSTOM's")
    Set tUserBefore = $ClassMethod(..#FIXTURE, "Counts", "USER")
    Set tOtherBefore = $ClassMethod(..#FIXTURE, "Counts", ..#OTHERNAMESPACE)
    Set tSC = $ClassMethod(..#CONTROL, "EnableKey", .tPolicy)
    Do $$$AssertStatusOK(tSC, "the purge's governance key is turned on")
    Kill ^IRIS.Temp.OcuProbe2416Hold
    Try {
        Do $$$AssertEquals($ClassMethod(..#CONTROL, "Mint", "3650", .tProposal, .tTurn, .tReason), "minted", "the purge mints in USER: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Job ##class(OcuPilot.Test.InteropPurgeFixture).HoldLock("USER")::10
        Do $$$AssertTrue($Test, "the lock-holding job starts")
        For tI = 1:1:100 {
            If $Get(^IRIS.Temp.OcuProbe2416Hold) = 1 Quit
            Hang 0.1
        }
        Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2416Hold), 1, "it holds USER's lock")
        Set tSC = $ClassMethod(..#ITEMCONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer, ..#OTHERNAMESPACE)
        Do $$$AssertTrue(tStatus '= 200, "the confirm from HSCUSTOM is refused while USER is purging: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), tUserBefore, "USER's probe records are as they were")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", ..#OTHERNAMESPACE), tOtherBefore, "and so are HSCUSTOM's")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Set ^IRIS.Temp.OcuProbe2416Hold = "stop"
    For tI = 1:1:100 {
        If $Get(^IRIS.Temp.OcuProbe2416Hold) = 2 Quit
        Hang 0.1
    }
    Kill ^IRIS.Temp.OcuProbe2416Hold
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

}

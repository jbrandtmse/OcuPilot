/// <p>Pins Story 24.15's source-control refusal of schedule spec writes on the shipped paths, with <code>USER</code> really under source control
/// (AD-8, AD-62): the person's Save, Edit and Remove are refused 409 <code>INTEROP.SCHEDULE.SOURCECONTROL</code> with the published sentence; the
/// agent's add, update and remove are refused at the mint, so no card is made; and an update and a remove minted before source control was switched on
/// are refused at the confirm. The held schedule spec is unchanged throughout.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because each test puts <code>USER</code> under <class>OcuPilot.Test.SourceControlProbe</class>'s source-control class and
/// takes it away again. It removes every schedule spec and proposal it creates, asserts that <code>USER</code> then names no source-control class, and
/// puts back the governance policy it found.</p>
Class OcuPilot.Test.InteropScheduleSourceControl Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

Parameter NAMESPACE = "USER";

Parameter SC = "OcuPilot.Test.SourceControlProbe";

Parameter FIXTURE = "OcuPilot.Test.InteropScheduleFixture";

Parameter CLEARER = "OcuPilot.Test.InteropLookupFixture";

Parameter SCHEDULES = "OcuPilot.Test.InteropScheduleControl";

Parameter REFUSALS = "OcuPilot.Test.InteropScheduleRefusals";

Parameter NAME = "OcuProbe2415SA";

Parameter SPEC = "START:*-*-*T08:00:00,STOP:*-*-*T17:00:00";

Parameter REFUSAL = "INTEROP.SCHEDULE.SOURCECONTROL";

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropScheduleSourceControl puts " _ ..#NAMESPACE _ " under a source-control class and takes it away again, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set tSC = $ClassMethod(..#SC, "Disable", ..#NAMESPACE)
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Quit $ClassMethod(..#CLEARER, "Clear")
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#SC, "Disable", ..#NAMESPACE), "the probe's source-control class is taken out of " _ ..#NAMESPACE)
    Do $$$AssertEquals(##class(%Studio.SourceControl.Interface).SourceControlClassGet(..#NAMESPACE), "", ..#NAMESPACE _ " names no source-control class")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#CLEARER, "Clear"), "the probe schedule specs are removed")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleCount") + $ClassMethod(..#FIXTURE, "ScheduleCount", "OcuProbe2415S", "HSCUSTOM"), 0, "and none survives in either namespace")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The code of the answer <var>pAnswer</var> and its published sentence, as <code>code|sentence</code>.</p>
ClassMethod CodeAndReason(pAnswer) As %String
{
    If '$IsObject($Get(pAnswer)) Quit ""
    Quit pAnswer.%Get("code") _ "|" _ pAnswer.%Get("reason")
}

/// <p>AC2: with <code>USER</code> under source control, every write a person or the agent makes is refused on the shipped path before anything is
/// written: the person's Save, Edit and Remove over HTTP and the agent's mint of each of the three tools by <code>SOURCECONTROL</code>; of an update and
/// a remove minted while the namespace was not under source control, the update's re-read, which asks for the edit, refuses and closes the proposal
/// target-changed, and the remove is refused <code>SOURCECONTROL</code> by the write.</p>
/// <p>Mutation (Rule 19): drop the <code>SourceControlled</code> refusal from <method>OcuPilot.Port.InteropPort.ScheduleWriteRefusal</method> -- every
/// leg goes red; set <parameter>OcuPilot.Screen.Tool.InteropScheduleUpdate.READASKSACTION</parameter> to 0 -- the confirmed update's leg goes red.</p>
Method TestEveryShippedWritePathIsRefusedUnderSourceControl()
{
    Set tSchedules = ..#SCHEDULES
    Set tReason = $Parameter("OcuPilot.Api.InteropError", "REASONSCHEDULESOURCECONTROL")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutSchedule", ..#NAME, ..#SPEC, "held"), "the probe schedule spec is held")
    Kill tSettings
    Set tSettings("interop.schedules.remove") = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the remove tool's key is turned on")
    Set tSC = $ClassMethod(tSchedules, "Mint", "InteropScheduleUpdate", $ClassMethod(tSchedules, "ArgsFor", ..#NAME, {"Description": "changed"}), .tUpdate, .tFault, .tUpdateTurn)
    Do $$$AssertTrue($IsObject($Get(tUpdate)), "an update mints while the namespace is not under source control")
    Set tSC = $ClassMethod(tSchedules, "Mint", "InteropScheduleRemove", $ClassMethod(tSchedules, "ArgsFor", ..#NAME), .tRemove, .tFault, .tRemoveTurn)
    Do $$$AssertTrue($IsObject($Get(tRemove)), "and so does a remove")
    Do $$$AssertStatusOK($ClassMethod(..#SC, "Enable", ..#NAMESPACE), ..#NAMESPACE _ " is put under source control")
    Do $ClassMethod(tSchedules, "Save", $ClassMethod(tSchedules, "SaveBody", ..#NAME _ "New", ..#SPEC), .tAnswer)
    Do $$$AssertEquals(..CodeAndReason(.tAnswer), ..#REFUSAL _ "|" _ tReason, "the person's Save is refused with the published sentence")
    Do $$$AssertEquals($ClassMethod(tSchedules, "Act", "edit", ..#NAME, {"Description": "changed"}, .tAnswer), "409 " _ ..#REFUSAL, "and the person's Edit")
    Do $$$AssertEquals($ClassMethod(tSchedules, "Act", "remove", ..#NAME, "", .tAnswer), "409 " _ ..#REFUSAL, "and the person's Remove")
    For tCase = $ListBuild("InteropScheduleAdd", ..#NAME _ "New", {"ScheduleSpec": (..#SPEC)}), $ListBuild("InteropScheduleUpdate", ..#NAME, {"Description": "changed"}), $ListBuild("InteropScheduleRemove", ..#NAME, "") {
        Set tVerdict = $ClassMethod(..#REFUSALS, "MintVerdict", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), .tMintReason)
        Do $$$AssertEquals(tVerdict _ "|" _ tMintReason, ..#REFUSAL _ "|" _ tReason, $List(tCase, 1) _ ": the agent's mint is refused, and no card is made")
    }
    Set tMinted("update") = $Get(tUpdate)
    Set tMinted("remove") = $Get(tRemove)
    Set tWant("update") = "PROPOSAL.TARGETCHANGED"
    Set tWant("remove") = ..#REFUSAL
    For tKind = "update", "remove" {
        Set tProposal = tMinted(tKind)
        Do $$$AssertTrue($IsObject(tProposal), "the " _ tKind _ " minted before is there to confirm")
        If '$IsObject(tProposal) Continue
        Set tStatus = $ClassMethod(tSchedules, "Confirm", tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), tWant(tKind), "the " _ tKind _ " minted before is refused at the confirm: " _ $Extract($Get(tRaw), 1, 300))
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), ..#SPEC _ "|held|0", "the held schedule spec is unchanged")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleCount"), 1, "and nothing was added")
    For tTurn = $Get(tUpdateTurn), $Get(tRemoveTurn) {
        If tTurn '= "" Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
}

}

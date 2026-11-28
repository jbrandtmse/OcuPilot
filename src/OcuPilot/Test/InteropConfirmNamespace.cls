/// <p>Pins that a confirmed write of three <code>InteropPort</code> tools acts in the namespace its proposal read (AD-52, AD-62):
/// the agent's remove of a business partner, its remove of a lookup entry and its delete of a lookup table, each minted in
/// <code>USER</code> and confirmed by a request scoped to <code>HSCUSTOM</code>, where the same row is held. The confirm answers 200,
/// <code>USER</code>'s row goes and <code>HSCUSTOM</code>'s is left as it was.</p>
/// <p>It borrows the transport helpers of <class>OcuPilot.Test.InteropItemControl</class>. <b>What it needs from the environment:</b>
/// interoperability-enabled <code>USER</code> and <code>HSCUSTOM</code> namespaces, the HTTP test account and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It removes every probe row it makes in both namespaces, deletes its
/// ledger rows and puts the governance policy back.</p>
Class OcuPilot.Test.InteropConfirmNamespace Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter OTHERNAMESPACE = "HSCUSTOM";

Parameter PARTNER = "OcuProbe226Ns";

Parameter TABLE = "OcuProbe205Ns";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropConfirmNamespace writes probe lookup tables and business partners in USER and HSCUSTOM on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ..ClearProbes()
}

Method OnAfterAllTests() As %Status
{
    Quit ..ClearProbes()
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit ..ClearProbes()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(..ClearProbes(), "the probe tables and partners are removed from both namespaces")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Remove every probe table and partner from <code>USER</code>, and the two this class makes from <code>HSCUSTOM</code>.</p>
ClassMethod ClearProbes() As %Status
{
    Set tFixture = ..#FIXTURE
    Set tSC = $ClassMethod(tFixture, "Clear")
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFixture, "Drop", ..#TABLE, ..#OTHERNAMESPACE))
    Quit $$$ADDSC(tSC, $ClassMethod(tFixture, "DropPartners", ..#PARTNER, ..#OTHERNAMESPACE))
}

/// <p>Confirm <var>pProposal</var> over HTTP from a request scoped to <parameter>OTHERNAMESPACE</parameter>: the status, and the
/// single envelope's answer in <var>pAnswer</var>.</p>
ClassMethod ConfirmFromOther(pProposal As %DynamicObject, Output pAnswer, Output pRaw) As %Integer
{
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", pProposal.proposalId, .tStatus, .pRaw, .pAnswer, ..#OTHERNAMESPACE)
    Quit tStatus
}

/// <p>The arguments of a call that names <var>pName</var> as <code>Name</code>.</p>
ClassMethod NameArgs(pName As %String) As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set("Name", pName, "string")
    Quit tArgs
}

/// <p>Matrix row 1: a partner removed by a proposal minted in <code>USER</code> and confirmed from <code>HSCUSTOM</code>, where the
/// same partner is held, goes from <code>USER</code> and stays in <code>HSCUSTOM</code>.</p>
/// <p>Mutation (Rule 19): take <code>Namespace</code> out of <parameter>OcuPilot.Screen.Tool.InteropPartnerRemove.FINGERPRINTSUBJECT</parameter>
/// -- the confirm removes HSCUSTOM's partner and this goes red.</p>
Method TestAPartnerRemoveConfirmedFromAnotherNamespaceActsWhereItRead()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutPartner", ..#PARTNER), "the partner is held in USER")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutPartner", ..#PARTNER, "", ..#OTHERNAMESPACE), "and the same partner in HSCUSTOM")
    Set tHeld = $ClassMethod(tFixture, "PartnerText", ..#PARTNER, ..#OTHERNAMESPACE)
    Do $$$AssertEquals($ClassMethod(tFixture, "PartnerText", ..#PARTNER), tHeld, "the two are identical: " _ tHeld)
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Set tTurn = ""
    Try {
        Kill tSettings
        Set tSettings("interop.businesspartners.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the remove's key is turned on")
        Set tSC = $ClassMethod("OcuPilot.Test.InteropPartnerControl", "Mint", "InteropPartnerRemove", $ClassMethod("OcuPilot.Test.InteropPartnerControl", "ArgsFor", ..#PARTNER), .tProposal, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "the remove mints in USER: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Quit
        Set tStatus = ..ConfirmFromOther(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "a confirm sent from HSCUSTOM answers: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(tFixture, "PartnerText", ..#PARTNER), "<absent>", "it removed the partner in USER, where the proposal read")
        Do $$$AssertEquals($ClassMethod(tFixture, "PartnerText", ..#PARTNER, ..#OTHERNAMESPACE), tHeld, "and left HSCUSTOM's alone")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the partner leg raised")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>Matrix row 2: an entry removed by a proposal minted in <code>USER</code> and confirmed from <code>HSCUSTOM</code>, where the
/// same table holds the same entries, goes from <code>USER</code>'s table and stays in <code>HSCUSTOM</code>'s.</p>
/// <p>Mutation (Rule 19): take <code>Namespace</code> out of <parameter>OcuPilot.Screen.Tool.InteropLookupEntryRemove.FINGERPRINTSUBJECT</parameter>
/// -- the confirm removes HSCUSTOM's entry and this goes red.</p>
Method TestAnEntryRemoveConfirmedFromAnotherNamespaceActsWhereItRead()
{
    Set tFixture = ..#FIXTURE
    For tNamespace = "", ..#OTHERNAMESPACE {
        Do $$$AssertStatusOK($ClassMethod(tFixture, "Put", ..#TABLE, "k", "same", tNamespace), "the entry k is held in " _ $Select(tNamespace = "": "USER", 1: tNamespace))
        Do $$$AssertStatusOK($ClassMethod(tFixture, "Put", ..#TABLE, "keep", "1", tNamespace), "with the entry keep")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Set tTurn = ""
    Try {
        Kill tSettings
        Set tSettings("interop.lookupentries.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the remove's key is turned on")
        Set tSC = $ClassMethod("OcuPilot.Test.InteropLookupControl", "Mint", "InteropLookupEntryRemove", $ClassMethod("OcuPilot.Test.InteropLookupControl", "ArgsFor", ..#TABLE, "k"), .tProposal, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "the remove mints in USER: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Quit
        Set tStatus = ..ConfirmFromOther(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "a confirm sent from HSCUSTOM answers: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "keep=1", "it removed the entry in USER, where the proposal read")
        Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE, ..#OTHERNAMESPACE), "k=same;keep=1", "and left HSCUSTOM's alone")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the entry leg raised")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>Matrix row 3: a table deleted by a proposal minted in <code>USER</code> and confirmed from <code>HSCUSTOM</code>, where a table of
/// the same name holds the same entry, goes from <code>USER</code> and stays in <code>HSCUSTOM</code>.</p>
/// <p>Mutation (Rule 19): take <code>Namespace</code> out of <parameter>OcuPilot.Screen.Tool.InteropLookupTableDelete.FINGERPRINTSUBJECT</parameter>
/// -- the confirm deletes HSCUSTOM's table and this goes red.</p>
Method TestATableDeleteConfirmedFromAnotherNamespaceActsWhereItRead()
{
    Set tFixture = ..#FIXTURE
    For tNamespace = "", ..#OTHERNAMESPACE {
        Do $$$AssertStatusOK($ClassMethod(tFixture, "Put", ..#TABLE, "a", "1", tNamespace), "the table holds a=1 in " _ $Select(tNamespace = "": "USER", 1: tNamespace))
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Set tTurn = ""
    Try {
        Kill tSettings
        Set tSettings("interop.lookuptables.delete") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the delete's key is turned on")
        Set tSC = $ClassMethod("OcuPilot.Test.InteropLookupControl", "Mint", "InteropLookupTableDelete", ..NameArgs(..#TABLE), .tProposal, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "the delete mints in USER: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Quit
        Set tStatus = ..ConfirmFromOther(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "a confirm sent from HSCUSTOM answers: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(tFixture, "Exists", ..#TABLE), 0, "it deleted the table in USER, where the proposal read")
        Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE, ..#OTHERNAMESPACE), "a=1", "and left HSCUSTOM's alone")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the table leg raised")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

}

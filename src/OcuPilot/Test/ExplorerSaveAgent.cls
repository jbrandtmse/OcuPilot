/// <p>Story 20.21's agent save, end to end in process (AD-6, AD-34, AD-53, AD-22): the Edit mints one
/// changed-lines row with the compile named as the consequence; a routine's edit does the same; a confirm
/// saves the new text and answers the compile's output; a save that does not compile is confirmed and
/// says so; a document changed after the mint is refused 409 and nothing is written.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving
/// over HTTP as <class>OcuPilot.Test.Http</class>'s account, and a <code>USER</code> namespace. It creates
/// and removes the documents <class>OcuPilot.Test.ExplorerSaveAgentProbe</class> names, snapshots the stored
/// governance policy before each test, clears it and puts it back after it, and it runs under one test run
/// at a time on that instance.</p>
Class OcuPilot.Test.ExplorerSaveAgent Extends %UnitTest.TestCase
{

/// <p>The namespace the probe documents are created in.</p>
Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerSaveAgentProbe";

Parameter CLASSTOOL = "explorer.classes.save";

Parameter ROUTINETOOL = "explorer.routines.save";

Parameter ALPHA = "OcuProbe2021.Alpha";

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "every probe document is removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The text of the probe class: its one method answers <var>pAnswer</var>.</p>
ClassMethod ClassText(pAnswer As %String = "1") As %String
{
    Quit $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, pAnswer)
}

/// <p>The edit that changes the probe's answer from 1 to <var>pAnswer</var>.</p>
ClassMethod EditOf(pAnswer As %String = "2") As %DynamicObject
{
    Quit {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": "    Quit 1", "New": ("    Quit " _ pAnswer)}], "rationale": "change the answer", "expectedImpact": "the method answers the new value"}
}

/// <p>The Edit mints one proposal: its change is one changed-lines row with three lines of context, and its
/// stored consequence is <code>EXPLORER.SAVE.COMPILES</code>.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.ExplorerSave.ADVERTISED</parameter> 0 -- this
/// goes red.</p>
Method TestTheEditMintsOneChangedLinesRow()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Rewrite", ..#PROBENAMESPACE, ..#ALPHA, "1"), "the class holds its text")
    Set tSC = ..DispatchEdit(..#CLASSTOOL, ..EditOf("2"), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "the Edit is minted: " _ $Extract($Get(tContent), 1, 300))
    If '$IsObject($Get(tProposal)) Quit
    Set tChanged = tProposal.changed
    Do $$$AssertEquals(tChanged.%Size(), 1, "one changed-lines row")
    Set tRow = tChanged.%Get(0)
    Do $$$AssertEquals(tRow.kind _ " " _ tRow.field, "lines Text", "the row is kind lines")
    Do $$$AssertEquals(tRow.line, 3, "the first line shown is three lines above the change")
    Do $$$AssertTrue((tRow.before [ "    Quit 1") && (tRow.after [ "    Quit 2") && (tRow.before'[ "Quit 2"), "the row shows the old line and the new line")
    Set tStored = ##class(OcuPilot.Test.ExplorerWrite).StoredText(tProposal.proposalId, .tLedgerRows)
    Do $$$AssertTrue(tStored [ "EXPLORER.SAVE.COMPILES", "the stored consequence is the compile's: " _ $Extract(tStored, 1, 200))
}

/// <p>The routine's Edit mints the same kind of proposal through the Routines list's own tool.</p>
Method TestTheRoutineEditMints()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe2021Mac.mac"), "a probe routine is saved")
    Set tArgs = {"Names": "OcuProbe2021Mac.mac", "Edits": [{"Old": " Quit", "New": " Quit 1"}]}
    Set tSC = ..DispatchEdit(..#ROUTINETOOL, tArgs, .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "the routine Edit is minted: " _ $Extract($Get(tContent), 1, 300))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%Size(), 1, "a routine row is present")
    Do $$$AssertTrue(tProposal.changed.%Get(0).after [ " Quit 1", "the new line is shown")
}

/// <p>Confirm saves the new text and answers the compile's output with no errors.</p>
Method TestTheConfirmSavesAndCompiles()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tSC = ..DispatchEdit(..#CLASSTOOL, ..EditOf("2"), .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) Do $$$AssertTrue(0, "the Edit is minted: " _ $Extract($Get(tContent), 1, 300)) Quit
    Set tConfirmSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tConfirmSC, "the confirm writes: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.state _ " " _ tResult.action, "confirmed updated", "the proposal is confirmed")
    Do $$$AssertEquals($Piece(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#ALPHA _ ".cls"), $Char(10), 6), "    Quit 2", "the source is the new text")
    Do $$$AssertEquals(tResult.output.errors, 0, "the compile reports no errors")
}

/// <p>A save that leaves the class uncompilable is confirmed; its source is the new text and the output
/// says it did not compile.</p>
Method TestTheSavedButNotCompiledIsSaid()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tSC = ..DispatchEdit(..#CLASSTOOL, ..EditOf("(1"), .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) Do $$$AssertTrue(0, "the Edit is minted: " _ $Extract($Get(tContent), 1, 300)) Quit
    Set tConfirmSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tConfirmSC, "the confirm writes: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.state, "confirmed", "the proposal is confirmed")
    Do $$$AssertEquals($Select($IsObject(tResult.%Get("output")): tResult.output.%GetTypeOf("errors") _ ":" _ tResult.output.errors, 1: "none"), "boolean:1", "the compile did not compile: " _ tResult.%ToJSON())
    Do $$$AssertTrue($Piece(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#ALPHA _ ".cls"), $Char(10), 6) = "    Quit (1", "the instance holds the new text")
}

/// <p>A document changed after the mint is refused 409 <code>TARGETCHANGED</code> at the confirm, the
/// kernel's changed-target answer and not the port's version conflict, and nothing is written: the source is
/// the other writer's text.</p>
Method TestAChangedDocumentIsRefusedAndNothingIsWritten()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tSC = ..DispatchEdit(..#CLASSTOOL, ..EditOf("2"), .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) Do $$$AssertTrue(0, "the Edit is minted: " _ $Extract($Get(tContent), 1, 300)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Rewrite", ..#PROBENAMESPACE, ..#ALPHA, "9"), "another writer changes the class")
    Set tConfirmSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a changed target")
    Do $$$AssertEquals($Piece(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#ALPHA _ ".cls"), $Char(10), 6), "    Quit 9", "and the source is the other writer's text")
}

/// <p>Sends one tool call through the agent's dispatcher in the probe namespace, as the turn's loop does.</p>
ClassMethod DispatchEdit(pTool As %String, pInput As %DynamicObject, Output pContent, Output pIsError, Output pProposal) As %Status
{
    Set tWrite = ##class(OcuPilot.Test.ExplorerWrite).%New("")
    Set tSC = tWrite.DispatchFor(pTool, ..#PROBENAMESPACE, pInput, .pContent, .pIsError, .pProposal)
    Quit tSC
}

}

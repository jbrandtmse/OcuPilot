/// <p>Pins Story 20.16's editor saves end to end on probe documents in <code>USER</code> (AD-6, AD-10, AD-15, AD-22, AD-41,
/// AD-53, AD-61, AD-62): the agent's edit of a rule, a business process written in BPL and a data transformation written in DTL
/// mints one destructive lines row requiring the routines database's WRITE and the editor reload as its consequence, saves and
/// compiles on Confirm, is marked and ledgered as <code>ok</code>, and reads back as the new text; a class another writer changed
/// after the mint is refused 409 <code>TARGETCHANGED</code> with nothing written; and a BPL or a DTL that no longer compiles is
/// confirmed and says so.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and a <code>USER</code> namespace that
/// runs interoperability. It makes and removes the <code>OcuProbe2016</code> probe package
/// (<class>OcuPilot.Test.InteropEditorProbe</class>) before and after each test, and snapshots the stored governance policy
/// before each test and puts it back after it.</p>
Class OcuPilot.Test.InteropEditorSave Extends %UnitTest.TestCase
{

Parameter NAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.InteropEditorProbe";

Parameter PACKAGE = "OcuProbe2016";

/// <p>The three editors, <code>&lt;probe kind&gt;|&lt;tool&gt;|&lt;text the edit replaces&gt;|&lt;its replacement&gt;</code>.</p>
Parameter EDITS = "rule|interop.ruleeditor.save|OcuProbeTarget|OcuProbeTargetTwo;process|interop.processeditor.save|probe-one|probe-two;transform|interop.transformeditor.save|source.StringValue'|source.StringValue_""-edited""'";

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
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Remove", ..#PACKAGE)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PACKAGE), "every probe document, generated class and cache node is removed")
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.InteropEditorProbe", "ForgetLedger"), "the ledger rows of the probe turns are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Sends <var>pTool</var> with <var>pInput</var> through the agent's dispatcher in <code>USER</code>, inside a completed turn
/// seeded for the running account.</p>
ClassMethod Dispatch(pTool As %String, pInput As %DynamicObject, Output pContent, Output pIsError, Output pProposal) As %Status
{
    Set tWrite = ##class(OcuPilot.Test.ExplorerWrite).%New("")
    Quit tWrite.DispatchFor(pTool, ..#NAMESPACE, pInput, .pContent, .pIsError, .pProposal)
}

/// <p>The stored text of probe class <var>pName</var> (without <code>.cls</code>), its lines joined by line feeds.</p>
ClassMethod Stored(pName As %String) As %String
{
    Quit ##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#NAMESPACE, pName _ ".cls")
}

/// <p>Probe <var>pKind</var>'s edit as <code>{Names, Edits}</code>, replacing <var>pOld</var> with <var>pNew</var> when given.</p>
ClassMethod EditOf(pKind As %String, pOld As %String = "", pNew As %String = "") As %DynamicObject
{
    For tI = 1:1:$Length(..#EDITS, ";") {
        Set tRow = $Piece(..#EDITS, ";", tI)
        If $Piece(tRow, "|", 1) = pKind Quit
    }
    If pOld = "" Set pOld = $Piece(tRow, "|", 3), pNew = $Piece(tRow, "|", 4)
    Quit {"Names": ($ClassMethod(..#PROBE, "Name", pKind, ..#PACKAGE) _ ".cls"), "Edits": [{"Old": (pOld), "New": (pNew)}], "rationale": "change the probe", "expectedImpact": "the probe changes"}
}

/// <p>Each editor's save mints one destructive lines row that requires <code>%Development:USE</code> and WRITE on the routines
/// database and names the editor reload, writes and compiles nothing at the mint, and on Confirm saves the new text, compiles it
/// without error, is marked and ledgered as <code>ok</code>, and answers its target as the class in <code>USER</code>.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.InteropEditorSave</class> answers the explorer save's consequence
/// -- the consequence leg goes red.</p>
Method TestEachEditorSaveIsMintedAndConfirmed()
{
    For tI = 1:1:$Length(..#EDITS, ";") {
        Set tRow = $Piece(..#EDITS, ";", tI)
        Set tKind = $Piece(tRow, "|", 1)
        Set tTool = $Piece(tRow, "|", 2)
        Set tName = $ClassMethod(..#PROBE, "Name", tKind, ..#PACKAGE)
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", tKind, ..#PACKAGE), tKind _ ": the probe is saved and compiled")
        Set tBefore = ..Stored(tName)
        Do $$$AssertTrue(tBefore [ $Piece(tRow, "|", 3), tKind _ ": the stored text holds the text the edit replaces")
        Set tSC = ..Dispatch(tTool, ..EditOf(tKind), .tContent, .tIsError, .tProposal)
        If '$IsObject($Get(tProposal)) || tIsError {
            Do $$$AssertTrue(0, tTool _ ": the edit is minted: " _ $Extract($Get(tContent), 1, 300))
            Continue
        }
        Do $$$AssertEquals(tProposal.changed.%Size(), 1, tTool _ ": the proposal carries one changed row")
        Set tChange = tProposal.changed.%Get(0)
        Do $$$AssertEquals(tChange.field _ "|" _ tChange.kind, "Text|lines", tTool _ ": a lines row for the Text field")
        Do $$$AssertTrue((tChange.before [ $Piece(tRow, "|", 3)) && (tChange.after [ $Piece(tRow, "|", 4)), tTool _ ": it holds the change")
        Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.proposalId, .tFound, .tValues)
        Do $$$AssertTrue($Get(tFound), tTool _ ": the proposal is stored")
        Do $$$AssertEquals($Get(tValues("destructive")) _ " " _ $Get(tValues("consequence")), "1 INTEROP.EDITOR.RELOADS", tTool _ ": it is destructive and its consequence is the editor reload")
        Do $$$AssertTrue(($Get(tValues("requiredPairs")) [ "%Development:USE") && ($Get(tValues("requiredPairs")) [ "%DB_USER:WRITE"), tTool _ ": it requires %Development:USE and WRITE on the routines database: " _ $Get(tValues("requiredPairs")))
        Do $$$AssertEquals(..Stored(tName), tBefore, tTool _ ": nothing is saved before Confirm")

        Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#NAMESPACE, tProposal, .tResult, .tHttp, .tCode)
        Do $$$AssertStatusOK(tSC, tTool _ ": the confirm writes: " _ $Get(tCode))
        If '$IsObject($Get(tResult)) Continue
        Do $$$AssertEquals(tResult.state _ " " _ tResult.action _ " " _ tResult.auditMarked, "confirmed updated 1", tTool _ ": confirmed, as an update, and marked")
        Do $$$AssertEquals(tProposal.target.%ToJSON(), "{""type"":""class"",""scope"":""" _ ..#NAMESPACE _ """,""id"":""" _ tName _ ".cls""}", tTool _ ": its target is the class in " _ ..#NAMESPACE)
        Set tAfter = ..Stored(tName)
        Do $$$AssertTrue((tAfter [ $Piece(tRow, "|", 4)) && (tBefore '[ $Piece(tRow, "|", 4)), tTool _ ": the class holds the new text")
        Do $$$AssertEquals($Select($IsObject(tResult.%Get("output")): tResult.output.%GetTypeOf("errors") _ ":" _ tResult.output.errors, 1: "none"), "boolean:0", tTool _ ": the compile reports no error: " _ $Extract(tResult.%ToJSON(), 1, 600))
        Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.proposalId, .tFound, .tValues)
        Do $$$AssertEquals($Get(tValues("targetRef")), "class" _ $Char(2) _ ..#NAMESPACE _ $Char(2) _ tName _ ".cls", tTool _ ": the confirmed row's target is type class, scope " _ ..#NAMESPACE _ ", the class")
        Set tSC = ##class(OcuPilot.Kernel.State.Ledger).GuardedIdsForWindow($Username, "", $Get(tValues("turnKey")), 100, .tIds, .tProblem)
        Set tWrites = 0
        For tJ = 1:1:+$Get(tIds) {
            Kill tLedger
            Do ##class(OcuPilot.Kernel.State.Ledger).GuardedRow(tIds(tJ), .tLedger)
            If ($Get(tLedger("kind")) = "write") && ($Get(tLedger("name")) = tTool) {
                Set tWrites = tWrites + 1
                Do $$$AssertEquals($Get(tLedger("status")) _ " " _ $Get(tLedger("auditMarked")), "ok marked", tTool _ ": the write's ledger row is ok and marked")
                Do $$$AssertTrue($Get(tLedger("target")) [ (tName _ ".cls"), tTool _ ": and names the class: " _ $Get(tLedger("target")))
            }
        }
        Do $$$AssertEquals(tWrites, 1, tTool _ ": one write row for the save")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PACKAGE), tKind _ ": the probe is removed before the next kind")
    }
}

/// <p>A class another writer changed after the mint is refused 409 <code>TARGETCHANGED</code>, the kernel's changed-target answer,
/// with the other writer's text left in place.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.InteropEditorSave</class> overrides <parameter>FINGERPRINTSUBJECT</parameter>
/// without <code>Modified</code> -- the confirm passes the fingerprint and is refused on another ground, so this goes red.</p>
Method TestAnOutsideRewriteAfterTheMintIsRefusedAsAChangedTarget()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "transform", ..#PACKAGE)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", "transform", ..#PACKAGE), "the probe is saved and compiled")
    Set tSC = ..Dispatch("interop.transformeditor.save", ..EditOf("transform"), .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError Do $$$AssertTrue(0, "the edit is minted: " _ $Extract($Get(tContent), 1, 300)) Quit
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.ExplorerSaveProbe", "Rewrite", ..#NAMESPACE, tName, "9"), "another writer changes the class")
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#NAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a changed target")
    Do $$$AssertEquals($Piece(..Stored(tName), $Char(10), 6), "    Quit 9", "and the class holds the other writer's text")
}

/// <p>An edit that leaves a BPL's generated class failing to compile, or a DTL whose code does not compile, is confirmed: the
/// class holds the new text and the output says the compile reported an error.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.SaveSet</method> reports its compile's errors as false -- both legs go red.</p>
Method TestAnEditThatDoesNotCompileIsSavedAndSaysSo()
{
    For tCase = $ListBuild("process", "interop.processeditor.save", $ClassMethod(..#PROBE, "Name", "process", ..#PACKAGE), $Parameter(..#PROBE, "BPLTRACE"), $Parameter(..#PROBE, "BROKENCODE") _ $Char(10) _ $Parameter(..#PROBE, "BPLTRACE")), $ListBuild("transform", "interop.transformeditor.save", $ClassMethod(..#PROBE, "Name", "transform", ..#PACKAGE), $Parameter(..#PROBE, "DTLASSIGN"), $Parameter(..#PROBE, "DTLASSIGN") _ $Char(10) _ $Parameter(..#PROBE, "BROKENCODE")) {
        Set tKind = $List(tCase, 1)
        Set tTool = $List(tCase, 2)
        Set tName = $List(tCase, 3)
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", tKind, ..#PACKAGE), tKind _ ": the probe is saved and compiled")
        Set tSC = ..Dispatch(tTool, ..EditOf(tKind, $List(tCase, 4), $List(tCase, 5)), .tContent, .tIsError, .tProposal)
        If '$IsObject($Get(tProposal)) || tIsError {
            Do $$$AssertTrue(0, tTool _ ": the edit is minted: " _ $Extract($Get(tContent), 1, 300))
            Continue
        }
        Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#NAMESPACE, tProposal, .tResult, .tHttp, .tCode)
        Do $$$AssertStatusOK(tSC, tTool _ ": the confirm writes: " _ $Get(tCode))
        If '$IsObject($Get(tResult)) Continue
        Do $$$AssertEquals(tResult.state, "confirmed", tTool _ ": the proposal is confirmed")
        Do $$$AssertTrue(..Stored(tName) [ $Parameter(..#PROBE, "BROKENCODE"), tTool _ ": the class holds the new text")
        Do $$$AssertEquals($Select($IsObject(tResult.%Get("output")): tResult.output.%GetTypeOf("errors") _ ":" _ tResult.output.errors, 1: "none"), "boolean:1", tTool _ ": the compile reports an error: " _ $Extract(tResult.%ToJSON(), 1, 600))
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PACKAGE), tKind _ ": the probe is removed before the next kind")
    }
}

}

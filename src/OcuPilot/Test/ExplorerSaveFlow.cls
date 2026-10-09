/// <p>Story 20.21's agent save through the dispatcher on probe documents in <code>USER</code> (AD-6, AD-10,
/// AD-15, AD-22, AD-41, AD-53, DW-2228): each refusal that comes before the document is read (OcuPilot's own
/// code, a <code>%</code> name, <code>%SYS</code>, a class or routine stored in another database) answers its
/// code for a document that does not exist, while a missing document of the namespace's own database answers
/// <code>PORT.NOTFOUND</code>; a name set or another kind of document is refused; the closed schema refuses a
/// text, a version or a compile choice; the proposal is destructive, requires WRITE on the routines
/// database, shows the model its hunk and not the document, and writes and compiles nothing before Confirm; a
/// routine and an include file are saved and compiled on Confirm; a routine header rename and a text past the
/// port's bound are refused; a confirmed save is marked, ledgered as <code>ok</code> and stores no compile
/// line; a second proposal against the same document is refused 409 once the first is confirmed; the save
/// key governs the agent at the dispatcher and at Confirm; and the provider is shown the contract.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over
/// HTTP as <class>OcuPilot.Test.Http</class>'s account, a <code>USER</code> namespace, and the
/// <code>ENSLIB</code> database mapped for the <code>Ens</code> package and its routines. It creates and
/// removes the documents <class>OcuPilot.Test.ExplorerSaveAgentProbe</class> names, and snapshots the stored
/// governance policy before each test and puts it back after it.</p>
Class OcuPilot.Test.ExplorerSaveFlow Extends %UnitTest.TestCase
{

Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerSaveAgentProbe";

Parameter CLASSTOOL = "explorer.classes.save";

Parameter ROUTINETOOL = "explorer.routines.save";

Parameter ALPHA = "OcuProbe2021.Flow";

Parameter MACRO = "OcuProbe2021Mac.mac";

Parameter INCLUDE = "OcuProbe2021Inc.inc";

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
    Quit $ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE)
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

/// <p>Sends <var>pTool</var> with <var>pInput</var> through the agent's dispatcher in <var>pNamespace</var>,
/// inside a completed turn seeded for the running account.</p>
ClassMethod Dispatch(pNamespace As %String, pTool As %String, pInput As %DynamicObject, Output pContent, Output pIsError, Output pProposal) As %Status
{
    Set tWrite = ##class(OcuPilot.Test.ExplorerWrite).%New("")
    Quit tWrite.DispatchFor(pTool, pNamespace, pInput, .pContent, .pIsError, .pProposal)
}

/// <p>The <code>code</code> member of the JSON result <var>pContent</var>, or <code>""</code>.</p>
ClassMethod CodeOf(pContent As %String) As %String
{
    Set tCode = ""
    Try {
        Set tCode = ##class(%DynamicAbstractObject).%FromJSON(pContent).%Get("code")
    } Catch {
        Set tCode = ""
    }
    Quit tCode
}

/// <p>The problem sentence a refusal carries in <code>detail.problem</code>, or <code>""</code>.</p>
ClassMethod ProblemOf(pContent As %String) As %String
{
    Set tProblem = ""
    Try {
        Set tProblem = ##class(%DynamicAbstractObject).%FromJSON(pContent).detail.problem
    } Catch {
        Set tProblem = ""
    }
    Quit tProblem
}

/// <p>The probe class's one-line edit, <code>Quit 1</code> to <code>Quit pAnswer</code>.</p>
ClassMethod EditOf(pAnswer As %String = "2") As %DynamicObject
{
    Quit {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": "    Quit 1", "New": ("    Quit " _ pAnswer)}]}
}

/// <p>Asserts that the call of <var>pTool</var> for <var>pName</var> in <var>pNamespace</var> is refused with
/// <var>pCode</var>, with <var>pText</var> in its problem, and that no proposal row is added for the tool.</p>
Method Refused(pNamespace As %String, pTool As %String, pName As %String, pCode As %String, pText As %String)
{
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(pTool)
    Set tSC = ..Dispatch(pNamespace, pTool, {"Names": (pName), "Edits": [{"Old": "    Quit 1", "New": "    Quit 2"}]}, .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError, pName _ " is refused: " _ $Extract($Get(tContent), 1, 240))
    Do $$$AssertEquals(..CodeOf($Get(tContent)), pCode, pName _ " answers " _ pCode)
    Do $$$AssertTrue(..ProblemOf($Get(tContent)) [ pText, pName _ " names its reason (" _ pText _ "): " _ ..ProblemOf($Get(tContent)))
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(pTool), tBefore, pName _ " adds no proposal")
}

/// <p>The refusals that come before the read answer their own code for a document that does not exist --
/// had the mint read it first, they would answer <code>PORT.NOTFOUND</code> -- while a document of the
/// namespace's own database that does not exist answers it.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.ExplorerSaveMint</class> asks <code>AgentProblem</code>
/// after the read -- the mapped, <code>%</code> and <code>%SYS</code> legs go red.</p>
Method TestARefusalComesBeforeTheReadOfTheDocument()
{
    Set tArguments = "TOOL.ARGUMENTS"
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "OcuPilotProbe2021.Missing.cls", "PROHIBITED.OCUPILOTCODE", "")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "%OcuProbe2021.Missing.cls", tArguments, "begins with %")
    Do ..Refused("%SYS", ..#CLASSTOOL, "Security.NoSuch2021.cls", tArguments, "in %SYS")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "Ens.NoSuch2021.cls", tArguments, "database ENSLIB")
    Do ..Refused(..#PROBENAMESPACE, ..#ROUTINETOOL, "EnsNoSuch2021.mac", tArguments, "database ENSLIB")
    Do ..Refused(..#PROBENAMESPACE, ..#ROUTINETOOL, "%OcuProbe2021.mac", tArguments, "begins with %")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "OcuProbe2021.Missing.cls", "PORT.NOTFOUND", "")
    Do ..Refused(..#PROBENAMESPACE, ..#ROUTINETOOL, "OcuProbe2021Missing.mac", "PORT.NOTFOUND", "")
}

/// <p>Exactly one document of the tool's own kind: a set of two names, a routine named to the Classes tool and a
/// class named to the Routines tool are refused 400 and add no proposal.</p>
Method TestANameSetOrAnotherKindOfDocumentIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tArguments = "TOOL.ARGUMENTS"
    Set tOne = "exactly one document"
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, ..#ALPHA _ ".cls," _ ..#ALPHA _ "2.cls", tArguments, tOne)
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, ..#MACRO, tArguments, tOne)
    Do ..Refused(..#PROBENAMESPACE, ..#ROUTINETOOL, ..#ALPHA _ ".cls", tArguments, tOne)
}

/// <p>The text, the version and the compile choice are never arguments: a call carrying any of them is refused
/// 400 by the closed schema and adds no proposal, as is a list of twenty-one replacements.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSave.InputSchema</method> allows additional
/// properties -- the extra-member legs go red.</p>
Method TestTheAgentCannotSupplyTheTextTheVersionOrTheCompileChoice()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CLASSTOOL)
    For tMember = "content", "version", "Compile" {
        Set tInput = ..EditOf("2")
        Do tInput.%Set(tMember, $Select(tMember = "Compile": 0, 1: "x"))
        Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, tInput, .tContent, .tIsError, .tProposal)
        Do $$$AssertTrue($$$ISOK(tSC) && tIsError && (..CodeOf($Get(tContent)) = "TOOL.ARGUMENTS"), tMember _ " is refused as an argument: " _ $Extract($Get(tContent), 1, 200))
    }
    Set tMany = []
    For tI = 1:1:21 Do tMany.%Push({"Old": "    Quit 1", "New": "    Quit 2"})
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, {"Names": (..#ALPHA _ ".cls"), "Edits": (tMany)}, .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError && (..CodeOf($Get(tContent)) = "TOOL.ARGUMENTS"), "twenty-one replacements are refused: " _ $Extract($Get(tContent), 1, 200))
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CLASSTOOL), tBefore, "and none of the calls adds a proposal")
    Do $$$AssertEquals($Piece(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#ALPHA _ ".cls"), $Char(10), 6), "    Quit 1", "nor changes the document")
}

/// <p>The proposal a 40-line class's edit mints: the model's result carries the hunk and neither the document
/// nor the new text; the stored row is destructive, requires WRITE on the routines database, names the
/// compile as its consequence, holds the whole new text and the compile choice, and carries the agent's
/// rationale, expected impact and reverse; and nothing is saved or compiled before Confirm.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSaveMint.Hunk</method> starts every hunk at
/// line 1 -- the far-lines leg goes red. <class>OcuPilot.Screen.Tool.ExplorerSaveMint</class> stops copying
/// <code>rationale</code>, <code>expectedImpact</code> and <code>reverse</code> into the rewritten arguments --
/// the agent's-words leg goes red.</p>
Method TestTheMintedProposalShowsTheHunkRequiresTheWriteAndWritesNothing()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Wide", ..#PROBENAMESPACE, ..#ALPHA, 40), "a 40-line probe class is saved")
    Set tBefore = ##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": "    Set x20 = 20", "New": "    Set x20 = 0"}], "rationale": "zero one line", "expectedImpact": "x20 is zero", "reverse": "set x20 back to 20"}, .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "the edit is minted: " _ $Extract($Get(tContent), 1, 300))
    If '$IsObject($Get(tProposal)) Quit
    Set tRow = tProposal.changed.%Get(0)
    Do $$$AssertEquals(tRow.kind _ " " _ tRow.line, "lines 22", "the row is a lines row from three lines above the change at 25")
    Do $$$AssertTrue((tRow.before [ "Set x20 = 20") && (tRow.after [ "Set x20 = 0") && (tRow.before [ "Set x17 = 17") && (tRow.before [ "Set x23 = 23"), "it holds the change and three lines either side")
    Do $$$AssertTrue((tContent '[ "Set x1 = 1") && (tContent '[ "Set x40 = 40") && (tContent '[ ("Class " _ ..#ALPHA)), "the model's result holds neither the document's first line, its last, nor its header")
    Do $$$AssertEquals(tProposal.%GetTypeOf("content") _ " " _ tProposal.%GetTypeOf("output"), "unassigned unassigned", "nor a text member, nor an output")
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.proposalId, .tFound, .tValues)
    Do $$$AssertTrue($Get(tFound), "the proposal is stored")
    Do $$$AssertEquals($Get(tValues("destructive")) _ " " _ $Get(tValues("consequence")), "1 EXPLORER.SAVE.COMPILES", "it is destructive and its consequence is the compile")
    Do $$$AssertTrue($Get(tValues("requiredPairs")) [ "%DB_USER:WRITE", "it requires WRITE on the routines database: " _ $Get(tValues("requiredPairs")))
    Do $$$AssertTrue(($Get(tValues("arguments")) [ """Compile"":true") && ($Get(tValues("arguments")) [ "Set x1 = 1") && ($Get(tValues("arguments")) [ "Set x20 = 0"), "its stored arguments hold the whole new text and compile true")
    Do $$$AssertEquals($Get(tValues("rationale")) _ "|" _ $Get(tValues("expectedImpact")) _ "|" _ $Get(tValues("reverse")), "zero one line|x20 is zero|set x20 back to 20", "and the agent's rationale, expected impact and reverse, for the card")
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#ALPHA _ ".cls"), tBefore, "nothing is saved before Confirm")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, ..#ALPHA), "and nothing is compiled")
}

/// <p>A routine's edit is saved on Confirm, compiled as a routine with no error, and marked.</p>
Method TestARoutineEditIsSavedCompiledAndMarked()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, ..#MACRO), "a probe routine is saved")
    Set tBefore = ##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#MACRO)
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#ROUTINETOOL, {"Names": (..#MACRO), "Edits": [{"Old": " Quit", "New": " Quit 1"}]}, .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError Do $$$AssertTrue(0, "the edit is minted: " _ $Extract($Get(tContent), 1, 300)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#MACRO), tBefore, "nothing is saved at the mint")
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm writes: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.state _ " " _ tResult.action _ " " _ tResult.auditMarked, "confirmed updated 1", "the proposal is confirmed, as an update, and marked")
    Do $$$AssertEquals($Piece(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#MACRO), $Char(10), 3), " Quit 1", "the routine holds the new text")
    Do $$$AssertEquals($Select($IsObject(tResult.%Get("output")): tResult.output.%GetTypeOf("errors") _ ":" _ tResult.output.errors, 1: "none"), "boolean:0", "the compile reports no error: " _ tResult.%ToJSON())
    Do $$$AssertTrue(tResult.output.lines.%ToJSON() [ "OcuProbe2021Mac", "and its console names the routine")
}

/// <p>An include file's edit is saved and compiled on Confirm.</p>
Method TestAnIncludeFileEditIsSavedAndCompiled()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, ..#INCLUDE), "a probe include file is saved")
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#ROUTINETOOL, {"Names": (..#INCLUDE), "Edits": [{"Old": "42", "New": "43"}]}, .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError Do $$$AssertTrue(0, "the edit is minted: " _ $Extract($Get(tContent), 1, 300)) Quit
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm writes: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertTrue(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#INCLUDE) [ "#define OcuProbe192Value 43", "the include file holds the new text")
    Do $$$AssertEquals($Select($IsObject(tResult.%Get("output")): tResult.output.errors, 1: "none"), 0, "and its compile reports no error: " _ tResult.%ToJSON())
}

/// <p>A routine edit that renames the routine, or drops an include file's type, would save a different
/// document than the one named, and is refused.</p>
Method TestARoutineHeaderEditIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, ..#MACRO), "a probe routine is saved")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, ..#INCLUDE), "a probe include file is saved")
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#ROUTINETOOL)
    For tCase = $ListBuild(..#MACRO, "ROUTINE OcuProbe2021Mac", "ROUTINE OcuProbe2021Other"), $ListBuild(..#INCLUDE, " [Type=INC]", "") {
        Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#ROUTINETOOL, {"Names": ($List(tCase, 1)), "Edits": [{"Old": ($List(tCase, 2)), "New": ($List(tCase, 3))}]}, .tContent, .tIsError, .tProposal)
        Do $$$AssertTrue(tIsError && (..CodeOf($Get(tContent)) = "TOOL.ARGUMENTS") && (..ProblemOf($Get(tContent)) [ "name"), $List(tCase, 1) _ ": the header edit is refused as a change of name: " _ $Extract($Get(tContent), 1, 240))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#ROUTINETOOL), tBefore, "and neither adds a proposal")
}

/// <p>A confirmed save is marked, and the turn's ledger holds its write row as <code>ok</code> and marked; the
/// proposal and its ledger rows store no compile line.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Confirm.Confirm</method> takes the write as unmarked
/// (<code>tMarked</code> 0) -- the marked legs go red.</p>
Method TestAConfirmedSaveIsMarkedLedgeredAndStoresNoCompileLine()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..EditOf("2"), .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError Do $$$AssertTrue(0, "the edit is minted: " _ $Extract($Get(tContent), 1, 300)) Quit
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm writes: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.auditMarked, 1, "the confirm reports the write marked")
    Do $$$AssertTrue(tResult.output.lines.%ToJSON() [ ("Compiling class " _ ..#ALPHA), "and the screen's answer carries the compile's lines")
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.proposalId, .tFound, .tValues)
    Set tSC = ##class(OcuPilot.Kernel.State.Ledger).GuardedIdsForWindow($Username, "", $Get(tValues("turnKey")), 100, .tIds, .tProblem)
    Set tWrites = 0
    For tI = 1:1:+$Get(tIds) {
        Kill tRow
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedRow(tIds(tI), .tRow)
        If ($Get(tRow("kind")) = "write") && ($Get(tRow("name")) = ..#CLASSTOOL) {
            Set tWrites = tWrites + 1
            Do $$$AssertEquals($Get(tRow("status")) _ " " _ $Get(tRow("auditMarked")), "ok marked", "the write's ledger row is ok and marked")
            Do $$$AssertTrue($Get(tRow("target")) [ (..#ALPHA _ ".cls"), "and names the document: " _ $Get(tRow("target")))
        }
    }
    Do $$$AssertEquals(tWrites, 1, "one write row for the save")
    Set tStored = ##class(OcuPilot.Test.ExplorerWrite).StoredText(tProposal.proposalId, .tLedgerRows)
    Do $$$AssertTrue(tLedgerRows > 0, "the turn's ledger rows are read: " _ tLedgerRows)
    Do $$$AssertTrue((tStored '[ "Compilation") && (tStored '[ "Compiling") && (tStored '[ "qualifiers"), "and the stored proposal and the ledger rows hold no compile line: " _ $Extract(tStored, 1, 300))
}

/// <p>A document another writer changed after the mint is refused 409 <code>TARGETCHANGED</code>, the kernel's
/// changed-target answer and not the port's version conflict, with nothing compiled and the other writer's text
/// left in place.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> skips the fresh
/// digest's comparison -- the port's own conflict still refuses, with another code, and this goes red.</p>
Method TestAnOutsideRewriteAfterTheMintIsRefusedAsAChangedTarget()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..EditOf("2"), .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError Do $$$AssertTrue(0, "the edit is minted: " _ $Extract($Get(tContent), 1, 300)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Rewrite", ..#PROBENAMESPACE, ..#ALPHA, "9"), "another writer changes the class")
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a changed target")
    Do $$$AssertEquals($Piece(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#ALPHA _ ".cls"), $Char(10), 6), "    Quit 9", "and the document holds the other writer's text")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, ..#ALPHA), "and nothing was compiled")
}

/// <p>Two proposals against the same document, minted at the same version: the first confirms, and the second
/// is refused 409 <code>TARGETCHANGED</code> with the first's text left in place.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> skips the fresh
/// digest's comparison -- the port's own version conflict refuses the second with another code, and this goes
/// red.</p>
Method TestASecondProposalIsRefusedOnceTheFirstIsConfirmed()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..EditOf("2"), .tContentOne, .tIsErrorOne, .tOne)
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..EditOf("3"), .tContentTwo, .tIsErrorTwo, .tTwo)
    If '$IsObject($Get(tOne)) || '$IsObject($Get(tTwo)) || tIsErrorOne || tIsErrorTwo Do $$$AssertTrue(0, "both edits are minted: " _ $Extract($Get(tContentOne), 1, 120) _ " " _ $Extract($Get(tContentTwo), 1, 120)) Quit
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tOne, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the first confirms: " _ $Get(tCode))
    Do $$$AssertEquals($Piece(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#ALPHA _ ".cls"), $Char(10), 6), "    Quit 2", "and the document holds its text")
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tTwo, .tResultTwo, .tHttpTwo, .tCodeTwo)
    Do $$$AssertEquals(tHttpTwo _ " " _ tCodeTwo, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the second is refused as a changed target")
    Do $$$AssertEquals($Piece(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#ALPHA _ ".cls"), $Char(10), 6), "    Quit 2", "and the first's text stays")
}

/// <p>A result past the port's bound is refused at the mint: 1,700,000 quotation marks escape to more
/// characters than one save takes, and 2,200,000 escape past the longest string the instance can build, which
/// counts as over too.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.ExplorerSaveMint</class> measures the unescaped text -- the
/// first leg goes red; it measures without its <code>Try</code>, so the escape's throw reaches the mint's own
/// <code>Catch</code> -- the second leg goes red (500 <code>INTERNAL</code>).</p>
Method TestAnEditPastThePortsBoundIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CLASSTOOL)
    For tCount = 1700000, 2200000 {
        Set tQuotes = $Translate($Justify("", tCount), " ", $Char(34))
        Set tEdits = []
        Do tEdits.%Push({"Old": "    Quit 1", "New": (tQuotes)})
        Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, {"Names": (..#ALPHA _ ".cls"), "Edits": (tEdits)}, .tContent, .tIsError, .tProposal)
        Do $$$AssertTrue($$$ISOK(tSC) && tIsError && (..CodeOf($Get(tContent)) = "TOOL.ARGUMENTS"), tCount _ " quotation marks: the edit is refused: " _ $Extract($Get(tContent), 1, 200))
        Do $$$AssertTrue(..ProblemOf($Get(tContent)) [ "longer than one save takes", tCount _ " quotation marks: and says why: " _ ..ProblemOf($Get(tContent)))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CLASSTOOL), tBefore, "and no proposal is added")
}

/// <p>The save's governance key decides for the agent: disabled, the dispatcher refuses the call and mints
/// nothing; and a proposal minted while it was enabled is refused 403 at Confirm once it is disabled, with the
/// document unchanged.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Kernel.Governance.Baseline</class> lists the key as write-exempt -- both
/// refusals go red.</p>
Method TestTheSaveKeyGovernsTheAgentAtTheDispatcherAndAtConfirm()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..EditOf("2"), .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError Do $$$AssertTrue(0, "the edit is minted while the key is enabled: " _ $Extract($Get(tContent), 1, 300)) Quit
    Kill tSettings
    Set tSettings(..#CLASSTOOL) = "disabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is disabled through its stored setting")
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CLASSTOOL)
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..EditOf("3"), .tRefused, .tRefusedIsError, .tNone)
    Do $$$AssertTrue(tRefusedIsError && (..CodeOf($Get(tRefused)) = ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED), "the dispatcher refuses the call: " _ $Extract($Get(tRefused), 1, 200))
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CLASSTOOL), tBefore, "and mints nothing")
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "403 " _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the earlier proposal is refused at Confirm")
    Do $$$AssertEquals($Piece(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#ALPHA _ ".cls"), $Char(10), 6), "    Quit 1", "with the document unchanged")
}

/// <p>A person's Save is not the agent's: with the save key disabled it still writes, and it saves a text the
/// agent's mint would refuse -- one holding a DEL control character -- because the agent's rules apply to the
/// agent's path only.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSave.ScreenActionDelta</method> refuses a text the
/// sanitizer would change -- the control-character leg goes red.</p>
Method TestAPersonsSaveIsUnchangedByTheAgentsKeyAndRules()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Kill tSettings
    Set tSettings(..#CLASSTOOL) = "disabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the save key is disabled")
    Set tText = ##class(OcuPilot.Test.ExplorerSaveProbe).ClassText(..#ALPHA, "5")
    Set tText = $Replace(tText, "ClassMethod Probe()", "/// del" _ $Char(127) _ "char" _ $Char(10) _ "ClassMethod Probe()")
    Set tVersion = ##class(OcuPilot.Test.ExplorerSave).Version(..#ALPHA _ ".cls")
    Do ##class(OcuPilot.Test.ExplorerSave).Save("classes", ..#ALPHA _ ".cls", tText, tVersion, "false", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "a person's Save writes: " _ ##class(OcuPilot.Test.ExplorerSave).Json($Get(tBody)))
    Set tStored = ##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Do $$$AssertTrue((tStored [ ("del" _ $Char(127) _ "char")) && (tStored [ "Quit 5"), "and the class holds the person's text, control character included")
}

/// <p>What the provider is shown of each save: the description names the read tool of its kind, the exact-match
/// rule and the DW-2228 sentence, the compile on Confirm that the tool never answers and the names it refuses,
/// and no longer says the save is never offered; the input schema has the document and the replacements
/// (one to twenty objects) and the agent's own words, requires the first two, allows nothing else and offers no
/// text, version or compile choice.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.ExplorerClassSave.DESCRIPTION</parameter> drops the
/// exact-match sentences -- the description leg goes red.</p>
Method TestTheProviderIsShownTheEditsContract()
{
    Set tRegistry = "OcuPilot.Screen.Tool.Registry"
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ProviderTools", .tProvider), "the provider tool list builds")
    For tCase = $ListBuild(..#CLASSTOOL, "explorer.class.source", "class"), $ListBuild(..#ROUTINETOOL, "explorer.routine.source", "routine") {
        Set tWire = $ClassMethod(tRegistry, "WireName", $List(tCase, 1))
        Set tDescription = ""
        Set tSchema = ""
        For tI = 1:1:+$Get(tProvider) {
            If tProvider(tI, "name") = tWire {
                Set tDescription = tProvider(tI, "description")
                Set tSchema = ##class(%DynamicAbstractObject).%FromJSON(tProvider(tI, "inputSchema"))
            }
        }
        Do $$$AssertTrue(tDescription '= "", $List(tCase, 1) _ " is in the provider list")
        For tText = $List(tCase, 2), "matched exactly, character for character", "[redacted]", "never answers", "begins with %", "OcuPilot", "%SYS", "stored in another database" {
            Do $$$AssertTrue(tDescription [ tText, $List(tCase, 1) _ "'s description holds '" _ tText _ "'")
        }
        Do $$$AssertTrue(tDescription '[ "never offered", $List(tCase, 1) _ "'s description no longer says it is never offered")
        If '$IsObject(tSchema) Continue
        Set tNames = ""
        Set tIterator = tSchema.properties.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tKey
        }
        Do $$$AssertEquals(tNames, "Names,Edits,rationale,expectedImpact,reverse", $List(tCase, 1) _ "'s schema offers the document, the replacements and the agent's own words")
        Do $$$AssertEquals(tSchema.required.%ToJSON() _ " " _ tSchema.additionalProperties, "[""Names"",""Edits""] 0", "requires the first two and allows nothing else")
        Set tEdits = tSchema.properties.Edits
        Do $$$AssertEquals(tEdits.type _ " " _ tEdits.minItems _ " " _ tEdits.maxItems _ " " _ tEdits.items.type, "array 1 20 object", "Edits is one to twenty objects")
    }
}

}

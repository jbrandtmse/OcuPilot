/// <p>Pins Story 19.2's compile and delete end to end (AD-6, AD-10, AD-22, AD-39, AD-53, AD-58): the
/// Classes and Routines lists' actions over HTTP on probe documents in <code>USER</code> -- a compile
/// with its flags and its console lines, a compile error written into the output, a delete of a set
/// read back gone, a delete one of whose documents another process holds read back present, a
/// persistent class's data kept by its delete, a missing document refused by name -- the agent's
/// compile and delete through mint and confirm, an oversized or missing set refused at the mint, the
/// delete refused by governance at the baseline and confirmed once its key is enabled, refused once its
/// document is edited after the mint, the console
/// kept off the proposal the model reads, and OcuPilot's own documents refused on both callers.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and
/// serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, and a <code>USER</code>
/// namespace. It creates and removes the probe documents <class>OcuPilot.Test.ExplorerProbe</class>
/// names and their data globals, failing if any is left, and snapshots the stored governance policy before each test and
/// puts it back after it.</p>
Class OcuPilot.Test.ExplorerWrite Extends %UnitTest.TestCase
{

/// <p>The namespace the probe documents are created in.</p>
Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerProbe";

Parameter COMPILETOOL = "OcuPilot.Screen.Tool.ExplorerClassCompile";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.ExplorerClassDelete";

/// <p>The classes list's delete key, which the baseline disables.</p>
Parameter DELETEKEY = "explorer.classes.delete";

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

/// <p>One screen action on <var>pList</var> (<code>classes</code> or <code>routines</code>) in
/// <var>pNamespace</var>: <var>pAction</var> on <var>pId</var>, with the three compile values where
/// <var>pFlags</var> spells them as three digits; the HTTP status and the parsed envelope.</p>
ClassMethod Act(pList As %String, pNamespace As %String, pAction As %String, pId As %String, pFlags As %String, Output pStatus As %Integer, Output pBody)
{
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    If pFlags '= "" {
        Set tValues = {}
        Do tValues.%Set("KeepSource", $Select($Extract(pFlags, 1): "true", 1: "false"), "string")
        Do tValues.%Set("CompileDependents", $Select($Extract(pFlags, 2): "true", 1: "false"), "string")
        Do tValues.%Set("SkipUpToDate", $Select($Extract(pFlags, 3): "true", 1: "false"), "string")
        Do tRequest.%Set("values", tValues)
    }
    Do ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/explorer." _ pList _ "/action?ns=" _ pNamespace, .pStatus, .pBody, tRequest.%ToJSON())
}

/// <p>The agent's call of <var>pTool</var> for <var>pNames</var> with <var>pArgs</var>, scoped to
/// <var>pNamespace</var>, inside a completed turn seeded for the running account: the tool's
/// <code>View</code>, the one method the model reaches, whose answer <var>pProposal</var> is the
/// tool result the model reads.</p>
Method MintFor(pTool As %String, pNamespace As %String, pNames As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault) As %Status
{
    Set pProposal = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Do pArgs.%Set("Names", pNames, "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
    Set tSC = $ClassMethod(pTool, "View", "", pArgs, 0, .pProposal, .pHttp, .pFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit tSC
}

/// <p>Confirm <var>pProposal</var> in process as the running account, scoped to
/// <var>pNamespace</var>.</p>
ClassMethod ConfirmIn(pNamespace As %String, pProposal As %DynamicObject, Output pResult, Output pHttp As %Integer, Output pCode As %String) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Quit ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(pProposal)): pProposal.%Get("proposalId"), 1: ""), "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p><var>pBody</var> as text.</p>
ClassMethod Json(pBody) As %String
{
    If $IsObject($Get(pBody)) Quit pBody.%ToJSON()
    Quit $Get(pBody)
}

/// <p>AC1: the screen's compile of one document sends <code>c</code> plus exactly the chosen flags,
/// which the compiler's own console line names, compiles it, and answers the console lines as
/// <code>output</code> beside the triple and a read-back that sent nothing.</p>
/// <p>Mutation (Rule 19): drop <code>k</code> from <method>OcuPilot.Port.AtelierPort.CompileFlags</method>
/// -- the qualifiers leg goes red.</p>
Method TestTheScreenCompilesADocumentWithItsFlags()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, "OcuProbe192.Alpha"), "a probe class is saved")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, "OcuProbe192.Alpha"), "uncompiled")
    Do ..Act("classes", ..#PROBENAMESPACE, "compile", "OcuProbe192.Alpha.cls", "101", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the compile answers 200: " _ ..Json(tBody))
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.action _ " " _ tBody.target.%ToJSON() _ " " _ tBody.readBack.verdict, "updated {""type"":""class"",""scope"":""USER"",""id"":""OcuProbe192.Alpha.cls""} nothingSent", "the triple, the verb and a read-back that sent nothing")
    Set tLines = $Select($IsObject(tBody.%Get("output")): tBody.output.lines.%ToJSON(), 1: "")
    Do $$$AssertTrue(tLines [ "qualifiers 'cuk'", "the compiler was handed c plus exactly the chosen flags: " _ tLines)
    Do $$$AssertTrue(tLines [ "OcuProbe192.Alpha", "and its console lines name the class")
    Do $$$AssertEquals(tBody.output.errors, 0, "with no error")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, "OcuProbe192.Alpha"), "the class is compiled")
    For tCase = $ListBuild("001", "cu"), $ListBuild("100", "ck") {
        Do ..Act("classes", ..#PROBENAMESPACE, "compile", "OcuProbe192.Alpha.cls", $List(tCase, 1), .tStatus, .tBody)
        Do $$$AssertTrue((tStatus = 200) && (..Json(tBody) [ ("qualifiers '" _ $List(tCase, 2) _ "'")), $List(tCase, 1) _ ": KeepSource and SkipUpToDate reach the compiler apart, as " _ $List(tCase, 2) _ ": " _ ..Json(tBody))
    }
    Do ..Act("routines", ..#PROBENAMESPACE, "compile", "OcuProbe192Mac.mac", "000", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code, 1: ""), "404 EXPLORER.DOCUMENT.ABSENT", "a routine the namespace does not hold is refused by name")
    Do $$$AssertEquals($Select($IsObject(tBody) && $IsObject(tBody.%Get("detail")): tBody.detail.documents.%ToJSON(), 1: ""), "[""OcuProbe192Mac.mac""]", "naming it")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe192Mac.mac"), "a probe routine is saved")
    Do ..Act("routines", ..#PROBENAMESPACE, "compile", "OcuProbe192Mac.mac", "000", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "and once saved it compiles: " _ ..Json(tBody))
    Do $$$AssertTrue(..Json(tBody) [ "qualifiers 'c'", "with c alone")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe192Inc.inc"), "a probe include file is saved")
    Do ..Act("routines", ..#PROBENAMESPACE, "compile", "OcuProbe192Inc.inc", "101", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody) && $IsObject(tBody.%Get("output")): tBody.output.errors, 1: ""), "200 0", "and an include file's compile answers with no error: " _ ..Json(tBody))
}

/// <p>A compile error answers 200 with <code>errors</code> true and the compiler's lines, its error
/// among them, in the output, and is not a fault.</p>
Method TestACompileErrorIsWrittenIntoTheOutput()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, "OcuProbe192.Broken", 1), "a probe class that does not compile is saved")
    Do ..Act("classes", ..#PROBENAMESPACE, "compile", "OcuProbe192.Broken.cls", "101", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the compile answers 200: " _ ..Json(tBody))
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("output")) Quit
    Do $$$AssertEquals(tBody.output.errors, 1, "errors is true")
    Set tLines = tBody.output.lines.%ToJSON()
    Do $$$AssertTrue((tLines [ "ERROR #5373") && (tLines [ "OcuProbe192.Broken") && (tLines [ "Detected 1 errors"), "the error and the compiler's every other line are in the output: " _ tLines)
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, "OcuProbe192.Broken"), "and the class is not compiled")
}

/// <p>AC2: the screen's delete of a set removes every document, reads back not found and answers each
/// document deleted; a set one of whose documents another process holds answers that one refused in
/// the port's own words and reads back present.</p>
/// <p>Mutation (Rule 19): answer 1 from <method>OcuPilot.Screen.Tool.ExplorerDelete.ReadBackGone</method>
/// -- the survivor leg goes red.</p>
Method TestTheScreenDeletesASetAndReadsItBack()
{
    For tName = "OcuProbe192.Alpha", "OcuProbe192.Beta" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, tName), tName _ " is saved")
    }
    Do ..Act("classes", ..#PROBENAMESPACE, "delete", "OcuProbe192.Beta.cls,OcuProbe192.Alpha.cls", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the delete answers 200: " _ ..Json(tBody))
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.action _ " " _ tBody.target.id _ " " _ tBody.readBack.verdict, "deleted OcuProbe192.Alpha.cls,OcuProbe192.Beta.cls notFound", "the canonical set, deleted and read back not found")
    Do $$$AssertEquals(tBody.output.%ToJSON(), "{""documents"":[{""name"":""OcuProbe192.Alpha.cls"",""deleted"":true,""reason"":""""},{""name"":""OcuProbe192.Beta.cls"",""deleted"":true,""reason"":""""}]}", "each document's own result")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe192.Alpha.cls") && '$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe192.Beta.cls"), "both are gone")

    For tName = "OcuProbe192.Alpha", "OcuProbe192.Beta" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, tName), tName _ " is saved again")
    }
    Do ..HoldDocument("OcuProbe192.Beta.cls", 1)
    Do ..Act("classes", ..#PROBENAMESPACE, "delete", "OcuProbe192.Alpha.cls,OcuProbe192.Beta.cls", "", .tStatus, .tBody)
    Do ..HoldDocument("OcuProbe192.Beta.cls", 0)
    Do $$$AssertEquals(tStatus, 200, "a held document is not a fault: " _ ..Json(tBody))
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.output.documents.%Get(1).%ToJSON(), {"name": "OcuProbe192.Beta.cls", "deleted": false, "reason": (##class(OcuPilot.Api.AtelierError).#DELETELOCKED)}.%ToJSON(), "the held one is refused in the port's own words")
    Do $$$AssertEquals(tBody.readBack.verdict, "present", "and the set reads back present while it survives")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe192.Beta.cls"), "it is still held")

    For tName = "OcuProbe192Mac.mac", "OcuProbe192Inc.inc" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, tName), tName _ " is saved")
    }
    Do ..Act("routines", ..#PROBENAMESPACE, "delete", "OcuProbe192Mac.mac,OcuProbe192Inc.inc", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody) && $IsObject(tBody.%Get("readBack")): tBody.target.id _ " " _ tBody.readBack.verdict, 1: ""), "200 OcuProbe192Inc.inc,OcuProbe192Mac.mac notFound", "the Routines list's delete of a set reads back not found: " _ ..Json(tBody))
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe192Mac.mac") && '$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe192Inc.inc"), "and both routines are gone")
}

/// <p>The screen's delete of a persistent class removes its source and compiled code and keeps its
/// stored data, as the classic page does.</p>
Method TestADeleteKeepsAPersistentClassesData()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakePersistentRow", ..#PROBENAMESPACE, "OcuProbe192.Kept", .tGlobal), "a persistent probe class is compiled with one row stored")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "HasData", ..#PROBENAMESPACE, $Get(tGlobal)), "its row is stored in " _ $Get(tGlobal))
    Do ..Act("classes", ..#PROBENAMESPACE, "delete", "OcuProbe192.Kept.cls", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody) && $IsObject(tBody.%Get("readBack")): tBody.readBack.verdict, 1: ""), "200 notFound", "the delete answers 200 and reads back not found: " _ ..Json(tBody))
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe192.Kept.cls") && '$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, "OcuProbe192.Kept"), "its source and compiled code are gone")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "HasData", ..#PROBENAMESPACE, $Get(tGlobal)), "and its stored row is kept")
}

/// <p>Take or release the editing lock on <var>pDocument</var> in the probe namespace, as an editor
/// holding it does.</p>
ClassMethod HoldDocument(pDocument As %String, pHold As %Boolean)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#PROBENAMESPACE
        Do ##class(%RoutineMgr).LockItem(pDocument, pHold, 0)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>AC3: the agent's compile mints a proposal whose card names the documents and the three flags
/// and carries no console line; confirming compiles both in one call and answers the console as the
/// confirm's <code>output</code>.</p>
/// <p>Mutation (Rule 19): put the written output on the mint's answer -- the turn leg goes red.</p>
Method TestTheAgentCompilesThroughConfirm()
{
    For tName = "OcuProbe192.Alpha", "OcuProbe192.Beta" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, tName), tName _ " is saved")
    }
    Set tArgs = {"KeepSource": true, "CompileDependents": false, "SkipUpToDate": true}
    Set tSC = ..MintFor(..#COMPILETOOL, ..#PROBENAMESPACE, "OcuProbe192.Beta.cls,OcuProbe192.Alpha.cls", tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the compile is minted: " _ ..Json($Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tCard = tProposal.changed.%ToJSON()
    Do $$$AssertEquals(tProposal.target.id, "OcuProbe192.Alpha.cls,OcuProbe192.Beta.cls", "the target is the canonical set")
    Do $$$AssertTrue((tCard [ "OcuProbe192.Alpha.cls, OcuProbe192.Beta.cls") && (tCard [ """KeepSource""") && (tCard [ """CompileDependents""") && (tCard [ """SkipUpToDate"""), "the card names the documents and the flags: " _ tCard)
    Do $$$AssertTrue((tProposal.%ToJSON() '[ "Compilation") && (tProposal.%ToJSON() '[ "Compiling") && (tProposal.%GetTypeOf("output") = "unassigned"), "and the answer the model reads holds no console line")
    Set tSC = ..ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm writes: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.state _ " " _ tResult.action _ " " _ tResult.readBack.verdict, "confirmed updated nothingSent", "the proposal is confirmed")
    Set tLines = $Select($IsObject(tResult.%Get("output")): tResult.output.lines.%ToJSON(), 1: "")
    Do $$$AssertTrue((tLines [ "qualifiers 'cuk'") && (tLines [ "OcuProbe192.Alpha") && (tLines [ "OcuProbe192.Beta"), "and the confirm answers the console of one compile of both: " _ tLines)
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, "OcuProbe192.Alpha") && $ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, "OcuProbe192.Beta"), "both are compiled")
    Set tStored = ..StoredText(tProposal.proposalId, .tLedgerRows)
    Do $$$AssertTrue(tLedgerRows > 0, "the turn's ledger rows are read: " _ tLedgerRows)
    Do $$$AssertTrue((tStored [ "OcuProbe192.Alpha.cls") && (tStored '[ "Compilation") && (tStored '[ "Compiling"), "and the stored proposal and its turn's ledger rows hold no console line: " _ $Extract(tStored, 1, 400))
}

/// <p>Everything OcuPilot stored for proposal <var>pProposalId</var> -- its row and its turn's ledger
/// rows -- as one text. <var>pLedgerRows</var> is how many ledger rows were read, 0 when the read
/// failed.</p>
ClassMethod StoredText(pProposalId As %String, Output pLedgerRows As %Integer) As %String
{
    Set pLedgerRows = 0
    Set tText = ""
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposalId, .tFound, .tValues)
    Set tKey = ""
    For {
        Set tKey = $Order(tValues(tKey), 1, tValue)
        If tKey = "" Quit
        Set tText = tText _ " " _ tValue
    }
    Set tSC = ##class(OcuPilot.Kernel.State.Ledger).GuardedIdsForWindow($Username, "", $Get(tValues("turnKey")), 100, .tIds, .tProblem)
    If $$$ISERR(tSC) Quit tText
    Set pLedgerRows = +$Get(tIds)
    For tI = 1:1:pLedgerRows {
        Kill tRow
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedRow(tIds(tI), .tRow)
        Set tKey = ""
        For {
            Set tKey = $Order(tRow(tKey), 1, tValue)
            If tKey = "" Quit
            Set tText = tText _ " " _ tValue
        }
    }
    Quit tText
}

/// <p>AC2: at the baseline the agent's delete is refused by governance at the dispatch gate and at the
/// confirm, with nothing deleted; once its key is enabled through its stored setting, the confirmed
/// delete removes the set and reads back not found.</p>
Method TestTheAgentsDeleteIsGovernedAndThenConfirmed()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, "OcuProbe192.Alpha"), "a probe class is saved")
    Kill tDecision
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide(..#DELETEKEY, ##class(OcuPilot.Kernel.Governance.Policy).#WRITEKIND, $Username, {"Names": "OcuProbe192.Alpha.cls"}, .tDecision), "the gate decides")
    Do $$$AssertEquals(+$Get(tDecision("allowed")), 0, "the baseline disables the agent's delete")
    Set tSC = ..MintFor(..#DELETETOOL, ..#PROBENAMESPACE, "OcuProbe192.Alpha.cls", {}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a proposal is minted")
    Set tSC = ..ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertEquals(tConfirmHttp _ " " _ $Get(tCode), "403 " _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "and its confirm is refused by governance")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe192.Alpha.cls"), "with nothing deleted")

    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is enabled through its stored setting")
    Set tSC = ..MintFor(..#DELETETOOL, ..#PROBENAMESPACE, "OcuProbe192.Alpha.cls", {}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is minted")
    Set tSC = ..ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.action _ " " _ tResult.readBack.verdict _ " " _ tResult.output.documents.%Get(0).deleted, "deleted notFound 1", "the document is deleted and reads back not found")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe192.Alpha.cls"), "it is gone")
}

/// <p>AC2 (AD-6): a document edited after the agent's delete was minted refuses the confirm 409 as a
/// changed target and is not deleted, because the delete's fingerprint covers each document's modified
/// time.</p>
/// <p>Mutation (Rule 19): drop <code>Modified</code> from
/// <parameter>OcuPilot.Screen.Tool.ExplorerDelete.FINGERPRINTSUBJECT</parameter> -- the confirm deletes the
/// edited class and this goes red.</p>
Method TestAnEditAfterTheMintRefusesTheDelete()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, "OcuProbe192.Alpha"), "a probe class is saved")
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the delete key is enabled through its stored setting")
    Set tSC = ..MintFor(..#DELETETOOL, ..#PROBENAMESPACE, "OcuProbe192.Alpha.cls", {}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is minted: " _ ..Json($Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    ; Apart by more than a second, so the edit's modified time differs from the mint's whatever the
    ; timestamp's precision.
    Hang 1.1
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, "OcuProbe192.Alpha", 1), "the class is edited after the mint")
    Set tSC = ..ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertEquals(tConfirmHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a changed target")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe192.Alpha.cls"), "and the edited class is not deleted")
}

/// <p>AC7: OcuPilot's own documents are refused <code>PROHIBITED.OCUPILOTCODE</code> on both callers,
/// in any namespace and whatever the case of the name -- the screen's compile of a probe class whose
/// name begins with <code>OcuPilot</code>, the screen's delete of a set holding it, a class and a
/// routine so named in the install namespace, and the agent's confirmed compile -- with the published
/// sentence, and the probe is neither compiled nor deleted.</p>
/// <p>Mutation (Rule 19): drop the code arm from <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method>
/// -- every leg goes red.</p>
Method TestOcuPilotsOwnCodeIsRefusedOnBothCallers()
{
    Set tOwnName = $Parameter(..#PROBE, "OWNPACKAGE") _ ".Own"
    Set tOwn = tOwnName _ ".cls"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, tOwnName), "a probe class whose name begins with OcuPilot is saved, uncompiled")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, "OcuProbe192.Alpha"), "and a probe class beside it")
    Do ..Act("classes", ..#PROBENAMESPACE, "compile", tOwn, "101", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code _ " " _ tBody.reason, 1: ""), "403 PROHIBITED.OCUPILOTCODE " _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODEREASON, "the screen's compile of one is refused with the published sentence")
    Do ..Act("classes", ..#PROBENAMESPACE, "delete", "OcuProbe192.Alpha.cls," _ tOwn, "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code, 1: ""), "403 PROHIBITED.OCUPILOTCODE", "the screen's delete of a set holding one among others is refused")
    For tCase = $ListBuild("classes", "ocupilot.probe192.cls"), $ListBuild("routines", "OCUPILOTPROBE192.mac") {
        Do ..Act($List(tCase, 1), $Namespace, "delete", $List(tCase, 2), "", .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code, 1: ""), "403 PROHIBITED.OCUPILOTCODE", "the screen's delete of '" _ $List(tCase, 2) _ "' in the install namespace is refused")
    }

    Set tSC = ..MintFor(..#COMPILETOOL, ..#PROBENAMESPACE, tOwn, {"KeepSource": true, "CompileDependents": false, "SkipUpToDate": true}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's compile of one is minted")
    Set tSC = ..ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertEquals(tConfirmHttp _ " " _ $Get(tCode), "403 PROHIBITED.OCUPILOTCODE", "and refused at the confirm")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, tOwn) && '$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, tOwnName), "the probe is neither deleted nor compiled")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe192.Alpha.cls"), "and the set's other class is not deleted")
}

/// <p>The two delete keys ship disabled and the two compile keys enabled (AD-22).</p>
Method TestTheBaselineShipsTheDeletesDisabled()
{
    For tCase = $ListBuild("explorer.classes.compile", 1), $ListBuild("explorer.routines.compile", 1), $ListBuild("explorer.classes.delete", 0), $ListBuild("explorer.routines.delete", 0) {
        Do ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 1), .tListed)
        Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve($List(tCase, 1), "write", .tEnabled, .tSource)
        Do $$$AssertEquals(tListed _ " " _ ''$Get(tEnabled), "1 " _ $List(tCase, 2), $List(tCase, 1) _ ": listed and decided " _ $List(tCase, 2))
    }
}

/// <p>The agent's mint refuses a set of more than one hundred documents 400 <code>TOOL.ARGUMENTS</code>,
/// and the screen's action refuses it 400 too; and the mint refuses a set naming a document the
/// namespace does not hold 404 <code>EXPLORER.DOCUMENT.ABSENT</code> naming it, with no proposal
/// minted.</p>
/// <p>Mutation (Rule 19): skip the absent check in <method>OcuPilot.Screen.Tool.ExplorerMint.Mint</method>
/// -- the absent leg goes red.</p>
Method TestTheMintRefusesAnOversizedOrMissingSet()
{
    Set tMany = ""
    For tI = 1:1:101 Set tMany = tMany _ $Select(tI = 1: "", 1: ",") _ "OcuProbe192.N" _ tI _ ".cls"
    Set tSC = ..MintFor(..#COMPILETOOL, ..#PROBENAMESPACE, tMany, {"KeepSource": true, "CompileDependents": false, "SkipUpToDate": true}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 TOOL.ARGUMENTS", "a set of 101 documents is refused at the mint")
    Do $$$AssertTrue('$IsObject($Get(tProposal)), "and nothing is minted")
    Do ..Act("classes", ..#PROBENAMESPACE, "delete", tMany, "", .tStatus, .tBody)
    Do $$$AssertTrue((tStatus = 400) && $IsObject(tBody) && $ListFind($ListBuild("TOOL.ARGUMENTS", "PORT.VALIDATION"), tBody.code), "the screen's delete of 101 documents is refused 400: " _ ..Json(tBody))
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, "OcuProbe192.Alpha"), "a probe class is saved")
    Set tSC = ..MintFor(..#DELETETOOL, ..#PROBENAMESPACE, "OcuProbe192.Alpha.cls,OcuProbe192.Missing.cls", {}, .tProposal, .tHttp, .tFault)
    Set tDocuments = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("documents").%ToJSON(), 1: "")
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: "") _ " " _ tDocuments, "404 EXPLORER.DOCUMENT.ABSENT [""OcuProbe192.Missing.cls""]", "a set naming a missing document is refused at the mint, naming it")
    Do $$$AssertTrue('$IsObject($Get(tProposal)), "and nothing is minted")
}

}

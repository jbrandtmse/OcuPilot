/// <p>Pins Story 19.13's export and import end to end (AD-6, AD-10, AD-21, AD-22, AD-39, AD-53): the
/// Classes and Routines lists' actions over HTTP on probe documents in <code>USER</code> -- an export
/// to a server file, deleted and imported back with each document's source as it was, and the same
/// through this browser and a local file -- the agent's export and import through mint and confirm,
/// with the import's key enabled through its stored setting, the cards naming documents, file and
/// consequence and the tool results, stored rows and ledger free of the output, OcuPilot's own code
/// refused on both callers while its export is allowed, an unreadable file leaving no stub, and a file
/// changed after the mint refused.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and
/// serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, a <code>USER</code> namespace and
/// the manager directory as an allowed root. It creates and removes the documents and files
/// <class>OcuPilot.Test.ExplorerTransferProbe</class> names, and snapshots the stored governance policy
/// before each test and puts it back after it.</p>
Class OcuPilot.Test.ExplorerTransfer Extends %UnitTest.TestCase
{

Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerTransferProbe";

Parameter EXPORTTOOL = "OcuPilot.Screen.Tool.ExplorerClassExport";

Parameter IMPORTTOOL = "OcuPilot.Screen.Tool.ExplorerClassImport";

/// <p>The classes list's import key, which the baseline disables.</p>
Parameter IMPORTKEY = "explorer.classes.import";

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
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "RemoveDirectory")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "MakeDirectory")
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "every probe document is removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveDirectory"), "and the probe directory")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>One screen action on <var>pList</var> in the probe namespace: <var>pAction</var> on
/// <var>pId</var> with <var>pValues</var>, or none; the HTTP status and the parsed envelope.</p>
ClassMethod Act(pList As %String, pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pStatus As %Integer, Output pBody)
{
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    If $IsObject(pValues) Do tRequest.%Set("values", pValues)
    Do ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/explorer." _ pList _ "/action?ns=" _ ..#PROBENAMESPACE, .pStatus, .pBody, tRequest.%ToJSON())
}

/// <p>The agent's call of <var>pTool</var> with <var>pArgs</var> in the probe namespace, inside a
/// completed turn seeded for the running account: the tool's <code>View</code>, whose answer
/// <var>pProposal</var> is the tool result the model reads.</p>
Method MintFor(pTool As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault) As %Status
{
    Set pProposal = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(..#PROBENAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
    Set tSC = $ClassMethod(pTool, "View", "", pArgs, 0, .pProposal, .pHttp, .pFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit tSC
}

/// <p>The agent's call of tool <var>pToolName</var> with <var>pInput</var> in the probe namespace, sent
/// as one <code>tool_use</code> block through the agent's dispatcher inside a completed turn seeded for
/// the running account, as the turn's loop sends it: <var>pContent</var> is the tool result the model
/// reads, <var>pIsError</var> whether it is an error, and <var>pProposal</var> that result parsed.</p>
Method DispatchFor(pToolName As %String, pInput As %DynamicObject, Output pContent As %String, Output pIsError As %Boolean, Output pProposal) As %Status
{
    Set pContent = ""
    Set pIsError = 1
    Set pProposal = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(..#PROBENAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Set tUse = {"type": "tool_use", "id": "toolu_transfer"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pToolName), "string")
    Do tUse.%Set("input", pInput)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurn, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    If $$$ISERR(tSC) Quit tSC
    Set pContent = tResults.%Get(0).%Get("content")
    Set pIsError = tResults.%Get(0).%Get("is_error")
    Try {
        Set pProposal = ##class(%DynamicObject).%FromJSON(pContent)
    } Catch {
        Set pProposal = ""
    }
    Quit $$$OK
}

/// <p>Confirm <var>pProposal</var> in process as the running account, in the probe namespace.</p>
ClassMethod ConfirmIn(pProposal As %DynamicObject, Output pResult, Output pHttp As %Integer, Output pCode As %String) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#PROBENAMESPACE)
    Quit ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(pProposal)): pProposal.%Get("proposalId"), 1: ""), "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p><var>pBody</var> as text.</p>
ClassMethod Json(pBody) As %String
{
    If $IsObject($Get(pBody)) Quit pBody.%ToJSON()
    Quit $Get(pBody)
}

/// <p>The file values naming probe file <var>pName</var>.</p>
ClassMethod FileValues(pName As %String) As %DynamicObject
{
    Quit {"root": ($ClassMethod(..#PROBE, "Root")), "path": ($ClassMethod(..#PROBE, "RelativeName", pName))}
}

/// <p>AC1: two classes and a routine exported to a server file over the screen's actions, deleted,
/// and imported back from that file, each read back through <code>GET doc</code> exactly as it was;
/// the export and the import answer their output beside a read-back that sent nothing.</p>
/// <p>Mutation (Rule 19): drop the last exported line in
/// <method>OcuPilot.Port.AtelierPort.ExportSet</method> before it is written -- the import is refused
/// unreadable and this goes red.</p>
Method TestTheServerRoundTripRestoresEachDocument()
{
    Set tProbe = ..#PROBE
    For tName = "OcuProbe1913.Alpha", "OcuProbe1913.Beta" {
        Do $$$AssertStatusOK($ClassMethod(tProbe, "MakeClass", ..#PROBENAMESPACE, tName), tName _ " is saved")
    }
    Do $$$AssertStatusOK($ClassMethod(tProbe, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe1913Mac.mac"), "a routine is saved")
    Set tDocuments = $ListBuild("OcuProbe1913.Alpha.cls", "OcuProbe1913.Beta.cls", "OcuProbe1913Mac.mac")
    For tI = 1:1:3 Set tBefore(tI) = $ClassMethod(tProbe, "Source", ..#PROBENAMESPACE, $List(tDocuments, tI))
    Do $$$AssertTrue((tBefore(1) [ "Class OcuProbe1913.Alpha") && (tBefore(3) '= ""), "their sources read")
    Do ..Act("classes", "export", "OcuProbe1913.Beta.cls,OcuProbe1913.Alpha.cls", ..FileValues("classes.xml"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody) && $IsObject(tBody.%Get("readBack")): tBody.action _ " " _ tBody.readBack.verdict _ " " _ tBody.output.%ToJSON(), 1: ""), "200 updated nothingSent " _ ..FileValues("classes.xml").%ToJSON(), "the classes are exported to the server file: " _ ..Json(tBody))
    Do ..Act("routines", "export", "OcuProbe1913Mac.mac", ..FileValues("routines.xml"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "and the routine: " _ ..Json(tBody))
    Do ..Act("classes", "delete", "OcuProbe1913.Alpha.cls,OcuProbe1913.Beta.cls", "", .tStatus, .tBody)
    Do ..Act("routines", "delete", "OcuProbe1913Mac.mac", "", .tStatus, .tBody)
    For tI = 1:1:3 Do $$$AssertTrue('$ClassMethod(tProbe, "Exists", ..#PROBENAMESPACE, $List(tDocuments, tI)), $List(tDocuments, tI) _ " is deleted")
    For tCase = $ListBuild("classes", "classes.xml"), $ListBuild("routines", "routines.xml") {
        Set tValues = ..FileValues($List(tCase, 2))
        Do tValues.%Set("Compile", "true", "string")
        Do ..Act($List(tCase, 1), "import", "import", tValues, .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody) && $IsObject(tBody.%Get("output")): tBody.action _ " " _ tBody.readBack.verdict _ " " _ tBody.output.errors, 1: ""), "200 created nothingSent 0", $List(tCase, 2) _ " is imported: " _ ..Json(tBody))
    }
    For tI = 1:1:3 Do $$$AssertEquals($ClassMethod(tProbe, "Source", ..#PROBENAMESPACE, $List(tDocuments, tI)), tBefore(tI), $List(tDocuments, tI) _ " reads back as it was")
    Do $$$AssertTrue($ClassMethod(tProbe, "Compiled", ..#PROBENAMESPACE, "OcuProbe1913.Alpha"), "and the import compiled it")
}

/// <p>AC1: two classes exported to this browser, deleted, and imported back as a local file whose
/// text is the answered lines joined by line feeds, each read back exactly as it was; the export to
/// this browser writes no file.</p>
/// <p>Mutation (Rule 19): drop <code>content</code> in
/// <method>OcuPilot.Screen.Tool.ExplorerImport.ScreenActionDelta</method> -- this goes red.</p>
Method TestTheBrowserRoundTripRestoresEachDocument()
{
    Set tProbe = ..#PROBE
    For tName = "OcuProbe1913.Alpha", "OcuProbe1913.Beta" {
        Do $$$AssertStatusOK($ClassMethod(tProbe, "MakeClass", ..#PROBENAMESPACE, tName), tName _ " is saved")
        Set tBefore(tName) = $ClassMethod(tProbe, "Source", ..#PROBENAMESPACE, tName _ ".cls")
    }
    Do ..Act("classes", "export-browser", "OcuProbe1913.Alpha.cls,OcuProbe1913.Beta.cls", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the export to this browser answers: " _ $Extract(..Json(tBody), 1, 300))
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("output")) Quit
    Set tText = ""
    Set tIterator = tBody.output.lines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tText = tText _ $Select(tIndex = 0: "", 1: $Char(10)) _ tLine
    }
    Do $$$AssertTrue((tText [ "<Export") && (tBody.output.%GetTypeOf("root") = "unassigned"), "its output is the XML lines")
    Do ..Act("classes", "delete", "OcuProbe1913.Alpha.cls,OcuProbe1913.Beta.cls", "", .tStatus, .tBody)
    Do $$$AssertTrue('$ClassMethod(tProbe, "Exists", ..#PROBENAMESPACE, "OcuProbe1913.Alpha.cls"), "the classes are deleted")
    Do ..Act("classes", "import-local", "import", {"fileName": "USER-export.xml", "content": (tText), "Compile": "false"}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody) && $IsObject(tBody.%Get("output")): tBody.output.imported.%ToJSON(), 1: ""), "200 [""OcuProbe1913.Alpha.cls"",""OcuProbe1913.Beta.cls""]", "the local file imports both: " _ ..Json(tBody))
    For tName = "OcuProbe1913.Alpha", "OcuProbe1913.Beta" {
        Do $$$AssertEquals($ClassMethod(tProbe, "Source", ..#PROBENAMESPACE, tName _ ".cls"), tBefore(tName), tName _ " reads back as it was")
    }
    Do $$$AssertTrue('$ClassMethod(tProbe, "Compiled", ..#PROBENAMESPACE, "OcuProbe1913.Alpha"), "and is not compiled when Compile is off")
}

/// <p>AC3: the agent's export call, sent through the dispatcher, mints a card naming the documents and
/// the file with the replacement consequence, and its confirm writes the file; at the baseline the
/// dispatcher refuses the import call, and an import minted there is refused at its confirm by
/// governance; with the import key enabled through its stored setting, the agent's import call of
/// that file mints a card naming the file, the reviewed documents and the compile choice, and its
/// confirm loads them. Neither tool result the model reads, nor the stored proposals and their turns'
/// ledger rows, holds an XML or console line.</p>
/// <p>Mutation (Rule 19): put the written output on the mint's answer -- this goes red; drop
/// <code>Compile</code> from <method>OcuPilot.Screen.Tool.ExplorerImport.InputSchema</method> -- the
/// dispatcher refuses the import call and this goes red.</p>
Method TestTheAgentExportsAndImportsThroughConfirm()
{
    Set tProbe = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tProbe, "MakeClass", ..#PROBENAMESPACE, "OcuProbe1913.Alpha"), "a probe class is saved")
    Set tBefore = $ClassMethod(tProbe, "Source", ..#PROBENAMESPACE, "OcuProbe1913.Alpha.cls")
    Set tArgs = ..FileValues("agent.xml")
    Do tArgs.%Set("Names", "OcuProbe1913.Alpha.cls", "string")
    Set tSC = ..DispatchFor("explorer.classes.export", tArgs, .tExportResult, .tIsError, .tExport)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tExport)), "the agent's export call is minted through the dispatcher: " _ $Extract(tExportResult, 1, 300))
    If '$IsObject($Get(tExport)) Quit
    Set tCard = tExport.changed.%ToJSON()
    Do $$$AssertTrue((tCard [ """root""") && (tCard [ "OcuProbe1913/agent.xml") && (tCard [ "OcuProbe1913.Alpha.cls"), "its card names the documents and the file: " _ tCard)
    Do $$$AssertEquals(..Stored(tExport.proposalId, "consequence"), "EXPLORER.EXPORT.REPLACES", "with the replacement consequence")
    Set tSC = ..ConfirmIn(tExport, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the export is confirmed: " _ $Get(tCode))
    Do $$$AssertTrue($IsObject($Get(tResult)) && $ClassMethod(tProbe, "FileExists", "agent.xml") && ($ClassMethod(tProbe, "ReadFile", "agent.xml") [ "<Class name=""OcuProbe1913.Alpha"">"), "and writes the file")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Remove", ..#PROBENAMESPACE), "the class is removed")

    Set tImportArgs = {"Id": "import", "Compile": true}
    Do tImportArgs.%Set("root", tArgs.root, "string")
    Do tImportArgs.%Set("path", tArgs.path, "string")
    Set tSC = ..DispatchFor("explorer.classes.import", tImportArgs, .tRefused, .tIsError, .tAnswer)
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError && $IsObject($Get(tAnswer)) && (tAnswer.%Get("code") = ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED), "at the baseline the dispatcher refuses the agent's import call: " _ tRefused)
    Set tSC = ..MintFor(..#IMPORTTOOL, tImportArgs, .tImport, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "an import minted at the baseline")
    Set tSC = ..ConfirmIn(tImport, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertEquals(tConfirmHttp _ " " _ $Get(tCode), "403 " _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "has its confirm refused by governance")
    Kill tSettings
    Set tSettings(..#IMPORTKEY) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the import key is enabled through its stored setting")
    Set tSC = ..DispatchFor("explorer.classes.import", tImportArgs, .tImportResult, .tIsError, .tImport)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tImport)), "the agent's import call is minted through the dispatcher: " _ $Extract(tImportResult, 1, 300))
    If '$IsObject($Get(tImport)) Quit
    Set tCard = tImport.changed.%ToJSON()
    Do $$$AssertTrue((tCard [ """root""") && (tCard [ """path""") && (tCard [ """documents""") && (tCard [ "OcuProbe1913.Alpha.cls new") && (tCard [ """Compile"""), "its card names the file, the reviewed documents and the compile choice: " _ tCard)
    Do $$$AssertEquals(tImport.target.id _ " " _ ..Stored(tImport.proposalId, "consequence"), "import EXPLORER.IMPORT.REPLACES", "its target is import, with the replacement consequence")
    Set tSC = ..ConfirmIn(tImport, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the import is confirmed: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.state _ " " _ tResult.action _ " " _ $Select($IsObject(tResult.%Get("output")): tResult.output.imported.%ToJSON(), 1: ""), "confirmed created [""OcuProbe1913.Alpha.cls""]", "and loads the reviewed document")
    Do $$$AssertEquals($ClassMethod(tProbe, "Source", ..#PROBENAMESPACE, "OcuProbe1913.Alpha.cls"), tBefore, "as it was")
    For tModel = tExportResult, tImportResult {
        Do $$$AssertTrue((tModel [ "proposalId") && (tModel '[ "<Export") && (tModel '[ "<?xml") && (tModel '[ "Load started") && (tModel '[ "Compiling") && (tModel '[ """output"""), "the tool result the model reads holds no XML or console line: " _ $Extract(tModel, 1, 200))
    }
    For tProposal = tExport, tImport {
        Set tStored = ##class(OcuPilot.Test.ExplorerWrite).StoredText(tProposal.proposalId, .tLedgerRows)
        Do $$$AssertTrue(tLedgerRows > 0, "the turn's ledger rows are read: " _ tLedgerRows)
        Do $$$AssertTrue((tStored [ "OcuProbe1913") && (tStored '[ "<Export") && (tStored '[ "Load started") && (tStored '[ "Compiling"), "and the stored proposal and its ledger rows hold none: " _ $Extract(tStored, 1, 300))
    }
}

/// <p>The stored proposal <var>pProposalId</var>'s value <var>pName</var>.</p>
ClassMethod Stored(pProposalId As %String, pName As %String) As %String
{
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposalId, .tFound, .tValues)
    Quit $Get(tValues(pName))
}

/// <p>AC5: a file holding one of OcuPilot's own documents is refused
/// <code>PROHIBITED.OCUPILOTCODE</code> with the published sentence, on the screen's local import and
/// on the agent's confirmed import of a server file, and the document is not created; its export is
/// allowed.</p>
/// <p>Mutation (Rule 19): drop the import branch of the code arm in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -- both legs go red.</p>
Method TestAnImportOfOcuPilotsOwnCodeIsRefusedOnBothCallers()
{
    Set tProbe = ..#PROBE
    Set tOwn = $Parameter(tProbe, "OWNPACKAGE") _ ".Own"
    Do $$$AssertStatusOK($ClassMethod(tProbe, "MakeClass", ..#PROBENAMESPACE, tOwn), "a probe class whose name begins with OcuPilot is saved")
    Do ..Act("classes", "export-browser", tOwn _ ".cls", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "its export is allowed: " _ $Extract(..Json(tBody), 1, 200))
    Do ..Act("classes", "export", tOwn _ ".cls", ..FileValues("own.xml"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "to a server file too")
    Set tText = $ClassMethod(tProbe, "ReadFile", "own.xml")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Remove", ..#PROBENAMESPACE), "the class is removed")
    Do ..Act("classes", "import-local", "import", {"fileName": "own.xml", "content": (tText), "Compile": "true"}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code _ " " _ tBody.reason, 1: ""), "403 PROHIBITED.OCUPILOTCODE " _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODEREASON, "the screen's import is refused with the published sentence")
    Kill tSettings
    Set tSettings(..#IMPORTKEY) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the import key is enabled through its stored setting")
    Set tArgs = ..FileValues("own.xml")
    Do tArgs.%Set("Id", "import", "string")
    Do tArgs.%Set("Compile", 1, "boolean")
    Set tSC = ..MintFor(..#IMPORTTOOL, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's import is minted: " _ ..Json($Get(tFault)))
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertEquals(tConfirmHttp _ " " _ $Get(tCode), "403 PROHIBITED.OCUPILOTCODE", "and refused at the confirm")
    Do $$$AssertTrue('$ClassMethod(tProbe, "Exists", ..#PROBENAMESPACE, tOwn _ ".cls"), "the document is not created")
}

/// <p>AC6: a file that does not read is refused <code>UNREADABLE</code> with no document, stub
/// included, created; and the agent's confirmed import is refused <code>CHANGED</code>, with nothing
/// loaded, when the file is rewritten after the mint with the same document and other code, and when
/// the document it would replace changes on the instance after the mint.</p>
/// <p>Mutation (Rule 19): skip the list before the load in
/// <method>OcuPilot.Port.AtelierPort.ImportSet</method> -- the stub leg goes red; drop the digest note
/// from <method>OcuPilot.Port.AtelierPort.Examine</method> -- the rewritten-file leg goes red.</p>
Method TestAnUnreadableOrChangedFileLoadsNothing()
{
    Set tProbe = ..#PROBE
    Set tValues = {"fileName": "bad.xml", "Compile": "true"}
    Do tValues.%Set("content", "<?xml version=""1.0""?>" _ $Char(10) _ "<Export><Class name=""OcuProbe1913.Stub""><Super>%RegisteredObject", "string")
    Do ..Act("classes", "import-local", "import", tValues, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code, 1: ""), "422 EXPLORER.IMPORT.UNREADABLE", "malformed XML is unreadable: " _ ..Json(tBody))
    Do $$$AssertTrue('$ClassMethod(tProbe, "Exists", ..#PROBENAMESPACE, "OcuProbe1913.Stub.cls"), "and leaves no stub")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "MakeClass", ..#PROBENAMESPACE, "OcuProbe1913.Alpha"), "a probe class is saved")
    Do ..Act("classes", "export", "OcuProbe1913.Alpha.cls", ..FileValues("changed.xml"), .tStatus, .tBody)
    Set tExported = $ClassMethod(tProbe, "ReadFile", "changed.xml")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Remove", ..#PROBENAMESPACE), "and removed once exported")
    Kill tSettings
    Set tSettings(..#IMPORTKEY) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the import key is enabled through its stored setting")
    Set tArgs = ..FileValues("changed.xml")
    Do tArgs.%Set("Id", "import", "string")
    Do tArgs.%Set("Compile", 0, "boolean")
    Set tSC = ..MintFor(..#IMPORTTOOL, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the import is minted: " _ ..Json($Get(tFault)))
    Do $$$AssertStatusOK($ClassMethod(tProbe, "MakeClass", ..#PROBENAMESPACE, "OcuProbe1913.Alpha", 1), "another version of the class is saved")
    Do ..Act("classes", "export", "OcuProbe1913.Alpha.cls", ..FileValues("changed.xml"), .tStatus, .tBody)
    Do $$$AssertTrue((tStatus = 200) && ($ClassMethod(tProbe, "ReadFile", "changed.xml") [ "<Property name=""Broken"">") && (tExported '[ "<Property name=""Broken"">"), "and exported over the file, which holds the same document with other code")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Remove", ..#PROBENAMESPACE), "and removed, so the namespace is as the mint read it")
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertEquals(tConfirmHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Api.AtelierError).#IMPORTCHANGED, "the confirm of a file rewritten after the mint is refused as changed")
    Do $$$AssertTrue('$ClassMethod(tProbe, "Exists", ..#PROBENAMESPACE, "OcuProbe1913.Alpha.cls"), "and loads nothing")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "WriteFile", "changed.xml", tExported), "the exported file is put back")
    Set tSC = ..MintFor(..#IMPORTTOOL, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the import is minted again: " _ ..Json($Get(tFault)))
    Do $$$AssertStatusOK($ClassMethod(tProbe, "MakeClass", ..#PROBENAMESPACE, "OcuProbe1913.Alpha", 1), "and the document it would create is created, otherwise, before the confirm")
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertEquals(tConfirmHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Api.AtelierError).#IMPORTCHANGED, "the confirm is refused as changed")
    Do $$$AssertEquals($ClassMethod(tProbe, "Source", ..#PROBENAMESPACE, "OcuProbe1913.Alpha.cls") [ "Property Broken", 1, "and the class stands as it was saved, not as the file holds it")
}

/// <p>An export naming a document the namespace does not hold is refused 404
/// <code>EXPLORER.DOCUMENT.ABSENT</code> at the screen's action and at the agent's mint, with no file
/// written and no proposal minted.</p>
Method TestAnExportNamingAMissingDocumentIsRefused()
{
    Set tProbe = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tProbe, "MakeClass", ..#PROBENAMESPACE, "OcuProbe1913.Alpha"), "a probe class is saved")
    Do ..Act("classes", "export", "OcuProbe1913.Alpha.cls,OcuProbe1913.Missing.cls", ..FileValues("absent.xml"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code, 1: ""), "404 EXPLORER.DOCUMENT.ABSENT", "the screen's export is refused: " _ ..Json(tBody))
    Set tArgs = ..FileValues("absent.xml")
    Do tArgs.%Set("Names", "OcuProbe1913.Alpha.cls,OcuProbe1913.Missing.cls", "string")
    Set tSC = ..MintFor(..#EXPORTTOOL, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "404 EXPLORER.DOCUMENT.ABSENT", "and so is the agent's, at the mint")
    Do $$$AssertTrue('$IsObject($Get(tProposal)) && '$ClassMethod(tProbe, "FileExists", "absent.xml"), "with nothing minted and no file written")
}

/// <p>AC5: the code arm reads every name an import's reviewed summary holds -- one of OcuPilot's own
/// documents after another is refused <code>PROHIBITED.OCUPILOTCODE</code>, a summary naming none is
/// permitted -- and an export of an own-code document is not judged.</p>
Method TestTheCodeArmReadsEveryNameAnImportReviewed()
{
    Set tProhibited = "OcuPilot.Kernel.Proposal.Prohibited"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("class", ..#PROBENAMESPACE, "import", .tImportRef), "the import's target key is built")
    For tCase = $ListBuild("OcuProbe1913.Alpha.cls new, OcuPilotProbe1913.Own.cls replaces 2026-10-02 08:59:19.69, OcuProbe1913.Beta.cls new", "1 PROHIBITED.OCUPILOTCODE"), $ListBuild("OcuProbe1913.Alpha.cls new, OcuProbe1913Mac.MAC new", "0 ") {
        Set tPayload = {}
        Do tPayload.%Set("documents", $List(tCase, 1), "string")
        Do $$$AssertStatusOK($ClassMethod(tProhibited, "Prohibits", "explorer.classes.import", tImportRef, tPayload.%ToJSON(), "[]", .tProhibits, .tCode), "the arm answers")
        Do $$$AssertEquals(tProhibits _ " " _ tCode, $List(tCase, 2), $List(tCase, 1))
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("class", ..#PROBENAMESPACE, "OcuPilotProbe1913.Own.cls", .tExportRef), "an export's target key is built")
    Do $$$AssertStatusOK($ClassMethod(tProhibited, "Prohibits", "explorer.classes.export", tExportRef, "{}", "[]", .tProhibits, .tCode), "the arm answers for an export")
    Do $$$AssertEquals(tProhibits, 0, "and does not judge it")
}

/// <p>The agent's mints refuse the file the write would refuse, with nothing minted: an export naming a
/// directory that does not exist, on <code>path</code>, and an import naming a file that does not
/// exist.</p>
Method TestTheMintsRefuseTheFileTheWriteWould()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, "OcuProbe1913.Alpha"), "a probe class is saved")
    Set tArgs = ..FileValues("none/x.xml")
    Do tArgs.%Set("Names", "OcuProbe1913.Alpha.cls", "string")
    Do ..MintFor(..#EXPORTTOOL, tArgs, .tProposal, .tHttp, .tFault)
    Set tField = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) && $IsObject(tFault.detail.%Get("violations")): tFault.detail.violations.%Get(0).%Get("field"), 1: "")
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: "") _ " " _ tField, "400 EXPLORER.EXPORT.DIRECTORY path", "an export to a directory that does not exist is refused at the mint on path: " _ ..Json($Get(tFault)))
    Do $$$AssertTrue('$IsObject($Get(tProposal)), "and nothing is minted")
    Set tArgs = ..FileValues("absent.xml")
    Do tArgs.%Set("Id", "import", "string")
    Do tArgs.%Set("Compile", 1, "boolean")
    Do ..MintFor(..#IMPORTTOOL, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 PATH.NOFILE", "an import of a file that does not exist is refused at the mint: " _ ..Json($Get(tFault)))
    Do $$$AssertTrue('$IsObject($Get(tProposal)), "and nothing is minted")
}

/// <p>The import's closed schema requires its target, its server file and its compile choice, and
/// never advertises a local file or the reviewed summary.</p>
Method TestTheImportSchemaAdvertisesNoLocalFile()
{
    Set tSchema = $ClassMethod(..#IMPORTTOOL, "InputSchema")
    For tName = "fileName", "content", "documents" {
        Do $$$AssertTrue('tSchema.properties.%IsDefined(tName), tName _ " is not advertised")
    }
    Set tRequired = ""
    Set tIterator = tSchema.required.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Set tRequired = tRequired _ $Select(tRequired = "": "", 1: ",") _ tValue
    }
    Do $$$AssertEquals(tRequired _ " " _ tSchema.%GetTypeOf("additionalProperties") _ " " _ tSchema.additionalProperties, "Id,root,path,Compile boolean 0", "its target, file and compile choice are required, and the schema is closed")
}

/// <p>The two export keys ship enabled and the two import keys disabled (AD-22).</p>
Method TestTheBaselineShipsTheImportsDisabled()
{
    For tCase = $ListBuild("explorer.classes.export", 1), $ListBuild("explorer.routines.export", 1), $ListBuild("explorer.classes.import", 0), $ListBuild("explorer.routines.import", 0) {
        Do ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 1), .tListed)
        Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve($List(tCase, 1), "write", .tEnabled, .tSource)
        Do $$$AssertEquals(tListed _ " " _ ''$Get(tEnabled), "1 " _ $List(tCase, 2), $List(tCase, 1) _ ": listed and decided " _ $List(tCase, 2))
    }
}

}

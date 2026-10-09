/// <p>Pins Story 19.3's person save end to end, and Story 20.21's advertising of both saves (AD-8, AD-10,
/// AD-22, AD-39, AD-53, AD-61): the Classes and Routines lists' <code>save</code> action over HTTP on probe
/// documents in <code>USER</code> -- the text saved at the version read and answered with its target, read again
/// through the viewer's own declared read; a concurrent change refused <code>CONFLICT</code> and kept; a held
/// document refused <code>LOCKED</code>, its holder logged at information severity; an empty text or a compile
/// choice other than true or false refused by the route; OcuPilot's own code refused; the compile's lines on the
/// screen's answer alone; the save keys shipping enabled while a person's Save writes; and both saves offered to
/// the agent.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over
/// HTTP as <class>OcuPilot.Test.Http</class>'s account, and a <code>USER</code> namespace. It creates and removes
/// the documents <class>OcuPilot.Test.ExplorerSaveProbe</class> names and one lock job, released before its test
/// ends, reads the tail of <code>messages.log</code>, and snapshots the stored governance policy before each test
/// and puts it back after it.</p>
Class OcuPilot.Test.ExplorerSave Extends %UnitTest.TestCase
{

Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerSaveProbe";

/// <p>The probe class every leg saves.</p>
Parameter ALPHA = "OcuProbe193.Alpha";

/// <p>The two save tools, the Classes list's first.</p>
Parameter TOOLS = "explorer.classes.save,explorer.routines.save";

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
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "ReleaseLock", ..#PROBENAMESPACE), "no lock job is left holding a probe")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "every probe document is removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>One <code>save</code> on <var>pList</var> in the probe namespace: <var>pText</var> as
/// <var>pId</var> at <var>pVersion</var>, compiled when <var>pCompile</var> is <code>true</code>; the
/// HTTP status and the parsed envelope.</p>
ClassMethod Save(pList As %String, pId As %String, pText As %String, pVersion As %String, pCompile As %String, Output pStatus As %Integer, Output pBody)
{
    Set tRequest = {"action": "save"}
    Do tRequest.%Set("id", pId, "string")
    Set tValues = {}
    Do tValues.%Set("content", pText, "string")
    Do tValues.%Set("version", pVersion, "string")
    Do tValues.%Set("Compile", pCompile, "string")
    Do tRequest.%Set("values", tValues)
    Do ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/explorer." _ pList _ "/action?ns=" _ ..#PROBENAMESPACE, .pStatus, .pBody, tRequest.%ToJSON())
}

/// <p><var>pBody</var> as text.</p>
ClassMethod Json(pBody) As %String
{
    If $IsObject($Get(pBody)) Quit pBody.%ToJSON()
    Quit $Get(pBody)
}

/// <p>The probe class's source and version.</p>
ClassMethod Source(pDocument As %String = {..#ALPHA _ ".cls"}) As %String
{
    Quit $ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, pDocument)
}

ClassMethod Version(pDocument As %String = {..#ALPHA _ ".cls"}) As %String
{
    Quit $ClassMethod(..#PROBE, "Version", ..#PROBENAMESPACE, pDocument)
}

/// <p>AC1, AC7, AC8: a class's text saved over the screen route at the version read is stored and
/// answered with the change event's triple and verb, no output and nothing of the text; the class
/// viewer's own declared read then answers the saved text under a new version; and a routine is saved
/// the same way on the Routines list.</p>
Method TestTheScreenRouteSavesAndAnswersItsTarget()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tVersion = ..Version()
    Set tText = $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "2")
    Do ..Save("classes", ..#ALPHA _ ".cls", tText, tVersion, "false", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody) && $IsObject(tBody.%Get("target")): tBody.action _ " " _ tBody.target.%ToJSON() _ " " _ tBody.readBack.verdict _ " " _ tBody.%GetTypeOf("output"), 1: ""), "200 updated {""type"":""class"",""scope"":""USER"",""id"":""OcuProbe193.Alpha.cls""} nothingSent unassigned", "the save answers its target and verb, with no output: " _ ..Json(tBody))
    Do $$$AssertTrue(..Json(tBody) '[ "Quit 2", "and nothing of the text")
    Do $$$AssertEquals(..Source(), tText, "the instance holds the text")
    Do ##class(OcuPilot.Test.Http).MakeRequest("GET", "/screens/explorer.class/read?maxRows=50&name=" _ ..#ALPHA _ ".cls&form=udl&ns=" _ ..#PROBENAMESPACE, .tReadStatus, .tRead)
    Set tDocument = $Select($IsObject(tRead) && $IsObject(tRead.%Get("document")): tRead.document, 1: {})
    Set tLines = $Select($IsObject(tDocument.%Get("content")): tDocument.content.%ToJSON(), 1: "")
    Do $$$AssertTrue((tReadStatus = 200) && (tLines [ "Quit 2") && (tDocument.modified '= "") && (tDocument.modified '= tVersion) && (tDocument.modified = ..Version()), "the viewer's own read answers the saved text under its new version: " _ tReadStatus _ " " _ tDocument.%Get("modified"))
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe193Mac.mac"), "a probe routine is saved")
    Set tRoutine = ..Source("OcuProbe193Mac.mac") _ $Char(10) _ " ; saved over the screen route"
    Do ..Save("routines", "OcuProbe193Mac.mac", tRoutine, ..Version("OcuProbe193Mac.mac"), "false", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody) && $IsObject(tBody.%Get("target")): tBody.target.type, 1: ""), "200 routine", "the routine is saved on the Routines list: " _ ..Json(tBody))
    Do $$$AssertEquals(..Source("OcuProbe193Mac.mac"), tRoutine, "with its text")
}

/// <p>AC1: a save at the version read before another writer changed the class is refused 409
/// <code>EXPLORER.DOCUMENT.CONFLICT</code> with the published sentence, and the other writer's text
/// stands.</p>
Method TestAConcurrentChangeIsRefusedAndKept()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tVersion = ..Version()
    Hang 0.1
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Rewrite", ..#PROBENAMESPACE, ..#ALPHA, "3"), "another writer changes it")
    Set tTheirs = ..Source()
    Do ..Save("classes", ..#ALPHA _ ".cls", $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "2"), tVersion, "true", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code _ " " _ tBody.reason, 1: ""), "409 EXPLORER.DOCUMENT.CONFLICT " _ ##class(OcuPilot.Api.AtelierError).#REASONDOCUMENTCONFLICT, "the save is refused with the published sentence")
    Do $$$AssertTrue((..Source() = tTheirs) && (tTheirs [ "Quit 3"), "and the other writer's text stands")
}

/// <p>Story 19.3's empty-text row and AD-56 (ii): a save whose text is empty, or whose
/// <code>Compile</code> is neither <code>true</code> nor <code>false</code>, is refused 400
/// <code>TOOL.ARGUMENTS</code> by the route, before any port call, and the class is unchanged.</p>
Method TestAnEmptyTextOrABadCompileIsRefusedByTheRoute()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tBefore = ..Source()
    Do ..Save("classes", ..#ALPHA _ ".cls", "", ..Version(), "false", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code, 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "the empty text is refused: " _ ..Json(tBody))
    Do ..Save("classes", ..#ALPHA _ ".cls", $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "2"), ..Version(), "yes", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code, 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "a compile choice other than true or false is refused: " _ ..Json(tBody))
    Do $$$AssertEquals(..Source(), tBefore, "and the class is unchanged")
}

/// <p>AC5, AD-61 rule 6: over the screen route, a save of a class another process holds is refused
/// 409 <code>EXPLORER.DOCUMENT.LOCKED</code> with the published sentence and the class unchanged, and
/// the vendor's lock message reaches <code>messages.log</code> at information severity, never as a
/// fault.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AtelierPort.LogNote</method> write through
/// <method>OcuPilot.Kernel.Audit.Log.Error</method> -- this goes red.</p>
Method TestALockedDocumentIsRefusedAndItsHolderNoted()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tBefore = ..Source()
    Set tLog = ##class(%File).NormalizeFilename(##class(OcuPilot.Port.LogSourcePort).FileFor("messages"), ##class(OcuPilot.Port.LogSourcePort).ManagerDirectory())
    Set tFrom = ##class(%File).GetFileSize(tLog)
    Do $$$AssertTrue(tFrom >= 0, "the messages log resolves, so its tail can be read: " _ tLog)
    Do $$$AssertTrue($ClassMethod(..#PROBE, "HoldLock", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), "another process holds the class")
    Try {
        Do ..Save("classes", ..#ALPHA _ ".cls", $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "2"), ..Version(), "false", .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code _ " " _ tBody.reason, 1: ""), "409 EXPLORER.DOCUMENT.LOCKED " _ ##class(OcuPilot.Api.AtelierError).#REASONDOCUMENTLOCKED, "the save is refused with the published sentence: " _ ..Json(tBody))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the leg completes without raising")
    }
    Do $$$AssertTrue($ClassMethod(..#PROBE, "ReleaseLock", ..#PROBENAMESPACE), "the lock is released")
    Do $$$AssertEquals(..Source(), tBefore, "and the class is unchanged")
    Set tLine = ""
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If tStream.LinkToFile(tLog) && (tStream.Size > tFrom) && tStream.MoveTo(tFrom + 1) {
        While 'tStream.AtEnd {
            Set tRead = tStream.ReadLine()
            If tRead [ "PutDoc found the document held by another process" Set tLine = tRead
        }
    }
    Set tStream = ""
    Do $$$AssertTrue((tLine [ "#5864") && ($Piece($Piece(tLine, ") ", 2), " ", 1) = "0"), "the vendor's lock message is logged at information severity: " _ tLine)
}

/// <p>AC6: a save of a class whose name begins with <code>OcuPilot</code> is refused 403
/// <code>PROHIBITED.OCUPILOTCODE</code> with the published sentence, and the class is unchanged.</p>
Method TestOcuPilotsOwnCodeIsRefused()
{
    Set tOwn = $Parameter(..#PROBE, "OWNPACKAGE") _ ".Own"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, tOwn), "a probe class whose name begins with OcuPilot is saved")
    Set tBefore = ..Source(tOwn _ ".cls")
    Do ..Save("classes", tOwn _ ".cls", $ClassMethod(..#PROBE, "ClassText", tOwn, "2"), ..Version(tOwn _ ".cls"), "false", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code _ " " _ tBody.reason, 1: ""), "403 PROHIBITED.OCUPILOTCODE " _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODEREASON, "the save is refused with the published sentence")
    Do $$$AssertEquals(..Source(tOwn _ ".cls"), tBefore, "and the class is unchanged")
}

/// <p>AC4: a save that compiles answers the compiler's lines as the screen's <code>output</code>, and
/// the class is compiled.</p>
/// <p>Mutation (Rule 19): answer <code>""</code> from
/// <method>OcuPilot.Screen.Tool.ExplorerSave.WriteOutput</method> -- this goes red.</p>
Method TestACompileAnswersItsLinesToTheScreen()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Do ..Save("classes", ..#ALPHA _ ".cls", $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "4"), ..Version(), "true", .tStatus, .tBody)
    Set tOutput = $Select($IsObject(tBody) && $IsObject(tBody.%Get("output")): tBody.output, 1: {})
    Do $$$AssertTrue((tStatus = 200) && (tOutput.%GetTypeOf("lines") = "array") && (tOutput.lines.%ToJSON() [ ("Compiling class " _ ..#ALPHA)) && (tOutput.%Get("errors") = 0), "the save answers the compiler's lines: " _ ..Json(tBody))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, ..#ALPHA), "and the class is compiled")
}

/// <p>AC1, AD-22: both save keys are in the baseline and ship enabled, so the governance policy reads
/// them enabled, while a person's own Save writes.</p>
Method TestTheKeysShipEnabledAndAPersonsSaveWrites()
{
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tKey = $Piece(..#TOOLS, ",", tI)
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed(tKey, .tListed)
        Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve(tKey, "write", .tEnabled, .tSource)
        Do $$$AssertEquals(tListed _ " " _ tValue _ " " _ ''$Get(tEnabled), "1 1 1", tKey _ ": listed, enabled, and read enabled")
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tText = $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "5")
    Do ..Save("classes", ..#ALPHA _ ".cls", tText, ..Version(), "false", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "a person's Save writes: " _ ..Json(tBody))
    Do $$$AssertEquals(..Source(), tText, "the text")
}

/// <p>The number of stored proposals naming tool <var>pToolName</var>.</p>
ClassMethod ProposalRows(pToolName As %String) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ToolName) = ?", pToolName)
    If (tRS.%SQLCODE '= 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%Get("N")
}

/// <p>AC1, AD-53, Story 20.21: each save is advertised: it is in the provider tool list, the dispatch lookup,
/// a proposal-path resolve and each list's screen-context <code>tools</code>, and its <code>Advertised</code> is
/// 1. A call carrying only <code>Names</code> is refused 400 <code>TOOL.ARGUMENTS</code> with no proposal written.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.ExplorerSave.ADVERTISED</parameter> 0 -- this goes red.</p>
Method TestTheSaveIsOfferedToTheAgent()
{
    Set tRegistry = "OcuPilot.Screen.Tool.Registry"
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ProviderTools", .tProvider), "the provider tool list builds")
    Set tProviderNames = ""
    For tI = 1:1:+$Get(tProvider) Set tProviderNames = tProviderNames _ $ListBuild(tProvider(tI, "name"))
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tTool = $Piece(..#TOOLS, ",", tI)
        Set tList = $Select(tI = 1: "classes", 1: "routines")
        Set tWire = $ClassMethod(tRegistry, "WireName", tTool)
        Do $$$AssertTrue($ListFind(tProviderNames, tWire) > 0, tTool _ ": the provider tool list carries the save")
        Kill tByWire
        Do $ClassMethod(tRegistry, "ResolveWire", tWire, .tByWire)
        Do $$$AssertTrue($IsObject($Get(tByWire)), tTool _ ": the dispatch lookup finds the save")
        Kill tByName
        Do $ClassMethod(tRegistry, "Resolve", tTool, .tByName)
        Do $$$AssertTrue($IsObject($Get(tByName)), tTool _ ": a proposal-path resolve finds the save")
        Kill tTools
        Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools("OcuPilot.Screen.Descriptor.Explorer" _ $Select(tI = 1: "Class", 1: "Routine") _ "List", .tTools), tTool _ ": the list's context tools build")
        Set tJson = $Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: "")
        Do $$$AssertTrue(tJson [ tWire, tTool _ ": the list's context tools carry the save: " _ tJson)
        Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Tool.Explorer" _ $Select(tI = 1: "Class", 1: "Routine") _ "Save", "Advertised"), 1, tTool _ ": declared advertised")
    }

    Set tBefore = ..ProposalRows("explorer.classes.save")
    Do $$$AssertTrue(tBefore >= 0, "the stored proposals are counted: " _ tBefore)
    Do ##class(OcuPilot.Kernel.Scope).Set(..#PROBENAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded")
    Set tUse = {"type": "tool_use", "id": "toolu_save", "input": {"Names": "OcuProbe193.Alpha.cls"}}
    Do tUse.%Set("name", $ClassMethod(tRegistry, "WireName", "explorer.classes.save"), "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurn, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertStatusOK(tSC, "the dispatch answers")
    Set tCode = ""
    If $IsObject($Get(tResults)) && (tResults.%Size() = 1) Set tCode = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content")).%Get("code")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "a call carrying only Names is refused TOOL.ARGUMENTS")
    Do $$$AssertEquals(..ProposalRows("explorer.classes.save"), tBefore, "and no proposal is written")
}

}

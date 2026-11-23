/// <p>What Story 24.16 Batch 4's armed archive suites share: the arming check, the probe messages <class>OcuPilot.Test.InteropArchiveFixture</class> stores in <code>HSCUSTOM</code>
/// and removes from it and from <code>USER</code> before and after every test and asserts gone, both namespaces' <code>^Ens.ArchiveManager</code> trees put back exactly, the lock
/// asserted free after every test, the HTTP calls of the Archive manager and Archive settings screens and the proposal route, the agent's mint, the governance key a test turns on
/// and the audit rows a run or a set leaves. The source is <code>HSCUSTOM</code>, which holds the product; the target is <code>USER</code>, the one namespace the classic page lists
/// on the throwaway. <b>No production is started.</b></p>
/// <p><b>Not run itself</b>: it declares no test.</p>
Class OcuPilot.Test.InteropArchiveCase Extends %UnitTest.TestCase [ Abstract ]
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropArchiveFixture";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropArchiveSeam";

Parameter SOURCE = "HSCUSTOM";

Parameter TARGET = "USER";

Parameter RUNSCREEN = "/screens/interop.archive";

Parameter SETSCREEN = "/screens/interop.archivesettings";

Parameter RUNTOOL = "OcuPilot.Screen.Tool.InteropArchiveRun";

Parameter SETTOOL = "OcuPilot.Screen.Tool.InteropArchiveSettingSet";

Parameter RUNKEY = "interop.archive.run";

Parameter SETKEY = "interop.archivesettings.set";

Parameter TARGETNAME = "Archive to namespace";

Parameter CLASSNAME = "Archive manager class name";

Parameter DAYSNAME = "Number of days before archiving";

/// <p>The days every run is given: nothing but a probe, back-dated twice as long, is old enough to move.</p>
Parameter RUNDAYS = 3650;

/// <p>Both namespaces' archive trees as every test starts from them: no node.</p>
Parameter EMPTYTREES = "{""HSCUSTOM"":[],""USER"":[]}";

/// <p>What both namespaces' archive trees held when the class started.</p>
Property PreparedTrees As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedTrees = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, ..%ClassName(1) _ " stores probe messages in HSCUSTOM, moves them into USER, writes both namespaces' archive settings and creates principals on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedTrees = $ClassMethod(..#FIXTURE, "SaveTrees")
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    If ..PreparedTrees = "" Quit $$$OK
    Quit $ClassMethod(..#FIXTURE, "RestoreTrees", ..PreparedTrees)
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "ClearLog")
    Kill ^IRIS.Temp.OcuProbe2416ArcMode, ^IRIS.Temp.OcuProbe2416ArcHold
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Do $ClassMethod(..#FIXTURE, "RestoreTrees", ..#EMPTYTREES)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "ClearLog")
    Set ^IRIS.Temp.OcuProbe2416ArcHold = "stop"
    Hang 0.3
    Kill ^IRIS.Temp.OcuProbe2416ArcMode, ^IRIS.Temp.OcuProbe2416ArcHold
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "DropProbes"), "the probe messages and their archived copies are removed from both namespaces, and none survives")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "RestoreTrees", ..PreparedTrees), "both namespaces' archive trees are put back")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SaveTrees"), ..PreparedTrees, "and read as they did before the test")
    Do $$$AssertTrue('$ClassMethod(..#FIXTURE, "LockHeld", ..#SOURCE), "the vendor's lock is free in the source namespace")
    Do $$$AssertTrue('$ClassMethod(..#FIXTURE, "LockHeld", ..#TARGET), "and in the target")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>One HTTP call as the test account, scoped to <var>pNamespace</var>: the status in <var>pStatus</var> and the parsed answer, or the raw text, in <var>pAnswer</var>.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pBody, Output pStatus As %Integer, Output pAnswer, pNamespace As %String = {..#SOURCE}) As %Status
{
    Set pAnswer = ""
    Kill tExtra
    Set tJson = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ pNamespace
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, tJson, $Select(tJson = "": "", 1: "application/json"), .tExtra, 300)
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
    Quit tSC
}

/// <p>One person's Run archive on the Archive manager screen as <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod ActRun(Output pAnswer, pNamespace As %String = {..#SOURCE}) As %String
{
    Set tBody = {"action": "archive", "id": (pNamespace)}
    Do ..Call("POST", ..#RUNSCREEN _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>One person's Set value on the Archive settings screen as <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod ActSet(pId As %String, pValue As %String, Output pAnswer) As %String
{
    Set tBody = {"action": "set", "id": (pId), "values": {"Value": (pValue)}}
    Do ..Call("POST", ..#SETSCREEN _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The agent's mint of <var>pTool</var> for <var>pArgs</var>, scoped to <var>pNamespace</var>: the code of its refusal, <code>minted</code> when it was not refused; the sentence
/// in <var>pReason</var>; the proposal in <var>pProposal</var> and its turn in <var>pTurn</var>.</p>
ClassMethod MintVerdict(pTool As %String, pArgs As %DynamicObject, Output pReason As %String, Output pProposal, Output pTurn, pNamespace As %String = {..#SOURCE}) As %String
{
    Set pReason = ""
    Set pProposal = ""
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .pTurn)
    If $$$ISERR(tSC) Quit "refused"
    Do pArgs.%Set("rationale", "probe", "string")
    Do pArgs.%Set("expectedImpact", "probe", "string")
    Set tIdArgument = $ClassMethod(pTool, "IdArgument")
    Set tSC = $ClassMethod($ClassMethod(pTool, "MintClass"), "Mint", $Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), tUser, "", pTurn, pArgs, $ClassMethod(pTool, "LimitsClass"), .pProposal, .tHttp, .tFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pArgs.%Get(tIdArgument), tIdArgument, $ClassMethod(pTool, "SettableFields"), $ClassMethod(pTool, "ToolClass"))
    If $IsObject($Get(pProposal)) Quit "minted"
    If '$IsObject($Get(tFault)) Quit "refused"
    Set pReason = $Select($IsObject(tFault.%Get("detail")) && (tFault.detail.%Get("problem") '= ""): tFault.detail.%Get("problem"), 1: tFault.%Get("reason"))
    Quit tFault.%Get("code")
}

/// <p>The agent's mint of the archive run of <var>pNamespace</var>.</p>
ClassMethod MintRun(Output pReason As %String, Output pProposal, Output pTurn, pNamespace As %String = {..#SOURCE}) As %String
{
    Quit ..MintVerdict(..#RUNTOOL, {"Name": (pNamespace)}, .pReason, .pProposal, .pTurn, pNamespace)
}

/// <p>The agent's mint of the set of <var>pName</var> to <var>pValue</var> in <var>pNamespace</var>.</p>
ClassMethod MintSet(pName As %String, pValue As %String, Output pReason As %String, Output pProposal, Output pTurn, pNamespace As %String = {..#SOURCE}) As %String
{
    Quit ..MintVerdict(..#SETTOOL, {"Name": (pName), "Value": (pValue)}, .pReason, .pProposal, .pTurn, pNamespace)
}

/// <p>Confirm proposal <var>pProposalId</var> over the wire as the test account, scoped to <var>pNamespace</var>: the status in <var>pStatus</var>, the raw body and the parsed answer.</p>
ClassMethod Confirm(pProposalId As %String, Output pStatus As %Integer, Output pRaw As %String, Output pAnswer, pNamespace As %String = {..#SOURCE}) As %Status
{
    Set pAnswer = ""
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/proposal/" _ pProposalId _ "/confirm?ns=" _ pNamespace
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pRaw, .tHeaders, "", "application/json", .tExtra, 300)
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(pRaw) } Catch { Set pAnswer = "" }
    Quit tSC
}

/// <p>The port class <var>pClass</var>'s call of <var>pEndpoint</var> and <var>pType</var> in <var>pNamespace</var> as <code>status code</code>, the row or rows in <var>pResult</var> and
/// the envelope in <var>pFault</var>.</p>
ClassMethod Verdict(pEndpoint As %String, pType As %String, Output pResult, Output pFault, pId As %String = "", pBody = "", pAction As %String = "", pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    If pId '= "" Set tQuery("id") = pId
    If pAction '= "" Set tQuery("action") = pAction
    Set tSC = $ClassMethod(pClass, "Invoke", pEndpoint, pType, .tQuery, pBody, .pResult, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>The port's run of <var>pNamespace</var> as <code>status code</code>.</p>
ClassMethod RunVerdict(Output pFault, pClass As %String = {..#PORT}, pNamespace As %String = {..#SOURCE}) As %String
{
    Quit ..Verdict("Archive", "ARCHIVE", .tRow, .pFault, pNamespace, , , pNamespace, pClass)
}

/// <p>Store the archive settings of the source namespace as <var>pTarget</var>, <var>pClass</var> and <var>pDays</var>, each <code>&lt;absent&gt;</code> for a node not stored.</p>
ClassMethod Settings(pTarget As %String = {..#TARGET}, pDays As %String = {..#RUNDAYS}, pClass As %String = "<absent>")
{
    Do $ClassMethod(..#FIXTURE, "PutSettings", ..#SOURCE, pTarget, pClass, pDays)
}

/// <p>Arrange the matrix's probes in the source: one back-dated header of each body kind and one Queued, and one made now; answer <code>1</code> when each was stored. The ids are in
/// <var>pIds</var> by name.</p>
ClassMethod Arrange(Output pIds) As %Boolean
{
    Kill pIds
    Set pIds("hl7") = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "hl7", "Hl7")
    Set pIds("xml") = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "xml", "Xml")
    Set pIds("chars") = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "chars", "Chars")
    Set pIds("none") = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "none", "None")
    Set pIds("queued") = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "none", "Queued", $Parameter(..#FIXTURE, "OLDDAYS"), 2)
    Set pIds("current") = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "xml", "Current", 0)
    Set tOk = 1
    Set tKind = ""
    For {
        Set tKind = $Order(pIds(tKind))
        If tKind = "" Quit
        If +pIds(tKind) < 1 Set tOk = 0
    }
    Quit tOk
}

/// <p>The ids of <var>pIds</var>'s back-dated probes, ascending, comma-separated.</p>
ClassMethod OldIds(ByRef pIds) As %String
{
    Set tList = $ListBuild(pIds("hl7"), pIds("xml"), pIds("chars"), pIds("none"), pIds("queued"))
    Set tSorted = ""
    For tI = 1:1:$ListLength(tList) {
        Set tIds(+$List(tList, tI)) = ""
    }
    Set tId = ""
    For {
        Set tId = $Order(tIds(tId))
        If tId = "" Quit
        Set tSorted = tSorted _ $Select(tSorted = "": "", 1: ",") _ tId
    }
    Quit tSorted
}

/// <p>The history rows of the source as one text, <code>Name=Value</code>, separated by <code>;</code>.</p>
ClassMethod History() As %String
{
    Do ..Verdict("Archive", "LIST", .tRows)
    Set tText = ""
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tText = tText _ $Select(tText = "": "", 1: ";") _ tRow.Name _ "=" _ tRow.Value
        }
    }
    Quit tText
}

/// <p>The value of the history row <var>pName</var>.</p>
ClassMethod HistoryValue(pName As %String) As %String
{
    Set tText = ";" _ ..History() _ ";"
    Set tFrom = $Find(tText, ";" _ pName _ "=")
    If 'tFrom Quit ""
    Quit $Piece($Extract(tText, tFrom, *), ";", 1)
}

/// <p>The error rows of the source as one text, <code>MessageId</code>, comma-separated, and the count in <var>pCount</var>.</p>
ClassMethod ErrorIds(Output pCount As %Integer, pClass As %String = {..#PORT}) As %String
{
    Do ..Verdict("ArchiveErrors", "LIST", .tRows, , , , , , pClass)
    Set tText = ""
    Set pCount = 0
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set pCount = pCount + 1
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.MessageId
        }
    }
    Quit tText
}

/// <p>Turn on the governance key of the run, which ships off, for the rest of the test; <var>pPolicy</var> is what to hand back to the fixture's <code>Restore</code>.</p>
ClassMethod EnableKey(Output pPolicy) As %Status
{
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.pPolicy)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Kill tSettings
    Set tSettings(..#RUNKEY) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>The rows of OcuPilot's own <code>ConfigChange</code> since <var>pSince</var> that carry <var>pMarker</var>, with the last row's data in <var>pData</var>.</p>
ClassMethod OwnRows(pSince As %String, pMarker As %String, Output pData As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", pMarker, .pData)
}

/// <p>How many rows of the vendor's own audit since <var>pSince</var> carry <var>pWords</var>: a run and a set write none (measured).</p>
ClassMethod VendorRows(pSince As %String, pWords As %String) As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventData, Description FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = '%Ensemble'", pSince)
        While tRS.%Next() {
            If (tRS.%Get("EventData") [ pWords) || (tRS.%Get("Description") [ pWords) Set tCount = tCount + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>The text of every step of <var>pSteps</var>, joined by line feeds.</p>
ClassMethod StepText(pSteps As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pSteps) Quit tText
    Set tIterator = pSteps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        Set tText = tText _ $Select(tText = "": "", 1: $Char(10)) _ tStep.%Get("text")
    }
    Quit tText
}

}
